--!strict
local SoundService = game:GetService("SoundService")
local Content = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AudioCatalog"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Controller = {}
function Controller.start(settings)
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume, group.Parent = "MidnightAudio", 1, SoundService
	local sounds, connections = {}, {}
	local routed = setmetatable({}, {__mode = "k"})
	local silencedSteps = {}
	local stopped, muted = false, false
	local previous: Types.Snapshot? = nil
	for name, definition in Catalog do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Volume, sound.PlaybackSpeed = name, definition.id, definition.volume, definition.pitch
		sound.Looped, sound.SoundGroup, sound.Parent = name == "Wind" or name == "Motor", group, SoundService
		sounds[name] = sound
	end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.ScreenInsets = "MidnightAudioControls", false, Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local mute = Instance.new("TextButton")
	mute.Size, mute.Position, mute.Parent = UDim2.fromOffset(100,44), UDim2.new(1,-112,0,136), gui
	mute.BackgroundColor3, mute.TextColor3, mute.Font, mute.TextSize = Color3.fromRGB(27,39,64), Color3.fromRGB(246,244,235), Enum.Font.GothamMedium, 14
	mute.Text = "소리 켜짐"
	local corner = Instance.new("UICorner"); corner.Parent = mute
	if settings then settings.register(mute) end
	local function route(instance)
		if instance:IsA("Sound") and not instance.SoundGroup then instance.SoundGroup = group; routed[instance] = true end
	end
	for _, instance in workspace:GetDescendants() do route(instance) end
	table.insert(connections,workspace.DescendantAdded:Connect(route))
	table.insert(connections,mute.Activated:Connect(function()
		if settings then settings.set("muted",not settings.get().muted)
		else
			muted = not muted; group.Volume = if muted then 0 else 1
			mute.Text = if muted then "소리 꺼짐" else "소리 켜짐"
		end
	end))
	local disconnectSettings=nil
	if settings then disconnectSettings=settings.subscribe(function(options)
		muted=options.muted;group.Volume=if muted or options.loaded==false then 0 else 1
		mute.Text=if muted then "소리 꺼짐"else"소리 켜짐"
	end)end
	local function play(name: string)
		local sound = sounds[name]
		if sound then sound.TimePosition = 0; sound:Play() end
	end
	task.spawn(function()
		local list = {}; for _, sound in sounds do table.insert(list,sound) end
		local ok, err = pcall(function()
			Content:PreloadAsync(list,function(id,status)
				if not stopped and status ~= Enum.AssetFetchStatus.Success then warn("[MidnightDelivery] Audio unavailable: " .. id) end
			end)
		end)
		if not stopped then
			if not ok then warn("[MidnightDelivery] Audio preload failed: " .. tostring(err)) end
			sounds.Wind:Play()
		end
	end)
	local function restoreSteps()
		for sound, volume in silencedSteps do
			if sound.Parent then sound.Volume = volume end
		end
		table.clear(silencedSteps)
	end
	local elapsed, dangerAt = 0, 0
	table.insert(connections,RunService.RenderStepped:Connect(function(dt)
		local p = Players.LocalPlayer
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local model = seat and seat.Parent
		local riding = humanoid and humanoid.Health > 0 and humanoid.Sit and seat and seat:IsA("VehicleSeat")
			and model and model:GetAttribute("VehicleId") ~= nil and model:GetAttribute("OwnerUserId") == p.UserId
		if riding then
			local speed = model:GetAttribute("Speed") or 0
			local ratio = math.clamp(speed/38,0,1)
			-- 정차 때도 낮은 공회전을 유지하고 복제되는 속도 값 사이를 부드럽게 연결한다.
			local alpha = 1-math.exp(-8*math.min(dt,0.1))
			sounds.Motor.PlaybackSpeed += (Catalog.Motor.pitch+ratio*1.05-sounds.Motor.PlaybackSpeed)*alpha
			sounds.Motor.Volume += (0.07+ratio*(Catalog.Motor.volume-0.07)-sounds.Motor.Volume)*alpha
			if not sounds.Motor.Playing then sounds.Motor:Play() end
			-- 좌석 이동을 걷기로 오인해 재생되는 기본 Running 소리도 탑승 중에만 억제한다.
			for _, instance in p.Character:GetDescendants() do
				if instance:IsA("Sound") and instance.Name == "Running" then
					if silencedSteps[instance] == nil then silencedSteps[instance] = instance.Volume end
					instance.Volume = 0
				end
			end
		else
			if sounds.Motor.Playing then sounds.Motor:Stop() end
			sounds.Motor.PlaybackSpeed, sounds.Motor.Volume = Catalog.Motor.pitch, 0.07
			restoreSteps()
		end
		elapsed += dt; if elapsed < 0.1 then return end; elapsed = 0
		if previous and previous.chase.endsAt > workspace:GetServerTimeNow() and os.clock() > dangerAt then
			play("Danger"); dangerAt = os.clock()+1.2
		end
	end))
	return {
		update = function(snapshot: Types.Snapshot)
			if previous then
				if snapshot.coins > previous.coins then play("Success")
				elseif snapshot.downUntil > previous.downUntil and snapshot.downUntil > 0 then play("Down")
				elseif previous.downUntil > 0 and snapshot.downUntil == 0 then play("Recover")
				elseif snapshot.orderIndex ~= previous.orderIndex or (snapshot.phase == "PREPARING" and previous.phase ~= snapshot.phase) then play("Receipt") end
			end
			previous = snapshot
		end,
		destroy = function()
			stopped = true
			for _, connection in connections do connection:Disconnect() end
			restoreSteps()
			for sound in routed do if sound.Parent and sound.SoundGroup == group then sound.SoundGroup = nil end end
			for _, sound in sounds do sound:Destroy() end
			if disconnectSettings then disconnectSettings()end
			mute:Destroy();group:Destroy(); gui:Destroy()
		end,
	}
end
return Controller
