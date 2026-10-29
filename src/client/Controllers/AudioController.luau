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
	local elapsed, dangerAt = 0, 0
	table.insert(connections,RunService.RenderStepped:Connect(function(dt)
		elapsed += dt; if elapsed < 0.1 then return end; elapsed = 0
		local p = Players.LocalPlayer
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local model = seat and seat.Parent
		local speed = if model then model:GetAttribute("Speed") or 0 else 0
		if speed > 1 then
			sounds.Motor.PlaybackSpeed = 0.65 + speed/38*0.9
			if not sounds.Motor.Playing then sounds.Motor:Play() end
		elseif sounds.Motor.Playing then sounds.Motor:Stop() end
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
			for sound in routed do if sound.Parent and sound.SoundGroup == group then sound.SoundGroup = nil end end
			for _, sound in sounds do sound:Destroy() end
			if disconnectSettings then disconnectSettings()end
			mute:Destroy();group:Destroy(); gui:Destroy()
		end,
	}
end
return Controller
