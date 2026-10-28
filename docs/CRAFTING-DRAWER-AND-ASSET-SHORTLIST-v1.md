# 제작함 구현·구매 에셋 후보 — 2026-10-27

## 실제 구현

전체 화면 제작대를 오른쪽 개인 제작함으로 교체했다. 논리 1600×900 / 실제 1920×1080에서 폭 520, 오른쪽 여백 24로 전장 가로 약 65%를 드러낸다. 전장에 추가 음영이나 전체 입력 차단막을 씌우지 않는다. 준비 시간과 시험의 기존 세계/경제 분리는 유지한다.

- 위: 오브 2개 × 6칸. 직접 드래그·순서 변경·적용 범위/문법 오류 표시.
- 가운데: 가방 / 제작 / 합성 도감. 목록은 스크롤하며 선택 후 위치를 보존한다.
- 아래: 선택 구체 설명, 장착, 강화 재료/행동 변화 미리보기, 마석 강화와 합치기.
- 맨 아래: 되돌리기 / 시험 발사 / 준비 완료. 시험에서는 같은 배치로 편집하고 준비대로 복귀한다.
- 구매하면 새 구체를 선택한 가방으로 이동한다. 자동 장착하거나 기존 구체를 교체하지 않는다.
- 시험 중 제작/강화/합성은 막고 조합 편집만 허용한다.
- 화면 검사에서 가방 둘째 줄 잘림, 시험 통계와 회피 안내 겹침, 뒤쪽 HUD 문구 노출을 발견해 수정했다.

이번에는 마법 성능·가격·웨이브·유물을 변경하지 않았다. 이전의 전면 제작 화면과 시험 화면을 통합한 것이며, 전투 개인창 전체를 다시 만든 작업은 아니다.

## 구매형 GUI 적용 원칙

사용자는 GUI 구매를 사실상 필수로 판단했다. 이전 기획서의 '구매는 선택' 권고보다 최신 사용자 선호를 우선한다. 현재 색상·기본 패널은 **동작/배치 확인용이며 최종 게임 아트가 아니다.**

`interface.gd`의 `crafting_theme: Theme`를 통해 구매한 PNG를 Godot Theme/StyleBoxTexture로 적용할 진입점을 만들었다.

| Theme 타입 | 사용할 스타일 |
|---|---|
| CraftButton | normal, hover, pressed, disabled, focus |
| CraftPanel | panel |
| CraftSlot | normal, hover, selected |

실제 구매 파일의 9-slice 여백·눌림/선택 상태·장식 두께를 확인하고 적용해야 한다. 기존 글리프와 슬롯 정보도 구매 아이콘과 어울리게 후속 정리할 수 있다. 단순히 프레임을 붙였다는 이유로 완성된 아트라고 판단하지 않는다.

구매 전 필요한 최소 부품은 패널, 탭, 버튼의 상태, 슬롯의 상태, 스크롤바, 선택 테두리, 툴팁, 체력/진행 막대다. 장식보다 구체 아이콘과 행동 변화가 먼저 읽혀야 한다.

## GUI 후보

가격은 2026-10-27 판매 페이지 표시이며 세금/환율은 제외했다. 구매하거나 유료 원본을 반입하지 않았다.

