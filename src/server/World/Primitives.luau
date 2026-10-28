--!strict
local Primitives = {}

function Primitives.part(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = name, size, frame
	part.Color, part.Material = color, material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Primitives.sign(parent: Instance, text: string, frame: CFrame, size: Vector3, color: Color3): Part
	local part = Primitives.part(parent, "Sign", size, frame, Color3.fromRGB(17, 25, 44))
	local surface = Instance.new("SurfaceGui")
	surface.Face, surface.PixelsPerStud = Enum.NormalId.Front, 36
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.TextColor3, label.TextScaled = text, color, true
	label.Font = Enum.Font.GothamBold
	label.Parent = surface
	return part
end

return Primitives
