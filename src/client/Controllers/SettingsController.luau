--!strict
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Controller={}
function Controller.start(remote: RemoteEvent)
	local prefs={muted=false,reducedMotion=false,largeText=false,hudMode="auto"}
	local pending,subscribers,connections={}, {},{}
	local state=nil
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.ScreenInsets="MidnightSettings",false,25,Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
	local function button(parent,text)
		local b=Instance.new("TextButton")
		b.Text,b.Size,b.BackgroundColor3,b.TextColor3,b.Font,b.TextSize,b.Parent=text,UDim2.new(1,0,0,44),Color3.fromRGB(27,39,64),Color3.fromRGB(246,244,235),Enum.Font.GothamMedium,15,parent
		local c=Instance.new("UICorner");c.Parent=b
		return b
	end
	local gear=button(gui,"메뉴")
	gear.Size,gear.Position=UDim2.fromOffset(44,44),UDim2.new(1,-56,0,16)
	local drawer=Instance.new("ScrollingFrame")
	drawer.AnchorPoint,drawer.Position,drawer.Size=Vector2.new(1,0),UDim2.new(1,-12,0,68),UDim2.new(0,210,1,-84)
	drawer.BackgroundColor3,drawer.BorderSizePixel,drawer.Visible,drawer.Parent=Color3.fromRGB(17,25,44),0,false,gui
	drawer.Active=true
	drawer.CanvasSize,drawer.AutomaticCanvasSize,drawer.ScrollBarThickness=UDim2.new(),Enum.AutomaticSize.Y,4
	local constraint=Instance.new("UISizeConstraint");constraint.MaxSize,constraint.Parent=Vector2.new(210,276),drawer
	local padding=Instance.new("UIPadding");padding.PaddingLeft,padding.PaddingRight,padding.PaddingTop,padding.PaddingBottom=UDim.new(0,8),UDim.new(0,8),UDim.new(0,8),UDim.new(0,8);padding.Parent=drawer
	local layout=Instance.new("UIListLayout");layout.Padding,layout.SortOrder,layout.Parent=UDim.new(0,8),Enum.SortOrder.LayoutOrder,drawer
	local panel=Instance.new("ScrollingFrame")
	panel.Active=true
	panel.CanvasSize,panel.AutomaticCanvasSize,panel.ScrollBarThickness=UDim2.new(),Enum.AutomaticSize.Y,4
	panel.AnchorPoint,panel.Position,panel.Size,panel.BackgroundColor3,panel.Visible,panel.Parent=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.new(1,-24,1,-24),Color3.fromRGB(17,25,44),false,gui
	local limit=Instance.new("UISizeConstraint");limit.MaxSize,limit.Parent=Vector2.new(420,334),panel
	local pad=Instance.new("UIPadding");pad.PaddingTop,pad.PaddingBottom,pad.PaddingLeft,pad.PaddingRight=UDim.new(0,10),UDim.new(0,10),UDim.new(0,10),UDim.new(0,10);pad.Parent=panel
	local list=Instance.new("UIListLayout");list.Padding,list.Parent=UDim.new(0,7),panel
	local status=Instance.new("TextLabel")
	status.Size,status.BackgroundTransparency,status.TextColor3,status.TextWrapped,status.TextSize,status.Parent=UDim2.new(1,0,0,44),1,Color3.fromRGB(246,244,235),true,14,panel
	local controls={}
	for _,key in {"muted","reducedMotion","largeText","hudMode"}do controls[key]=button(panel,"")end
	local close=button(panel,"닫기")
	local index=0
	local function register(b)
		index+=1;b.LayoutOrder=index;b.Position=UDim2.new();b.Size=UDim2.new(1,-4,0,44);b.Parent=drawer
		table.insert(connections,b.Activated:Connect(function()drawer.Visible=false end))
	end
	local open=button(gui,"화면·접근성 설정");register(open)
	local function get()
		local value=table.clone(prefs)
		value.loaded=state~=nil and state.data.mode~="LOADING"
		value.menuOpen=drawer.Visible or panel.Visible
		value.compactHUD=if prefs.hudMode=="auto"then UIS.TouchEnabled else prefs.hudMode=="compact"
		return value
	end
	local function redraw()
		controls.muted.Text="소리: "..(if prefs.muted then "꺼짐"else"켜짐")
		controls.reducedMotion.Text="알림 애니메이션: "..(if prefs.reducedMotion then "줄이기"else"기본")
		controls.largeText.Text="HUD 글자: "..(if prefs.largeText then "크게"else"기본")
		controls.hudMode.Text="주문 카드: "..(if prefs.hudMode=="auto"then"기기 자동"elseif prefs.hudMode=="compact"then"접기"else"펼치기")
		status.Text=if state and (state.data.mode=="READY" or state.data.mode=="SAVING")then "화면 설정 · 자동 저장"else"화면 설정 · 현재 접속에 적용 · 저장 미연결"
		for _,fn in subscribers do fn(get())end
	end
	local function set(key,value)
		prefs[key]=value;pending[key]={value=value,time=os.clock(),sent=state~=nil and state.data.mode~="LOADING"}
		if state and state.data.mode~="LOADING"then remote:FireServer({kind="SetPreference",roundId=state.roundId,key=key,value=value})end
		redraw()
	end
	for _,key in {"muted","reducedMotion","largeText"}do table.insert(connections,controls[key].Activated:Connect(function()set(key,not prefs[key])end))end
	table.insert(connections,controls.hudMode.Activated:Connect(function()set("hudMode",if prefs.hudMode=="auto"then"compact"elseif prefs.hudMode=="compact"then"expanded"else"auto")end))
	table.insert(connections,gear.Activated:Connect(function()drawer.Visible=not drawer.Visible;panel.Visible=false end))
	table.insert(connections,open.Activated:Connect(function()panel.Visible=true end))
	table.insert(connections,close.Activated:Connect(function()panel.Visible=false end))
	redraw()
	return {
		get=get,set=set,register=register,
		subscribe=function(fn)table.insert(subscribers,fn);fn(get());return function()local i=table.find(subscribers,fn);if i then table.remove(subscribers,i)end end end,
		update=function(snapshot)
			state=snapshot
			if snapshot.data.mode~="LOADING"then
				for key,value in snapshot.preferences do
					local p=pending[key]
					if p and not p.sent then remote:FireServer({kind="SetPreference",roundId=snapshot.roundId,key=key,value=p.value});p.sent=true;p.time=os.clock()end
					if not p or p.value==value or os.clock()-p.time>3 then prefs[key]=value;pending[key]=nil end
				end
			end
			redraw()
		end,
		destroy=function()for _,c in connections do c:Disconnect()end;table.clear(subscribers);gui:Destroy()end,
	}
end
return Controller
