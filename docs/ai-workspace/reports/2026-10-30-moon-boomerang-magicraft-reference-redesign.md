# MAGIC-BOOMERANG-2026-10-30-01 · 달빛 부메랑을 마법공예 회선검형으로 개편 — 기본 내장 도탄 삭제

> **상태: APPROVED (사용자 설계 방향 확정) / IN_PROGRESS 아님 / 게임 코드 미변경 / Godot·웹 실행 테스트 미실시.** 정확한 속도·관통·재타격 쿨다운·강화 수치는 여전히 미확정. 사용자 확정 결정: [DEC-2026-10-30-04](../decisions/2026-10-30-boomerang-magicraft-reference-no-innate-bounce.md).

- 작성: 2026-10-30
- 프로젝트: LittleEvasn/witchlings-mayhem
- **사용자 지시:** “일단 마법공예를 따라가 / 내가 원했던거니까 일단 도탄도 삭제해 / 라고 보고서에 올려둬”
- 코드 확인: 2026-10-30의 `main`, `spell_runtime.gd`, `spell_progression.gd`, `magic_catalog.gd`.
- 비교 상대: Magicraft / 마법공예의 **회선검(回旋之刃, Boomerang Blade, abilityType 1022, ID 10221~10223)**. 아래의 원작 소스는 비공식 역컴파일 자료이므로 실제 원작 게임의 모든 버전과 일치한다고 단정하지 않는다.

## 1. 수정 목표 — 승인됨

**달빛 부메랑은 마법공예 회선검 같은 자연스러운 왕복 관통 무기로 변경한다.** 처음에는 발사 방향의 관성으로 앞으로 나아가다가 이동 중 계속 시전자 방향으로 선회하여, 큰 호를 그리면서 돌아온다. 적 명중이 기본 귀환 트리거가 아니라 **물리적으로 지나가는 경로 자체가 공격 범위**다.

**달빛 부메랑 자체의 도탄을 완전히 제거한다.** 적에게 맞히면 다른 적을 선택해 새 호형 도탄 레그로 날아가는 기능, 강화 1~3의 '기본 도탄 +1/+2/+3회' 기능은 본체에서 폐기한다. 기본 공격에서 타깃 자동 도탄을 기대하거나 설명하면 안 된다.

회선검형의 **관통** 및 출발·귀환 양방향에서의 적 타격을 기본 컨셉으로 유지하되, 동일 적의 재타격에 대한 과도한 중복 방지 시간·관통 수는 실제 밸런스 테스트에서 확정한다.

## 2. 현재 달빛 부메랑과 원작 코드의 차이

| 항목 | 현재 우리 Godot | 마법공예 원작 역컴파일 확인 | 변경 목표 |
|---|---|---|---|
| 기본 궤도 | `moon_leg()`: 시작점·종점·제어점을 지정하고 베지어 곡선 따라 이동 | `SpellMoveJob.Boomerang_Common()`: 각 프레임 현재 방향을 시전자 방향에 LERP, `extraLerpSpeed` 누적 | **관성+연속 방향 보정 회선** |
| 출발 | 최초 가까운 적을 잡거나 정면 약 300 이동 지점을 지정 | 초기 방향으로 투척. 기본형의 귀환 보정이 항상 이동 중 작동 | 적이 없어도 부드러운 회선 가능 |
| 귀환 | `turn_back()`: `returning=true`, 새 레그 설정, 속도 변경 | 시간 경과에 따라 시전자 위치를 향한 보정이 증가 | 별도의 순간 전환 느낌 없이 돌아오도록 |
| 기본 명중 | `moon_contact()`: 도탄이 없으면 즉시 `turn_back()` | 원작 설정 데이터 ID 10221은 `int1=5` 관통, `speed=26`, `duration=5` | **명중 시 즉시 귀환 폐기, 관통형 무기** |
| 내장 도탄 | `ricochets`, `nearest_enemy(...300...)` 새 목표, `moon_leg()` 재계산 | 원작 회선검 기본의 핵심 로직은 도탄이 아닌 회선+관통 | **본체 내장 도탄 제거** |
| 강화 | `spell_progression.gd`: `ricochets=r` (0~3); 합성 부메랑 `ricochets=3` | 원작 설정 `int1`: 5/8/12 단계, 단위 직접 비교 금지 | 강화 목적을 회선/관통/왕복 범위 위주로 재설계 |
| 동일 적 재타격 | `p.hit`가 외향·귀환 동안 유지되어 동일 적 재타격 금지 | 원작 MonoBehaviour `CheckHitBoxState()`는 히트박스를 주기적으로 재활성화; 최신 ECS에서 정확한 동일 적 재타격 간격은 추가 검증 필요 | 왕복 재타격 허용, **최소 재타격 간격 추가 검토** |
| 회수 | 돌아올 때 플레이어 거리 24 이내에 제거 | 원작 ECS `Spell1022Job`: 처음 0.5초 회수 무시, 소유자 접촉 시 회수 | 자신에게 돌아와 종료, 즉시 오회수 방지 |
| 시각 | `magic_visuals.gd`: 달 이미지 회전·짧은 뒤꼬리 | `Spell1022Effect.cs`: 회전·트레일·그림자 분리 | 게임 스타일에 맞는 회전·잔상 독립 구현 |

**중요:** 원작 `SpellConfig.json`의 `speed=26` 및 우리 `PROFILE.speed=460`은 서로 다른 엔진·단위다. 숫자를 대입해 같다고 주장하거나 직접 복제하지 않는다.

