--!strict
local P = require(script.Parent.Primitives)
local Factory = {}

function Factory.create(parent: Instance, kind: string, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Midnight" .. kind
	local giant, house = kind == "Giant", kind == "Fake"
	local color = if giant then Color3.fromRGB(255, 175, 90) elseif house then Color3.fromRGB(156, 112, 207) else Color3.fromRGB(130, 215, 255)
	local root = P.part(model, "HumanoidRootPart", Vector3.new(3, 4, 3), CFrame.new(position), color)
	root.Transparency, root.CanCollide = 1, false
	local body = P.part(model, "Torso", if giant then Vector3.new(7, 8, 5) elseif house then Vector3.new(7, 6, 6) else Vector3.new(4, 5, 4), CFrame.new(position), color)
	body.CanCollide = true
	if not giant and not house then body.Shape, body.Transparency = Enum.PartType.Ball, 0.2 end
	local head = P.part(model, "Head", Vector3.new(4, 3, 3), CFrame.new(position + Vector3.new(0, 4.5, 0)), color)
	head.Shape = Enum.PartType.Ball
	for _, x in { -0.9, 0.9 } do
		local eye = P.part(model, "Eye", Vector3.new(0.6, 0.8, 0.35), CFrame.new(position + Vector3.new(x, 4.8, -1.5)), Color3.fromRGB(27, 39, 64), Enum.Material.Neon)
		eye.CanCollide = false
	end
	P.part(model, "Smile", Vector3.new(1.7, 0.25, 0.3), CFrame.new(position + Vector3.new(0, 3.8, -1.5)), Color3.fromRGB(27, 39, 64))
	if house then
		P.part(model, "Roof", Vector3.new(9, 2, 8), CFrame.new(position + Vector3.new(0, 3.5, 0)), Color3.fromRGB(80, 60, 122))
		for _, x in { -2, 2 } do P.part(model, "Foot", Vector3.new(2.4, 1.5, 4), CFrame.new(position + Vector3.new(x, -3.5, 0)), color) end
	elseif giant then
		for _, x in { -4.5, 4.5 } do P.part(model, "Arm", Vector3.new(2, 6, 2), CFrame.new(position + Vector3.new(x, 0, 0)), color) end
	else
		for _, x in { -1.4, 0, 1.4 } do
			P.part(model, "GhostTail", Vector3.new(1.2, 2, 1.5), CFrame.new(position + Vector3.new(x, -2.3, 0)), color)
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath, humanoid.DisplayDistanceType = false, false, Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed, humanoid.HipHeight, humanoid.Parent = if giant then 19 else 20, if giant or house then 3 else 2, model
	model.PrimaryPart = root
	-- 모든 장식은 한 물리 어셈블리에 용접한다. 외부 리그/애니메이션 ID에 의존하지 않는다.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanTouch = false, false
			if part ~= root then
				part.Massless = true
				if part ~= body then part.CanCollide = false end
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = root, part, root
			end
		end
	end
	model.Parent = parent
	return { model = model, root = root, humanoid = humanoid }
end
return Factory
