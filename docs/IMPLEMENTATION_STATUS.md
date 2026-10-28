# 구현 현황

기록: 2026-10-28 (한국 시간). 원본 설계서와 기술 명세 전체를 검토했습니다.

## P0 — 코드/빌드 구현, Studio 통과 대기

- `default.project.json`: Shared / Server / Client 매핑.
- `src/server/Bootstrap.server.luau`, `src/client/Bootstrap.client.luau`: 초기화, 명시적 성공/실패 로그, 초기 스냅샷과 GUI.
- `src/server/World/{WorldBuilder,BuildingFactory,Primitives}.luau`: 코드 생성 네온 야간 마을, 본부, 스폰, 현관, 표지판, 숲, 외곽 주택.
- 소유권 Attribute가 있는 GameWorld만 교체. 새 생성 실패 시 기존 월드 보존. 모르는 GameWorld는 오류로 중단.
- `tools/setup.sh`, `tools/verify.sh`, README: 고정 도구 버전과 실행/검증 방법.
- 직접 검증: Rojo Place 빌드, Luau 컴파일, 데이터 모델에서 264개 하위 인스턴스 생성/반복 생성/사용자 월드 보호.
- **미검증:** 실제 Studio Play의 서버·클라이언트 실행/Output/화면/이동. P0 최종 완료로 판정하지 않음.

## P1 — 수직 슬라이스 코드 구현, Studio 통과 대기

- `Services/RoundModel.luau`: 20/10/420/15초 상태 전환, 참가 고정, 중도 이탈, 타임아웃, 다음 라운드.
- `Services/RoundService.luau`: 엔진 이벤트·스냅샷·프롬프트 연결. 서버에서 주문 닫기 후 재화 지급.
- `Services/EconomyService.luau`: 라운드/유저 키 중복 지급 방지, 세션 Coins/XP.
- `Services/SecurityService.luau`: 거리·생존·기본 이동 이상·스냅샷 빈도·상호작용 쿨다운 검사.
- `client/Controllers/HUDController.luau`, `client/UI/*`: 서버 타이머, 주문, 결과, 목표 방향과 거리, 화면 폭 적응·접기 버튼.
- 직접 검증: 라운드/경제/보안 14개 테스트 PASS. 20라운드 테스트는 순수 모델 반복이며 실제 20판 게임 QA가 아님.
- **미검증:** 실제 PC/모바일 배달, 터치 입력/세이프 영역/목표 화살표, 2·4인 서버 복제·동시 프롬프트. P1 완료로 판정하지 않음.

## P2~P6 — 미착수

괴물 규칙, 3건 주문, AI/구조, 스쿠터, 달리기, 영구 저장/상점/꾸미기, 접근성 옵션, 실기기 성능, 출시/게시 QA 미구현.

다음 순서: docs/TESTING.md의 P0/P1 Studio 검증 → 실패 수정 → P2. Studio 통과 조건을 자동 모델 테스트로 대체하지 않습니다.

## 2026-10-29 — 다운로드 전달 보완

- `tools/package.py`: 검증된 Place와 한글 실행 방법을 ZIP으로 패키징.
- `downloads/MidnightDelivery-Studio.zip`: Rojo 설치 없이 Studio에서 열 수 있는 P0/P1 개발 빌드.
- 작업공간 내부 경로를 사용자용 다운로드로 안내한 문제를 GitHub 다운로드 경로로 보완.
- 게임 기능 변경 없음. Studio 검증 대기 상태 유지.
