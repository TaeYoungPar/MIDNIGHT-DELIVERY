--!strict
local Security = {}
Security.__index = Security
type Record = { character: Model, position: Vector3, time: number, blockedUntil: number }
type State = { records: { [Player]: Record }, requests: { [Player]: number }, interactions: { [Player]: number } }
type Service = typeof(setmetatable({} :: State, Security))

function Security.new(): Service
	return setmetatable({ records = {}, requests = {}, interactions = {} }, Security)
end

function Security.remove(self: Service, player: Player)
	self.records[player], self.requests[player], self.interactions[player] = nil, nil, nil
end

function Security.allowSnapshot(self: Service, player: Player, now: number): boolean
	local last = self.requests[player] or -math.huge
	if now - last < 1 then return false end
	self.requests[player] = now
	return true
end

function Security.sample(self: Service, player: Player, now: number, allowedSpeed: number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		self.records[player] = nil
		return
	end
	local position = root.Position
	-- NaN/Infinity가 거리 비교를 우회하지 못하도록 위치를 먼저 검사한다.
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z
		or math.abs(position.X) > 1e6 or math.abs(position.Y) > 1e6 or math.abs(position.Z) > 1e6 then
		self.records[player] = nil
		return
	end
	local record = self.records[player]
	if not record or record.character ~= character then
		self.records[player] = { character = character, position = position, time = now, blockedUntil = now + 2 }
		return
	end
	-- 허용 속도는 서버가 확인한 좌석 소유/탑승 상태에서만 확장한다.
	local delta = position - record.position
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if horizontal > (allowedSpeed or 28) * (now - record.time) + 8 then record.blockedUntil = now + 3 end
	record.position, record.time = position, now
end

function Security.authorizePosition(self: Service, player: Player, now: number)
	self.records[player] = nil
	self:sample(player, now)
	local record = self.records[player]
	if record then record.blockedUntil = now + 0.5 end
end

function Security.canDeliver(self: Service, player: Player, target: Vector3, maxDistance: number, now: number, cooldown: number): boolean
	local record = self.records[player]
	if not record or now < record.blockedUntil then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
	local distance = (root.Position - target).Magnitude
	if distance ~= distance or distance > maxDistance then return false end
	if now - (self.interactions[player] or -math.huge) < cooldown then return false end
	self.interactions[player] = now
	return true
end

return Security
