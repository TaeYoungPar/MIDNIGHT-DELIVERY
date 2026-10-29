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
local player={Character=nil,WaitForChild=function()return{}end}
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
for _,definition in catalog do assert(definition.id:find("rbxasset://sounds/",1,true)==1 and definition.volume<=0.4)end
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
player.Character={FindFirstChildOfClass=function()return{SeatPart={Parent={GetAttribute=function()return 30 end}}}end}
heartbeat:Fire(0.1);assert(byName.Motor.Playing and byName.Motor.PlaybackSpeed>0.65)
player.Character=nil;heartbeat:Fire(0.1);assert(not byName.Motor.Playing)
audio.destroy();assert(characterSound.SoundGroup==nil and groups[1].destroyed)
for _,sound in sounds do if sound~=characterSound then assert(sound.destroyed)end end
print("PASS audio catalog, order/reward/down/recovery/chase hooks, wind/motor loops, mute/unmute, sound routing and cleanup (mocked playback; not audible validation)")
