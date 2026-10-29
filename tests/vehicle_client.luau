--!strict
-- 실제 클라이언트 모듈을 카메라/입력/GUI 대역으로 실행한다. Studio 렌더링·터치·좌석 복제가 아니다.
local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local function signal()
	local handlers={}
	return {Connect=function(_,fn)local key={};handlers[key]=fn;return{Disconnect=function()handlers[key]=nil end}end,
		Fire=function(_,...)for _,fn in handlers do fn(...)end end,
		Count=function()local n=0;for _ in handlers do n+=1 end;return n end}
end
local function setup(touch)
	local made,requests,bindings,actions={},{},{},{}
	local function instance(class)
		local obj={ClassName=class,Activated=signal(),InputBegan=signal()}
		obj.IsA=function(_,name)return class==name end
		obj.Destroy=function(self)self.destroyed=true;self.Parent=nil end
		table.insert(made,obj);return obj
	end
	local humanoid={Health=100,Sit=false}
	local character={FindFirstChildOfClass=function(_,class)return if class=="Humanoid"then humanoid else nil end}
	local player={UserId=1,Character=character,WaitForChild=function()return{}end,GetAttribute=function()return 5 end}
	local function model(id,owner,name,x)
		local attrs={VehicleId=id,OwnerUserId=owner,OwnerName=name}
		local m={GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end}
		local prompt={Enabled=true,Parent={}}
		local seat={Parent=m,Position=r.Vector3.new(x,3,-99),CFrame=r.CFrame.new(x,3,-99)*r.CFrame.Angles(0,math.pi,0),
			IsA=function(_,class)return class=="VehicleSeat"end,FindFirstChildWhichIsA=function()return prompt end,ThrottleFloat=0,SteerFloat=0}
		m.FindFirstChild=function(_,key)return if key=="DriverSeat"then seat else nil end
		return m,seat,prompt
	end
	local own,seat,ownPrompt=model(1,1,"Local",-18)
	local other,otherSeat,otherPrompt=model(2,2,"Other",-6)
	local vehicles={GetChildren=function()return{own,other}end}
	own.Parent,other.Parent=vehicles,vehicles
	local world={FindFirstChild=function(_,name)return if name=="Vehicles"then vehicles else nil end}
	local camera={CameraType=r.Enum.CameraType.Custom,CFrame=r.CFrame.new(),CameraSubject=humanoid}
	local hitDistance=nil
	local ws={CurrentCamera=camera,FindFirstChild=function(_,name)return if name=="GameWorld"then world else nil end,
		GetServerTimeNow=function()return 100 end,Raycast=function()return if hitDistance then {Distance=hitDistance}else nil end}
	local run={RenderStepped=signal(),BindToRenderStep=function(_,name,priority,fn)bindings[name]={priority=priority,fn=fn}end,
		UnbindFromRenderStep=function(_,name)bindings[name]=nil end}
	local typing=false
	local uis={TouchEnabled=touch,InputEnded=signal(),WindowFocusReleased=signal(),WindowFocused=signal(),
		GetFocusedTextBox=function()return if typing then{}else nil end,IsKeyDown=function()return false end}
	local cas={BindActionAtPriority=function(_,name,fn,button,priority,...)actions[name]={fn=fn,priority=priority,keys={...}}end,
		UnbindAction=function(_,name)actions[name]=nil end}
	local game={GetService=function(_,name)
		if name=="Players"then return{LocalPlayer=player}elseif name=="RunService"then return run
		elseif name=="UserInputService"then return uis elseif name=="ContextActionService"then return cas
		else return{WaitForChild=function(self)return self end}end
	end}
	local env={game=game,workspace=ws,Instance={new=instance},Vector3=r.Vector3,CFrame=r.CFrame,Color3=r.Color3,
		Vector2=r.Vector2,UDim2=r.UDim2,Enum=r.Enum,RaycastParams={new=function()return{}end},require=function()return{}end}
	local Camera=luau.load(fs.readFile("src/client/Controllers/VehicleController.luau"),{environment=env})()
	local Input=luau.load(fs.readFile("src/client/Controllers/InputController.luau"),{environment=env})()
	local remote={FireServer=function(_,payload)table.insert(requests,payload)end}
	local controls=Input.start(remote,{get=function()return{menuOpen=false}end,register=function()end})
	controls.update({roundId=3,downUntil=0,vehicle={owned=true,resetAt=0},phase="WAITING",participant=false})
	local controller=Camera.start()
	return {made=made,requests=requests,bindings=bindings,actions=actions,humanoid=humanoid,character=character,seat=seat,
		own=own,other=other,ownPrompt=ownPrompt,otherPrompt=otherPrompt,camera=camera,uis=uis,run=run,player=player,
		typing=function(value)typing=value end,hit=function(value)hitDistance=value end,
		step=function(dt)run.RenderStepped:Fire(dt);for _,binding in bindings do binding.fn(dt)end end,
		mount=function()humanoid.SeatPart=seat;humanoid.Sit=true;seat.Occupant=humanoid end,
		destroy=function()controls.destroy();controller.destroy()end}
end
local function find(f,class,name)
	for _,obj in f.made do if obj.ClassName==class and obj.Name==name then return obj end end
	error("Missing "..class.." "..name)
