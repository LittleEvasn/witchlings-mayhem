# 프로젝트 인수인계 · 2026-10-26

이 문서는 작은 진입점이다. 변경된 상태만 갱신하고 과거 대화 전체를 붙이지 않는다.

## 현재 목표와 보존할 상태
- Witchlings’ Mayhem: 1인 마법 조합 서바이벌. 두 오브 × 6칸, 마우스 조준 자동 발사.
- 실험 실패작의 마석으로 준비 시간에 마법/유물을 제작한다. 재시작하면 해당 실험의 성장과 유물이 사라진다.
- 구체 역할·보조 강화·두 오브 밸런스·유물 12개가 구현되어 있다. 자세한 규칙은 아래 최신 문서와 실제 코드로 확인한다.
- **스크롤 맵 작업은 사용자 요청으로 중단 상태다. 재개 지시 전에는 계속 구현/플레이 검증하지 않는다.**
- 작업 폴더는 Git 저장소가 아니다(설정 당시 확인). 기존 편집은 되돌리지 않는다.

## 중단한 맵 작업
- 코드에는 4800×3600 월드, 추적 카메라, 화면 밖 적 생성, 월드 좌표 정리, 별도 trial/measurement 프로필이 들어 있다.
- 이전 작업에서 관련 검사 통과 기록: scroll_arena 223 / random_spawns 20 / prep_board 35 / relics 149 / two_orb_measurement 41. 이는 이전 실행 기록이며 이번 에이전트 설정에서 재실행하지 않았다.
- 마지막 logical viewport 보정 후 실제 대각선 이동·맵 가장자리·마우스 조준 시각 확인과 최종 보고가 남았다. 맵 작업 완료로 취급하지 않는다.
- 기존 배경을 재사용한 바닥 패턴은 반복감이 보일 수 있다. 미관 완성 판정은 하지 않았다.
- 백업: `artifacts/scroll-arena-before-20261026-125528`.

## 필요한 문서만 읽기
| 주제 | 문서 / 주요 코드 |
|---|---|
| 순차·연결 문법 | docs/SPELL-PROGRAM-v1.md; scripts/spells.gd, spell_runtime.gd |
| 역할 변경 | docs/SPELL-ROLES-IMPLEMENTATION-v1.md; spell_behaviors.gd, fusion_effects.gd |
| 보조 강화 | docs/MODIFIER-UPGRADES-v1.md; spell_progression.gd, spell_forge.gd |
| 최신 밸런스 | docs/TWO-ORB-BALANCE-v1.md (이전 문서 수치보다 최신) |
| 유물 | docs/RELICS-v1.md; scripts/relics.gd, relic_ui.gd |
| 편집·제작 | scripts/orb_control.gd, spell_workbench.gd, economy.gd |
| 웨이브 | docs/RANDOMIZED-WAVES.md; scripts/waves.gd, game.gd |
| 스크롤 맵 | docs/ARENA-REFERENCE-NOTES.md; scripts/arena_world.gd, game.gd, waves.gd |
| 측정 | docs/MEASUREMENT-LAB.md; scripts/measurement_runner.gd |

## 검사 실행
프로젝트에서 `python tools/run_tests.py <suite>`로 관련 검사 하나를 지정한다.
예: spell_program_test, modifier_upgrades_test, forge_test, prep_board_test, relics_test, scroll_arena_test.
도구가 결과를 artifacts에 저장한다. 오래된 전체 검사에는 이전 설계 기대값이 남을 수 있으므로 무관한 전수 실행/기대값 변경 금지.
Godot: `C:/Users/user/Desktop/Godot_v4.6.2-stable_win64.exe`.
MCP는 연결된 프로젝트를 확인한 후 사용한다. 다른 게임 세션을 조작하지 않는다.

## 남은 알려진 문제
유물과 갈래·메아리·장판을 극단적으로 겹치면 생성 상한/성능 문제가 있다(RELICS-v1 기록). 일반 작업에 섞어 대규모 최적화하지 않는다.
게임이 재미있는지는 사용자 플레이 피드백으로 판단하며 검사 개수로 입증하지 않는다.
