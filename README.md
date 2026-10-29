# 괴물 야식 배달부 · Midnight Delivery

Roblox Studio / Luau / Rojo 7 · 1~4인 협동 호러 코미디 게임 개발 중.
**현재 P6 마감 개발 빌드입니다. 실제 Roblox 저장/Studio/기기 검증과 출시 QA는 미검증입니다.**

[출시 전 상태표](docs/RELEASE_READINESS.md)

나중에 직접 확인하실 항목: **[사용자 확인 체크리스트](docs/USER_VERIFICATION.md)**

## 바로 실행

**[MidnightDelivery.rbxlx 다운로드](https://github.com/TaeYoungPar/MIDNIGHT-DELIVERY/blob/main/downloads/MidnightDelivery.rbxlx?raw=true)**

파일을 저장하고 Studio **파일 → 파일에서 열기**에서 선택한 뒤 **F5**. GitHub 파일 페이지가 열리면 **Download raw file**을 누르세요. 비공개 저장소는 GitHub 로그인이 필요합니다. ZIP/Rojo 없이 빌드 파일을 바로 엽니다.

Play 때 맵이 생성됩니다. 로비 20초 → 준비 10초 → 순차 배달 3건 → 결과 15초 → 다음 판.

## 메뉴·첫 안내

상단 **메뉴**에서 소리, 차량 복구, 꾸미기 상점, 화면·접근성 설정과 도움말을 엽니다. 모바일 조작 영역을 가리지 않도록 기능 버튼을 메뉴에 모았습니다. 작은 화면에서는 메뉴/설정 화면을 스크롤할 수 있습니다.

첫 접속에는 3단계 플레이 안내가 표시되며 닫거나 메뉴에서 다시 볼 수 있습니다. 화면 설정은 **소리, 알림 애니메이션 줄이기, HUD 글자 확대, 주문 카드 자동/접기/펼치기**를 제공합니다. 저장 연결이 있으면 설정/안내 여부를 보존하며, 세션 전용에서도 즉시 적용됩니다.

## 조작과 기능

- 도보: WASD/기본 모바일 조이스틱, 스페이스 점프. **Shift 또는 달리기 버튼을 누른 채 이동**하면 최대 5초 스프린트. 모두 소진하면 5초 충전 후 다시 사용합니다.
- 스쿠터: 본부 앞 **자기 이름이 표시된 스쿠터**에 E/터치로 탑승. PC WASD/방향키, 모바일 ↑/↓/←/→ 버튼. 전진 최고 38, 후진 12 studs/s. 스페이스 또는 하차 버튼으로 내립니다.
- 차량 복구: 본부 주차 위치로 되돌립니다. 탑승 중이면 함께 안전하게 내려주며 쿨다운은 15초입니다. 다른 사람의 차량은 조작/복구할 수 없습니다.
- 지도 밖/지면 없음 감지 시 차량 복구, 도보 낙하/외곽 이탈 시 본부 복귀. 스쿠터는 항상 서 있는 서버 아케이드 방식입니다.
- 소리 버튼으로 음소거/해제. 주문 접수·보상·추격·기절/복귀 알림, 작은 바람 루프와 주행 속도에 따른 임시 차량 효과음을 연결했습니다. **Roblox 내장 음색을 재사용한 프로토타입**이며 실제 재생과 음질은 Studio 미검증입니다. 설정은 영구 저장 연결 시 보존하고, 세션 모드에서는 접속 동안만 적용됩니다.

## 배달 규칙

- **유령:** 파란 집에서 3회 노크 → 캐릭터가 문을 향해 4초 유지. 위반하면 10초 추격, 최대 두 번 재시도.
- **거인:** 90초 이내 배달. 늦으면 12초 추격, 현관에서 3초간 진정시키면 56 Coins.
- **가짜 집:** 우편함 표식/색·현관등 단서로 정답 찾기. 오답 시 8초 추격/10초 문 잠금, 두 번 오답이면 실패.
- **기절:** 12초 후 도로 자동 복귀 또는 팀원이 3초간 눌러 구조. 복귀 후 4초 보호.
- 주문당 120초, 라운드 최대 420초. 정상 성공 80 Coins/20 XP, 전부 성공 보너스 120 Coins. 첫 판 유령→거인→가짜 집, 이후 시작 고객/정답 순환.

Coins/XP·보유/장착은 저장 연결이 정상일 때 영구 저장합니다. 미게시/API 미허용/저장 잠금·읽기 실패 시 **세션 전용**으로 전환하고 상점을 잠가 기존 데이터를 보호합니다. P6 실제 출시 QA는 아직 남았습니다. 경험 최대 인원 **4명**은 Roblox 경험 설정에서 직접 지정하세요. 중도 합류자는 다음 라운드까지 대기합니다.

## 저장·레벨·꾸미기 상점

저장 테스트는 **별도의 비공개 테스트 경험에 게시**한 뒤 Experience Settings/보안에서 **Enable Studio Access to API Services**를 켜고 진행합니다. 미게시 rbxlx 파일만 열었을 때는 세션 전용/상점 잠금이 정상입니다.

- 모자 120 Coins(Lv.1), 민트 스쿠터 180 Coins(Lv.2), 유령 배지 240 Coins(Lv.2). 구매 후 장착/해제를 선택합니다. 외형만 바뀌며 Robux 결제는 없습니다.
- XP로 레벨 1~10을 계산합니다. Lv.2는 누적 100 XP. HUD에 영구 저장 연결/저장 대기/실패/세션 전용을 구분합니다.
- 60~74초마다 저장/임대 갱신, 상점 변경 후 약 5초 내 저장 예약, 이탈/종료 저장. 다른 서버의 유효한 임대·손상/미지원 스키마에는 쓰지 않습니다.
- Studio: `MidnightDelivery_Studio_PlayerData_v1`, Roblox 앱: `MidnightDelivery_Live_PlayerData_v1`. **서로 별개 데이터**입니다. 같은 접속 방식으로 재접속하여 복원을 비교하세요.
- 실제 Roblox DataStore 성공은 아직 미검증입니다. 테스트 절차는 위 사용자 체크리스트를 따르세요.

프로필 형식은 P6에서 v2로 올렸고 기존 v1 지갑/인벤토리를 이행합니다. DataStore 이름은 변경하지 않았습니다. 이전 P5 파일은 새 스키마를 세션 전용으로 취급하므로 저장 테스트에는 최신 파일을 사용하세요.

## 개발 / 자동 검사

로컬 Studio 동기화는 Rojo 7.6.1과 Studio Rojo 플러그인을 설치하고 저장소 루트에서 `rojo serve default.project.json`. 클라우드 localhost는 다른 PC의 Studio에서 직접 접근되지 않습니다.

```bash
cd /workspace/MIDNIGHT-DELIVERY
bash tools/setup.sh
export PATH="/workspace/tools-bin:$PATH"
bash tools/verify.sh
python3 tools/package.py
# 선택: 로컬 TCP 사용 가능 시
python3 tools/smoke_rojo.py
```

도구 버전은 Rojo 7.6.1 / Lune 0.10.4 / Luau 0.744로 고정하고 TLS 검증을 유지합니다. `package.py`는 검사한 빌드를 `downloads/MidnightDelivery.rbxlx`로 복사합니다. 외부 모델/음원 ID, Roblox 비밀 키, 유료 상품은 필요하지 않습니다.

[구현 현황](docs/IMPLEMENTATION_STATUS.md) · [검증 절차](docs/TESTING.md) · [알려진 제한](docs/KNOWN_LIMITATIONS.md)
