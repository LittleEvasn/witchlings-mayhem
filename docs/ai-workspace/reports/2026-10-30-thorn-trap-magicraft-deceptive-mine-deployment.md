# MAGIC-THORN-2026-10-30-01 · 가시꽃 덫을 괴이한 지뢰처럼 굴린 뒤 원형 덫으로 전개

> **상태: APPROVED (사용자가 이름·이동 참고 모델·전개 형태 확정) / 게임 코드 미변경 / Godot·웹 실행 테스트 미실시**
>
> **사용자 지시:** “가시꽃 덫도 괴이한 지뢰 코드를 그대로 가져오는데, 괴이한 지뢰는 좀 이따가 펑 터지잖아? 근데 우리는 동그란 덫이 팍 펼쳐지는거지. 그러니까 씨앗이 괴이한 지뢰처럼 굴러가다가 덪이 팍 펼쳐진다 라는거지.”

**확정 결정:** [DEC-2026-10-30-07](../decisions/2026-10-30-thorn-trap-magicraft-deceptive-mine-deployment.md)

## A. 게임에서 보여야 하는 4단계

1. **투척:** 시전자가 가시꽃 **씨앗**을 앞으로 던진다. 공중/바닥에서 씨앗이 실제로 회전한다.
2. **굴림·튕김:** 씨앗은 마법공예 **괴이한 지뢰(诡雷 / Deceptive Mine, 주문 ID `1012`)**처럼 속도·중력·반발·마찰을 적용받으며 바닥을 따라 굴러가고 짧게 튄다. 적을 향해 직진하는 미사일이나 착지 즉시 설치되는 정적 구슬로 구현하면 안 된다.
3. **팍! 전개:** 지뢰의 **지연 폭발 순간을 우리 게임의 원형 덫 전개 이벤트**로 바꾼다. 씨앗이 열리면서 중심에서 사방으로 가시/꽃잎/팔이 **동시에 빠르게 펼쳐져 하나의 동그란 덫 형태**로 고정된다. 이것은 폭발 피해와 구별되는 **설치 완료 연출**이다.
4. **설치된 덫:** 전개된 덫은 바닥에 **그대로 남아** 접근하는 적을 감지하며 기존 가시꽃 덫의 공격 역할을 수행한다. **전개 → 감지 → 발동**을 별도 상태로 유지한다. 원작 지뢰처럼 폭발하는 순간 오브젝트가 사라지는 형태로 만들지 않는다.

한 줄 정의: **“괴이한 지뢰처럼 굴러가는 씨앗 → 약간의 지연 → 원형 가시꽃 덫이 팍 펼쳐짐 → 펼쳐진 덫이 적을 기다림.”**

## B. 원작 코드 조사: 확정된 메커니즘과 포팅 범위

원작은 Magicraft 공개 역컴파일 `kav1982/_reverse_engineering`의 **`Spell1012TrickMine`** 시리즈. 공식 소스 아님, 버전 차이 가능.

| 원작 소스 | 확인된 실제 처리 | 우리 Godot 구현에 가져올 부분 |
|---|---|---|
| `Spell1012TrickMineSystem.cs` 초기화 | `ReboundCount=100`, `Gravity=15`, `CurrentFallSpeed=-4`, `FallingReboundForceRatio=0.33`; 회전 방향/효과 초기 각도 | 회전·바닥 충돌·감쇠되는 튀기/굴림을 가진 **씨앗 투척 운동** |
| `Spell1012TrickMine.cs` 이전 구현 | 현재 속도가 정지 임계값보다 작으면 정지; 내려올 때 반동·이동속도·회전속도 감소; 바닥 처리 | 씨앗이 바닥에서 실제로 튀고 점차 굴러 멈추는 과정 |
| `Spell1012TrickMineSystem.cs` 업데이트 | 시간이 끝나면 `Explosion()`. 근거리 반경 **0.6** 내 적이 있으면 먼저 폭발할 수 있음. 남은 시간이 **1.5초** 내라면 점멸 예고 | **지연 발동/예고 원리** 참고. **원본의 조기 폭발·연쇄 폭발을 그대로 공격으로 이식하지 않음** |
| `Spell1012TrickMine.cs` 이전 구현 | 지속시간 끝 무렵 `ExplodeBefore` 애니메이션; 종료 시 `Explode()` | 예고→덫 전개 애니메이션으로 교체 |
| `Spell1012TrickMineSystem.cs` `Explosion()` | 범위 피해, VFX/사운드, 인접 지뢰의 연쇄 폭발 트리거 | **교체 대상**. 원형 덫 전개를 수행하고 장판/히트박스 생성, 씨앗 본체 제거. 인접 지뢰 자동 연쇄 폭발은 합의되지 않았으므로 이식 금지 |

