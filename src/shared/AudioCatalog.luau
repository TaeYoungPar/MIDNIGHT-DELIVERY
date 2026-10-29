--!strict
-- 알림은 Roblox 내장 음색, 차량은 공개 A-Chassis 1.7.2의 ENG_Engine에 실제 지정된 엔진 루프다.
-- 출처/Studio 접근 확인 절차: docs/AUDIO_SOURCES.md. 임의 ID나 발소리 대체 재생을 사용하지 않는다.
return table.freeze({
	Receipt = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35, pitch = 1.5 },
	Success = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4, pitch = 1.25 },
	Danger = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.4, pitch = 0.8 },
	Down = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.4, pitch = 0.65 },
	Recover = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35, pitch = 1 },
	Wind = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.04, pitch = 0.65 },
	Motor = { id = "rbxassetid://6002661882", volume = 0.18, pitch = 0.85 },
})
