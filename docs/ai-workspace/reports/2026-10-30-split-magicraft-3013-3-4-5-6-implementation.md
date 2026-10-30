# MAGIC-SPLIT-2026-10-30-01 · 분열(3013) 원작식 코드 개편 + 0~3강 3·4·5·6개

> **상태: IN_PROGRESS / GitHub 코드 반영·검증 테스트 추가 완료, 실제 Godot 엔진 실행 및 전투 확인 미실행.** 원작 완전 등가라고 판단하지 않음.

- 날짜: 2026-10-30
- 프로젝트: `LittleEvasn/witchlings-mayhem`
- 사용자 확정: [DEC-2026-10-30-10](../decisions/2026-10-30-magicraft-split-3-4-5-6.md)
- 원작 참조: Magicraft `Split` ID 3013 (원본 3/5/8기본 3강). `kav1982/_reverse_engineering`의 `SpellDestroySystem.cs`, `SpellSpawnParamsStorage.cs`, `ShootSpellUtils.cs`, `SpellSystem.cs`, `分裂逆向分析.md`.
- 이번 작업: **기존 게임 코드를 실제로 수정해 GitHub에 업로드**, 관련 테스트 수정. **로컬 Godot 실행기 없어서 테스트 실행 및 시각 확인은 하지 못함**.

## 1. 원작과 관찰의 정합성

사용자가 직접 테스트한 **“타격했을 때 분열된다”**는 상황은 원작의 일반적인 비관통 투사체에서는 맞다.

원작 `SpellSystem.Execute`는 적 `Enter` 피해 후 소멸 조건이 만족되면 `SpellDestroyTag`를 켠다. 그 후 `SpellDestroySystem.ProcessDestroy`가 해당 엔티티를 파괴하면서 `Split()`을 실행한다. 따라서 **적중 → 부모 소멸 → 분열**이며, 관통 등으로 부모가 살아 있다면 매 명중마다 바로 분열하는 방식이라고 단정할 수 없다.

우리 기존 로직은 `magic_extensions.impact()`에서 선제적으로 `split()`을 호출했고, `instant_laser`도 궤적 판정/명중 시 분열을 앞당겼다. 새 계약은 **부모 정상 종료 `finish()` 한 곳에서 분열**을 소유하게 한다. 첫 적중으로 죽는 기본탄은 그 종료 프레임에 분열한다.

## 2. 원작 수치와 사용자 확정값

| 항목 | 마법공예 `3013` | 현재 사용자 확정 Godot |
|---|---|---|
| 강화 단계 | Lv1 / Lv2 / Lv3 | 0강 / 1강 / 2강 / 3강 |
| 자식 생성 수 | 3 / 5 / 8 | **3 / 4 / 5 / 6** |
| 자식 피해 | 각각 부모 33% | **각각 부모 33%** |
| 총 잠재 추가 피해(모두 명중 시) | 99 / 165 / 264% | **99 / 132 / 165 / 198%** |
| 기본 크기·판정 반경 | ×0.8 | **×0.8** |
| 비낙하 이동 속도 | ×0.5 | **×0.5** |
| 밀침 | ×0.5 | **×0.5** |
| 수명/관통 | 발사 당시 스냅샷의 전체값으로 재시작 | 생성 당시 `_split_launch` 기록을 이용해 복구 |
| 재분열·후속 트리거 | 금지 | 금지 |
| 방향/배치 | 난수 시작각 + 360° / 자식 수, 종료점 주변 | 동일 계산 방식 / 2D px 반경 |
| 저FPS 압축 | 자식 수 줄이고 데미지/효율 보정 | **미구현**(후속 부하 검증 대상) |

## 3. 실제 변경한 Godot 코드

| 경로 | 반영 내용 |
|---|---|
| `scripts/modifier_effects.gd` | 분열 강화 배열 `[3,4,5,6]`, 각 33% 및 80% 크기/50% 속도 툴팁 |
| `scripts/magic_catalog.gd`, `scripts/spells.gd` | 첫 명중 무조건 분열/전체 55% 설명 제거, **부모 소멸 시 3~6발** 표시 |
| `scripts/magic_extensions.gd` | `impact()`의 조기 `split()` 제거, `finish()` 분열 유지. `split()`에서 자식별 독립 생성·난수 위상·33% 피해·0.8 크기·0.5 비낙하 속도·0.5 밀침·수명/관통 스냅샷 복구용 필드 설정. `attach()`에 초기 수명/속도/반경/관통 기록 |
| `scripts/spell_behaviors.gd` | 기본 피해 계산에 자식 분열 `_split_damage_ratio`만 곱하며, 원소량 등에 쓰는 `factor`는 별도 보존. 밀침은 자식 50% 보정 |
| `scripts/spell_runtime.gd` | 투사체 생성 시 자식에게 `_split_launch`의 속도/수명/반경/관통 적용, 부모 발사 당시 정보 별도 저장. 설치형도 초기정보 기록 |
| `scripts/instant_laser.gd` | 광선 명중 즉시 선제 분열 제거; 광선이 실제 종료된 후 자식 생성. 자식의 광선 길이를 절반으로 사용 |
| `tests/magic60_test.gd` | 기존 분열3강 수 5→6 예상값 변경; 0~3강 3/4/5/6개, 각 자식 피해/반경/속도·전체 수명, 비관통 적중 시 분열, 관통 중 조기 분열 방지 회귀 추가 |

