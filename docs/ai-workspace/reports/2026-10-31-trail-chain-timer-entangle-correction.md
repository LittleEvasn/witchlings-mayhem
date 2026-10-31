# MAGIC-TRIGGER-CORRECTION-2026-10-31-01 · 적용 대상 정정: 복제 궤적=연쇄식 자기 복제, 시간 트리거=휘감기식 후속 공전

- **작성/정정일:** 2026-10-31
- **상태:** **APPROVED (두 기능의 참고작과 핵심 동작 방향 사용자 재확인)** / **PROPOSED (시간 트리거 강화 수치·실행 예외와 복제 궤적 세부 수치)** / **게임 코드 미변경**
- **프로젝트:** `LittleEvasn/witchlings-mayhem`
- **조사 당시 main HEAD:** `3a9db29badce637b2493c00ba7c8f26574ecffab`
- **요청 범위:** 대화 중 혼동된 두 **서로 다른 마법**의 참고작·작동 방식을 바로잡아 보고서/결정/색인에 기록한다. 코드·에셋·테스트는 **수정하지 않는다**.
- **참조:** [이전 연쇄식 복제 궤적 보고서 — 다시 유효](2026-10-31-copy-trail-to-magicraft-chain-self-cast.md); [잘못된 '복제 궤적→휘감기' 보고서 — SUPERSEDED](2026-10-31-copy-trail-to-magicraft-entangle-self-orbit.md).

## 1. 사용자 최종 정정: 마법을 혼동하지 말 것

| 우리 게임 기능 | 현재 ID/분류 | **참고하는 마법공예 기능** | 최종 목표 |
|---|---|---|---|
| **복제 궤적** (향후 '휘감기'라고 부르는 경우도 있었으나 현재 코드의 이름은 복제 궤적) | **`trail` / 보조(modifier)** | **연쇄 / Chain / 3203 / OnMoveTrigger** | **부모 마법이 이동하는 동안 자신의 현재 위치에서 동일한 부모 마법의 복제본을 별도의 공격으로 발사.** 원작처럼 '뒤에 연결된 다른 마법'을 발사하지 않음. |
| **시간 트리거** | **`timer` / 연결(connector)** | **휘감기 / Entangle / 3204 / OnStartRotationTrigger** | **연결된 후속 마법을 부모 마법 주위에 생성해 회전시킨다.** 부모 '자기 복제'가 아니라 **뒤에 연결된 마법**이 대상. |

**혼동 방지 핵심 규칙:**
- `trail`은 **연쇄(3203) 기반**, **이동 중 자기 복제 발사**. **휘감기식 원형 자기복제/부모 주위 고정 공전**으로 만들면 잘못이다.
- `timer`는 **휘감기(3204) 기반**, **후속 주문의 공전**. **연쇄식 거리 이동 발동·자기복제 발사**로 만들면 잘못이다.
- 두 마법을 한 기능으로 통합하거나, `trail`과 `timer`의 ID를 서로 바꾸지 않는다. 현재 저장 데이터/레시피 호환을 위해 내부 ID 유지 권고.
- 마법공예 원작의 숫자·엔진 좌표·원작 클래스 구조는 참고 데이터이지 우리 게임에 확정된 수치가 아니다.

## 2. 복제 궤적 (`trail`) — 원래 출처와 재확인된 개편 방향

### 최초 차용 / 과거 구현(현재 코드 사실)

- **최초 아이디어 출처:** 《노이타(Noita)》 **Copy Trail** (`LARPA_CHAOS_2`). 이동 중 투사체의 복제본을 경로에 생성한다.
- 우리 게임 `scripts/magic_catalog.gd`의 현재 `trail`: '**복제 궤적**', 이동 거리마다 약한 잔상.
- `scripts/magic_extensions.gd`: **90 이동거리** 누적 시 구형 잔상/파생 공격 생성, `scripts/modifier_effects.gd`: **0~3강 2/3/4/5회 제한·각 20%**라는 기존 구현.
- **이것은 과거 구현 설명**이지 새 연쇄식 설계의 승인 수치가 아니다.

