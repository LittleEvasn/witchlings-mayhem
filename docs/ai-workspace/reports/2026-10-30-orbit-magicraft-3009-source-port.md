# MAGIC-ORBIT-2026-10-30-01 · 공전(orbit)을 마법공예 공전 3009 방식으로 통일

> **상태: APPROVED — 원작식 공전 동작·코드 계약 사용자 확정 / 실제 Godot 구현·테스트 미수행.**
>
> **사용자 결정:** 두 게임의 공전 차이를 실제 코드로 비교한 뒤 “그럼 마법공예쪽으로 코드 통일하도록 보고서 올려”. 따라서 **기존 고정 각속도·반경 누적 방식이 아니라 원작의 속도 기반 원운동과 공전 수명·반경·기준점·우선순위 로직으로 교체**하는 것이 이 작업의 핵심. 이번 요청은 **보고서 등록만**, 게임 코드·아트·빌드 변경은 하지 않음.
>
> **중요:** 여기서 “공전”은 우리 보조 `orbit` ≈ Magicraft `AroundOwner(3009)`다. 기본 공격 `satellite`(달무리 위성)과 합성 `orbit_vortex`의 고유 동작을 동일 주문으로 오해하거나 폐기하면 안 된다.

- 작성일: 2026-10-30
- 프로젝트: `LittleEvasn/witchlings-mayhem`
- 우리 코드 열람 기준: `main@b7e1bf6d4883e85a7a04d7c67921a734313b00dc` (원격 HEAD 조회 시점)
- 원작 참조: 비공식 공개 역컴파일 `kav1982/_reverse_engineering`, `Magicraft / 마법공예`, 공전 `AroundOwner` ID `3009` (설정 `30091~30093`). 공식 소스·실게임 최신 버전과 일치함은 별도 검증되지 않음.
- 근거 수준: 양쪽 저장소 소스/수치표 직접 열람 및 우리 기존 Magic60 실측 보고서 열람. 이번 요청에서 새 Godot 실행, 화면 육안·게임 체감·성능 측정 **0회**.
- 관련 사용자 결정: [DEC-2026-10-30-09](../decisions/2026-10-30-orbit-magicraft-3009-motion-contract.md)
- 관련 기존 결함: [MAGIC60-FIX-AND-TEST-REPORT](../../MAGIC60-FIX-AND-TEST-REPORT.md), 공전+잔불 발자국 P0. 기존 [MAGICRAFT-CORE-SOURCE-REVIEW-v3](../../MAGICRAFT-CORE-SOURCE-REVIEW-v3.md)의 원작/우리 규칙 차이를 함께 준수.

## 1. 사용자 기대 행동 → 구현 계약 → 완료 기준

1. 서로 다른 속도의 탄에 공전을 붙이면 각각 **자신의 이동 속도에 비례**해 돌 것. 고정 2.5rad/s 일괄 공전은 폐기.
2. 공전 시 투사체가 시전자의 주변/지정 기준점에서 **반경을 유지**하며 회전하고, 시전자가 이동해도 원형 궤도 중심을 따라올 것.
3. 강화로 원작처럼 **공전 추가 지속시간·추가 이동 속도·반경**을 가진다. 반경만 늘고 생존 시간이 그대로인 현행 방식은 폐기.
4. 공전 중복 적용 시 원작 `GetSpellRotationInfo`처럼 **속도·지속시간은 더하고 반경은 뒤쪽 유효 공전의 값으로 덮는다**. 무조건 90+90=180px 누적 금지.
5. 투사체마다 공전 **초기 각도**가 설정되어야 한다. 원작 일반 경로는 0~360° 난수이며 산탄 전용 균등 배치 경로가 존재한다. 우리 구현은 고정 0°로 일괄 겹쳐 시작하면 불합격.
6. 공전 VFX 표시 좌표와 실제 충돌/피해/장판 경로가 일치해야 한다. 최초 중심→원둘레 텔레포트 선분에 **허위 타격**이 생기면 안 된다.
7. 공전으로 기본 공격의 실제 명중·관통·종료·연결을 잃거나, 공전이 단순히 색다른 원운동 장식으로 끝나면 불합격. 공전 때문에 발생하는 판정 변화는 원작 기준으로 분석해 반영하되 우리 **명중 연결 1회/정상 종료 1회/강제 정리 무발동** 등의 확정 계약을 몰래 변경하지 않는다.

