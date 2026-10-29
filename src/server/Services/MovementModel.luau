--!strict
-- 스프린트와 차량 수치는 순수 함수로 검사한다. 클라이언트 속도 주장은 받지 않는다.
local Model = {}
export type Stamina = { value: number, exhausted: boolean }
function Model.stamina(state: Stamina, wants: boolean, moving: boolean, enabled: boolean, dt: number): number
	dt = math.clamp(dt, 0, 0.2)
	local running = wants and moving and enabled and not state.exhausted and state.value > 0
	state.value = math.clamp(state.value + (if running then -dt else dt), 0, 5)
	if state.value <= 0.001 then state.exhausted = true end
	if state.value >= 4.999 then state.exhausted = false end
	return if running then 22 else 16
end
function Model.speed(speed: number, throttle: number, dt: number, maximum: number?): number
	local target = if throttle >= 0 then throttle * (maximum or 38) else throttle * 12
	local rate = if throttle == 0 then 26 else 18
	return speed + math.clamp(target - speed, -rate * dt, rate * dt)
end
function Model.input(throttle: any, steer: any): boolean
	return typeof(throttle) == "number" and typeof(steer) == "number" and throttle == throttle and steer == steer
		and math.abs(throttle) <= 1 and math.abs(steer) <= 1
end
return Model