### 원작 설정값의 의미 — `SpellConfig.json`

주문 `10121` / `10122` / `10123`은 공통으로 **`speed=8`, `upSpeed=2`, `gravity=-10`, `duration=3.5초`**, 반경은 **1.5 / 1.8 / 2.2**로 지정되어 있다. 시스템 초기화의 실제 `Gravity=15` 등은 설정값과 상황이 달라 **원본 운동 상태·데이터 단위를 함께 분석한 뒤 Godot 픽셀에 변환**해야 한다. 3.5초는 원작 지뢰의 수명이고 우리 덫의 전개 지연 시간으로 무조건 확정된 값이 아니다.

**미확정 구현 상세안:** 씨앗을 얼마나 오래 굴릴지, 적과 접촉하면 즉시 펼쳐질지, 원형 덫이 열린 순간 자체에 공격 판정이 있는지, 열리는 애니메이션을 몇 프레임 쓸지는 **사용자가 아직 결정하지 않음**. 우선 지연 전개, 이후 적 접근 발동이라는 구조를 유지한다.

## C. 현행 게임 코드와 문제점

- [`scripts/spell_runtime.gd`](../../../scripts/spell_runtime.gd) `PROFILE["thorn"]`: 속도 **320 픽셀/초**, 탄환 수명 **0.85초**, 현재 **직선 이동 `p.pos += p.dir*p.speed*delta`**.
- 같은 파일 `update_projectiles()`: 시드가 적과 충돌하거나 수명이 끝나면 `install(p)`로 즉시 설치. 바닥 물리·씨앗의 실제 회전·튕김·지연 전개 단계 **없음**.
- `install()`에서 `zone.kind="thorn"`을 생성하고 `behavior.register_garden(zone)`으로 중첩 설치 그룹을 등록. 덫 설치 뒤의 적접근 판정은 `update_zones()`에 있음.
- 현행 덫은 설치 후 **약 0.25초**부터 적이 반경에 있으면 `activated`되고 피해를 준 뒤 종료하는 구조. **전개(시각)와 발동(피해)을 별도로 분리**하고, 적접근 판정을 정지된 덫에만 적용해야 함.
- [`scripts/spell_progression.gd`](../../../scripts/spell_progression.gd): 기존 `thorn` 강화 0~3 반경 **62/80/100/125**, 지속시간 **6/7/8/9초**. 이는 **설치 후 덫의 성능**이며 새 씨앗 굴림의 물리 타이머와 구분해야 함.
- [`scripts/magic_catalog.gd`](../../../scripts/magic_catalog.gd): 설명을 `씨앗이 튀며 굴러감 → 원형 덫 전개 → 적 접근 시 발동`에 맞춰 갱신해야 함.

## D. 수정 파일과 개발 요구

1. **`spell_runtime.gd`**: `thorn`에만 독립 **ROLLING_SEED → DEPLOYING → ARMED_TRAP → TRIGGERED/EXPIRED** 상태를 둔다. 원본 씨앗 물리를 2D로 구현하고 `vortex`와 공유 중인 `seed`/설치 경로에서 분리한다. `install()` 호출 시점은 지연 전개 규칙과 일치하도록 이동한다.
2. **`spell_behaviors.gd`**: 설치 후 적 접근 감지·명중·덫 종료는 유지. 새로운 전개와 적접근 폭발을 **두 이벤트로 계측**하여, 씨앗이 펼쳐진 순간에 적을 자동 공격하는 버그를 막는다. 현행 가시꽃 덫의 `garden` 중첩 규칙은 별도 승인 없이 제거하지 않는다.
3. **`magic_visuals.gd`**: 회전·바닥 굴림·충돌 순간·씨앗 열림·동그랗게 **팍 펼쳐지는** 가시꽃 애니메이션 및 무장 완료 모습. 데미지 반경과 원형 덫의 실제 화면 반경이 일치해야 한다. 원작 스프라이트를 복사하는 게 아니라 우리 게임의 2D 스타일로 제작.
4. **`spell_progression.gd`**, **`magic_catalog.gd`**: 투척 씨앗 물리/설치 후 덫 수명/강화 수치가 구별되도록 데이터·툴팁 변경. 강화 0~3 세부 매핑은 미확정.
5. **`magic_extensions.gd`**, **`fusion_effects.gd`**, `support_fusions.gd`: `meteor_thorn`(유성 가시꽃), `timed_thorn`(시한 가시꽃)의 **낙하·전개·반복 공격**을 새 상태와 일치시키는 호환성 시험. 갈래·메아리·관통·낙하·시간 트리거/소멸 후도 점검.
6. **관련 이전 결정:** [소용돌이 씨앗의 중첩 폐기](../decisions/2026-10-30-vortex-magicraft-black-hole-replacement.md)는 `vortex`에 한정. `thorn` 공유 중첩 함수는 부주의하게 삭제하면 안 됨.

