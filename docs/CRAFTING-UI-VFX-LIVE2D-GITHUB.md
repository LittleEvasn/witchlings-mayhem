# 제작 UI·무료 VFX·Live2D·GitHub 확인 · 2026-10-27

## 이번에 실제 변경한 것

잔불을 최근 이동선 폴리라인에서 **이동 중 차례로 놓는 개별 원형 장판**으로 바꿨다. 다른 마법·경제·제작 UI 배치는 이번에 개편하지 않았다.

- 시전 후1초 동안 새 이동을 따라 설치. 기본 반경24에 중심 간격52.8(반경×2.2), 강화 시 반경/수명 표 유지.
- 정지 중 추가 걸음 장판 없음. 시작 지점에 같은 프로그램의 기존 장판이 있으면 겹쳐 놓지 않음.
- 갈래는 평행한 원형 장판 줄. 같은 오브의 겹친 피해는 최강만.
- 연결 후 발현은 사건점의 짧은3원 배치이며 플레이어를 따라오지 않는다.
- 시전 그룹별 첫 명중/정상 종료 연결 유지. 생성기가 닫힌 뒤 마지막 원형 장판 수명이 끝날 때 종료 연결. 강제 정리/상한 취소는 연결하지 않음.
- 순간이동200초과에는 복도 전체를 칠하지 않음. 전체 영역256/발자국 생성기128 안전 한도와 측정 기록 유지.
- 관련21개 검사 통과: 정지/이동거리/원형 충돌·빈틈/갈래/강화/연결/강제정리/순간이동/불꽃행진. 다른 전체 마법 검사는 반복하지 않았다. 이전 magic_v2_test의 폴리라인 기대값은 새 사용자 지시에 맞춰 갱신했으며 이번에 전체 실행하지 않았다.
- 실제 화면 artifacts/round-ember-game.png:216거리 이동 후 원5개, 간격52.8. 실행 로그 오류 없음. Windows 실행파일 갱신 성공.
- 백업 artifacts/round-ember-before-20261027. 전용검사 tests/round_ember_test.gd, 결과 artifacts/round-ember-verification.json.

## 제작 UI 추천안 — 아직 배치 구현 안 함

현재 두 오브와 가방의 직접 편집은 유지한다. 오른쪽 좁은 칸이 제작안·상세·강화·합성 도감을 교대로 맡는 대신 세 영역으로 역할을 고정한다.

|영역|내용|
|---|---|
|왼쪽 약22%|구체 제작안/가격/재구성, 합성9종 도감. 제작/합성 두 탭|
|가운데 약52%|항상 보이는 두 오브×6, 바로 아래 가방. 오브 번호 장식·큰 빈 여백 축소|
|오른쪽 약26%|선택한 구체/도안의 현재 행동→강화 후 행동, 소비할 실제 구체·마석, 실행 버튼|

가방·오브의 선택을 유지한 채 재료를 고른다. 드롭만으로 강화하지 않고 결과를 확인한 뒤 실행한다. 시험 발사/준비 완료는 아래 고정, 시험 복귀 때 선택·스크롤 보존. 첫 구현은 재배치와 선택 상태 유지만, 필터/연출은 그 뒤다. 재미 개선은 사용자 플레이로 확인해야 한다.

아이디어 담당 Astra/high가 현재 코드와 화면2장을 읽어 제안했다. 세션01a17caf-2997-74d3-9b2d-5722a8bd0ef8, 실제 모델 관찰 DB 확인. 파일 편집·시험·참고게임 플레이 없음.

## Cartoon Coffee 무료40종

확인한 원본: `C:/Users/user/Desktop/Witchlings' Mayhem/cartoon-coffee-free-minipack-40-vfx/Cartoon Coffee Free Minipack - 40 VFX`.

- 스프라이트 시트40개 모두 RGBA이며 알파0을 포함한다. PNG 연속 프레임과 GIF 미리보기도 있다. Godot에서 사용하는 형식이다.
- 시트 크기:4096² 27개/2048² 11개/1536² 2개. 모두 원본 RGBA로 동시에 올리면 약1922MiB(밉맵·엔진 부가 비용 제외)이므로 필요한 효과만 선택하고 게임 표시 크기에 맞춰 정규화한다.
- More Info.txt는 개인·상업 프로젝트 사용과 프로젝트 내 수정을 허용한다. 제작자의 서면 허가 없는 VFX 재배포·공유는 수정본도 금지한다. 따라서 원본 팩이나 추출 프레임을 GitHub 업로드 대상에 섞지 않는다.
- 불꽃/폭발/별빛/피격/바람은 유용. Projectile_Bullet·Star_Bursts·Star_Flash, Explosion_Bomb·Fire_Burst, Charge_Wind_Loop, Blue Slash, Bonfire 등을 우선 후보로 본다.
- 전용 낙뢰·서리·덩굴/가시 효과는 충분하지 않다. 물 효과를 냉기라고 이름만 바꾸는 식으로 전체 마법을 억지로 덮지 않는다.
- 이번에는 검사·미리보기만 했으며 런타임에 이 팩을 복사/적용하지 않았다. 아트의 실제 크기·타이밍 적합성은 선별 적용 후 확인할 사항.