## 3. 실제 구현 시 변경해야 할 코드 (미구현)

1. **`scripts/spell_runtime.gd`:** 부메랑 발사 단계의 `ricochets`, `outbound_limit` 설정, `moon_leg()`·`turn_back()`·`moon_contact()` 중심 상태와 `update_projectiles()`의 부메랑 이동을 회선형 방향 보정으로 변경. 기존 다른 공격/일반 보조의 도탄 로직은 유지한다.
2. **`scripts/spell_progression.gd`:** 기본 달빛 부메랑 강화 단계별 `ricochets=r` 및 합성 `ricochets=3` 처리와 '추가 도탄 후 귀환' 설명을 제거/재설계. 정확한 대체 강화 수치와 설명은 별도 밸런스 확정 전까지 임의 도입 금지.
3. **`scripts/magic_catalog.gd`:** 달빛 부메랑 설명을 관통·왕복 중심으로 갱신. `twin_moons`(쌍월륜, `boomerang + bounce`), `echo_return`(잔향 귀환)과 도탄 이벤트를 기대하는 종속 항목 호환성 재검토.
4. **`scripts/magic_visuals.gd`:** 실제 이동 방향에 맞는 회전·잔영 방향·시각적 구별 확인.
5. **`scripts/magic_extensions.gd` 및 합성 관련 코드:** 별도 보조 `bounce`, `pierce`, `seek`, `orbit`, `fan`, `echo`와 결합 시 기본 동작·경고 UI 및 파생탄/트리거를 확인.

## 4. 범위 명확화

- **제거 확정:** 달빛 부메랑 **본체에 내장된 자동 도탄** + 이를 기반으로 한 **기본 강화별 추가 도탄 횟수**.
- **삭제 지시 아님:** 모든 마법에 쓰는 독립 보조 `bounce`(도탄), 합성 보조 `devour_bounce`(포식 도탄), 다른 공격의 도탄.
- **검토 필요:** 달빛 부메랑에 **별도 도탄 보조**를 붙였을 때에는 도탄이 가능하도록 할지, 왕복 회선 특성을 우선할지. 원래 `twin_moons`가 `boomerang + bounce` 합성이라는 구조가 깨지지 않게 따로 결정해야 한다. **임의 삭제·대체 금지.**
- **미확정:** 원작과 동일한 정확한 수식, 관통 허용 대상 수, 적별 재타격 제한, 왕복 피해 계수, 범위·생존시간·발사 빈도, 강화 수치와 쌍월륜 조합.
- 현재 대화의 요청은 **보고서 등록**이며 **실제 Godot 게임 수정·웹 반영을 요청한 것은 아니다**.

## 5. 구현 후 수용 테스트 (향후)

| 시나리오 | 필수 확인 |
|---|---|
| 적이 없는 공간에 발사 | 큰 호를 그리며 자연스럽게 돌아옴; 목표점마다 궤적이 꺾이는 느낌 없음 |
| 경로에 적 여러 마리 | **명중 후에도 즉시 귀환하거나 도탄하지 않고 관통 이동** |
| 한 마리만 있는 표적 | 외향·귀환에 재타격 가능, 무한 다단히트는 제한 |
| 플레이어 이동 중 | 고정된 과거 좌표가 아닌 **현재 시전자 위치**를 향해 귀환 |
| 강화 0~3 | 강화 단계만으로 **자동 도탄 없음**, 대체 성장 수치 및 설명 일치 |
| 도탄 보조·쌍월륜 | 기본 부메랑 도탄 삭제 때문에 발생하는 충돌·비활성·강제 귀환·연결 부작용 별도 확인 |
| 갈래·추적·공전·메아리·관통 등 | 실제 궤도·발사 개수·개별 충돌·시계/쿨타임/후속 트리거와 호환 |
| Godot headless / 웹 실험실 | 궤적 샘플링, 충돌/재타격 이벤트, 발사량·성능·화면 확인. 빌드 성공만으로 최종 검증 완료 판정 금지 |

## 6. 출처: 공개 역컴파일 (공식 원본 아님)

- [Magicraft: `SpellMoveJob.cs`](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellMoveJob.cs) — `Boomerang_Common`, `Boomerang_Rotation`, `Boomerang_ChaseTarget`.
- [Magicraft: `Spell1022Job.cs`](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1022Job.cs) — 회수·거리 종료 처리.
- [Magicraft: `Spell1022Boomerang.cs`](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1022Boomerang.cs) — 이전 구현의 연속 보정·히트박스 재활성화.
- [Magicraft: `SpellConfig.json`](https://github.com/kav1982/_reverse_engineering/blob/main/assets_export/SpellConfig.json) — ID 10221~10223.
- [Magicraft: `TextConfig_Spell.json`](https://github.com/kav1982/_reverse_engineering/blob/main/assets_export/TextConfig_Spell.json) — '회선검' 명칭·설명.
- 우리 코드: [`spell_runtime.gd`](../../../scripts/spell_runtime.gd), [`spell_progression.gd`](../../../scripts/spell_progression.gd), [`magic_catalog.gd`](../../../scripts/magic_catalog.gd).

**검증 수준:** 현재 양쪽 소스 열람/동작 대조 완료; 원작 게임 화면 직접 계측 및 Godot에서 변경안 테스트 **아직 미실행**. 저작권 있는 역컴파일 코드를 프로젝트에 그대로 복사하지 않는다.
