# MAGIC-METEOR-1013-2026-10-31-01 · 운석 마법공예 방식 코드 교체

- 작성일: 2026-10-31
- 사용자 지시: “운석은 무조껀 마법공예식으로 바꿔 코드에 적어놔 무조껀 마법공예식으로”
- 상태: **CODE_CHANGED / GODOT_RUNTIME_UNVERIFIED**. 실제 코드와 테스트는 GitHub에 반영했으나 Godot 실행 검증 전.
- 저장소: LittleEvasn/witchlings-mayhem
- 원본 출처: kav1982/_reverse_engineering 의 Spell1013MeteorSystem.cs, Spell1013Meteor.cs, 法术数值总表.md.

## 실제 이식한 동작

1. 기존 운석은 화염구 + 낙하(내부 ID meteor) 합성을 유지한다. 첫 타격 뒤 반경 45/75/105/135 고리 충격파 4회를 예약하던 분기를 **삭제했다**.
2. 원작 운석은 시전 초기 **본체 1개와 소형 운석들**을 별개 개체로 생성한다. 우리 코드에도 실제 독립 낙하체 배열을 만들고 각 운석의 출발좌표, 목표좌표, 고도, 수직속도, 중력, 진행시간을 업데이트하게 했다.
3. 원본 Magicraft 1013의 강화 소형 운석 수 **0 / 2 / 5**를 기준으로 우리 기본 공격의 0~3단계에 **0 / 2 / 5 / 5**로 매핑했다. 완성 합성 운석은 현재 최고 단계 프로필을 사용하므로 **본체 1 + 소형 5 = 6개**가 시전 때 생성된다. 본체 착탄 후 새끼가 생성되는 구조가 아님.
4. 각각의 운석은 실제 2D 월드에서 낙하하고 **착탄 지점에서만 독립 범위 피해와 폭발 이펙트**를 발생시킨다. 비행 중 피해 없음. 소형 운석은 별도의 연결 마법을 무한 발동하지 않음.
5. 낙하 중 본체와 소형 운석 각각의 현재 공중 위치 및 독립 착탄 범위 표기를 렌더링하고, 모든 운석을 게임 상태 초기화에서 정리한다. 동시 개체는 상한 96으로 제한한다.

## 실제 코드 변경

- [scripts/magic_extensions.gd](../../../scripts/magic_extensions.gd): launch_meteor / add_meteor_body / update_meteors / meteor_impact 추가, 구형 고리 충격파 제거.
- [scripts/magic_visuals.gd](../../../scripts/magic_visuals.gd): 개별 낙하 위치 및 착탄 예고 렌더링.
- [scripts/magic_catalog.gd](../../../scripts/magic_catalog.gd): 운석 툴팁 새 동작으로 교체.
- [tests/magic60_test.gd](../../../tests/magic60_test.gd): 1+5 생성, 낙하 중 이동/무피해, 6회 독립 착탄, 구형 충격파 없음, 게임 초기화 시 미착탄 운석 제거 테스트.

## 원작과의 차이 / 검증되지 않은 부분

- 공개 역컴파일의 소형 운석 프리팹 계수(tinyMeteorDamageRatio / tinyMeteorSizeRatio / tinyMeteorHeightShift 등)는 필드명만 확인되며 **실제 Unity 직렬화 값이 제공되지 않는다**. 현재 Godot에서 **피해 0.28배, 크기 0.48배, 낙하 0.58~0.86초 등은 조정용 값**이며 원작의 숫자와 동일하다고 주장하지 않는다.
- 원작 구형 구현에는 **조건부 반동·재낙하·호버 및 굴절/반사 처리**도 존재한다. 이번 변경은 **독립 생성·실제 낙하·착탄 폭발**을 우선 이식했으며 해당 조건부 특수 이동을 원작과 동등하게 모두 포팅한 상태는 아니다. 사용자 최종 목표는 원작식으로 일치시키는 것이므로 미이식 항목으로 남겨 둔다.
- 원본 게임은 3단계 강화, 우리 게임은 완성 합성 최고 프로필을 사용하는 4단계 체계다. 임의로 소형 6개 이상의 비원작 단계는 만들지 않았다.
- 현재 코드의 시각·피해 검사, Godot 4.6.2 엔진 컴파일/웹 빌드/4오브 성능은 **미실행**. GitHub에 추가한 테스트가 실제 통과했는지는 확인 후 별도 검증해야 한다. 소스 변경만으로 완전 이식 완료 판정을 내리지 않는다.

## 참조

- [원작 ECS 운석](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1013MeteorSystem.cs)
- [원작 이전 Unity 운석](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/Spell1013Meteor.cs)
- [원작 10131~10133 수치표](https://github.com/kav1982/_reverse_engineering/blob/main/%E6%B3%95%E6%9C%AF%E6%95%B0%E5%80%BC%E6%80%BB%E8%A1%A8.md)

**핵심 계약: 운석은 반드시 실제 낙하체 본체+소형 운석의 개별 착탄이어야 하며, 옛 원형 충격파 4회 방식으로 되돌리지 않는다.**