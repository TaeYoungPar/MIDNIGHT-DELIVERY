--!strict
-- 기절/복귀는 단조 시각과 세대 번호로 관리하여 구조·자동 복귀 경합을 한 번만 처리한다.
local State = {}
State.__index = State
export type Entry = { downUntil: number, protectedUntil: number, generation: number }
type Store = { entries: { [number]: Entry }, duration: number, protection: number }
export type Model = typeof(setmetatable({} :: Store, State))
function State.new(duration: number, protection: number): Model
	return setmetatable({ entries = {}, duration = duration, protection = protection }, State)
end
function State.reset(self: Model, id: number, now: number)
	local previous = self.entries[id]
	self.entries[id] = { downUntil = 0, protectedUntil = now + self.protection, generation = if previous then previous.generation + 1 else 1 }
end
function State.remove(self: Model, id: number) self.entries[id] = nil end
function State.canAct(self: Model, id: number): boolean
	local entry = self.entries[id]
	return entry ~= nil and entry.downUntil == 0
end
function State.down(self: Model, id: number, now: number): boolean
	local entry = self.entries[id]
	if not entry or entry.downUntil ~= 0 or now < entry.protectedUntil then return false end
	entry.downUntil = now + self.duration
	entry.generation += 1
	return true
end
function State.recover(self: Model, id: number, generation: number, now: number): boolean
	local entry = self.entries[id]
	if not entry or entry.downUntil == 0 or entry.generation ~= generation then return false end
	entry.downUntil, entry.protectedUntil = 0, now + self.protection
	entry.generation += 1
	return true
end
return State
