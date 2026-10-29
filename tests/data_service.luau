--!strict
local fs,luau=require("@lune/fs"),require("@lune/luau")
local Model=require("../src/server/Services/ProfileModel")
local Economy=require("../src/server/Services/EconomyService")
local Store=luau.load(fs.readFile("src/server/Services/ProfileStore.luau"),{environment={script={Parent={ProfileModel="m"}},require=function()return Model end}})()
local function clone(v)if typeof(v)~="table"then return v end;local t={};for k,x in v do t[k]=clone(x)end;return t end
local count=0
local function test(name,run)local ok,e=pcall(run);assert(ok,name..": "..tostring(e));count+=1;print("PASS "..name)end
local function setup(published,studio)
	local rows,attrs={},{}
	local clock,unix,serial=100,1793170000,0
	local hook=nil
	local names={}
	local adapter={UpdateAsync=function(_,key,fn)
		local nextRow=fn(clone(rows[key]));if nextRow then rows[key]=clone(nextRow)end
		if hook then local h=hook;hook=nil;h()end
		return clone(nextRow)
	end}
	local economy=Economy.new()
	local module=luau.load(fs.readFile("src/server/Services/DataService.luau"),{environment={
		script={Parent={ProfileModel="model",ProfileStore="store"}},require=function(name)return if name=="model"then Model else Store end,
		game={GameId=if published then 123 else 0,GetService=function(_,name)
			if name=="DataStoreService"then return{GetDataStore=function(_,storeName)table.insert(names,storeName);return adapter end}
			elseif name=="HttpService"then return{GenerateGUID=function()serial+=1;return"T"..serial end}
			else return{IsStudio=function()return studio end}end
		end},
		os={clock=function()return clock end,time=function()return unix end},
		task={spawn=function(fn)fn()end,wait=function(n)clock+=n;unix+=n end},
	}})()
	local data=module.new(economy,function()end)
	economy.canMutate=function(p)return data:canEarn(p)end;economy.onMutation=function(p)data:touch(p)end
	local function player(id)
		local a={};attrs[id]=a
		return{UserId=id,SetAttribute=function(_,k,v)a[k]=v end}
	end
	return{data=data,e=economy,rows=rows,names=names,attrs=attrs,player=player,
		advance=function(n)clock+=n;unix+=n end,hook=function(fn)hook=fn end}
end

test("unpublished place stays session-only and cannot write shop",function()
	local f=setup(false,true);local p=f.player(1);f.e:add(p);f.data:begin(p)
	assert(f.data:loaded(p)and f.data:status(p).mode=="SESSION"and not f.data:canShop(p))
	assert(f.e:award(p,1,80,20,1));f.data:remove(p)
	assert(next(f.rows)==nil)
end)
test("published Studio and live use distinct datastore names",function()
	local a,b=setup(true,true),setup(true,false)
	assert(a.names[1]=="MidnightDelivery_Studio_PlayerData_v1"and b.names[1]=="MidnightDelivery_Live_PlayerData_v1")
end)
test("actual data/economy lifecycle saves and restores coins, XP and level",function()
	local f=setup(true,true);local p=f.player(1);f.e:add(p);f.data:begin(p)
	assert(f.data:canShop(p));for i=1,5 do assert(f.e:award(p,i,80,20,1))end
	assert(f.attrs[1].Level==2 and f.attrs[1].Coins==400)
	f.data:remove(p);f.e:remove(p);assert(f.rows.User_1.lease==nil)
	local again=f.player(1);f.e:add(again);f.data:begin(again)
	assert(f.attrs[1].Coins==400 and f.attrs[1].XP==100 and f.attrs[1].Level==2)
	f.data:shutdown();assert(next(f.data.handles)==nil)
end)
test("autosave renews lease and clears dirty without closing session",function()
	local f=setup(true,true);local p=f.player(1);f.e:add(p);f.data:begin(p)
	f.e:award(p,1,80,20,1);assert(f.data:status(p).dirty)
	f.advance(62);f.data:tick()
	assert(not f.data:status(p).dirty and f.rows.User_1.profile.coins==80 and f.rows.User_1.lease)
	f.data:shutdown()
end)
test("leaving during load releases acquired lease and cannot replace newer wallet",function()
	local f=setup(true,true);local p=f.player(1);f.e:add(p)
	f.hook(function()
		f.data:remove(p)
		f.e.profiles[1]={coins=777,xp=0}
	end)
	f.data:begin(p)
	assert(f.e.profiles[1].coins==777 and f.rows.User_1.lease==nil and f.data.handles[p]==nil)
end)
print(string.format("%d DataService lifecycle tests passed (mock scheduler and in-memory adapter; no live Roblox storage)",count))
