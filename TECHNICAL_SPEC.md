# 기술 설계서 — Roblox / Luau / Rojo

## 1. 기술 스택과 실행 보장
- Roblox Studio (Luau), Rojo 7 프로젝트 파일 `default.project.json`, Git.
- 외부 npm/웹 런타임 및 외부 API 없이 실행되는 Roblox 네이티브 게임을 목표.
- 로컬 개발은 `rojo serve`로 Studio 동기화, 필요하면 `rojo build`로 place 생성 가능하게 구성.
- 필수 의존성은 최소화. Rojo 미설치 상황을 README에 설명. 게임의 실행에는 Rojo 플러그인 연동 또는 빌드/Studio 반입이 필요하다는 점을 숨기지 않는다.
- 외부 asset ID가 없어도 맵/차량/몬스터/GUI가 코드로 생성되어 1판을 시험 가능해야 한다.

## 2. 제안된 저장소 구조
```
midnight-delivery/
├─ default.project.json
├─ AGENTS.md
├─ README.md
├─ src/
│  ├─ shared/
│  │  ├─ Config.luau
│  │  ├─ Types.luau
│  │  ├─ Catalogs.luau
│  │  └─ RemoteNames.luau
│  ├─ server/
│  │  ├─ Bootstrap.server.luau
│  │  ├─ Services/
│  │  │  ├─ RoundService.luau
│  │  │  ├─ OrderService.luau
│  │  │  ├─ EventService.luau
│  │  │  ├─ MonsterService.luau
│  │  │  ├─ VehicleService.luau
│  │  │  ├─ PlayerStateService.luau
│  │  │  ├─ EconomyService.luau
│  │  │  ├─ DataService.luau
│  │  │  ├─ ShopService.luau
│  │  │  └─ SecurityService.luau
│  │  └─ World/
│  │     ├─ WorldBuilder.luau
│  │     ├─ BuildingFactory.luau
│  │     ├─ VehicleFactory.luau
│  │     └─ MonsterFactory.luau
│  └─ client/
│     ├─ Bootstrap.client.luau
│     ├─ Controllers/
│     │  ├─ HUDController.luau
│     │  ├─ InputController.luau
│     │  ├─ VehicleController.luau
│     │  ├─ ShopController.luau
│     │  └─ EffectsController.luau
│     └─ UI/
│        ├─ UIFactory.luau
│        └─ Theme.luau
├─ docs/
│  ├─ TESTING.md
│  ├─ KNOWN_LIMITATIONS.md
│  └─ IMPLEMENTATION_STATUS.md
└─ tools/ (선택: 검증 스크립트)
```
- Rojo는 `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayer.StarterPlayerScripts.Client`에 매핑.
- Roblox Studio에서 수동으로 파트를 만든 뒤 코드가 그 위치에 의존하게 하지 않는다.
- 1회 설정부터 처음 진입·맵 생성·UI 표시·한 판 종료까지 재현 가능한 절차 마련.

## 3. 서버가 신뢰하는 게임 상태
### RoundState
`WAITING → PREPARING → PLAYING → RESULTS → WAITING`
- WAITING: 20초(플레이어 1명 이상), PREPARING: 10초, PLAYING: 420초 최대, RESULTS: 15초.
- 라운드 종료 때 이벤트 구독, NPC, 도로 장애물, 주문, 보상 완료 플래그를 정리.
- 모든 타이머는 서버의 단조로운 경과 시간 기반으로, 클라이언트는 표시만 함.
- 각 라운드에 `roundId` 고유 값 생성; `roundId`가 일치하지 않는 원격 요청은 무시.

### OrderState
`CREATED → ACTIVE → (SPECIAL_EVENT) → COMPLETED | FAILED`
- 주문 3건/라운드, 순차 진행, 고객 타입과 목적지 중복 방지.
- 주문마다 `orderId`, `roundId`, `customerType`, `destinationId`, `expiresAt`, `attemptCount`, `completedByUserId`, `rewardedUserIds`.
- `completeOrder(player, orderId)`는 현재 활성 주문, 거리, 고객별 기믹 조건, 플레이어 상태를 서버에서 검사하고 **한 번만** 처리.
- 주문 실패가 반복되어도 다음 주문 생성이 막히지 않음.

### PlayerRoundState
- `isActiveParticipant`, `isDowned`, `invulnerableUntil`, `currentVehicleId`, `roundRewardCoins`, `roundRewardXP`, `lastInteractionAt`.
- 플레이어 퇴장/재접속에 안전하게 청소, 기절 시 12초 뒤 복구 또는 팀원 3초 상호작용.
- 중도 합류 유저는 결과 화면에서 참여 보상 지급 대상이 아님.

