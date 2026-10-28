"""Package the verified Rojo place for downloading and opening in Studio."""
from pathlib import Path
import subprocess
import zipfile

subprocess.run(['python3', 'tools/check_project.py'], check=True)
place = Path('build/MidnightDelivery.rbxlx')
destination = Path('downloads/MidnightDelivery-Studio.zip')
destination.parent.mkdir(exist_ok=True)
instructions = '''괴물 야식 배달부 · P2 주문 규칙 개발 빌드

1. ZIP 파일 전체를 압축 해제합니다.
2. Roblox Studio → 파일(File) → 파일에서 열기(Open from File).
3. MidnightDelivery.rbxlx를 열고 F5를 누릅니다. 맵은 자동 생성됩니다.
4. 로비 20초 + 준비 10초 후 주문 카드와 화살표를 확인합니다.

첫 라운드는 아래 3건을 순차 진행합니다.
- 유령: 파란 지붕집 현관에서 E/터치 길게 눌러 3회 노크.
  마지막 노크 후 캐릭터가 문을 향한 채 4초 유지합니다.
- 거인: 90초 안에 배달. 늦으면 현관에서 3초간 진정시키기.
- 가짜 집: 주문 카드의 우편함 표식과 현관등 단서를 읽고 진짜 집에 배달.
  틀리면 10초 대기, 두 번 틀리면 해당 주문 실패.

주문당 최대 120초. 다음 라운드는 시작 고객과 가짜 집의 정답이 바뀝니다.
일반 성공 80 Coins, 식은 음식 56 Coins, 모두 성공 보너스 120 Coins.
WASD 이동 / 스페이스 점프 / Shift+F5 테스트 종료.

Studio에서 P2 실플레이는 아직 미검증입니다.
괴물 추격 AI/스쿠터/영구 저장은 아직 없습니다. Coins/XP는 세션 전용입니다.
문제가 있으면 Output의 오류 메시지와 재현 상황을 전달해 주세요.
'''
with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for name, data in [('MidnightDelivery.rbxlx', place.read_bytes()), ('실행방법.txt', instructions.encode('utf-8'))]:
        item = zipfile.ZipInfo(name, date_time=(2026, 10, 29, 0, 0, 0))
        item.compress_type = zipfile.ZIP_DEFLATED
        item.external_attr = 0o100644 << 16
        archive.writestr(item, data)
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert archive.read('MidnightDelivery.rbxlx') == place.read_bytes()
print(f'PASS {destination} ({destination.stat().st_size} bytes); place matches verified artifact')
