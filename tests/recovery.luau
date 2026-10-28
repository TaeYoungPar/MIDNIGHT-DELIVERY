--!strict
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Model = require("../src/server/Services/PlayerStateModel")
local tests = 0
local function test(name, run)
	local ok, err = pcall(run); assert(ok, name .. ": " .. tostring(err))
	tests += 1; print("PASS " .. name)
end
local function signal()
	local handlers = {}
	return { Connect = function(_, fn) local key = {}; handlers[key] = fn; return { Disconnect = function() handlers[key] = nil end } end,
		Fire = function(_, ...) for _, fn in handlers do fn(...) end end }
end
local clock, occluded = 0, false
local prompts = {}
local config = luau.load(fs.readFile("src/shared/Config.luau"), { environment = {Vector3 = r.Vector3} })()
local module = luau.load(fs.readFile("src/server/Services/PlayerStateService.luau"), { environment = {
	game = {GetService = function(_, name) if name == "ReplicatedStorage" then return {Shared = {Config = "config"}} end; return {} end},
	script = {Parent = {PlayerStateModel = "model"}}, require = function(name) return if name == "config" then config else Model end,
	workspace = {GetServerTimeNow = function() return clock end, Raycast = function() return if occluded then {} else nil end},
	Vector3 = r.Vector3, CFrame = r.CFrame, Enum = r.Enum, RaycastParams = {new = function() return {} end},
	task = {spawn = function(fn) fn() end},
	Instance = {new = function(class)
		local instance = { Destroy = function(self) self.Parent = nil end }
		if class == "ProximityPrompt" then
			instance.PromptButtonHoldBegan, instance.PromptButtonHoldEnded, instance.Triggered = signal(), signal(), signal()
			table.insert(prompts, instance)
		end
		return instance
	end},
} })()
local function makePlayer(id)
	local root = {Position = r.Vector3.new(0,4,-105), Parent = true, Anchored = false, IsA = function() return true end}
	local humanoid = {Health = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, AutoRotate = true, Parent = true, IsA = function() return true end}
	local p = {UserId = id, DisplayName = "Tester" .. id, CharacterAdded = signal(), root = root, humanoid = humanoid}
	p.Character = {
		WaitForChild = function(_, name) return if name == "HumanoidRootPart" then root else humanoid end,
		FindFirstChild = function() return root end, FindFirstChildOfClass = function() return humanoid end,
		SetAttribute = function() end, PivotTo = function(_, cf) root.Position = cf.Position; root.frame = cf end,
	}
	return p
end
local function setup()
	clock, occluded = 0, false; table.clear(prompts)
	local service = module.new({CFrame = r.CFrame.new(0,1,-119) * r.CFrame.Angles(0,math.pi,0)}, function(p) return p.UserId <= 3 end, function() end)
	local a, b, spectator = makePlayer(1), makePlayer(2), makePlayer(4)
	service:add(a); service:add(b); service:add(spectator)
	clock = 5
	return service, a, b, spectator
end

test("state model rejects immunity and duplicate down/recovery generations", function()
	local m = Model.new(12,4); m:reset(1,0)
	assert(not m:down(1,3)); assert(m:down(1,4)); assert(not m:down(1,5))
	local generation = m.entries[1].generation
	assert(not m:canAct(1) and m.entries[1].downUntil == 16)
	assert(m:recover(1,generation,16) and not m:recover(1,generation,16))
	assert(not m:down(1,19.9) and m:down(1,20))
	m:reset(1,21); assert(not m:recover(1,generation,22))
	m:remove(1); assert(not m:canAct(1))
end)
test("spawn faces +Z and down immobilizes without killing", function()
	local s,a = setup()
	assert(a.root.frame.LookVector:Dot(r.Vector3.new(0,0,1)) > 0.99)
	assert(s:down(a) and not s:down(a))
	assert(a.root.Anchored and a.humanoid.WalkSpeed == 0 and a.humanoid.Health == 100)
	assert(not s:canAct(a)); s:destroy(); assert(not a.root.Anchored and a.humanoid.WalkSpeed == 16)
end)
test("solo twelve-second recovery returns to checkpoint with four-second protection", function()
	local s,a = setup(); s:down(a)
	clock = 16.99; s:tick(); assert(not s:canAct(a))
	clock = 17; s:tick(); assert(s:canAct(a) and not a.root.Anchored)
	assert((a.root.Position - config.Recovery.Checkpoints[1]).Magnitude < 0.1)
	assert(not s:canChase(a)); clock = 21; assert(s:canChase(a)); s:destroy()
end)
test("rescue validates participant, self, distance, wall and held time", function()
	local s,a,b,spectator = setup(); s:down(a)
	local prompt = prompts[#prompts]
	prompt.PromptButtonHoldBegan:Fire(a); assert(s.rescuers[a] == nil)
	prompt.PromptButtonHoldBegan:Fire(spectator); assert(s.rescuers[spectator] == nil)
	b.root.Position = a.root.Position + r.Vector3.new(100,0,0)
	prompt.PromptButtonHoldBegan:Fire(b); assert(s.rescuers[b] == nil)
	b.root.Position = a.root.Position + r.Vector3.new(2,0,0)
	occluded = true; prompt.PromptButtonHoldBegan:Fire(b); assert(s.rescuers[b] == nil)
	occluded = false; prompt.PromptButtonHoldBegan:Fire(b)
	clock = 7; prompt.Triggered:Fire(b); assert(not s:canAct(a))
	clock = 8; prompt.Triggered:Fire(b); assert(s:canAct(a) and not a.root.Anchored)
	prompt.Triggered:Fire(b); assert(s:canAct(a)); s:destroy()
end)
test("rescue is cancelled by release or range break", function()
	local s,a,b = setup(); s:down(a); local prompt = prompts[#prompts]
	prompt.PromptButtonHoldBegan:Fire(b); clock = 6; prompt.PromptButtonHoldEnded:Fire(b)
	clock = 8; s:tick(); prompt.Triggered:Fire(b); assert(not s:canAct(a))
	prompt.PromptButtonHoldBegan:Fire(b); b.root.Position += r.Vector3.new(100,0,0); s:tick()
	b.root.Position = a.root.Position; clock = 11; prompt.Triggered:Fire(b); assert(not s:canAct(a)); s:destroy()
end)
test("automatic recovery wins at deadline; old rescue cannot revive new down", function()
	local s,a,b = setup(); s:down(a); local old = prompts[#prompts]
	clock = 14; old.PromptButtonHoldBegan:Fire(b)
	clock = 17; s:tick(); old.Triggered:Fire(b); assert(s:canAct(a))
	clock = 21; s:down(a); old.Triggered:Fire(b); assert(not s:canAct(a)); s:destroy()
end)
test("respawn, round cleanup and departure remove locks/prompts", function()
	local s,a,b = setup(); s:down(a)
	s:spawnCharacter(a, a.Character); assert(s:canAct(a) and not a.root.Anchored)
	clock = 10; s:down(a); s:clearRound(); assert(s:canAct(a))
	clock = 15; s:down(b); s:remove(b); assert(not b.root.Anchored and s.model.entries[b.UserId] == nil)
	s:destroy(); assert(next(s.bindings) == nil and next(s.downed) == nil)
end)
print(string.format("%d recovery tests passed (model and mocked engine signals; not Studio)", tests))
