--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Types = require(Shared:WaitForChild("Types"))
local Factory = require(script.Parent.Parent.UI.UIFactory)
local HUD = {}

function HUD.start()
	local player = Players.LocalPlayer
	local ui = Factory.create(player:WaitForChild("PlayerGui"))
	local state: Types.Snapshot? = nil
	local collapsed, toastUntil = false, 0
	local connections = {}
	local function render()
		if not state then return end
		ui.phase.Text = Strings[state.phase] or state.phase
		ui.stats.Text = string.format("%d Coins  ·  %d XP  ·  팀 %d/4", state.coins, state.xp, state.playerCount)
		if state.phase == "RESULTS" then
			ui.title.Text = state.result
			ui.hint.Text = string.format("성공 %d / 실패 %d · +%d Coins\n잠시 후 다음 배달을 준비합니다.", state.successes, state.failures, state.reward)
		elseif not state.participant and state.phase ~= "WAITING" then
			ui.title.Text, ui.hint.Text = "로비 대기", Strings.Spectator
		elseif state.phase == "PLAYING" or state.phase == "PREPARING" then
			ui.title.Text, ui.hint.Text = state.orderTitle, state.orderHint
		else
			ui.title.Text, ui.hint.Text = Strings.Title, "자동으로 시작합니다.\n주문 확인 → 네온 길 따라 이동 → 현관 배달"
		end
		ui.hint.Visible = not collapsed
		ui.card.Size = UDim2.fromOffset(math.min(300, math.max(190, ui.root.AbsoluteSize.X - 140)), if collapsed then 42 else 142)
		ui.stats.Position = UDim2.fromOffset(16, if collapsed then 134 else 234)
		ui.note.Position = UDim2.fromOffset(16, if collapsed then 160 else 260)
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
		update = function(snapshot: Types.Snapshot?)
			if not snapshot or (state and snapshot.version < state.version) then return end
			state = snapshot
			render()
		end,
		feedback = function(message: string)
			ui.toast.Text, toastUntil = message, workspace:GetServerTimeNow() + 4
		end,
		destroy = function()
			for _, connection in connections do connection:Disconnect() end
			ui.gui:Destroy()
		end,
	}
end

return HUD
