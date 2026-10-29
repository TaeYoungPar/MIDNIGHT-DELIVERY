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
	local clock, wall, overlap, ground, groundY = 0,false,false,true,0
	local groundFilters = nil
	local created = {}
	local boxBlocked = function() return false end
	local deferred, players, actors = {},{},{}
	local heartbeat=signal()
	local function player(id)
		local p={UserId=id,DisplayName="Tester"..id, allowed=true, down=false}
		p.root={Position=r.Vector3.new(0,5,-99),IsA=function(_,class)return class=="BasePart"end}
		p.humanoid={Sit=false,AutoRotate=true,ChangeState=function(self,state)self.state=state end}
		p.Character={IsA=function()return true end,PivotTo=function(_,cf)p.root.Position=cf.Position end,
			GetDescendants=function()return{p.root}end,DescendantAdded=signal()}
		p.root.IsDescendantOf=function(_,char)return char==p.Character end
		p.humanoid.Parent=p.Character
		table.insert(players,p);return p
	end
	local a,b=player(1),player(2)
	local states={root=function(_,p)return p.root,p.humanoid end,canAct=function(_,p)return not p.down end}
	local factory={create=function(parent,id,frame)
		local attrs={}
		local changed=signal()
		local actor={}
		local body={IsA=function(_,class)return class=="BasePart"end}
		actor.model={Parent=parent,FindFirstChild=function(_,name)return if name=="Body"then body else nil end,SetAttribute=function(_,k,v)attrs[k]=v end,GetAttribute=function(_,k)return attrs[k]end, Destroy=function(self)self.destroyed=true end}
		local welds={}
		actor.seat={Position=frame.Position,occupantChanged=changed,GetPropertyChangedSignal=function()return changed end,GetChildren=function()
			local live={};for _,w in welds do if not w.destroyed then table.insert(live,w)end end;return live end}
		actor.seat.Sit=function(self,h)
			self.Occupant=h;h.SeatPart=self;h.Sit=true
			local p=if h==a.humanoid then a else b
			table.insert(welds,{Name="SeatWeld",IsA=function(_,name)return name=="Weld"end,Part1=p.root,
				Destroy=function(w)w.destroyed=true end})
			changed:Fire()
		end
		local function moveAssembly(cf)
			actor.seat.Position=cf.Position
			for _,p in players do if p.humanoid.SeatPart==actor.seat and p.humanoid.Sit then p.root.Position=cf.Position+r.Vector3.new(0,2,0) end end
		end
		setmetatable(actor.seat,{__newindex=function(self,key,value)
			if key=="CFrame" then moveAssembly(value) else rawset(self,key,value) end
		end})
		actor.model.PivotTo=function()error("move the welded seat once, not every model part")end
		actor.prompt={Triggered=signal()};table.insert(actors,actor);return actor
	end}
	local playerService={GetPlayers=function()return players end,GetPlayerFromCharacter=function(_,char)for _,p in players do if p.Character==char then return p end end;return nil end}
	local config=luau.load(fs.readFile("src/shared/Config.luau"),{environment={Vector3=r.Vector3}})()
	local module=luau.load(fs.readFile("src/server/Services/VehicleService.luau"),{environment={
		game={GetService=function(_,name)if name=="Players"then return playerService elseif name=="RunService"then return{PreSimulation=heartbeat}else return{Shared={Config="config"}}end end},
		script={Parent={MovementModel="motion",Parent={World={VehicleFactory="factory"}}}},
		require=function(name)if name=="config"then return config elseif name=="motion"then return Motion else return factory end end,
		Vector3=r.Vector3,CFrame=r.CFrame,Color3=r.Color3,Enum=r.Enum,
		Instance={new=function(class)local obj={ClassName=class,Destroy=function(self)self.destroyed=true end};table.insert(created,obj);return obj end},
		RaycastParams={new=function()return{}end},OverlapParams={new=function()return{}end},
		workspace={GetServerTimeNow=function()return clock end,Blockcast=function()return if wall then {}else nil end,
			GetPartBoundsInBox=function(_,cf)return if overlap or boxBlocked(cf) then {{}}else{}end,
			Raycast=function(_,origin,direction,params)
				if direction.Y > -20 then return nil end
				groundFilters=params.FilterDescendantsInstances
				return if ground then{Position=r.Vector3.new(origin.X,groundY,origin.Z),Normal=r.Vector3.yAxis}else nil
			end},
		task={defer=function(fn)table.insert(deferred,fn)end},
	}})()
	local moved=0
	local s=module.new({},states,function(p)return p.allowed end,function()end,function()moved+=1 end)
	s:add(a);s:add(b)
	return{s=s,a=a,b=b,actors=actors,players=players,heartbeat=heartbeat,
		time=function(v)clock=v end,wall=function(v)wall=v end,overlap=function(v)overlap=v end,ground=function(v)ground=v end,
		boxBlocked=function(fn)boxBlocked=fn end,
		groundY=function(value)groundY=value end,groundFilters=function()return groundFilters end,created=created,
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
test("exit destroys even a stale SeatWeld before moving the rider to safe ground",function()
	local f=setup();f.mount(f.a);local slot=f.s:slot(f.a)
	local weld=slot.actor.seat:GetChildren()[1]
	-- Occupant/SeatPart가 먼저 비어도 실제 용접이 남은 경우를 재현한다.
	slot.actor.seat.Occupant=nil;f.a.humanoid.SeatPart=nil
	f.s:exit(f.a)
	assert(weld.destroyed and not f.a.humanoid.Sit and f.a.humanoid.state==r.Enum.HumanoidStateType.GettingUp)
	assert(math.abs((f.a.root.Position-slot.frame.Position).Magnitude-6)<0.1)
	assert(f.a.root.AssemblyLinearVelocity==r.Vector3.zero and f.moved()==1)
	local position=f.a.root.Position;f.s:exit(f.a)
	assert(f.moved()==1 and f.a.root.Position==position,"on-foot exit must not teleport")
	f.s:destroy()
end)
test("blocked side uses another exit; completely blocked exits return to HQ",function()
	local f=setup();f.mount(f.a);local slot=f.s:slot(f.a)
	local first=slot.frame:PointToWorldSpace(r.Vector3.new(6,0,0))
	f.boxBlocked(function(cf)return math.abs(cf.Position.X-first.X)<0.1 end)
	f.s:exit(f.a)
	local second=slot.frame:PointToWorldSpace(r.Vector3.new(-6,0,0))
	assert(math.abs(f.a.root.Position.X-second.X)<0.01)
	f.s:destroy()
	local g=setup();g.mount(g.a);g.overlap(true);g.s:exit(g.a)
	assert(g.a.root.Position==r.Vector3.new(0,5,-119));g.s:destroy()
end)
test("exit briefly rejects remount; reset cannot schedule a later rider teleport",function()
	local f=setup();f.mount(f.a);local seat=f.s:slot(f.a).actor.seat
	f.s:exit(f.a);seat.Occupant=nil;f.a.humanoid.SeatPart=nil
	f.mount(f.a);assert(not f.a.humanoid.Sit)
	f.time(1);f.mount(f.a);assert(f.a.humanoid.Sit)
	f.s:reset(f.a,true);local before=f.a.root.Position;f.s:destroy();f.flush()
	assert(f.a.root.Position==before and f.moved()==2)
end)
test("physics frames advance immediately instead of dropping alternating render frames",function()
	local f=setup();f.mount(f.a);f.s:input(f.a,1,0)
	local slot=f.s:slot(f.a);local previous=slot.frame.Position
	for _=1,6 do
		f.heartbeat:Fire(1/60)
		assert((slot.frame.Position-previous).Magnitude>0,"every physics frame must move the seat")
		previous=slot.frame.Position
	end
	f.s:input(f.a,1,1);local yaw=slot.yaw;f.s:tick(1/60)
	assert(slot.turn>0 and slot.turn<1,"a steering edge must ease instead of snapping")
	assert(math.abs(slot.yaw-yaw)<1.6/60,"first steering frame must not jump to full angular speed")
	f.s:exit(f.a);assert(slot.turn==0,"remount must not inherit steering momentum")
	f.s:destroy()
end)
test("road height is damped and other cars and riders cannot become ground",function()
	local f=setup();f.mount(f.a);f.s:input(f.a,1,0)
	local slot=f.s:slot(f.a);local before=slot.frame.Position.Y
	f.groundY(0.25);f.s:tick(1/60)
	assert(slot.frame.Position.Y>before and slot.frame.Position.Y<before+0.25)
	local filters=f.groundFilters()
	assert(table.find(filters,slot.actor.model.Parent)and table.find(filters,f.a.Character)and table.find(filters,f.b.Character))
	before=slot.frame;f.groundY(6);f.s:tick(1/60)
	assert(slot.speed==0 and slot.frame==before,"high surfaces must stop driving, not lift the seat")
	f.s:destroy()
end)
test("rider self-collision and auto-rotation are restored on exit and removed on destroy",function()
	local f=setup();f.mount(f.a)
	local slot=f.s:slot(f.a);local rider=slot.rider
	assert(rider and not f.a.humanoid.AutoRotate)
	local constraints=0
	for _,obj in f.created do if obj.ClassName=="NoCollisionConstraint"then constraints+=1;assert(obj.Part1==f.a.root)end end
	assert(constraints==1)
	f.a.Character.DescendantAdded:Fire({IsA=function(_,name)return name=="BasePart"end})
	assert(#f.created==3,"new avatar parts must also ignore their own chassis")
	f.s:exit(f.a);assert(f.a.humanoid.AutoRotate and rider.folder.destroyed and slot.rider==nil)
	local count=#f.created;f.a.Character.DescendantAdded:Fire(f.a.root);assert(#f.created==count)
	f.s:destroy()
	local g=setup();g.a.humanoid.AutoRotate=false;g.mount(g.a)
	local second=g.s:slot(g.a);local natural=second.rider
	g.a.humanoid.Sit=false;g.a.humanoid.SeatPart=nil;second.actor.seat.Occupant=nil
	second.actor.seat.occupantChanged:Fire()
	assert(natural.folder.destroyed and second.rider==nil and not g.a.humanoid.AutoRotate,"natural unseat preserves pre-existing rotation state")
	g.a.humanoid.AutoRotate=true;g.mount(g.a);local active=second.rider
	g.s:destroy();assert(active.folder.destroyed and g.a.humanoid.AutoRotate,"destroy must restore an active rider")
end)
print(string.format("%d P4 vehicle/movement tests passed (mocked seat, casts and physics; not Studio)",tests))
