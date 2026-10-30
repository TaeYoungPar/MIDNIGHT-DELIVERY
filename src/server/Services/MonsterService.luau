--!strict
local Pathfinding = game:GetService("PathfindingService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Factory = require(script.Parent.Parent.World.MonsterFactory)
local Service = {}
Service.__index = Service
type Actor = { model: Model, root: Part, humanoid: Humanoid }
type Chase = { kind: string, target: Player, character: Model?, actor: Actor, endsAt: number,
	revealUntil: number, walkSpeed: number, nextPathAt: number, busy: boolean, waypoints: { PathWaypoint }, waypoint: number }
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
	local targetRoot = self.states:root(target)
	if not targetRoot then return end
	local params, overlap = RaycastParams.new(), OverlapParams.new()
	params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, {self.parent,target.Character}, true
	overlap.FilterType, overlap.FilterDescendantsInstances, overlap.RespectCanCollide = Enum.RaycastFilterType.Exclude, {self.parent,target.Character}, true
	local look = targetRoot.CFrame.LookVector
	local forward = Vector3.new(look.X,0,look.Z)
	forward = if forward.Magnitude > 0.1 then forward.Unit else Vector3.new(0,0,-1)
	local right = Vector3.new(-forward.Z,0,forward.X)
	local spawnPosition = nil
	-- 플레이어가 보는 방향부터 빈 지면을 찾는다. 집/벽 안이나 몸에 겹쳐서 생성하지 않는다.
	for _, angle in {0,45,-45,90,-90,135,-135,180} do
		local radians = math.rad(angle)
		local point = targetRoot.Position + (forward*math.cos(radians)+right*math.sin(radians))*Config.Monster.SpawnDistance
		local ground = workspace:Raycast(point+Vector3.new(0,12,0),Vector3.new(0,-60,0),params)
		if not ground or ground.Normal.Y < 0.65 or math.abs(ground.Position.Y-targetRoot.Position.Y)>12 then continue end
		local position = ground.Position+Vector3.new(0,7,0)
		if #workspace:GetPartBoundsInBox(CFrame.new(position),Vector3.new(12,13,12),overlap)>0 then continue end
		if workspace:Raycast(targetRoot.Position,position-targetRoot.Position,params) then continue end
		spawnPosition = position;break
	end
	if not spawnPosition then warn("[MidnightDelivery] No clear monster reveal position");return end
	local actor = Factory.create(self.parent,kind,spawnPosition)
	actor.root.CFrame = CFrame.lookAt(spawnPosition,Vector3.new(targetRoot.Position.X,spawnPosition.Y,targetRoot.Position.Z))
	actor.root:SetNetworkOwner(nil)
	local timestamp = workspace:GetServerTimeNow()
	local walkSpeed = actor.humanoid.WalkSpeed
	actor.humanoid.WalkSpeed = 0
	self.active = {kind=kind,target=target,character=target.Character,actor=actor,
		endsAt=timestamp+Config.Monster.RevealTime+duration,revealUntil=timestamp+Config.Monster.RevealTime,walkSpeed=walkSpeed,
		nextPathAt=0,busy=false,waypoints={},waypoint=1}
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
	-- 등장 유예 중에는 접근해도 즉시 기절시키지 않는다. 이후 원래 추격 속도로 복원한다.
	if timestamp < active.revealUntil then return end
	actor.humanoid.WalkSpeed = active.walkSpeed
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
