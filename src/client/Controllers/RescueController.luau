--!strict
local Players = game:GetService("Players")
local Controller = {}

function Controller.start()
	local player = Players.LocalPlayer
	local descendantConnection: RBXScriptConnection? = nil
	local hidden = setmetatable({}, {__mode = "k"})
	local function release()
		if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
		for prompt, enabled in hidden do
			if prompt.Parent then prompt.Enabled = enabled end
		end
		table.clear(hidden)
	end
	local function watch(character: Model)
		release()
		local function hide(instance: Instance)
			-- 본인 캐릭터의 구조 프롬프트만 로컬에서 숨긴다. 팀원의 프롬프트/서버 권한 검사는 유지한다.
			local attachment = instance.Parent
			if instance:IsA("ProximityPrompt") and attachment and attachment:IsA("Attachment")
				and attachment.Name == "MidnightRescue" and instance:IsDescendantOf(character) then
				if hidden[instance] == nil then hidden[instance] = instance.Enabled end
				instance.Enabled = false
			end
		end
		descendantConnection = character.DescendantAdded:Connect(hide)
		for _, instance in character:GetDescendants() do hide(instance) end
	end
	local added = player.CharacterAdded:Connect(watch)
	local removing = player.CharacterRemoving:Connect(release)
	if player.Character then watch(player.Character) end
	return function()
		added:Disconnect(); removing:Disconnect(); release()
	end
end
return Controller
