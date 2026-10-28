"""Package the verified Rojo place for downloading and opening in Studio."""
from pathlib import Path
import subprocess
import zipfile

subprocess.run(['python3', 'tools/check_project.py'], check=True)
place = Path('build/MidnightDelivery.rbxlx')
destination = Path('downloads/MidnightDelivery-Studio.zip')
destination.parent.mkdir(exist_ok=True)
instructions = '''괴물 야식 배달부 · P0/P1 개발 빌드

1. ZIP 파일 전체를 압축 해제합니다.
2. Roblox Studio에서 파일(File) → 파일에서 열기(Open from File)를 선택합니다.
3. MidnightDelivery.rbxlx를 열고 플레이(▶) 또는 F5를 누릅니다.
4. 로비 20초 + 준비 10초 후 화살표를 따라 파란 지붕집으로 갑니다.
5. 현관에서 E 키를 길게 눌러 배달합니다. 성공 시 80 Coins가 표시됩니다.

WASD: 이동 / 스페이스: 점프 / Shift+F5: 테스트 종료.
맵은 플레이 시작 때 자동 생성됩니다.

주의: 개발 중인 배달 1건 버전입니다. Studio 실플레이는 아직 미검증입니다.
괴물/스쿠터/영구 저장은 아직 없습니다. Coins/XP는 세션 전용입니다.
문제가 있으면 Studio 출력(Output) 창의 오류 메시지를 전달해 주세요.
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
