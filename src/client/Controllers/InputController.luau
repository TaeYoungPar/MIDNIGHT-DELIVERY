--!strict
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Actions = game:GetService("ContextActionService")
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Controller = {}
function Controller.start(remote: RemoteEvent,settings)
	local player = Players.LocalPlayer
	local state: Types.Snapshot? = nil
	local focused = true
	local connections, inputs, held = {}, {}, {}
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.ScreenInsets = "MidnightControls", false, Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local drive = Instance.new("Frame")
	drive.BackgroundTransparency, drive.Size, drive.AnchorPoint = 1, UDim2.fromOffset(164,104), Vector2.new(0.5,1)
	drive.Position, drive.Parent = UDim2.new(0.53,0,1,-16), gui
	local function send(kind: string, extra: { [string]: any }?)
		if not state then return end
		local payload = extra or {}
		payload.kind, payload.roundId = kind, state.roundId
		remote:FireServer(payload)
	end
	local function button(parent: Instance, label: string, position: UDim2, size: UDim2)
		local b = Instance.new("TextButton")
		b.Text, b.Position, b.Size, b.Parent = label, position, size, parent
		b.BackgroundColor3, b.TextColor3, b.TextSize, b.Font = Color3.fromRGB(27,39,64), Color3.fromRGB(246,244,235), 16, Enum.Font.GothamMedium
		local corner = Instance.new("UICorner"); corner.Parent = b
		return b
	end
	local function holdButton(parent, label, name, position)
		local b = button(parent,label,position,UDim2.fromOffset(48,48))
		table.insert(connections,b.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			inputs[input] = name; held[name] = (held[name] or 0) + 1
		end))
		return b
	end
	holdButton(drive,"↑", "Forward",UDim2.fromOffset(56,0))
	holdButton(drive,"←", "Left",UDim2.fromOffset(0,54))
	holdButton(drive,"↓", "Reverse",UDim2.fromOffset(56,54))
	holdButton(drive,"→", "Right",UDim2.fromOffset(112,54))
	local sprint = holdButton(gui,"달리기","Sprint",UDim2.new(1,-82,1,-160))
	sprint.Size = UDim2.fromOffset(70,48)
	local leave = button(gui,"하차",UDim2.new(1,-16,1,-180),UDim2.fromOffset(112,56))
	leave.Name, leave.AnchorPoint = "ExitVehicle", Vector2.new(1,1)
	leave.BackgroundColor3 = Color3.fromRGB(174,69,40)
	local hint = Instance.new("TextLabel")
	hint.Name, hint.AnchorPoint, hint.Size = "DrivingHint", Vector2.new(0.5,1), UDim2.new(0.85,0,0,40)
	hint.Position = UDim2.new(0.5,0,1,if UIS.TouchEnabled then -124 else -20)
	hint.BackgroundColor3, hint.BackgroundTransparency = Color3.fromRGB(17,25,44), 0.12
	hint.TextColor3, hint.TextSize, hint.Font, hint.TextWrapped = Color3.fromRGB(246,244,235), 15, Enum.Font.GothamMedium, true
	hint.Text = if UIS.TouchEnabled then "방향 버튼으로 운전 · 오른쪽 하차 버튼" else "WASD / 방향키 운전 · X 또는 Space로 하차"
	hint.Parent = gui
	leave.Visible, drive.Visible, hint.Visible = false, false, false
	local reset = button(gui,"차량 복구",UDim2.new(1,-124,0,188),UDim2.fromOffset(112,44))
	if settings then settings.register(reset)end
	table.insert(connections,leave.Activated:Connect(function() send("ExitVehicle") end))
	table.insert(connections,reset.Activated:Connect(function() send("ResetVehicle") end))
	table.insert(connections,UIS.InputEnded:Connect(function(input)
		local name = inputs[input]
		if name then held[name] = math.max(0,(held[name] or 0)-1); inputs[input] = nil end
	end))
	table.insert(connections,UIS.WindowFocusReleased:Connect(function()
		focused = false; table.clear(held); table.clear(inputs)
		send("Sprint",{enabled=false}); send("VehicleInput",{throttle=0,steer=0})
	end))
	table.insert(connections,UIS.WindowFocused:Connect(function() focused = true end))
	local function ridingSeat()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if humanoid and humanoid.Health > 0 and humanoid.Sit and seat and seat:IsA("VehicleSeat")
			and seat.Parent and seat.Parent:GetAttribute("OwnerUserId") == player.UserId then return seat end
		return nil
	end
	-- 기본 차량 점프 처리가 Space 입력을 먼저 소비해도 하차가 서버로 전달되게 한다.
	Actions:BindActionAtPriority("MidnightExitVehicle",function(_,inputState)
		if not ridingSeat() or UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then send("ExitVehicle") end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.X,Enum.KeyCode.Space,Enum.KeyCode.ButtonB)
	local elapsed, sprintElapsed = 0, 0
	table.insert(connections,RunService.RenderStepped:Connect(function(dt)
		elapsed += dt; sprintElapsed += dt
		if elapsed < 0.1 then return end
		elapsed = 0
		local seat = ridingSeat()
		local riding = seat ~= nil
		local down = state and state.downUntil > workspace:GetServerTimeNow()
		drive.Visible = UIS.TouchEnabled and riding and not down
		leave.Visible, sprint.Visible = riding and not down, not riding and not down
		hint.Visible = riding and not down
		reset.Visible = state ~= nil and state.vehicle.owned and (state.phase == "WAITING" or state.participant) and not down
		if state then
			local cooldown = math.max(0,math.ceil(state.vehicle.resetAt-workspace:GetServerTimeNow()))
			reset.Text = if cooldown > 0 then "복구 " .. cooldown .. "초" else "차량 복구"
		end
		sprint.Text = string.format("달리기\n%d%%",math.floor((player:GetAttribute("Stamina") or 5)*20))
		local function pressed(name) return (held[name] or 0) > 0 end
		local typing = UIS:GetFocusedTextBox() ~= nil or (settings and settings.get().menuOpen==true)
		if sprintElapsed >= 0.3 then
			sprintElapsed = 0
			send("Sprint",{enabled=focused and not typing and not riding and not down and (pressed("Sprint") or UIS:IsKeyDown(Enum.KeyCode.LeftShift))})
		end
		if riding and seat and seat:IsA("VehicleSeat") then
			local throttle = if focused and not typing then seat.ThrottleFloat else 0
			local steer = if focused and not typing then seat.SteerFloat else 0
			if focused and not typing then
				if pressed("Forward") or UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then throttle = 1 end
				if pressed("Reverse") or UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then throttle = -1 end
				if pressed("Left") or UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then steer = -1 end
				if pressed("Right") or UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then steer = 1 end
			end
			send("VehicleInput",{throttle=throttle,steer=steer})
		end
	end))
	return {
		update = function(snapshot: Types.Snapshot) state = snapshot end,
		destroy = function()
			Actions:UnbindAction("MidnightExitVehicle")
			for _, connection in connections do connection:Disconnect() end
			reset:Destroy(); gui:Destroy()
		end,
	}
end
return Controller
