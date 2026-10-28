# 괴물 야식 배달부 · Midnight Delivery

Roblox Studio / Luau / Rojo 7로 개발 중인 1~4인 협동 호러 코미디 게임입니다.
**현재 P0 기반과 P1 배달 1건 코드가 구현되었으며 Studio 검증 전입니다. 출시 가능한 빌드가 아닙니다.**

## Studio에서 바로 실행하기

[실행용 ZIP 다운로드](https://github.com/TaeYoungPar/MIDNIGHT-DELIVERY/blob/main/downloads/MidnightDelivery-Studio.zip?raw=true) → 압축 해제 → Studio의 **파일 → 파일에서 열기**에서 `MidnightDelivery.rbxlx` 선택 → **F5**.
GitHub 로그인 상태에서 다운로드하세요. 파일 페이지가 열리면 **Download raw file** 버튼을 누릅니다. Rojo 없이 빌드 파일을 바로 열 수 있습니다. ZIP에는 실행 방법도 들어 있습니다.

이 ZIP은 아래 headless 검사를 통과한 P0/P1 개발 빌드입니다. Studio 실플레이는 미검증입니다. 소스를 바꾼 뒤 배포 파일을 갱신하려면 `bash tools/verify.sh` 다음 `python3 tools/package.py`를 실행합니다.

## 지금 구현된 것

- Rojo 서버/공유/클라이언트 매핑, 서버와 클라이언트 부트스트랩.
- 외부 에셋 없는 자동 생성 월드: 야식 본부, 네온 도로, 파란 지붕집, 후속 구역용 주택 외형, 가로등과 숲.
- 서버 권위의 20초 로비 → 10초 준비 → 배달 1건(최대 420초) → 결과 15초 → 다음 라운드.
- 현관 ProximityPrompt, 생존·거리·참가·시간·중복 보상 검사, 팀원당 80 Coins / 20 XP.
- 주문 접기/펼치기, 서버 시간 기반 타이머, 목표 방향·거리, 결과와 세션 재화 HUD.
- 중도 합류자는 다음 라운드 대기. 최대 4명 참가. 괴물·스쿠터·저장·상점은 아직 없습니다.

## 빈 Place에서 실행하기

1. Windows 또는 macOS에 Roblox Studio와 공식 [Rojo 7.6.1 CLI](https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1)를 설치합니다. 동기화를 원하면 공식 Rojo Studio 플러그인도 설치합니다.
2. 이 저장소 루트에서 `rojo build default.project.json -o MidnightDelivery.rbxlx`를 실행하고 생성 파일을 Studio에서 엽니다. 빌드 경로는 `.gitignore` 대상입니다.
3. 동기화 방식은 빈 Place를 열고 `rojo serve default.project.json` 실행 후 Studio 플러그인에서 연결합니다. 기본 로컬 포트는 34872입니다. 클라우드 루프백 서버는 다른 PC의 Studio에서 직접 접근되지 않으므로 로컬 체크아웃에서 실행하거나 빌드 파일을 내려받으세요.
4. Play를 누르면 `GameWorld`가 생성되고 Output에 `[MidnightDelivery] World ready`, `Server bootstrap ready`, `Client GUI ready`가 출력되어야 합니다.
5. 본부에서 30초 대기 후 화살표를 따라 파란 지붕집 현관에 접근하여 E 키 또는 기본 터치 프롬프트를 길게 누릅니다. 80 Coins와 결과를 확인하고 다음 라운드를 기다립니다.
6. 경험의 서버 최대 인원 **4명**은 Creator Hub/Studio 경험 설정에서 직접 지정합니다. 코드가 플랫폼의 서버 정원을 변경하지 않습니다.

아직 저장 기능을 사용하지 않으므로 API Services 설정이나 Roblox 비밀 키는 필요하지 않습니다. 유료 구매 API와 외부 에셋도 호출하지 않습니다.

## Linux 클라우드 개발 / 자동 검사

현재 환경은 Roblox Studio를 실행하지 못합니다. 빌드와 순수 로직/데이터 모델 검사만 가능합니다.

```bash
cd /workspace/MIDNIGHT-DELIVERY
bash tools/setup.sh
export PATH="/workspace/tools-bin:$PATH"
bash tools/verify.sh
# 로컬 TCP 사용이 가능한 환경에서 동기화 서버 확인:
python3 tools/smoke_rojo.py
```

설치 버전: Rojo 7.6.1, Lune 0.10.4, Luau 0.744. curl/python3와 GitHub 릴리스 접근이 필요하며 TLS 검증을 유지합니다. `build/MidnightDelivery.rbxlx`가 생성됩니다. 게임 런타임 의존성은 Roblox 엔진뿐입니다.

검증 범위와 재현 시나리오: [docs/TESTING.md](docs/TESTING.md). 단계별 현황: [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md). 제한/설계 조정: [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md).

## 구조와 다음 단계

`src/shared`: 설정·문구·프로토콜 타입. `src/server/World`: 월드 생성. `src/server/Services`: 순수 라운드 모델·경제·보안·엔진 연결. `src/client`: 초기화·HUD·테마. `tests`: 실제 모듈 기반 headless 검사.

P0/P1의 Studio 확인 후 P2(세 고객 규칙/3건 주문) → P3(추격/기절/구조) → P4(스쿠터/모바일) → P5(영구 저장/상점) → P6(실기기/출시 QA) 순서로 진행합니다. 원본 설계 문서의 체크박스는 실제 Studio 통과 전까지 완료 표시하지 않습니다.
