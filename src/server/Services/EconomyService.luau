--!strict
-- P1은 세션 재화만 제공한다. 영구 저장 기능으로 오해하지 않도록 HUD에도 표시한다.
local Economy = {}
Economy.__index = Economy
type Profile = { coins: number, xp: number }
type State = { profiles: { [number]: Profile }, paid: { [number]: boolean }, roundId: number }
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

function Economy.award(self: Service, player: any, roundId: number, coins: number, xp: number): boolean
	if roundId < self.roundId then return false end
	if roundId > self.roundId then self.roundId = roundId; table.clear(self.paid) end
	local id = player.UserId
	if self.paid[id] or not self.profiles[id] then return false end
	self.paid[id] = true
	local profile = self.profiles[id]
	profile.coins += coins
	profile.xp += xp
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("XP", profile.xp)
	return true
end

return Economy
