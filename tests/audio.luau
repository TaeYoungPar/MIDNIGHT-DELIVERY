--!strict
local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local catalog=require("../src/shared/AudioCatalog")
local function signal()
	local handlers={};return{Connect=function(_,fn)local key={};handlers[key]=fn;return{Disconnect=function()handlers[key]=nil end}end,
		Fire=function(_,...)for _,fn in handlers do fn(...)end end}
end
local sounds,groups,buttons={}, {},{}
local heartbeat,descendant=signal(),signal()
local function make(class)
	local obj={Parent=nil,IsA=function(_,name)return name==class end,Destroy=function(self)self.Parent=nil;self.destroyed=true end}
	if class=="Sound"then obj.Play=function(self)self.Playing=true;self.plays=(self.plays or 0)+1 end;obj.Stop=function(self)self.Playing=false end;table.insert(sounds,obj)
	elseif class=="SoundGroup"then table.insert(groups,obj)
	elseif class=="TextButton"then obj.Activated=signal();table.insert(buttons,obj)end
	return obj
end
local clock=0
local characterSound=make("Sound");characterSound.Parent=true
local player={UserId=1,Character=nil,WaitForChild=function()return{}end}
local module=luau.load(fs.readFile("src/client/Controllers/AudioController.luau"),{environment={
	game={GetService=function(_,name)
		if name=="SoundService"then return{}elseif name=="Players"then return{LocalPlayer=player}
		elseif name=="RunService"then return{RenderStepped=heartbeat}
		elseif name=="ContentProvider"then return{PreloadAsync=function(_,list,callback)for _,s in list do callback(s.SoundId,r.Enum.AssetFetchStatus.Success)end end}
		else return{WaitForChild=function(self)return self end}end
	end},require=function()return catalog end,
	workspace={GetDescendants=function()return{characterSound}end,DescendantAdded=descendant,GetServerTimeNow=function()return clock end},
	Instance={new=make},Enum=r.Enum,Color3=r.Color3,UDim2=r.UDim2,task={spawn=function(fn)fn()end},
}})()
local audio=module.start()
local byName={};for _,s in sounds do if s.Name then byName[s.Name]=s end end
assert(characterSound.SoundGroup==groups[1] and byName.Wind.Playing)
audio.cue("Knock");assert(byName.Knock.plays==1 and byName.Knock.TimePosition==0 and not byName.Knock.Looped)
audio.cue(nil);audio.cue("Motor");assert(byName.Knock.plays==1 and not byName.Motor.Playing,"only an explicit server knock cue is accepted")
audio.cue("Knock");assert(byName.Knock.plays==2,"each accepted knock restarts the short hit")
for name,definition in catalog do
	assert(definition.volume<=0.4)
	if name=="Motor"then assert(definition.id=="rbxassetid://6002661882","engine must use the sourced engine loop, never a footsteps sample")
	else assert(definition.id:find("rbxasset://sounds/",1,true)==1)end
end
local function snap(phase,coins,down,index,chase)
	return{phase=phase,coins=coins,downUntil=down,orderIndex=index,chase={endsAt=chase}}
end
audio.update(snap("WAITING",0,0,0,0));audio.update(snap("PREPARING",0,0,1,0))
assert(byName.Receipt.plays==1)
audio.update(snap("PLAYING",80,0,2,0));assert(byName.Success.plays==1)
audio.update(snap("PLAYING",80,12,2,0));assert(byName.Down.plays==1)
audio.update(snap("PLAYING",80,0,2,0));assert(byName.Recover.plays==1)
audio.update(snap("PLAYING",80,0,2,10));heartbeat:Fire(0.1);assert(byName.Danger.plays==1)
buttons[1].Activated:Fire();assert(groups[1].Volume==0 and buttons[1].Text=="소리 꺼짐")
buttons[1].Activated:Fire();assert(groups[1].Volume==1)
local speed=0
local model={GetAttribute=function(_,key)return if key=="Speed"then speed elseif key=="VehicleId"then 1 else 1 end}
local seat={Parent=model,IsA=function(_,name)return name=="VehicleSeat"end}
local humanoid={SeatPart=seat,Sit=true,Health=100}
local running=make("Sound");running.Name,running.Volume,running.Parent="Running",0.65,true
local steps={running}
player.Character={FindFirstChildOfClass=function()return humanoid end,GetDescendants=function()return steps end}
heartbeat:Fire(0.1)
assert(byName.Motor.Playing and running.Volume==0,"idling engine must play without footsteps")
local initialPitch,plays=byName.Motor.PlaybackSpeed,byName.Motor.plays
speed=38;heartbeat:Fire(1/60)
assert(byName.Motor.PlaybackSpeed>initialPitch and byName.Motor.PlaybackSpeed<catalog.Motor.pitch+1.05,"RPM must ease, not jump")
assert(byName.Motor.plays==plays,"do not restart the loop at every speed update")
local late=make("Sound");late.Name,late.Volume,late.Parent="Running",0.5,true;table.insert(steps,late)
heartbeat:Fire(0.1);assert(late.Volume==0)
humanoid.SeatPart=nil;humanoid.Sit=false;heartbeat:Fire(0.1)
assert(not byName.Motor.Playing and running.Volume==0.65 and late.Volume==0.5,"dismount must restore walking audio")
humanoid.SeatPart=seat;humanoid.Sit=true;heartbeat:Fire(0.1);assert(byName.Motor.Playing)
player.Character=nil;heartbeat:Fire(0.1);assert(not byName.Motor.Playing and running.Volume==0.65)
audio.destroy();assert(characterSound.SoundGroup==nil and groups[1].destroyed)
for _,sound in sounds do if sound~=characterSound and sound~=running and sound~=late then assert(sound.destroyed)end end
local options={muted=true,loaded=false}
local subscribed=nil
local bridge={
	register=function()end,get=function()return options end,
	set=function(key,value)options[key]=value;if subscribed then subscribed(options)end end,
	subscribe=function(fn)subscribed=fn;fn(options);return function()subscribed=nil end end,
}
local linked=module.start(bridge)
assert(groups[#groups].Volume==0,"audio must stay silent before saved preferences load")
options.loaded=true;subscribed(options);assert(groups[#groups].Volume==0)
bridge.set("muted",false);assert(groups[#groups].Volume==1)
buttons[#buttons].Activated:Fire();assert(options.muted and groups[#groups].Volume==0)
linked.destroy();assert(subscribed==nil)
print("PASS audio catalog, order/reward/down/recovery/chase hooks, wind/motor loops, mute/unmute, sound routing and cleanup (mocked playback; not audible validation)")