### 새 승인 방향 — 마법공예 연쇄를 '자기 복제'로 변형

- 마법공예 **연쇄(3203)**: 부모 마법이 **이동 중** 조건을 만족하면 **뒤에 연결된 하위 마법(B)**을 부모 위치에서 발사.
- **우리 새 `trail`**: 부모 **A가 이동하는 도중**, 부모의 현재 위치에서 **A 자신의 복제 공격체 A′**를 **실제로 추가 발사**. 별도 후속 슬롯 B가 필요하지 않음.
- 부모의 단순 잔상 궤적/정지 장식이 아니라 실제 새 공격체의 시전·비행·충돌·피해가 있어야 한다.
- 사용자 이전 명시: **기존 90 이동거리마다 생성 방식은 폐기**. 원작 연쇄의 '이동 기반 트리거'라는 구조를 참고하되 이 게임에 없는 마나·하위 그룹 비용을 무리하게 가정하지 않는다.
- **복제 횟수, 개별 피해, 재복제 허용 규칙**은 여전히 **미확정**. 구형 `[2,3,4,5]`, `20%`, `90px`를 검토 없이 그대로 '새 확정 수치'라고 적지 않는다.
- 원작 측면 방향(±90° 교대)은 참고 구현의 우선 검토 대상으로 둘 수 있으나 **우리 게임에 별도 확정한 것은 아니다**.

관련 원작: [SpellMoveTriggerSystem.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellMoveTriggerSystem.cs), [ShootSpellUtils.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/ShootSpellUtils.cs). 원문 복사/리소스 반입하지 않음.

## 3. 시간 트리거 (`timer`) — 휘감기를 참고할 대상

### 현재 기능(코드 현황)

- `scripts/magic_catalog.gd`: '**시간 트리거**' 설명은 '**생성 0.6초 후 후속 주문 한 번. 그 전에 소멸하면 취소**'.
- `scripts/magic_extensions.gd`: `timer` 연결+유효한 후속 마법을 가진 공격체에 `_timer_left` 설정; 현재 강화 0~3에서 **0.6/0.55/0.5/0.45초**로 줄어듦. `update_timers()` 경로에서 만료 시 `runtime.trigger(source,pos,"timer")` 실행.
- 위 시간 지연 방식을 **휘감기식 회전 후속 발사로 교체해야 한다는 사용자 방향**이 확정됐다. 특정 지연 시간이 새 기능에서도 유지된다고 자동 가정하지 않는다.

### 참고할 원작: 휘감기(Entangle 3204)

- 원작 `SpellTwineTriggerSystem`은 부모 생성 시 **SubGroup(뒤에 연결된 하위 주문)**을 `Count`개 생성하고, **360°/Count**로 나뉜 회전 시작각을 주어 **부모 주변을 회전**시키는 구조.
- 원작 `ShootSpellUtils.cs`는 `OnStartRotationTrigger` 구성에서 하위 주문 개수 `int2` 합산, 회전 반경 `float1` 최댓값을 사용.
- 원작 기본 세 레벨은 **3/5/8개**이나 **우리 게임에 그대로 승인된 숫자는 아님**.
- **우리 `timer` 변경 방향**은 **부모 마법 A → 시간 트리거 → 뒤의 마법 B** 조합에서 **B가 부모 주변을 회전하도록 후속 생성**하는 것. **B 대신 A 자기복제**는 `trail`과 혼동한 잘못된 구현이므로 금지.
- 휘감기의 정확한 생성 시점(즉시 회전 시작 vs 기존 딜레이 일부 존치), 수량 강화 **0~+3 매핑**, 반경·회전 속도·피해율·수명·중복/다단 연결·부모 소멸 뒤 동작은 **추후 상세 설계/검증 항목**.
- **이전 대화에서 나온 2/3/4/5는 잘못된 대상('복제 궤적→휘감기')에 붙여 기록된 값**이다. 사용자가 그 적용 대상을 정정했으므로, 이 숫자를 `trail`의 새 연쇄식 횟수나 `timer`의 휘감기식 수량으로 **자동 확정·이전하지 않는다**. 기획 시 명시적으로 별도 확인/제안이 필요하다.

