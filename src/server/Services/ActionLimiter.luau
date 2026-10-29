--!strict
-- 하나의 플레이어가 Remote를 몰아서 보내도 엔진 작업량을 제한한다.
local Limiter = {}
Limiter.__index = Limiter
type Entry = { tokens: number, time: number }
type Store = { records: { [number]: Entry } }
export type Model = typeof(setmetatable({} :: Store, Limiter))
function Limiter.new(): Model return setmetatable({ records = {} }, Limiter) end
function Limiter.allow(self: Model, id: number, now: number): boolean
	local entry = self.records[id]
	if not entry then entry = { tokens = 20, time = now }; self.records[id] = entry end
	entry.tokens = math.min(20, entry.tokens + math.max(0, now - entry.time) * 15)
	entry.time = now
	if entry.tokens < 1 then return false end
	entry.tokens -= 1
	return true
end
function Limiter.remove(self: Model, id: number) self.records[id] = nil end
return Limiter
