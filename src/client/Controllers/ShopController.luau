--!strict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog=require(Shared:WaitForChild("Catalogs"))
local Types=require(Shared:WaitForChild("Types"))
local Controller={}
function Controller.start(remote: RemoteEvent)
	local state: Types.Snapshot?=nil
	local connections,rows={},{}
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.ScreenInsets="MidnightShop",false,20,Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
	local function label(parent,text,position,size,fontSize)
		local l=Instance.new("TextLabel")
		l.Text,l.Position,l.Size,l.TextSize,l.Parent=text,position,size,fontSize,parent
		l.BackgroundTransparency,l.TextColor3,l.TextWrapped,l.Font=1,Color3.fromRGB(246,244,235),true,Enum.Font.GothamMedium
		l.TextXAlignment=Enum.TextXAlignment.Left
		return l
	end
	local function button(parent,text,position,size)
		local b=Instance.new("TextButton")
		b.Text,b.Position,b.Size,b.Parent=text,position,size,parent
		b.BackgroundColor3,b.TextColor3,b.TextSize,b.Font=Color3.fromRGB(255,170,69),Color3.fromRGB(17,25,44),15,Enum.Font.GothamBold
		local c=Instance.new("UICorner");c.Parent=b
		return b
	end
	local open=button(gui,"꾸미기 상점",UDim2.new(1,-124,0,240),UDim2.fromOffset(112,44))
	local overlay=Instance.new("Frame")
	overlay.Size,overlay.BackgroundColor3,overlay.BackgroundTransparency,overlay.Visible,overlay.Parent=UDim2.fromScale(1,1),Color3.fromRGB(5,8,18),0.2,false,gui
	overlay.Active=true
	local panel=Instance.new("Frame")
	panel.Size,panel.AnchorPoint,panel.Position=UDim2.new(1,-24,1,-24),Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	panel.BackgroundColor3,panel.BorderSizePixel,panel.Parent=Color3.fromRGB(27,39,64),0,overlay
	local limit=Instance.new("UISizeConstraint");limit.MaxSize,limit.Parent=Vector2.new(520,430),panel
	local corner=Instance.new("UICorner");corner.Parent=panel
	label(panel,"야식 본부 · 꾸미기",UDim2.fromOffset(14,6),UDim2.new(1,-76,0,32),20)
	local close=button(panel,"닫기",UDim2.new(1,-68,0,5),UDim2.fromOffset(58,44))
	local balance=label(panel,"",UDim2.fromOffset(14,42),UDim2.new(1,-28,0,26),15)
	local note=label(panel,"",UDim2.fromOffset(14,72),UDim2.new(1,-28,0,40),12)
	local list=Instance.new("ScrollingFrame")
	list.Position,list.Size,list.BackgroundTransparency,list.BorderSizePixel=UDim2.fromOffset(10,120),UDim2.new(1,-20,1,-130),1,0
	list.CanvasSize,list.AutomaticCanvasSize,list.ScrollBarThickness,list.Parent=UDim2.new(),Enum.AutomaticSize.Y,5,panel
	local layout=Instance.new("UIListLayout");layout.Padding,layout.Parent=UDim.new(0,8),list
	for index,item in Catalog do
		local card=Instance.new("Frame")
		card.Size,card.BackgroundColor3,card.BorderSizePixel,card.LayoutOrder,card.Parent=UDim2.new(1,-8,0,84),Color3.fromRGB(40,54,80),0,index,list
		local c=Instance.new("UICorner");c.Parent=card
		label(card,item.name,UDim2.fromOffset(10,5),UDim2.new(1,-125,0,28),16)
		label(card,item.description.." · Lv."..item.level,UDim2.fromOffset(10,35),UDim2.new(1,-125,0,42),12)
		local action=button(card,"",UDim2.new(1,-112,0,20),UDim2.fromOffset(102,46))
		rows[item.id]=action
		table.insert(connections,action.Activated:Connect(function()
			if not state or state.data.mode~="READY" then return end
			if state.owned[item.id] then remote:FireServer({kind="EquipCosmetic",roundId=state.roundId,itemId=item.id,enabled=state.equipped[item.slot]~=item.id})
			elseif state.coins>=item.price and state.level>=item.level then remote:FireServer({kind="PurchaseWithCoins",roundId=state.roundId,itemId=item.id}) end
		end))
	end
	table.insert(connections,open.Activated:Connect(function()overlay.Visible=not overlay.Visible end))
	table.insert(connections,close.Activated:Connect(function()overlay.Visible=false end))
	return {
		update=function(snapshot: Types.Snapshot)
			state=snapshot
			open.Visible=snapshot.downUntil<=workspace:GetServerTimeNow() and not snapshot.vehicle.seated
			if not open.Visible then overlay.Visible=false end
			balance.Text=string.format("Lv.%d · %d XP · %d Coins",snapshot.level,snapshot.xp,snapshot.coins)
			note.Text=if snapshot.data.mode=="READY" then (if snapshot.data.dirty then "변경 저장 대기 · 라운드는 계속 진행됩니다" else "Coins 전용 상점 · 라운드는 계속 진행됩니다")
				elseif snapshot.data.mode=="SAVING" then "저장 중입니다. 잠시 기다려주세요."
				else "상점 잠김 · 프로필 로딩/저장 연결을 확인하세요. 세션 전용 데이터는 저장하지 않습니다."
			for _,item in Catalog do
				local b=rows[item.id]
				b.AutoButtonColor=snapshot.data.mode=="READY"
				b.Text=if snapshot.data.mode~="READY" then "잠김"
					elseif snapshot.owned[item.id] then (if snapshot.equipped[item.slot]==item.id then "해제" else "장착")
					elseif snapshot.level<item.level then "Lv."..item.level.." 필요"
					elseif snapshot.coins<item.price then item.price.." Coins\n잔액 부족" else item.price.." Coins"
			end
		end,
		destroy=function()for _,connection in connections do connection:Disconnect()end;gui:Destroy()end,
	}
end
return Controller
