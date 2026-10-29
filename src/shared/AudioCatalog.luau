--!strict
-- Roblox 공식 Core-Scripts의 기본 캐릭터 효과음 경로. 숫자 에셋 ID/외부 업로드가 없다.
-- 임시 음색이며 전용 야간 배경음/차량 녹음으로 교체 가능한 단일 카탈로그다.
return table.freeze({
	Receipt = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35, pitch = 1.5 },
	Success = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4, pitch = 1.25 },
	Danger = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.4, pitch = 0.8 },
	Down = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.4, pitch = 0.65 },
	Recover = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35, pitch = 1 },
	Wind = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.04, pitch = 0.65 },
	Motor = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.13, pitch = 0.65 },
})
