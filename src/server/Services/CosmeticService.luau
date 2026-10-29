--!strict
local P = require(script.Parent.Parent.World.Primitives)
local Service={}
Service.__index=Service
function Service.new(data,vehicles) return setmetatable({data=data,vehicles=vehicles,bindings={},cache={},stopped=false},Service) end
function Service:apply(player)
	local profile=self.data:profile(player)
	local equipped=if profile then profile.equipped else {}
	self.vehicles:skin(player,equipped.scooter or "")
	local char=player.Character
	local head=char and char:FindFirstChild("Head")
	if not char or not head or not head:IsA("BasePart") then return end
	local signature=(equipped.hat or "")..":"..(equipped.scooter or "")..":"..(equipped.badge or "")
	local cached=self.cache[player]
	if cached and cached.character==char and cached.signature==signature then return end
	self.cache[player]={character=char,signature=signature}
	local previous=char:FindFirstChild("MidnightCosmetics")
	if previous then previous:Destroy() end
	local model=Instance.new("Model")
	model.Name,model.Parent="MidnightCosmetics",char
	local function part(name,size,frame,color,target,material)
		local body=P.part(model,name,size,frame,color,material)
		body.Anchored,body.Massless,body.CanCollide,body.CanTouch,body.CanQuery=false,true,false,false,false
		local weld=Instance.new("WeldConstraint")
		weld.Part0,weld.Part1,weld.Parent=target,body,body
		return body
	end
	if equipped.hat=="neon_cap" then
		local color=Color3.fromRGB(255,170,69)
		part("Cap",Vector3.new(head.Size.X+0.3,0.5,head.Size.Z+0.2),head.CFrame*CFrame.new(0,head.Size.Y/2+0.2,0),color,head)
		part("NeonBrim",Vector3.new(head.Size.X+0.5,0.12,1),head.CFrame*CFrame.new(0,head.Size.Y/2,-0.8),color,head,Enum.Material.Neon)
	end
	if equipped.badge=="ghost_badge" then
		local torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			local body=part("GhostBadge",Vector3.new(0.65,0.8,0.25),torso.CFrame*CFrame.new(-0.5,0.2,-torso.Size.Z/2-0.2),Color3.fromRGB(170,139,255),torso,Enum.Material.Neon)
			body.Shape=Enum.PartType.Ball
			for _,x in {-0.64,-0.36} do
				part("BadgeEye",Vector3.new(0.1,0.15,0.08),torso.CFrame*CFrame.new(x,0.32,-torso.Size.Z/2-0.35),Color3.fromRGB(27,39,64),torso)
			end
		end
	end
end
function Service:add(player)
	self.bindings[player]=player.CharacterAdded:Connect(function(char)
		task.spawn(function()
			char:WaitForChild("Head",10)
			if not self.stopped and self.bindings[player] and player.Character==char then self:apply(player) end
		end)
	end)
	self:apply(player)
end
function Service:remove(player) self.cache[player]=nil;if self.bindings[player] then self.bindings[player]:Disconnect();self.bindings[player]=nil end end
function Service:destroy() self.stopped=true;for player in self.bindings do self:remove(player) end end
return Service
