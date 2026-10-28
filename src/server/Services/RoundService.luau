--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local RoundModel = require(script.Parent.RoundModel)
local Security = require(script.Parent.SecurityService)
local Economy = require(script.Parent.EconomyService)
local RoundService = {}

type World = { world: Folder, spawn: SpawnLocation, prompt: ProximityPrompt, target: Vector3 }
type Remotes = { State: RemoteEvent, Feedback: RemoteEvent, Snapshot: RemoteFunction }
function RoundService.start(world: World, remotes: Remotes)
	local model = RoundModel.new(Config.Round)
	local security, economy = Security.new(), Economy.new()
	local version, elapsed = 0, 0
	local connections = {}
	local function snapshot(player: Player)
		return {
			version = version, phase = model.phase, roundId = model.roundId, endsAt = model.endsAt,
			participant = model.participants[player.UserId] == true, playerCount = #Players:GetPlayers(),
			coins = player:GetAttribute("Coins") or 0, xp = player:GetAttribute("XP") or 0,
			result = model.result, reward = player:GetAttribute("RoundReward") or 0,
			orderActive = model.orderActive, target = world.target,
		}
	end
	local function publish()
		version += 1
		world.prompt.Enabled = model.phase == "PLAYING" and model.orderActive
		for _, player in Players:GetPlayers() do remotes.State:FireClient(player, snapshot(player)) end
	end
	local function add(player: Player)
		economy:add(player)
		player:SetAttribute("RoundReward", 0)
		player.RespawnLocation = world.spawn
		-- 이미 기본 Place에서 스폰된 캐릭터도 본부로 옮긴다. 새 캐릭터는 RespawnLocation을 따른다.
		if player.Character then player.Character:PivotTo(world.spawn.CFrame + Vector3.new(0, 5, 0)) end
		publish()
	end
	for _, player in Players:GetPlayers() do add(player) end
	table.insert(connections, Players.PlayerAdded:Connect(add))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		model:remove(player.UserId)
		security:remove(player)
		economy:remove(player)
		-- PlayerRemoving 중 GetPlayers()에는 떠나는 플레이어가 아직 포함될 수 있다.
		task.defer(publish)
	end))
	remotes.Snapshot.OnServerInvoke = function(player)
		if not security:allowSnapshot(player, workspace:GetServerTimeNow()) then return nil end
		return snapshot(player)
	end
	table.insert(connections, world.prompt.Triggered:Connect(function(player)
		local now = workspace:GetServerTimeNow()
		security:sample(player, now)
		if not security:canDeliver(player, world.target, Config.Delivery.Distance, now, Config.Delivery.Cooldown) then return end
		local recipients = model:complete(player.UserId, model.roundId, now)
		if not recipients then return end
		for _, id in recipients do
			local recipient = Players:GetPlayerByUserId(id)
			if recipient and economy:award(recipient, model.roundId, Config.Delivery.Reward, Config.Delivery.XP) then
				recipient:SetAttribute("RoundReward", Config.Delivery.Reward)
				remotes.Feedback:FireClient(recipient, "+80 Coins · 배달 성공!")
			end
		end
		publish()
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < 0.1 then return end
		elapsed = 0
		local now, ids = workspace:GetServerTimeNow(), {}
		for _, player in Players:GetPlayers() do
			security:sample(player, now)
			table.insert(ids, player.UserId)
		end
		table.sort(ids)
		local oldPhase = model.phase
		if model:tick(now, ids) then
			if model.phase == "PREPARING" and oldPhase == "WAITING" then
				for _, player in Players:GetPlayers() do player:SetAttribute("RoundReward", 0) end
			end
			publish()
			print(string.format("[MidnightDelivery] round=%d phase=%s", model.roundId, model.phase))
		end
	end))
	publish()
	-- Studio에서 서버 종료 시 이벤트/콜백이 중복 잔류하지 않게 종료 경로를 둔다.
	return function()
		for _, connection in connections do connection:Disconnect() end
		remotes.Snapshot.OnServerInvoke = nil
		world.prompt.Enabled = false
	end
end

return RoundService