## 2. 실제 원작(Magicraft) 코드 근거 — 확정/주의 분리

| 원본 | 소스에서 확인한 동작 |
|---|---|
| `SpellShootDataExtend.GetSpellMovementType` | 강화 목록을 **오른쪽부터 왼쪽으로** 훑고 최초 만나는 이동 보조로 이동 타입 결정. 공전 `AroundOwner` → `Rotation`. 추적/자동항법이 뒤에 있으면 공전이 이동 타입을 이기지 못할 수 있음. |
| `SpellShootData.GetSpellRotationInfo` | 활성 강화들을 훑어 `AroundOwner`의 `float2`를 **extraSpeed 합산**, `float1`을 **extraDuration 합산**, `float3`을 **rotationRadius 대입(마지막 값)**. `RandomRotationRadiu`는 별도 기능/분기. |
| `ShootSpellUtils.SipToSSP` | `Rotation`인 경우에만 공전 extraSpeed를 탄 속성의 `AddBase`에 더하고 extraDuration을 생존시간의 `Extra`로 부여. `AroundTarget`은 플레이어의 공전 중심 엔티티 또는 발사체 소유자 등 상황별 설정. 시작 각도 기본 `Random.Range(0,360)`. |
| `SpellMoveJob.Normal_Rotation` | 각도 변화량 `360/(2π × radius / speed) × delta`(°) ≡ `delta × speed/radius`(rad). 새 위치 `center + direction(angle) × radius`, 진행 방향은 원 접선(각도+90°), 물리 선속도는 0으로 갱신. |
| `SpellMovementComponentData.UpdateAroundFollowAndGetAroundPositionWhenAround` | 추적 대상 트랜스폼이 있으면 그 위치를 중심으로 업데이트하고, 없으면 보관한 `AroundCenter` 사용. |
| `SpellSystem.Execute` | 피해는 진입 이벤트를 사용하고 기본적인 비관통 탄은 적/충돌에 소멸할 수 있음. **공전이 무적·무한관통·자동반복타격을 부여하는 것은 아님**. |

원작 공전 ID별 정확한 설정값(원작 단위):

| 원작 레벨 | `extraDuration` (`float1`) | `extraSpeed` (`float2`) | `rotationRadius` (`float3`) |
|---|---:|---:|---:|
| Lv1 / 30091 | +4초 | +0 | 3 |
| Lv2 / 30092 | +7초 | +5 | 4 |
| Lv3 / 30093 | +11초 | +10 | 5 |

- **회전 속도는 각도가 아니라 선속도÷반경**으로 결정된다. 따라서 원래 속도가 0이고 공전 추가 속도도 0이면 원주 위치에 정지해 시전자를 따라오는 형태가 가능하다.
- **원작은 3레벨**, 우리 게임은 **0~3강의 4단계**. 원작에 “Lv4”가 있다고 작성하면 오류. 원작 게임 단위 `3/4/5`를 우리 px `3/4/5`로 그대로 붙여도 안 됨.
- 공전이 주는 추가 지속시간은 일반 `duration` 증강과 다른 `Extra` 계층이다. 공전이 최종 이동 타입이 아니면 이 보너스가 무조건 생기는 것이 아님.
- 일반적 투사체와 광선·시전 유지·낙하·특수 공격은 원작에서 각각 별도 예외 경로가 존재한다. `Rotation` 하나로 바꾸면 60종 모두가 자동으로 원작처럼 움직인다고 주장하지 않는다.
- 원작 코드는 **참조 알고리즘·수식·상태 전이**의 근거. 상업 게임 역컴파일 C# 코드 전문/추출 아트를 권리 확인 없이 프로젝트에 복사·재배포하지 않는다. Godot 쪽에서 독립 구현으로 동작을 대응 포팅한다.

## 3. 현재 우리 Godot 구현에서 바꿔야 하는 구체 사항

