extends RefCounted
## Front-end flow and neutral layout. Existing art only; purchased GUI skin remains separate.
const Spells=preload("res://scripts/spells.gd")
const Content=preload("res://scripts/run_content.gd")
const Relics=preload("res://scripts/relics.gd")
const GuiSkin=preload("res://scripts/crafting_board.gd")

static func open(ui: CanvasLayer, page: String, shade_alpha := .35) -> void:
	ui.close_modal()
	ui.modal=Control.new()
	ui.modal.name="Front_"+page
	ui.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.modal.mouse_filter=Control.MOUSE_FILTER_STOP
	ui.root.add_child(ui.modal)
	ui.front_screen=page
	ui.hud.visible=false
	ui.game.player.visible=page=="intro"
	var shade:=ColorRect.new()
	shade.name="ModalShade"
	shade.color=Color(.025,.035,.065,shade_alpha)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.modal.add_child(shade)
	ui._resize_modal_shade()

static func action(ui: CanvasLayer, name: String, text: String, rect: Rect2, callback: Callable, primary := false, font_size := 20) -> Button:
	var b: Button=ui.button(ui.modal,text,rect,callback,primary,font_size)
	b.name=name
	return b

static func token(ui: CanvasLayer, id: String, at: Vector2, slot := -1) -> Control:
	var tile: Panel=ui.panel(ui.modal,Rect2(at,Vector2(100,64)),ui.PANEL)
	tile.mouse_filter=Control.MOUSE_FILTER_PASS
	if slot>=0:
		ui.label(tile,str(slot+1),Vector2(5,1),10,ui.MUTED)
	if id.is_empty():
		ui.label(tile,"—",Vector2(39,20),19,ui.MUTED)
		return tile
	var part: Dictionary=Spells.definition(id)
	var rank: int=Spells.Progression.rank(id)
	tile.tooltip_text=part.name+"\n"+part.desc
	ui.label(tile,ui.Board.glyph(id),Vector2(35,1),27,part.color)
	if rank>0: ui.label(tile,"+%d"%rank,Vector2(74,2),11,ui.MINT)
	var name_text: String=Spells.definition(Spells.Progression.base_id(id)).name
	var text: Label=ui.label(tile,name_text,Vector2(4,39),12,ui.TEXT,92)
	text.max_lines_visible=1
	text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	return tile

static func finish(ui: CanvasLayer, focused: String, order: Array) -> void:
	GuiSkin.apply_skin(ui,ui.modal)
	var controls: Array=[]
	for key in order:
		var c: Control=ui.modal.get_node_or_null(key)
		if is_instance_valid(c) and (not c is BaseButton or not c.disabled): controls.append(c)
	for i in controls.size():
		var before: Control=controls[posmod(i-1,controls.size())]
		var after: Control=controls[(i+1)%controls.size()]
		controls[i].focus_previous=controls[i].get_path_to(before)
		controls[i].focus_next=controls[i].get_path_to(after)
		controls[i].focus_neighbor_top=controls[i].get_path_to(before)
		controls[i].focus_neighbor_bottom=controls[i].get_path_to(after)
	var target: Control=ui.modal.get_node_or_null(focused)
	if target!=null: ui.call_deferred("focus_front",weakref(target))

