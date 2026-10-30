--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local Factory = require(script.Parent.Parent.UI.UIFactory)
local HUD = {}

function HUD.start()
	local player = Players.LocalPlayer
	local ui = Factory.create(player:WaitForChild("PlayerGui"))
	local state: Types.Snapshot? = nil
	local collapsed, toastUntil = UIS.TouchEnabled, 0
	local connections = {}
	local options={reducedMotion=false,largeText=false}
	local previousMode,previousCompact=nil,nil
	local tween=nil
	local fontSizes={}
	for _,item in ui.gui:GetDescendants()do if item:IsA("TextLabel")or item:IsA("TextButton")then fontSizes[item]=item.TextSize end end
	local function render()
		if not state then return end
		ui.phase.Text = Strings[state.phase] or state.phase
		ui.stats.Text = string.format("Lv.%d · %d Coins · 팀 %d/4", state.level, state.coins, state.playerCount)
		ui.note.Text = if state.data.mode=="READY" then (if state.data.dirty then "변경 저장 대기 · 자동 저장" else "영구 저장 연결됨")
			elseif state.data.mode=="SAVING" then "저장 중…"
			elseif state.data.mode=="LOADING" then "프로필 로딩 중 · 참가 대기"
			elseif state.data.mode=="SAVE_ERROR" then "저장 실패 · 재시도 중 · 상점 잠김"
			else "세션 전용 · 이번 진행은 저장되지 않습니다"
		if state.phase == "RESULTS" then
			ui.title.Text = state.result
			ui.hint.Text = string.format("성공 %d / 실패 %d · +%d Coins\n잠시 후 다음 배달을 준비합니다.", state.successes, state.failures, state.reward)
		elseif state.phase == "WAITING" or state.phase == "PREPARING" then
			ui.title.Text = if state.phase == "PREPARING" then "배달가방 준비 중" else "다음 배달 기다리는 중"
			ui.hint.Text = "본부의 주황 출발선 안에서 기다리세요.\n배달이 시작되면 출발선이 열립니다."
		elseif not state.participant then
			ui.title.Text, ui.hint.Text = "로비 대기", Strings.Spectator
		elseif state.phase == "PLAYING" or state.phase == "PREPARING" then
			ui.title.Text, ui.hint.Text = state.orderTitle, state.orderHint
		else
			ui.title.Text, ui.hint.Text = Strings.Title, "자동으로 시작합니다.\n주문 확인 → 네온 길 따라 이동 → 현관 배달"
		end
		ui.hint.Visible = not collapsed
		ui.card.Size = UDim2.fromOffset(math.min(300, math.max(190, ui.root.AbsoluteSize.X - 140)), if collapsed then 42 else (if options.largeText then 164 else 142))
		ui.stats.Position = UDim2.fromOffset(16, if collapsed then 134 else (if options.largeText then 256 else 234))
		ui.note.Position = UDim2.fromOffset(16, if collapsed then 182 else (if options.largeText then 304 else 282))
		ui.toggle.Text = if collapsed then "주문 펼치기" else "주문 접기"
	end
	table.insert(connections, ui.toggle.Activated:Connect(function() collapsed = not collapsed; render() end))
	table.insert(connections, ui.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
	local elapsed = 0
	table.insert(connections, RunService.RenderStepped:Connect(function(delta)
		elapsed += delta
		if elapsed < 0.1 then return end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		if now > toastUntil then ui.toast.Text = "" end
		if not state then return end
		if state.downUntil > now then
			ui.recovery.Text = string.format("기절 · %d초 후 자동 복귀\n팀원이 3초간 눌러 구조할 수 있습니다", math.ceil(state.downUntil - now))
		elseif state.protectedUntil > now then ui.recovery.Text = string.format("보호 중 · %d초", math.ceil(state.protectedUntil - now))
		elseif state.chase.endsAt > now then
			ui.recovery.Text = if state.chase.targetId == player.UserId then "괴물이 쫓아옵니다! 도로를 따라 도망치세요" else "팀원이 추격당하고 있습니다!"
		else ui.recovery.Text = "" end
		local members = {}
		for _, member in state.members do
			local cut=utf8.offset(member.name,11)
			local name=if cut then string.sub(member.name,1,cut-1).."…"else member.name
			table.insert(members, name .. (if member.downUntil > now then " · 구조 필요" else " · 정상"))
		end
		ui.team.Text = table.concat(members, "  /  ")
		local compactTeam=UIS.TouchEnabled or ui.root.AbsoluteSize.Y<500
		ui.team.Visible=not compactTeam
		if compactTeam then
			local down=0;for _,member in state.members do if member.downUntil>now then down+=1 end end
			ui.stats.Text=string.format("Lv.%d · %d Coins\n참가 %d명 · 구조 필요 %d명",state.level,state.coins,#state.members,down)
		end
		if state.phase == "PLAYING" and state.participant then
			local detail = state.orderHint
			if state.stage == "HOLDING" then detail = string.format("문을 향한 채 그대로! %d초", math.max(0, math.ceil(state.holdUntil - now)))
			elseif state.stage == "COOLDOWN" then detail = string.format("규칙 위반 · %d초 후 재시도", math.max(0, math.ceil(state.cooldownUntil - now)))
			elseif state.late then detail = "음식이 식었습니다 · 현관에서 3초간 진정시키기"
			elseif state.hotUntil > 0 then detail = string.format("음식 온도 %d%% · 식기 전에 현관으로!", math.clamp(math.ceil((state.hotUntil - now) / 90 * 100), 0, 100))
			elseif string.find(state.orderTitle, "유령") then detail = string.format("노크 %d/3 · 세 번째 노크 후 4초 정면 유지", state.knocks) end
			ui.hint.Text = detail .. string.format("\n주문 남은 시간 %d초", math.max(0, math.ceil(state.orderEndsAt - now)))
			ui.phase.Text = string.format("배달 %d/3 · 성공 %d", state.orderIndex, state.successes)
		end
		local seconds = math.max(0, math.ceil(state.endsAt - now))
		if state.phase == "RESULTS" then
			ui.phase.Text = string.format("%d판 결과 · 다음 대기까지 %d초",state.roundId or 0,seconds)
		elseif state.phase == "WAITING" then
			ui.phase.Text = if state.endsAt == 0 then "참가자 준비를 기다리는 중" else string.format("다음 판 가방 준비까지 %d초",seconds)
		elseif state.phase == "PREPARING" then
			ui.phase.Text = string.format("%d판 · 출발선 개방까지 %d초",state.roundId or 0,seconds)
		end
		ui.timer.Text = if state.endsAt == 0 then "대기" else string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		local active = state.participant and state.orderActive and root ~= nil and camera ~= nil
		ui.arrow.Visible, ui.distance.Visible = active, active
		if not active or not root or not root:IsA("BasePart") or not camera then return end
		local target = state.target
		if not target then return end
		local projected, onScreen = camera:WorldToViewportPoint(target)
		-- 뒤쪽 목표는 투영 방향을 반전해 화면 가장자리에 안내한다.
		local center = ui.root.AbsoluteSize / 2
		local localPoint = Vector2.new(projected.X, projected.Y) - ui.root.AbsolutePosition
		local direction = localPoint - center
		if projected.Z < 0 then direction = -direction end
		if direction.Magnitude < 1 then direction = Vector2.new(0, -1) end
		local unit = direction.Unit
		local limit = Vector2.new(math.max(40, center.X - 40), math.max(40, center.Y - 50))
		local radius = math.min(limit.X / math.max(math.abs(unit.X), 0.001), limit.Y / math.max(math.abs(unit.Y), 0.001))
		local point = if onScreen then localPoint else center + unit * radius
		point = Vector2.new(math.clamp(point.X, 32, center.X * 2 - 32), math.clamp(point.Y, 84, center.Y * 2 - 50))
		ui.arrow.Position, ui.arrow.Rotation = UDim2.fromOffset(point.X, point.Y), math.deg(math.atan2(unit.Y, unit.X)) + 90
		ui.distance.Position = UDim2.fromOffset(math.clamp(point.X, 105, math.max(105, center.X * 2 - 105)), point.Y + 22)
		ui.distance.Text = string.format("목적지 · %d studs", math.floor((root.Position - target).Magnitude))
	end))
	ui.arrow.Visible, ui.distance.Visible = false, false
	return {
		configure=function(value)
			options=value
			if value.hudMode~=previousMode or value.compactHUD~=previousCompact then collapsed=value.compactHUD end
			previousMode,previousCompact=value.hudMode,value.compactHUD
			for item,size in fontSizes do item.TextSize=math.floor(size*(if value.largeText then 1.15 else 1)+0.5)end
			if value.reducedMotion and tween then tween:Cancel();tween=nil;ui.toast.TextTransparency=0 end
			render()
		end,
		update = function(snapshot: Types.Snapshot?)
			if not snapshot or (state and snapshot.version < state.version) then return end
			state = snapshot
			render()
		end,
		feedback = function(message: string)
			if tween then tween:Cancel();tween=nil end
			ui.toast.Text, toastUntil = message, workspace:GetServerTimeNow() + 4
			ui.toast.TextTransparency=if options.reducedMotion then 0 else 1
			if not options.reducedMotion then
				tween=TweenService:Create(ui.toast,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{TextTransparency=0});tween:Play()
			end
		end,
		destroy = function()
			for _, connection in connections do connection:Disconnect() end
			if tween then tween:Cancel()end
			ui.gui:Destroy()
		end,
	}
end

return HUD
