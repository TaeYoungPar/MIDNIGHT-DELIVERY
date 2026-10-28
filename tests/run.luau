--!strict
-- 실제 모듈을 실행하되 Roblox 엔진 기능은 검증한 것으로 취급하지 않는다.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Round = require("../src/server/Services/RoundModel")
local Economy = require("../src/server/Services/EconomyService")
local Security = luau.load(fs.readFile("src/server/Services/SecurityService.luau"), {
	environment = { Vector3 = roblox.Vector3 },
})()
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if not ok then error("FAIL " .. name .. ": " .. tostring(err)) end
	passed += 1
	print("PASS " .. name)
end
local settings = { Waiting = 20, Preparing = 10, Playing = 420, Results = 15, MaxPlayers = 4 }
local function playing(ids)
	local model = Round.new(settings)
	model:tick(0, ids); model:tick(20, ids); model:tick(30, ids)
	assert(model.phase == "PLAYING" and model.endsAt == 450)
	return model
end
local function player(id)
	local attributes = {}
	return { UserId = id, SetAttribute = function(_, key, value) attributes[key] = value end,
		GetAttribute = function(_, key) return attributes[key] end }
end
local function livePlayer(id)
	local p = player(id)
	local root = { Position = roblox.Vector3.zero, IsA = function(_, class) return class == "BasePart" end }
	local humanoid = { Health = 100 }
	p.Character = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return humanoid end }
	return p, root, humanoid
end

test("zero players freezes waiting countdown", function()
	local m = Round.new(settings)
	m:tick(50, {}); assert(m.endsAt == 0)
	m:tick(100, {1}); assert(m.endsAt == 120)
	m:tick(110, {}); assert(m.endsAt == 0)
	m:tick(999, {1}); assert(m.endsAt == 1019)
end)
test("20s lobby and 10s preparation boundaries", function()
	local m = Round.new(settings)
	m:tick(0, {1}); m:tick(19.99, {1}); assert(m.phase == "WAITING")
	m:tick(20, {1}); assert(m.phase == "PREPARING")
	m:tick(29.99, {1}); assert(not m.orderActive)
	m:tick(30, {1}); assert(m.orderActive)
end)
test("P1 success rewards participants once and advances next round", function()
	local m = playing({1})
	local result = m:complete(1, 1, 31)
	assert(result and #result == 1 and result[1] == 1)
	assert(m:complete(1, 1, 31) == nil)
	assert(m.phase == "RESULTS" and m.endsAt == 46)
	m:tick(46, {1}); assert(m.phase == "WAITING" and not m.participants[1])
	m:tick(66, {1}); m:tick(76, {1})
	assert(m.roundId == 2 and m:complete(1, 2, 77) ~= nil)
end)
test("simultaneous four-player deliveries resolve once", function()
	local m = playing({1,2,3,4})
	local successes = 0
	for id = 1, 4 do
		local result = m:complete(id, 1, 31)
		if result then successes += 1; assert(#result == 4) end
	end
	assert(successes == 1)
end)
test("late joins and fifth player cannot deliver or receive reward", function()
	local m = playing({1,2,3,4,5})
	assert(m:complete(5, 1, 31) == nil and m:complete(6, 1, 31) == nil)
	local recipients = m:complete(1, 1, 31)
	assert(recipients and #recipients == 4)
end)
test("stale round and early interaction rejected", function()
	local m = Round.new(settings)
	m:tick(0, {1}); assert(m:complete(1, 0, 1) == nil)
	m = playing({1}); assert(m:complete(1, 0, 31) == nil)
end)
test("deadline wins over delivery including exact-time race", function()
	local m = playing({1})
	assert(m:complete(1, 1, 450) == nil)
	m:tick(450, {1}); assert(m.phase == "RESULTS" and not m.orderActive)
	assert(m:complete(1, 1, 450) == nil)
end)
test("disconnect removes recipients and empty team exits", function()
	local m = playing({1,2})
	m:remove(2)
	local recipients = m:complete(1, 1, 31)
	assert(recipients and #recipients == 1 and recipients[1] == 1)
	m = playing({1}); m:remove(1); m:tick(31, {2})
	assert(m.phase == "RESULTS")
end)
test("empty server cancels active round without stale order", function()
	local m = playing({1}); m:tick(40, {})
	assert(m.phase == "WAITING" and not m.orderActive and next(m.participants) == nil)
end)
test("20 rounds do not retain participants or active order", function()
	local m = Round.new(settings)
	local now = 0
	for i = 1, 20 do
		m:tick(now, {i}); now += 20; m:tick(now, {i}); now += 10; m:tick(now, {i})
		assert(m.roundId == i)
		assert(m:complete(i, i, now) ~= nil)
		now += 15; m:tick(now, {i})
		assert(not m.orderActive and next(m.participants) == nil)
	end
end)
test("economy is idempotent within round and rejects old round", function()
	local economy, p = Economy.new(), player(1)
	economy:add(p)
	assert(economy:award(p, 1, 80, 20))
	assert(not economy:award(p, 1, 80, 20))
	assert(economy:award(p, 2, 80, 20))
	assert(not economy:award(p, 1, 80, 20))
	assert(p:GetAttribute("Coins") == 160 and p:GetAttribute("XP") == 40)
end)
test("snapshot spam throttled per player", function()
	local security, p, q = Security.new(), player(1), player(2)
	assert(security:allowSnapshot(p, 0))
	assert(not security:allowSnapshot(p, 0.5))
	assert(security:allowSnapshot(q, 0.5))
	assert(security:allowSnapshot(p, 1))
end)
test("distance, death, cooldown and missing character checks", function()
	local security = Security.new()
	local p, root, humanoid = livePlayer(1)
	security:sample(p, 0); security:sample(p, 3)
	assert(not security:canDeliver(p, roblox.Vector3.new(100,0,0), 12, 3, 0.75))
	assert(security:canDeliver(p, roblox.Vector3.zero, 12, 3, 0.75))
	assert(not security:canDeliver(p, roblox.Vector3.zero, 12, 3.1, 0.75))
	humanoid.Health = 0
	assert(not security:canDeliver(p, roblox.Vector3.zero, 12, 4, 0.75))
	humanoid.Health = 100; p.Character = nil
	assert(not security:canDeliver(p, roblox.Vector3.zero, 12, 4, 0.75))
end)
test("teleport jump delays delivery and respawn requires fresh sample", function()
	local security = Security.new()
	local p, root = livePlayer(1)
	security:sample(p, 0); security:sample(p, 3)
	root.Position = roblox.Vector3.new(100,0,0)
	security:sample(p, 3.1)
	assert(not security:canDeliver(p, root.Position, 12, 3.1, 0.75))
	security:remove(p)
	assert(not security:canDeliver(p, root.Position, 12, 10, 0.75))
end)
print(string.format("%d tests passed (pure Luau / mocked security only; no Roblox engine run)", passed))
