# Magicraft 실제 역컴파일·모바일 VFX 재검토 v3
2026-10-29. 사용자 제공 조사문을 실제 저장소 파일·설정과 대조했다. 게임 소스/아트/저장/원문 보고서 변경 없음. 이전 v1/v2의 “원작 복합 실행 코드 미확인” 상태는 이 문서가 갱신한다.

## 1. 결론
**관련 메서드 본문이 있는 PC 역컴파일 자료가 실제 공개되어 있다.** 자동 조작/모드/계산기만 보고 근거가 부족하다고 멈춘 앞선 조사는 핵심 자료를 놓쳤다.
다만 공식 소스 공개가 아니라 제3자가 올린 역컴파일·추출물이다. 저장소 설명의 출처/원작 버전 일치·실제 게임 실행 결과를 별도로 인증한 것은 아니다.
실제 본문과 설정이 있어 이제 낙하/공전/분열/후속 연결/광선의 구조를 구체적으로 비교할 수 있다. 원작 분석 문서에도 코드와 안 맞는 설명이 있어 그대로 옮기면 안 된다.
이번 결과는 **정적 조사와 규칙 차이 보고**다. 새 마법 구현·성능·밸런스 합격 보고가 아니다.

## 2. 조사 대상·고정 버전·정확한 범위
파일별 blob SHA·검토 행 범위는 [MAGICRAFT-CORE-SOURCE-EVIDENCE-v3.json](MAGICRAFT-CORE-SOURCE-EVIDENCE-v3.json)에 기록했다. 내려받았다는 사실과 본문을 검토한 범위를 혼동하지 않도록 메서드 범위를 제한했다.
- PC: [kav1982/_reverse_engineering](https://github.com/kav1982/_reverse_engineering), commit `d7f6cbe82dfd52ce2d71cf5f09dc393c86931ea8` (2026-09-10). 재귀 목록 3,538항목, truncated=false. Assembly-CSharp 아래 .cs는 **3,402개**다. 작성자의 3,403개 설명과 현재 트리 수가 1개 다르며 “약3,400개”는 맞는다. 모두 읽은 것이 아니라 아래 실행 경로를 선택해 읽었다.
- 모바일: [kav1982/MFGY_Chick](https://github.com/kav1982/MFGY_Chick), commit `0055918c0ac42b8c3933a2c7b5cd1a71f0a62f3a` (2026-08-29). 재귀 목록 3,492항목, truncated=false.
- 주로 읽은 PC 분석 문서: 마법 시스템 총괄, 낙하, 분열, 레이저와 레이저 미술 설명의 관련 절. 문서를 읽은 것과 아래 C# 본문으로 대조한 것을 구분했다. 모든 마법별 분석 문서/3,402개 파일을 전수 감사했다는 뜻이 아니다.
- PC 실제 본문: SpellGroupParser/SlotData의 보조 범위, SpellShootData/Extend/InitialParameter, ShootSpellUtils, SpawnParams/Storage/Processor, ShootSystem, MoveJob, DestroySystem, HitTrigger/OverTrigger/MoveTrigger/TwineTrigger, LaserJob, SpellTools/RadiusAttributeValue, 피해 결과/DPS·블랙홀 관련 메서드. 정확한 파일·행·blob은 동반 근거 목록 참조.
- 모바일: 두 README/분석 문서, Summary, Spell_1004, **AllSkillEvidence.json 전체 6,418,669바이트를 JSON으로 파싱**해 수량과 1004 참조 확인. 원본 APK를 직접 추출하거나 파티클을 실제 재생하지 않았다.
- 총괄 Sol6.1/high: PC 실행 경로·다른 저장소·모바일 JSON 직접 검산·보고서. 조사 Luna/high 1명: 모바일 자료·PNG 목록·PC 레이저 VFX 교차 확인. 보조 세션 `01a187bb-fc65-7f40-a2c5-6cdecf131768`, 실제 모델은 관찰 DB로 확인.

## 3. 실제 호출 경로
1. **편집 → 주문 트리**: SpellGroupParser 생성자 27~49행에서 공격마다 왼쪽 보조 목록을 저장한다. NextShoot 93~132행에서 연결과 하위 그룹을 만든다.
2. **보조 집계**: SpellShootData의 종류별 getter → SpellInitialParameter.Builder.ProcessShootDataEffect 282~374행에서 이동/피해/원소/낙하 등 집계.
3. **발사 계획**: ShootSpellUtils.ShootSpellGroup 140~188행이 각 공격의 매개변수를 만들고, SipToSSP 196행부터 SpellSpawnParams로 변환한다.
4. **생성**: SpellShootSystem.SpawnSpellEntity 213~615행이 컴포넌트·충돌·궤도·연결을 구성하고 발사 상태를 저장한다.
5. **진행**: 일반 이동은 MoveJob, 레이저/분해광선/장판은 해당 전용 Job. 하나의 범용 이동 루프만으로 전부 처리하지 않는다.
6. **명중 → 연결**: TakeDamageResult 240~248행 → HitTriggerSystem 170~199행 → ShootSpellBuffer.ShootByTrigger 14~25행 → 하위 그룹을 새로 발사.
7. **소멸 → 분열**: DestroySystem.Split 486~584행 → 저장된 SpawnParamsStorage.ToSplit 36~58행 → SpawnSpellEntity. 보조 목록 전체를 다시 스캔하는 경로가 아니다.

## 4. 앞선 판단을 고쳐야 하는 핵심

### 4.1 후속에 보조가 모두 끊기는 것이 원작 규칙은 아니다
[SpellGroupParser.cs](https://github.com/kav1982/_reverse_engineering/blob/d7f6cbe82dfd52ce2d71cf5f09dc393c86931ea8/decompiled/Assembly-CSharp/SpellGroupParser.cs) 32~48행에서 왼쪽 보조 누적 목록은 공격이나 연결을 만났다고 전부 비워지지 않는다.
109~129행은 하위 그룹에서 숨길 보조만 제외한다. [SlotData.cs](https://github.com/kav1982/_reverse_engineering/blob/d7f6cbe82dfd52ce2d71cf5f09dc393c86931ea8/decompiled/Assembly-CSharp/SlotData.cs) 671~674행의 HindInSubGroup은 이 스냅샷에서 **Multishot만 true**다.
따라서 이 코드에서는 거대화 같은 다른 보조가 후속에 남을 수 있다. “원작은 거대화·반복을 포함한 모든 보조를 연결에서 초기화한다”는 주장은 성립하지 않는다.
우리 최신 확정 규칙은 연결에서 전부 초기화하므로 **의도적으로 원작과 다른 규칙**이다. 사용자의 기존 후속 거대화 불만을 이 조사만으로 뒤집지 않는다.
메아리 이름도 구분해야 한다: 원작 回响는 명중 연결3205, 우리 메아리는 지연 복제 보조다. Multishot3002가 우리 메아리에 더 가까운 반복 역할이다. 이름 동일 여부로 상속을 결정하지 않는다.

### 4.2 낙하 × 공전은 착지 후에만 공전하는 구조가 아니다
SpellShootDataExtend.GetSpellMovementType 99~116행은 왼쪽 보조 목록을 **오른쪽에서부터** 보아 공전/마우스추적/적추적/자기추적 중 하나를 선택한다. 마지막 적용 이동 보조가 우선하는 방식이다.
낙하는 별도 IsFallSpell·높이·수직 속도다. SpellTools 1887~1897행이 생성 높이를 -7로 만들고, ShootSystem의 Rotation 분기가 XY를 궤도에 놓는다. MoveJob.Normal_Rotation 706~719행은 **현재 z를 보존한 채 XY를 공전**한다. Normal_Fall 532~556행은 별도로 z속도와 착지를 처리한다.
따라서 일반 경로에서는 공중에서 공전하며 내려온다. v1/v2의 “낙하 → 착지 후 공전”은 원작 확인 결과가 아니라 우리 권고였으며 원작과 다르다.

### 4.3 일반 레이저와 지속 분해 광선은 서로 다른 실행 형태다
[Spell1004LaserJob.cs](https://github.com/kav1982/_reverse_engineering/blob/d7f6cbe82dfd52ce2d71cf5f09dc393c86931ea8/decompiled/Assembly-CSharp/Spell1004LaserJob.cs) 194~646행: 초기화 때 경로를 계산하고 명중/착지 피해를 전달한 뒤 IsInitialize=true.
211행은 표시 수명 0.2초+정체 시간, 633~636행은 초기 명중했으면 0.2초. 652~670행에는 초기 비명중·정체 상태인 경우 새 적을 잡는 별도 검사 경로가 있다. 그래서 “무조건 첫 프레임 외엔 아무 판정도 없다”라고 단순화해도 틀린다.
설정10041~10043은 isDPS=false, duration=0, speed=15. 여기서 speed는 초기 경로 길이 예산으로 쓰이고 이후 이동 속도는 210행에서0으로 바뀐다.
반면 설정10111 분해 광선은 isDPS=true, duration=2, DPSDamageInterval=0.1이다. **설정과 역할이 다름**을 확인했으며 이번에 1011 전용 Job 전체의 반복 판정까지 감사하지는 않았다.
우리 계획의 A11 레이저가 지속 빔이라면 원작1004 복제라고 부르면 안 된다. 순간 레이저인지 지속 빔인지 먼저 정의해야 한다.

### 4.4 낙하 레이저의 “반경0이라 피해가 거의 없음”은 설정·계산식과 충돌
작성자의 레이저/낙하 분석 문서는 해당 추정을 중간 신뢰도/미확인으로 남겼다. 하지만 다음 코드를 끝까지 이으면 비영 반경이 나온다.
- SpellShootData.GetSpellFallExplosionRadius 596~601행: Fall.float1 합산.
- SpellConfig31191~31193: float1=**1 / 1.5 / 2.3**.
- InitialParameter 355행에서 fallExplosionRadius 저장, SipToSSP 258~262행에서 Radius.FallRadius에 반영.
- [RadiusAttributeValue.cs](https://github.com/kav1982/_reverse_engineering/blob/d7f6cbe82dfd52ce2d71cf5f09dc393c86931ea8/decompiled/Assembly-CSharp/RadiusAttributeValue.cs) 24~26행: **(Base + FallRadius) × (1+AddRatio) × MulRatio + Extra**.
- LaserJob.TouchGroundExplosion 1407~1425행: 바로 그 Calculate 값을 피해 검색 반경으로 사용한다.
레이저 기본 Base=0이어도 FallRadius가 들어오므로, 다른 보정이 없는 기본 낙하 반경은 **1**이다. 범위 보조가 있어야만 피해가 난다고 이 자료에서 결론 낼 수 없다. 정적 데이터 경로의 정정이며 실제 피격 수/콜라이더 경계 실측은 아니다.

### 4.5 분열은 현재 잔여 상태가 아니라 발사 스냅샷을 복사
[SpellSpawnParamsStorage.cs](https://github.com/kav1982/_reverse_engineering/blob/d7f6cbe82dfd52ce2d71cf5f09dc393c86931ea8/decompiled/Assembly-CSharp/SpellSpawnParamsStorage.cs) 36~58행:
- Params를 복사한 뒤 SubGroup과 다섯 종류의 trigger 정보를 비운다.
- IsSplitSpell=true, Split.Count=0. 자식은 재분열/사용자 후속을 새로 얻지 않는다.
- 피해 배율×splitData.DamageRatio, 범위 Base/Extra×0.8, 밀침×0.5. 일반 자식 속도×0.5, 낙하 자식은 반동 계수×0.7.
- 발사 스냅샷의 관통/반사/수명/원소는 남는다. 부모가 다 쓴 남은 횟수를 복사하는 것이 아니라 발사 때 저장한 값을 받는다. 지속/피해 타이머가0인 스냅샷을 새로 생성하는 구조다.
- SipToSSP 314~317행의 분열 피해 비율은0.33. 원소 부여량은 ToSplit에서 별도 분배하지 않는다. 앞선 우리 권고의 proc_mass 분배는 원작 동작으로 확인된 것이 아니다.
- DestroySystem 491~494행은 충전 타이머만 현재 부모에서 별도로 옮긴다. 모든 값이 무조건 스냅샷인 것도 아니다.
- ShootSystem 647행은 분열 자식의 번개 사슬 피해를 추가로×0.35한다. 개별 효과 예외가 존재한다.

### 4.6 원작 명중 연결은 첫 명중 한 번이 아니다
SipToSSP 473~480행은 명중 연결의 Cooldown=1 / int2합계로 설정한다. 설정32051~32053의 int2=4/6/8이므로 기본 반복 허용 간격은0.25 / 약0.167 /0.125초다.
TakeDamageResult 240~248행은 쿨다운이 끝난 유효 피격에서 NeedTrigger를 다시 올린다. HitTriggerSystem은 소비 가능한 마력이 있으면 하위 주문을 실행한다. 같은 프레임 다중 명중은 쿨다운으로 제한하지만 전체 수명 단 한 번으로 제한하지 않는다.
**우리 첫 명중1회는 의도적인 별도 규칙**이다. 원작처럼 바꾸면서 마나 제한까지 제외하면 생성량이 훨씬 커질 수 있으므로 무단 이식 금지.

### 4.7 도탄·굴절·추적을 하나로 취급하면 안 된다
원작 Rebound3012는 물리 충돌 반사 횟수다(MoveJob 218~250행). 적 사이를 새로 겨누는 Refraction3121과 다르다.
SpellTools.TryRefract 1900~1948행과 LaserJob.RefractionTransformGet 1352~1392행은 방문 대상을 제외하되 목표가 없으면 이전 기록을 비우고 현재 명중 대상만 제외해 재검색한다. 원작이 전체 수명 동안 A→B→C→A를 영구 금지한다고 말하면 틀린다.
우리 새 도탄을 적 간 이동+영구 visited로 만들겠다는 것은 원작 그대로의 Rebound가 아닌 우리 정책이다.

### 4.8 연결 두 개 연속은 원작에서 항상 문법 오류가 아니다
Parser120~131행은 연속 trigger를 배열로 모아 동일 하위 그룹에 연결한다. SipToSSP는 각 trigger종류별 컴포넌트를 구성한다.
[A 명중연결 종료연결 B]는 이 파서에서 A에 두 사건을 붙여 B를 공유할 수 있는 구조다. [A 연결 B 연결 C]는 하위 그룹 재귀로 표현한다.
우리의 연속 연결 부분 무효 규칙은 사용자 확정이므로 유지하되 “마법공예도 그 부분은 불가능하다”고 설명하지 않는다.

## 5. 사용자 요청 12개 상호작용 대조표
“확인”은 이 저장소 정적 코드와 설정 기준이다. 공식 최신 빌드에서 실행 검증했다는 뜻이 아니다.

|번호|상호작용|실제 자료에서 확인한 것|우리에게 필요한 판단|
|---|---|---|---|
|1|낙하 × 공전|XY 공전과 수직 낙하 동시. 이동 방식 선택과 낙하 플래그는 분리|착지 뒤 공전 제안 수정 후보. 원작식 병렬축 또는 우리 고유 규칙을 명시|
|2|공전 × 광선|1004는 초기36단계로 원형 폴리라인을 생성. 낙하면 전용 높이 경로/착지 피해|회전하는 발사점에서 지속 빔이 나가는 이전 제안과 다름. 순간/지속 정의부터|
|3|추적 × 도탄|추적은 선택된 movement.Type, Rebound는 물리 반사. 굴절의 재표적 기록은 막히면 초기화|반사와 적 간 이동의 이름·설명·방문 정책 분리|
|4|분열 × 복제|발사 시 다중 발사 수를 전개, 분열은 발사 스냅샷을 복사. 재분열과 trigger 제거|우리 메아리와 원작 Multishot을 대응해 생성권·위력·상태 예산 따로 결정|
|5|분열 × 연결|분열 자식에서 SubGroup/Hit/Over/Move/Twine/OverSplit 정보 제거|사용자 후속 소유권 원본 한정은 실제 참고 근거 확보|
|6|광선 × 명중 후|1004는 초기 경로 명중, 정체 특수 재검사. 명중 연결 시스템 자체는 쿨다운 반복 가능|우리 첫명중1회 유지와 원작 차이 명시. 지속1011 전용 Job은 후속 감사 대상|
|7|장판 × 공전|일반 공전은 transform.XY 갱신, 블랙홀 Job은 현재 transform 중심으로 범위 피해. 낙하 상태는 별도 분기|이 사례가 모든 덫/장판 지원을 입증하지 않음. 우리 공격별 이동 가능 표 필요|
|8|다중 시전 × 메아리|GetSpellMultiShootData는 반복 수 합산·간격 최댓값, Parser는 부모 Multishot만 하위에서 제외|반복을 다시 하위에서 곱하지 않는 근거. 원작 回响는 지연복제가 아니라 명중연결|
|9|속성 × 지속 공격|DPS 판정은 Damage×DamageInterval, 별도 타이머. 블랙홀은 원소 패킷과 시간보정 전달|모든 속성이 공통0.2초 간격이라는 근거 없음. 원소별 중첩/갱신은 추가 시험 필요|
|10|속성 × 분열|ElementComponentData 전체는 스냅샷에 남음. ToSplit에서 동일비례 분배 없음|이전 proc_mass 분배는 우리 밸런스 제안. 원작과 같다고 주장 금지|
|11|합성 × 일반 보조|저장소의 canCompound·단계 합성과 우리 고유 레시피 완성30은 동일 시스템으로 확인되지 않음|우리 완성형 각각 상속표·강화 정의 필요. 원작 코드만으로30종 합격 판정 불가|
|12|연결 × 연결|연속 trigger 배열과 재귀 SubGroup. 종료/명중/이동/부모공전은 서로 다른 이벤트|연속 연결 무효는 우리 별도 문법. 취소·무한 재귀·다중 사건은 우리 정책 검사 필요|

속성 시간 보정도 범위를 제한해서 읽는다. SpellTools3250~3257행은 저FPS 최적화가 켜진 경우 VenomApplyCount에 LastFrameTimeScale을 곱할 뿐이다. 모든 속성이 이 방식으로 정규화된다는 증거가 아니다. 이번에는 독·화상·냉기·전격의 적 내부 상태 갱신 루프 전체를 감사하지 않았다.

## 6. 레이저 VFX의 실제 구조
PC LaserLineApplySystem183~223행은 Trail/Shadow를 찾아 같은 경로를 본체 LineRenderer에 적용하고 그림자는 XY/Z0으로 투영해 너비를 맞춘다.
LaserJob672~702행은 소멸 때 현재 폴리라인 구간을 샘플링해 전역 VFX 버퍼에 위치/색상 데이터를 기록한다. VFXController41~66행은 버퍼를 GraphicsBuffer로 넘겨 재생한 뒤 비운다.
즉 **경로 계산/피해 → 선 표시 → 명중·소멸 파티클**이 나뉜다. PNG 몇 장만 가져오면 같은 효과가 된다는 구조가 아니다.
미술 설명에는 별도 Spell10008_BendPreview/LaserBendDestroyDemo 시제품도 등장하지만 두 저장소의 현재 트리에서 그 C#는 찾지 못했다. **문서상의 재현 미리보기와 실제 원작1004 코드를 구분**했다.
우리 Godot 적용 원리: 계산한 경로를 판정과 Line2D 표시가 공유하고, 파티클은 hit/end 사건에서 따로 발생시킬 수 있다. 이번에는 구현하지 않았다.

## 7. 모바일 VFX 수량과 재현 상태
트리에서 PNG1,436개, 해당 폴더별1001=92 /1004=5 /1013=14개를 읽기 조사로 셌다.
총괄이 AllSkillEvidence.json을 직접 파싱해 (sourceFile, sourcePathId) 쌍으로 중복 제거:
- ability136, config329행.
- texture참조1,448개 / 고유1,408개.
- material참조854개 / 고유854개.
- particle참조1,628개 / 고유1,628개.
- 1004 행은 texture5 / material15 / particle18 참조.
이는 저장소 JSON과 파일 목록의 일관성 검산이다. 원작 APK에 실제로 모든 리소스가 온전하게 들어 있다는 독립 검증은 아니다.
1004의 implementation.has_dots_source=true는 원본 경로/Metadata 심볼 발견을 말한다. 실제 C# 메서드 본문이 모바일 저장소에 복원되어 있다는 뜻으로 읽지 않는다.
Documentation/FULL_REVERSE_README와 HEAD 커밋 설명은 과거1001/1002/1004 재구축 샘플을 제거했고, 동작·시각 등가 재생은 미검증이라고 명시한다.
모바일 보고서는 APK mfgy_1.2.2f1 / Unity6000.0.62f1 / IL2CPP를 대상으로 한다. PC 보고서의 Mono/ECS와 같은 버전·동작이라고 합치지 않는다.

## 8. 나머지 제공 링크도 확인한 결과
|저장소·고정커밋|실제 확인 범위|판정|
|---|---|---|
|Turing-Project/Magicraft_Autocontrol|이전 v2에서 코드·캐시·API 클라이언트 확인|외부 자동 조작, 원작 엔진 아님. 더 직접적인 PC 자료가 이제 우선|
|lbxx228/Magicraft-MOD / eeaab376403038234a925cf69105f88c9a71a006|트리5항목·MonsterHpRatio.cs 전체/README|실제 BepInEx 패치. 적HP×10·속도×2 기능이며 마법 조합 엔진 자료가 아님|
|oooo0h/Magicraft_mod / f51c2178ec0b8f5b369cfaff747be567c12862f2|트리2항목: README와 InfiniteReroll.dll, README 읽음|소스 .cs 없음. DLL을 역컴파일/실행하지 않았으므로 내부 로직 미분석|
|Heigen007/Unity_Magicraft_Project / a55d45b145b2733989fc6cd03a3fdae207815700|프로젝트 목록·SpellExecutor.cs 실제 분기/메서드|별도 Unity 구현. 36~37/100~103행 Beam 미구현. 원작 엔진 대체 근거 아님|
|MtcLuna05/LeosSpells / 91938017dc278d7203ff1de32e7639402c0d02e0|Java WandItem/SpellBaseEntity의 수집·시전·tick 본문|Minecraft 독립 구현. 원작 상속/광선/낙하 규칙의 증거 아님|

PC/모바일 트리에서 전용 LICENSE 파일을 확인하지 못했다. 다른 프로젝트의 오픈소스 라이선스가 역컴파일 원작/추출 텍스처의 사용권까지 부여하는 것으로 취급하지 않는다. 이번에는 외부 실행 코드/PNG를 게임에 복사하지 않았다.

## 9. 우리 보고서 정정과 다음 작업
1. v1/v2는 이전 시점의 조사 기록으로 보존하되, “원작 복합 코드 미확인”과 이동·보조 상속에 관한 근거 상태는 본 v3가 대체한다.
2. 지금 필요한 것은 마법60개를 즉시 추가하는 것이 아니라 **원작에서 새로 확인된 동작과 우리 확정 규칙의 차이를 반영한 실행 계약**이다.
3. 기존 사용자 규칙인 연결 경계 초기화/첫 명중1회/복제 후속 없음/마나 없음/응축 보류를 이 조사만으로 바꾸지 않는다. 원작과 다른 점을 숨기지 않는다.
4. 새 이동은 “동시에 합성되는 축(낙하 높이)”과 “택일하는 평면 궤도(공전/추적)”를 구분해야 한다. 별도 보조가 항상 같이 작동한다고 미리 약속하지 않는다.
5. 레이저는 순간형인지 지속형인지, 도탄은 벽 반사인지 적 간 굴절인지, 분열 자식의 원소/관통/수명 예산을 원작대로 할지 우리 제한을 둘지 명확히 해야 한다. 확인된 원작 수치는 우리 밸런스 값의 자동 채택 근거가 아니다.
6. 확정 계약으로 직진/광선/장판 최소 실행층을 만들고 12사례·다단계·취소·동시 적·4오브를 검증한 다음 기본30/합성30을 넣는 구현 순서는 유효하다.
7. 추출 파티클의 구성 원리는 참고할 수 있지만 실제 게임 에셋은 별도 적합한 리소스를 사용한다. 자동 구매·VFX 교체·GUI/모션 작업은 이번 범위가 아니다.

## 10. 수행·미수행
수행: GitHub 고정 커밋/재귀 목록·관련 C#/설정 본문 대조, JSON 수량 계산, 분석 문서 오류2곳 정정, 12항목 및 제공 저장소 분류, 관련 프로젝트 코드와 확정 정책 차이 기록.
미수행: 참고 게임 실행/조작/캡처·DLL 실행·외부 모드 설치·원작 코드/그림 반입·새마법 구현·전체 테스트·신규 성능/재미 검증.
로컬 artifacts/magicraft-source-audit/mobile-counts-verified.json은 JSON 검산 결과다. 메타데이터 연구 파일은 artifacts에만 두고 Git에 포함하지 않는다.
