--!strict
local Pathfinding = game:GetService("PathfindingService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Factory = require(script.Parent.Parent.World.MonsterFactory)
local Service = {}
Service.__index = Service
type Actor = { model: Model, root: Part, humanoid: Humanoid }
type Chase = { kind: string, target: Player, character: Model?, actor: Actor, endsAt: number,
	nextPathAt: number, busy: boolean, waypoints: { PathWaypoint }, waypoint: number }
type StateAccess = { canChase: (any, Player) -> boolean, root: (any, Player) -> (BasePart?, Humanoid?), down: (any, Player) -> boolean }
type Store = { parent: Instance, states: StateAccess, changed: () -> (), active: Chase? }
export type Runtime = typeof(setmetatable({} :: Store, Service))
function Service.new(parent: Instance, states: StateAccess, changed: () -> ()): Runtime
	return setmetatable({ parent = parent, states = states, changed = changed, active = nil }, Service)
end
function Service.stop(self: Runtime)
	if not self.active then return end
	local active = self.active
	self.active = nil
	active.actor.model:Destroy()
	self.changed()
end
function Service.status(self: Runtime)
	local active = self.active
	return { kind = if active then active.kind else "", targetId = if active then active.target.UserId else 0,
		endsAt = if active then active.endsAt else 0 }
end
function Service.start(self: Runtime, kind: string, target: Player?, origin: Vector3)
	if not target or not self.states:canChase(target) then return end
	self:stop()
	local duration = if kind == "Ghost" then Config.Monster.GhostDuration elseif kind == "Giant" then Config.Monster.GiantDuration else Config.Monster.FakeDuration
	local groundRay = RaycastParams.new()
	groundRay.FilterType, groundRay.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { self.parent, target.Character }
	-- 현관 바깥에서 지면을 찾고 생성한다. 집 내부/지붕 위 스폰을 피한다.
	local hit = workspace:Raycast(origin + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), groundRay)
	local spawnPosition = if hit then hit.Position + Vector3.new(0, 7, 0) else origin + Vector3.new(0, 7, 0)
	local actor = Factory.create(self.parent, kind, spawnPosition)
	actor.root:SetNetworkOwner(nil)
	self.active = { kind = kind, target = target, character = target.Character, actor = actor,
		endsAt = workspace:GetServerTimeNow() + duration, nextPathAt = 0, busy = false, waypoints = {}, waypoint = 1 }
	self.changed()
end
function Service.tick(self: Runtime)
	local active = self.active
	if not active then return end
	local timestamp = workspace:GetServerTimeNow()
	local targetRoot = self.states:root(active.target)
	if timestamp >= active.endsAt or active.target.Character ~= active.character or not self.states:canChase(active.target)
		or not targetRoot or not active.actor.model.Parent or active.actor.humanoid.Health <= 0 or active.actor.root.Position.Y < -50 then self:stop(); return end
	local actor = active.actor
	local delta = targetRoot.Position - actor.root.Position
	-- 서버 근접 판정 + 시야 검사. 벽 뒤 플레이어를 거리만으로 기절시키지 않는다.
	if delta.Magnitude <= Config.Monster.CatchDistance then
		local ray = RaycastParams.new()
		ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { actor.model }
		local hit = workspace:Raycast(actor.root.Position, delta, ray)
		if not hit or (active.character and hit.Instance:IsDescendantOf(active.character)) then
			self.states:down(active.target)
			self:stop()
			return
		end
	end
	if timestamp >= active.nextPathAt and not active.busy then
		active.busy, active.nextPathAt = true, timestamp + Config.Monster.PathInterval
		local startPosition, goal = actor.root.Position, targetRoot.Position
		task.spawn(function()
			local ok, waypoints = pcall(function()
				local path = Pathfinding:CreatePath({ AgentRadius = if active.kind == "Giant" then 3.5 else 2.5, AgentHeight = 9, AgentCanJump = true })
				path:ComputeAsync(startPosition, goal)
				return if path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}
			end)
			-- 취소된 ComputeAsync가 늦게 돌아와 새 추격의 상태를 덮어쓰지 않게 한다.
			if self.active ~= active then return end
			active.busy = false
			active.waypoints = if ok then waypoints else {}
			active.waypoint = 2
		end)
	end
	local waypoint = active.waypoints[active.waypoint]
	if waypoint and (actor.root.Position - waypoint.Position).Magnitude < 4 then
		active.waypoint += 1; waypoint = active.waypoints[active.waypoint]
	end
	if waypoint then
		if waypoint.Action == Enum.PathWaypointAction.Jump then actor.humanoid.Jump = true end
		actor.humanoid:MoveTo(waypoint.Position)
	else
		-- 경로 실패 시 물리 충돌을 유지한 MoveTo 폴백. CFrame 순간이동으로 벽을 뚫지 않는다.
		actor.humanoid:MoveTo(targetRoot.Position)
	end
end
function Service.destroy(self: Runtime) self:stop() end
return Service