| 코드 경로 | 현 상태(직접 열람) | 변경 필수 |
|---|---|---|
| `scripts/magic_catalog.gd` `orbit` | 보조 공전 설명만 존재 | 실제 강화 효과/우선순위/지속시간에 맞춰 툴팁 수정; 내부 ID `orbit` 보존 |
| `scripts/magic_extensions.gd` `motion()` | 보조 배열에서 마지막 `seek`/`orbit` 결정 | **원작 오른쪽 우선**을 명시적 이동 계약으로 통일. 낙하의 수직축은 별도 처리. 합성형 `orbit_afterimage`가 차지하는 우선순위 회귀 |
| 같은 파일 `attach()/move()` | `_motion_age*2.5` 고정, `radius=rank_value("orbit")`, 각도0 기본, 움직임마다 `speed=max(speed,150)` | `effective_linear_speed`·`radius`·`angle`·`orbit_center`를 인스턴스에 저장. `angle += dt * speed/radius`, 위치를 원둘레로 갱신, 방향 접선 설정. 150 속도 강제값 제거(정지형 예외 지원), 충돌 샘플 좌표 보정 |
| `scripts/modifier_effects.gd` | 공전 0~3강 반경 `90/110/130/150px`, 여러 장 수치 **합산**, 시간/속도 없음 | 원작의 개별 `radius` 마지막 값, `speed_bonus` 합산, `duration_bonus` 합산으로 변경. `profile` 결과 구조 확장 |
| `scripts/spell_runtime.gd` `emit()/update_projectiles()` | 기존 `spec.speed`·`spec.life` 그대로; 원래 발사 위치에서 속도 이동 후 `extensions.move`에서 공전 좌표로 이동; 이전 위치→공전 위치를 한 선분으로 충돌 검사 | 생성 시 공전 위치로 **초기화**, 첫 프레임 튀는 선분 제거, 이후 원호를 따라가는 실제 구간 충돌 처리. 원래 `spec` 속도와 새 공전 추가 속도를 함께 사용, 수명 보너스 적용 |
| `scripts/spell_behaviors.gd` `special()/update_orbits()` | 별도 기본 공격 `satellite`는 기존 자체 회전(`age*TAU`)/타격 주기를 사용 | **달무리 위성은 독립 기본 공격**. 보조 `orbit`의 이동 계약을 적용하는 부분만 엄격히 구분; 기본 공격을 같은 탄으로 취급해 지워서는 안 됨 |
| `scripts/magic_visuals.gd` / 설치형 경로 | 표시 경로와 실충돌이 달라질 수 있음 | 공전 중심, 투사체 위치, 회전/후광/잔상, 장판 `path_points`가 같은 좌표를 바라보게 연결 |
| `tests/magic60_audit`, `docs/verification/magic60-20261030` | 공전+잔불 표시/피해 좌표 불일치 재현 자료 존재 | 이전 P0 재현 케이스를 수정 전 보존하고 수정 후 60Hz/120Hz 재실행. 새 원작식 속도/수명/반경·충돌 회귀 추가 |

### 3.1 제안 런타임 계약(원작 수식의 GDScript 대응 — 아직 코드 아님)

```text
[컴파일/시전 초기]
movement_kind = rightmost(seek|orbit|other planar movement)
if movement_kind == orbit:
    radius = last_orbit_card.radius * UNIT_SCALE
    extra_speed = sum(orbit_cards.extraSpeed) * UNIT_SCALE
    extra_duration = sum(orbit_cards.extraDuration)
    effective_speed = apply_existing_speed_modifiers(base_spell_speed + extra_speed)
    life = apply_existing_lifetime_modifiers(base_spell_life) + extra_duration
    center = resolve_owner_or_explicit_anchor(spell_instance)
    angle = seeded_random_angle()            # or source-verified multi-shot arrangement
    pos = center + from_angle(angle) * radius
    previous_collision_pos = pos              # avoid center→orbit teleport hit

[매 프레임]
if movement_kind == orbit:
    center = resolve_updated_center(spell_instance)
    angle += delta * effective_speed / max(radius, EPSILON)
    old_pos = previous_collision_pos
    pos = center + from_angle(angle) * radius
    dir = from_angle(angle + PI/2)
    collide_on_orbit_path(old_pos, pos)        # subdivide long arcs / consider moving center
    previous_collision_pos = pos
```

