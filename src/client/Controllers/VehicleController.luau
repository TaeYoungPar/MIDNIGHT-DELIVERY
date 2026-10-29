--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Controller = {}

function Controller.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local entries = {}
	local activeCamera, activeSeat, smoothed = nil, nil, nil
	local armLength = nil
	local binding = "MidnightVehicleCamera"
	local elapsed = 1
	local function releaseCamera()
		if activeCamera then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then activeCamera.CameraSubject = humanoid end
			activeCamera.CameraType = Enum.CameraType.Custom
		end
		activeCamera, activeSeat, smoothed = nil, nil, nil
		armLength = nil
	end
	local function clear(model)
		local entry = entries[model]
		if not entry then return end
		entry.tag:Destroy(); entry.highlight:Destroy()
		if entry.prompt.Parent then entry.prompt.Enabled = entry.enabled end
		entries[model] = nil
	end
	local function discover()
		local world = workspace:FindFirstChild("GameWorld")
		local vehicles = world and world:FindFirstChild("Vehicles")
		for model in entries do if not vehicles or model.Parent ~= vehicles then clear(model) end end
		if not vehicles then return end
		for _, model in vehicles:GetChildren() do
			if entries[model] then continue end
			local seat = model:FindFirstChild("DriverSeat")
			local prompt = seat and seat:FindFirstChildWhichIsA("ProximityPrompt",true)
			if not seat or not seat:IsA("VehicleSeat") or not prompt then continue end
			local tag = Instance.new("BillboardGui")
			tag.Name, tag.Adornee, tag.Size = "ScooterOwner", seat, UDim2.fromOffset(220,58)
			tag.StudsOffsetWorldSpace, tag.MaxDistance = Vector3.new(0,5,0), 150
			tag.Parent = playerGui
			local label = Instance.new("TextLabel")
			label.Size, label.BackgroundColor3, label.BackgroundTransparency = UDim2.fromScale(1,1), Color3.fromRGB(17,25,44), 0.12
			label.Font, label.TextSize, label.TextWrapped = Enum.Font.GothamBold, 16, true
			label.Parent = tag
			local corner = Instance.new("UICorner"); corner.Parent = label
			local highlight = Instance.new("Highlight")
			highlight.Name, highlight.Adornee = "MyScooter", model
			highlight.FillColor, highlight.OutlineColor = Color3.fromRGB(99,216,184), Color3.fromRGB(170,255,230)
			highlight.FillTransparency, highlight.OutlineTransparency = 0.8, 0
			highlight.DepthMode, highlight.Parent = Enum.HighlightDepthMode.AlwaysOnTop, tag
			entries[model] = {seat=seat,prompt=prompt,tag=tag,label=label,highlight=highlight,enabled=prompt.Enabled}
		end
	end
	-- 소유 표시와 프롬프트는 이 클라이언트에서만 바꾼다. 탑승 권한은 서버가 별도로 검증한다.
	local function mark()
		for model, entry in entries do
			local own = model:GetAttribute("OwnerUserId") == player.UserId
			local owner = model:GetAttribute("OwnerName") or ""
			-- Occupant는 NotReplicated 속성이므로 로컬 Humanoid의 탑승 좌석으로 표시를 판단한다.
			entry.prompt.Enabled = own and activeSeat ~= entry.seat
			entry.highlight.Enabled, entry.tag.AlwaysOnTop = own and activeSeat == nil, own
			entry.tag.Enabled = activeSeat == nil
			entry.label.TextColor3 = if own then Color3.fromRGB(170,255,230) else Color3.fromRGB(220,220,220)
			entry.label.Text = if own then "내 스쿠터 · "..tostring(model:GetAttribute("VehicleId")).."번\n"..(if UIS.TouchEnabled then "다가가서 탑승 버튼" else "다가가서 E · 탑승")
				elseif owner ~= "" then owner.."의 스쿠터\n다른 배달원 전용" else "배정 대기"
		end
	end
	RunService:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+1,function(dt)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local model = seat and seat.Parent
		local riding = humanoid and humanoid.Health > 0 and humanoid.Sit and seat and seat:IsA("VehicleSeat")
			and model and model:GetAttribute("OwnerUserId") == player.UserId
		local camera = workspace.CurrentCamera
		if not riding or not camera then
			if activeCamera then releaseCamera() end
		else
			if activeCamera ~= camera or activeSeat ~= seat then
				releaseCamera()
				activeCamera, activeSeat = camera, seat
			end
			-- 고정된 anchored 좌석에 Roblox 기본 차량 카메라가 재진입하지 않도록 뒤쪽 추적 시점을 직접 갱신한다.
			-- 카메라 위치와 주시점이 서로 다른 시간의 좌석을 보지 않도록 차량 프레임 하나를 보간한다.
			-- 복구/큰 위치 보정은 즉시 따라가서 오래된 위치에서 지형을 가로질러 이동하지 않게 한다.
			local desired = seat.CFrame
			if smoothed and (smoothed.Position-desired.Position).Magnitude >= 24 then armLength = nil end
			smoothed = if smoothed and (smoothed.Position-desired.Position).Magnitude < 24
				then smoothed:Lerp(desired,1-math.exp(-12*math.min(dt,0.1))) else desired
			local forward = smoothed.LookVector
			local focus = smoothed.Position + Vector3.new(0,3,0) + forward*3
			local position = smoothed.Position - forward*16 + Vector3.new(0,8,0)
			local params = RaycastParams.new()
			params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Exclude,{model,player.Character},true
			local delta = position-focus
			local hit = workspace:Raycast(focus,delta,params)
			local available = if hit then math.min(delta.Magnitude,math.max(0.1,hit.Distance-0.6)) else delta.Magnitude
			-- 벽 쪽으로는 즉시 줄이되, 벽을 벗어날 때는 천천히 늘려 줌이 번갈아 튀지 않게 한다.
			armLength = if not armLength or available < armLength then available
				else armLength+(available-armLength)*(1-math.exp(-8*math.min(dt,0.1)))
			position = focus + delta.Unit*armLength
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame, camera.Focus = CFrame.lookAt(position,focus), CFrame.new(focus)
		end
		elapsed += dt
		if elapsed >= 0.2 then elapsed = 0; discover(); mark() end
	end)
	return {destroy=function()
		RunService:UnbindFromRenderStep(binding)
		releaseCamera()
		local models={}; for model in entries do table.insert(models,model) end
		for _, model in models do clear(model) end
	end}
end
return Controller
