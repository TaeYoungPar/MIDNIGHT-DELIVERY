# 검증 기록과 Studio 절차

## 최신 — 스쿠터 떨림·엔진음 수정

- `bash tools/verify.sh`: Luau 전체 컴파일, 엔진 비의존 모델 타입, 번호 있는 로직/대역 **76개**, 별도 컨트롤러/통합/월드 검사, Rojo 빌드와 **44개 소스** 포함·일치 PASS.
- `tests/vehicles.luau`: 기존 12개 + 매 물리 프레임 이동/도로 높이 완충·차량과 플레이어의 지면 제외/자기 차체 충돌·자동 회전 복원 검사로 **15개 PASS**. 자연 하차, 추가된 캐릭터 부품, 활성 탑승 중 서비스 종료 정리도 검사합니다. 실제 물리는 대역입니다.
- `tests/vehicle_client.luau`: 주시점 높이·회전 보간, 벽에서 빠져나올 때 줌 완충, 큰 위치 복구의 보간 초기화 추가 PASS. 실제 픽셀과 카메라 체감은 미검증입니다. Lune의 CFrame 구현은 Roblox 렌더러를 대신하지 않습니다.
- `tests/world.luau`: 좌석 하나만 고정, 차체 부품 용접/massless, Body만 충돌하는 구조 확인 PASS.
- `tests/audio.luau`: 발소리 대신 출처 확인한 엔진 ID 사용, 정차 공회전, RPM 완충, 루프 재시작 방지, 탑승 중 기본 발소리 억제/새 Running 소리/하차 복원 검사 PASS. **실제 음원 다운로드·청취 검사가 아닙니다**.
- 현재 공개 API 덤프에서 PreSimulation, WeldConstraint/NoCollisionConstraint의 Part0/Part1, Humanoid.AutoRotate, Sound.PlaybackSpeed/Volume/SoundId 존재 확인. PreSimulation/WeldConstraint 공식 Creator Hub 원문 대조. API 실제 호출 실행 성공을 뜻하지 않습니다.
- Studio 수동 검사: `USER_VERIFICATION.md` 맨 앞 떨림·엔진음 점검. 2·4인/모바일/R6·R15/고지연/실제 엔진음 접근은 **NOT TESTED**. 사용자의 실패 보고를 자동 검사로 통과 처리하지 않습니다.

아래는 이전 빌드의 검사 기록입니다.

현재 빌드는 P6 스쿠터 수정판입니다. 최신 검사 기록은 맨 위 떨림·엔진음 수정 절입니다. 사용자 수동 확인은 별도 **[USER_VERIFICATION.md](USER_VERIFICATION.md)**에 모았습니다. 아래는 이전 단계 당시 기록입니다.

2026-10-28. 자동 검사 결과와 엔진 실행 결과를 구분합니다.

## 직접 실행한 검사

저장소 루트에서 PATH에 `/workspace/tools-bin`을 추가하고 `bash tools/verify.sh` 실행.

| 검사 | 결과 | 범위 |
|---|---|---|
| Luau 컴파일 | PASS | src/tests 구문·바이트코드 컴파일. 엔진 타입/런타임 보장 아님 |
| luau-analyze | PASS | 엔진 비의존 RoundModel/EconomyService의 strict 타입 |
| Lune tests/run.luau | PASS · 14개 | 실제 라운드/경제 모듈과 Vector3 기반 보안 mock |
| Lune tests/world.luau | PASS | 실제 생성 코드를 Lune 데이터 모델에서 실행. 264개 descendants, 생성 재실행, 사용자 월드 보호 |
| Rojo 7.6.1 build | PASS | build/MidnightDelivery.rbxlx 생성 |
| tools/check_project.py | PASS | 모든 Luau 소스 포함, 서버 Script/클라이언트 LocalScript 패키징 |
| 로컬 Rojo 핸드셰이크 | PASS | tools/smoke_rojo.py: 7.6.1 버전과 sessionId 응답, 해당 프로세스 종료 |
| Studio / 실제 기기 / 실제 멀티 서버 | NOT TESTED | 아래 수동 테스트 필요 |