**충돌 주의:** 반경이 크거나 이동속도·`delta`가 커지면 두 좌표 사이 직선(현 `old→pos` 단일 `segment`)은 원호 안쪽을 가로지른다. 최대 각도/세그먼트 길이로 원호를 적응 분할하거나 Godot의 대응 스윕으로 검사한다. 시전자가 급격히 이동해 중심이 바뀌는 경우, 중심 이동선과 공전 이동선을 함께 샘플링하고 0.2초 프레임에도 누락·허위타격을 막는다. **원작의 수식은 확인되지만 이 세그먼트 세분화는 Godot 이식에 필요한 구현 선택**이며 원작 코드 그대로라고 주장하지 않는다.

### 3.2 우리 강화 0~3강에 적용할 수치 — 출처와 제안을 분리

**사용자가 확정한 것은 ‘원작 코드 방식으로 통일’이며, 원작에 없는 4번째 강화 수치 자체는 미확정이다.** 구현 시 아래처럼 원작 값을 기준으로 수치 테이블을 분리한다.

| 우리 강화 | 원작 대응 | 반경(원작 단위) | 속도 추가(원작 단위/초) | 시간 추가 |
|---|---|---:|---:|---:|
| 0강 | 원작 Lv1 | 3 | +0 | +4초 |
| 1강 | 원작 Lv2 | 4 | +5 | +7초 |
| 2강 | 원작 Lv3 | 5 | +10 | +11초 |
| 3강 | **원작 없음 — 임시 확장 제안** | **6** | **+15** | **+16초** |

- `UNIT_SCALE` **임시 환산 후보 30px/원작 거리 단위**라면 반경은 `90/120/150/180px`, 속도 추가는 `0/150/300/450px/s`다. 이는 우리 `bolt`의 기본 `440px/s`, 공전 기존 반경 `90px` 등을 이용한 **설계용 근사값**이며 원작 수치 1:1 확인값이 아님. 픽셀/메타/카메라 비율을 Godot에서 측정해 고정한다.
- +4/+7/+11초를 전부 적용하면 기존 2.6초탄의 생존이 장시간 늘어난다. 탄 밀도·관통·이벤트 수/성능과 치명적 상호작용 가능성 검사 필수. 보존/조정 시에는 **원작과 다른 수치**임을 명시.
- 다른 강화(가속·감속·지속·거대화)가 있다면 원작 속성 계층을 참조해 합산/곱산 순서를 일관되게 적용. `radius` 합산·고정 각속도는 다시 도입하지 않는다.
- 원작에 없는 3강 숫자·픽셀 환산·메모리/CPU 제한 정책을 **“마법공예 원본 공식 값”이라고 표기 금지**. 별도 밸런스 검증의 대상이며 확정되지 않았다.

## 4. 우선순위·타 마법 상호작용: 게임의 확정 계약 보존

