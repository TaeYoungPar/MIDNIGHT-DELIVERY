--!strict
-- Roblox 객체에 의존하지 않는 라운드 상태 머신. now는 서버 시간이 주입된다.
local RoundModel = {}
RoundModel.__index = RoundModel

type Settings = { Waiting: number, Preparing: number, Playing: number, Results: number, MaxPlayers: number }
type State = {
	settings: Settings, phase: string, roundId: number, endsAt: number,
	participants: { [number]: boolean }, orderActive: boolean, result: string,
}
export type Model = typeof(setmetatable({} :: State, RoundModel))

function RoundModel.new(settings: Settings): Model
	return setmetatable({ settings = settings, phase = "WAITING", roundId = 0, endsAt = 0,
		participants = {}, orderActive = false, result = "" }, RoundModel)
end

function RoundModel.remove(self: Model, userId: number)
	self.participants[userId] = nil
end

function RoundModel.tick(self: Model, now: number, userIds: { number }): boolean
	if #userIds == 0 then
		local changed = self.endsAt ~= 0 or self.phase ~= "WAITING"
		self.phase, self.endsAt, self.orderActive = "WAITING", 0, false
		table.clear(self.participants)
		return changed
	end
	if self.phase == "WAITING" and self.endsAt == 0 then
		self.endsAt = now + self.settings.Waiting
		return true
	end
	if self.phase == "PLAYING" and next(self.participants) == nil then
		self.phase, self.result, self.orderActive = "RESULTS", "배달 팀이 모두 나갔습니다", false
		self.endsAt = now + self.settings.Results
		return true
	end
	if now < self.endsAt then return false end
	if self.phase == "WAITING" then
		self.roundId += 1
		table.clear(self.participants)
		-- 서버가 제공한 입장 목록에서 최대 4명만 확정한다. 중도 입장은 끼어들지 않는다.
		for index, userId in userIds do
			if index <= self.settings.MaxPlayers then self.participants[userId] = true end
		end
		self.result = ""
		self.phase, self.endsAt = "PREPARING", now + self.settings.Preparing
	elseif self.phase == "PREPARING" then
		self.phase, self.endsAt, self.orderActive = "PLAYING", now + self.settings.Playing, true
	elseif self.phase == "PLAYING" then
		self.phase, self.result, self.orderActive = "RESULTS", "시간 초과 · 배달 실패", false
		self.endsAt = now + self.settings.Results
	elseif self.phase == "RESULTS" then
		self.phase, self.endsAt = "WAITING", now + self.settings.Waiting
		table.clear(self.participants)
	end
	return true
end

function RoundModel.finish(self: Model, now: number, result: string)
	if self.phase ~= "PLAYING" then return end
	self.orderActive, self.phase, self.result = false, "RESULTS", result
	self.endsAt = now + self.settings.Results
end

function RoundModel.complete(self: Model, userId: number, expectedRound: number, now: number): { number }?
	if self.phase ~= "PLAYING" or not self.orderActive or expectedRound ~= self.roundId
		or not self.participants[userId] or now >= self.endsAt then return nil end
	-- 양보/yield 없이 주문을 먼저 닫아 동시 클릭과 중복 보상을 차단한다.
	self.orderActive, self.phase, self.result = false, "RESULTS", "배달 성공!"
	self.endsAt = now + self.settings.Results
	local recipients = {}
	for id in self.participants do table.insert(recipients, id) end
	return recipients
end

return RoundModel
