--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Names = require(ReplicatedStorage.Shared.RemoteNames)
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local RoundService = require(script.Parent.Services.RoundService)

-- 중복 Bootstrap은 기존 실행을 덮어쓰지 않고 명시적으로 중단한다.
assert(not ReplicatedStorage:FindFirstChild(Names.Folder), "MidnightDelivery Remotes already exist; restart Play")
local world = WorldBuilder.build()
local folder = Instance.new("Folder")
folder.Name = Names.Folder
local state = Instance.new("RemoteEvent")
state.Name, state.Parent = Names.State, folder
local feedback = Instance.new("RemoteEvent")
feedback.Name, feedback.Parent = Names.Feedback, folder
local snapshot = Instance.new("RemoteFunction")
snapshot.Name, snapshot.Parent = Names.Snapshot, folder
local action = Instance.new("RemoteEvent")
action.Name, action.Parent = Names.Action, folder
local remotes = { State = state, Feedback = feedback, Snapshot = snapshot, Action = action }
-- 초기화는 yield 없이 진행한다. FireClient 전 Remote가 DataModel에 속하도록 먼저 공개한다.
folder.Parent = ReplicatedStorage
local stop = RoundService.start(world, remotes)
Players.CharacterAutoLoads = true
game:BindToClose(stop)
print("[MidnightDelivery] Server bootstrap ready (P4)")
