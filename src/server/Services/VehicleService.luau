--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Motion = require(script.Parent.MovementModel)
local Factory = require(script.Parent.Parent.World.VehicleFactory)
local Service = {}
Service.__index = Service
type Actor = { model: Model, seat: VehicleSeat, prompt: ProximityPrompt }
type Slot = { actor: Actor, owner: Player?, home: CFrame, frame: CFrame, yaw: number, speed: number,
	throttle: number, steer: number, inputAt: number, riding: boolean, mountAfter: number }
type States = { root: (any,Player) -> (BasePart?,Humanoid?), canAct: (any,Player) -> boolean }
type Store = { slots: { Slot }, states: States, canUse: (Player) -> boolean, changed: () -> (), authorizedMove: (Player) -> (),
	connections: { RBXScriptConnection }, cooldowns: { [Player]: number }, stopped: boolean, elapsed: number }
export type Runtime = typeof(setmetatable({} :: Store, Service))
function Service.new(parent: Instance, states: States, canUse: (Player) -> boolean, changed: () -> (), authorizedMove: (Player) -> ()): Runtime
	local self: Runtime = setmetatable({ slots = {}, states = states, canUse = canUse, changed = changed,
		authorizedMove = authorizedMove, connections = {}, cooldowns = {}, stopped = false, elapsed = 0 }, Service)
	for id = 1, 4 do
		local frame = CFrame.new((id - 2.5) * 12, Config.Map.Spawn.Y + 2, Config.Map.Spawn.Z + 20) * CFrame.Angles(0,math.pi,0)
		local actor = Factory.create(parent, id, frame)
		local slot: Slot = { actor = actor, owner = nil, home = frame, frame = frame, yaw = math.pi, speed = 0,
			throttle = 0, steer = 0, inputAt = 0, riding = false, mountAfter = 0 }
		self.slots[id] = slot
		table.insert(self.connections, actor.prompt.Triggered:Connect(function(player)
			local root, humanoid = states:root(player)
			if slot.owner ~= player or not self.canUse(player) or not states:canAct(player) or not root or not humanoid
				or humanoid.SeatPart or workspace:GetServerTimeNow() < slot.mountAfter
				or (root.Position - actor.seat.Position).Magnitude > 8 then return end
			actor.seat:Sit(humanoid)
		end))
		table.insert(self.connections, actor.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local humanoid = actor.seat.Occupant
			if humanoid then
				local character = humanoid.Parent
				local player = if character and character:IsA("Model") then Players:GetPlayerFromCharacter(character) else nil
				if player ~= slot.owner or not player or not self.canUse(player) or not states:canAct(player) then
					humanoid.Sit = false
					return
				end
			end
			slot.riding = humanoid ~= nil
			slot.throttle, slot.steer, slot.speed = 0, 0, 0
			self.changed()
		end))
	end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.elapsed += dt
		if self.elapsed < 1/30 then return end
		local step = math.min(self.elapsed,0.05)
		self.elapsed = 0
		self:tick(step)
	end))
	return self
end
function Service.slot(self: Runtime, player: Player): Slot?
	for _, slot in self.slots do if slot.owner == player then return slot end end
	return nil
end
function Service.add(self: Runtime, player: Player)
	if self:slot(player) then return end
	for _, slot in self.slots do
		if not slot.owner then
			slot.owner = player
			slot.actor.model:SetAttribute("OwnerUserId", player.UserId)
			slot.actor.model:SetAttribute("OwnerName", player.DisplayName)
			slot.actor.prompt.ObjectText = player.DisplayName .. "의 스쿠터"
			self:skin(player,"")
			return
		end
	end
