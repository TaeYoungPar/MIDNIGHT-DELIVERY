# 차량 엔진음 출처와 확인 범위

기존 `Motor`는 `rbxasset://sounds/action_footsteps_plastic.mp3`를 반복 재생했습니다. 이를 엔진 루프 `rbxassetid://6002661882` 참조로 교체했습니다. ID를 추측하지 않고 아래 공개 차량 모델을 내려받아 Sound의 AudioContent를 읽어 확인했습니다.

- 출처: [A-Chassis 1.7.2 stable 릴리스](https://github.com/lisphm/A-Chassis/releases/tag/v1.7.2-stable), `A-Chassis.1.7.2.rbxm`.
- 모델 경로: `A-Chassis 1.7.2 > A-Chassis Tune > Plugins > Sounds > ENG_Engine`.
- 확인 값: `AudioContent` URI `rbxassetid://6002661882`.
- 내려받은 모델 SHA-256: `df344662f30c83f42a83aad8ff8168db8a58932fcd7ddc79bff8f411b6743c67`.
- 해당 프레임워크의 스크립트/모델/오디오 바이너리를 이 프로젝트에 복사하지 않았습니다. 게임에서는 Roblox 오디오 에셋을 참조합니다. 프레임워크 코드의 라이선스가 개별 오디오의 권리를 보장한다고 간주하지 않습니다.

공개 모델의 참조는 현재 경험의 오디오 재생 권한이나 공개 배포 허용을 입증하지 않습니다. Roblox Store 메타데이터 요청은 이 환경에서 HTTP 403이었으며, Studio/Roblox 오디오 재생은 실행하지 못했습니다. 공개 출시 전 해당 에셋의 사용 가능 여부와 권리를 Creator Store/Creator Hub에서 확인해야 합니다. 별도의 오디오 업로드나 Roblox 키를 이 작업에서 생성/요청하지 않았습니다.

Studio에서 최신 rbxlx를 열고 Play → 내 스쿠터 탑승 → 공회전/가속/하차를 청취합니다. Output에 `Audio unavailable` 또는 에셋 접근 오류가 없어야 합니다. 권한이 거부되면 `AudioCatalog.Motor.id`를 경험에서 사용할 수 있는 엔진 음원으로 교체해야 합니다. 실패 시 발소리를 대신 틀지 않으며 게임 로직/HUD는 계속 작동합니다.

알림과 바람은 기존 Roblox 내장 사운드 경로를 유지합니다. 자체 녹음이나 전용 스쿠터 녹음이라고 주장하지 않습니다.
