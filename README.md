# 괴물 야식 배달부 · Midnight Delivery

Roblox Studio / Luau / Rojo 7 · 1~4인 협동 호러 코미디 게임 개발 중.
**현재 P2 주문 규칙 개발 빌드입니다. P2 Studio 실플레이와 출시 QA는 미검증입니다.**

## Studio에서 실행

[실행 ZIP 다운로드](https://github.com/TaeYoungPar/MIDNIGHT-DELIVERY/blob/main/downloads/MidnightDelivery-Studio.zip?raw=true) → 압축 해제 → Studio **파일 → 파일에서 열기**에서 `MidnightDelivery.rbxlx` 선택 → **F5**.
GitHub 파일 화면이 열리면 **Download raw file**을 누르세요. 비공개 저장소는 GitHub 로그인이 필요합니다. Rojo 없이 빌드 파일을 열 수 있습니다.

맵은 Play를 누를 때 생성됩니다. 로비 20초 → 준비 10초 → 주문 3건 → 결과 15초 → 다음 라운드.

- **유령 / 파란 지붕집:** E 키 또는 터치 프롬프트로 3회 노크 후 캐릭터가 문을 향한 채 4초 유지. 실패하면 10초 대기 후 재시도, 3회 위반 시 주문 실패.
- **거인 / 큰 현관집:** 90초 이내 배달. 늦으면 3초간 진정시키기, 56 Coins.
- **가짜 집 / 외곽 주택:** 카드의 우편함 색·표식과 현관등 단서를 읽고 배달. 오답이면 10초 대기, 2회 오배송 시 주문 실패.
- 주문당 120초, 라운드 최대 420초. 실패해도 다음 주문으로 진행. 정상 배달 80 Coins / 20 XP, 3건 모두 성공하면 120 Coins 추가.
- 첫 판은 유령 → 거인 → 가짜 집. 다음 판은 시작 고객과 정답 단서를 바꿉니다.
- 중도 입장은 다음 라운드 대기. 경험 최대 인원 **4명**은 Roblox 경험 설정에서 직접 지정합니다.

Coins/XP는 **세션 전용**입니다. 추격 AI·기절/구조·스쿠터·저장·상점은 아직 없습니다. 현재 규칙 위반의 위험 피드백은 자막과 재시도 잠금이며 실제 몬스터가 추격하지 않습니다.

## 로컬 Rojo 개발

Windows/macOS에 [Rojo 7.6.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1)을 설치하고 저장소 루트에서 실행합니다.

```bash
rojo build default.project.json -o MidnightDelivery.rbxlx
# 또는 Studio Rojo 플러그인으로 동기화
rojo serve default.project.json
```

클라우드의 localhost:34872는 다른 PC의 Studio에서 직접 접근할 수 없습니다. 로컬 체크아웃에서 실행하거나 ZIP의 빌드 파일을 여세요. Roblox 비밀 키, 유료 상품, 외부 에셋은 필요하지 않습니다.

## Linux 클라우드 검사 / 패키징

```bash
cd /workspace/MIDNIGHT-DELIVERY
bash tools/setup.sh
export PATH="/workspace/tools-bin:$PATH"
bash tools/verify.sh
python3 tools/package.py
# 로컬 TCP 사용이 가능한 환경에서 선택 검사
python3 tools/smoke_rojo.py
```

도구는 Rojo 7.6.1 / Lune 0.10.4 / Luau 0.744로 고정합니다. 설치에는 curl/python3와 공식 GitHub 릴리스 접근이 필요하며 TLS 검증을 유지합니다. 게임은 Roblox 엔진만 사용합니다.

[구현 현황](docs/IMPLEMENTATION_STATUS.md) · [테스트 절차](docs/TESTING.md) · [알려진 제한](docs/KNOWN_LIMITATIONS.md)

`src/shared`: 설정·문구·타입·단서. `src/server/World`: 월드/안내판 생성. `src/server/Services`: 라운드·주문·보상·검증. `src/client`: HUD/테마/초기화. `tests`: 실제 모듈을 실행하는 headless 검사.
