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
	if name == "Players" or name == "RunService" then return {} end
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
assert(first.spawn.CFrame.LookVector:Dot(r.Vector3.new(0,0,1)) > 0.99, "Spawn must face the road, not headquarters")
assert(not first.prompt.Enabled and math.abs(first.prompt.HoldDuration - 0.6) < 0.001)
assert((first.target - r.Vector3.new(-105, 6, -1.5)).Magnitude < 0.001)
local nav = first.world.Roads.BlueHouseGuide
for _, part in nav:GetDescendants() do
	if part:IsA("BasePart") then assert(not part.CanCollide and not part.CanTouch and not part.CanQuery,"blue-house guide must never block walking, driving, or camera casts") end
end
for _, part in first.world:GetDescendants() do
	if part:IsA("BasePart") and part.Name=="Sign" then assert(not part.CanCollide and not part.CanQuery,"decorative signs are not walls") end
end
local wanted = first.target - nav.ArrowShaft.CFrame.Position
local flat = r.Vector3.new(wanted.X, 0, wanted.Z).Unit
assert(nav.ArrowShaft.CFrame.LookVector:Dot(flat) > 0.99, "3D arrow must point to the actual blue house")
local faces = 0
for _, item in nav:GetDescendants() do if item.ClassName == "SurfaceGui" then faces += 1 end end
assert(faces == 2, "Navigation sign must be readable on both sides")
assert(first.world.Buildings.ghost_house.Roof.Color.B > first.world.Buildings.ghost_house.Roof.Color.G)
local promptCount = 0
for _, destination in first.destinations do
	promptCount += 1
	assert(not destination.prompt.Enabled)
