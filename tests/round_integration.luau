--!strict
-- 실제 RoundService와 하위 서비스의 연결을 mock 신호로 검사한다. Roblox 복제/물리 테스트가 아니다.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function signal()
	local handlers = {}
	return {
		Connect = function(_, callback)
			local key = {}; handlers[key] = callback
			return { Disconnect = function() handlers[key] = nil end }
		end,
		Fire = function(_, ...) for _, callback in handlers do callback(...) end end,
	}
end
local clock = 0
local players = {}
local heartbeat = signal()
local added, removing = signal(), signal()
local playerService = {
	PlayerAdded = added, PlayerRemoving = removing,
	GetPlayers = function() return players end,
	GetPlayerByUserId = function(_, id) for _, p in players do if p.UserId == id then return p end end; return nil end,
}
local nodes, cache = {}, {}
local function node(path)
	if nodes[path] then return nodes[path] end
	local n = { path = path }; nodes[path] = n
	local parent = string.match(path, "^(.*)/[^/]+$")
	if parent then n.Parent = node(parent) end
	return setmetatable(n, { __index = function(_, key) return node(path .. "/" .. key) end })
end
local game = { GetService = function(_, name)
	if name == "Players" then return playerService end
	if name == "RunService" then return { Heartbeat = heartbeat } end
	if name == "ReplicatedStorage" then return { Shared = node("src/shared") } end
	error(name)
end }
local function load(n)
	if cache[n.path] then return cache[n.path] end
	local value = luau.load(fs.readFile(n.path .. ".luau"), { debugName = n.path, environment = {
		game = game, workspace = { GetServerTimeNow = function() return clock end },
		script = n, require = load, Vector3 = r.Vector3, task = { defer = function(fn) fn() end },
	} })()
	cache[n.path] = value; return value
end
local function makePlayer(id)
	local attrs = {}
	local root = {Position = r.Vector3.zero, CFrame = r.CFrame.identity, IsA = function() return true end}
	local humanoid = {Health = 100}
	local p = {UserId = id, root = root, GetAttribute = function(_, key) return attrs[key] end,
		SetAttribute = function(_, key, v) attrs[key] = v end}
	p.Character = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return humanoid end, PivotTo = function() end }
	return p
end
local world = { world = {}, spawn = {CFrame = r.CFrame.identity}, fakeCenter = r.Vector3.zero, destinations = {} }
for index, id in {"ghost_house", "giant_house", "fake_1", "fake_2", "fake_3"} do
	world.destinations[id] = { target = r.Vector3.new(index * 10, 3, 0), door = {Position = r.Vector3.new(index * 10, 3, 3)},
		prompt = { Triggered = signal(), PromptButtonHoldBegan = signal() } }
end
local snapshots = {}
local remotes = { State = {FireClient = function(_, p, snapshot) snapshots[p.UserId] = snapshot end},
	Feedback = {FireClient = function() end}, Snapshot = {} }
local p = makePlayer(1); table.insert(players, p)
local stop = load(node("src/server/Services/RoundService")).start(world, remotes)
local function step(time)
	clock = time; heartbeat:Fire(0.1)
end
local function move(destination)
	p.root.Position = world.destinations[destination].target
	-- +Z 방향을 보는 캐릭터. CFrame.Angles는 실제 Luau 데이터 타입을 사용한다.
	p.root.CFrame = r.CFrame.new(p.root.Position) * r.CFrame.Angles(0, math.pi, 0)
end
local function trigger(id) world.destinations[id].prompt.Triggered:Fire(p) end
step(0); step(20); assert(snapshots[1].phase == "PREPARING")
step(30); assert(snapshots[1].phase == "PLAYING" and snapshots[1].orderIndex == 1)
local spectator = makePlayer(2); table.insert(players, spectator); added:Fire(spectator)
assert(not snapshots[2].participant)
move("ghost_house"); step(35)
trigger("ghost_house"); step(36); trigger("ghost_house"); step(37); trigger("ghost_house")
assert(snapshots[1].stage == "HOLDING")
step(41.1)
assert(snapshots[1].orderIndex == 2 and p:GetAttribute("Coins") == 80)
assert(spectator:GetAttribute("Coins") == 0)
move("giant_house"); step(42); trigger("giant_house")
assert(snapshots[1].orderIndex == 3 and p:GetAttribute("Coins") == 160)
move("fake_1"); step(43); trigger("fake_1")
assert(snapshots[1].phase == "RESULTS" and p:GetAttribute("Coins") == 360)
assert(snapshots[1].successes == 3 and snapshots[1].reward == 360)
trigger("fake_1"); assert(p:GetAttribute("Coins") == 360)
step(58); assert(snapshots[1].phase == "WAITING")
step(78); assert(snapshots[2].participant and snapshots[1].orderTitle:find("거인"))
step(88); move("giant_house"); step(178)
assert(snapshots[1].late and world.destinations.giant_house.prompt.HoldDuration == 3)
trigger("giant_house"); assert(p:GetAttribute("Coins") == 360, "no forged short calming")
step(179); world.destinations.giant_house.prompt.PromptButtonHoldBegan:Fire(p)
step(182.1); trigger("giant_house")
assert(p:GetAttribute("Coins") == 416 and spectator:GetAttribute("Coins") == 56)
assert(snapshots[1].orderIndex == 2)
step(302.2); assert(snapshots[1].orderIndex == 3 and snapshots[1].failures == 1)
step(422.3); assert(snapshots[1].phase == "RESULTS" and snapshots[1].failures == 2)
assert(p:GetAttribute("Coins") == 416, "no all-success bonus for partial round")
stop()
for _, dest in world.destinations do assert(not dest.prompt.Enabled) end
assert(remotes.Snapshot.OnServerInvoke == nil)
print("PASS RoundService integration: three orders, 360 reward, spectator exclusion, next-round rotation, late giant hold, partial timeouts, shutdown (mock signals)")
