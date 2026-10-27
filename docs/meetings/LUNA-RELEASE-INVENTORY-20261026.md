# 루나 사실 조사 반환 요약

발언: wm_scout_product_inventory / 실제 gpt-6-luna/high. 읽기전용, 게임실행·검사·수정 없음. 아래는 총괄의 별도 확인과 구분한 루나의 조사 범위다.

- spells.gd:6부터 기본공격9 확인: 별빛탄/꽃폭탄/달빛부메랑/소용돌이씨앗/가시꽃덫/서리숨결/벼락/달무리위성/잔불발자국.
- spells.gd:12부터 보조8, 연결2(명중후/소멸후). prep_board.gd:117 두오브x6 표시.
- prep_board.gd:5 합성글리프5확인. 실제 합성정의는 지정범위밖 spell_progression.gd이므로 루나는세부확인하지않음. 총괄이이후FUSIONS5를직접확인.
- economy.gd:7 시작꾸러미4. interface.gd:355 공통부품/시작만다르고다른편성가능 안내.
- waves.gd:4 웨이브5, 마지막보스지원/120초. 실제출현성공/적이름은미확인.
- GENERATION.md:6 마녀1/슬라임·박쥐임프·갑충아트. actor.gd:30 크롭사용. 보스전용새아트미확인.
- relics.gd:5 유물12정의,52미보유선택3제시.
- interface.gd:346 결과화면다른조합재시도/판재화초기화, economy.gd 제작/강화/합성/재구성. 영구해금재도전목표는지정범위에서확인못함.
- 아트문서가Generated prototype art로표기, actor.gd:2 바운스/기울임임을명시, interface.gd:275 MAGIC EXPERIMENTS0.8. assets의사운드파일못찾았으나코드생성인지는루나미확인(총괄이game.gd1331에서별도확인).

현재수량/재도전구조는코드사실이며상용완성도/실제재미를평가한것은아니다. 광범위재설계/구체추가권고는하지않았다.
