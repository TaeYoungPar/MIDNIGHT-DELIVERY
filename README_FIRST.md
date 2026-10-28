# MIDNIGHT DELIVERY — Codex 전달 패키지

버전: 1.0 / 기준일: 2026-10-28 / 플랫폼: Roblox Studio (Luau) / 작업 방식: Codex + Git + Rojo 7

## 목적
Codex가 **실제로 플레이 가능한 Roblox 협동 게임 MVP**를 구현하도록 하기 위한 기획·기술·QA 문서입니다. 문서 작성만으로 끝내지 말고 `.luau` 코드, 맵 생성기, UI, 프로젝트 설정, 테스트 가이드를 구현해야 합니다.

## 읽는 순서
1. `CODEX_START_PROMPT.md`: Codex에 붙여 넣는 작업 지시
2. `GAME_DESIGN_DOCUMENT.md`: 플레이 경험, 상세 규칙, 밸런스, UX, 수익화
3. `TECHNICAL_SPEC.md`: Roblox 프로젝트 구조, 서비스, 보안, 데이터, API
4. `IMPLEMENTATION_ROADMAP.md`: 작업 순서와 단계별 완료 조건
5. `WORLD_LAYOUT_AND_UI.md`: 구역 좌표, 디자인 가이드, PC/모바일 화면 구조
6. `QA_CHECKLIST.md`: 테스트 항목 및 출시 판단
7. `AGENTS.md`: Codex/코딩 에이전트 상시 준수 규칙

## 시작 방법
1. 새 Git 저장소에 이 문서들을 넣는다.
2. Codex에서 이 저장소를 열고 `CODEX_START_PROMPT.md`의 내용을 전달한다.
3. Codex가 만든 `default.project.json`을 기준으로 `rojo serve` 실행 → Roblox Studio Rojo 플러그인 연결 → Studio의 Play/Start Server 테스트.
4. Roblox 경험 설정에서 서버 최대 인원을 **4명**으로 설정한다. 코드만으로 경험의 최대 서버 인원 설정을 대신하지 않는다.
5. 코덱스가 설치할 수 없는 Roblox Studio 플러그인, 에셋 업로드, Roblox 게임 게시/상품 ID 등록은 사용자 수동 작업으로 안내하도록 한다.

## 명확한 범위
- MVP에는 서버당 1~4명, 싱글 서버 단위 라운드(파티 매칭·서버간 텔레포트 제외), 3가지 주문 이벤트, 한 번에 3건 배달, 간단 스쿠터, 화폐/저장, 코스메틱 상점, 모바일 UI가 포함된다.
- 실제 로벅스 판매는 게시 후 설정 가능한 후속 단계로 한다. 상품 ID가 없을 땐 구매 UI 비활성화.
- 음원/이미지/모델에 외부 저작물 무단 이용 금지. 초기에는 코드로 생성한 오리지널 임시 모델을 사용한다.
- 구조/실행/테스트가 안 된 기능을 완성으로 보고하지 않는다.

## 공식 참고
- Roblox 데이터 저장 모범 사례: https://create.roblox.com/docs/cloud-services/data-stores/best-practices
- Roblox 보안: https://create.roblox.com/docs/scripting/security/client-server-boundary
- Roblox 구매 처리: https://create.roblox.com/docs/reference/engine/classes/MarketplaceService
- Rojo 프로젝트 구조: https://rojo.space/docs/v7/project-format/
