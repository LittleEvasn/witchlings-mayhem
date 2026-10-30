# MAGIC-LASER-2026-10-30-01 · 기본 레이저 → 마법공예 '광선' (Spell 1004) 이식

- **상태: IN_PROGRESS** (Godot/WASM CI 결과 확인 대기, 사용자 플레이 검증 전)
- **날짜:** 2026-10-30
- **사용자 원문:** “레이저 가장 큰 문제인 레이저다 지금은 마법공예의 붕괴 광선의 만들다 만 버전 같은데 바꿔 마법 공예 광선으로 바꿔 코드 그대로 가”
- **확정 의도:** 기본 레이저를 Magicraft의 **광선(激光 / Laser, 주문 ID 1004)**으로 전환. Magicraft의 별도 **붕괴 광선(瓦解射线 / Ray of Disintegration, 1011)**과 혼동 금지.
- **구현 방법:** 저작권 있는 제3자 역컴파일 소스를 문자 단위로 가져오는 것이 아니라, 검사 가능한 동작을 Godot에 대응한 독립 구현. 완전한 일대일 원문 복제는 아니므로 동일하다고 과장 금지.

## 현재 원작 소스에서 확인한 사실

- 원작 1004 기본형: **instant ray**, `Duration=0`, 명중 판정은 발사 시 계산, 광선 라인과 VFX는 약 0.2초 표시. 원작 강화 레벨 1~3의 `int1=0/1/2`가 광선 굴절 횟수. 관통보다는 **대상을 명중한 뒤 다른 대상에게 반사/굴절**하는 것이 강화 특징.
- 별도의 원작 1011: `Duration=2`, `DamageInterval=0.1`, `isDPS=true`, 지속 피해·무제한 관통 성격. 사용자가 기본 레이저에 적용하길 원하지 않는 특성.
- 원작 코드: [Spell1004LaserJob.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1004LaserJob.cs), [Spell1004LaserSystem.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1004LaserSystem.cs), [Spell1004Laser.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1004Laser.cs), [SpellConfig.json](https://github.com/kav1982/_reverse_engineering/blob/main/assets_export/SpellConfig.json).
- 원작 경로 생성은 **발사 당시 구간별 Raycast → 대상 순서대로 타격 → 남은 굴절 기회에 따라 다음 대상 쪽으로 방향 변경 → 최종 폴리라인을 짧게 렌더링**하는 형태. 특수 보조에 따른 공전/낙하/추적 분기도 존재한다.

## 지금 반영한 코드

| 파일 | 구현 내용 |
|---|---|
| [`scripts/instant_laser.gd`](../../../scripts/instant_laser.gd) | 실제 공격 시점에 광선 폴리라인과 다중 적 히트를 계산. 전방의 첫 적과 충돌하면 실제 광선 경로가 종료·굴절, 미명중은 최대 거리까지 직선. 같은 구간 내 타격 중복 방지. 보조 `pierce`, `bounce`, `seek`, `orbit`, `fan` 동작을 위한 가지 분기 |
| [`scripts/magic_extensions.gd`](../../../scripts/magic_extensions.gd) | 기본 `laser`(및 plasma_beam)는 `InstantLaser.fire`를 시전 시 1회 호출. `_laser_instant` 상태는 **추가 피해를 가하지 않고 0.2초 시각 잔상만 유지**. 기존 `disintegration`은 별도 지속형으로 분리하고 관통 허용 |
| [`scripts/spell_progression.gd`](../../../scripts/spell_progression.gd) | 강화 0~3의 기존 `0.7~1.2초 유지/최대 관통 1~4명`을 삭제. **즉발 굴절 0/1/2/3회**. 기존 4단계 게임 시스템에 원작 3단계를 매핑하기 위해 마지막 3굴절은 게임 자체 확장값(원작과 정확한 동등값 아님) |
| [`scripts/magic_catalog.gd`](../../../scripts/magic_catalog.gd) | 표시명 **레이저 → 광선**, 설명: 단발 히트·강화 굴절·0.2초 잔상 |
| [`tests/ai_autoplay_test.gd`](../../../tests/ai_autoplay_test.gd) | 60종 Godot 전투 테스트에 추가로 `추적+광선@3` 밀집 표적 테스트. 즉발 선분·명중·굴절 메트릭 검사 |

## 준수한 핵심 설계

1. **광선 자체는 0.2초 지속 공격이 아니다.** 0.2초는 렌더링 잔상이고 피해는 1회다.
2. 굴절은 적과 적 사이의 **실제 선분**을 따라간다. 다른 적에게 전역 자동 피해만 주는 방식은 금지.
3. 오브/연결 `impact`는 실제 적 명중 위치, `expire`는 광선 종료 위치를 기준으로 실행.
4. `disintegration`은 사용자 요청대로 기본 광선과 달라야 하므로 유지 시간/반복 피해를 별도 유지.
5. `plasma_beam`은 새 즉발 광선 분기를 공유하며, 플라즈마 고유 체인 라이트닝의 전면 재설계는 기존 다른 제안에서 처리.

## 남은 기술 확인·실측 항목

- Godot 4.6.2 실제 CI 파싱·헤드리스 시나리오·웹 빌드 결과.
- 확정된 샘플 레이에서 1회 타격 및 굴절 0/1/2/3회 계측. 적이 없어도 빔의 광선 잔상은 나타나야 함.
- 보조 `fall`, `orbit`, `seek`, `fan`, `pierce`, `bounce`, `echo`, `split`, `trail`과 타격·시각 호환.
- 원작 `Spell1004LaserJob`의 벽 충돌 및 지형 반사, 띄워진 후 관통/시간 지연, 목표 재검출 등은 현재 게임 환경 및 구현 범위를 고려해 추가 검토. **지금 코드를 원작 C#의 완전한 1:1 전수 포팅으로 표시하지 말 것.**
- 강화 원작 3단계와 우리 4단계 수치가 다르므로 밸런스·정확도 구분.
- 기존 60종 AI 테스트와 배포 완료 뒤 실제 화면에서 외형·굴절·타격을 직접 확인하기 전에는 **VERIFIED** 표시 금지.
