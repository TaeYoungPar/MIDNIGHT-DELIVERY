--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.OrderCatalog)
local RoundModel = require(script.Parent.RoundModel)
local OrderModel = require(script.Parent.OrderModel)
local Planner = require(script.Parent.OrderPlanner)
local Security = require(script.Parent.SecurityService)
local Economy = require(script.Parent.EconomyService)
local PlayerStates = require(script.Parent.PlayerStateService)
local Monsters = require(script.Parent.MonsterService)
local RoundService = {}
type Destination = { prompt: ProximityPrompt, target: Vector3, door: Part }
type World = { world: Folder, spawn: SpawnLocation, destinations: { [string]: Destination }, fakeCenter: Vector3 }
type Remotes = { State: RemoteEvent, Feedback: RemoteEvent, Snapshot: RemoteFunction }

function RoundService.start(world: World, remotes: Remotes, dependencies: any?)
	local model = RoundModel.new(Config.Round)
	local orders: OrderModel.Model? = nil
	local security, economy = Security.new(), Economy.new()
	local playerStates, monsters
	local version, elapsed = 0, 0
	local connections = {}
	local holds: { [Player]: { index: number, destination: string, began: number } } = {}
	local function now() return workspace:GetServerTimeNow() end
	local function snapshot(player: Player)
		local spec = orders and orders:current()
		local members = {}
		for _, member in Players:GetPlayers() do
			if model.participants[member.UserId] then
				local status = if playerStates then playerStates:status(member) else { downUntil = 0, protectedUntil = 0 }
				table.insert(members, { name = member.DisplayName, downUntil = status.downUntil })
			end
		end
		local status = if playerStates then playerStates:status(player) else { downUntil = 0, protectedUntil = 0 }
		local target = if spec and spec.kind == "Fake" then world.fakeCenter
			elseif spec then world.destinations[spec.destination].target else nil
		return {
			downUntil = status.downUntil, protectedUntil = status.protectedUntil, members = members,
			chase = if monsters then monsters:status() else { kind = "", endsAt = 0, targetId = 0 },
			version = version, phase = model.phase, roundId = model.roundId, endsAt = model.endsAt,
			participant = model.participants[player.UserId] == true, playerCount = #Players:GetPlayers(),
			coins = player:GetAttribute("Coins") or 0, xp = player:GetAttribute("XP") or 0,
			result = model.result, reward = player:GetAttribute("RoundReward") or 0,
			orderActive = model.orderActive, target = target,
			orderIndex = if orders then orders.index else 0, orderTitle = if spec then spec.title else "",
			orderHint = if spec then spec.hint else "", orderEndsAt = if orders then orders.expiresAt else 0,
			stage = if orders then orders.stage else "", knocks = if orders then orders.knocks else 0,
			holdUntil = if orders then orders.holdUntil else 0, cooldownUntil = if orders then orders.cooldownUntil else 0,
			hotUntil = if orders and spec and spec.kind == "Giant" then orders.startedAt + Config.Orders.GiantHot else 0,
			late = if orders then orders.late else false, successes = if orders then orders.successes else 0,
			failures = if orders then orders.failures else 0,
		}
	end
	local function publish()
		version += 1
		local spec = orders and orders:current()
		for id, destination in world.destinations do
			local selected = spec and (spec.destination == id or (spec.kind == "Fake" and string.match(id, "^fake_")))
			destination.prompt.Enabled = model.phase == "PLAYING" and selected ~= nil and selected ~= false
				and orders ~= nil and (orders.stage == "ACTIVE" or orders.stage == "CALM")
			destination.prompt.HoldDuration = if spec and spec.kind == "Giant" and orders and orders.late then Config.Orders.GiantCalm else 0.6
			destination.prompt.ActionText = if spec and spec.kind == "Ghost" then "문 두드리기"
				elseif spec and spec.kind == "Giant" and orders and orders.late then "진정시키기" else "야식 배달"
		end
		for _, player in Players:GetPlayers() do remotes.State:FireClient(player, snapshot(player)) end
	end
	local function participant(player)
		return model.phase == "PLAYING" and model.participants[player.UserId] == true
	end
	playerStates = if dependencies and dependencies.playerStates then dependencies.playerStates else PlayerStates.new(world.spawn, participant, publish)
	monsters = if dependencies and dependencies.monsters then dependencies.monsters else Monsters.new(world.world:FindFirstChild("NPCs"), playerStates, publish)
	local function chase(kind, player, destinationId)
		local destination = world.destinations[destinationId]
		if destination and player then monsters:start(kind, player, destination.target + Vector3.new(0, 0, -10)) end
	end
	local function feedback(message: string)
		for _, player in Players:GetPlayers() do remotes.Feedback:FireClient(player, message) end
	end
	local function award(coins: number, orderId: number)
		for id in model.participants do
			local player = Players:GetPlayerByUserId(id)
			if player and economy:award(player, model.roundId, coins, if orderId == 4 then 0 else Config.Delivery.XP, orderId) then
				player:SetAttribute("RoundReward", (player:GetAttribute("RoundReward") or 0) + coins)
			end
		end
	end
	local function flushOutcome()
		if not orders then return end
		local result = orders:takeOutcome()
		if not result then return end
		monsters:stop()
		if result.success then award(result.reward, result.index) end
		feedback(result.reason .. (if result.success then " · +" .. result.reward .. " Coins" else " · 다음 주문으로 진행"))
		table.clear(holds)
		if not orders:advance(now()) then
			playerStates:clearRound()
			if orders.successes == 3 then award(120, 4) end
			model:finish(now(), string.format("배달 %d/3 성공 · %d건 실패", orders.successes, orders.failures))
		end
	end
	local function add(player: Player)
		economy:add(player)
		player:SetAttribute("RoundReward", 0)
		playerStates:add(player)
		publish()
	end
	for _, player in Players:GetPlayers() do add(player) end
	table.insert(connections, Players.PlayerAdded:Connect(add))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		model:remove(player.UserId); security:remove(player); economy:remove(player); playerStates:remove(player)
		holds[player] = nil
		task.defer(publish)
	end))
	remotes.Snapshot.OnServerInvoke = function(player)
		if not security:allowSnapshot(player, now()) then return nil end
		return snapshot(player)
	end
	local function inRange(player: Player, destination: Destination): boolean
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
		local distance = (root.Position - destination.target).Magnitude
		return distance == distance and distance <= Config.Delivery.Distance
	end
	for id, destination in world.destinations do
		table.insert(connections, destination.prompt.PromptButtonHoldBegan:Connect(function(player)
			if not orders or model.phase ~= "PLAYING" or not model.participants[player.UserId] or not playerStates:canAct(player) or not inRange(player, destination) then return end
			holds[player] = { index = orders.index, destination = id, began = now() }
		end))
		table.insert(connections, destination.prompt.Triggered:Connect(function(player)
			if not orders or model.phase ~= "PLAYING" or not model.participants[player.UserId] or now() >= model.endsAt or not playerStates:canAct(player) then return end
			local timestamp = now()
			security:sample(player, timestamp)
			if not security:canDeliver(player, destination.target, Config.Delivery.Distance, timestamp, Config.Delivery.Cooldown) then return end
			local hold = holds[player]
			local heldFor = if hold and hold.index == orders.index and hold.destination == id then timestamp - hold.began else 0
			holds[player] = nil
			if orders:interact(id, player.UserId, timestamp, heldFor) then
				if orders.stage == "HOLDING" then feedback("뒤돌아보지 마세요! 캐릭터가 문을 향한 채 4초 유지")
				elseif orders.stage == "COOLDOWN" then
					feedback("가짜 집이 깨어났습니다! 도망치세요")
					chase("Fake", player, id)
				end
				flushOutcome(); publish()
			end
		end))
	end
	local function ghostHolderValid(): boolean
		if not orders or not orders.holder then return false end
		local player = Players:GetPlayerByUserId(orders.holder)
		if not player or not model.participants[player.UserId] or not playerStates:canAct(player) then return false end
		local dest = world.destinations.ghost_house
		if not inRange(player, dest) then return false end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return false end
		if (root.Position - dest.target).Magnitude > 10 then return false end
		local direction = dest.door.Position - root.Position
		local flat = Vector3.new(direction.X, 0, direction.Z)
		return flat.Magnitude > 0.1 and root.CFrame.LookVector:Dot(flat.Unit) >= 0.55
	end
	table.insert(connections, RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < 0.1 then return end
		elapsed = 0
		playerStates:tick()
		monsters:tick()
		local timestamp, ids = now(), {}
		for _, player in Players:GetPlayers() do security:sample(player, timestamp); table.insert(ids, player.UserId) end
		for player, hold in holds do
			local dest = world.destinations[hold.destination]
			if not orders or hold.index ~= orders.index or not dest or not playerStates:canAct(player) or not inRange(player, dest) then holds[player] = nil end
		end
		table.sort(ids)
		local oldPhase = model.phase
		local changed = model:tick(timestamp, ids)
		if model.phase ~= "PLAYING" and oldPhase == "PLAYING" then monsters:stop(); playerStates:clearRound() end
		if model.phase == "PREPARING" and oldPhase == "WAITING" then
			orders = OrderModel.new(Config.Orders, Planner.create(model.roundId, Catalog.FakeHouses))
			orders:advance(timestamp + Config.Round.Preparing)
			for _, player in Players:GetPlayers() do player:SetAttribute("RoundReward", 0) end
			table.clear(holds)
		elseif model.phase == "WAITING" and oldPhase ~= "WAITING" then orders = nil; table.clear(holds) end
		if model.phase == "PLAYING" and orders then
			local oldStage, previousHolder = orders.stage, orders.holder
			if orders:tick(timestamp, ghostHolderValid()) then
				changed = true
				if orders.stage == "COOLDOWN" and oldStage == "HOLDING" then
					feedback("유령이 쫓아옵니다! 도망친 뒤 다시 노크하세요")
					chase("Ghost", if previousHolder then Players:GetPlayerByUserId(previousHolder) else nil, "ghost_house")
				elseif orders.stage == "CALM" then
					feedback("거인이 나왔습니다! 도망치거나 현관에서 진정시키세요")
					local nearest, distance = nil, math.huge
					for _, candidate in Players:GetPlayers() do
						if playerStates:canChase(candidate) then
							local root = playerStates:root(candidate)
							local d = (root.Position - world.destinations.giant_house.target).Magnitude
							if d < distance then nearest, distance = candidate, d end
						end
					end
					chase("Giant", nearest, "giant_house")
				end
				flushOutcome()
			end
		end
		if changed then publish() end
	end))
	publish()
	return function()
		for _, connection in connections do connection:Disconnect() end
		monsters:destroy()
		playerStates:destroy()
		remotes.Snapshot.OnServerInvoke = nil
		for _, dest in world.destinations do dest.prompt.Enabled = false end
	end
end
return RoundService
