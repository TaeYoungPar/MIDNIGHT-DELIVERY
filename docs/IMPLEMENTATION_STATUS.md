# 구현 현황 · 2026-10-29 (한국 시간)

## 현재 빌드

P0~P3 기반 위에 P4 스쿠터/입력/복구 코드와 임시 사운드/음소거를 추가했습니다. **P3/P4 실제 Studio·모바일·4인 검증은 아직 NOT TESTED**입니다. 사용자는 현재 실행 확인이 어려워 독립적으로 가능한 구현/모의 검증을 진행했습니다. 출시 또는 P4 통과로 선언하지 않습니다.

## 이전 기반

코드 생성 네온 마을, 서버 라운드, 고객 3종/순차 배달/보상, 추격 NPC 3종, 기절·구조·자동 복귀, 도로 방향 스폰/초기 카메라, HUD를 유지합니다. 원본 설계 문서 8개는 변경하지 않았습니다.

## P4 추가 파일/연결

- `World/VehicleFactory.luau`: 둥근 전조등/두 바퀴/핸들/야식 박스/개인 표식의 외부 에셋 없는 스쿠터 모델.
- `Services/VehicleService.luau`: 스쿠터 4대, 유저별 1대, 서버 탑승/소유/생존/좌석 거리 검증, 서버 속도/조향, 30Hz 아케이드 이동, Box sweep/회전 overlap 검사, 입력 timeout 제동, 지면/경계 복구, 소유자 복구 15초 쿨다운, 기절 시 SeatWeld 안전 해제.
- `Services/MovementModel.luau`: 스프린트 16→22, 5초 소진/충전, 전진 38/후진 12, 가속/제동/유효 축 순수 로직.
- `Services/ActionLimiter.luau`: Remote burst/빈도 제한. `RoundService`에서 액션 허용 목록·roundId·자료형·권한 재검증.
- `SecurityService`: 실제 소유 차량 좌석 탑승 시에만 서버 허용 이동 속도 확장. 정상 서버 복구 위치 이동은 별도 승인 경로.
- `PlayerStateService`: 낙하/외곽 이탈 본부 복귀, 차량 하차 후 기절 연결.
- `client/Controllers/InputController.luau`: 키보드/네이티브 좌석 입력, 모바일 48px 방향 버튼, 하차/복구/달리기, 포커스 이탈·텍스트 입력 처리. 모바일 주문 카드는 기본 접힘.
- `shared/AudioCatalog.luau`, `client/Controllers/AudioController.luau`: 공식 Roblox 기본 사운드 경로, 접수/성공/추격/기절/복귀 알림, 바람/주행 루프, 음소거/해제, 로딩 실패 경고와 연결 정리.

## 직접 검사

- 번호 있는 로직/대역 테스트 **47개 PASS**: 기존 36 + 낙하 1 + 차량/이동 10.
- 별도 오디오 연결/음소거/루프/정리 mock 검사 PASS. 실제 청취 검사가 아님.
- RoundService 통합 mock PASS: 주문·보상·합류·추격 연결 및 새 액션의 구 roundId/허용되지 않은 보상 요청 거부.
- 월드/괴물/스쿠터 데이터 모델: 스쿠터 4대/VehicleSeat/앵커/프롬프트 구성 PASS.
- Luau 컴파일, 엔진 비의존 모델 타입 검사, Rojo **32개 소스** 포함/일치 PASS.
- 배포 파일은 직접 `.rbxlx`로 갱신하며 ZIP을 만들지 않습니다.

## 남은 단계

P4 Studio 게이트: 실제 좌석 용접/주행/벽·경사·복구, 2·4인/네트워크 지연, 실제 모바일 UI/소리/30FPS. 실패를 수정한 다음 P5 저장/레벨/꾸미기 상점과 P6 접근성·사운드 폴리시·실기기·출시 QA로 진행합니다.