14개 시나리오: 0인 대기, 20/10초 경계, 성공 후 다음 판, 4인 동시 완료 모델, 중도 합류/5번째 참가 거부, 구 라운드/조기 완료 거부, 마감 시각 경합, 이탈 보상 제외, 빈 서버 초기화, 모델 20회 반복, 경제 멱등성/구 라운드 거부, 스냅샷 rate limit, 거리/사망/쿨다운/캐릭터 없음, 순간이동 감지 지연.

Lune는 Roblox Studio가 아닙니다. World 검사는 Instance 속성 데이터와 생성 분기만 다루며 난수 객체를 대역으로 주입합니다. 프롬프트 터치, 조명 결과, 물리 충돌, 네트워크 소유권, 엔진 Remote 실행을 검증하지 않습니다.

## P0 수동 게이트 — 모두 NOT TESTED

1. README 절차로 빌드한 rbxlx를 Studio에서 열고 View > Output을 표시합니다.
2. Play: 생성 폴더 1개, 본부 스폰, 밤 조명과 표지판/집/도로가 보이는지 확인합니다.
3. 서버/클라이언트 성공 로그와 HUD를 확인합니다. 빨간 오류/무한 WaitForChild 경고가 있으면 전체 메시지를 기록합니다.
4. Stop/Play를 두 번 반복합니다. 이전 GUI/맵이 중복되지 않아야 합니다. 기존 Place에서 동기화했다면 기본 Spawn과 겹치는지도 확인합니다.
5. Studio Script Analysis에서 전체 src의 타입/API 오류를 확인합니다. headless 검사는 엔진 전체 타입 검사가 아닙니다.

## P1 수동 게이트 — 모두 NOT TESTED

1. 혼자 입장: 20초 로비 → 준비 10초 → 배달 시작. 시작 전 문 프롬프트가 비활성 상태여야 합니다.
2. 본부에서 네온 길과 화살표를 따라 01 파란 지붕집으로 갑니다. 현관 E/터치 길게 누르기 → 80 Coins / 20 XP / 결과. 15초 후 로비, 다음 라운드에서 누적 160 Coins 확인.
3. 문을 빠르게 여러 번 눌러도 한 번만 지급되어야 합니다. 멀리서 접근/사망 상태/대기자는 보상을 발생시키면 안 됩니다.
4. 배달 없이 420초 기다리면 실패 결과와 다음 라운드로 진행되어야 합니다. 마감과 동시에 눌러도 중복 결과/보상이 없어야 합니다.
5. Test의 서버/클라이언트 실행에서 2인, 4인을 각각 검사합니다. 같은 주문과 시간이 보이고 동시 입력에 각 참가자 80 Coins 한 번만 지급되어야 합니다.
6. PLAYING 도중 새 클라이언트 합류: 대기 표시, 문 상호작용 거부, 보상 0. 다음 준비부터 참여. 참여자 이탈, 마지막 참여자 이탈 후 대기자 남음, 빈 서버도 검사합니다.
7. 리스폰 후 GUI 중복/멈춤 없이 본부 스폰, 새 캐릭터로 배달 가능 여부 확인. 이동 검사 초기 2초 보호가 끝난 뒤 시도합니다.
8. Device Emulator 16:9와 19.5:9에서 주문 접기/펼치기, 조이스틱/점프/터치 프롬프트, 목표가 앞/뒤/화면 밖일 때 화살표를 확인합니다. 실제 모바일에서도 반복합니다.

## 기록 방법

실행 일시, Studio 버전, 기기/해상도, 서버 인원, roundId, 재현 단계, 기대/실제 결과, Output 로그를 남깁니다. 원본 QA_CHECKLIST는 P2 이후 기능까지 포함하므로 현재 자동 검사 PASS로 원본 항목을 일괄 체크하지 않습니다.

## 2026-10-29 — 배포 파일 검증

`python3 tools/package.py`: 기존 Rojo 빌드의 16개 소스 일치 확인, ZIP 무결성, ZIP 내 rbxlx와 원본 바이트 일치 PASS. Studio 실행 여부는 여전히 NOT TESTED.

## 2026-10-29 — P2 규칙 및 표지판

사용자가 이전 P1 기본 실행/배달은 작동하고 표지판이 잘못되었다고 피드백했습니다. 아래 자동 검사 PASS는 P2 실플레이 통과를 뜻하지 않습니다.

