--!strict
-- 실제 설정/튜토리얼 컨트롤러를 GUI/입력 대역으로 실행. 픽셀/터치 실기기 검증이 아니다.
local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local steps=require("../src/shared/TutorialSteps")
local created,requests={},{}
local function signal()
	local handlers={}
	return{Connect=function(_,fn)local key={};handlers[key]=fn;return{Disconnect=function()handlers[key]=nil end}end,
		Fire=function(_,...)for _,fn in handlers do fn(...)end end,
		Count=function()local n=0;for _ in handlers do n+=1 end;return n end}
end
local function make(class)
	local obj={ClassName=class,Activated=signal(),Destroy=function(self)self.destroyed=true end}
	table.insert(created,obj);return obj
end
local clock=100
local game={GetService=function(_,name)
	if name=="Players"then return{LocalPlayer={WaitForChild=function()return{}end}}
	elseif name=="UserInputService"then return{TouchEnabled=true}
	else return{WaitForChild=function(self)return self end}end
end}
local env={game=game,require=function()return steps end,Instance={new=make},Color3=r.Color3,Vector2=r.Vector2,UDim=r.UDim,UDim2=r.UDim2,Enum=r.Enum,
	workspace={GetServerTimeNow=function()return clock end},os={clock=function()return clock end}}
local Settings=luau.load(fs.readFile("src/client/Controllers/SettingsController.luau"),{environment=env})()
local Tutorial=luau.load(fs.readFile("src/client/Controllers/TutorialController.luau"),{environment=env})()
local remote={FireServer=function(_,payload)table.insert(requests,payload)end}
local settings=Settings.start(remote)
assert(settings.get().compactHUD and not settings.get().loaded)
local observed=0
local disconnect=settings.subscribe(function()observed+=1 end)
settings.set("muted",true);assert(settings.get().muted and #requests==0)
local function snapshot(mode)
	return{roundId=1,preferences={muted=false,reducedMotion=false,largeText=false,hudMode="auto"},tutorialSeen=false,
		data={mode=mode},phase="WAITING",participant=false,downUntil=0,vehicle={seated=false}}
end
settings.update(snapshot("LOADING"));assert(#requests==0)
local ready=snapshot("READY");settings.update(ready)
assert(#requests==1 and requests[1].kind=="SetPreference" and requests[1].key=="muted" and settings.get().muted)
ready.preferences.muted=true;settings.update(ready)
settings.set("hudMode","expanded");assert(not settings.get().compactHUD and observed>1)
local tutorial=Tutorial.start(remote,settings)
tutorial.update(ready)
local function button(text)
	for _,obj in created do if obj.ClassName=="TextButton"and obj.Text==text then return obj end end
	error("Button missing: "..text)
end
button("다음").Activated:Fire();button("다음").Activated:Fire();button("알겠어요").Activated:Fire()
assert(requests[#requests].kind=="TutorialComplete")
ready.tutorialSeen=true;tutorial.update(ready)
button("게임 방법 다시 보기").Activated:Fire()
local count=0
for _,obj in created do if obj.ClassName=="TextButton"and obj.LayoutOrder then count+=1;assert(obj.Size.Y.Offset==44)end end
assert(count==2,"settings and help must be registered in utility drawer")
local before=observed;disconnect();settings.set("largeText",true);assert(observed==before)
tutorial.destroy();settings.destroy()
for _,obj in created do assert(obj.Activated:Count()==0)end
print("PASS settings pre-load edits, server sync, auto/expanded HUD, subscription cleanup, tutorial completion/replay and 44px drawer (GUI mocks)")
