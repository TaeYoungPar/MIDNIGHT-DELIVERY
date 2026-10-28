--!strict
-- 순수 주문 규칙. 위치/방향/홀드 시간은 엔진 연결층이 서버에서 검증해 전달한다.
local Order = {}
Order.__index = Order
export type Spec = { kind: string, destination: string, title: string, hint: string }
export type Outcome = { success: boolean, reward: number, reason: string, index: number }
type Settings = { Duration: number, GhostHold: number, GhostCooldown: number, GiantHot: number, GiantCalm: number, FakeLock: number }
type State = {
	settings: Settings, specs: { Spec }, index: number, expiresAt: number, stage: string,
	startedAt: number, cooldownUntil: number, knocks: number, lastKnock: number,
	holdUntil: number, holder: number?, attempts: number, mistakes: number, late: boolean,
	pending: Outcome?, successes: number, failures: number,
}
export type Model = typeof(setmetatable({} :: State, Order))

function Order.new(settings: Settings, specs: { Spec }): Model
	return setmetatable({ settings = settings, specs = specs, index = 0, expiresAt = 0, stage = "IDLE",
		startedAt = 0, cooldownUntil = 0, knocks = 0, lastKnock = -math.huge, holdUntil = 0,
		holder = nil, attempts = 0, mistakes = 0, late = false, pending = nil, successes = 0, failures = 0 }, Order)
end
function Order.current(self: Model): Spec?
	return self.specs[self.index]
end
function Order.advance(self: Model, now: number): boolean
	if self.index >= #self.specs then self.stage = "DONE"; return false end
	self.index += 1
	self.stage, self.startedAt, self.expiresAt = "ACTIVE", now, now + self.settings.Duration
	self.cooldownUntil, self.knocks, self.lastKnock = 0, 0, -math.huge
	self.holdUntil, self.holder, self.attempts, self.mistakes, self.late = 0, nil, 0, 0, false
	return true
end
function Order.resolve(self: Model, success: boolean, reward: number, reason: string)
	if self.stage == "RESOLVED" or self.stage == "DONE" or self.stage == "IDLE" then return end
	self.stage = "RESOLVED"
	if success then self.successes += 1 else self.failures += 1 end
	self.pending = { success = success, reward = reward, reason = reason, index = self.index }
end
function Order.takeOutcome(self: Model): Outcome?
	local result = self.pending
	self.pending = nil
	return result
end
function Order.tick(self: Model, now: number, holderValid: boolean): boolean
	local spec = self:current()
	if not spec or self.stage == "RESOLVED" or self.stage == "DONE" then return false end
	if now >= self.expiresAt then self:resolve(false, 0, "주문 시간 초과"); return true end
	if self.stage == "COOLDOWN" and now >= self.cooldownUntil then self.stage = "ACTIVE"; return true end
	if spec.kind == "Giant" and not self.late and now >= self.startedAt + self.settings.GiantHot then
		self.late, self.stage = true, "CALM"
		return true
	end
	if self.stage == "HOLDING" then
		if not holderValid then
			self.attempts += 1
			self.knocks, self.holder = 0, nil
			if self.attempts >= 3 then self:resolve(false, 0, "유령 규칙 3회 위반")
			else self.stage, self.cooldownUntil = "COOLDOWN", now + self.settings.GhostCooldown end
			return true
		elseif now >= self.holdUntil then self:resolve(true, 80, "유령 배달 성공"); return true end
	end
	return false
end
function Order.interact(self: Model, destination: string, userId: number, now: number, heldFor: number): boolean
	local spec = self:current()
	if not spec or now >= self.expiresAt or (self.stage ~= "ACTIVE" and self.stage ~= "CALM") then return false end
	if spec.kind == "Fake" then
		if not string.match(destination, "^fake_[123]$") then return false end
		if destination == spec.destination then self:resolve(true, 80, "진짜 주소를 찾았습니다")
		else
			self.mistakes += 1
			if self.mistakes >= 2 then self:resolve(false, 0, "가짜 집 2회 오배송")
			else self.stage, self.cooldownUntil = "COOLDOWN", now + self.settings.FakeLock end
		end
	elseif destination ~= spec.destination then return false
	elseif spec.kind == "Ghost" then
		if now - self.lastKnock < 0.6 then return false end
		self.lastKnock, self.knocks = now, self.knocks + 1
		if self.knocks == 3 then
			self.stage, self.holder, self.holdUntil = "HOLDING", userId, now + self.settings.GhostHold
		end
	elseif spec.kind == "Giant" then
		-- 90초 경계에서 Heartbeat보다 프롬프트가 먼저 도착해도 할인 규칙이 적용된다.
		local isLate = self.late or now >= self.startedAt + self.settings.GiantHot
		if isLate and heldFor < self.settings.GiantCalm then return false end
		self.late = isLate
		self:resolve(true, if self.late then 56 else 80, if self.late then "거인 진정 성공 · 식은 음식" else "따뜻한 음식 배달 성공")
	else return false end
	return true
end
return Order