end
-- 벽/바닥을 검사해 좌우·뒤·앞 순서로 하차 지점을 찾는다. 막혔으면 본부의 안전한 스폰으로 복귀한다.
function Service.exitFrame(self: Runtime, slot: Slot, player: Player, parkAtHome: boolean?): CFrame
	local base = if parkAtHome then slot.home else slot.frame
	local params, overlap = RaycastParams.new(), OverlapParams.new()
	params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, {slot.actor.model, player.Character}, true
	overlap.FilterType, overlap.FilterDescendantsInstances, overlap.RespectCanCollide = Enum.RaycastFilterType.Exclude, {slot.actor.model, player.Character}, true
	for _, offset in {Vector3.new(6,0,0),Vector3.new(-6,0,0),Vector3.new(0,0,8),Vector3.new(0,0,-8)} do
		local point = base:PointToWorldSpace(offset)
		local ground = workspace:Raycast(point + Vector3.new(0,8,0), Vector3.new(0,-30,0), params)
		if not ground or ground.Normal.Y < 0.65 or ground.Position.Y > base.Position.Y + 2 then continue end
		local position = ground.Position + Vector3.new(0,3.2,0)
		local origin = base.Position + Vector3.new(0,2,0)
		if workspace:Raycast(origin, position-origin, params) then continue end
		local frame = CFrame.new(position) * base.Rotation
		if #workspace:GetPartBoundsInBox(frame,Vector3.new(4,5.5,4),overlap) == 0 then return frame end
	end
	return CFrame.new(Config.Map.Spawn + Vector3.new(0,4,0)) * CFrame.Angles(0,math.pi,0)
end
function Service.exit(self: Runtime, player: Player, parkAtHome: boolean?)
	local slot = self:slot(player)
	if not slot then return end
	local character = player.Character
	local root, humanoid = self.states:root(player)
	local seat = slot.actor.seat
	local attached = humanoid ~= nil and humanoid.Sit and (seat.Occupant == humanoid or humanoid.SeatPart == seat)
	-- Occupant는 Sit=false보다 늦게 복제될 수 있다. 소유 캐릭터의 용접을 먼저 찾아 제거한다.
	for _, weld in seat:GetChildren() do
		if weld.Name == "SeatWeld" and weld:IsA("Weld") and character
			and ((weld.Part1 and weld.Part1:IsDescendantOf(character)) or (weld.Part0 and weld.Part0:IsDescendantOf(character))) then
			attached = true
			weld:Destroy()
		end
	end
	if attached and character and root and humanoid then
		slot.mountAfter = workspace:GetServerTimeNow() + 1
		humanoid.Sit, humanoid.Jump = false, false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		character:PivotTo(self:exitFrame(slot,player,parkAtHome))
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		self.authorizedMove(player)
	end
	slot.speed, slot.throttle, slot.steer, slot.riding = 0, 0, 0, false
end
function Service.reset(self: Runtime, player: Player, manual: boolean): boolean
	local slot = self:slot(player)
	if not slot then return false end
	local timestamp = workspace:GetServerTimeNow()
	if manual and (not self.canUse(player) or not self.states:canAct(player) or timestamp < (self.cooldowns[player] or 0)) then return false end
	if manual then self.cooldowns[player] = timestamp + Config.Vehicle.ResetCooldown end
	self:exit(player,true)
	-- 용접 제거와 안전 하차를 완료한 뒤 같은 호출에서 복구하여 지연된 재배치가 새 탑승을 덮지 않게 한다.
	slot.frame, slot.yaw = slot.home, math.pi
	slot.actor.model:PivotTo(slot.frame)
	self.changed()
	return true
end
function Service.remove(self: Runtime, player: Player)
	local slot = self:slot(player)
	if slot then
		self:exit(player)
		slot.owner = nil
		slot.actor.model:SetAttribute("OwnerUserId", 0)
		slot.actor.model:SetAttribute("OwnerName", "")
		slot.actor.model:PivotTo(slot.home)
		slot.frame, slot.yaw = slot.home, math.pi
	end
	self.cooldowns[player] = nil
	for _, waiting in Players:GetPlayers() do if waiting ~= player then self:add(waiting) end end
end
function Service.input(self: Runtime, player: Player, throttle: any, steer: any): boolean
	local slot = self:slot(player)
	if not slot or not Motion.input(throttle,steer) or not self.canUse(player) or not self.states:canAct(player) then return false end
	local _, humanoid = self.states:root(player)
	if not humanoid or not self:seated(player) then return false end
	slot.throttle, slot.steer, slot.inputAt = throttle, steer, workspace:GetServerTimeNow()
	return true
