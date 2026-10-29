--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalogs)
local Profile = require(script.Parent.ProfileModel)
local Service = {}
Service.__index=Service
function Service.new(data,apply) return setmetatable({data=data,apply=apply,last={}},Service) end
function Service:action(player,kind,id,enabled): (boolean,string)
	if typeof(id)~="string" or #id>64 or (kind=="EquipCosmetic" and typeof(enabled)~="boolean") then return false,"잘못된 요청입니다" end
	if not self.data:canShop(player) then return false,"저장 연결이 준비되지 않아 상점이 잠겼습니다" end
	local now=workspace:GetServerTimeNow()
	if now-(self.last[player] or -math.huge)<0.4 then return false,"잠시 후 다시 눌러주세요" end
	self.last[player]=now
	local item=nil
	for _,entry in Catalog do if entry.id==id then item=entry;break end end
	if not item then return false,"없는 상품입니다" end
	local profile=self.data:profile(player)
	if not profile then return false,"프로필 로딩 중입니다" end
	local ok,message
	if kind=="PurchaseWithCoins" then ok,message=Profile.purchase(profile,item)
	elseif kind=="EquipCosmetic" then ok,message=Profile.equip(profile,item,enabled)
	else return false,"허용되지 않은 요청입니다" end
	if ok then self.data:touch(player);self.data:queueSave(player);self.apply(player) end
	return ok,message
end
function Service:remove(player) self.last[player]=nil end
return Service