static func title(ui: CanvasLayer) -> void:
	open(ui,"title",.24)
	var saved: Dictionary=ui.game.checkpoint_info()
	ui.label(ui.modal,"W I T C H L I N G S '   M A Y H E M",Vector2(100,138),16,ui.MINT)
	ui.label(ui.modal,"마녀들의\n사고현장",Vector2(94,185),72,ui.TEXT)
	ui.label(ui.modal,"숙제는 조수에게. 사고는 우리에게.",Vector2(100,384),22,ui.TEXT)
	ui.portrait(ui.modal,Rect2(700,130,620,620))
	var order: Array=[]
	var y:=434.0
	if not saved.is_empty() and saved.run_id not in ui.game.profile.data.completed_ids:
		action(ui,"Continue","이어하기 · %d웨이브 준비"%(int(saved.wave)+1),Rect2(100,y,360,60),ui.game.resume_checkpoint,true,21)
		order.append("Continue")
		y+=73
	action(ui,"NewExperiment","새 실험",Rect2(100,y,360,55),ui.show_kits,saved.is_empty(),23)
	order.append("NewExperiment")
	y+=66
	for item in [["Collection","발견 도감"],["Records","실험 기록"],["Settings","설정"],["Quit","게임 종료"]]:
		var id: String=item[0]
		action(ui,id,item[1],Rect2(100,y,360,44),func():
			match id:
				"Collection": ui.show_collection("title")
				"Records": ui.show_records()
				"Settings": ui.show_settings(true)
				"Quit": quit_prompt(ui)
		)
		order.append(id)
		y+=55
	ui.label(ui.modal,"루미의 실험",Vector2(855,713),26,ui.MINT)
	ui.label(ui.modal,"실패작의 마석으로 주문을 만들고,\n교수님이 돌아오기 전에 사고를 수습하자.",Vector2(755,755),18,ui.TEXT,460)
	var note: String="제작 중 자동 저장 · 준비 완료 후 전투는 저장하지 않아요."
	if not ui.game.checkpoint_store.warning.is_empty(): note=ui.game.checkpoint_store.warning
	if not ui.game.checkpoint_message.is_empty() and saved.is_empty(): note=ui.game.checkpoint_message
	ui.label(ui.modal,note,Vector2(100,811),14,ui.MUTED,550).max_lines_visible=2
	if not ui.game.profile.warning.is_empty(): ui.label(ui.modal,ui.game.profile.warning,Vector2(100,843),13,ui.PINK,1200)
	finish(ui,order[0],order)

static func start_selected(ui: CanvasLayer) -> void:
	if ui.game.state!="title": return
	if not ui.game.checkpoint_info().is_empty():
		confirm_replace(ui)
		return
	ui.game.begin_lumi_run(ui.setup_kit,ui.setup_intro)
	if ui.game.state=="title":
		prepare(ui)
		ui.label(ui.modal,ui.game.checkpoint_message,Vector2(622,775),13,ui.PINK,690).max_lines_visible=1

static func confirm_replace(ui: CanvasLayer) -> void:
	open(ui,"replace",.6)
	ui.panel(ui.modal,Rect2(420,260,620,346),ui.INK)
	ui.label(ui.modal,"이어할 실험이 있어요",Vector2(454,294),29,ui.TEXT)
	ui.label(ui.modal,"새 실험을 시작하면 이전 제작 저장은 사라져요.\n발견 도감과 끝난 실험 기록은 남아요.",Vector2(454,356),19,ui.MUTED,540)
	action(ui,"CancelReplace","시작 조합으로 돌아가기",Rect2(454,514,280,52),func():prepare(ui),true,17)
	action(ui,"ConfirmReplace","새 실험 시작",Rect2(752,514,250,52),func():
		ui.game.begin_lumi_run(ui.setup_kit,ui.setup_intro)
		if ui.game.state=="title":
			confirm_replace(ui)
			ui.label(ui.modal,ui.game.checkpoint_message,Vector2(454,440),15,ui.PINK,540)
	,false,18)
	finish(ui,"CancelReplace",["CancelReplace","ConfirmReplace"])

