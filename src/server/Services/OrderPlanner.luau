--!strict
local Planner = {}
function Planner.create(roundId: number, candidates)
	local chosen = candidates[(roundId - 1) % #candidates + 1]
	local specs = {
		{ kind = "Ghost", destination = "ghost_house", title = "유령 · 01 파란 지붕집", hint = "문을 3번 두드린 뒤 4초 동안 문을 향하세요.\n카메라 대신 캐릭터 방향을 검사합니다." },
		{ kind = "Giant", destination = "giant_house", title = "거인 · 02 큰 현관집", hint = "90초 안에 따뜻하게 배달하세요.\n늦으면 현관에서 3초간 진정시키기 · 보상 56 Coins" },
		{ kind = "Fake", destination = chosen.id, title = "수상한 주소 · 외곽 주택 03", hint = "단서: " .. chosen.clue .. "\n잘못된 집은 10초 대기 · 2회 실수 시 실패" },
	}
	-- 첫 판은 학습 순서, 다음 판부터 시작 고객과 단서가 바뀐다. 세 종류는 매번 모두 등장한다.
	local result = {}
	for offset = 0, 2 do table.insert(result, specs[(roundId - 1 + offset) % 3 + 1]) end
	return result
end
return Planner
