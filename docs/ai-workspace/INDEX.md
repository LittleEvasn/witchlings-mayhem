# AI 협업 보고서 — 인덱스

이 저장소를 연 새로운 ChatGPT/Codex는 `README.md` → `AGENTS.md` → 아래 활성 보고서 순서로 확인한다.

## 활성 보고서

| 보고서 ID | 제목 | 상태 | 문서 | 다음 행동 |
|---|---|---|---|---|
| BAL-2026-10-30-01 | 뱀파이어 서바이버즈 대비 마법 발사 템포 밸런스 제안 | **PROPOSED** | [보고서](reports/2026-10-30-vs-fire-rate-balance.md) | 사용자 수치 검토·승인, 승인 후 Codex 구현과 실제 Godot A/B 테스트 |
| REF-2026-10-30-01 | 뱀서·마법공예 원작 역분석 공개 자료 링크 | **PROPOSED** (참고자료) | [자료 목록](reports/2026-10-30-vs-magicraft-reverse-engineering-sources.md) | 원작 코드·역분석 문서를 조사할 때 참고; 구현 승인 아님 |
| UI-2026-10-30-01 | 전투 HUD·중앙 3~4택·편집 전환·보물상자 잭팟 UI 개편 제안 | **PROPOSED** | [보고서](reports/2026-10-30-combat-hud-reward-chest-ui-proposal.md) | 사용자 UI 방향 검토·승인; 승인 이후 Codex 구현 및 Godot 화면·입력 검증 |
| UI-2026-10-30-02 | 캐릭터 선택 UI 레퍼런스·레이아웃 및 시작 마법 선택 흐름 제안 | **PROPOSED** | [보고서](reports/2026-10-30-character-selection-ui-research-proposal.md) | 사용자 B+C안·선택 단계·미구현 캐릭터 표시 정책 검토 및 승인; 승인 전 구현 금지 |
| UI-2026-10-30-03 | 게임 시작 화면·타이틀→전투 진입 흐름 조사 및 UI 개편 제안 (이미지 제외) | **PROPOSED** | [보고서](reports/2026-10-30-game-start-title-to-combat-ui-proposal.md) | 타이틀 구성·선택 단계·첫 진입 연출 사용자 검토; 승인 전 코드·그림 작업 금지 |
| UI-2026-10-30-04 | 발견 도감 UI 레퍼런스·탭/필터·합성 관계 및 강화 비교 개편 제안 | **PROPOSED** | [보고서](reports/2026-10-30-collection-codex-ui-research-proposal.md) | 사용자 도감 배치/6열/역할 필터/합성 관계/강화 정보 검토·승인, 승인 전 코드 구현 금지 |
| UI-2026-10-30-05 | 상점·제작 작업대 UI 레퍼런스 조사 및 구매·오브·가방 통합형 레이아웃 제안 | **PROPOSED** | [보고서](reports/2026-10-30-crafting-shop-workbench-ui-research-proposal.md) | 사용자 B안 통합 레이아웃·작업대 폭·성장 탭·스킨 방향 검토; 승인 전 구현/구매 금지 |
| UI-2026-10-30-06 | 승리·패배 결과 화면 레퍼런스·빌드 기록·승패 연출·재도전 UI 개편 제안 | **PROPOSED** | [보고서](reports/2026-10-30-victory-defeat-results-ui-research-proposal.md) | 사용자 결과 화면 위계·표정·연출·빌드 표시 검토/승인; 승인 전 코드·아트 변경 금지 |
| UI-2026-10-30-07 | ESC 일시정지 메뉴·설정 화면 레퍼런스·안전 확인창·옵션 분류 UI 개편 제안 | **PROPOSED** | [보고서](reports/2026-10-30-escape-pause-settings-ui-research-proposal.md) | 사용자 ESC 구성·런 종료 확인·설정 3분류 검토, 승인 전 코드/에셋 변경 금지 |
| UI-2026-10-30-08 | 실험 기록 UI 레퍼런스·최근 런 선택 상세·오브/유물·웨이브 복기 개편 제안 | **PROPOSED** | [보고서](reports/2026-10-30-experiment-run-history-ui-research-proposal.md) | 사용자 2열 일지/필터/웨이브 펼침 검토; 승인 전 코드·저장 스키마 변경 금지 |
| UI-2026-10-30-09 | 마법·유물 상세 툴팁 레퍼런스 및 Magicraft형 공통 정보 카드·슬롯 연계 제안 | **PROPOSED** | [보고서](reports/2026-10-30-spell-relic-tooltip-ui-research-proposal.md) | 사용자 Magicraft형 카드·상황별 상세량·슬롯 강조 검토; 승인 전 코드/에셋 변경 금지 |
| AI-AUTO-2026-10-30-01 | 실제 Godot 마법 60종 AI 자동 플레이 검사 및 미해결 2종 | **UNDER_REVIEW** (60종 실행·255검사 성공, 경고 2) | [실측 보고서](reports/2026-10-30-ai-autoplay-60-verification.md) | 천둥 인장·심판 낙뢰 5초 무피해 재현·원인 확인 |
| UI-MAGIC-2026-10-30-02 | 마법 조합 상쇄 노란 경고 / 비작동 빨간 경고 UI | **PROPOSED** (색상 규칙은 사용자 확정, 기술 구현·테스트 대기) | [진단 UI 보고서](reports/2026-10-30-magic-suppression-slot-diagnostics.md) · [확정 결정](decisions/2026-10-30-magic-warning-severity.md) | Codex: 별도 구현 요청 시 기존 슬롯 진단을 확장, 노랑은 시전 차단 금지 |
| STORY-TUTORIAL-2026-10-30-01 | 모카의 마법 조합 보충수업 · 튜토리얼 대사·장면·실습 완료 조건 | **PROPOSED** (방향 긍정 평가, 구현 승인·테스트 전) | [보고서](reports/2026-10-30-moka-magic-combination-tutorial-story-v1.md) | 사용자 대사·분량 검토; 확정 후 Godot 실습/장면전환 구현·검증 |
| STORY-2026-10-30-01 | 메인 스토리 1 「방과 후의 마녀들」 수정 대사본 | **PROPOSED** (인형은 익숙한 존재·실습장 전환 없음: 사용자 확정) | [스토리 1](reports/2026-10-30-story1-after-class-witches-dialogue-v1.md) | 대본 검토 후 동일 화면에서 튜토리얼 T01로 연결, 중복 T00 재생 금지 |
| STORY-2026-10-30-02 | 메인 스토리 2 「사고 수습 성공!」 일반 엔딩 4종 개정 대사본 | **APPROVED** (사용자 대사본 보고서 등록 승인, 게임 구현 전) | [스토리 2 개정본](reports/2026-10-30-story2-accident-resolved-general-endings-v2.md) | 이 원고 기준 공통 도입·캐릭터별 엔딩 4종·공통 마무리; 구현은 별도 요청 시 |
| STORY-2026-10-30-03 | 메인 스토리 3 「드디어 성공했어!」 공통 진엔딩: 실제 숙제 해결 후 마력 고갈·역소환 | **APPROVED** (사용자 원고 등록 승인, 게임 구현 전) | [진엔딩 대사본](reports/2026-10-30-story3-true-ending-mana-exhaustion-v2.md) | 기존 클리어 후 조건 분기, 별도 진엔딩 장면/보스/스테이지 없음·4명 공통·교수님 미등장 |
| MAGIC-BOOMERANG-2026-10-30-01 | 달빛 부메랑: 마법공예 회선검형 왕복 관통으로 개편, **기본 내장 도탄 삭제** | **APPROVED** (사용자 설계 확정, 코드 미구현) | [보고서](reports/2026-10-30-moon-boomerang-magicraft-reference-redesign.md) · [확정 결정](decisions/2026-10-30-boomerang-magicraft-reference-no-innate-bounce.md) | 향후 구현 시 회선 비행·왕복 타격·강화 도탄 삭제·쌍월륜/도탄 보조 호환성 테스트 |
| MAGIC-ICE-SWORD-2026-10-30-01 | 서리숨결→**얼음검**: 마법공예 **파마의 검** 코드 기준 정확한 휘두르기 구현 (사용자 원문: **“그대로 코드 배껴”**) | **APPROVED** (사용자 기획 확정, 코드 미구현) | [정밀 구현 보고서](reports/2026-10-30-frost-to-ice-sword-magicraft-source-port.md) · [확정 결정](decisions/2026-10-30-ice-sword-exact-magicraft-parma-sword.md) | 원본 회전·타격 구현을 Godot 대응 포팅, 냉염숨결/빙정 삼중파 영향 검토, 실제 시각·히트박스 검증 |
| MAGIC-VORTEX-2026-10-30-01 | 소용돌이 씨앗을 **마법공예 블랙홀 동작으로 교체**, 기존 소용돌이 간 **겹침·중첩 성장 삭제** | **APPROVED** (사용자 설계 확정, 코드 미구현) | [보고서](reports/2026-10-30-vortex-replace-with-magicraft-black-hole.md) · [확정 결정](decisions/2026-10-30-vortex-magicraft-black-hole-replacement.md) | 블랙홀 이동/흡입/틱 피해/시간 성장 원본 정밀 이식, 겹침 방지 정책·가시꽃 덫/합성 호환성 검증 |
| MAGIC-THORN-2026-10-30-01 | 가시꽃 덫: **괴이한 지뢰처럼 굴러가는 씨앗 → 지연 후 원형 덫이 팍 전개** | **APPROVED** (사용자 방향 확정, 코드 미구현) | [구현 보고서](reports/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md) · [확정 결정](decisions/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md) | 원본 지뢰 굴림·감속·지연 이동을 대응 포팅하고 폭발 대신 원형 덫 전개, 합성/중첩 호환 검증 |
| MAGIC-LASER-2026-10-30-01 | **레이저 → 마법공예 기본 광선(1004)**: 즉발 직선/굴절 광선, 분해 광선(1011)은 지속형 분리 | **UNDER_REVIEW** (Godot 263검사 성공·0실패, 웹 빌드 성공 / 브라우저 시각검증 전) | [구현·검증 보고서](reports/2026-10-30-laser-magicraft-1004-implementation.md) | [CI 263검사 성공](https://github.com/LittleEvasn/witchlings-mayhem/actions/runs/41056392316), 브라우저에서 광선 시각·입력·보조 호환성 검증 |
| MAGIC-FLAME-BURST-2026-10-30-01 | 화염방사기: **마법공예 원작 맹렬한 용의 숨결(1025)**의 전진 불꽃·사거리 확장을 **짧은 단발형 화염 버스트**로 개편 | **APPROVED** (사용자 방향 확정, 세부 수치 제안, 코드 미구현) | [상세 보고서](reports/2026-10-30-flamethrower-magicraft-1025-short-burst.md) · [확정 결정](decisions/2026-10-30-flamethrower-short-burst-dragon-breath-reference.md) | Codex: 별도 구현 요청 시 0.35~0.5초 버스트·전진 화염/VFX 일치·실제 타격/화상 검증; 우리 동명 합성 및 독염 분사 호환 확인 |
| MAGIC-ORBIT-2026-10-30-01 | **공전(orbit) → 마법공예 공전 3009 방식**: 투사체 속도 기반 각속도·추가 수명/속도·반경 덮어쓰기·시작각도·충돌 정합 | **APPROVED** (동작 계약 사용자 확정, 우리 3강/px 환산은 제안·코드 미구현) | [정밀 포팅 보고서](reports/2026-10-30-orbit-magicraft-3009-source-port.md) · [확정 결정](decisions/2026-10-30-orbit-magicraft-3009-motion-contract.md) | Codex: 별도 구현 시 원작 3009 대응 포팅·공전+잔불 P0·원호 충돌·낙하/광선/연결 호환·실제 Godot 수명/피해 검증 |

## 검토·승인·구현 인계

- [DEC-2026-10-30-09: 공전(orbit)을 마법공예 3009 이동·수명·반경 방식으로 통일](decisions/2026-10-30-orbit-magicraft-3009-motion-contract.md) **사용자 동작 계약 확정**. 4단계 수치·픽셀 환산은 제안/검증 전, 코드 미구현.

- [DEC-2026-10-30-08: 화염방사기 → 원작 맹렬한 용의 숨결(1025) 기반 단발형 분출](decisions/2026-10-30-flamethrower-short-burst-dragon-breath-reference.md) **사용자 개편 방향 확정**. 세부 밸런스·합성 수정 범위 미확정, 게임 코드 미수정.

- [DEC-2026-10-30-07: 가시꽃 덫을 괴이한 지뢰처럼 굴린 뒤 원형 전개](decisions/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md) **사용자 확정**. 코드 미수정, 물리 이동·전개·발동 분리 구현 및 검증 필요.

- [DEC-2026-10-30-06: 소용돌이 씨앗 → 마법공예 블랙홀 / 소용돌이 겹침·중첩 폐기](decisions/2026-10-30-vortex-magicraft-black-hole-replacement.md) **사용자 확정**. 코드 미수정, 포팅·테스트 필요.

- [DEC-2026-10-30-05: 서리숨결 → 얼음검 / 마법공예 파마의 검 충실 구현](decisions/2026-10-30-ice-sword-exact-magicraft-parma-sword.md) **사용자 확정**. 원문 “그대로 코드 배껴” 명시. 실제 코드 미변경.

- [DEC-2026-10-30-04: 달빛 부메랑을 마법공예 회선검형으로, 기본 내장 도탄 삭제](decisions/2026-10-30-boomerang-magicraft-reference-no-innate-bounce.md) **사용자 확정**. 보고서 등록만 완료; 코드 미변경.

- [DEC-2026-10-30-02: 상쇄=노랑 / 비작동=빨강](decisions/2026-10-30-magic-warning-severity.md) **사용자 확정**. 세부 구현 방식은 [관련 보고서](reports/2026-10-30-magic-suppression-slot-diagnostics.md) 검토 후 진행.
- [DEC-2026-10-30-03: 메인 스토리1 → 튜토리얼 → 프롤로그 → 일반 엔딩 → 진엔딩 / 일상 서브 스토리 2~3개](decisions/2026-10-30-story-main-flow-and-side-stories.md) **사용자 확정**. 튜토리얼 원고 T00/T01~05/T06~08의 재배치 기준이며 서브 스토리 세부 사건은 제안 단계.
- 다른 보고서는 명시적으로 결정되지 않았다. 기존 제안이 자동 승인되지는 않는다.
- 보고서의 `PROPOSED`는 **사용자 승인·코드 반영·실제 엔진 검증을 의미하지 않는다**.

## 완료 보관

- 아직 없음.

작업자가 변경 결과를 남길 때 보고서 상태 및 경로를 여기서 갱신한다. 채팅끼리 자동 알림을 보내지는 않는다.
