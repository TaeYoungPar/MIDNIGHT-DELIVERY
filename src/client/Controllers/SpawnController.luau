--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Controller = {}
function Controller.start()
	local player = Players.LocalPlayer
	local stopped = false
	local function orient(character: Model)
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then return end
			local deadline = os.clock() + 5
			while not stopped and player.Character == character and not character:GetAttribute("MidnightSpawnReady") and os.clock() < deadline do task.wait(0.05) end
			if stopped or player.Character ~= character or not character:GetAttribute("MidnightSpawnReady") then return end
			RunService.RenderStepped:Wait()
			if stopped or player.Character ~= character then return end
			local camera = workspace.CurrentCamera
			if not camera then return end
			local forward = Vector3.new(0, 0, 1)
			camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, humanoid
			-- 새 캐릭터마다 한 번만 초기 방향을 잡고 즉시 Roblox 기본 카메라에 조작을 돌려준다.
			camera.CFrame = CFrame.lookAt(root.Position - forward * 14 + Vector3.new(0, 7, 0), root.Position + forward * 12 + Vector3.new(0, 3, 0))
		end)
	end
	local connection = player.CharacterAdded:Connect(orient)
	if player.Character then orient(player.Character) end
	return function() stopped = true; connection:Disconnect() end
end
return Controller
