--!strict
local Theme = require(script.Parent.Theme)
local Strings = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Strings"))
local Factory = {}

local function label(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, fontSize: number, color: Color3?)
	local item = Instance.new("TextLabel")
	item.Name, item.Text, item.Position, item.Size = name, text, position, size
	item.BackgroundTransparency, item.TextColor3, item.TextSize = 1, color or Theme.Text, fontSize
	item.Font, item.TextWrapped = Enum.Font.GothamMedium, true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local function panel(parent: Instance, name: string, position: UDim2, size: UDim2)
	local item = Instance.new("Frame")
	item.Name, item.Position, item.Size = name, position, size
	item.BackgroundColor3, item.BackgroundTransparency, item.BorderSizePixel = Theme.Panel, 0.08, 0
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 14), item
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Transparency, stroke.Parent = Theme.Cyan, 0.65, item
	return item
end

function Factory.create(playerGui: Instance)
	local old = playerGui:FindFirstChild("MidnightHUD")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "MidnightHUD", false, Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent = "SafeRoot", UDim2.fromScale(1, 1), 1, gui
	local header = panel(root, "Header", UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 66))
	label(header, "Brand", Strings.Subtitle, UDim2.fromOffset(14, 6), UDim2.new(1, -150, 0, 20), 14, Theme.Orange)
	local phase = label(header, "Phase", "서버 연결 중…", UDim2.fromOffset(14, 28), UDim2.new(1, -150, 0, 30), 17)
	local timer = label(header, "Timer", "--:--", UDim2.new(0.75, 0, 0, 15), UDim2.new(0.25, -14, 0, 40), 25, Theme.Cyan)
	timer.AnchorPoint=Vector2.new(1,0)
	timer.Position,timer.Size=UDim2.new(1,-58,0,15),UDim2.fromOffset(76,40)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	local card = panel(root, "Order", UDim2.fromOffset(12, 84), UDim2.fromOffset(300, 142))
	local title = label(card, "Title", Strings.Title, UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 25), 18, Theme.Orange)
	local hint = label(card, "Hint", "주문 확인 → 길 따라 이동 → 현관 배달", UDim2.fromOffset(12, 42), UDim2.new(1, -24, 0, 76), 15)
	local toggle = Instance.new("TextButton")
	toggle.Text, toggle.Size, toggle.Position = "주문 접기", UDim2.fromOffset(100, 44), UDim2.new(1, -112, 0, 84)
	toggle.Font, toggle.TextSize, toggle.TextColor3 = Enum.Font.GothamMedium, 14, Theme.Text
	toggle.BackgroundColor3, toggle.Parent = Theme.Panel, root
	local corner = Instance.new("UICorner"); corner.Parent = toggle
	local stats = label(root, "Stats", "", UDim2.fromOffset(16, 234), UDim2.new(1, -140, 0, 44), 14, Theme.Orange)
	local note = label(root, "Note", Strings.SessionOnly, UDim2.fromOffset(16, 260), UDim2.new(1, -140, 0, 54), 12, Theme.Muted)
	local arrow = label(root, "Arrow", "▲", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(44, 44), 32, Theme.Cyan)
	arrow.AnchorPoint, arrow.TextXAlignment = Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center
	local distance = label(root, "Distance", "", UDim2.fromScale(0.5, 0.6), UDim2.fromOffset(210, 32), 14, Theme.Cyan)
	distance.AnchorPoint, distance.TextXAlignment = Vector2.new(0.5, 0), Enum.TextXAlignment.Center
	local recovery = label(root, "Recovery", "", UDim2.new(0.08, 0, 0.58, 0), UDim2.new(0.84, 0, 0, 80), 19, Theme.Orange)
	recovery.TextXAlignment = Enum.TextXAlignment.Center
	local team = label(root, "Team", "", UDim2.new(0, 16, 1, -65), UDim2.new(0.6, 0, 0, 50), 12, Theme.Muted)
	local toast = label(root, "Toast", "", UDim2.new(0.1, 0, 0.72, 0), UDim2.new(0.8, 0, 0, 48), 20, Theme.Orange)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	return { gui = gui, root = root, phase = phase, timer = timer, card = card, title = title, hint = hint,
		toggle = toggle, stats = stats, note = note, arrow = arrow, distance = distance, toast = toast, recovery = recovery, team = team }
end

return Factory
