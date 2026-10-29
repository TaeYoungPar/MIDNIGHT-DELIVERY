--!strict
local Model = require(script.Parent.ProfileModel)
local ProfileStore = require(script.Parent.ProfileStore)
local Service = {}
Service.__index = Service
function Service.new(economy, changed)
	local DataStores = game:GetService("DataStoreService")
	local Http = game:GetService("HttpService")
	local Run = game:GetService("RunService")
	local name = if Run:IsStudio() then "MidnightDelivery_Studio_PlayerData_v1" else "MidnightDelivery_Live_PlayerData_v1"
	local adapter = nil
	if game.GameId ~= 0 then
		local ok,value = pcall(function() return DataStores:GetDataStore(name) end)
		if ok then adapter=value end
	end
	print("[MidnightDelivery] Data namespace=" .. name .. (if adapter then "" else " (session only; unpublished/unavailable)"))
	return setmetatable({economy=economy,changed=changed,adapter=adapter,http=Http,handles={},stopped=false},Service)
end
function Service:sync(player, handle)
	if self.handles[player] ~= handle or handle.closing then return end
	player:SetAttribute("Coins",handle.profile.coins)
	player:SetAttribute("XP",handle.profile.xp)
	player:SetAttribute("Level",Model.level(handle.profile.xp))
	self.changed(player)
end
function Service:begin(player)
	local placeholder = {profile=Model.default(),mode="LOADING",reason="",expiresAt=0,version=0,dirty=false,busy=false,closing=false,loading=true}
	self.handles[player]=placeholder
	self.economy.profiles[player.UserId]=placeholder.profile
	self:sync(player,placeholder)
	task.spawn(function()
		local store = if self.adapter then ProfileStore.new(self.adapter,os.time,task.wait,self.http:GenerateGUID(false)) else nil
		placeholder.store=store
		local loaded = if store then store:load(player.UserId) else {profile=Model.default(),mode="SESSION",reason="unpublished_or_unavailable",expiresAt=0,version=0,dirty=false,busy=false}
		-- 퇴장 중 로드가 끝나도 새 Player의 메모리 프로필을 덮지 않는다.
		for _,key in {"profile","mode","reason","expiresAt","version","dirty","busy"} do placeholder[key]=loaded[key] end
		placeholder.loading=false
		if loaded.mode=="SESSION" then warn("[MidnightDelivery] Profile session-only: user="..player.UserId.." reason="..tostring(loaded.reason)) end
		placeholder.nextSave=os.clock()+60+(player.UserId%15)
		if placeholder.closing or self.stopped then self:close(player,placeholder);return end
		if self.handles[player]~=placeholder then return end
		self.economy.profiles[player.UserId]=placeholder.profile
		self:sync(player,placeholder)
	end)
end
function Service:loaded(player): boolean
	local h=self.handles[player]
	return h~=nil and not h.loading and not h.closing
end
function Service:canEarn(player): boolean
	local h=self.handles[player]
	if not h or h.loading or h.closing then return false end
	if h.store then h.store:writable(h) end
	return true
end
function Service:canShop(player): boolean
	local h=self.handles[player]
	return h~=nil and h.store~=nil and h.mode=="READY" and h.store:writable(h) and not h.closing
end
function Service:profile(player)
	local h=self.handles[player]
	return if h then h.profile else nil
end
function Service:status(player)
	local h=self.handles[player]
	if not h then return {mode="LOADING",reason="",dirty=false} end
	return {mode=if h.busy then "SAVING" else h.mode,reason=h.reason,dirty=h.dirty}
end
function Service:touch(player)
	local h=self.handles[player]
	if not h or h.closing then return end
	h.version+=1
	if h.mode=="READY" or h.mode=="SAVE_ERROR" then h.dirty=true end
	self:sync(player,h)
end
function Service:queueSave(player)
	local h=self.handles[player]
	if h then h.nextSave=math.min(h.nextSave or math.huge,os.clock()+5) end
end
function Service:tick()
	for player,h in self.handles do
		if not h.loading and not h.closing and h.store and not h.busy and os.clock()>=(h.nextSave or math.huge)
			and (h.mode=="READY" or h.mode=="SAVE_ERROR") then
			h.nextSave=os.clock()+60+(player.UserId%15)
			task.spawn(function()
				local ok=h.store:save(player.UserId,h,false)
				if not ok then warn("[MidnightDelivery] Profile save not confirmed: user="..player.UserId.." reason="..h.reason) end
				self:sync(player,h)
			end)
		end
	end
end
function Service:close(player,h)
	if h.closeBusy or h.closed then return end
	h.closeBusy,h.closing=true,true
	local deadline=os.clock()+25
	while (h.loading or h.busy) and os.clock()<deadline do task.wait(0.1) end
	local neededSave=h.loading or h.mode=="READY" or h.mode=="SAVE_ERROR"
	local ok=h.mode=="SESSION"
	if not h.loading and not h.busy and h.store then ok=h.store:save(player.UserId,h,true) end
	if not ok and neededSave then warn("[MidnightDelivery] Closing profile not confirmed; user="..player.UserId) end
	h.closeBusy,h.closed=false,true
	-- 로드 요청이 25초 뒤에 끝나면 begin의 닫기 경로가 임대 해제를 다시 시도한다.
	if h.loading then h.closed=false;return end
	if self.handles[player]==h then self.handles[player]=nil end
end
function Service:remove(player)
	local h=self.handles[player]
	if h then h.closing=true;task.spawn(function()self:close(player,h)end) end
end
function Service:shutdown()
	self.stopped=true
	for player,h in self.handles do h.closing=true;task.spawn(function()self:close(player,h)end) end
	local deadline=os.clock()+25
	while next(self.handles) and os.clock()<deadline do task.wait(0.1) end
end
return Service
