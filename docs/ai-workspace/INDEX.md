# AI 협업 보고서 — 인덱스

이 저장소를 연 새로운 ChatGPT/Codex는 `README.md` → `AGENTS.md` → 아래 활성 보고서 순서로 확인한다.

## 활성 보고서

| 보고서 ID | 제목 | 상태 | 문서 | 다음 행동 |
|---|---|---|---|---|
| BAL-2026-10-30-01 | 뱀파이어 서바이버즈 대비 마법 발사 템포 밸런스 제안 | **PROPOSED** | [보고서](reports/2026-10-30-vs-fire-rate-balance.md) | 사용자 수치 검토·승인, 승인 후 Codex 구현과 실제 Godot A/B 테스트 |
| REF-2026-10-30-01 | 뱀서·마법공예 원작 역분석 공개 자료 링크 | **PROPOSED** (참고자료) | [자료 목록](reports/2026-10-30-vs-magicraft-reverse-engineering-sources.md) | 원작 코드·역분석 문서를 조사할 때 참고; 구현 승인 아님 |
| UI-2026-10-30-01 | 전투 HUD·중앙 3~4택·편집 전환·보물상자 잭팟 UI 개편 제안 | **PROPOSED** | [보고서](reports/2026-10-30-combat-hud-reward-chest-ui-proposal.md) | 사용자 UI 방향 검토·승인; 승인 이후 Codex 구현 및 Godot 화면·입력 검증 |
| UI-2026-10-30-02 | 캐릭터 선택 UI 레퍼런스·레이아웃 및 시작 마법 선택 흐름 제안 | **PROPOSED** | [보고서](reports/2026-10-30-character-selection-ui-research-proposal.md) | 사용자 B+C안·선택 단계·미구현 캐릭터 표시 정책 검토 및 승인; 승인 전 구현 금지 |
| AI-AUTO-2026-10-30-01 | 실제 Godot 마법 60종 AI 자동 플레이 검사 및 미해결 2종 | **UNDER_REVIEW** (60종 실행·255검사 성공, 경고 2) | [실측 보고서](reports/2026-10-30-ai-autoplay-60-verification.md) | 천둥 인장·심판 낙뢰 5초 무피해 재현·원인 확인 |
| UI-MAGIC-2026-10-30-02 | 마법 조합 상쇄 노란 경고 / 비작동 빨간 경고 UI | **PROPOSED** (색상 규칙은 사용자 확정, 기술 구현·테스트 대기) | [진단 UI 보고서](reports/2026-10-30-magic-suppression-slot-diagnostics.md) · [확정 결정](decisions/2026-10-30-magic-warning-severity.md) | Codex: 별도 구현 요청 시 기존 슬롯 진단을 확장, 노랑은 시전 차단 금지 |
| STORY-TUTORIAL-2026-10-30-01 | 모카의 마법 조합 보충수업 · 튜토리얼 대사·장면·실습 완료 조건 | **PROPOSED** (방향 긍정 평가, 구현 승인·테스트 전) | [보고서](reports/2026-10-30-moka-magic-combination-tutorial-story-v1.md) | 사용자 대사·분량 검토; 확정 후 Godot 실습/장면전환 구현·검증 |

## 검토·승인·구현 인계

- [DEC-2026-10-30-02: 상쇄=노랑 / 비작동=빨강](decisions/2026-10-30-magic-warning-severity.md) **사용자 확정**. 세부 구현 방식은 [관련 보고서](reports/2026-10-30-magic-suppression-slot-diagnostics.md) 검토 후 진행.
- [DEC-2026-10-30-03: 메인 스토리1 → 튜토리얼 → 프롤로그 → 일반 엔딩 → 진엔딩 / 일상 서브 스토리 2~3개](decisions/2026-10-30-story-main-flow-and-side-stories.md) **사용자 확정**. 튜토리얼 원고 T00/T01~05/T06~08의 재배치 기준이며 서브 스토리 세부 사건은 제안 단계.
- 다른 보고서는 명시적으로 결정되지 않았다. 기존 제안이 자동 승인되지는 않는다.
- 보고서의 `PROPOSED`는 **사용자 승인·코드 반영·실제 엔진 검증을 의미하지 않는다**.

## 완료 보관

- 아직 없음.

작업자가 변경 결과를 남길 때 보고서 상태 및 경로를 여기서 갱신한다. 채팅끼리 자동 알림을 보내지는 않는다.
