# 검증 기록과 Studio 절차

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