- `tests/orders.luau`: **9개 PASS** — 라운드별 3종/단서 변화, 유령 쿨다운·4초 유지·위반/재시도, 거인 90초 경계·3초 진정·할인, 가짜 집 잠금/실패/회복, 주문 타임아웃 경합, 부분 성공→3건 종료, 주문별 지급/올성공 보너스 멱등성.
- `tests/round_integration.luau`: 실제 RoundService와 하위 모듈 실행, 신호/Players mock. 3건 성공→360 Coins→다음 판, 중도 합류 보상 제외/다음 판 참가, 순서 회전, 식은 거인 홀드 위조 거부/56 보상, 부분 실패→결과, 종료 연결 해제 PASS. 실제 Roblox Remote/복제 검사는 아님.
- `tests/world.luau`: **294개 descendants** 생성/재생성, 프롬프트 5개, 파란 지붕, 양면 안내판, 실제 목적지 방향과 3D 화살표 내적 > 0.99 PASS.
- 기존 14개 회귀 테스트 유지. 컴파일, RoundModel/EconomyService/OrderModel strict 타입, 모든 20개 소스 Rojo 패키징 검사 PASS.

### P2 Studio 재현 — NOT TESTED

1. 최신 ZIP의 rbxlx를 새로 열고 Play. 이전 파일을 열면 수정이 반영되지 않습니다.
2. 본부에서 교차로의 3D 화살표가 파란 지붕집을 향하는지, 문자판이 양면에서 읽히는지 확인.
3. 첫 판 유령: 3회 노크 후 캐릭터가 문을 향한 채 4초 유지 → 80 Coins와 거인 주문으로 변경. 두 번째 시도에서는 돌아보기/거리 이탈 → 10초 잠금과 다시 노크. 연타/3회 위반도 검사.
4. 거인: 90초 이내 → 80 Coins. 별도 판에서 90초 경과 → 3초 진정 프롬프트/56 Coins. 홀드 중 멀어지기/사망 시 지급 금지.
5. 가짜 집: 카드의 별/원/마름모 우편함 및 현관등 단서와 실제 외형 비교. 오답 → 10초 잠금. 다음에 정답 성공 또는 두 번 오답 → 주문 실패.
6. 세 건 전부 성공 시 360 Coins/60 XP. 부분 성공은 성공한 주문 재화만 지급하고 결과에서 성공/실패 수 표시. 주문마다 120초 경과 시 다음 건으로 이동.
7. 다음 판은 거인부터 시작하고 정답 우편함도 변경. 목표/HUD/프롬프트가 직전 주문으로 남지 않아야 함.
8. 2인/4인 동시 입력과 유령 마지막 노크 수행자 이탈, 라운드 중 새 참가자 보상 제외, 모바일 터치/접기/펼치기 확인.

현재 추격 NPC는 없으므로 추격/기절/구조는 **미구현**으로 기록하고 PASS 처리하지 않습니다.

## 2026-10-29 — P3 추격/기절/구조 및 초기 방향

- `tests/recovery.luau`: **7개 PASS**, 실제 PlayerStateModel과 PlayerStateService(엔진 신호/인스턴스 대역). 보호/중복 처리/세대 키, 도로 방향 스폰, 이동 제한, 12초 자동 복귀, 4초 보호, 자기 구조/대기자/거리/벽/짧은 홀드 거부, 홀드 취소/거리 이탈, 구조·자동 복귀 경합, 리스폰/라운드/이탈 정리.
- `tests/monsters.luau`: **6개 PASS**, 실제 MonsterService(경로/물리 대역). 단일 NPC/고객별 수명, 벽 뒤 잡기 거부/잡기 1회, 보호/대상 교체/이탈, 경로 계산 간격, 취소된 비동기 결과, 경로 실패 폴백/재시도, 낙하 NPC 제거.
- RoundService mock 통합 검사에 유령/거인/가짜 집 추격 훅 연결 추가 PASS.
- Lune 월드 metadata: 스폰 LookVector와 도로 +Z 내적 > 0.99. 세 종류 괴물에 대해 모든 파트 unanchored, 단일 용접 어셈블리, Humanoid/PrimaryPart 설정 확인. 물리/보행 검사가 아님.
- 전체 36개 로직/대역 테스트 + 통합/모델 생성 검사 PASS, 25개 소스 컴파일/빌드 일치 PASS. 직접 `.rbxlx` 파일 복사 바이트 일치 PASS. ZIP은 더 이상 생성하지 않음.

### P3 Studio 재현 — 모두 NOT TESTED

