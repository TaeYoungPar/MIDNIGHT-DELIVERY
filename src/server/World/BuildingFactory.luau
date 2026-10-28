--!strict
local P = require(script.Parent.Primitives)
local Factory = {}
local navy, orange = Color3.fromRGB(27, 39, 64), Color3.fromRGB(255, 170, 69)

function Factory.house(parent: Instance, id: string, origin: Vector3, color: Color3, style: any?): (Model, Part)
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("DestinationId", id)
	model.Parent = parent
	style = style or {}
	local cf = CFrame.new(origin)
	P.part(model, "Foundation", Vector3.new(38, 1, 32), cf * CFrame.new(0, 0.5, 0), navy)
	P.part(model, "Walls", Vector3.new(32, 19, 26), cf * CFrame.new(0, 10.5, 0), Color3.fromRGB(66, 72, 98))
	P.part(model, "Roof", Vector3.new(39, 4, 34), cf * CFrame.new(0, 22, 0) * CFrame.Angles(0, 0, math.rad(-5)), color)
	local door = P.part(model, "Door", Vector3.new(if id == "giant_house" then 10 else 6, if id == "giant_house" then 15 else 10, 0.6), cf * CFrame.new(0, if id == "giant_house" then 8.5 else 6, -13.5), navy)
	P.part(model, "DoorTrim", Vector3.new(8, 0.4, 0.7), cf * CFrame.new(0, 11.4, -13.7), color, Enum.Material.Neon)
	P.part(model, "Porch", Vector3.new(14, 0.5, 8), cf * CFrame.new(0, 0.7, -17), Color3.fromRGB(102, 104, 123))
	for _, x in { -10, 10 } do
		P.part(model, "Window", Vector3.new(5, 6, 0.4), cf * CFrame.new(x, 11, -13.4), Color3.fromRGB(170, 139, 255), Enum.Material.Neon)
		P.part(model, "WindowBar", Vector3.new(0.35, 6.4, 0.6), cf * CFrame.new(x, 11, -13.7), navy)
	end
	P.part(model, "MailPost", Vector3.new(0.8, 4, 0.8), cf * CFrame.new(11, 2, -23), navy)
	P.part(model, "StarMailbox", Vector3.new(3, 2, 2), cf * CFrame.new(11, 4.5, -23), style.mailboxColor or orange)
	P.sign(model, style.label or (id == "ghost_house" and "01 · 파란 지붕집" or "02 · 거인의 집"), cf * CFrame.new(0, if id == "giant_house" then 18 else 16, -13.6), Vector3.new(17, 3, 0.4), color)
	if style.symbol then
		P.sign(model, style.symbol, cf * CFrame.new(11, 4.5, -24.1), Vector3.new(3, 2, 0.2), Color3.new(1, 1, 1))
	end
	P.part(model, "PorchLamp", Vector3.new(2, 1, 1), cf * CFrame.new(0, 12.5, -14), style.lampColor or orange, Enum.Material.Neon)
	return model, door
end

function Factory.headquarters(parent: Instance, origin: Vector3)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Headquarters", parent
	local cf = CFrame.new(origin) * CFrame.Angles(0, math.pi, 0)
	P.part(model, "Floor", Vector3.new(64, 1, 40), cf * CFrame.new(0, 0.5, 0), navy)
	P.part(model, "BackWall", Vector3.new(64, 20, 2), cf * CFrame.new(0, 11, 19), navy)
	for _, x in { -31, 31 } do
		P.part(model, "SideWall", Vector3.new(2, 20, 40), cf * CFrame.new(x, 11, 0), navy)
	end
	P.part(model, "Roof", Vector3.new(70, 2, 46), cf * CFrame.new(0, 22, 0), navy)
	P.part(model, "NeonAwning", Vector3.new(70, 0.6, 1), cf * CFrame.new(0, 21, -23), orange, Enum.Material.Neon)
	P.part(model, "Counter", Vector3.new(35, 4, 6), cf * CFrame.new(0, 3, 8), Color3.fromRGB(160, 88, 52))
	P.sign(model, "야식 본부 / MIDNIGHT", cf * CFrame.new(0, 17, -21), Vector3.new(54, 6, 0.6), orange)
	P.sign(model, "접수 / 주문카드를 확인하세요", cf * CFrame.new(0, 8, 4.8), Vector3.new(30, 3, 0.5), Color3.fromRGB(99, 216, 232))
	for index = 1, 4 do
		local x = (index - 2.5) * 10
		P.part(model, "ParkingBay", Vector3.new(8, 0.12, 12), cf * CFrame.new(x, 1.1, -10), Color3.fromRGB(48, 62, 83))
	end
end

return Factory
