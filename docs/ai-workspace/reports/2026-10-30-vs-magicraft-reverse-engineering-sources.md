# REF-2026-10-30-01 · 뱀파이어 서바이버즈·마법공예 원작 역분석 공개 자료 링크

> **상태: PROPOSED (참고 자료 등록) / 게임 코드 미변경 / 구현 승인 아님.** 외부 저장소의 존재·구성 및 알려진 관련 파일 경로를 근거로 한 탐색 목록이다. 원작과 동일한 실행 결과를 검증하거나 Godot에서 테스트한 문서는 아니다.

- 작성일: 2026-10-30
- 프로젝트: `LittleEvasn/witchlings-mayhem`
- 우리 저장소 기준: `main` / `85f904ce9457` (참고 문서 작성 기준, 게임 코드 분석·수정 없음)
- 목적: 다른 ChatGPT와 Codex가 **원작 내부 구조가 공개적으로 분석된 위치**를 바로 찾고 조사할 수 있게 링크를 공동 등록한다.
- 범위: 링크 목록 및 검토 목적만 기록. 원작 코드·게임 에셋의 복사, 재배포, 실제 게임 수정은 수행하지 않음.

## 1. Vampire Survivors — 역컴파일 코드 및 내부 시스템

### VS-01 · IL2CPP 역컴파일·구조 재구성 코드

