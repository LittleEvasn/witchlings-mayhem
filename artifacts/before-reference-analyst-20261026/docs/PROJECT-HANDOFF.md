# 프로젝트 인수인계 · 2026-10-26

이 문서는 작은 진입점이다. 변경된 상태만 갱신하고 과거 대화 전체를 붙이지 않는다.

## 현재 목표와 보존할 상태
- 최신 실제플레이 피드백: 적이 약하고 추적+벼락 제자리생존, 이동목표없음, 제작 진입 전 대기가 지루함. 다음 우선은 전투압박/초반성장간격/선택이동보상이며 아트나 다른캐릭터 확대를 먼저 하지 않는다. `docs/COMBAT-PRESSURE-FEEDBACK-v1.md`는 조사·제안이며 게임수치/UI는 아직 변경하지 않았다. 중간3중1택/전장이 보이는 인벤/향후 멀티 개인창 비정지는 후속 제안. 현재8~10분 목표를 지루한 시간 채우기로 고정하지 않는다.
- Witchlings’ Mayhem: 1인 마법 조합 서바이벌. 두 오브 × 6칸, 마우스 조준 자동 발사.
- 실험 실패작의 마석으로 준비 시간에 마법/유물을 제작한다. 재시작하면 해당 실험의 성장과 유물이 사라진다.
- 구체 역할·보조 강화·두 오브 밸런스·유물 12개가 구현되어 있다. 자세한 규칙은 아래 최신 문서와 실제 코드로 확인한다.
- 사용자는 현재 맵과 몬스터·마법·제작·유물 상태가 지금 단계에 충분하다고 판단했다. 맵 미관이나 규모 개선을 다음 우선 작업으로 다시 제안하지 않는다. 현재 우선순위는 총괄의 업무 배정·추적을 통한 출시 준비다.
- 업무 보드 연결 구현 완료. 현재 채팅=개발책임(실제 세션 Sol6.1/high). 사용자 지시로 총괄/Luna/Astra/Sol검토 4역할이 순서대로 전체 출시 회의에 실제 참여했다. 최신 전체 기준은 `docs/RELEASE-MASTER-PLAN-v2.md`, 업무 명세는 `docs/RELEASE-BACKLOG-v2.json`. 이전 기술5개만으로 출시완성이라 판정하지 않는다.
- 사용자 승인 후 루미1인의 시작→성장→보스→일반엔딩→결과/재도전 경로 구현. 최신 시간은 일반전투90/105/120/135초+보스최대150초(전투최대10분), 제작 무제한, 준비포함12~15분은 플레이 목표다. 이전5분회의 기준보다 최신 사용자 결정을 따른다. 다른3마녀/진엔딩/본격 아트마감은 후속이며 이번 구현으로 최종 출시완성이라 하지 않는다. 상세: `docs/LUMI-RUN-v1.md`.
- 기본 소리설정·최근10회 결과·루미단서만 저장하며 진행 중 실험의 이어하기는 미지원(화면에 안내). 별도 Windows 실행파일 `artifacts/builds/lumi-run/WitchlingsMayhem.exe`, 빌드명세 export_presets.cfg, 재빌드 tools/build_lumi.py. 기존 캐릭터/맵/보스 그림은 재사용, 자체 합성 BGM3곡은 스케치다.
- 이번 관련 검사 lumi_run_test62 / prep_board_test35 통과, 고정시드 전체흐름 봇검사 및 실제화면 확인. 봇은 무적·가까운적조준이므로 사람의 난이도/재미 근거가 아니다. 전체 마법 전수검사는 재실행하지 않았다.
- 작업 폴더는 Git 저장소가 아니다(설정 당시 확인). 기존 편집은 되돌리지 않는다.

## 스크롤 맵 작업 상태
- 코드에는 4800×3600 월드, 추적 카메라, 화면 밖 적 생성, 월드 좌표 정리, 별도 trial/measurement 프로필이 들어 있다.
- 2026-10-26 재개 확인: `python tools/run_tests.py scroll_arena_test` 통과 (223 checks, 0 failures). 다른 검사군은 실행하지 않았다.
- 실제 게임에서 대각선 입력 12물리 프레임 후 카메라가 (2400,1800)에서 (2433.94,1833.94)로 따라오는 것을 확인했다. 예상 이동량 33.94와 일치하며 플레이어는 화면 중앙, HUD는 고정이었다.
- 실제 런타임에서 플레이어를 월드 좌상단·우하단 경계 좌표에 두고 카메라 화면을 확인했다. 카메라 뷰는 각각 (0,0)–(1440,900), (3360,2700)–(4800,3600)으로 월드 안에 유지됐다. 경계까지 직접 걸어가는 플레이 확인은 아직 안 했다.
- 실제 런타임에서 카메라 중앙/가장자리에서 마우스 좌표→월드 조준점 변환을 확인했다. 중앙에서는 커서 (1100,400) → 월드 (2917.5,1800), 조준 방향 오른쪽. 우하단 경계에서도 커서 (1100,400) → 월드 (4597.5,3150)으로 카메라 오프셋이 반영됐다. 발사체를 직접 커서에 맞춰 쏘는 연속 시각 검수는 별도 확인 항목이다.
- 기존 바닥 텍스처 반복감은 알려져 있다. 사용자는 현재 수준을 이번 단계에 충분하다고 승인했다. 아래 이전 확인 항목은 기록이며 미관 후속 작업을 강제로 재개하지 않는다.
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