## 4. Remote API (최소·서버 중심)
서버가 `ReplicatedStorage/Remotes`를 생성하고 다음처럼 사용:
- `GameStateChanged` (server→client): phase, roundId, endsAt, order, event, members, teamProgress.
- `UIFeedback` (server→client): messageKey, parameters, severity.
- `PlayerDataChanged` (server→client): coins, xp, level, equippedCosmetics, ownedCosmetics.
- `RequestAction` (client→server): 액션 타입 `Sprint`, `ResetVehicle`, `EquipCosmetic`, `PurchaseWithCoins` 등 **허용 목록 기반**.
- `RequestSnapshot` (client→server / RemoteFunction 또는 이벤트 쌍): 합류 시 현재 상태 요청.
- 접근 가능한 배달/부활/노크는 가능한 한 `ProximityPrompt.Triggered` 서버 이벤트로 처리하되, **거리·라운드·소유·상태·쿨다운을 직접 재검증**.
- 클라이언트의 위치·재화·주문 성공 주장·이동 시간·구매 완료 신고를 신뢰하지 않는다.
- `RemoteFunction`에서 오래 걸리는 데이터 저장을 기다리지 말고 비동기 이벤트 흐름 권장.

## 5. 월드 생성 방식
- `WorldBuilder`는 서버 최초 시작에서 정해진 맵 배치를 Model 단위로 생성한다. 재호출하더라도 중복 생성하지 않는다.
- Workspace에 `GameWorld` 폴더. `Lobby`, `Roads`, `Buildings`, `Trees`, `DeliveryPoints`, `NPCs`, `Vehicles`, `Effects` 하위 폴더.
- 건물 모델에는 `DestinationId`, `CustomerType`, `InteractPoint` 등의 Attributes / Attachments 사용.
- 월드 좌표는 `Config.Map`에 중앙 집중. 게임 로직은 문자열 ID로 찾고, 임의 `workspace.Part123` 인덱스 금지.
- 목표 약 650x650 studs 내 도로, 본부, 네온 마을, 숲길, 외곽 주택 3채.
- 주문 미션 포인트는 정해진 생성 지점 3~6개. 거짓 집 시나리오에만 3개 인접 후보 집 사용.
- 맵 생성 실패 시 명시적인 오류 로그와 재현 가능한 시드 출력.
- 장식 모델은 Anchor/CanCollide 최적화 및 시야 방해 점검. 모든 주요 경로에 수동 안내표지 추가.

## 6. 괴물 추격 AI
- `MonsterService`에서 현재 이벤트용 1마리만 활성화(추격 겹침 방지).
- NPC는 `Humanoid`, `HumanoidRootPart`, PathfindingService waypoint 기반 이동 + 막힐 때 경로 재계산/단순 직선 이동 폴백.
- 추격 대상은 해당 이벤트를 유발한 플레이어. 그 유저가 기절/이탈하면 몬스터는 퇴장한다.
- 목표 근접 판정/기절 처리는 서버에서. 한 번 부딪힐 때 복수의 `Touched` 이벤트가 발생하더라도 1회 처리하도록 디바운스.
- 순찰/연출은 추격 제한 시간 8~12초, Pathfinding 계산 빈도 제한, 몬스터 제거 및 연결 해제 확인.
- 모델/애니메이션 에셋이 없어도 동작하는 저폴리 기본 몬스터 모델 사용.

## 7. 스쿠터 물리
- `VehicleFactory`가 4대 생성. 기본 모델 + VehicleSeat + 제약(또는 검증된 안정적 아케이드 제어)을 사용.
- PC WASD/모바일 탑승 조작 지원, 탑승/하차/복구/기절 시 처리.
- 최고 속도·가속·회전·후진 Config로 관리. 서버는 탑승자/지속 과속/위치 이상 판단.
- 맵 외곽 낙하 시 안전한 도로에 리스폰. 복구 버튼은 차가 탑승 중이거나 플레이어 소유/지정 차량일 때만 유효.
- 물리 소유권(NetworkOwnership)은 엔진 권장 흐름 따르되 원격 입력을 검증하고, 보상은 반드시 서버 측 근접 판정.
- 모바일에서 스쿠터가 안정적으로 조종되지 않으면 출시 차단 사유. 미완성 물리 구조 대신 작동하는 단순한 차량을 우선.

