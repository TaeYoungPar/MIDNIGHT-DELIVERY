--!strict
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local StateModel = require(script.Parent.PlayerStateModel)
local Service = {}
Service.__index = Service
type Downed = {
	root: BasePart, humanoid: Humanoid, character: Model, attachment: Attachment, generation: number,
	anchored: boolean, walkSpeed: number, jumpPower: number, jumpHeight: number, autoRotate: boolean,
	connections: { RBXScriptConnection },
}
type Rescue = { victim: Player, generation: number, character: Model?, began: number, endedAt: number? }
type Store = { spawn: SpawnLocation, isParticipant: (Player) -> boolean, changed: () -> (), model: StateModel.Model,
	bindings: { [Player]: RBXScriptConnection }, downed: { [Player]: Downed }, rescuers: { [Player]: Rescue }, stopped: boolean, authorizedMove: ((Player) -> ())?, beforeDown: ((Player) -> ())? }
export type Runtime = typeof(setmetatable({} :: Store, Service))

function Service.new(spawn: SpawnLocation, isParticipant: (Player) -> boolean, changed: () -> (), authorizedMove: ((Player) -> ())?): Runtime
	return setmetatable({ spawn = spawn, isParticipant = isParticipant, changed = changed,
		model = StateModel.new(Config.Recovery.DownTime, Config.Recovery.Protection),
		authorizedMove = authorizedMove, bindings = {}, downed = {}, rescuers = {}, stopped = false }, Service)
