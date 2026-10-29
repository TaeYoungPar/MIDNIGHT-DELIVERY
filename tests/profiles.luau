--!strict
local fs,luau=require("@lune/fs"),require("@lune/luau")
local Model=require("../src/server/Services/ProfileModel")
local Catalog=require("../src/shared/Catalogs")
local Economy=require("../src/server/Services/EconomyService")
local Store=luau.load(fs.readFile("src/server/Services/ProfileStore.luau"),{
	environment={script={Parent={ProfileModel="model"}},require=function()return Model end},
})()
local tests=0
local function test(name,run)local ok,e=pcall(run);assert(ok,name..": "..tostring(e));tests+=1;print("PASS "..name)end
local function clone(value)
	if typeof(value)~="table"then return value end
	local out={};for k,v in value do out[k]=clone(v)end;return out
end
local function backend()
	local rows,calls,failures={},0,0
	local hook=nil
	local adapter={UpdateAsync=function(_,key,fn)
		calls+=1
		if failures>0 then failures-=1;error("temporary failure")end
		-- Roblox는 콜백을 재시도할 수 있다. 같은 옛 값으로 두 번 불러도 수익/지출이 변하지 않아야 한다.
		fn(clone(rows[key]))
		local value=fn(clone(rows[key]))
		if value then rows[key]=clone(value)end
		if hook then local h=hook;hook=nil;h()end
		return clone(value)
	end}
	return{adapter=adapter,rows=rows,calls=function()return calls end,fail=function(n)failures=n end,hook=function(fn)hook=fn end}
end
local function context()
	local b=backend();local time=1793170000
	return{b=b,a=Store.new(b.adapter,function()return time end,function()end,"A"),
		other=Store.new(b.adapter,function()return time end,function()end,"B"),time=function(t)time=t end,now=function()return time end}
end