static func prepare(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	if not g.Economy.KITS.has(ui.setup_kit): ui.setup_kit=g.selected_kit
	open(ui,"prepare",.3)
	ui.label(ui.modal,"새 실험 준비",Vector2(96,64),36,ui.TEXT)
	ui.label(ui.modal,"마녀와 시작 주문을 확인해 주세요.",Vector2(98,116),18,ui.MUTED)
	ui.portrait(ui.modal,Rect2(82,176,468,468))
	ui.label(ui.modal,"루미",Vector2(240,616),38,ui.MINT)
	ui.label(ui.modal,"귀찮은 숙제는 마법 조수에게.\n멈춤 조건을 빼먹은 건 비밀이야.",Vector2(144,680),19,ui.TEXT,370)
	ui.label(ui.modal,"현재 플레이할 수 있는 마녀",Vector2(164,755),15,ui.MUTED)
	ui.label(ui.modal,"시작 조합",Vector2(622,110),23,ui.MINT)
	var order: Array=[]
	var i:=0
	for id in g.Economy.KITS:
		var kit: Dictionary=g.Economy.KITS[id]
		var b:=action(ui,"Kit_"+id,kit.name+"   ·   "+Spells.describe(kit.recipe),Rect2(622,153+i*66,690,55),func():ui.setup_kit=id;prepare(ui),ui.setup_kit==id,18)
		b.tooltip_text=kit.note
		order.append("Kit_"+id)
		i+=1
	var selected: Dictionary=g.Economy.KITS[ui.setup_kit]
	ui.panel(ui.modal,Rect2(622,438,690,205),ui.INK)
	ui.label(ui.modal,selected.note,Vector2(643,450),19,ui.TEXT,640)
	var slot:=0
	for id in selected.recipe:
		var at:=Vector2(644+slot*100,496)
		var part: Dictionary=Spells.definition(id)
		ui.panel(ui.modal,Rect2(at,Vector2(88,82)),ui.PANEL).tooltip_text=part.desc
		ui.label(ui.modal,ui.Board.glyph(id),at+Vector2(22,0),32,part.color)
		var text: Label=ui.label(ui.modal,part.name,at+Vector2(4,51),13,ui.TEXT,80)
		text.max_lines_visible=1
		text.tooltip_text=part.name+" · "+part.desc
		slot+=1
	ui.label(ui.modal,"공통 지급: 별빛탄 · 명중 후  |  다른 구체도 전투 중 획득·제작 가능",Vector2(643,606),13,ui.MUTED,640)
	var toggle:=CheckButton.new()
	toggle.name="ReplayIntro"
	toggle.text="도입 이야기 보기"
	toggle.position=Vector2(622,663)
	toggle.size=Vector2(300,45)
	toggle.button_pressed=ui.setup_intro
	toggle.toggled.connect(func(value):ui.setup_intro=value)
	ui.modal.add_child(toggle)
	ui.label(ui.modal,"이동 WASD · 회피 Space · 공격 자동\n오브 1은 가장 가까운 적, 오브 2는 그다음 적을 노려요.",Vector2(622,718),16,ui.TEXT,690)
	action(ui,"PrepareBack","← 타이틀",Rect2(96,813,200,46),g.return_title,false,17)
	action(ui,"StartExperiment","실험 시작 →",Rect2(1002,802,310,60),func():
		start_selected(ui)
	,true,23)
	order.append_array(["ReplayIntro","StartExperiment","PrepareBack"])
	finish(ui,"Kit_"+ui.setup_kit,order)

static func intro(ui: CanvasLayer) -> void:
	if ui.game.state!="intro": return
	open(ui,"intro",0)
	ui.intro_index=clampi(ui.intro_index,0,Content.INTRO.size()-1)
	ui.panel(ui.modal,Rect2(180,636,1080,206),ui.INK)
	ui.label(ui.modal,"루미   ·   %d / %d"%[ui.intro_index+1,Content.INTRO.size()],Vector2(208,656),20,ui.MINT)
	var line: Label=ui.label(ui.modal,Content.INTRO[ui.intro_index],Vector2(208,699),23,ui.TEXT,1016)
	line.name="IntroLine"
	action(ui,"IntroSkip","건너뛰고 시작",Rect2(208,783,210,38),ui.game.begin_combat,false,16)
	action(ui,"IntroNext","전투 시작 →" if ui.intro_index==Content.INTRO.size()-1 else "다음 →",Rect2(1010,779,222,44),func():
		if ui.intro_index==Content.INTRO.size()-1: ui.game.begin_combat()
		else: ui.intro_index+=1;intro(ui)
	,true,18)
	ui.label(ui.modal,"이동 WASD · 회피 Space · 조합 Tab · 공격은 자동이에요",Vector2(240,51),19,ui.MINT,1020)
	action(ui,"IntroBack","← 시작 조합",Rect2(1080,91,180,38),ui.show_kits,false,16)
	finish(ui,"IntroNext",["IntroNext","IntroSkip","IntroBack"])

static func results(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	open(ui,"results",.4)
	ui.label(ui.modal,"사고 수습 완료" if g.result_win else "실험 중단",Vector2(86,89),42,ui.MINT if g.result_win else ui.PINK)
	ui.label(ui.modal,"루미의 실험 · 일반 결말" if g.result_win else g.end_reason,Vector2(90,153),18,ui.TEXT,425)
	ui.portrait(ui.modal,Rect2(70,229,420,420))
	ui.label(ui.modal,"멈춤 조건의 단서 발견" if g.result_win else "다음 실험에서는 다른 주문을.",Vector2(90,686),22,ui.MINT,425)
	ui.label(ui.modal,"마석·구체·유물은 사라져도\n사고의 단서와 실험 기록은 남아요.",Vector2(90,735),17,ui.MUTED,420)
	ui.panel(ui.modal,Rect2(560,92,770,166),ui.INK)
	var ending: String="루미: 멈췄다! 이제 숙제만 대신해 주면…\n교수님: 이 실습장, 너희가 치워.\n루미: …그게 제일 귀찮은데." if g.result_win else "교수님이 폭주한 실험을 멈췄다.\n실패작과 그 마석으로 만든 주문·유물도 사라졌다.\n루미: 실패한 주문은 기억했어. 다음엔 다르게 해보자."
	ui.label(ui.modal,ending,Vector2(582,114),19,ui.TEXT,724)
	var stats: Array=[["전투",Content.clock(g.elapsed)],["제작·편집",Content.clock(g.prep_elapsed)],["처치",str(g.kills)],["획득 마석",str(g.economy.total_earned)]]
	for i in stats.size():
		var x:=560+i*196
		ui.panel(ui.modal,Rect2(x,279,182,77),ui.PANEL)
		ui.label(ui.modal,stats[i][0],Vector2(x+14,286),14,ui.MUTED)
		ui.label(ui.modal,stats[i][1],Vector2(x+14,313),25,ui.TEXT)
	for orb in 2:
		var x:=560+orb*395
		ui.panel(ui.modal,Rect2(x,379,375,222),ui.INK)
		var heading: Label=ui.label(ui.modal,"오브 %d"%(orb+1),Vector2(x+18,392),21,ui.MINT if orb==0 else ui.PINK)
		heading.name="ResultOrb%d"%orb
		for slot in 6:
			var id: String=g.orb_recipes[orb][slot] if slot<g.orb_recipes[orb].size() else ""
			var tile: Control=token(ui,id,Vector2(x+18+(slot%3)*112,432+int(slot/3)*75),slot)
			tile.name="ResultSlot%d_%d"%[orb,slot]
	var names: Array=[]
	for id in g.relics.owned: names.append(Relics.definition(id).name)
	var relic_text: String="이번 유물 · "+(" / ".join(names) if not names.is_empty() else "없음")
	var relic_label: Label=ui.label(ui.modal,relic_text,Vector2(562,624),16,ui.MUTED,768)
	relic_label.max_lines_visible=3
	relic_label.tooltip_text=relic_text
	action(ui,"RetrySame","같은 시작 조합으로 다시",Rect2(560,735,770,57),func():
		if g.state=="ended": g.begin_lumi_run(g.selected_kit,false)
	,true,22)
	action(ui,"RetryOther","다른 시작 조합 고르기",Rect2(560,807,445,47),ui.show_kits,false,18)
	action(ui,"ResultTitle","타이틀",Rect2(1024,807,306,47),g.return_title,false,18)
	if not g.profile.warning.is_empty(): ui.label(ui.modal,g.profile.warning,Vector2(90,844),13,ui.PINK,430)
	finish(ui,"RetrySame",["RetrySame","RetryOther","ResultTitle"])

static func quit_prompt(ui: CanvasLayer) -> void:
	open(ui,"quit",.65)
	ui.panel(ui.modal,Rect2(450,292,540,280),ui.INK)
	ui.label(ui.modal,"게임을 종료할까요?",Vector2(483,326),29,ui.TEXT)
	action(ui,"CancelQuit","돌아가기",Rect2(483,466,220,56),ui.show_title,true)
	action(ui,"ConfirmQuit","종료",Rect2(729,466,220,56),ui.game.request_quit)
	finish(ui,"CancelQuit",["CancelQuit","ConfirmQuit"])

static func back(ui: CanvasLayer) -> void:
	match ui.front_screen:
		"title": quit_prompt(ui)
		"prepare", "records", "quit", "settings_title": ui.game.return_title()
		"intro": ui.show_kits()
		"results": ui.game.return_title()
		"settings_pause": ui.show_pause()
		"replace": prepare(ui)
		"collection": ui.close_collection()