## 4. 원작 완전 이식으로 주장할 수 없는 부분

1. **원작은 발사 당시 이미 계산해 둔 통합 `SpellSpawnParams`를 복사**, 현재 우리 구조는 일부 투사체 수치만 `_split_launch`로 복원하고 나머지 보조 효과를 `stage` 재구성으로 처리한다. 원소·추적·공전·특수 속성 전부의 **1:1 재현 검증은 아직 안 됐다**.
2. 원작 자식은 부모의 시전 트리거 5종/후속 그룹 제거, 일회성 다중 시전 재실행 방지. 우리도 분열·갈래·메아리·연결 재생성을 막지만 모든 원작 발사 설정과 동일하지는 않다.
3. 원작의 비낙하 `Speed×0.5`는 일부 공격에서 레이저 길이로 쓰인다. 우리도 기본 광선 범위 절반 처리를 추가했지만, **화염분사·덫·낙하·위성·고유 합성의 특수 분열은 별도 동작 계측**이 필요하다.
4. 설치형 및 우리 고유 완성 합성은 원작과 1:1 대응 마법이 아니다. 이번 패치는 이름/공격 성질이 유지되도록 했으나 일부 원본 외형/피해/특수 복제 효과는 회귀 검사가 필요하다.
5. 프레임당 생성 안전 상한 `MAX_EMITS_PER_TICK`와 `MAX_PROJECTILES`은 그대로다. 원작처럼 수를 줄인 만큼 피해 보정하는 로직은 아직 없다. **상한으로 자식이 조용히 누락되면 전체 완료 판정 금지**.
6. 현재 빌드의 기존 `공전+잔불 발자국` P0/낙하 각 공격별 문제는 별도 추적 중이며, 분열 수정을 이유로 해결했다고 표시하지 않는다.

## 5. 실행 검증을 위한 독립 완료 조건

- 기본 `bolt`: 적이 없을 때 정상 만료 후 3/4/5/6발, 실제 각 33%, 기존 부모 22 피해 기준 기본 자식 7.26. **생성 로그가 아니라 각 자식의 실제 충돌·피해를 확인**.
- `split@3 + bolt`: 여섯 자식이 정확히 한 번만 생성, 서로 60° 간격 + 랜덤 시작각. 부모 정상 종료 위치에서 근접 생성, 자식의 남은 수명은 부모 잔량이 아니라 새 전체 수명.
- `split + bolt` 비관통: 첫 적중에 부모가 종료하고 바로 자식 3개. `split + pierce + bolt`: 첫 적중 후 부모가 여전히 살아있다면 조기 분열 0, 소멸 후 3개.
- `split + pierce + bolt`: 분열 자식에게 부모 **초기 전체 관통** 복원. 적 둘 이상에 유효 충돌·피해 기록.
- `split + fan/echo/giant/charge/element_fire/element_ice/element_poison/element_lightning/seek/orbit/fall`: 중복 발사/원소량/정지·이동 경로/부하 검증.
- `split + laser`: 광선의 실제 끝점에서 약 0.2초 후 분열; 자식 광선 길이는 부모의 절반, 각 자식 재분열 0, 적중 연출/피해 좌표 일치.
- `split + vortex/thorn/satellite/ember_path/flamethrower`: 자식에게 실명중·원본 공격 성질·타이밍이 보존되는지 검증. 일부 타입은 분열 자식이 예산 제한으로 누락될 수 있으므로 계측.
- 비정상 취소/게임 재시작 시 **분열 0**, 이전 세대의 예약 잡 유출 0. 30/60/120Hz와 큰 프레임 간격, 화면 경계·4오브·300적 성능 분리 검사.
- 원본의 `SpellSpawnParamsStorage.ToSplit` → `SpellDestroySystem.Split` → `SpellShootSystem.SpawnSpellEntity`에 대응하는 코드/이벤트표를 비교해 생략 사항을 정리할 것.
- **이번 보고서의 정적 확인은 실제 Godot 실행 통과를 뜻하지 않음**. 엔진 구문/실피해/실제 렌더/성능은 실행한 뒤 측정값으로 기록. 테스트가 실패하면 `VERIFIED`로 올리지 않는다.

## 6. 참고 코드

- [Magicraft: 분열 역분석](https://github.com/kav1982/_reverse_engineering/blob/main/%E5%88%86%E8%A3%82%E9%80%86%E5%90%91%E5%88%86%E6%9E%90.md)
- [Magicraft: 분열 자식 속성 복제](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellSpawnParamsStorage.cs)
- [Magicraft: 소멸 시 분열](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellDestroySystem.cs)
- [Magicraft: 적중/소멸 조건](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellSystem.cs)
- [Godot: 분열 실행](https://github.com/LittleEvasn/witchlings-mayhem/blob/main/scripts/magic_extensions.gd)
- [Godot: 투사체 생성/수명](https://github.com/LittleEvasn/witchlings-mayhem/blob/main/scripts/spell_runtime.gd)

**저작권:** 원작의 알고리즘·행동 수식 참고. 비공식 역컴파일된 상용 코드 전문 또는 원본 그림을 복사·재배포하지 않았다.
