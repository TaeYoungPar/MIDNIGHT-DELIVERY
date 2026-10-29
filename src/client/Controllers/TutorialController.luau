--!strict
local Players=game:GetService("Players")
local Steps=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TutorialSteps"))
local Controller={}
function Controller.start(remote: RemoteEvent,settings)
	local step,done,manual,pending=1,false,false,false
	local state=nil
	local lastSent=-math.huge
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.ScreenInsets="MidnightTutorial",false,30,Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
	local panel=Instance.new("Frame")
	panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.45),UDim2.new(1,-24,0,218)
	panel.BackgroundColor3,panel.BorderSizePixel,panel.Visible,panel.Parent=Color3.fromRGB(17,25,44),0,false,gui
	local limit=Instance.new("UISizeConstraint");limit.MaxSize,limit.Parent=Vector2.new(480,218),panel
	local corner=Instance.new("UICorner");corner.Parent=panel
	local function label(position,size,font)
		local l=Instance.new("TextLabel")
		l.Position,l.Size,l.TextSize,l.BackgroundTransparency,l.TextColor3,l.TextWrapped,l.Parent=position,size,font,1,Color3.fromRGB(246,244,235),true,panel
		l.Font,l.TextXAlignment=Enum.Font.GothamMedium,Enum.TextXAlignment.Left
		return l
	end
	local title=label(UDim2.fromOffset(14,6),UDim2.new(1,-28,0,32),20)
	local body=label(UDim2.fromOffset(14,44),UDim2.new(1,-28,0,112),16)
	local function button(text,position,size,parent)
		local b=Instance.new("TextButton")
		b.Text,b.Position,b.Size,b.BackgroundColor3,b.TextColor3,b.Font,b.TextSize,b.Parent=text,position,size,Color3.fromRGB(255,170,69),Color3.fromRGB(17,25,44),Enum.Font.GothamMedium,16,parent
		local c=Instance.new("UICorner");c.Parent=b
		return b
	end
	local nextButton=button("다음",UDim2.new(1,-128,1,-54),UDim2.fromOffset(114,44),panel)
	local skip=button("안내 닫기",UDim2.new(0,14,1,-54),UDim2.fromOffset(114,44),panel)
	local replay=button("게임 방법 다시 보기",UDim2.new(),UDim2.fromOffset(180,44),gui)
	settings.register(replay)
	local function render()
		title.Text,body.Text=Steps[step].title,Steps[step].body
		nextButton.Text=if step==#Steps then "알겠어요"else"다음"
		panel.Visible=state~=nil and state.downUntil<=workspace:GetServerTimeNow() and not state.vehicle.seated
			and (manual or ((state.phase=="WAITING" or not state.participant) and state.data.mode~="LOADING" and not state.tutorialSeen and not done))
	end
	local function complete()
		done,manual,pending=true,false,true
		render()
		if state and state.data.mode~="LOADING"then remote:FireServer({kind="TutorialComplete",roundId=state.roundId});lastSent=os.clock()end
	end
	local connections={
		nextButton.Activated:Connect(function()if step<#Steps then step+=1;render()else complete()end end),
		skip.Activated:Connect(complete),
		replay.Activated:Connect(function()step,manual=1,true;render()end),
	}
	return {
		update=function(snapshot)
			state=snapshot
			if snapshot.tutorialSeen then pending=false end
			if pending and snapshot.data.mode~="LOADING"and os.clock()-lastSent>=1 then
				remote:FireServer({kind="TutorialComplete",roundId=snapshot.roundId});lastSent=os.clock()
			end
			render()
		end,
		destroy=function()for _,c in connections do c:Disconnect()end;replay:Destroy();gui:Destroy()end,
	}
end
return Controller
