--!strict
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Motion = require("../src/server/Services/MovementModel")
local Limiter = require("../src/server/Services/ActionLimiter")
local tests = 0
local function test(name, run) local ok,e=pcall(run); assert(ok,name..": "..tostring(e)); tests+=1; print("PASS "..name) end
local function signal()
	local handlers={}
	return {Connect=function(_,fn) local k={};handlers[k]=fn;return{Disconnect=function()handlers[k]=nil end}end,
		Fire=function(_,...)for _,fn in handlers do fn(...)end end}
end
local function setup()
	local clock, wall, overlap, ground = 0,false,false,true
	local deferred, players, actors = {},{},{}
	local heartbeat=signal()
	local function player(id)
		local p={UserId=id,DisplayName="Tester"..id, allowed=true, down=false}
		p.root={Position=r.Vector3.new(0,5,-99)}
		p.humanoid={Sit=false}
		p.Character={IsA=function()return true end,PivotTo=function(_,cf)p.root.Position=cf.Position end}
		p.humanoid.Parent=p.Character
		table.insert(players,p);return p
	end
	local a,b=player(1),player(2)
	local states={root=function(_,p)return p.root,p.humanoid end,canAct=function(_,p)return not p.down end}
	local factory={create=function(parent,id,frame)
		local attrs={}
		local changed=signal()
		local actor={}
		actor.model={SetAttribute=function(_,k,v)attrs[k]=v end,GetAttribute=function(_,k)return attrs[k]end, Destroy=function(self)self.destroyed=true end}
		actor.seat={Position=frame.Position,GetPropertyChangedSignal=function()return changed end,FindFirstChild=function()return nil end}
		actor.seat.Sit=function(self,h)self.Occupant=h;h.SeatPart=self;h.Sit=true;changed:Fire()end
		actor.model.PivotTo=function(_,cf)
			actor.seat.Position=cf.Position
			for _,p in players do if p.humanoid.SeatPart==actor.seat and p.humanoid.Sit then p.root.Position=cf.Position+r.Vector3.new(0,2,0) end end
		end
		actor.prompt={Triggered=signal()};table.insert(actors,actor);return actor
	end}
	local playerService={GetPlayers=function()return players end,GetPlayerFromCharacter=function(_,char)for _,p in players do if p.Character==char then return p end end;return nil end}
	local config=luau.load(fs.readFile("src/shared/Config.luau"),{environment={Vector3=r.Vector3}})()
	local module=luau.load(fs.readFile("src/server/Services/VehicleService.luau"),{environment={
		game={GetService=function(_,name)if name=="Players"then return playerService elseif name=="RunService"then return{Heartbeat=heartbeat}else return{Shared={Config="config"}}end end},
		script={Parent={MovementModel="motion",Parent={World={VehicleFactory="factory"}}}},
		require=function(name)if name=="config"then return config elseif name=="motion"then return Motion else return factory end end,
		Vector3=r.Vector3,CFrame=r.CFrame,Enum=r.Enum,
		RaycastParams={new=function()return{}end},OverlapParams={new=function()return{}end},
		workspace={GetServerTimeNow=function()return clock end,Blockcast=function()return if wall then {}else nil end,
			GetPartBoundsInBox=function()return if overlap then {{}}else{}end,
			Raycast=function(_,origin)return if ground then{Position=r.Vector3.new(origin.X,0,origin.Z)}else nil end},
		task={defer=function(fn)table.insert(deferred,fn)end},
	}})()
	local moved=0
	local s=module.new({},states,function(p)return p.allowed end,function()end,function()moved+=1 end)
	s:add(a);s:add(b)
	return{s=s,a=a,b=b,actors=actors,players=players,heartbeat=heartbeat,
		time=function(v)clock=v end,wall=function(v)wall=v end,overlap=function(v)overlap=v end,ground=function(v)ground=v end,
		flush=function()local pending=deferred;deferred={};for _,fn in pending do fn()end end,
		moved=function()return moved end,
		mount=function(p)local slot=s:slot(p);p.root.Position=slot.actor.seat.Position;slot.actor.prompt.Triggered:Fire(p)end}
end

