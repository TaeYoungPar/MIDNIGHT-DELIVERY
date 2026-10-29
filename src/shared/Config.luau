--!strict
-- 타이머와 보상은 서버에서도 같은 설정을 사용한다. 주문 3건의 제한과 고객별 조건도 중앙에서 관리한다.
return table.freeze({
	Build = "P4 스쿠터·모바일·사운드 / Studio 검증 대기",
	Round = table.freeze({ Waiting = 20, Preparing = 10, Playing = 420, Results = 15, MaxPlayers = 4 }),
	Delivery = table.freeze({ Reward = 80, XP = 20, Distance = 12, Cooldown = 0.6 }),
	Orders = table.freeze({ Duration = 120, GhostHold = 4, GhostCooldown = 10, GiantHot = 90, GiantCalm = 3, FakeLock = 10 }),
	Vehicle = table.freeze({ ResetCooldown = 15, MaxSpeed = 38 }),
	Recovery = table.freeze({ DownTime = 12, Protection = 4, RescueHold = 3, RescueDistance = 8,
		Checkpoints = { Vector3.new(0, 4, -105), Vector3.new(-105, 4, -20), Vector3.new(0, 4, 120), Vector3.new(20, 4, 230) } }),
	Monster = table.freeze({ GhostDuration = 10, GiantDuration = 12, FakeDuration = 8, PathInterval = 1.5, CatchDistance = 4.5 }),
	Map = table.freeze({
		Seed = 1028,
		Size = 650,
		Headquarters = Vector3.new(0, 0, -145),
		Spawn = Vector3.new(0, 1, -119),
		GhostHouse = Vector3.new(-105, 0, 15),
		GiantHouse = Vector3.new(180, 0, 155),
	}),
})