1. **공전 × 추적:** 원작은 오른쪽부터 검색해 결정된 이동 타입 하나를 사용한다. `orbit`과 `seek` 두 운동을 단순 합산해 가상의 ‘추적 원궤도’로 만들지 않는다. 패배한 공전 효과의 시간/속도도 원작처럼 `Rotation` 조건일 때만 실제 적용. 게임 내 노랑 상쇄/빨강 비작동 표시 규칙 유지.
2. **공전 × 낙하:** 원작은 공전의 **XY 궤도**와 낙하의 **Z/높이 이벤트**를 병렬로 다룰 수 있다. 우리 현재 `fall`은 예고→착지점 생성 구조이므로 별도 승인된 낙하 보고서를 우선하고, 공전만 바꾸면서 낙하를 착지 후 회전만 하는 단순 구현으로 몰래 축소하지 않는다. 이 조합은 **원작식 병렬 움직임 계약을 검토해야 할 미완료 항목**으로 남긴다.
3. **공전 × 광선:** 원작 기본 광선 1004는 공전일 때 **360° 원형 폴리라인(36세그먼트)** 방식이다. 우리 광선의 현재 즉발 판정이 회전 발사점에서 한 줄씩 반복 발사되는 식으로 조용히 변경되지 않게 전용 구현/회귀. 기존 [광선 개편 보고서](2026-10-30-laser-magicraft-1004-implementation.md)와 함께 읽기.
4. **공전 × 빛나는 별의 화살 / 충전:** 원작 `SpellChargeSystem`은 차지 시계를 증가시키며 `SpellChargeEndSystem`이 원작 `ShiningStar`+`Rotation`+충전별 출처의 종료 이후 공전 중심을 재바인딩한다. `Spell1026ShiningStarChargingSystem.CreateShootEffect`에서 `Rotation`일 때 일부 발사 VFX는 생략되지만 충전 계산 제거는 아님. **우리 현재 `charge`는 단발 피해 배율 보조이지 원작의 수동 차지 스킬과 같은 기능이 아님**. 조합별 표시·결과 구분.
5. **공전 × 달무리 위성:** 기본 공격 `satellite`의 원래 다중 위성/대상 접촉 쿨다운을 유지한 채 `orbit` 보조의 이동 계약과 분리. 기본 위성 공전의 속도·피해를 무작정 3009로 덮어쓰지 않는다.
6. **공전 × 소용돌이·가시꽃·잔불·화염구·분열·복제·소멸 후:** 설치형/광역형은 공전 **표시·피격 중심·장판 중심**의 일치를 검사. 자식·연결의 위치/세대/횟수/소유권은 우리 게임의 확정 범위 제한을 유지하되 원작과의 차이는 문서화.
7. **관통/재접촉:** 원작은 단순 `Enter` 타격이고 기본 비관통 투사체는 소멸 가능. 우리 `p.hit` 영구 방문 기록·연결 1회 규칙은 별도 계약. 재접촉 피해 정책을 바꿔 원작과 완전히 같아졌다고 주장하지 말고, 손실 없는 일반탄·관통탄·여러 바퀴 재진입을 구분해 검증한다. **피해 재접촉과 후속 연결 반복은 서로 다른 문제**.
8. **경계/벽:** 원작 `SpellShootSystem` `Rotation`은 벽 충돌 마스크를 조정한다. 우리에게 원작과 똑같은 벽 시스템이 존재한다고 가정하지 말 것. 맵 경계에서 무효화/정지/탈출 처리를 실제 Godot 물리·좌표계에 맞춰 테스트.

## 5. 구현 작업 순서(다음 Codex 수정 요청에서만 수행)

1. 기존 이동 타입, 보조 값 저장 계약을 동작 단위로 확정하고 원본 핵심 `GetSpellRotationInfo` → `SipToSSP` → `Normal_Rotation` → 종료 경로까지 함수 대응표 작성.
2. `modifier_effects`와 `magic_extensions`에 **반경 최종값 / 속도·수명 합산 / 이동 우선순위 / 소유자 중심 / 개별 시작각도**를 도입.
3. **대표 탄 `bolt + orbit`**에서 프레임별 (center, angle, radius, position, speed, life) 계측. 시전 즉시/이동 중/만료까지 실제 렌더와 판정 비교.
4. `spell_runtime`의 충돌 시작 위치와 프레임별 원호 스윕·적중 소멸/관통 규칙을 연결. 가짜 중심→원주 선분 검사 제거.
5. 기존 `orbit + ember_path` P0 재현을 먼저 해결하고, 소용돌이/화염구/분열/후속/레이저/낙하/위성 등 **구조가 다른 대표 유형**으로 확대.
6. UI·툴팁·수치/강화 설명과 Godot 0~3강 적용/중복공전/오른쪽 우선순위 테스트.
7. 4오브×다수 적 부하·프레임 지연/재시작 잔여 인스턴스/동시 발사 상한 회귀. 추정 성능을 실측 FPS로 포장하지 않는다.

## 6. 완료를 위한 재현 및 실패 기준 (미수행)