목록 artifacts/cartoon-coffee-free40-manifest.json, 미리보기 cartoon-coffee-free40-contact.png. GIF의 프레임 수는 시트의 유효 프레임 수라고 간주하지 말고 PNG 시퀀스로 확인할 것.

## GitHub 확인

- GitHub 연결 계정 LittleEvasn 조회 성공. 현재 커넥터가 접근 가능한 저장소 목록은0개다. 이 결과는 사용자의 전체 저장소가 없다는 뜻이 아니다.
- 실제 Godot 프로젝트 폴더에는 .git 없음/원격 없음. Desktop 번들 git.exe 2.53.0 실행 확인. 새 저장소 생성·쓰기·push는 이번에 실행하거나 검증하지 않았다.
- 연결된 대상 저장소에 대한 쓰기 권한이 확인되면 커밋/업로드를 맡을 수 있다. 현재 상태를 업로드 완료나 즉시 push 검증 완료로 보고하지 않는다.
- 저장소 루트는 바깥 Witchlings' Mayhem 전체가 아니라 안쪽 Godot 프로젝트 폴더로 잡는다. 그림·cmo3·can3·외부 VFX 다운로드·zip을 통째로 올리지 않는다.
- 현재 artifacts만2634파일/약249MiB다. .godot, artifacts, 빌드exe/pck, 개인 설정/자격 증명, 재배포 금지 VFX는 제외해야 한다. scripts/scenes/tests/tools/docs/project.godot과 허용된 실행 에셋 위주로 구성한다. 실제 공개 전 별도 업로드 목록 검토가 필요하다.
- GitHub 업로드와 무료 AI 편집 접근은 별개다. 공식 요금 안내는 Free의 소규모 Codex 사용을 명시하지만 계정별 노출/사용 한도가 있으며 저장소 공개로 무제한이 되지 않는다: https://learn.chatgpt.com/docs/pricing

## Live2D 적용 경로

확인: 그림 폴더에 루미.cmo3(890413바이트), Untitled Animation.can3(7978바이트), 별도 SD1.cmo3가 있다. 편집 파일 헤더를 확인했다. Cubism5.3 설치도 있다. 이 폴더에는 .moc3/.model3.json/.motion3.json 출력물이 없다. 원본 앱에서 모델 연결과 실제 모션 재생은 이번에 검증하지 않았다.

**현재 게임에는 투명 PNG 연속 프레임을 우선 추천한다.** Cubism에서 만든 모션을 그대로 렌더하여 Godot AnimatedSprite2D/SpriteFrames로 재생한다. 스파인으로 다시 제작할 필요 없다. 대신 런타임에서 눈/입/머리 파라미터를 실시간 조작하는 방식은 아니다.

1. Cubism에서 can3를 열고 연결된 모델이 올바른 루미인지 확인. cmo3가 여러 개라 파일 이름만으로 동일 모델이라고 단정하지 않는다.
2. 내보낼 애니메이션 장면/작업 범위를 선택.
3. 파일 → 이미지/동영상 내보내기 → 연속 이미지(Still Image / Sequential Number).
4. PNG, 배경 없는 알파, 원본 FPS, 종횡비 유지·폭512px를 첫 시험값으로 출력. 대기/이동 등은 폴더 분리.
5. Godot에서 동일 캔버스/발 기준점과 프레임 간격으로 연결. 게임에서 뭉개짐·루프 이음새 확인 후 최종 크기 결정.

**실시간 Live2D 재생도 별도 경로로 가능하다.** 비공식 GDCubism(GDExtension)은 Godot4.3이상을 표기한다. 실제4.6.2/사용자5.3모델 호환성과 SDK 배포 조건은 별도 확인이 필요하며 이번에 설치하지 않았다. cmo3를 모델용 .moc3+.model3.json+텍스처로, can3의 각 장면을 .motion3.json으로 내보낸 뒤 연결한다. .cmo3/.can3를 Godot에 그대로 넣는 방식은 아니다.

근거:
- Live2D 게임용 데이터/출력: https://docs.live2d.com/en/cubism-editor-manual/export-moc3-motion3-files/
- 공식 연속 이미지 내보내기: https://docs.live2d.com/en/cubism-editor-manual/exporting-images/
- GDCubism 작성자 저장소: https://github.com/MizunagiKB/gd_cubism
- GDCubism/연결 SDK 조건: https://mizunagikb.github.io/gd_cubism/gd_cubism/0.9/en/license.html

참여: 총괄 Sol6.1/high 조사·잔불 구현·관련 검증, Astra/high UI 제안1회. 새 유료 서비스·구매·GitHub 게시·Cubism 설치/에디터 수정 없음. 토큰 가격 미제공, 비용 절감 실측 주장 없음.
