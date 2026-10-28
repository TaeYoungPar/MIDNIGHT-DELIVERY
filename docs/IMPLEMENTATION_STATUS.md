# 구현 현황 · 2026-10-29 (한국 시간)

## 현재 범위

P0/P1 기반, P2 주문 3종, P3 추격·기절·구조 코드를 구현했습니다. 사용자에게서 이전 빌드의 기본 실행/배달 피드백을 받았지만, **P3 실제 Studio 플레이/모바일/4인 검증은 아직 NOT TESTED**입니다. 출시 가능한 상태로 선언하지 않습니다.

## P0/P1/P2 기반

Rojo 매핑/서버·클라이언트 Bootstrap, 자동 생성 네온 마을, 서버 타이머, 세션 Coins/XP, 참가자 확정/중도 합류 대기, HUD/결과/다음 라운드를 유지합니다. 3건 순차 주문은 유령 노크·정면 유지 / 거인 온도·진정 / 가짜 집 단서·오배송으로 구분됩니다. 주문당 120초, 정상 80 Coins, 식은 음식 56 Coins, 전체 성공 보너스 120 Coins.

파란 지붕집 안내는 좌표 기반 3D 화살표/양면 문자판으로 수정했고 지붕을 파란색으로 맞췄습니다. 서버 스폰 CFrame과 캐릭터 Pivot 방향은 도로(+Z)를 향하며 초기 카메라도 새 캐릭터마다 한 번 정렬합니다.

## P3 구현 파일

- `Services/PlayerStateModel.luau`: 기절 12초, 세대 키로 구조/자동 복귀 경합 방지, 복귀 보호 4초.
- `Services/PlayerStateService.luau`: 스폰/리스폰, 이동·배달 제한, 서버 근접/생존/참가/시야/3초 홀드 검사, 팀 구조/솔로 도로 복귀, 이탈·리스폰·라운드 정리.
- `World/MonsterFactory.luau`: 외부 에셋 없는 유령/거인/집 괴물. 단일 용접 Humanoid 어셈블리, 고객별 실루엣.
- `Services/MonsterService.luau`: 한 번에 한 서버 소유 NPC, 10/12/8초 추격, Pathfinding 계산 간격/MoveTo 폴백, 서버 근접+시야 판정, 기절/대상 이탈/캐릭터 교체/보호/라운드 종료 정리, 취소된 비동기 결과 무시.
- `Services/RoundService.luau`: 고객별 규칙 위반과 추격 연결, 기절 중 배달 거부, 주문 종료 시 NPC 정리.
- `client/Controllers/SpawnController.luau`: 도로 방향 초기 카메라 후 기본 카메라 조작 유지.
- HUD: 추격·기절·복귀 보호·팀원 구조 필요 표시.

## 직접 실행한 검증

- 기존 23개 + 기절/구조 7개 + 추격 6개 = **36개** 로직/대역 테스트 PASS.
- 실제 RoundService를 mock 신호로 실행한 통합 검사 PASS. 3종 추격 훅/순차 주문/보상/합류/정리.
- Lune 데이터 모델: 월드 294개 descendants, 안내판/스폰 방향, 세 괴물 어셈블리/용접/속성 검사 PASS.
- Luau 컴파일, 엔진 비의존 핵심 모델 strict 타입 검사, Rojo 빌드와 **25개 소스** 일치 검사 PASS.
- 배포 rbxlx와 검증 빌드 바이트 일치 PASS. 실제 Roblox 엔진 물리/렌더링/복제 테스트는 아님.

## 배포와 다음 단계

`tools/package.py`는 `downloads/MidnightDelivery.rbxlx` 직접 파일만 갱신합니다. 사용자의 요청에 따라 ZIP 생성/배포를 중단했습니다. GitHub Download raw file로 받아 Studio에서 바로 엽니다.

다음은 docs/TESTING.md의 P3 Studio 검증과 실패 수정, P4 스쿠터/모바일/낙하 복구, P5 영구 저장/상점, P6 접근성·실기기·출시 QA입니다. 원본 설계 문서 8개는 변경하지 않았습니다.