1. 최신 `MidnightDelivery.rbxlx` 다운로드 후 파일 열기/F5. 캐릭터와 카메라가 본부가 아닌 도로를 향하는지 확인. 리스폰 후에도 확인하고 자유 카메라 조작이 계속 가능한지 검사.
2. 유령 3회 노크 후 뒤돌아보기: 유령 1마리가 현관 바깥에서 나타나 경로를 따라 추격하는지 확인. 멀리 도망치면 10초 후 제거되어야 함.
3. 유령에 잡히기: 체력은 유지되고 이동/배달 금지, HUD 12초 카운트. 혼자 기다리면 도로 복귀 후 4초 보호, 이동/배달 재개. 같은 NPC가 중복 기절시키면 안 됨.
4. 2·4인 서버: 한 사람 기절, 참가 팀원이 가까이에서 3초 눌러 구조. 자기 자신/중도 합류 대기자/먼 거리/벽 뒤 구조 금지. 중간에 놓거나 이동하면 취소. 자동 복귀 시각과 구조가 겹쳐도 1회만 처리.
5. 거인 90초 경과 시 12초 추격, 진정 배달 성공하면 NPC 정리. 가짜 집 첫 오답 시 집 괴물 8초 추격, 문 잠금 10초 유지 확인.
6. 추격 중 대상 이탈/사망/리스폰, 기절 중 리스폰, 주문 타임아웃, 라운드 종료 확인. 고정 캐릭터/프롬프트/괴물이 잔류하면 안 됨.
7. 벽 모퉁이/가로등/경로 실패에서 NPC가 순간이동/관통하지 않는지, 끝없이 남지 않는지 확인. 20판 반복해 NPC 수/연결/메모리 점검.
8. 모바일 에뮬레이터와 실기기의 카메라/프롬프트/기절/구조 버튼, 긴 팀원 이름 표시를 확인.

검증 자료로 Studio 버전, 인원, 라운드/주문, 재현 단계, Output 오류, 필요 시 영상/화면을 남깁니다. 이 항목은 headless PASS로 체크하지 않습니다.

## 2026-10-29 — P4 스쿠터/모바일/스프린트/사운드

최신 검증/재현 절차는 이 절을 기준으로 합니다. 앞부분의 P1~P3 기록은 당시 상태입니다.

- `tests/vehicles.luau`: **10개 PASS**. 실제 MovementModel/ActionLimiter/VehicleService 실행, 좌석/캐스트/물리는 대역. 스태미나 소진/재충전, NaN/Infinity/잘못된 입력 거부, 속도·후진·제동, 토큰 버킷, 스쿠터 4대/소유권, 입력 timeout, 회전 overlap/벽 sweep, 복구/쿨다운/하차, 지면 없음/이탈, 취소된 지연 작업 검사.
- `tests/recovery.luau`: 외곽/낙하 복귀 1개 추가로 **8개 PASS**. 전체 번호 있는 로직/대역 테스트 합계 **47개 PASS**.
- `tests/audio.luau`: 실제 AudioController의 접수/성공/추격/기절/복귀, 바람/주행 루프, 음소거/해제, 기본 캐릭터 사운드 그룹 연결/해제, 종료 정리 mock 검사 PASS. **청취 검사가 아님**.
- RoundService 통합 mock: VehicleInput의 이전 roundId 거부/정상 dispatch, GiveCoins 같은 허용되지 않은 액션 무시 PASS.
- Lune metadata: VehicleFactory로 4대 생성, anchored VehicleSeat/차체/개별 프롬프트/소유자 Attribute PASS. 실제 탑승·이동 검사가 아님.
- 컴파일/엔진 비의존 핵심 타입/Rojo 32개 소스 패키징 검사 PASS. 직접 rbxlx 배포 파일과 빌드 원본 바이트 일치 PASS.

### P4 Studio 게이트 — 모두 NOT TESTED

