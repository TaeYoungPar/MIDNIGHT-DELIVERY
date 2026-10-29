--!strict
-- 데이터 파싱/잠금/상점은 순수 함수로 분리한다. UpdateAsync 재호출에서 보상/구매를 실행하지 않는다.
local Model = {}
local MAX = 1000000000
local thresholds = { 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200 }
export type Profile = { schemaVersion: number, coins: number, xp: number, lifetimeDeliveries: number,
	owned: { [string]: boolean }, equipped: { [string]: string } }
export type Row = { schemaVersion: number, profile: Profile, revision: number, updatedAt: number,
	lease: { token: string, expiresAt: number }? }
function Model.default(): Profile
	return { schemaVersion = 1, coins = 0, xp = 0, lifetimeDeliveries = 0, owned = {}, equipped = {hat="",scooter="",badge=""} }
end
function Model.integer(value: any, maximum: number?): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value <= (maximum or MAX) and value % 1 == 0
end
function Model.copy(profile: Profile): Profile
	return { schemaVersion = 1, coins = profile.coins, xp = profile.xp, lifetimeDeliveries = profile.lifetimeDeliveries,
		owned = table.clone(profile.owned), equipped = table.clone(profile.equipped) }
end
function Model.level(xp: number): number
	local level = 1
	for index, threshold in thresholds do if xp >= threshold then level = index end end
	return level
end
function Model.decode(raw: any): (Row?, string?)
	if raw == nil then return {schemaVersion=1,profile=Model.default(),revision=0,updatedAt=0}, nil end
	if typeof(raw) ~= "table" or raw.schemaVersion ~= 1 then return nil,"unsupported_schema" end
	local source = if raw.profile ~= nil then raw.profile else raw
	if typeof(source) ~= "table" or not Model.integer(source.coins) or not Model.integer(source.xp)
		or not Model.integer(if source.lifetimeDeliveries ~= nil then source.lifetimeDeliveries else 0) then return nil,"invalid_currency" end
	if source.schemaVersion ~= nil and source.schemaVersion ~= 1 then return nil,"unsupported_schema" end
	local profile = Model.default()
	profile.coins, profile.xp, profile.lifetimeDeliveries = source.coins, source.xp, if source.lifetimeDeliveries ~= nil then source.lifetimeDeliveries else 0
	local owned = if source.owned ~= nil then source.owned elseif source.ownedCosmetics ~= nil then source.ownedCosmetics else {}
	if typeof(owned) ~= "table" then return nil,"invalid_inventory" end
	local count = 0
	for key, value in owned do
		local id = if typeof(key) == "number" then value else key
		if typeof(id) ~= "string" or #id > 64 or not string.match(id,"^[%w_]+$") or (typeof(key) ~= "number" and value ~= true) then return nil,"invalid_item" end
		profile.owned[id] = true; count += 1
		if count > 100 then return nil,"inventory_too_large" end
	end
	local equipped = if source.equipped ~= nil then source.equipped else {}
	if typeof(equipped) ~= "table" then return nil,"invalid_equipped" end
	for _, slot in {"hat","scooter","badge"} do
		local id = if equipped[slot] ~= nil then equipped[slot] else ""
		if typeof(id) ~= "string" or (#id > 0 and not profile.owned[id]) then return nil,"unowned_equipped" end
		profile.equipped[slot] = id
	end
	-- 최초 기획의 기본 스킨은 별도 파트가 없는 기본 외형으로 이행한다.
	local revision = raw.revision or 0
	if not Model.integer(revision) then return nil,"invalid_revision" end
	local lease = raw.lease
	if lease ~= nil and (typeof(lease) ~= "table" or typeof(lease.token) ~= "string" or #lease.token < 1 or #lease.token > 200
		or not Model.integer(lease.expiresAt,1000000000000)) then return nil,"invalid_lease" end
	return {schemaVersion=1,profile=profile,revision=revision,updatedAt=raw.updatedAt or 0,
		lease=if lease then {token=lease.token,expiresAt=lease.expiresAt} else nil},nil
end
function Model.acquire(raw: any, token: string, now: number, ttl: number): (Row?, string?)
	local row, reason = Model.decode(raw)
	if not row then return nil,reason end
	if row.lease and row.lease.token ~= token and row.lease.expiresAt > now then return nil,"locked" end
	row.lease = {token=token,expiresAt=now+ttl}
	row.updatedAt = now
	return row,nil
end
function Model.write(raw: any, token: string, profile: Profile, now: number, ttl: number, release: boolean): (Row?, string?)
	local row, reason = Model.decode(raw)
	if not row then return nil,reason end
	if not row.lease or row.lease.token ~= token or row.lease.expiresAt <= now then return nil,"lease_lost" end
	row.profile, row.revision, row.updatedAt = Model.copy(profile), row.revision+1, now
	row.lease = if release then nil else {token=token,expiresAt=now+ttl}
	return row,nil
end
function Model.purchase(profile: Profile, item: any): (boolean,string)
	if not item then return false,"없는 상품입니다" end
	if profile.owned[item.id] then return false,"이미 보유하고 있습니다" end
	local count=0;for _ in profile.owned do count+=1 end
	if count>=100 then return false,"보관함이 가득 찼습니다" end
	if Model.level(profile.xp) < item.level then return false,"레벨이 부족합니다" end
	if profile.coins < item.price then return false,"Coins가 부족합니다" end
	profile.coins -= item.price; profile.owned[item.id] = true
	return true,"구매 완료 · 장착을 눌러주세요"
end
function Model.equip(profile: Profile, item: any, enabled: boolean): (boolean,string)
	if not item or not profile.owned[item.id] then return false,"보유하지 않은 상품입니다" end
	profile.equipped[item.slot] = if enabled then item.id else ""
	return true,if enabled then "장착했습니다" else "해제했습니다"
end
return Model
