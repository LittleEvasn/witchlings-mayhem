extends RefCounted
const Content=preload("res://scripts/run_content.gd")
const Spells=preload("res://scripts/spells.gd")
const Relics=preload("res://scripts/relics.gd")

static func shell(ui: CanvasLayer, title: String, subtitle: String) -> void:
	ui.new_modal(Rect2(160,100,1120,700))
	ui.hud.visible=false
	ui.label(ui.modal,title,Vector2(208,136),36,ui.MINT)
	ui.label(ui.modal,subtitle,Vector2(210,194),18,ui.MUTED,1000)

static func intro(ui: CanvasLayer) -> void:
	shell(ui,"숙제는 조수에게, 사고는 우리에게", "LUMI · 멈춤 조건을 빠뜨린 마녀")
	ui.portrait(ui.modal,Rect2(870,235,330,365))
	for i in Content.INTRO.size(): ui.label(ui.modal,Content.INTRO[i],Vector2(210,267+i*77),21,ui.TEXT,630)
	ui.panel(ui.modal,Rect2(208,520,640,103),ui.PANEL)
	ui.label(ui.modal,"WASD 이동 · 가까운 적 자동 조준 · 자동 시전\nSpace 회피 · Tab 조합 정리\n실패작의 마석으로 웨이브 사이에 구체 제작·강화",Vector2(229,534),18,ui.MINT,600)
	ui.button(ui.modal,"실험 시작  →",Rect2(850,684,360,62),ui.game.begin_combat,true,23).grab_focus()
	ui.button(ui.modal,"시작 부품 다시 고르기",Rect2(210,694,310,45),ui.show_kits,false,18)
	ui.label(ui.modal,"전투 약 8~10분 · 제작 시간 제한 없음 · 진행 중인 실험은 저장되지 않아요",Vector2(210,746),15,ui.MUTED,980)

static func ending(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	shell(ui,"사고 수습 완료" if g.result_win else "교수님이 돌아왔다", "루미의 실험 · 일반 결말" if g.result_win else g.end_reason)
	ui.portrait(ui.modal,Rect2(830,250,350,370))
	var lines: Array
	if g.result_win:
		lines=["루미: 멈췄다! 이제 숙제만 대신해 주면…", "교수님: 이 실습장, 너희가 치워.", "루미: …그게 제일 귀찮은데.", "사고의 단서 · ‘완벽하게 해결해’에는 끝이 없었다.", "다음에는 목표와 함께 멈춤 조건도 적어두자."]
	else:
		lines=["교수님이 폭주한 실험을 멈췄다.", "실패작도, 그 마석으로 만든 주문과 유물도 사라졌다.", "루미: 실패한 주문은 기억했어. 다음엔 다르게 해보자.", "실험을 다시 시작하면 다른 부품과 조합을 시험할 수 있어."]
	for i in lines.size(): ui.label(ui.modal,lines[i],Vector2(210,270+i*66),20,ui.MINT if i==3 and g.result_win else ui.TEXT,620)
	ui.button(ui.modal,"실험 결과 보기  →",Rect2(850,684,360,62),ui.show_results,true,23).grab_focus()

static func results(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	shell(ui,"이번 실험의 기록", "수습 성공 · 멈춤 조건의 단서 발견" if g.result_win else g.end_reason)
	ui.label(ui.modal,"전투 %s    제작·편집 %s    처치 %d    획득 %d 마석" % [Content.clock(g.elapsed),Content.clock(g.prep_elapsed),g.kills,g.economy.total_earned],Vector2(210,252),21,ui.TEXT,1010)
	for i in 2:
		var x:=210+i*515
		ui.panel(ui.modal,Rect2(x,315,495,225),ui.PANEL)
		ui.label(ui.modal,"오브 %d" % (i+1),Vector2(x+20,335),23,ui.MINT if i==0 else ui.PINK)
		ui.label(ui.modal,Spells.describe(g.orb_recipes[i]) if not g.orb_recipes[i].is_empty() else "비어 있음",Vector2(x+20,387),18,ui.TEXT,445).max_lines_visible=5
	var names: Array=[]
	for id in g.relics.owned: names.append(Relics.definition(id).name)
	ui.label(ui.modal,"이번 유물 · "+(" / ".join(names) if not names.is_empty() else "없음"),Vector2(210,566),17,ui.MUTED,1000)
	ui.label(ui.modal,"마석·구체·유물은 새 실험에서 초기화돼요. 결말의 단서와 결과 기록은 남아요.",Vector2(210,627),16,ui.MUTED,1000)
	ui.button(ui.modal,"다른 조합으로 다시",Rect2(210,696,400,60),ui.show_kits,true,22).grab_focus()
	ui.button(ui.modal,"같은 시작 부품으로 다시",Rect2(630,696,350,60),func():g.begin_lumi_run(g.selected_kit),false,19)
	ui.button(ui.modal,"타이틀",Rect2(1000,696,220,60),g.return_title,false,19)
	if not g.profile.warning.is_empty(): ui.label(ui.modal,g.profile.warning,Vector2(210,765),14,ui.PINK,1000)

static func records(ui: CanvasLayer) -> void:
	var data: Dictionary=ui.game.profile.data
	shell(ui,"실험 기록", "수습 %d회 · 실패 %d회 · %s" % [data.wins,data.losses,"루미의 멈춤 조건 단서 발견" if data.lumi_clue else "아직 사고 원인을 알아내지 못했어요"])
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(210,260)
	scroll.size=Vector2(1000,390)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var rows:=VBoxContainer.new()
	rows.custom_minimum_size.x=970
	rows.add_theme_constant_override("separation",16)
	scroll.add_child(rows)
	if data.records.is_empty():
		var empty:=Label.new(); empty.text="첫 실험의 결과를 기다리고 있어요."; rows.add_child(empty)
	for r in data.records:
		if not r is Dictionary: continue
		var line:=Label.new()
		line.text="%s · %s · 전투 %s · 처치 %d" % ["수습" if r.get("won",false) else "실패",ui.game.Economy.KITS.get(r.get("kit","sigil"),{}).get("name","실험"),Content.clock(r.get("combat",0)),r.get("kills",0)]
		rows.add_child(line)
	ui.button(ui.modal,"돌아가기",Rect2(850,696,360,60),ui.show_title,true).grab_focus()

static func settings(ui: CanvasLayer, from_title: bool) -> void:
	var g: Node2D=ui.game
	shell(ui,"소리 설정", "설정은 다음 실행에도 유지돼요. 진행 중인 실험의 이어하기 저장은 지원하지 않아요.")
	ui.button(ui.modal,"효과음  "+("켜짐" if g.sound_enabled else "꺼짐"),Rect2(210,290,460,70),func():g.sound_enabled=not g.sound_enabled;g.save_settings();settings(ui,from_title),false,24)
	ui.button(ui.modal,"배경 음악 · 준비 중",Rect2(210,385,460,70),func():pass,false,24).disabled=true
	ui.label(ui.modal,"현재 배경 음악은 없어요.\n효과음은 플레이 중 M으로도 바꿀 수 있어요.",Vector2(210,500),20,ui.MUTED,950)
	ui.button(ui.modal,"돌아가기",Rect2(850,696,360,60),ui.show_title if from_title else ui.show_pause,true).grab_focus()