end
function Service.seated(self: Runtime, player: Player): boolean
	local slot = self:slot(player)
	local root, humanoid = self.states:root(player)
	return slot ~= nil and root ~= nil and humanoid ~= nil and humanoid.Sit and humanoid.SeatPart == slot.actor.seat
		and slot.actor.seat.Occupant == humanoid and (root.Position - slot.actor.seat.Position).Magnitude <= 12
end
function Service.skin(self: Runtime, player: Player, id: string)
	local slot = self:slot(player)
	if not slot then return end
	local body = slot.actor.model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then body.Color = if id=="scooter_mint" then Color3.fromRGB(99,216,184) else Color3.fromRGB(255,170,69) end
	slot.actor.model:SetAttribute("SkinId",id)
end
function Service.status(self: Runtime, player: Player)
	local slot = self:slot(player)
	return { owned = slot ~= nil, seated = self:seated(player), speed = if slot then math.abs(slot.speed) else 0,
		resetAt = self.cooldowns[player] or 0 }
end
function Service.tick(self: Runtime, dt: number)
	if self.stopped or dt <= 0 then return end
	for _, slot in self.slots do
		local player = slot.owner
		if not player then continue end
		if not self:seated(player) or not self.canUse(player) or not self.states:canAct(player) then
			if slot.riding then self:exit(player); self.changed() end
			slot.throttle, slot.steer = 0, 0
		end
		if workspace:GetServerTimeNow() - slot.inputAt > 0.4 then slot.throttle, slot.steer = 0, 0 end
		slot.speed = Motion.speed(slot.speed, slot.throttle, dt, Config.Vehicle.MaxSpeed)
		if math.abs((slot.actor.model:GetAttribute("Speed") or 0) - math.abs(slot.speed)) > 0.5 or slot.speed == 0 then slot.actor.model:SetAttribute("Speed", math.abs(slot.speed)) end
		if math.abs(slot.speed) < 0.05 then continue end
		local yaw = slot.yaw - slot.steer * 1.6 * dt * math.sign(slot.speed)
		local frame = CFrame.new(slot.frame.Position) * CFrame.Angles(0,yaw,0)
		local overlap = OverlapParams.new()
		overlap.FilterType, overlap.FilterDescendantsInstances, overlap.RespectCanCollide = Enum.RaycastFilterType.Exclude, { slot.actor.model, player.Character }, true
		if #workspace:GetPartBoundsInBox(frame * CFrame.new(0,0.6,0), Vector3.new(4.5,4.4,7.8), overlap) > 0 then slot.speed = 0; continue end
		local delta = frame.LookVector * slot.speed * dt
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude,
			{ slot.actor.model, player.Character }, true
		-- 차체 전체를 sweep하여 옆면/앞면 벽 충돌을 검사한다. 서버 CFrame 순간이동으로 벽을 통과하지 않는다.
		local hit = workspace:Blockcast(frame * CFrame.new(0,0.6,0), Vector3.new(4.5,4.4,7.8), delta, params)
		if hit then slot.speed = 0; continue end
		local proposed = frame.Position + delta
		local ground = workspace:Raycast(proposed + Vector3.new(0,8,0), Vector3.new(0,-35,0), params)
		if not ground or math.abs(proposed.X) > 310 or math.abs(proposed.Z) > 310 or ground.Position.Y < -10 then
			self:reset(player, false); continue
		end
		slot.yaw, slot.frame = yaw, CFrame.new(proposed.X, ground.Position.Y + 3, proposed.Z) * CFrame.Angles(0,yaw,0)
		slot.actor.model:PivotTo(slot.frame)
	end
end
function Service.destroy(self: Runtime)
	self.stopped = true
	for _, connection in self.connections do connection:Disconnect() end
	for _, slot in self.slots do
		if slot.owner then self:exit(slot.owner) end
		slot.actor.model:Destroy()
	end
	table.clear(self.slots)
end
return Service