end
local f=setup(false)
f.step(0.2)
assert(f.ownPrompt.Enabled and not f.otherPrompt.Enabled)
local ownHighlight,ownTag=nil,nil
for _,obj in f.made do
	if obj.ClassName=="Highlight"and obj.Adornee==f.own then ownHighlight=obj end
	if obj.ClassName=="BillboardGui"and obj.Adornee==f.seat then ownTag=obj end
end
assert(ownHighlight and ownHighlight.Enabled and ownTag.AlwaysOnTop)
local foundLabel=false
for _,obj in f.made do if obj.ClassName=="TextLabel"and obj.Parent==ownTag then foundLabel=string.find(obj.Text,"내 스쿠터")~=nil end end
assert(foundLabel)
assert(f.camera.CameraType==r.Enum.CameraType.Custom,"on-foot camera must remain native")
f.mount();f.step(0.2)
assert(f.camera.CameraType==r.Enum.CameraType.Scriptable)
local wanted=f.seat.Position-f.seat.CFrame.LookVector*16+r.Vector3.new(0,8,0)
assert((f.camera.CFrame.Position-wanted).Magnitude<0.01,"camera must start above and behind scooter")
assert(not ownHighlight.Enabled and not ownTag.Enabled and not f.ownPrompt.Enabled)
local previous=f.camera.CFrame.Position
f.seat.Position+=r.Vector3.new(2,0,0);f.seat.CFrame=r.CFrame.new(f.seat.Position)*r.CFrame.Angles(0,math.pi,0)
f.step(1/60)
assert(f.camera.CFrame.Position.X>previous.X and f.camera.CFrame.Position.X<previous.X+2,"replicated motion must be smoothed")
f.hit(5);f.step(1/60)
assert(math.abs((f.camera.CFrame.Position-f.camera.Focus.Position).Magnitude-4.4)<0.01,"wall hit must shorten camera arm from the smoothed focus")
f.hit(nil)
local oldFocus=f.camera.Focus.Position
f.seat.Position+=r.Vector3.new(0,0.25,0)
f.seat.CFrame=r.CFrame.new(f.seat.Position)*r.CFrame.Angles(0,math.pi-0.1,0)
f.step(1/60)
assert((f.camera.Focus.Position-oldFocus).Magnitude<0.25,"focus must not snap to a replicated height or steering update")
local arm=(f.camera.CFrame.Position-f.camera.Focus.Position).Magnitude
assert(arm>4.4 and arm<10,"leaving an obstruction must extend the arm gradually instead of zooming out at once")
f.seat.Position+=r.Vector3.new(100,0,0);f.seat.CFrame=r.CFrame.new(f.seat.Position)
f.step(1/60)
assert((f.camera.Focus.Position-(f.seat.Position+r.Vector3.new(0,3,-3))).Magnitude<0.01,"reset must discard the old camera frame")
local action=f.actions.MidnightExitVehicle
assert(action.priority>r.Enum.ContextActionPriority.High.Value)
assert(table.find(action.keys,r.Enum.KeyCode.Space)and table.find(action.keys,r.Enum.KeyCode.X))
assert(action.fn("exit",r.Enum.UserInputState.Begin)==r.Enum.ContextActionResult.Sink)
assert(f.requests[#f.requests].kind=="ExitVehicle"and f.requests[#f.requests].roundId==3)
local button=find(f,"TextButton","ExitVehicle")
assert(button.Visible and button.Size.X.Offset==112 and button.Size.Y.Offset==56)
button.Activated:Fire();assert(f.requests[#f.requests].kind=="ExitVehicle")
f.typing(true);assert(action.fn("exit",r.Enum.UserInputState.Begin)==r.Enum.ContextActionResult.Pass);f.typing(false)
f.humanoid.SeatPart=nil;f.humanoid.Sit=false;f.seat.Occupant=nil;f.hit(nil);f.step(0.2)
assert(f.camera.CameraType==r.Enum.CameraType.Custom and f.camera.CameraSubject==f.humanoid and not button.Visible)
assert(action.fn("exit",r.Enum.UserInputState.Begin)==r.Enum.ContextActionResult.Pass,"walking Space must remain jump")
f.mount();f.step(0.2);f.humanoid.Health=0;f.step(0.2)
assert(f.camera.CameraType==r.Enum.CameraType.Custom,"death must release chase camera")
f.own:SetAttribute("OwnerUserId",2);f.other:SetAttribute("OwnerUserId",1);f.step(0.2)
assert(not f.ownPrompt.Enabled and f.otherPrompt.Enabled,"ownership changes must refresh local prompts")
f.destroy()
assert(next(f.bindings)==nil and next(f.actions)==nil and f.run.RenderStepped:Count()==0)
assert(f.ownPrompt.Enabled and f.otherPrompt.Enabled,"destroy restores local prompt state")
for _,obj in f.made do assert(obj.Activated:Count()==0 and obj.InputBegan:Count()==0)end
local mobile=setup(true);mobile.mount();mobile.step(0.2)
find(mobile,"TextButton","ExitVehicle").Activated:Fire()
assert(mobile.requests[#mobile.requests].kind=="ExitVehicle")
assert(string.find(find(mobile,"TextLabel","DrivingHint").Text,"오른쪽 하차"))
mobile.destroy();assert(mobile.camera.CameraType==r.Enum.CameraType.Custom)
print("PASS scooter ownership/labels, follow-camera position/smoothing/wall/death/release, high-priority exit, touch button and cleanup (mocks; not Studio)")