end
function Service.now(self: Runtime) return workspace:GetServerTimeNow() end
function Service.root(self: Runtime, player: Player): (BasePart?, Humanoid?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return nil, nil end
	local position = root.Position
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z
		or math.abs(position.X) > 1e6 or math.abs(position.Y) > 1e6 or math.abs(position.Z) > 1e6 then return nil, nil end
	return root, humanoid
end
function Service.canAct(self: Runtime, player: Player): boolean
	return self.model:canAct(player.UserId) and self:root(player) ~= nil
end
function Service.canChase(self: Runtime, player: Player): boolean
	local entry = self.model.entries[player.UserId]
	return self.isParticipant(player) and self:canAct(player) and entry ~= nil and self:now() >= entry.protectedUntil
end
function Service.status(self: Runtime, player: Player)
	local entry = self.model.entries[player.UserId]
	return { downUntil = if entry then entry.downUntil else 0, protectedUntil = if entry then entry.protectedUntil else 0 }
end
function Service.clearRecord(self: Runtime, player: Player)
	local record = self.downed[player]
	if not record then return end
	for _, connection in record.connections do connection:Disconnect() end
	record.attachment:Destroy()
	if record.root.Parent then record.root.Anchored = record.anchored end
	if record.humanoid.Parent then
		record.humanoid.WalkSpeed, record.humanoid.JumpPower = record.walkSpeed, record.jumpPower
		record.humanoid.JumpHeight, record.humanoid.AutoRotate = record.jumpHeight, record.autoRotate
	end
	self.downed[player] = nil
	for helper, hold in self.rescuers do if helper == player or hold.victim == player then self.rescuers[helper] = nil end end
end
function Service.spawnCharacter(self: Runtime, player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if self.stopped or not self.bindings[player] or player.Character ~= character or not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then return end
	self:clearRecord(player)
	self.model:reset(player.UserId, self:now())
	-- SpawnLocation도 캐릭터 Pivot도 같은 도로 방향(+Z)을 사용한다.
	character:PivotTo(self.spawn.CFrame + Vector3.new((player.UserId % 4 - 1.5) * 3, 4, 0))
	character:SetAttribute("MidnightSpawnReady", true)
	self.changed()
end
function Service.add(self: Runtime, player: Player)
	self.model:reset(player.UserId, self:now())
	player.RespawnLocation = self.spawn
	self.bindings[player] = player.CharacterAdded:Connect(function(character)
		task.spawn(function() self:spawnCharacter(player, character) end)
	end)
	local character = player.Character
	if character then task.spawn(function() self:spawnCharacter(player, character) end) end
end
function Service.remove(self: Runtime, player: Player)
	if self.bindings[player] then self.bindings[player]:Disconnect(); self.bindings[player] = nil end
	self:clearRecord(player)
	self.rescuers[player] = nil
	self.model:remove(player.UserId)
end
function Service.validRescue(self: Runtime, helper: Player, victim: Player): boolean
	if helper == victim or not self.isParticipant(helper) or not self.isParticipant(victim) or not self:canAct(helper) then return false end
	local record = self.downed[victim]
	local helperRoot = self:root(helper)
	if not record or not helperRoot or victim.Character ~= record.character or record.humanoid.Health <= 0 then return false end
	local delta = record.root.Position - helperRoot.Position
	if delta.Magnitude ~= delta.Magnitude or delta.Magnitude > Config.Recovery.RescueDistance then return false end
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { helper.Character, victim.Character }
	return workspace:Raycast(helperRoot.Position, delta, ray) == nil
end
function Service.recover(self: Runtime, player: Player, automatic: boolean): boolean
	local record = self.downed[player]
	if not record or not self.model:recover(player.UserId, record.generation, self:now()) then return false end
	if automatic and player.Character == record.character then
		-- 구조받지 못해도 가장 가까운 도로 체크포인트에서 복귀한다.
		local nearest, distance = Config.Recovery.Checkpoints[1], math.huge
		for _, point in Config.Recovery.Checkpoints do
			local d = (record.root.Position - point).Magnitude
			if d < distance then nearest, distance = point, d end
		end
		record.character:PivotTo(CFrame.new(nearest) * CFrame.Angles(0, math.pi, 0))
		record.root.AssemblyLinearVelocity, record.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	end
	self:clearRecord(player)
	if automatic and self.authorizedMove then self.authorizedMove(player) end
	self.changed()
	return true
end
function Service.down(self: Runtime, player: Player): boolean
	local root, humanoid = self:root(player)
	local character = player.Character
	if not character or not root or not humanoid or not self.isParticipant(player) or not self.model:down(player.UserId, self:now()) then return false end
	if self.beforeDown then self.beforeDown(player) end
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = "MidnightRescue", root
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "팀원 구조", player.DisplayName
	prompt.HoldDuration, prompt.MaxActivationDistance = Config.Recovery.RescueHold, Config.Recovery.RescueDistance
	prompt.RequiresLineOfSight, prompt.Parent = true, attachment
	local record: Downed = { root = root, humanoid = humanoid, character = character, attachment = attachment,
		generation = self.model.entries[player.UserId].generation, anchored = root.Anchored,
		walkSpeed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight,
		autoRotate = humanoid.AutoRotate, connections = {} }
	self.downed[player] = record
	humanoid.Sit, humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = false, 0, 0, 0, false
	root.Anchored = true
	table.insert(record.connections, prompt.PromptButtonHoldBegan:Connect(function(helper)
		if self:validRescue(helper, player) then
			self.rescuers[helper] = { victim = player, generation = record.generation, character = helper.Character, began = self:now() }
		end
	end))
	table.insert(record.connections, prompt.PromptButtonHoldEnded:Connect(function(helper)
		-- Triggered와 같은 틱에 종료될 수 있어 지연 후 시각을 확인한다.
		local hold = self.rescuers[helper]
		if hold and hold.victim == player then hold.endedAt = self:now() end
	end))
	table.insert(record.connections, prompt.Triggered:Connect(function(helper)
		local hold = self.rescuers[helper]
		if not hold or hold.victim ~= player or hold.generation ~= record.generation or hold.character ~= helper.Character then return end
		if hold.endedAt and self:now() - hold.endedAt > 0.2 then return end
		local endTime = hold.endedAt or self:now()
		if endTime - hold.began < Config.Recovery.RescueHold - 0.15 or not self:validRescue(helper, player) then return end
		local entry = self.model.entries[player.UserId]
		if entry and self:now() < entry.downUntil then self:recover(player, false) end
		self.rescuers[helper] = nil
	end))
	self.changed()
	return true
end
function Service.tick(self: Runtime)
	local timestamp = self:now()
	for helper, hold in self.rescuers do
		if hold.character ~= helper.Character or not self:validRescue(helper, hold.victim)
			or (hold.endedAt and timestamp - hold.endedAt > 0.2) then self.rescuers[helper] = nil end
	end
	for player in self.bindings do
		local root, humanoid = self:root(player)
		if root and humanoid and not humanoid.SeatPart and not self.downed[player]
			and (root.Position.Y < -20 or math.abs(root.Position.X) > 320 or math.abs(root.Position.Z) > 320) then
			player.Character:PivotTo(self.spawn.CFrame + Vector3.new(0,4,0))
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			self.model:reset(player.UserId, timestamp)
			if self.authorizedMove then self.authorizedMove(player) end
			self.changed()
		end
	end
	local pending = {}
	for player, record in self.downed do
		local entry = self.model.entries[player.UserId]
		if not entry or player.Character ~= record.character or record.humanoid.Health <= 0 then table.insert(pending, {player = player, automatic = false})
		elseif timestamp >= entry.downUntil then table.insert(pending, {player = player, automatic = true}) end
	end
	for _, item in pending do
		if item.automatic then self:recover(item.player, true)
		else self:clearRecord(item.player); self.model:reset(item.player.UserId, timestamp); self.changed() end
	end
end
function Service.clearRound(self: Runtime)
	local pending = {}; for player in self.downed do table.insert(pending, player) end
	for _, player in pending do self:recover(player, true) end
	table.clear(self.rescuers)
end
function Service.destroy(self: Runtime)
	self.stopped = true
	local pending = {}; for player in self.bindings do table.insert(pending, player) end
	for _, player in pending do self:remove(player) end
end
return Service
