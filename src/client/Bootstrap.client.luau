--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Names = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteNames"))
local HUD = require(script.Parent.Controllers.HUDController)
local hud = HUD.start()
local stopSpawn = require(script.Parent.Controllers.SpawnController).start()
local folder = ReplicatedStorage:WaitForChild(Names.Folder, 30)
if not folder then
	hud.feedback("서버 초기화 실패 · Studio Output을 확인하세요")
	error("MidnightDelivery: Remotes unavailable after 30 seconds")
end
local stateRemote = folder:WaitForChild(Names.State)
local feedbackRemote = folder:WaitForChild(Names.Feedback)
local snapshotRemote = folder:WaitForChild(Names.Snapshot)
local controls = require(script.Parent.Controllers.InputController).start(folder:WaitForChild(Names.Action))
local audio = require(script.Parent.Controllers.AudioController).start()
local shop = require(script.Parent.Controllers.ShopController).start(folder:WaitForChild(Names.Action))
local latestVersion = -1
local function update(snapshot)
	if not snapshot or snapshot.version < latestVersion then return end
	latestVersion = snapshot.version
	hud.update(snapshot); controls.update(snapshot); audio.update(snapshot); shop.update(snapshot)
end
local stateConnection = stateRemote.OnClientEvent:Connect(update)
local feedbackConnection = feedbackRemote.OnClientEvent:Connect(hud.feedback)
-- 이벤트를 먼저 구독하여 초기 스냅샷 도중 발생한 상태 전환을 놓치지 않는다.
task.spawn(function()
	for attempt = 1, 3 do
		local ok, snapshot = pcall(function() return snapshotRemote:InvokeServer() end)
		if ok and snapshot then update(snapshot); return end
		task.wait(1.1)
	end
	hud.feedback("상태 동기화 실패 · 다시 입장하세요")
end)
script.Destroying:Connect(function()
	stateConnection:Disconnect()
	feedbackConnection:Disconnect()
	shop.destroy()
	controls.destroy()
	audio.destroy()
	hud.destroy()
	stopSpawn()
end)
print("[MidnightDelivery] Client GUI ready (P5)")
