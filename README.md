# 괴물 야식 배달부 · Midnight Delivery

Roblox Studio / Luau / Rojo 7 · 1~4인 협동 호러 코미디 게임 개발 중.
**현재 P3 추격·기절·구조 개발 빌드입니다. Studio 실플레이와 출시 QA는 미검증입니다.**

## Studio에서 바로 실행

**[MidnightDelivery.rbxlx 다운로드](https://github.com/TaeYoungPar/MIDNIGHT-DELIVERY/blob/main/downloads/MidnightDelivery.rbxlx?raw=true)**

GitHub 파일 화면이 열리면 **Download raw file**을 누르세요. 파일을 저장한 뒤 Studio **파일 → 파일에서 열기**에서 `MidnightDelivery.rbxlx`를 선택하고 **F5**를 누릅니다. ZIP 압축 해제나 Rojo 설치 없이 실행합니다. 비공개 저장소는 GitHub 로그인이 필요합니다.

맵은 Play 때 자동 생성됩니다. 캐릭터와 첫 카메라는 본부에서 도로 방향으로 시작합니다. 카메라는 시작 시 한 번만 맞추고 기본 Roblox 조작으로 돌아갑니다.

## 현재 게임 흐름

로비 20초 → 준비 10초 → 주문 3건 → 결과 15초 → 다음 라운드.

- **유령:** 파란 집에서 E/터치 길게 눌러 3회 노크 → 캐릭터가 문을 향해 4초 유지. 위반하면 유령이 10초 추격합니다. 최대 두 번 재시도.
- **거인:** 90초 이내 배달. 늦으면 거인이 12초 추격하고, 현관에서 3초간 진정시키면 할인 보상 56 Coins.
- **가짜 집:** 우편함 표식/색·현관등 단서로 정답 찾기. 오답이면 집 괴물이 8초 추격, 문 상호작용 10초 잠금. 두 번 오답이면 주문 실패.
- **잡히면 기절 12초:** 팀원이 가까이에서 3초간 눌러 구조하거나, 시간이 지나면 가까운 도로 체크포인트로 자동 복귀. 복귀 후 4초 보호.
- 주문당 120초, 라운드 최대 420초. 실패해도 다음 주문으로 진행. 정상 성공 80 Coins / 20 XP, 전부 성공 보너스 120 Coins.
- 첫 판은 유령→거인→가짜 집. 이후 시작 고객과 정답 단서 순환. 중도 입장은 다음 라운드 참가.

Coins/XP는 **세션 전용**입니다. 스쿠터/달리기/영구 저장/상점/출시 QA는 후속 단계입니다. 경험 정원 **4명**은 Roblox 경험 설정에서 직접 지정하세요.

## 로컬 Rojo 개발

Windows/macOS에 [Rojo 7.6.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1)을 설치하고 저장소 루트에서 실행합니다.

```bash
rojo build default.project.json -o MidnightDelivery.rbxlx
rojo serve default.project.json
```

클라우드 루프백 서버는 다른 PC의 Studio에서 직접 접근할 수 없습니다. 로컬 체크아웃에서 동기화하거나 빌드 파일을 다운로드하세요. 현재 빌드에 Roblox 비밀 키, 외부 에셋, 유료 상품은 필요하지 않습니다.

## Linux 클라우드 검사 / 배포 파일 갱신

```bash
cd /workspace/MIDNIGHT-DELIVERY
bash tools/setup.sh
export PATH="/workspace/tools-bin:$PATH"
bash tools/verify.sh
python3 tools/package.py
# 선택: 로컬 TCP 사용 가능 시 Rojo 핸드셰이크 검사
python3 tools/smoke_rojo.py
```

`package.py`는 검증된 빌드를 `downloads/MidnightDelivery.rbxlx`로 복사합니다. ZIP은 생성하지 않습니다. 도구는 Rojo 7.6.1 / Lune 0.10.4 / Luau 0.744로 고정하며 TLS 검증을 유지합니다. 게임 실행 의존성은 Roblox 엔진뿐입니다.

[구현 현황](docs/IMPLEMENTATION_STATUS.md) · [검증 절차](docs/TESTING.md) · [알려진 제한](docs/KNOWN_LIMITATIONS.md)