1. 최신 rbxlx 파일을 새로 열어 F5. 본부 앞 스쿠터 4대와 자신의 이름을 확인하고 E/터치로 자기 차량만 탑승. 다른 사람 차량 탑승/조작은 거절되어야 합니다.
2. PC W/S/A/D·방향키로 전진/후진/회전, 스페이스/하차 버튼으로 하차. 모델만 움직이고 캐릭터가 남거나, 하차 후 캐릭터가 고정되면 FAIL.
3. 모바일 에뮬레이터/실기기에서 ↑/↓/←/→ 버튼을 길게 누르며 운전. 손가락을 버튼 밖에서 떼거나 앱 포커스를 잃으면 입력이 남지 않아야 합니다. 기본 조이스틱/점프/문 프롬프트와 겹침 확인.
4. 벽 정면/옆면/회전 중, 다른 차량/플레이어 근처, 현관 계단/도로 가장자리에서 관통 없이 정지하는지 확인. 끼면 차량 복구 → 본부 안전 하차, 15초 연타 거부.
5. 추격 중 차량 탑승/기절, 탑승 중 리스폰/이탈, 차량 입력 통신 중단, 2·4인 동시 운전과 네트워크 지연을 검사합니다. 잘못된 좌석 소유/하차/카메라 이동이 없어야 합니다.
6. 도보 Shift/달리기 버튼 5초, 소진 후 5초 충전, 서 있을 때 소진되지 않음. 기절/탑승 중 스프린트 효과 금지. 외곽/낙하 시 본부 복귀 후 정상 이동 확인.
7. 기본 음색 접수/성공/위험/기절/복귀와 주행/바람 루프를 실제로 들어봅니다. 소리 버튼을 켜고 끄며 기본 발소리도 음소거되는지 확인. 다른 클라이언트 설정에는 영향이 없어야 합니다. Preload 경고 시 해당 경로/클라이언트 버전 기록.
8. 음소거 상태에서도 모든 규칙/실패/추격/복구를 HUD만 보고 이해할 수 있는지 검사. 16:9/19.5:9/세로 화면 버튼과 텍스트 검사.
9. 실제 모바일/4인에서 FPS와 서버 캐스트·복제 비용을 측정하고, 스쿠터로 목적지 25~60초 동선 실측. P3 미검증 항목도 함께 확인.

### 공식 API/기본 음원 경로 참고

- https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Blockcast
- https://create.roblox.com/docs/reference/engine/classes/VehicleSeat
- https://create.roblox.com/docs/reference/engine/classes/Sound
- https://github.com/Roblox/Core-Scripts/blob/master/PlayerScripts/StarterCharacterScripts/Sound.server.lua

공식 문서로 API와 기본 경로를 대조했으며, 그것이 현재 엔진에서의 주행/실제 소리 재생 성공을 입증하지는 않습니다.


## 2026-10-29 — P5 저장/레벨/꾸미기

- `tests/profiles.luau`: **15개 PASS**. 실제 ProfileModel/ProfileStore/Economy/ShopService와 메모리 UpdateAsync 어댑터. 현재 Unix 임대 시각, 손상/미지원 버전/비정상 값 거부, flat v1 이행, 서버 잠금/만료/오래된 서버 쓰기 차단, 제한 재시도, 저장 중 새 보상 보존, 잠금 해제/복원, 가격/레벨/보유/장착/권한/연타 검사.
- `tests/data_service.luau`: **5개 PASS**. 실제 DataService의 미게시 세션 모드, Studio/앱 이름 분리, 지갑/XP/레벨 저장·복원, autosave, 로드 중 이탈 후 임대 해제 및 새로운 지갑 보호. 스케줄러/저장소는 대역이며 라이브 Roblox 요청은 아님.
- 기존 47개와 합해 **67개** 번호 있는 로직/대역 테스트 PASS. 별도 라운드/오디오 통합 검사는 계속 실행.
- Lune metadata: 모자/유령 배지의 비충돌·질량 없음·용접, 민트 차체 적용/기본 복원 PASS. 아바타 실제 착용 모습 검사는 아님.
- 전체 컴파일, 핵심 순수 모델 strict 타입, Rojo 39개 소스 포함/일치 PASS.
- 실제 Roblox DataStore 요청/종료 저장/재접속·모바일 UI·외형·멀티플레이는 **NOT TESTED**.

### 수동 확인

`docs/USER_VERIFICATION.md`의 준비/실행/차량/추격/저장·상점/멀티플레이 순서로 확인합니다. 특히 미게시 파일의 세션 전용/상점 잠금은 정상이며, 별도 비공개 테스트 경험 게시 및 API Services 허용 후 저장을 시험합니다. Studio와 앱 데이터는 의도적으로 분리되어 있습니다.

