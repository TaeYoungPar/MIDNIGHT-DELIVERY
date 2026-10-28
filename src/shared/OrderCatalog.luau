--!strict
-- 단서는 색뿐 아니라 우편함 표식과 문패로도 구분한다.
return table.freeze({
	FakeHouses = table.freeze({
		{ id = "fake_1", label = "03-A · 별 우편함", symbol = "★", clue = "붉은 별(★) 우편함 · 노란 현관등", mailbox = { 220, 76, 89 }, lamp = { 255, 215, 100 } },
		{ id = "fake_2", label = "03-B · 원 우편함", symbol = "●", clue = "청록 원(●) 우편함 · 초록 현관등", mailbox = { 70, 190, 200 }, lamp = { 130, 255, 150 } },
		{ id = "fake_3", label = "03-C · 마름모 우편함", symbol = "◆", clue = "보라 마름모(◆) 우편함 · 분홍 현관등", mailbox = { 160, 120, 220 }, lamp = { 255, 140, 205 } },
	}),
})