test("stamina drains five seconds, exhausts, and fully recharges",function()
	local s={value=5,exhausted=false}
	for _=1,50 do Motion.stamina(s,true,true,true,0.1)end
	assert(s.value<0.01 and s.exhausted)
	for _=1,49 do assert(Motion.stamina(s,true,true,true,0.1)==16)end
	Motion.stamina(s,false,false,true,0.1);assert(not s.exhausted and s.value>4.99)
	assert(Motion.stamina(s,true,true,true,0.1)==22)
	assert(Motion.stamina(s,true,true,false,0.1)==16)
end)
test("vehicle input rejects NaN, infinity, strings and out-of-range axes",function()
	assert(Motion.input(1,-1));assert(not Motion.input(0/0,0));assert(not Motion.input(math.huge,0));assert(not Motion.input("1",0));assert(not Motion.input(0,1.1))
end)
test("speed limits, reverse and braking are server-calculated",function()
	local speed=0
	for _=1,100 do speed=Motion.speed(speed,1,0.05)end;assert(math.abs(speed-38)<0.001)
	for _=1,100 do speed=Motion.speed(speed,-1,0.05)end;assert(math.abs(speed+12)<0.001)
	for _=1,20 do speed=Motion.speed(speed,0,0.05)end;assert(math.abs(speed)<0.001)
end)
test("action token bucket bounds bursts and replenishes",function()
	local l=Limiter.new();for _=1,20 do assert(l:allow(1,0))end;assert(not l:allow(1,0));assert(l:allow(2,0));assert(l:allow(1,1));l:remove(1);assert(l:allow(1,1))
end)
test("four scooters and one owner per seat; strangers cannot mount or drive",function()
	local f=setup();assert(#f.s.slots==4 and f.s:slot(f.a)~=f.s:slot(f.b))
	local actor=f.s:slot(f.a).actor
	f.b.root.Position=actor.seat.Position;actor.prompt.Triggered:Fire(f.b);assert(not actor.seat.Occupant)
	assert(not f.s:input(f.b,1,0))
	f.mount(f.a);assert(f.s:seated(f.a) and f.s:input(f.a,1,0))
	f.a.down=true;assert(not f.s:input(f.a,1,0));f.s:tick(0.05);assert(not f.a.humanoid.Sit);f.s:destroy()
end)
test("movement clamps speed and input timeout brakes",function()
	local f=setup();f.mount(f.a)
	for i=1,60 do f.time(i*0.05);if i%4==1 then f.s:input(f.a,1,0)end;f.s:tick(0.05)end
	local slot=f.s:slot(f.a);assert(slot.speed<=38 and slot.speed>30)
	local before=slot.frame.Position;f.time(4);f.s:tick(0.05);assert(slot.throttle==0 and slot.speed<38)
	assert((slot.frame.Position-before).Magnitude<2);f.s:destroy()
end)
test("swept wall and rotation overlap stop the scooter",function()
	local f=setup();f.mount(f.a);f.s:input(f.a,1,1)
	local slot=f.s:slot(f.a);local before=slot.frame
	f.wall(true);f.s:tick(0.05);assert(slot.speed==0 and slot.frame==before)
	f.wall(false);f.overlap(true);f.s:tick(0.05);assert(slot.speed==0 and slot.frame==before);f.s:destroy()
end)
test("reset enforces ownership, cooldown, safe parking and ejection",function()
	local f=setup();f.mount(f.a);f.s:input(f.a,1,0);f.s:tick(0.05)
	assert(f.s:reset(f.a,true));f.flush();local slot=f.s:slot(f.a)
	assert(not f.a.humanoid.Sit and slot.frame==slot.home and f.moved()==1)
	assert(not f.s:reset(f.a,true));f.time(15);assert(f.s:reset(f.a,true));f.flush();f.s:destroy()
end)
test("missing ground resets scooter; departure releases and reassigns slot",function()
	local f=setup();f.mount(f.a);f.s:input(f.a,1,0);f.ground(false);f.s:tick(0.05);f.flush()
	assert(f.s:slot(f.a).frame==f.s:slot(f.a).home and not f.a.humanoid.Sit)
	local old=f.s:slot(f.a);f.s:remove(f.a);assert(old.owner==nil and f.s:slot(f.b)~=nil);f.s:destroy()
end)
test("deferred reset cannot move a destroyed service or reassigned slot",function()
	local f=setup();f.mount(f.a);f.s:reset(f.a,true);f.s:destroy();f.flush();assert(f.moved()==0)
end)
print(string.format("%d P4 vehicle/movement tests passed (mocked seat, casts and physics; not Studio)",tests))