## 8. 데이터 구조와 보존
DataStore 이름 예: `MidnightDelivery_PlayerData_v1`, 키 `User_<userId>`.
```
{
  schemaVersion = 1,
  coins = 0,
  xp = 0,
  level = 1,
  lifetimeDeliveries = 0,
  ownedCosmetics = {"scooter_default", "outfit_default"},
  equipped = {scooterSkin = "scooter_default", outfit = "outfit_default"},
  tutorialSeen = false,
  updatedAt = 0
}
```
- `DataService`는 입장 시 로딩(실패 시 제한된 세션 전용 기본 프로필임을 안내)→메모리에서 처리→주기적 저장(예: 120~180초 + 무작위 지연), 이탈·종료 시 저장.
- UpdateAsync() 기반의 데이터 병합/버전 관리 및 성공 여부 확인. 저장 실패 시 재시도/백오프/로그, 무한 재시도 금지.
- 경쟁 서버 저장 충돌에서 데이터가 덮어써지지 않도록 세션 잠금 또는 동등한 안전 전략을 구현. 필요한 경우 검증된 ProfileStore 사용 가능하나 외부 의존성과 설치 절차를 문서화. 원칙은 외부 의존성 최소.
- 새로 생성한 Coins, 구매, 아이템 등은 서버만 변경. 로딩 실패 시 유료 구매 등 영구 쓰기 경로를 막아 데이터 유실 방지.
- UpdateAsync callback 내부 yield 금지. 중복 저장/오래된 저장이 최신 상태를 덮지 않게 안전장치.
- Studio API Services 접근을 활성화해야 저장 테스트가 가능한 상황을 README에 안내; 실서비스 데이터와 테스트 데이터를 구분.

## 9. 보상과 상점
- 순차 완료 보상은 `EconomyService`에서 단일 진입점으로 지급, `roundId+orderId+userId` 멱등성 키.
- 결과 보너스는 `roundId+userId` 단 한 번 지급. 서버 재시작/중복 클릭 방지.
- `Catalogs`의 itemId별 이름, Coin 가격, cosmetic slot, preview style을 정의.
- 구매 시 서버가 가격/소유 여부/잔액/아이템 존재를 검사 후 차감+지급, 중복 소비 및 연타 방지.
- 외부에 실제 로벅스 구매 상품이 생성되기 전까지 `MarketplaceService` 호출 금지 또는 UI 비활성화.
- GamePass 소유 검증은 서버. Developer Products 도입 시 MarketplaceService 단일 receipt 처리 지점에서 구매 ID 멱등 보장. Roblox 공식 문서가 안내하는 API를 사용하고, 성공 확인 전 지급 완료 처리 금지.

## 10. UI 구현
- `UIFactory`에서 PlayerGui에 ScreenGui 구성(로비/HUD/상점/결과/설정). ZIndex, Insets, 기기 해상도 고려.
- `HUDController`는 서버 스냅샷을 읽고 표시, 비즈니스 판정/시간 권위는 없음.
- 목적지 안내는 Workspace 좌표를 카메라 뷰포트로 변환하여 목표가 화면 밖일 때 화살표 회전. 거리도 표시.
- 텍스트 문구는 별도 키 테이블에 보관(한국어 기본, 영어 확장 용이).
- 모바일: ContextActionService 또는 UserInputService로 Sprint 버튼/설정 버튼 표시, `ProximityPrompt`는 Roblox 기본 터치 지원 활용.
- UI 고정 위치가 모바일 기본 조이스틱/점프 버튼과 충돌하지 않도록 화면비 테스트.
- GUI 업데이트는 서버 이벤트/로컬 타이머에 따라 필요할 때만 수행(매 프레임 UI 전체 재생성 금지).

## 11. 보안/최적화/관측
- 클라이언트 요청은 허용 액션 타입, 데이터 타입, 길이, 쿨다운, 거리, 권한, 목표 주문, 라운드 ID를 검사.
- ProximityPrompt도 악성 클라이언트가 원거리 실행할 수 있어 수동 서버 거리 재검증 필수.
- 몬스터 경로 계산 과다 호출 금지, 죽은 NPC/종료 라운드 이벤트 연결/이펙트 제거.
- 성능 목표: 일반적인 중저가 모바일 30FPS 지향(실제 기기 QA 필요; 성공을 자동 선언하지 않는다).
- Output에 오류/무한 yield 경고가 없도록 하고, 이벤트 횟수/라운드 결과/저장 실패 로그 제공.
- `RoundService`, `OrderService`, `EconomyService`는 테스트 가능한 순수 함수/모듈을 최대한 분리한다.
