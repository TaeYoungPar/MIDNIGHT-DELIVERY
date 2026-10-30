--!strict
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local count = 0
local function test(name, run)
	local ok, err = pcall(run); assert(ok, name .. ": " .. tostring(err)); count += 1; print("PASS " .. name)
end
local function setup()
	local clock, pathCalls, downCalls = 0, 0, 0
	local allowed, blocked, failure = true, false, false
	local tasks, actors = {}, {}
	local target = {UserId = 1, Character = {}, root = {Position = r.Vector3.new(40,7,0),CFrame=r.CFrame.new(40,7,0)}}
	local config = luau.load(fs.readFile("src/shared/Config.luau"), {environment = {Vector3 = r.Vector3}})()
	local states = {canChase = function() return allowed end, root = function() return target.root end,
		down = function() downCalls += 1; allowed = false; return true end}
	local factory = {create = function(parent, _, position)
		local actor = {model = {Parent = parent}, root = {Position = position, SetNetworkOwner = function(_, owner) assert(owner == nil) end},
			humanoid = {Health = 100,WalkSpeed=20, MoveTo = function(self, pos) self.goal = pos end}}
		actor.model.Destroy = function(self) self.Parent = nil end
		table.insert(actors, actor); return actor
	end}
	local paths = {CreatePath = function()
		pathCalls += 1
		return {Status = r.Enum.PathStatus.Success,
			ComputeAsync = function() if failure then error("path unavailable") end end,
			GetWaypoints = function() return {{Position = r.Vector3.new(0,7,0)}, {Position = r.Vector3.new(20,7,0), Action = r.Enum.PathWaypointAction.Walk}} end}
	end}
	local service = luau.load(fs.readFile("src/server/Services/MonsterService.luau"), {environment = {
		game = {GetService = function(_, name) return if name == "PathfindingService" then paths else {Shared = {Config = "config"}} end},
		script = {Parent = {Parent = {World = {MonsterFactory = "factory"}}}},
		require = function(name) return if name == "config" then config else factory end,
		Vector3 = r.Vector3, CFrame=r.CFrame, Enum = r.Enum, RaycastParams = {new = function() return {} end}, OverlapParams={new=function()return{}end},
		workspace = {GetServerTimeNow = function() return clock end, GetPartBoundsInBox=function()return{}end, Raycast = function(_, origin, direction)
			if direction.Y == -60 then return {Position=r.Vector3.new(origin.X,0,origin.Z),Normal=r.Vector3.yAxis} end
			return if blocked then {Instance = {IsDescendantOf = function() return false end}} else nil
		end}, task = {spawn = function(fn) table.insert(tasks, fn) end},
	} })().new({}, states, function() end)
	return {s = service, target = target, actors = actors,
		time = function(v) clock = v end, block = function(v) blocked = v end, allow = function(v) allowed = v end,
		fail = function(v) failure = v end,
		runTasks = function() local todo = tasks; tasks = {}; for _, fn in todo do fn() end end,
		pathCount = function() return pathCalls end, downCount = function() return downCalls end}
end

test("single active monster replaces previous and expires by customer duration", function()
	local f = setup(); f.s:start("Ghost", f.target, r.Vector3.zero)
	assert(f.s:status().endsAt == 11)
	f.s:start("Giant", f.target, r.Vector3.zero); assert(f.actors[1].model.Parent == nil)
	assert(f.s:status().endsAt == 13)
	f.time(13); f.s:tick(); assert(f.s.active == nil)
	f.s:start("Fake", f.target, r.Vector3.zero); assert(f.s:status().endsAt == 22); f.s:destroy()
end)
test("catch is server-only, wall-protected and idempotent", function()
	local f = setup(); f.s:start("Ghost", f.target, r.Vector3.zero)
	f.time(1);f.target.root.Position = f.actors[1].root.Position
	f.block(true); f.s:tick(); assert(f.downCount() == 0)
	f.block(false); f.s:tick(); f.s:tick()
	assert(f.downCount() == 1 and f.s.active == nil)
end)
test("immunity, departure and character replacement cancel chase", function()
	local f = setup(); f.allow(false); f.s:start("Ghost", f.target, r.Vector3.zero); assert(#f.actors == 0)
	f.allow(true); f.s:start("Ghost", f.target, r.Vector3.zero); f.target.Character = {}; f.s:tick(); assert(f.s.active == nil)
	f.s:start("Ghost", f.target, r.Vector3.zero); f.allow(false); f.s:tick(); assert(f.s.active == nil)
end)
test("path requests are bounded and late async results cannot mutate replacement", function()
	local f = setup(); f.s:start("Ghost", f.target, r.Vector3.zero)
	f.time(1);f.s:tick(); f.s:tick(); f.runTasks(); assert(f.pathCount() == 1)
	f.time(1); f.s:tick(); assert(f.pathCount() == 1)
	f.time(3); f.s:tick(); local old = f.s.active
	f.s:start("Fake", f.target, r.Vector3.zero); local replacement = f.s.active
	f.runTasks(); assert(f.s.active == replacement and replacement ~= old and #replacement.waypoints == 0)
	f.s:destroy()
end)
test("path failure preserves colliding MoveTo fallback and retries", function()
	local f = setup(); f.fail(true); f.s:start("Ghost", f.target, r.Vector3.zero)
	f.time(1);f.s:tick(); f.runTasks(); f.s:tick()
	assert(not f.s.active.busy and f.actors[1].humanoid.goal == f.target.root.Position)
	f.time(3); f.s:tick(); f.runTasks(); assert(f.pathCount() == 2); f.s:destroy()
end)
test("stop cancels pending async path and fallen NPC is removed", function()
	local f = setup(); f.s:start("Ghost", f.target, r.Vector3.zero); f.s:tick(); f.s:stop(); f.runTasks(); assert(f.s.active == nil)
	f.s:start("Fake", f.target, r.Vector3.zero); f.actors[2].root.Position = r.Vector3.new(0,-100,0); f.s:tick(); assert(f.s.active == nil)
end)
test("monster reveals ahead at a safe distance before moving or catching",function()
	local f=setup();f.s:start("Ghost",f.target,r.Vector3.zero)
	local actor=f.actors[1]
	assert((actor.root.Position-f.target.root.Position).Magnitude>=24 and actor.root.Position.Z<0)
	assert(actor.humanoid.WalkSpeed==0)
	f.target.root.Position=actor.root.Position;f.s:tick();assert(f.downCount()==0 and f.pathCount()==0)
	f.time(1);f.s:tick();assert(f.downCount()==1)
	local blocked=setup();blocked.block(true);blocked.s:start("Ghost",blocked.target,r.Vector3.zero)
	assert(#blocked.actors==0,"never force a spawn inside an occluded location")
end)
print(string.format("%d MonsterService tests passed (mocked pathfinding/physics; not Studio)",count))