| 후보 | 확인한 구성 | 판단 |
|---|---|---|
| [Dobo Fantasy RPG UI](https://dobo-ui.itch.io/fantasy-rpg-ui-pack) | Premium $3.99, 무료 Demo. 1920×1080, 개별 PNG/시트, 버튼/슬롯 상태·카드·패널·HUD·스크롤바. 판매자 표기 2000+ | **우선 시각 후보.** 공개 구성 이미지에서 밝은 카툰 리본·프레임이 SD 마녀와 잘 맞아 보인다. 실제 무료 Demo의 리사이즈·작은 글자·선택 상태부터 확인할 것. 완제품 적용/품질 보장은 아니다. |
| [LayerLab GUI Pro Fantasy RPG](https://layerlab.itch.io/gui-pro-fantasy-rpg) | itch $39.99. 1200+ PNG, 46개 Godot 4.3+ .tscn 패널, 이미지 카탈로그. PSD/게임 로직/애니메이션 미포함 | 구성은 더 성숙하다. 다만 [공식 약관](https://layerlab.io/pages/licences)이 생성형 AI의 입력/구성요소 사용을 제한하므로, 우리처럼 AI가 화면/아트를 읽는 작업 범위는 판매자에게 확인하기 전 구매 보류 권고. AI가 코드만 작성하는 것까지 금지라고 단정한 것은 아니다. |
| [StationSupply Fantasy RPG UI](https://stationsupply.itch.io/fantasy-rpg-ui-kit) | Standard/Premium, SVG/PNG·9-slice 정보·Godot 데모. Premium 페이지 할인가 $7.80 | 보조 후보. 공개 미리보기의 목재/양피지와 정보 밀도가 사용자가 싫어한 문서 느낌을 충분히 벗어날지는 의문이다. 데모의 4.7.2 사용 표기와 우리 4.6.2 호환은 확인 필요. |

Dobo는 상업 프로젝트 사용/재가공을 허용하며 재배포와 Training/Generative AI를 금지한다고 표기한다. 이것을 생성형 이미지 편집의 허가로 해석하지 않는다. LayerLab의 입력 제한과 동일한 문구는 아니지만, 약관이 애매한 활용은 확인해야 한다. 판매자에게 연락하지 않았다.

## VFX 비교

결론: 이번 조사에서 **CartoonCoffee 메가팩을 확실히 능가하는 비도트 2D 종합팩은 확인하지 못했다.** 기본 계열은 CartoonCoffee를 우선하고, 부족한 계열만 실제 스케일로 검증하는 쪽을 권고한다. Unity 전용 파티클 패키지를 Godot에 바로 쓸 수 있다고 분류하지 않았다.

| 후보 | 가격·실제 형식 | 우리 게임 적합성/한계 |
|---|---|---|
| [CartoonCoffee Mega Pack Spritesheets](https://cartooncoffee.itch.io/megapack-spritesheets) | 할인 $98, PNG 스프라이트시트. Unity Prefabs/영상판과 별도 상품 | 여전히 주력 1순위. 현재 무료팩을 적용한 경험이 있다. 일부 팩은 변형 파일 미포함. 모든 마법, 특히 서리/가시의 전용 효과까지 포함한다고 보장하지 않는다. |
| [Toon Elemental Magic VFX Vol.1](https://taproot-solutions-llc.itch.io/toon-elemental-magic-vfx-vol1) | $2.99. **8종 × 4변형 = 32 애니메이션**, 768²·24프레임 PNG, 5×5 시트 | 불/얼음/번개/물/바람/돌/회복/독. 공개 움직임은 단순한 셀 색과 검은 윤곽선으로 CartoonCoffee보다 덜 풍부해 보였다. 저렴한 대안이지 명백한 상위품은 아니다. 일반 알파 합성, 검은 선 때문에 additive는 부적합. 판매자 No GenAI 표기. |
| [Ice & Frost Vol.1](https://taproot-solutions-llc.itch.io/ice-frost-vfx-vol1) | 할인 $2.09, 8×4변형, PNG/시트 | Frost Breath, Ice Shatter 등 서리숨결 후보. **AI Assisted/Graphics 표기**. 빛나는 수정 질감과 additive 계열이라 주력 팩과 화풍이 달라질 수 있다. 공개 사양만 확인했으며 실제 장착 검증 전이다. |
| [Nature & Plant Vol.1](https://taproot-solutions-llc.itch.io/nature-plant-vfx-vol1) | $2.99, 8×4변형, PNG/시트, 반복 | 꽃·덩굴·잎 계열의 보충 후보. **AI Assisted/Graphics 표기**. Thorn Aura는 정면 링 형태여서 탑다운 가시꽃 덫에 그대로 맞는다고 볼 수 없다. |

Taproot 계열 일부에는 무료 Sampler Vol.2가 있다. Toon의 No GenAI 표기를 Ice/Nature까지 확대하지 않는다. 32개를 서로 다른 주문 32종으로 세지 않는다. 유료 파일의 피벗·실제 알파·메모리·한 화면 다중 재생 성능은 미검증이다.

공개 미리보기는 게임 에셋에 반입하지 않았고 별도 조사 폴더에서만 확인했다. 구매 후에는 원본 압축파일/재배포 금지 에셋을 공개 GitHub에 올리지 않도록 배포 범위를 확인해야 한다.

## 검증 결과와 한계

- 관련 자동 검사: `prep_board_test` 35개, 최신 `crafting_vfx_test` 40개, 실패 0. 무관한 마법 전수검사는 실행하지 않았다.
- 사용자에게 Witchlings 화면 점검만 허용받고 1920×1080 실제 실행에서 제작/가방/합성/시험 4화면을 확인했다.
- 실제 마우스 버튼 입력으로 18마석 제작 → 실물 1개 증가 → 가방 자동 선택, 마석 강화 → bolt@1, 시험 진입 → 준비대 복귀와 선택 유지 확인. `artifacts/crafting-drawer-gui-check.json`.
- 마지막 재실행에서도 HUD 문구가 창 뒤로 노출되지 않음 확인. 게임 실행 로그 오류 없음. 편집기에는 이번 변경과 무관한 기존 경고 10개가 남아 있다. 스크린샷 캡처용 첫 eval의 잘못된 함수 호출은 수정 후 재실행했으며 제품 오류로 집계하지 않았다.
- Windows 빌드 성공, 프로젝트 설정 불변. `artifacts/builds/lumi-run/build-result.json`.
- 실행 화면 검사 후 Witchlings 게임을 중지했다. Cubism/GitHub 창은 조작하지 않았다. 구매/push 없음.

스크린샷: `artifacts/crafting-drawer-{craft,bag,fusion,trial}.png`.
현재 창은 좁은 목록에 스크롤이 필요하고 긴 구체명은 말줄임/툴팁을 쓴다. 현재 배치의 기능 검사와 최종 GUI 미관 평가는 별개다. 사용자 플레이 편의와 장시간 피로도는 후속 피드백이 필요하다.

수정 파일: scripts/crafting_board.gd, crafting_detail.gd(신규), interface.gd, prep_board.gd, prep_slot.gd, tests/crafting_vfx_test.gd. 이외 같은 작업 트리에 이미 있던 마법/VFX/Git 변경은 보존했다.

담당: 총괄 Sol6.1/high 구현·실행 확인·최종 구매 후보 판단, Luna/high 한 명의 한정된 VFX/GUI 조사. 실측 토큰/단독 작업 대비 수치가 없어 비용 절감은 미입증이다.