test("fresh profile and current Unix lease roundtrip validate",function()
	local f=context();local h=f.a:load(1)
	assert(h.mode=="READY" and h.expiresAt==f.now()+180)
	h.profile.coins=240;h.version+=1;assert(f.a:save(1,h,false))
	local row=Model.decode(f.b.rows.User_1);assert(row and row.profile.coins==240 and row.lease.expiresAt>1700000000)
end)
test("invalid currency, future schema, malformed inventory and unowned equip fail closed",function()
	for _,raw in {{schemaVersion=2},{schemaVersion=1,coins=0/0,xp=0},{schemaVersion=1,coins=-1,xp=0},
		{schemaVersion=1,coins=0,xp=0,owned=false},{schemaVersion=1,coins=0,xp=0,equipped={hat="neon_cap"}},
		{schemaVersion=1,coins=math.huge,xp=0}} do assert(Model.decode(raw)==nil)end
end)
test("documented flat v1 inventory migrates without losing currency",function()
	local row=Model.decode({schemaVersion=1,coins=120,xp=100,lifetimeDeliveries=5,ownedCosmetics={"outfit_default","scooter_default"},equipped={outfit="outfit_default",scooterSkin="scooter_default"}})
	assert(row and row.profile.coins==120 and row.profile.owned.outfit_default and row.profile.equipped.hat=="")
end)
test("live lease refuses second server without overwriting saved profile",function()
	local f=context();local first=f.a:load(1);first.profile.coins=360;f.a:save(1,first,false)
	local second=f.other:load(1);assert(second.mode=="SESSION" and second.reason=="locked")
	second.profile.coins=999;assert(not f.other:save(1,second,true));assert(f.b.rows.User_1.profile.coins==360)
end)
test("expired lease can be acquired and previous server cannot write",function()
	local f=context();local old=f.a:load(1);f.time(f.now()+181)
	local current=f.other:load(1);assert(current.mode=="READY")
	old.expiresAt=f.now()+180;old.profile.coins=999 -- 메모리가 잘못된 만료 시각을 갖더라도 저장된 토큰이 차단한다.
	assert(not f.a:save(1,old,false) and old.mode=="SESSION")
	assert(f.b.rows.User_1.lease.token=="B" and f.b.rows.User_1.profile.coins==0)
end)
test("lease safety guard freezes persistence before expiry",function()
	local f=context();local h=f.a:load(1);f.time(f.now()+150)
	assert(not f.a:writable(h) and h.mode=="SESSION" and not f.a:save(1,h,false))
end)
test("retries are bounded and failed loads never replace original data",function()
	local f=context();f.b.rows.User_1={schemaVersion=1,coins=800,xp=100}
	f.b.fail(3);local h=f.a:load(1);assert(h.mode=="SESSION" and f.b.calls()==3)
	assert(f.b.rows.User_1.coins==800 and not f.a:save(1,h,true))
end)
test("temporary save error retains dirty data and recovers on next save",function()
	local f=context();local h=f.a:load(1);h.profile.coins=80;h.version+=1;h.dirty=true
	f.b.fail(3);assert(not f.a:save(1,h,false));assert(h.mode=="SAVE_ERROR" and h.dirty)
	assert(f.a:save(1,h,false) and h.mode=="READY" and not h.dirty and f.b.rows.User_1.profile.coins==80)
end)
test("snapshot save never erases mutations received during async update",function()
	local f=context();local h=f.a:load(1);h.profile.coins=80;h.version=1
	f.b.hook(function()h.profile.coins=160;h.version=2 end)
	assert(f.a:save(1,h,false));assert(h.profile.coins==160 and h.dirty and f.b.rows.User_1.profile.coins==80)
	assert(f.a:save(1,h,false));assert(not h.dirty and f.b.rows.User_1.profile.coins==160)
end)
test("release saves once, removes lease, and new session restores inventory",function()
	local f=context();local h=f.a:load(1);h.profile.coins=360
	assert(Model.purchase(h.profile,Catalog[1]));assert(Model.equip(h.profile,Catalog[1],true))
	h.version+=1;h.closing=true;assert(f.a:save(1,h,true));assert(f.b.rows.User_1.lease==nil)
	assert(not f.a:save(1,h,true))
	local restored=f.other:load(1);assert(restored.profile.coins==240 and restored.profile.equipped.hat=="neon_cap")
end)
test("corrupt and newer records remain byte-for-byte structurally untouched",function()
	local f=context();f.b.rows.User_1={schemaVersion=99,privateFutureField="preserve"}
	local h=f.a:load(1);assert(h.mode=="SESSION");assert(f.b.rows.User_1.schemaVersion==99 and f.b.rows.User_1.privateFutureField=="preserve")
end)
test("shop checks coins, level, duplicate ownership and equip rights",function()
	local p=Model.default();assert(not Model.purchase(p,Catalog[1]));p.coins=1000
	assert(not Model.purchase(p,Catalog[2]));p.xp=100
	assert(Model.purchase(p,Catalog[2]) and p.coins==820);assert(not Model.purchase(p,Catalog[2]) and p.coins==820)
	assert(not Model.equip(p,Catalog[1],true));assert(Model.equip(p,Catalog[2],true));assert(Model.equip(p,Catalog[2],false))
	assert(p.equipped.scooter=="")
end)
test("XP levels are derived and capped; rewards stay idempotent",function()
	assert(Model.level(0)==1 and Model.level(99)==1 and Model.level(100)==2 and Model.level(1000000)==10)
	local attrs={};local p={UserId=1,SetAttribute=function(_,k,v)attrs[k]=v end}
	local e=Economy.new();e:add(p);e.profiles[1].coins=999999990;e.profiles[1].xp=999999990
	local count=0;e.onMutation=function()count+=1 end;e.canMutate=function()return true end
	assert(e:award(p,1,80,20,1));assert(not e:award(p,1,80,20,1))
	assert(attrs.Coins==1000000000 and attrs.XP==1000000000 and count==1)
end)
test("late save acknowledgement cannot re-enable an invalidated session",function()
	local f=context();local h=f.a:load(1);h.profile.coins=80;h.version=1
	f.b.hook(function()h.mode="SESSION";h.reason="lease_expired";h.profile.coins=160;h.version=2 end)
	assert(not f.a:save(1,h,false) and h.mode=="SESSION")
	assert(not f.a:save(1,h,false) and f.b.rows.User_1.profile.coins==80)
end)
test("shop service locks session mode and rejects invalid payloads",function()
	local profile=Model.default();profile.coins=500;profile.xp=100
	local writable=false
	local data={canShop=function()return writable end,profile=function()return profile end,touch=function()end,queueSave=function()end}
	local clock=0
	local Shop=luau.load(fs.readFile("src/server/Services/ShopService.luau"),{environment={
		game={GetService=function()return{Shared={Catalogs="catalog"}}end},script={Parent={ProfileModel="model"}},
		require=function(name)return if name=="catalog"then Catalog else Model end,
		workspace={GetServerTimeNow=function()return clock end},
	}})()
	local shop=Shop.new(data,function()end);local player={}
	assert(not shop:action(player,"PurchaseWithCoins","neon_cap",nil));assert(profile.coins==500)
	writable=true
	assert(not shop:action(player,"EquipCosmetic","neon_cap","yes"))
	assert(not shop:action(player,"PurchaseWithCoins",{},nil))
	assert(shop:action(player,"PurchaseWithCoins","neon_cap",nil));assert(profile.coins==380)
	clock=1;assert(not shop:action(player,"PurchaseWithCoins","neon_cap",nil));assert(profile.coins==380)
	clock=2;assert(shop:action(player,"EquipCosmetic","neon_cap",true));assert(profile.equipped.hat=="neon_cap")
	clock=3;assert(shop:action(player,"EquipCosmetic","neon_cap",false));assert(profile.equipped.hat=="")
end)
print(string.format("%d P5 profile/lease/economy tests passed (in-memory UpdateAsync adapter, not Roblox DataStore)",tests))