end
assert(promptCount == 5, "Ghost, giant, and three fake houses must have independent prompts")
for id in first.destinations do
	local paths=first.world.Roads:FindFirstChild(id.."_Paths")
	assert(paths and #paths:GetChildren()==4,"Each destination needs both side paths and cross connections")
end
assert(first.world.Buildings:FindFirstChild("convenience_store")and first.world.Lobby.HeadquartersDetails:FindFirstChild("ShopGuide"))
local count = #first.world:GetDescendants()
for _, instance in first.world:GetDescendants() do
	if instance:IsA("BasePart") then assert(instance.Anchored, instance.Name) end
end
local vehicleFactory = loadModule(node("src/server/World/VehicleFactory"))
local scooters = {}
for id = 1, 4 do
	local actor = vehicleFactory.create(first.world.Vehicles, id, r.CFrame.new(id*12,3,-99))
	assert(actor.seat.ClassName == "VehicleSeat" and actor.seat.Anchored and not actor.seat.CanTouch)
	assert(actor.model.PrimaryPart == actor.seat and actor.prompt.MaxActivationDistance == 8)
	assert(not actor.prompt.RequiresLineOfSight,"delivery box must not hide mount prompt")
	assert(actor.model:GetAttribute("OwnerUserId") == 0)
	assert(not actor.seat.CanCollide)
	for _, part in actor.model:GetDescendants() do
		if not part:IsA("BasePart") or part==actor.seat then continue end
		assert(not part.Anchored and part.Massless and not part.CanTouch)
		assert(part.CanCollide==(part.Name=="Body"))
		local weld=part:FindFirstChild("ChassisWeld")
		assert(weld and weld.Part0==actor.seat and weld.Part1==part,"one welded chassis, no independently anchored decorations")
	end
	table.insert(scooters,actor)
end
assert(#first.world.Vehicles:GetChildren() == 4)
local vehicleService=loadModule(node("src/server/Services/VehicleService"))
local cosmeticService=loadModule(node("src/server/Services/CosmeticService"))
local char=r.Instance.new("Model");char.Name="TestAvatar";char.Parent=workspace
local head=r.Instance.new("Part");head.Name="Head";head.Size=r.Vector3.new(2,1,1);head.CFrame=r.CFrame.new(0,5,0);head.Parent=char
local torso=r.Instance.new("Part");torso.Name="UpperTorso";torso.Size=r.Vector3.new(2,2,1);torso.CFrame=r.CFrame.new(0,3,0);torso.Parent=char
local owner={Character=char}
local vehicleRuntime=setmetatable({slots={{owner=owner,actor=scooters[1]}}},vehicleService)
local profile={equipped={hat="neon_cap",badge="ghost_badge",scooter="scooter_mint"}}
local cosmetics=cosmeticService.new({profile=function()return profile end},vehicleRuntime)
cosmetics:apply(owner)
assert(char.MidnightCosmetics:FindFirstChild("Cap")and char.MidnightCosmetics:FindFirstChild("GhostBadge"))
assert(scooters[1].model.Body.Color.G>scooters[1].model.Body.Color.R)
for _,part in char.MidnightCosmetics:GetDescendants()do
	if part:IsA("BasePart")then assert(not part.Anchored and part.Massless and not part.CanCollide and not part.CanQuery)end
end
profile.equipped={hat="",badge="",scooter=""};cosmetics:apply(owner)
assert(#char.MidnightCosmetics:GetChildren()==0 and scooters[1].model.Body.Color.R>scooters[1].model.Body.Color.G)
char:Destroy()
for _, actor in scooters do actor.model:Destroy() end
local monsterFactory = loadModule(node("src/server/World/MonsterFactory"))
for _, kind in { "Ghost", "Giant", "Fake" } do
	local actor = monsterFactory.create(first.world.NPCs, kind, r.Vector3.new(0, 7, 0))
	assert(actor.model.PrimaryPart == actor.root and not actor.root.Anchored)
	assert(actor.humanoid.RequiresNeck == false and actor.humanoid.WalkSpeed > 0)
	local parts, welds = 0, 0
	for _, instance in actor.model:GetDescendants() do
		if instance:IsA("BasePart") then parts += 1; assert(not instance.Anchored)
		elseif instance.ClassName == "WeldConstraint" then welds += 1 end
	end
	assert(welds == parts - 1, "Every monster part must belong to one welded assembly")
	actor.model:Destroy()
end
local second = builder.build()
local boundary = loadModule(node("src/server/Services/LobbyBoundary")).new(second.world)
boundary:setOpen(false)
assert(#boundary.walls==4)
for _,wall in boundary.walls do assert(wall.CanCollide and wall.CanQuery) end
local lobbyRoot={Position=r.Vector3.new(0,5,-119)}
local lobbyPlayer={Character={PivotTo=function(_,frame)lobbyRoot.Position=frame.Position end}}
local resets,authorized=0,0
local stateAccess={root=function()return lobbyRoot end}
local vehicleAccess={reset=function(_,_,manual)assert(not manual);resets+=1 end}
local function allow()authorized+=1 end
assert(not boundary:enforce(lobbyPlayer,stateAccess,vehicleAccess,allow))
lobbyRoot.Position=r.Vector3.new(80,5,-119)
assert(boundary:enforce(lobbyPlayer,stateAccess,vehicleAccess,allow) and resets==1 and authorized==1)
assert(lobbyRoot.Position.Z==-119 and lobbyRoot.AssemblyLinearVelocity==r.Vector3.zero)
lobbyRoot.Position=r.Vector3.new(0,40,-119)
assert(boundary:enforce(lobbyPlayer,stateAccess,vehicleAccess,allow),"jumping over the gate cannot bypass containment")
boundary:setOpen(true)
for _,wall in boundary.walls do assert(not wall.CanCollide and not wall.CanQuery and wall.Transparency==1) end
boundary:destroy()
assert(first.world.Parent == nil and second.world.Parent == workspace)
assert(#second.world:GetDescendants() == count)
assert(#workspace:GetChildren() == 1)
assert(#lighting:GetChildren() == 1)
assert(math.abs(lighting.ClockTime - 0.7) < 0.001)
second.world:SetAttribute("MidnightGenerated", false)
local ok = pcall(builder.build)
assert(not ok and second.world.Parent == workspace, "Must preserve unowned world")
print(string.format("PASS world generation, %d descendants; repeat build and unowned-world protection (data model only)", count))