- 저장소: **[Salmacis32/VampireSurvivorsRefCompilationProject](https://github.com/Salmacis32/VampireSurvivorsRefCompilationProject)**
- 목적: 원작 Unity/IL2CPP의 무기·투사체·스테이지·오브젝트·데이터 타입 구조 조사.
- 우선 확인할 파일:
  - [Objects/Weapons/Weapon.cs](https://github.com/Salmacis32/VampireSurvivorsRefCompilationProject/blob/master/Objects/Weapons/Weapon.cs)
  - [Objects/Projectiles/Projectile.cs](https://github.com/Salmacis32/VampireSurvivorsRefCompilationProject/blob/master/Objects/Projectiles/Projectile.cs)
  - [Objects/Stage.cs](https://github.com/Salmacis32/VampireSurvivorsRefCompilationProject/blob/master/Objects/Stage.cs)
  - [Objects/Pools/BulletPool.cs](https://github.com/Salmacis32/VampireSurvivorsRefCompilationProject/blob/master/Objects/Pools/BulletPool.cs)
- **한계:** 비공식 역컴파일/재구성 자료이며 공식 원본 소스가 아니다. 클래스·함수 선언만 있고 본문이 비어 있는 스캐폴드가 많다. GitHub에서 archived 상태. 메서드 실구현 여부를 파일별로 확인할 것.

### VS-02 · 무기·진화·투사체·스테이지 모딩 분석

- 저장소: **[lukeod/vampiresurvivors-modding](https://github.com/lukeod/vampiresurvivors-modding)**
- 목적: 실제 원작 런타임의 `WeaponData`, 진화/유니온 조건, 투사체 생성·재사용, 스폰, 성능 최적화 및 이펙트 구조 조사.
- 우선 확인:
  - [weapon-system.md](https://github.com/lukeod/vampiresurvivors-modding/blob/main/weapon-system.md)
  - [stage-system.md](https://github.com/lukeod/vampiresurvivors-modding/blob/main/stage-system.md)
  - [performance-guide.md](https://github.com/lukeod/vampiresurvivors-modding/blob/main/performance-guide.md)
  - [visual-effects.md](https://github.com/lukeod/vampiresurvivors-modding/blob/main/visual-effects.md)
  - [examples/projectile-manipulator/ProjectileManipulator.cs](https://github.com/lukeod/vampiresurvivors-modding/blob/main/examples/projectile-manipulator/ProjectileManipulator.cs)
- **한계:** 모딩·기술 설명이며 게임 실행 코드 전체나 최신 원작 동작에 대한 완전한 증명은 아니다.

### VS-03 · 게임에서 추출한 스테이지·적·무기 설정 데이터 (보조 자료)

- 저장소: **[SurvivatonsAndMore/VampireSurvivorsFiles](https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles)**
- [Stage.json](https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles/blob/main/Data/Vampire%20Survivors/Stage.json) — 광기의 숲(`FOREST`) 분 단위 적/보스/이벤트/스폰 설정
- [Enemy.json](https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles/blob/main/Data/Vampire%20Survivors/Enemy.json) — 적 종류 및 능력값
- [Weapon.json](https://github.com/SurvivatonsAndMore/VampireSurvivorsFiles/blob/main/Data/Vampire%20Survivors/Weapon.json) — 무기 데이터
- **한계:** 정적 설정 데이터다. 실행 시 충돌/위치 계산, 렌더링, AI 알고리즘을 전부 설명하지는 않는다. 추출 버전·최신 원작과 차이 확인 필요.

## 2. Magicraft / 魔法工艺 — 실제 내부 코드 역분석

### MC-01 · PC판 원작 C# 역컴파일 및 주문 시스템 분석

- 저장소: **[kav1982/_reverse_engineering](https://github.com/kav1982/_reverse_engineering)**
- 목적: 원작 PC판의 주문 생성·전달·이동·소멸·분열, 강화 누적과 트리거 연결 규칙 분석.
- 우선 확인:
  - [decompiled/Assembly-CSharp/SpellShootData.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellShootData.cs)
  - [decompiled/Assembly-CSharp/ShootSpellUtils.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/ShootSpellUtils.cs)
  - [decompiled/Assembly-CSharp/SpellShootSystem.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellShootSystem.cs)
  - [decompiled/Assembly-CSharp/SpellMoveJob.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellMoveJob.cs)
  - [decompiled/Assembly-CSharp/SpellDestroySystem.cs](https://github.com/kav1982/_reverse_engineering/blob/main/decompiled/Assembly-CSharp/SpellDestroySystem.cs)
  - [坠落逆向分析.md](https://github.com/kav1982/_reverse_engineering/blob/main/坠落逆向分析.md) — 낙하와 다른 이동/발동 형태의 결합
  - [分裂逆向分析.md](https://github.com/kav1982/_reverse_engineering/blob/main/分裂逆向分析.md) — 분열·파생 발동
  - [激光表现_美术说明.md](https://github.com/kav1982/_reverse_engineering/blob/main/激光表现_美术说明.md) — 레이저 표현 구조
- **한계:** 비공식 역분석이며 공식 공개 원본 소스 아님. 해당 분석자가 사용한 PC판 버전, 역컴파일 정확도, 실제 게임 결과와의 차이를 확인할 것.

### MC-02 · 모바일판 APK 역분석 및 마법 VFX 증거/재현 자료

- 저장소: **[kav1982/MFGY_Chick](https://github.com/kav1982/MFGY_Chick)**
- 목적: 모바일판 마법별 텍스처, 파티클, 머티리얼 연결 관계와 Unity에서의 재현 연구.
- 우선 확인:
  - [Assets/ReverseEngineering](https://github.com/kav1982/MFGY_Chick/tree/main/Assets/ReverseEngineering)
  - [ExtractedTextures](https://github.com/kav1982/MFGY_Chick/tree/main/Assets/ReverseEngineering/Art/ExtractedTextures) — 주문 ID별 이미지 자료
  - [AllSkillEvidence.json](https://github.com/kav1982/MFGY_Chick/blob/main/Assets/ReverseEngineering/Data/AllSkillEvidence.json) — 스킬별 VFX 참고 데이터
- **한계:** 모바일판 기준이며 PC판과 같은 리소스/동작을 보장하지 않는다. 원작 에셋 복사·재사용 권한을 부여하는 자료가 아니다.

## 3. Codex / 다른 GPT가 조사할 때 지킬 것

1. **원작 자료 → 확인된 작동 원리 → 우리 Godot 적용 아이디어**를 분리해 기록한다. 원작의 함수를 이름만 보고 구현으로 단정하지 않는다.
2. VS는 **무기 발사 간격·진화·상자·적 시간표·대량 전투**, Magicraft는 **주문 조합 실행 순서·후속 트리거·공전/낙하/분열·VFX 구성** 조사에 우선 활용한다.
3. 공개 저장소 파일의 **메서드 본문 유무**, 역분석 대상 버전, 자료 수집 방법, 재현 여부를 확인한다.
4. 역컴파일된 원작 코드·원작 이미지·VFX를 우리 게임에 그대로 반입하거나 배포하지 않는다. 라이선스와 권리관계는 별도로 검토하고, 확인된 원리를 바탕으로 **독립 구현**한다.
5. 이 목록은 **코덱스 작업 지시나 밸런스 수치 승인**이 아니다. 구현 요청은 별도 `decisions/` 승인과 `handoffs/` 인계 후 수행한다.
6. 기존 발사 템포 보고서 `BAL-2026-10-30-01`의 값과 별개로, 참고 자료 링크를 제공하는 **자료실 성격의 보고서**이다.

## 4. 검증 수준

- 확인: GitHub 저장소 존재, 각 저장소의 설명 및 대표 코드/문서 경로 확인.
- 미실시: 최신 원작 직접 실행·플레이, 공개 소스 전체의 함수 단위 검증, Godot 성능 시험·A/B 테스트.
- 작성 결과: 참고 링크 등록만 수행. **게임 코드 및 기획 규칙 미변경**.
