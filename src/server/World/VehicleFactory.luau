--!strict
local P = require(script.Parent.Primitives)
local Factory = {}
function Factory.create(parent: Instance, id: number, frame: CFrame)
	local model = Instance.new("Model")
	model.Name = "Scooter" .. id
	model:SetAttribute("VehicleId", id)
	model:SetAttribute("OwnerUserId", 0)
	local orange = Color3.fromRGB(255, 170, 69)
	local navy = Color3.fromRGB(27, 39, 64)
	local seat = Instance.new("VehicleSeat")
	seat.Name, seat.Size, seat.CFrame = "DriverSeat", Vector3.new(2.2, 0.8, 2.2), frame
	seat.Anchored, seat.CanTouch, seat.HeadsUpDisplay = true, false, false
	seat.Color, seat.Parent = navy, model
	P.part(model, "Body", Vector3.new(3, 1.3, 6), frame * CFrame.new(0,-0.7,0), orange)
	P.part(model, "Deck", Vector3.new(3.4,0.35,4), frame * CFrame.new(0,-1,-0.5), navy)
	P.part(model, "Stem", Vector3.new(0.4,2.3,0.4), frame * CFrame.new(0,0.6,-2), navy)
	P.part(model, "Handlebar", Vector3.new(4.3,0.4,0.4), frame * CFrame.new(0,1.7,-2), navy)
	for _, z in {-2.5,2.5} do
		local wheel = P.part(model, "Wheel", Vector3.new(1,2.6,2.6), frame * CFrame.new(0,-1.4,z), Color3.fromRGB(20,23,31))
		wheel.Shape = Enum.PartType.Cylinder
	end
	local lamp = P.part(model, "Headlight", Vector3.new(1.5,1.5,0.7), frame * CFrame.new(0,0.4,-3.1), Color3.fromRGB(255,239,180), Enum.Material.Neon)
	lamp.Shape = Enum.PartType.Ball
	P.part(model, "DeliveryBox", Vector3.new(3.5,2.8,2.6), frame * CFrame.new(0,1.1,2.1), navy)
	P.sign(model, "야식 / " .. id, frame * CFrame.new(0,1.3,3.45) * CFrame.Angles(0,math.pi,0), Vector3.new(3.2,1.5,0.2), orange)
	local attach = Instance.new("Attachment")
	attach.Position, attach.Parent = Vector3.new(0,1.5,-1), seat
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText, prompt.HoldDuration = "스쿠터 탑승", "배달 스쿠터 " .. id, 0.3
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = 8, true, attach
	model.PrimaryPart, model.Parent = seat, parent
	return { model = model, seat = seat, prompt = prompt }
end
return Factory
