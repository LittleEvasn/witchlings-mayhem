# AI 협업 보고서 — 인덱스

이 저장소를 연 새로운 ChatGPT/Codex는 `README.md` → `AGENTS.md` → 아래 활성 보고서 순서로 확인한다.

## 전투 HUD 최신 채용 (2026-10-31)

**정식 저장소:** https://github.com/LittleEvasn/witchlings-mayhem

- **최신 단일 기준:** [UI-HUD-2026-10-31-01 전투 HUD 승인 v1](reports/2026-10-31-combat-hud-revised-approved-v1.md) / [사용자 확정 결정](decisions/2026-10-31-approved-combat-hud-magicraft-layout-v1.md).
- 기존 UI 01~12 / 통합 설계 v0.2 / 시각 보드 v0.1 = **구 보고서(LEGACY REFERENCE)**. 보상·상자·그 외 화면은 미승인 기존 제안으로 보존하며 최신 전투 HUD 배치와 충돌하는 권고는 무효.
- **디자인 승인이지 코드 구현 완료가 아니다.** PNG 원본은 아직 GitHub에 별도 바이너리로 올리지 않았음.

## 활성 보고서

| 보고서 ID | 제목 | 상태 | 문서 | 다음 행동 |
|---|---|---|---|---|
| UI-HUD-2026-10-31-01 | **전투 HUD 최신 승인 배치 v1** (Magicraft 중심, 사용자 일반 전투 HUD 목업 채용) | **LATEST / APPROVED 디자인** (구현 전) | [보고서](reports/2026-10-31-combat-hud-revised-approved-v1.md) · [확정](decisions/2026-10-31-approved-combat-hud-magicraft-layout-v1.md) | 기존 UI-01~12 및 통합 v0.2의 과거 전투 HUD 배치보다 우선 |
| BAL-2026-10-30-01 | 뱀파이어 서바이버즈 대비 마법 발사 템포 밸런스 제안 | **PROPOSED** | [보고서](reports/2026-10-30-vs-fire-rate-balance.md) | 사용자 수치 검토·승인, 승인 후 Codex 구현과 실제 Godot A/B 테스트 |
| REF-2026-10-30-01 | 뱀서·마법공예 원작 역분석 공개 자료 링크 | **PROPOSED** (참고자료) | [자료 목록](reports/2026-10-30-vs-magicraft-reverse-engineering-sources.md) | 원작 코드·역분석 문서를 조사할 때 참고; 구현 승인 아님 |
| UI-2026-10-30-01 | 전투 HUD·중앙 3~4택·편집 전환·보물상자 잭팟 UI 개편 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-combat-hud-reward-chest-ui-proposal.md) | 사용자 UI 방향 검토·승인; 승인 이후 Codex 구현 및 Godot 화면·입력 검증 |
| UI-2026-10-30-02 | 캐릭터 선택 UI 레퍼런스·레이아웃 및 시작 마법 선택 흐름 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-character-selection-ui-research-proposal.md) | 사용자 B+C안·선택 단계·미구현 캐릭터 표시 정책 검토 및 승인; 승인 전 구현 금지 |
| UI-2026-10-30-03 | 게임 시작 화면·타이틀→전투 진입 흐름 조사 및 UI 개편 제안 (이미지 제외) | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-game-start-title-to-combat-ui-proposal.md) | 타이틀 구성·선택 단계·첫 진입 연출 사용자 검토; 승인 전 코드·그림 작업 금지 |
| UI-2026-10-30-04 | 발견 도감 UI 레퍼런스·탭/필터·합성 관계 및 강화 비교 개편 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-collection-codex-ui-research-proposal.md) | 사용자 도감 배치/6열/역할 필터/합성 관계/강화 정보 검토·승인, 승인 전 코드 구현 금지 |
| UI-2026-10-30-05 | 상점·제작 작업대 UI 레퍼런스 조사 및 구매·오브·가방 통합형 레이아웃 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-crafting-shop-workbench-ui-research-proposal.md) | 사용자 B안 통합 레이아웃·작업대 폭·성장 탭·스킨 방향 검토; 승인 전 구현/구매 금지 |
| UI-2026-10-30-06 | 승리·패배 결과 화면 레퍼런스·빌드 기록·승패 연출·재도전 UI 개편 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-victory-defeat-results-ui-research-proposal.md) | 사용자 결과 화면 위계·표정·연출·빌드 표시 검토/승인; 승인 전 코드·아트 변경 금지 |
| UI-2026-10-30-07 | ESC 일시정지 메뉴·설정 화면 레퍼런스·안전 확인창·옵션 분류 UI 개편 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-escape-pause-settings-ui-research-proposal.md) | 사용자 ESC 구성·런 종료 확인·설정 3분류 검토, 승인 전 코드/에셋 변경 금지 |
| UI-2026-10-30-08 | 실험 기록 UI 레퍼런스·최근 런 선택 상세·오브/유물·웨이브 복기 개편 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-experiment-run-history-ui-research-proposal.md) | 사용자 2열 일지/필터/웨이브 펼침 검토; 승인 전 코드·저장 스키마 변경 금지 |
| UI-2026-10-30-09 | 마법·유물 상세 툴팁 레퍼런스 및 Magicraft형 공통 정보 카드·슬롯 연계 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-spell-relic-tooltip-ui-research-proposal.md) | 사용자 Magicraft형 카드·상황별 상세량·슬롯 강조 검토; 승인 전 코드/에셋 변경 금지 |
| UI-2026-10-30-10 | 웨이브 전환·정예/위험 이벤트 경고·최종 보스 등장 UI 레퍼런스 및 연출 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-wave-transition-boss-intro-ui-research-proposal.md) | 사용자 비정지 배너/보스 인트로·경고 위치 검토; 실제 생성 연동 확인 후 별도 구현 승인 필요 |
| UI-2026-10-30-11 | Slay the Spire식 유물 보유 아이콘·Magicraft식 상세 카드·실시간 상태 UI 조사 및 개편 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-owned-relics-details-ui-research-proposal.md) | 사용자 유물창 정지 정책·아이콘/상세 배치 검토; 유물 강화 시스템은 미구현으로 별도 결정, 승인 전 코드 변경 금지 |
| UI-2026-10-30-12 | 마법·완성 합성·유물 첫 발견 알림 레퍼런스와 비정지 토스트·도감 NEW 표시 제안 | **LEGACY REFERENCE / PROPOSED** | [보고서](reports/2026-10-30-new-discovery-notification-ui-research-proposal.md) | 사용자 일반/합성 연출 강도·도감 NEW 지속 정책 검토, 프로필 신규 ID/알림 큐 설계는 승인 후; 게임 코드 미수정 |
| UI-COPY-2026-10-31-01 | **게임 내 짧은 문구 전면 개편** — 무문구 전투 위험·상자/첫 발견/승패 정보형 카피·실제 코드 교체 대상 | **PROPOSED** (개별 문구·구현 미확정) / **톤 정책 APPROVED** | [전면 수정 보고서](reports/2026-10-31-game-ui-short-copy-overhaul-v1.md) · [확정 문체 규칙](decisions/2026-10-31-battle-ui-copy-tone-no-cutesy-dialogue.md) | 유치한 구어체·감탄·중계형 경고 금지. Godot 문자열 교체는 별도 구현/검증 후 진행 |
| UI-2026-10-31-01 | **UI 통합 설계서 v0.2** · 기존 UI 01~12 통합, 화면별 참고 게임·참고 요소·시각 시안/검증 기준 | **LEGACY REFERENCE / PROPOSED** (통합 상위 제안; 개별 UI 보고서 01~12 유지) | [통합 설계서](reports/2026-10-31-ui-integrated-design-v02.md) | 개별 원문 보존, 참고 UI 실제 캡처·주석 보드·우리 16:9 목표 배치 이미지 확보 후 사용자 검토; 승인 전 구현 금지 |
| UI-VIS-2026-10-31-01 | **UI 시각 레퍼런스 보드 v0.1** · 원작 UI 스크린샷 출처 링크 + 우리 게임 PNG 4종 첨부 | **LEGACY REFERENCE / PROPOSED** (원작 이미지 외부 링크, 프로젝트 자체 PNG는 저장소에 포함) | [이미지 보드](reports/2026-10-31-ui-visual-reference-board-v01.md) | 4개 대표 화면의 공개 이미지 근거 확보; 주석 PNG·현재 Godot 캡처·16:9 목표 배치 시안 제작 및 사용자 검토 필요 |
| AI-AUTO-2026-10-30-01 | 실제 Godot 마법 60종 AI 자동 플레이 검사 및 미해결 2종 | **UNDER_REVIEW** (60종 실행·255검사 성공, 경고 2) | [실측 보고서](reports/2026-10-30-ai-autoplay-60-verification.md) | 천둥 인장·심판 낙뢰 5초 무피해 재현·원인 확인 |
| UI-MAGIC-2026-10-30-02 | 마법 조합 상쇄 노란 경고 / 비작동 빨간 경고 UI | **PROPOSED** (색상 규칙은 사용자 확정, 기술 구현·테스트 대기) | [진단 UI 보고서](reports/2026-10-30-magic-suppression-slot-diagnostics.md) · [확정 결정](decisions/2026-10-30-magic-warning-severity.md) | Codex: 별도 구현 요청 시 기존 슬롯 진단을 확장, 노랑은 시전 차단 금지 |
| STORY-TUTORIAL-2026-10-30-01 | 모카의 마법 조합 보충수업 · 튜토리얼 대사·장면·실습 완료 조건 | **PROPOSED** (방향 긍정 평가, 구현 승인·테스트 전) | [보고서](reports/2026-10-30-moka-magic-combination-tutorial-story-v1.md) | 사용자 대사·분량 검토; 확정 후 Godot 실습/장면전환 구현·검증 |
| STORY-2026-10-30-01 | 메인 스토리 1 「방과 후의 마녀들」 수정 대사본 | **PROPOSED** (인형은 익숙한 존재·실습장 전환 없음: 사용자 확정) | [스토리 1](reports/2026-10-30-story1-after-class-witches-dialogue-v1.md) | 대본 검토 후 동일 화면에서 튜토리얼 T01로 연결, 중복 T00 재생 금지 |
| STORY-2026-10-30-02 | 메인 스토리 2 「사고 수습 성공!」 일반 엔딩 4종 (과거 승인 대본) | **APPROVED 당시 원고 / 일부 장면 SUPERSEDED** (교수님 등장 부분은 최신 지시로 제외) | [구 대사본](reports/2026-10-30-story2-accident-resolved-general-endings-v2.md) | **최신 일반 엔딩은 통합 개정본 STORY-2026-10-30-04 우선**; 교수님 미등장·‘이거 언제 치우지?’ 추가 |
| STORY-2026-10-30-03 | 메인 스토리 3 「드디어 성공했어!」 공통 진엔딩: 실제 숙제 해결 후 마력 고갈·역소환 | **APPROVED** (사용자 원고 등록 승인, 게임 구현 전) | [진엔딩 대사본](reports/2026-10-30-story3-true-ending-mana-exhaustion-v2.md) | 기존 클리어 후 조건 분기, 별도 진엔딩 장면/보스/스테이지 없음·4명 공통·교수님 미등장 |
| STORY-2026-10-30-04 | **통합 스토리 개정 v3** · 허수아비 표적 / 교수님은 게임 오버 문구로만 / 일반 엔딩 청소 대사 추가 | **PROPOSED** (사용자 세부 연출 확정, 전체 개정 대본 최종 검토 전) | [통합 개정본](reports/2026-10-30-story-integrated-rewrite-straw-targets-v3.md) | 최우선 대본 기준: 교수님 스토리 비등장, ‘이거 언제 치우지?’ 적용. Godot 미구현 |
| STORY-2026-10-30-05 | 교수님은 게임 오버 문구로만 언급 / 일반 엔딩 ‘이거 언제 치우지?’ | **APPROVED** (사용자 설정 확정, 게임 미구현) | [확정 변경 보고서](reports/2026-10-30-professor-game-over-only-and-general-ending-cleanup.md) | 최신 통합 v3 기준 교수님 컷신 제거·일반 엔딩 청소 마무리·게임 오버 결과 문구 적용 |
| RELIC-2026-10-31-01 | **마법 작품 패러디 유물 네이밍 후보** — 해리 포터·하울·마녀의 모자 아틀리에 등 16개 레퍼런스 | **PROPOSED** (패러디 방향 사용자 긍정, 개별 이름·구현 미확정) | [이름 후보 보고서](reports/2026-10-31-magical-fiction-parody-relic-naming.md) | 6종 우선 후보 검토, 유물 효과·아트·코드 확정 전; 한국 전통/엉뚱한 잡동사니 중심 제외 |
| RELIC-2026-10-31-02 | **유물 28종 플레이버 텍스트 초안** — 마녀학원 12종·마법 작품 패러디 16종 | **PROPOSED** (사용자 요청으로 초안 등록, 개별 문구·채택 미확정) | [설명문 28종](reports/2026-10-31-relic-flavor-texts-28-draft.md) | 유물명·문구 최종 검토 및 기존 데이터 중복 확인; 효과·아트·코드 미구현, 서브 스토리는 마지막에 |
| MAGIC-BOOMERANG-2026-10-30-01 | 달빛 부메랑: 마법공예 회선검형 왕복 관통으로 개편, **기본 내장 도탄 삭제** | **APPROVED** (사용자 설계 확정, 코드 미구현) | [보고서](reports/2026-10-30-moon-boomerang-magicraft-reference-redesign.md) · [확정 결정](decisions/2026-10-30-boomerang-magicraft-reference-no-innate-bounce.md) | 향후 구현 시 회선 비행·왕복 타격·강화 도탄 삭제·쌍월륜/도탄 보조 호환성 테스트 |
| MAGIC-ICE-SWORD-2026-10-30-01 | 서리숨결→**얼음검**: 마법공예 **파마의 검** 코드 기준 정확한 휘두르기 구현 (사용자 원문: **“그대로 코드 배껴”**) | **APPROVED** (사용자 기획 확정, 코드 미구현) | [정밀 구현 보고서](reports/2026-10-30-frost-to-ice-sword-magicraft-source-port.md) · [확정 결정](decisions/2026-10-30-ice-sword-exact-magicraft-parma-sword.md) | 원본 회전·타격 구현을 Godot 대응 포팅, 냉염숨결/빙정 삼중파 영향 검토, 실제 시각·히트박스 검증 |
| MAGIC-VORTEX-2026-10-30-01 | 소용돌이 씨앗을 **마법공예 블랙홀 동작으로 교체**, 기존 소용돌이 간 **겹침·중첩 성장 삭제** | **APPROVED** (사용자 설계 확정, 코드 미구현) | [보고서](reports/2026-10-30-vortex-replace-with-magicraft-black-hole.md) · [확정 결정](decisions/2026-10-30-vortex-magicraft-black-hole-replacement.md) | 블랙홀 이동/흡입/틱 피해/시간 성장 원본 정밀 이식, 겹침 방지 정책·가시꽃 덫/합성 호환성 검증 |
| MAGIC-WHITE-HOLE-2026-10-31-01 | **공전 소용돌이(orbit_vortex) → 화이트홀**: 블랙홀과 동일하게 단일 개체 발사·이동, **흡인 대신 방사형 반발**, 쌍핵 공전·적 반대편 순간이동 폐기 | **APPROVED** (사용자 방향 확정; 반발 강도·피해·세부 수치 미확정 · **게임 코드 미수정**) | [개편 보고서](reports/2026-10-31-orbit-vortex-to-white-hole-replacement.md) · [확정 결정](decisions/2026-10-31-orbit-vortex-white-hole-replacement.md) | 레시피 소용돌이 씨앗+공전 유지; 블랙홀 개편과 동작 호환 후 실제 반발/틱피해/단일 개체 검증 |
| MAGIC-COLLAPSE-VORTEX-2026-10-31-01 | **붕괴 소용돌이(collapse_vortex)**: 기본 블랙홀보다 작은 핵·강한 흡인, **주변 적/탄환 흡수·압축 후 붕괴 폭발로 적과 흡수 탄환 사방 방출** | **APPROVED** (핵심 콘셉트 확정, 탄환 보존/적탄 소유권·흡인/피해/저장 수치 미확정 · **게임 코드 미수정**) | [개편 보고서](reports/2026-10-31-collapse-vortex-gravity-compress-release.md) · [확정 결정](decisions/2026-10-31-collapse-vortex-compress-absorb-release.md) | 기존 포획 수 비례 충격파 전용 효과 교체. 별도 구현 시 탄환 실제 흡수/복원 발사·적 방사형 방출·성능/연결 안전 검증 |
| MAGIC-THORN-2026-10-30-01 | 가시꽃 덫: **괴이한 지뢰처럼 굴러가는 씨앗 → 지연 후 원형 덫이 팍 전개** | **APPROVED** (사용자 방향 확정, 코드 미구현) | [구현 보고서](reports/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md) · [확정 결정](decisions/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md) | 원본 지뢰 굴림·감속·지연 이동을 대응 포팅하고 폭발 대신 원형 덫 전개, 합성/중첩 호환 검증 |
| MAGIC-BLAZING-THORN-2026-10-31-01 | **유성 가시꽃(구형 thorn+fall) → 작열 가시꽃(thorn+element_fire)**: 본체를 밟으면 **3~4개 화염 씨앗이 굴러가 소형 가시꽃 덫으로 전개**되는 번식형 합성 | **APPROVED** (핵심 동작 확정, 자식 재번식·피해/반경/굴림 세부 수치 미확정 · **게임 코드 미수정**) | [개편 보고서](reports/2026-10-31-meteor-thorn-to-blazing-thorn-seed-propagation.md) · [확정 결정](decisions/2026-10-31-meteor-thorn-to-blazing-thorn-rolling-seeds.md) | 낙하형 구 구현을 교체; 씨앗 실제 굴림·소형 덫 별도 발동·상한/재귀/연결·기본 thorn 물리/시한 가시꽃 회귀 검사 |
| MAGIC-HAILFRONT-2026-10-31-01 | **시한 가시꽃(timed_thorn / thorn+timer) 폐기 → 빙결+낙하(element_ice+fall) '빙설 전선'**: 느리게 전진하는 구름 아래에서 실제 우박 연속 낙하·피해·냉기 누적 | **APPROVED** (핵심 설계 확정 / 구름·우박 세부 수치 및 코드 미구현) | [개편·삭제 보고서](reports/2026-10-31-timed-thorn-replaced-by-hailfront-triple-frost-removed.md) · [확정 결정](decisions/2026-10-31-timed-thorn-hailfront-and-triple-frost-removal.md) | 보조+보조 신규 공격형 합성 실행체 필요. 기존 thorn+timer 폐기·새 우박 실제 착탄 및 상태효과·휘감기식 timer 호환 검증 |
| MAGIC-CHAIN-LIGHTNING-2026-10-31-01 | **천둥 인장(thunder_seal) → 체인 라이트닝**: 벼락+명중 후 유지, 최초 적 이후 **추가 4~5명**에게 실제 번개가 **적→적 순차 전이**(최대 서로 다른 5~6명) | **APPROVED** (연쇄 수와 핵심 동작 확정, 거리·피해·4/5 결정 조건 미확정 · **게임 코드 미수정**) | [개편 보고서](reports/2026-10-31-thunder-seal-to-chain-lightning-four-five-targets.md) · [확정 결정](decisions/2026-10-31-thunder-seal-chain-lightning-four-five-additional-targets.md) | 기존 천둥 인장 장판 폐기·고유 방문ID·실제 적간 연쇄 타격/VFX 구현 및 명중 후 개편·원소 번개·다중체인/보스/성능 검증 |
| MAGIC-JUDGEMENT-LIGHTNING-2026-10-31-01 | **심판 낙뢰(judgement)**: 기존 긴 캐스팅/확장 충격파를 폐기하고 **기본 벼락처럼 빠른 최초 타격 → 최초 착탄 좌표 고정 → 그곳 및 주변에 추가 낙뢰 4~5회**(최초 포함 총 5~6회) | **APPROVED** (동작·횟수 확정, 지연·피해·착탄 위치 분포 미확정 · **게임 코드 미수정**) | [개편 보고서](reports/2026-10-31-judgement-lightning-fast-strike-anchored-barrage.md) · [확정 결정](decisions/2026-10-31-judgement-lightning-fast-first-strike-anchored-four-five-barrage.md) | 기존 0.8초 예고/원형 AoE 3회 교체, 실제 개별 낙뢰·원래 좌표 재타격·주변 타격·피해/연결/고밀도 부하 검증 |
| MAGIC-TRIPLE-FROST-REMOVAL-2026-10-31-01 | **빙정 삼중파(triple_frost / frost+fan) 대체 없이 삭제**, 합성 1종 공석 유지 | **APPROVED / RETIRE PLANNED** (사용자 삭제 확정, 게임 코드는 아직 기존 30종 유지) | [개편·삭제 보고서](reports/2026-10-31-timed-thorn-replaced-by-hailfront-triple-frost-removed.md) · [확정 결정](decisions/2026-10-31-timed-thorn-hailfront-and-triple-frost-removal.md) | 기존 30 → 기획상 29종. 신규 조합 자동 보충 금지, 도감·제작·저장·테스트·frost+fan 차단 검증 |
| MAGIC-LASER-2026-10-30-01 | **레이저 → 마법공예 기본 광선(1004)**: 즉발 직선/굴절 광선, 분해 광선(1011)은 지속형 분리 | **UNDER_REVIEW** (Godot 263검사 성공·0실패, 웹 빌드 성공 / 브라우저 시각검증 전) | [구현·검증 보고서](reports/2026-10-30-laser-magicraft-1004-implementation.md) | [CI 263검사 성공](https://github.com/LittleEvasn/witchlings-mayhem/actions/runs/41056392316), 브라우저에서 광선 시각·입력·보조 호환성 검증 |
| MAGIC-FLAME-BURST-2026-10-30-01 | 화염방사기: **마법공예 원작 맹렬한 용의 숨결(1025)**의 전진 불꽃·사거리 확장을 **짧은 단발형 화염 버스트**로 개편 | **APPROVED** (사용자 방향 확정, 세부 수치 제안, 코드 미구현) | [상세 보고서](reports/2026-10-30-flamethrower-magicraft-1025-short-burst.md) · [확정 결정](decisions/2026-10-30-flamethrower-short-burst-dragon-breath-reference.md) | Codex: 별도 구현 요청 시 0.35~0.5초 버스트·전진 화염/VFX 일치·실제 타격/화상 검증; 우리 동명 합성 및 독염 분사 호환 확인 |
| MAGIC-ORBIT-2026-10-30-01 | **공전(orbit) → 마법공예 공전 3009 방식**: 투사체 속도 기반 각속도·추가 수명/속도·반경 덮어쓰기·시작각도·충돌 정합 | **APPROVED** (동작 계약 사용자 확정, 우리 3강/px 환산은 제안·코드 미구현) | [정밀 포팅 보고서](reports/2026-10-30-orbit-magicraft-3009-source-port.md) · [확정 결정](decisions/2026-10-30-orbit-magicraft-3009-motion-contract.md) | Codex: 별도 구현 시 원작 3009 대응 포팅·공전+잔불 P0·원호 충돌·낙하/광선/연결 호환·실제 Godot 수명/피해 검증 |
| MAGIC-SPLIT-2026-10-30-01 | **분열(3013) 원작식 개편 + 0~3강 3·4·5·6발**: 부모 소멸 시 분열, 자식 각각 피해33%·크기80%·속도50%, 원본 관통/수명 복구 | **UNDER_REVIEW** (Godot Magic60 830/0·AI 자동 플레이 263/0·경고2, 실제 수동 화면/부하 미확인) | [구현·미검증 보고서](reports/2026-10-30-split-magicraft-3013-3-4-5-6-implementation.md) · [확정 결정](decisions/2026-10-30-magicraft-split-3-4-5-6.md) | Godot에서 3/4/5/6발 실제 분열·피해/원본 관통·수명·광선·고부하 확인 후 VERIFIED 판정 |

| MAGIC-CHAIN-2026-10-31-01 | **복제 궤적(trail) → 마법공예 연쇄(3203) 기반 이동 중 자체 마법 복제 발사**. 노이타 Copy Trail이 최초 출처, A→A′ 발사·하위 B 불필요 | **APPROVED** (사용자 재확인·동작만 확정, 복제 횟수/피해/재복제 예외 미확정 · **게임 코드 미수정**) | [원작 근거·구현 계약](reports/2026-10-31-copy-trail-to-magicraft-chain-self-cast.md) · [최신 정정 보고서](reports/2026-10-31-trail-chain-timer-entangle-correction.md) | 별도 구현 요청 시 이동 중 실제 A′ 발사·피해/분열·합성 검증. **기존 trail→휘감기 공전 문서는 잘못된 대상** |

| MAGIC-CONNECTORS-2026-10-31-01 | **소멸 후 → 마법공예 이중주식 종료 피해 전이 / 명중 후 → 마법공예 메아리식 쿨다운 반복 명중 연결** | **APPROVED** (사용자 동작 방향 확정 · 0~3강 수치/마나 대체 미확정 · **게임 코드 미수정**) | [원작 근거·교체 보고서](reports/2026-10-31-duet-echo-replace-expire-impact.md) · [확정 결정](decisions/2026-10-31-expire-duet-impact-echo-reference.md) | 별도 구현 지시 시 부모 현재 피해 가산·명중 재발동·중복/특수공격/완성합성/성능 검증; 원작 3레벨과 우리 4단계·마나 부재는 별도 계약 |

| MAGIC-ENTANGLE-2026-10-31-01 | **[무효 이력] 복제 궤적(trail) → 마법공예 휘감기(3204)식 자체 복제·공전 및 복제 2/3/4/5개** | **SUPERSEDED** (사용자 적용 대상 정정, **게임 코드 미수정**) | [잘못된 적용 대상의 구안](reports/2026-10-31-copy-trail-to-magicraft-entangle-self-orbit.md) · [무효 결정문](decisions/2026-10-31-trail-entangle-2-3-4-5-self-orbit.md) | **이 계획 구현 금지. 휘감기 참고 대상은 시간 트리거(timer), 기존 연쇄 계획은 유효.** |
| MAGIC-TRIGGER-CORRECTION-2026-10-31-01 | **마법 대상 정정**: 복제 궤적(trail)=**마법공예 연쇄 3203**·이동 중 자기복제 A→A′ / 시간 트리거(timer)=**마법공예 휘감기 3204**·후속 B 공전 | **APPROVED** (참고 메커니즘·대상 확정, 횟수·피해·강화/실행 예외 미확정 · **게임 코드 미수정**) | [최신 정정 보고서](reports/2026-10-31-trail-chain-timer-entangle-correction.md) · [최신 확정 결정](decisions/2026-10-31-correction-trail-chain-timer-entangle.md) | 두 기능을 혼동하지 말 것. 이전 trail→휘감기 및 2/3/4/5개 공전 구안은 SUPERSEDED. 별도 구현 요청 전 코드 변경 금지 |
| MAGIC-BOLT-SPEAR-2026-10-31-01 | **별빛탄 0~+3강 1/2/3/4발(+1강 전방·후방) + 빛나는 창(별빛탄+관통) 4갈래·무한 적 관통·명중 적 중심 원형 범위 피해** | **APPROVED** (사용자 핵심 규칙 확정, +2/+3/합성 각도·범위 피해·반경·중복 타격 미확정 · **게임 코드 미수정**) | [정밀 개편 보고서](reports/2026-10-31-starlight-bolt-shining-spear-piercing-aoe-redesign.md) · [확정 결정](decisions/2026-10-31-bolt-1-2-3-4-shining-spear-4way-infinite-pierce-aoe.md) | 별도 구현 요청 시 실제 발사수/전후방/무한 관통/피격 적 중심 범위 실피해 검증. 기존 측면 2원 제거, 미확정 피해·각도는 별도 결정 |
| MAGIC-GLITTER-CHAIN-2026-10-31-01 | **반짝이 폭탄(꽃폭탄+분열)**: 기존 파편형 대신 피해 적 매개 **전염 범위 폭발**, 추가 전염 **6회 전체 공유**, 연쇄가 깊어질수록 피해 감소 | **APPROVED** (사용자 동작·6회·감쇠 방향 확정, 비율/반경/시간/분기 미확정 · **게임 코드 미수정**) | [상세 보고서](reports/2026-10-31-glitter-bomb-six-infections-damage-falloff.md) · [결정](decisions/2026-10-31-glitter-chain-six-damage-decay.md) | 최초 1회 + 추가 최대 6회, 가지마다 6회 초기화 금지. 별도 구현 요청 시 피격 적 중심·단계별 피해 감소 검증 |

## 검토·승인·구현 인계

- [DEC-2026-10-31-JUDGEMENT-LIGHTNING-01: 심판 낙뢰 빠른 최초 낙뢰·착탄 위치 중심 후속 4~5회](decisions/2026-10-31-judgement-lightning-fast-first-strike-anchored-four-five-barrage.md) **사용자 확정**. 기본 벼락과 같은 최초 낙하 속도, 최초 착탄 좌표 고정, 그곳·주위에 추가 낙뢰 4~5회(전체 5~6회). 세부 수치/위치분포 미정, 게임 코드 미수정.

- [DEC-2026-10-31-CHAIN-LIGHTNING-01: 천둥 인장 → 체인 라이트닝 / 최초 적 이후 4~5명 연쇄](decisions/2026-10-31-thunder-seal-chain-lightning-four-five-additional-targets.md) **사용자 확정**. 벼락+명중 후 레시피 유지, 적에서 적으로 실제 순차 전이·같은 체인 중복 타격 없음. 전이 거리/피해/정확한 4·5명 선택 조건 미확정, 코드 미수정.

- [DEC-2026-10-31-HAILFRONT-01: 시한 가시꽃 삭제 및 빙설 전선(빙결+낙하) 신설, 빙정 삼중파 삭제](decisions/2026-10-31-timed-thorn-hailfront-and-triple-frost-removal.md) **사용자 확정**. 늦게 전진하는 구름이 우박을 연속 낙하시켜 피해·냉기 누적. 빙정 삼중파는 대체하지 않고 합성 기획 29종/1공석, 실제 게임 코드 미수정.

- [DEC-2026-10-31-BLAZING-THORN-01: 유성 가시꽃 → 작열 가시꽃 / 화염 씨앗 번식](decisions/2026-10-31-meteor-thorn-to-blazing-thorn-rolling-seeds.md) **사용자 확정**. 기존 thorn+fall을 thorn+element_fire로 교체, 발동 시 굴러가는 씨앗 3~4개가 작은 화염 가시꽃 함정으로 전개. 새끼 재번식/수치/빙결+낙하 별도 미확정, 코드 미수정.

- [DEC-2026-10-31-COLLAPSE-01: 붕괴 소용돌이 강흡인·탄환 흡수·압축 및 방사형 방출](decisions/2026-10-31-collapse-vortex-compress-absorb-release.md) **사용자 핵심 방향 확정**. 구체 수치·속성 보존·적탄 소유권 미확정. 게임 코드 미수정.

- [DEC-2026-10-31-WHITE-HOLE-01: 공전 소용돌이 → 화이트홀](decisions/2026-10-31-orbit-vortex-white-hole-replacement.md) **사용자 확정**. 블랙홀과 동일 발사, 흡인→반발, 쌍핵 공전·적 이송 삭제, 코드 미수정.

- [DEC-2026-10-31-GLITTER-01: 반짝이 폭탄 전염 폭발 6회 공유·연쇄 단계별 피해 감소](decisions/2026-10-31-glitter-chain-six-damage-decay.md) **사용자 확정**. 피해율·범위·시간차·분기 수 미확정, 게임 코드 미수정.

- [DEC-2026-10-31-02: **게임 UI 문구는 건조하고 간결한 기능 라벨 사용 / 유아용 구어체·감탄·포위·박쥐 등 중계성 전투 안내 금지**](decisions/2026-10-31-battle-ui-copy-tone-no-cutesy-dialogue.md) **사용자 확정 문체 규칙**. 자세한 적용 시안은 [UI-COPY-2026-10-31-01](reports/2026-10-31-game-ui-short-copy-overhaul-v1.md). 실제 코드 미수정.

- [DEC-2026-10-31-04: 별빛탄 1/2/3/4발과 빛나는 창 4갈래·무한 관통·명중 대상 중심 원형 피해](decisions/2026-10-31-bolt-1-2-3-4-shining-spear-4way-infinite-pierce-aoe.md) **사용자 확정 방향**. 세부 발사 각도·범위 수치/중복 피해 규칙 미확정, 게임 코드 미수정.

- [DEC-2026-10-31-03: 복제 궤적(trail)→연쇄(3203)식 자기복제 발사, 시간 트리거(timer)→휘감기(3204)식 후속 공전](decisions/2026-10-31-correction-trail-chain-timer-entangle.md) **최신 사용자 확정 기준**. 생성 수·피해율·수명 등 미확정, 게임 코드 미수정.
- [DEC-2026-10-31-02: 과거 '복제 궤적→휘감기' 오작성](decisions/2026-10-31-trail-entangle-2-3-4-5-self-orbit.md) **SUPERSEDED / 무효 이력**. 구현 금지.

- [DEC-2026-10-31-01: 소멸 후는 마법공예 이중주(3201)식 부모 피해 추가 / 명중 후는 메아리(3205)식 쿨다운 재발동](decisions/2026-10-31-expire-duet-impact-echo-reference.md) **사용자 확정 방향**. 세부 수치·마나 대체 미확정, 게임 코드 미수정.


- [DEC-2026-10-30-10: 분열을 마법공예 3013 방식으로, 분열 수 3·4·5·6발](decisions/2026-10-30-magicraft-split-3-4-5-6.md) **사용자 확정**. 코드 반영했지만 실제 Godot 엔진·피해·성능 검증 전.

- [DEC-2026-10-30-09: 공전(orbit)을 마법공예 3009 이동·수명·반경 방식으로 통일](decisions/2026-10-30-orbit-magicraft-3009-motion-contract.md) **사용자 동작 계약 확정**. 4단계 수치·픽셀 환산은 제안/검증 전, 코드 미구현.

- [DEC-2026-10-30-08: 화염방사기 → 원작 맹렬한 용의 숨결(1025) 기반 단발형 분출](decisions/2026-10-30-flamethrower-short-burst-dragon-breath-reference.md) **사용자 개편 방향 확정**. 세부 밸런스·합성 수정 범위 미확정, 게임 코드 미수정.

- [DEC-2026-10-30-07: 가시꽃 덫을 괴이한 지뢰처럼 굴린 뒤 원형 전개](decisions/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md) **사용자 확정**. 코드 미수정, 물리 이동·전개·발동 분리 구현 및 검증 필요.

- [DEC-2026-10-30-06: 소용돌이 씨앗 → 마법공예 블랙홀 / 소용돌이 겹침·중첩 폐기](decisions/2026-10-30-vortex-magicraft-black-hole-replacement.md) **사용자 확정**. 코드 미수정, 포팅·테스트 필요.

- [DEC-2026-10-30-05: 서리숨결 → 얼음검 / 마법공예 파마의 검 충실 구현](decisions/2026-10-30-ice-sword-exact-magicraft-parma-sword.md) **사용자 확정**. 원문 “그대로 코드 배껴” 명시. 실제 코드 미변경.

- [DEC-2026-10-30-04: 달빛 부메랑을 마법공예 회선검형으로, 기본 내장 도탄 삭제](decisions/2026-10-30-boomerang-magicraft-reference-no-innate-bounce.md) **사용자 확정**. 보고서 등록만 완료; 코드 미변경.

- [DEC-2026-10-30-02: 상쇄=노랑 / 비작동=빨강](decisions/2026-10-30-magic-warning-severity.md) **사용자 확정**. 세부 구현 방식은 [관련 보고서](reports/2026-10-30-magic-suppression-slot-diagnostics.md) 검토 후 진행.
- [DEC-2026-10-30-03: 메인 스토리1 → 튜토리얼 → 프롤로그 → 일반 엔딩 → 진엔딩 / 일상 서브 스토리 2~3개](decisions/2026-10-30-story-main-flow-and-side-stories.md) **사용자 확정**. 튜토리얼 원고 T00/T01~05/T06~08의 재배치 기준이며 서브 스토리 세부 사건은 제안 단계.
- [DEC-2026-10-30-03 후속: 교수님은 게임 오버에서만 ‘교수님에게 혼났다’ 텍스트로 언급 / 일반 엔딩에 ‘이거 언제 치우지?’ 추가](decisions/2026-10-30-story-main-flow-and-side-stories.md) **사용자 확정**. 최신 [통합 개정 스토리](reports/2026-10-30-story-integrated-rewrite-straw-targets-v3.md) 우선.
- 다른 보고서는 명시적으로 결정되지 않았다. 기존 제안이 자동 승인되지는 않는다.
- 보고서의 `PROPOSED`는 **사용자 승인·코드 반영·실제 엔진 검증을 의미하지 않는다**.

## 완료 보관

- 아직 없음.

작업자가 변경 결과를 남길 때 보고서 상태 및 경로를 여기서 갱신한다. 채팅끼리 자동 알림을 보내지는 않는다.
