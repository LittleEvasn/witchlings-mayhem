# AI Workspace 협업 규칙

**정식 원격 저장소: `LittleEvasn/witchlings-mayhem` / https://github.com/LittleEvasn/witchlings-mayhem**

범위: `docs/ai-workspace/`. 저장소 최상위 `AGENTS.md`와 사용자의 최신 지시가 우선한다.

1. 작업 전 `README.md`, `INDEX.md`, 해당 보고서와 연관 최신 게임 문서를 확인한다.
2. 보고서에는 작성일, ID, 상태, 코드 기준 커밋, 근거, 검증 수준, 미확인 사항을 기록한다.
3. **소스 열람/코드 수식 계산/테스트 스크립트 작성/Godot 실제 실행/화면 확인/사용자 체감**을 별개로 기록한다. 서로 다른 증거를 모두 '테스트 완료'라고 부르지 않는다.
4. 여러 GPT의 독립적 의견은 `discussions/`에 근거를 남긴다. 동의/반대가 있는 문서를 조용히 덮어쓰지 않는다.
5. `PROPOSED` 보고서의 수치·규칙은 확정 사항이 아니다. 사용자 승인 없이 Codex가 이를 구현하지 않는다. 확정 사항은 `decisions/`에 기록한다.
6. 실제 구현 요청을 받으면 `handoffs/`에 변경 범위와 성공 조건을 기록한다. 구현·검증·커밋은 별개의 상태다.
7. 실제 수정 완료와 재현 테스트 성공, 커밋 또는 검증 근거가 있을 때만 `archive/`로 이동하고 `INDEX.md`를 수정한다.
8. 단순히 읽었다는 이유로 자동 보관하거나 삭제하지 않는다. GitHub Actions 자동 정리 또는 GPT 상시회의는 구현되지 않았다.

9. **사용자 확정 UI 문체 규칙(2026-10-31):** 전투·보상·상자·발견·제작·결과의 시스템 문구는 명사형/기능 라벨로 짧고 건조하게 쓴다. ‘~했어!’, ‘~해봐’, ‘~할까?’, ‘대박!’ 등 유치한 구어체·감탄·독려문을 금지한다. 일반 적/박쥐 떼/포위 알림은 기본 무문구로, 인물 대사·유물 플레이버 텍스트와 구별한다. [확정 결정](decisions/2026-10-31-battle-ui-copy-tone-no-cutesy-dialogue.md)과 [전체 UI 교체 보고서](reports/2026-10-31-game-ui-short-copy-overhaul-v1.md)가 구형 예시 문구에 우선한다. 게임 코드는 별도 구현 요청이 있어야 변경한다.

10. **전투 HUD 최신 승인:** [UI-HUD-2026-10-31-01](reports/2026-10-31-combat-hud-revised-approved-v1.md)의 배치가 우선. 좌상단 가방/바로 아래 오브4/상단 중앙 시계(Tab 개방 시 가림)/우상단 유물 세로/좌하단 HP·보호막·마석/맨 아래 EXP, MP·보스 HP바 없음. 예전 UI 보고서는 구 참고안이다.
11. 사용자가 “보고서 올려”라고 요청하면 **이 GitHub 저장소에 파일을 실제 커밋하고 `INDEX.md`를 업데이트**한다. 초안만 제출해서는 완료가 아니다. PNG 첨부 여부도 실제 바이너리 저장소 존재를 기준으로 구분한다.

권장 상태: `PROPOSED` → `UNDER_REVIEW` → `APPROVED` → `IN_PROGRESS` → `VERIFIED` → `ARCHIVED`. 필요 시 `REJECTED` 또는 `SUPERSEDED`.

마법 60종과 참고 게임을 다룰 때에는 현재 코드 버전과 `docs/PROJECT-HANDOFF.md`를 먼저 대조한다.
