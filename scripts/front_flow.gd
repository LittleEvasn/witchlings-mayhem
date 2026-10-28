extends RefCounted
## Front-end flow. Title/selection use the rounded presentation; other pages retain their layouts.
const Spells=preload("res://scripts/spells.gd")
const Content=preload("res://scripts/run_content.gd")
const Relics=preload("res://scripts/relics.gd")
const Look=preload("res://scripts/mayhem_skin.gd")
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
	var b: Button=Look.button(ui,ui.modal,text,rect,callback,primary,font_size) if ui.modal.get_meta("rounded_ui",false) else ui.button(ui.modal,text,rect,callback,primary,font_size)
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
	open(ui,"title",0)
	Look.backdrop(ui)
	var saved: Dictionary=ui.game.checkpoint_info()
	Look.chip(ui,ui.modal,"방과 후 마법실  ·  LUMI",Rect2(100,94,285,34))
	var logo: Label=Look.text(ui,ui.modal,"마녀들의",Vector2(96,166),69,Look.INK,0,true)
	logo.add_theme_color_override("font_outline_color",Look.PAPER)
	logo.add_theme_constant_override("outline_size",10)
	logo=Look.text(ui,ui.modal,"사고현장!",Vector2(96,235),93,Look.PURPLE,0,true)
	logo.add_theme_color_override("font_outline_color",Look.PAPER)
	logo.add_theme_constant_override("outline_size",12)
	Look.text(ui,ui.modal,"W I T C H L I N G S '   M A Y H E M",Vector2(109,352),14,Look.PURPLE)
	Look.text(ui,ui.modal,"숙제는 조수에게. 사고는 우리에게!",Vector2(107,396),22,Look.INK,0,true)
	ui.portrait(ui.modal,Rect2(718,103,685,685))
	Look.chip(ui,ui.modal,"루미  ·  오늘도 무사히 끝날 리가!",Rect2(884,738,392,42),Look.PAPER,Look.INK)
	var order: Array=[]
	var has_save: bool=not saved.is_empty() and saved.run_id not in ui.game.profile.data.completed_ids
	if has_save:
		action(ui,"Continue","이어하기   ·   %d웨이브 준비  →"%(int(saved.wave)+1),Rect2(105,457,430,70),ui.game.resume_checkpoint,true,26)
		order.append("Continue")
	action(ui,"NewExperiment","새 실험 시작  →" if not has_save else "새로운 실험",Rect2(105,541 if has_save else 463,430,58 if has_save else 78),ui.show_kits,not has_save,25)
	order.append("NewExperiment")
	for i in 3:
		var item: Array=[["Collection","발견 도감","charge"],["Records","실험 기록","expire"],["Settings","설정","giant"]][i]
		var id: String=item[0]
		var rect:=Rect2(105+i*148,638,134,105)
		var button:=action(ui,id,"",rect,func():
			match id:
				"Collection": ui.show_collection("title")
				"Records": ui.show_records()
				"Settings": ui.show_settings(true)
		)
		Look.icon(ui,button,item[2],Rect2(46,10,42,42))
		var label:=Look.text(ui,button,item[1],Vector2(4,65),20,Look.INK,126,true)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		order.append(id)
	action(ui,"Quit","종료  ×",Rect2(1303,44,104,40),func():quit_prompt(ui),false,17)
	order.append("Quit")
	var note: String="준비 시간에 자동 저장돼요."
	if not ui.game.checkpoint_store.warning.is_empty(): note=ui.game.checkpoint_store.warning
	if not ui.game.checkpoint_message.is_empty() and saved.is_empty(): note=ui.game.checkpoint_message
	Look.bounded(Look.text(ui,ui.modal,note,Vector2(108,813),14,Look.MUTED,590),2)
	if not ui.game.profile.warning.is_empty(): Look.bounded(Look.text(ui,ui.modal,ui.game.profile.warning,Vector2(108,851),12,Look.PURPLE,1200))
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
	open(ui,"prepare",0)
	Look.backdrop(ui)
	Look.text(ui,ui.modal,"오늘의 실험",Vector2(88,55),41,Look.INK,0,true)
	Look.text(ui,ui.modal,"마녀와 첫 주문을 골라 주세요.",Vector2(92,109),18,Look.MUTED)
	Look.card(ui,ui.modal,Rect2(86,185,437,530),Color("e5d7ef"),140,0)
	ui.portrait(ui.modal,Rect2(46,183,510,510))
	Look.chip(ui,ui.modal,"LUMI  /  루미",Rect2(168,670,274,45),Look.PAPER,Look.INK)
	Look.text(ui,ui.modal,"멈춤 조건을 빼먹은 건 비밀이야.",Vector2(110,747),21,Look.INK,425,true)
	Look.text(ui,ui.modal,"시작 조합",Vector2(596,145),28,Look.INK,0,true)
	var order: Array=[]
	var i:=0
	for id in g.Economy.KITS:
		var kit: Dictionary=g.Economy.KITS[id]
		var at:=Vector2(596+(i%2)*369,196+int(i/2)*188)
		var selected: bool=ui.setup_kit==id
		var b:=action(ui,"Kit_"+id,"",Rect2(at,Vector2(345,164)),func():ui.setup_kit=id;prepare(ui),selected,18)
		b.tooltip_text=kit.note
		Look.text(ui,b,kit.name,Vector2(20,15),23,Look.PAPER if selected else Look.INK,305,true)
		Look.bounded(Look.text(ui,b,kit.note,Vector2(20,48),14,Color("f2e8ff") if selected else Look.MUTED,300),2)
		for slot in kit.recipe.size():
			Look.icon(ui,b,kit.recipe[slot],Rect2(20+slot*60,96,48,48))
		order.append("Kit_"+id)
		i+=1
	Look.card(ui,ui.modal,Rect2(596,588,714,112),Look.PAPER,24,0)
	Look.text(ui,ui.modal,"함께 받는 구체",Vector2(618,605),17,Look.MUTED,0,true)
	Look.icon(ui,ui.modal,"bolt",Rect2(620,636,36,36))
	Look.icon(ui,ui.modal,"impact",Rect2(664,636,36,36))
	Look.text(ui,ui.modal,"새 주문은 전투와 제작에서 만나봐!",Vector2(729,640),18,Look.INK,540,true)
	var toggle:=CheckButton.new()
	toggle.name="ReplayIntro"
	toggle.text="도입 이야기 보기"
	toggle.position=Vector2(596,723)
	toggle.size=Vector2(300,40)
	toggle.button_pressed=ui.setup_intro
	toggle.add_theme_color_override("font_color",Look.INK)
	toggle.add_theme_font_override("font",Look.FONT)
	toggle.toggled.connect(func(value):ui.setup_intro=value)
	ui.modal.add_child(toggle)
	Look.text(ui,ui.modal,"WASD 이동   ·   Space 회피   ·   공격은 자동",Vector2(596,776),15,Look.MUTED)
	action(ui,"PrepareBack","← 돌아가기",Rect2(88,818,194,46),g.return_title,false,18)
	action(ui,"StartExperiment","실험 시작  →",Rect2(1055,803,255,60),func():start_selected(ui),true,25)
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