원작 근거: [SpellTwineTriggerSystem.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellTwineTriggerSystem.cs), [SpellTwineTriggerComponentData.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellTwineTriggerComponentData.cs), [ShootSpellUtils.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/ShootSpellUtils.cs).

## 4. 코드 담당 체크리스트(구현 **미착수**, 적용 범위만 표기)

1. `scripts/magic_catalog.gd`: `trail`에는 연쇄 기반 자기복제 발사를, `timer`에는 휘감기 기반 후속 주문 공전을 설명. 잘못된 구안의 휘감기식 `trail` 텍스트/기능을 반영하지 않는다.
2. `scripts/magic_extensions.gd`: `trail`의 90거리 잔상 로직과 `timer`의 타임아웃 후 1회 후속 발사 로직을 각각 **독립된 새 기능**으로 재검토한다. 공전 시간·사망·충돌·부모 이동 따라가기 및 범위 체크 필요.
3. `scripts/spell_runtime.gd`·`scripts/spells.gd`: `trail`은 **자체 복제, 뒤 주문 불필요**; `timer`는 **뒤 주문 필수, 부모/후속 오브 위치와 공격 성질 분리**라는 계약을 유지한다.
4. `scripts/modifier_effects.gd`: 이전 `trail`의 2/3/4/5 최대 복제 제한을 신규 연쇄 규칙으로 자동 이식하지 않는다.
5. 합성 `mirror_trail`, `orbit_afterimage` (trail 기반), `timed_thorn`, `clock_satellite` (timer 기반)를 두 참고 마법의 변경과 별개로 회귀/재설계 검토.
6. 새 검증은 `trail+별빛탄`에서 **실제 이동 중 자체 복제체 A′의 별도 타격**, `별빛탄 A→timer→별빛탄 B`에서 **B가 부모 주변을 회전하며 독립 타격**을 확인. 4오브, 분열·메아리·공전, 원소·레이저·부메랑·장판, 생성 상한/비정상 종료·메모리 정리, 전투 종료 후 잔여 마법 유무 포함.
7. `timer`에 `trail`처럼 재귀 복제 방지 규칙을 그대로 대입하지 않고 연결형 후속 발사/분리된 생성 권한과 정상적인 중첩 연결 정책을 검토한다.

## 5. 문서 상태와 검증 수준

| 자료 | 최신 상태 / 해석 |
|---|---|
| `MAGIC-CHAIN-2026-10-31-01` (복제 궤적→연쇄식 자기복제) | **APPROVED: 유효**. 새 수치·예외 미확정, **코드 미구현** |
| `MAGIC-ENTANGLE-2026-10-31-01` (복제 궤적→휘감기식 자기복제) | **SUPERSEDED: 사용자 지칭 오류로 작성한 잘못된 대상의 구안**. 구현 금지 |
| `DEC-2026-10-31-02` (잘못된 `trail` 휘감기 자체 공전 결정문) | **SUPERSEDED**. 역사 기록만 보존 |
| 이 정정 보고서 `MAGIC-TRIGGER-CORRECTION-2026-10-31-01` | **APPROVED: `trail`→연쇄(자체 복제), `timer`→휘감기(후속 주문 공전)**, 새 수치·예외 미확정 |

**검증 수준:** GitHub의 사용자 보고서/의사결정, 현재 Godot 코드 `scripts/magic_catalog.gd`, `scripts/magic_extensions.gd`, `scripts/spell_runtime.gd` 열람 및 원작 공개 역컴파일 동작 코드 확인. 이번 정정에 따라 **신규 코드 작성 없음**, **Godot 실행 없음**, **전투 실측 없음**, **화면 확인 없음**, **체감 검증 없음**.

**최종 지침:** **`trail` = 연쇄 참고 / 자기 마법의 이동 중 복제 발사. `timer` = 휘감기 참고 / 뒤에 연결된 마법이 부모 주위를 회전.** 두 기능을 서로 바꾸지 않는다. 사용자 별도 구현 요청 전까지는 보고서/결정/INDEX만 변경한다.
