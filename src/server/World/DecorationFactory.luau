--!strict
local P=require(script.Parent.Primitives)
local Factory={}
function Factory.escapePaths(parent: Instance,id: string,origin: Vector3)
	local model=Instance.new("Model");model.Name=id.."_Paths";model.Parent=parent
	-- 건물 양옆 통로를 뒤쪽 연결로 이어 막다른 구석을 줄인다. 실제 추격 동선은 Studio에서 검증한다.
	for _,side in {-1,1}do
		P.part(model,"SidePath",Vector3.new(8,0.12,66),CFrame.new(origin.X+side*24,0.22,origin.Z+2),Color3.fromRGB(72,84,102),Enum.Material.Concrete)
	end
	for _,z in {-25,28}do
		P.part(model,"CrossPath",Vector3.new(56,0.12,8),CFrame.new(origin.X,0.22,origin.Z+z),Color3.fromRGB(72,84,102),Enum.Material.Concrete)
	end
end
function Factory.headquarters(parent: Instance,origin: Vector3)
	local model=Instance.new("Model");model.Name="HeadquartersDetails";model.Parent=parent
	local orange=Color3.fromRGB(255,170,69)
	local frame=CFrame.new(origin)*CFrame.Angles(0,math.pi,0)
	P.sign(model,"영업 중 / NIGHT SHIFT",frame*CFrame.new(-20,9,-21),Vector3.new(16,3,0.4),Color3.fromRGB(99,216,184))
	for x=-12,12,8 do
		P.part(model,"PizzaBox",Vector3.new(5,0.7,4),frame*CFrame.new(x,5.3,8),orange)
	end
	local clerk=Instance.new("Model");clerk.Name="ShopGuide";clerk.Parent=model
	local cf=frame*CFrame.new(22,0,9)
	P.part(clerk,"Apron",Vector3.new(3.5,4,2),cf*CFrame.new(0,5,0),Color3.fromRGB(27,39,64))
	local head=P.part(clerk,"Head",Vector3.new(2.8,2.8,2.8),cf*CFrame.new(0,8.5,0),Color3.fromRGB(245,207,164));head.Shape=Enum.PartType.Ball
	P.part(clerk,"Cap",Vector3.new(3.1,0.5,3.1),cf*CFrame.new(0,10,0),orange)
	for _,x in {-0.6,0.6}do P.part(clerk,"Eye",Vector3.new(0.3,0.4,0.2),cf*CFrame.new(x,8.7,-1.35),Color3.fromRGB(27,39,64))end
	P.sign(clerk,"꾸미기 안내\n상단 메뉴 → 상점",cf*CFrame.new(0,3,-1.2),Vector3.new(10,4,0.3),orange)
	for _,part in clerk:GetDescendants()do if part:IsA("BasePart")then part.CanCollide=false end end
end
return Factory