| 시나리오 | 구현 완료의 관측 가능한 성공 조건 |
|---|---|
| `bolt` 단독/`bolt+orbit` 두 속도 변형 | 기본탄과 보조 속도에 따라 각속도 비례, 프레임별 오차 허용치 기록, 유효 충돌/정상 만료 |
| 원속도 0 / 공전 Lv1 | 각속도 0, 시전자 주변 고정 각도 위치 유지, 이동 시 중심 따라 이동 |
| 공전 중복 두 장·세 장 | `extraSpeed`와 `extraDuration`은 합산, `radius`는 원작식 마지막 적용값, 동시 탄 오프셋 정상 |
| 0~3강 / 큰 지연 프레임 | 각 단계 반경/속도/수명·툴팁 일치, 30/60/120Hz 및 큰 `delta`(예 0.2s)에서 터널링/불필요한 화면 관통 없음 |
| 적 진입/공전 재진입/첫 타격 | 첫 프레임 원점→원둘레 허위 명중 0, 실제 궤도 경로에서 명중, 기본 비관통 소멸, 관통탄 다중 대상·재접촉 규칙 구분 |
| `orbit + ember_path` (기존 P0) | 반경 90~150px 분리된 표시/실충돌 오류가 해소됨. 공전 따라가는 장판이 **실제 표시 지점의 적에게 피해**를 줌; 60/120Hz 이전 재현과 신규 강화 모두 확인 |
| 공전+추적/낙하/레이저 | 이동 우선순위/별도 낙하축/광선 전용 원형 판정이 각각 의도대로 작동, 없는 기능을 ‘통과’로 처리하지 않음 |
| 공전+충전/분열/메아리/연결/합성/위성 | 충전 효과·후속 소유권/횟수·기본 위성 특성 보존, 같은 이벤트에 중복 생성·무한 재귀 없음 |
| 화면 밖/경계/시전 취소/재시작/고부하 | 좌표·정리·상한 정상, 잔여 예약/유령 피해/비정상 인스턴스 증가 없음 |

**검증 결과를 분리해 기록:** ① C#/GDScript 소스 대조 및 정적 확인, ② Godot 구문/테스트, ③ 실제 생성→위치→표시→피해→종료, ④ 스크린 렌더·시각, ⑤ CPU/GPU/실제 FPS, ⑥ 게임 체감. 숫자만 맞춰 테스트를 통과시켜 **기능 체감 목표를 축소**하지 않는다.

## 7. 참조 링크 (실제 열람)

- 원작 핵심 [SpellShootData.cs — GetSpellRotationInfo](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellShootData.cs)
- 원작 [SpellShootDataExtend.cs — 오른쪽 우선 이동 보조](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellShootDataExtend.cs)
- 원작 [ShootSpellUtils.cs — 속도/지속시간/반경/중심/시작각도](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/ShootSpellUtils.cs)
- 원작 [SpellMoveJob.cs — Normal_Rotation](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellMoveJob.cs)
- 원작 [SpellMovementComponentData.cs — 공전 기준점](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellMovementComponentData.cs)
- 원작 [SpellSystem.cs — 충돌 Enter/일반탄 제거](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellSystem.cs)
- 원작 [법术数值总表.md — 30091~30093](https://github.com/kav1982/_reverse_engineering/blob/main/%E6%B3%95%E6%9C%AF%E6%95%B0%E5%80%BC%E6%80%BB%E8%A1%A8.md)
- 우리 [magic_extensions.gd](https://github.com/LittleEvasn/witchlings-mayhem/blob/main/scripts/magic_extensions.gd), [modifier_effects.gd](https://github.com/LittleEvasn/witchlings-mayhem/blob/main/scripts/modifier_effects.gd), [spell_runtime.gd](https://github.com/LittleEvasn/witchlings-mayhem/blob/main/scripts/spell_runtime.gd), [spell_behaviors.gd](https://github.com/LittleEvasn/witchlings-mayhem/blob/main/scripts/spell_behaviors.gd)
- 우리 [공전/잔불 실측 문제](../../MAGIC60-FIX-AND-TEST-REPORT.md) 및 재현 `docs/verification/magic60-20261030/magic60_orbit_ember_probe.json`

**현재 작업 상태: 보고서 등록만. 코드 변경·원작 실행·새 Godot 검증·웹/Windows 빌드 변경 없음.**
