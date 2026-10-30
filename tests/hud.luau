--!strict
local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local function signal()
	local callbacks={};return{Connect=function(_,fn)local k={};callbacks[k]=fn;return{Disconnect=function()callbacks[k]=nil end}end,
		Fire=function(_,...)for _,fn in callbacks do fn(...)end end,
		Count=function()local n=0;for _ in callbacks do n+=1 end;return n end}
end
local render,resize=signal(),signal()
local ui={}
local descendants={}
for _,name in {"phase","timer","title","hint","toggle","stats","note","arrow","distance","toast","recovery","team"}do
	ui[name]={TextSize=14,Activated=signal(),IsA=function(_,class)return class=="TextLabel"end}
	table.insert(descendants,ui[name])
end
ui.card={}
ui.root={AbsoluteSize=r.Vector2.new(780,360),GetPropertyChangedSignal=function()return resize end}
ui.gui={GetDescendants=function()return descendants end,Destroy=function(self)self.destroyed=true end}
local strings=require("../src/shared/Strings")
local factory={create=function()return ui end}
local shared={WaitForChild=function(_,name)return name end}
local player={Character=nil,WaitForChild=function()return{}end}
local tweenCount,cancelCount=0,0
local module=luau.load(fs.readFile("src/client/Controllers/HUDController.luau"),{environment={
	game={GetService=function(_,name)
		if name=="Players"then return{LocalPlayer=player}elseif name=="RunService"then return{RenderStepped=render}
		elseif name=="UserInputService"then return{TouchEnabled=true}
		elseif name=="TweenService"then return{Create=function(_,object,_,target)
			tweenCount+=1;return{Play=function()object.TextTransparency=target.TextTransparency end,Cancel=function()cancelCount+=1 end}
		end}
		else return{WaitForChild=function()return shared end}end
	end},
	script={Parent={Parent={UI={UIFactory="factory"}}}},require=function(name)return if name=="factory"then factory elseif name=="Strings"then strings else{}end,
	workspace={GetServerTimeNow=function()return 100 end},UDim2=r.UDim2,Vector2=r.Vector2,Enum=r.Enum,TweenInfo={new=function()return{}end},
}})()
local hud=module.start()
hud.configure({hudMode="auto",compactHUD=true,largeText=false,reducedMotion=false})
hud.update({version=1,phase="WAITING",coins=0,xp=0,level=1,playerCount=1,data={mode="READY",dirty=false},
	participant=false,endsAt=120,downUntil=0,protectedUntil=0,chase={endsAt=0},members={{name="아주아주아주아주아주긴이름",downUntil=0}},orderActive=false})
assert(not ui.hint.Visible)
render:Fire(0.1);assert(ui.phase.Text:find("가방 준비까지 20초"))
hud.configure({hudMode="expanded",compactHUD=false,largeText=true,reducedMotion=false})
assert(ui.hint.Visible and ui.card.Size.Y.Offset==164 and ui.hint.TextSize>14)
render:Fire(0.1);assert(ui.timer.Text=="00:20" and utf8.len(ui.team.Text)~=nil)
hud.feedback("test");assert(tweenCount==1)
hud.configure({hudMode="expanded",compactHUD=false,largeText=true,reducedMotion=true})
assert(cancelCount==1)
hud.feedback("quiet");assert(tweenCount==1 and ui.toast.TextTransparency==0)
assert(ui.hint.Text:find("출발선") and ui.title.Text=="다음 배달 기다리는 중")
hud.update({version=2,phase="PREPARING",coins=0,level=1,playerCount=1,data={mode="READY"},participant=true})
assert(ui.title.Text=="배달가방 준비 중" and ui.hint.Text:find("출발선"))
hud.destroy();assert(ui.gui.destroyed and render:Count()==0 and resize:Count()==0 and ui.toggle.Activated:Count()==0)
print("PASS HUD compact/large text, UTF-8 names, server timer, reduced alert animation and connection cleanup (GUI mocks)")
