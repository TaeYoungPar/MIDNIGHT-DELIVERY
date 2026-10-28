--!strict
-- 타이머와 보상은 서버에서도 같은 설정을 사용한다. P1은 배달 1건만 활성화한다.
return table.freeze({
	Build = "P0 + P1 / Studio 검증 대기",
	Round = table.freeze({ Waiting = 20, Preparing = 10, Playing = 420, Results = 15, MaxPlayers = 4 }),
	Delivery = table.freeze({ Reward = 80, XP = 20, Distance = 12, Cooldown = 0.75 }),
	Map = table.freeze({
		Seed = 1028,
		Size = 650,
		Headquarters = Vector3.new(0, 0, -145),
		Spawn = Vector3.new(0, 1, -119),
		GhostHouse = Vector3.new(-105, 0, 15),
		GiantHouse = Vector3.new(180, 0, 155),
	}),
})
