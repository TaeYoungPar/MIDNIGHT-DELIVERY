--!strict
-- Lune의 Roblox 데이터 모델로 실제 생성 코드를 실행한다. 물리/렌더링/복제 테스트는 아니다.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local nodes, cache = {}, {}
local function node(path)
	if nodes[path] then return nodes[path] end
	local n = { path = path }
	nodes[path] = n
	local parentPath = string.match(path, "^(.*)/[^/]+$")
	if parentPath then n.Parent = node(parentPath) end
	return setmetatable(n, { __index = function(_, key) return node(path .. "/" .. key) end })
end
local workspace = r.Instance.new("Workspace")
local lighting = r.Instance.new("Lighting")
local replicated = { Shared = node("src/shared") }
local game = { GetService = function(_, name)
	if name == "Lighting" then return lighting end
	if name == "ReplicatedStorage" then return replicated end
	error("Unexpected service " .. name)
end }
local function loadModule(n)
	if cache[n.path] then return cache[n.path] end
	local result = luau.load(fs.readFile(n.path .. ".luau"), { debugName = n.path, environment = {
		script = n, require = loadModule, game = game, workspace = workspace,
		Instance = r.Instance, Vector3 = r.Vector3, CFrame = r.CFrame, Color3 = r.Color3, Enum = r.Enum,
		UDim2 = r.UDim2,
		Random = { new = function(seed)
			-- 지도 생성 분기 실행용 결정론 난수 대역. Roblox Random 자체는 검증하지 않는다.
			return { NextNumber = function(_, lo, hi)
				seed = (seed * 16807) % 2147483647
				return lo + (hi - lo) * seed / 2147483647
			end }
		end },
	} })()
	cache[n.path] = result
	return result
end
local builder = loadModule(node("src/server/World/WorldBuilder"))
local first = builder.build()
assert(first.spawn.ClassName == "SpawnLocation" and first.spawn.Neutral)
assert(not first.prompt.Enabled and math.abs(first.prompt.HoldDuration - 0.6) < 0.001)
assert((first.target - r.Vector3.new(-105, 6, -1.5)).Magnitude < 0.001)
local count = #first.world:GetDescendants()
for _, instance in first.world:GetDescendants() do
	if instance:IsA("BasePart") then assert(instance.Anchored, instance.Name) end
end
local second = builder.build()
assert(first.world.Parent == nil and second.world.Parent == workspace)
assert(#second.world:GetDescendants() == count)
assert(#workspace:GetChildren() == 1)
assert(#lighting:GetChildren() == 1)
assert(math.abs(lighting.ClockTime - 0.7) < 0.001)
second.world:SetAttribute("MidnightGenerated", false)
local ok = pcall(builder.build)
assert(not ok and second.world.Parent == workspace, "Must preserve unowned world")
print(string.format("PASS world generation, %d descendants; repeat build and unowned-world protection (data model only)", count))
