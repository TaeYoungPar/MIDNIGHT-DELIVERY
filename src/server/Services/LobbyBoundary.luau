--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Boundary = {}
Boundary.__index = Boundary

function Boundary.new(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "DepartureBoundary", parent
	local walls, lines = {}, {}
	local b = Config.Lobby
	local width, depth = b.MaxX-b.MinX, b.MaxZ-b.MinZ
	for _, side in {
		{Vector3.new(width,30,1),Vector3.new(0,15,b.MinZ)},
		{Vector3.new(width,30,1),Vector3.new(0,15,b.MaxZ)},
		{Vector3.new(1,30,depth),Vector3.new(b.MinX,15,(b.MinZ+b.MaxZ)/2)},
		{Vector3.new(1,30,depth),Vector3.new(b.MaxX,15,(b.MinZ+b.MaxZ)/2)},
	} do
		local wall = Instance.new("Part")
		wall.Name, wall.Size, wall.Position = "DepartureGate", side[1], side[2]
		wall.Anchored, wall.CanTouch, wall.Material = true, false, Enum.Material.ForceField
		wall.Color, wall.Transparency, wall.Parent = Color3.fromRGB(255,170,69), 0.7, folder
		table.insert(walls,wall)
		local line = Instance.new("Part")
		line.Name, line.Size = "DepartureLine", Vector3.new(side[1].X,0.15,side[1].Z)
		line.Position = Vector3.new(side[2].X,0.4,side[2].Z)
		line.Anchored, line.CanCollide, line.CanTouch, line.CanQuery = true, false, false, false
		line.Material, line.Color, line.Parent = Enum.Material.Neon, wall.Color, folder
		table.insert(lines,line)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.Parent = Enum.NormalId.Front, walls[2]
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1,1), 1
	label.Text, label.TextScaled, label.TextColor3 = "출발선 · 배달 시작 후 개방", true, Color3.fromRGB(255,230,180)
	label.Parent = gui
	return setmetatable({folder=folder,walls=walls,lines=lines,caption=gui},Boundary)
end

function Boundary.setOpen(self, open: boolean)
	self.folder:SetAttribute("Open",open)
	self.caption.Enabled = not open
	for _, wall in self.walls do
		wall.CanCollide, wall.CanQuery, wall.Transparency = not open, not open, if open then 1 else 0.7
	end
	for _, line in self.lines do line.Color = if open then Color3.fromRGB(99,216,184) else Color3.fromRGB(255,170,69) end
end

-- 도보/차량/점프/우회로 선을 넘더라도 서버에서 복귀시킨다. 클라이언트 벽 표시에 의존하지 않는다.
function Boundary.enforce(self, player, states, vehicles, authorize): boolean
	local root = states:root(player)
	if not root or not player.Character then return false end
	local p, b = root.Position, Config.Lobby
	if p.X >= b.MinX+2 and p.X <= b.MaxX-2 and p.Z >= b.MinZ+2 and p.Z <= b.MaxZ-2 and p.Y >= -10 and p.Y <= 30 then return false end
	vehicles:reset(player,false)
	player.Character:PivotTo(CFrame.new(Config.Map.Spawn+Vector3.new(0,4,0))*CFrame.Angles(0,math.pi,0))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	authorize(player)
	return true
end
function Boundary.destroy(self) self.folder:Destroy() end
return Boundary