공식 API 대조:
- https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync
- https://create.roblox.com/docs/cloud-services/data-stores

UpdateAsync 콜백은 재호출 가능/return nil 취소/내부 yield 금지 조건을 따릅니다. 실제 서비스 승인·저장 성공은 위 문서를 읽거나 어댑터 테스트를 통과한 것만으로 확인되지 않습니다.


## 2026-10-29 — P6 설정/안내/마감 및 반복 회귀

- 번호 있는 로직/대역 테스트 **71개 PASS**. 이동 예산 1개, 설정 기본값/스키마 v1→v2/저장 복원 2개, 세션 설정 검증 1개 추가.
- `tests/settings_ui.luau`: 실제 Settings/Tutorial 컨트롤러를 GUI 대역으로 실행. 로딩 전 변경 대기·서버 동기화·기기 자동/펼침·구독 해제·안내 완료/다시 보기·44px 메뉴 PASS.
- `tests/hud.luau`: 실제 HUD + GUI/타이머/Tween 대역. 카드/큰 글자/UTF-8 닉네임/시간/알림 애니메이션 줄이기/연결 정리 PASS.
- 오디오 대역 검사에 설정 로드 전 조용한 대기/저장 음소거/메뉴 토글/구독 정리 추가 PASS. 실제 청취는 미검증.
- RoundService mock에서 **20개 가속 타임아웃 라운드**를 연속 실행. 매번 결과/다음 판, 정리 후 Heartbeat/입장·퇴장/프롬프트/Action 연결 0 확인 PASS. 실제 20판/메모리 측정은 아님.
- 월드 metadata: 359개 descendants, 목적지 5곳 각각 양옆 통로 2개/가로 연결 2개, 본부 안내 인물/편의점 생성 PASS. 실제 경로/미관/동선 시간은 미검증.
- Luau 컴파일/핵심 순수 모델 타입/Rojo **43개 소스** 포함·일치 PASS. 직접 rbxlx 배포 유지.

실제 검증은 `docs/USER_VERIFICATION.md`, 남은 출시 게이트는 `docs/RELEASE_READINESS.md`. 원본 QA 체크리스트는 이 대역 검사만으로 완료 표시하지 않습니다.

## 2026-10-29 — 사용자 스쿠터 피드백 수정

사용자 실제 보고: 이전 파일에서 탑승 시점 이상, 자기 차량 구분 어려움, 하차 불가. 이 보고는 실패 증거로 남기며 수정 후 실제 Studio 재검증은 아직 받지 못했습니다.

- `tests/vehicles.luau`: 기존 10개에서 12개로 변경. stale Occupant/SeatPart와 남은 SeatWeld, 해제 후 GettingUp/속도 초기화/안전 위치/서버 이동 승인, 중복 하차 비이동, 한쪽 막힘과 전체 막힘 본부 폴백, 1초 재탑승 제한, 지연 재배치 없는 복구 검사 PASS. 실제 물리 대신 좌석/캐스트 대역입니다.
- `tests/vehicle_client.luau`: 실제 VehicleController/InputController를 로드하여 소유별 이름표·Highlight·로컬 프롬프트·소유권 변경, 후방 카메라 위치·보간·벽 앞 거리·하차/사망/종료 해제, 높은 우선순위 X/Space 입력·도보/채팅 통과·112×56 터치 버튼·이벤트 정리 검사 PASS. 실제 픽셀/터치/네트워크 복제 검사가 아닙니다.
- 전체 `tools/verify.sh`: 번호 있는 로직/대역 73개 및 컨트롤러/통합/월드 검사 PASS. 컴파일·순수 모델 타입·Rojo 44개 소스 포함 검사 PASS. `tools/package.py`로 직접 rbxlx 복사/내용 검사.
- Roblox 공식 creator-docs의 Camera/VehicleSeat 문서에서 Scriptable/CameraSubject/Sit/Occupant 동작을 확인했습니다. 실제 API 호출 실행 성공을 뜻하지 않습니다.
- 수동 재현: `USER_VERIFICATION.md`의 맨 앞 스쿠터 3분 점검을 따릅니다. 최신 파일에서 탑승 → X/Space/버튼 각각 하차 → 다시 이동, 주행/벽 옆 하차, 기본 카메라 복귀를 우선 확인합니다. PC/모바일/2인·4인과 R6/R15·지연 QA는 아직 필요합니다.
