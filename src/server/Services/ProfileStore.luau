--!strict
local Model = require(script.Parent.ProfileModel)
local Store = {}
Store.__index = Store
export type Session = { profile: Model.Profile, mode: string, reason: string, expiresAt: number,
	version: number, dirty: boolean, busy: boolean, closing: boolean }
type Settings = { adapter: any, now: () -> number, waitFor: (number) -> any, token: string, ttl: number, guard: number }
export type Runtime = typeof(setmetatable({} :: Settings, Store))
-- adapter: UpdateAsync. clocks/wait는 테스트에서 주입하며, 콜백 내부에서는 yield하지 않는다.
function Store.new(adapter: any, now: () -> number, waitFor: (number) -> any, token: string): Runtime
	return setmetatable({adapter=adapter,now=now,waitFor=waitFor,token=token,ttl=180,guard=30},Store)
end
function Store.request(self: Runtime, key: string, transform: (any) -> (Model.Row?, string?)): (Model.Row?, string?)
	local errorReason = "request_failed"
	for attempt=1,3 do
		local reason: string? = nil
		local ok,result = pcall(function()
			return self.adapter:UpdateAsync(key,function(old,info)
				local nextRow, why = transform(old)
				reason = why
				if nextRow and info then return nextRow,info:GetUserIds(),info:GetMetadata() end
				return nextRow
			end)
		end)
		if ok then return result,reason end
		errorReason = "request_failed"
		if attempt < 3 then self.waitFor(2^(attempt-1)) end
	end
	return nil,errorReason
end
function Store.load(self: Runtime, id: number): Session
	local row,reason = self:request("User_"..id,function(old) return Model.acquire(old,self.token,self.now(),self.ttl) end)
	if row and not reason then
		row,reason=Model.decode(row)
		if row and (not row.lease or row.lease.token~=self.token or row.lease.expiresAt<=self.now()+self.guard) then row,reason=nil,"locked" end
	end
	if not row or reason then return {profile=Model.default(),mode="SESSION",reason=reason or "load_failed",expiresAt=0,version=0,dirty=false,busy=false,closing=false} end
	local lease=row.lease
	assert(lease,"Acquired profile must have a lease")
	return {profile=Model.copy(row.profile),mode="READY",reason="",expiresAt=lease.expiresAt,version=0,dirty=false,busy=false,closing=false}
end
function Store.writable(self: Runtime, record: Session): boolean
	if record.mode ~= "READY" and record.mode ~= "SAVE_ERROR" then return false end
	if self.now() >= record.expiresAt-self.guard then
		record.mode,record.reason,record.dirty = "SESSION","lease_expired",false
		return false
	end
	return not record.closing
end
function Store.save(self: Runtime, id: number, record: Session, release: boolean): boolean
	if record.busy or (record.mode ~= "READY" and record.mode ~= "SAVE_ERROR") then return false end
	if self.now() >= record.expiresAt-self.guard then record.mode,record.reason="SESSION","lease_expired";return false end
	record.busy = true
	local snapshot,version = Model.copy(record.profile),record.version
	local row,reason = self:request("User_"..id,function(old)
		if record.mode=="SESSION" then return nil,"lease_lost" end
		return Model.write(old,self.token,snapshot,self.now(),self.ttl,release)
	end)
	record.busy = false
	-- 늦게 온 성공 응답이 이미 세션 전용으로 전환된 핸들의 쓰기 권한을 되살리지 않는다.
	if record.mode=="SESSION" then return false end
	if not row or reason then
		if reason == "request_failed" then record.mode="SAVE_ERROR" else record.mode="SESSION" end
		record.reason = reason or "save_failed"
		return false
	end
	local lease=row.lease
	if not release and not lease then record.mode,record.reason="SESSION","lease_lost";return false end
	record.expiresAt = if lease then lease.expiresAt else 0
	record.dirty = record.version ~= version
	record.mode,record.reason = if release then "CLOSED" else "READY",""
	return true
end
return Store
