--!strict
local P = require(script.Parent.Primitives)
local Navigation = {}

function Navigation.create(parent: Instance, name: string, position: Vector3, target: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	local flat = Vector3.new(target.X, position.Y, target.Z)
	-- 문자 화살표는 보는 면에 따라 반대로 보인다. 실제 목적지 방향의 3D 화살표를 만든다.
	local delta = flat - position
	local yaw = math.atan2(-delta.X, -delta.Z)
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	model:SetAttribute("TargetPosition", target)
	local shaft = P.part(model, "ArrowShaft", Vector3.new(0.7, 0.2, 8), frame, color, Enum.Material.Neon)
	shaft.CanCollide = false
	for _, side in { -1, 1 } do
		local head = P.part(model, "ArrowHead", Vector3.new(0.7, 0.2, 4), frame * CFrame.new(side * 1.2, 0, -3) * CFrame.Angles(0, side * math.rad(40), 0), color, Enum.Material.Neon)
		head.CanCollide = false
	end
	P.sign(model, "01 · 파란 지붕집", CFrame.new(position + Vector3.new(0, 6, 0)), Vector3.new(22, 4, 0.6), color, true)
	return model
end
return Navigation
