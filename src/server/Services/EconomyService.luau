--!strict
-- 지갑은 DataService와 메모리 객체를 공유한다. 지급은 비동기 저장 콜백 밖에서 한 번만 실행한다.
local Economy = {}
Economy.__index = Economy
type Profile = { coins: number, xp: number, lifetimeDeliveries: number? }
type State = { profiles: { [number]: Profile }, paid: { [string]: boolean }, roundId: number, canMutate: ((any) -> boolean)?, onMutation: ((any) -> ())? }
type Service = typeof(setmetatable({} :: State, Economy))

function Economy.new(): Service
	return setmetatable({ profiles = {}, paid = {}, roundId = 0 }, Economy)
end

function Economy.add(self: Service, player: any)
	if not self.profiles[player.UserId] then self.profiles[player.UserId] = { coins = 0, xp = 0 } end
	local profile = self.profiles[player.UserId]
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("XP", profile.xp)
end

function Economy.remove(self: Service, player: any)
	-- 퇴장 기록을 무한히 쌓지 않는다. 현재 주문의 paid 키는 라운드 종료까지 유지한다.
	self.profiles[player.UserId] = nil
end

function Economy.award(self: Service, player: any, roundId: number, coins: number, xp: number, orderId: number?): boolean
	if self.canMutate and not self.canMutate(player) then return false end
	if roundId < self.roundId then return false end
	if roundId > self.roundId then self.roundId = roundId; table.clear(self.paid) end
	local id = player.UserId
	local key = tostring(orderId or 1) .. ":" .. tostring(id)
	if self.paid[key] or not self.profiles[id] then return false end
	self.paid[key] = true
	local profile = self.profiles[id]
	profile.coins = math.min(1000000000,profile.coins + coins)
	profile.xp = math.min(1000000000,profile.xp + xp)
	if (orderId or 1) <= 3 then profile.lifetimeDeliveries = math.min(1000000000,(profile.lifetimeDeliveries or 0)+1) end
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("XP", profile.xp)
	if self.onMutation then self.onMutation(player) end
	return true
end

return Economy