## E. 실제 엔진 검증 기준

- **적 없음:** 씨앗을 발사하면 던져진 물리 동작으로 튕기고 굴러 **일정 시간이 지나 원형 덫으로 전개**. 덫이 생긴 뒤에는 즉시 폭발하지 않고 유지되는지.
- **적 있음:** 굴러가는 도중 적과의 충돌/접근이 어느 상태를 유발하는지 기록. 전개한 덫에 적이 들어오면 실제 덫 발동/피해.
- **전개 연출:** 실제 원형 배치가 빠르게 펼쳐지고 **활성 판정도 펼쳐진 크기에 맞게** 표시. 씨앗이 곧바로 고정 원으로 바뀌는 가짜 연출 금지.
- **발사 방향·속도·튐:** 원본 괴이한 지뢰의 굴림·반동이 시각/좌표 로그에 반영되는지. 단순 직진 0.85초 뒤 설치하면 **불합격**.
- **다중 씨앗:** 원형 덫이 여럿 있는 경우 전개와 적 접근 발동이 서로 다른 이벤트로 구분되고, 원본 지뢰의 연쇄 폭발 기능이 임의로 되살아나지 않는지.
- **강화·합성:** 강화 0~3, 유성 가시꽃, 시한 가시꽃, 4오브, 빠른 다중 발사, 시간 트리거/소멸 후 등 합성·연결 호환. `vortex` 변경 작업과 병합 충돌 없는지.
- **검증 수준:** 소스 비교와 보고서 작성만 진행. 실제 Godot 테스트/웹 배포/애니메이션 아트 제작은 **미실행**. 스크린샷/프레임 기록 없이는 VERIFIED로 승격하지 않음.

## F. 출처

- [마법공예 `Spell1012TrickMine.cs` — 튀기·굴림·감속·예고·폭발](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1012TrickMine.cs)
- [`Spell1012TrickMineSystem.cs` — ECS 초기화·회전·조기/만료 폭발·주변 연쇄](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1012TrickMineSystem.cs)
- [`Spell1012TrickMineData.cs` — 폭발 쿨다운/연쇄 면역](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1012TrickMineData.cs)
- [`Spell1012TraceSystem.cs` — 원본 지뢰 폭발 흔적의 시간별 VFX](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1012TraceSystem.cs)
- [원작 `SpellConfig.json` — 10121~10123 레벨별 수치](https://github.com/kav1982/_reverse_engineering/blob/main/assets_export/SpellConfig.json)
- [원작 `TextConfig_Spell.json` — 한국어 이름 ‘괴이한 지뢰’](https://github.com/kav1982/_reverse_engineering/blob/main/assets_export/TextConfig_Spell.json)

**저작권과 이식 범위:** 사용자 표현 **“코드를 그대로 가져온다”**를 원본 메커니즘의 **정밀 재현 기준**으로 문서에 명시했다. 공개 역컴파일 소스의 직접 재배포 허가는 확인되지 않았으므로 원문 코드를 대량 복사하지 않고, 사용 가능 범위를 확인하면서 **행동·계산 순서를 Godot에 충실히 대응 구현**하도록 한다. 사용자의 ‘원형 덫 전개’ 요구를 훼손하는 원작 폭발 판정/연쇄폭발까지 동일하게 재현하지 않는다.
