extends CanvasLayer
const Spells = preload("res://scripts/spells.gd")
const Board = preload("res://scripts/prep_board.gd")
const RelicUI = preload("res://scripts/relic_ui.gd")
const RunUI = preload("res://scripts/run_ui.gd")
const INK := Color("171d2b")
const PANEL := Color("202536")
const BORDER := Color("48516b")
const TEXT := Color("f5f0e6")
const MUTED := Color("a9b6c6")
const MINT := Color("a8efe2")
const PINK := Color("ff9cae")
var game: Node2D
var root: Control
var modal: Control
var hud: Control
var recipe_bar: Control
var hp_label: Label
var hp_bar: ProgressBar
var money_label: Label
var shop_clock_label: Label
var time_label: Label
var wave_label: Label
var stats_label: Label
var dash_label: Label
var notice_label: Label
var objective_label: Label
var boss_bar: ProgressBar
var boss_label: Label
var trial_stats_label: Label
var font: SystemFont
var selected_item := ""
var merge_material := ""
var inspected_orb := -1
var inspected_slot := -1
var board_panel := "shop"
var fusion_choice := "storm_spear"
var relic_popup: Control
var relic_resume := false
var relic_strip: HBoxContainer
var shield_label: Label
var relic_revision := ""

func inspect_item(id: String, orb_index := -1, slot := -1) -> void:
	inspected_orb=orb_index
	inspected_slot=slot
	if selected_item!=id: merge_material=""
	selected_item=id
	board_panel="item"
	if orb_index>=0: game.select_orb(orb_index)
	refresh_workbench.call_deferred()

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic","Noto Sans CJK KR","Arial"])
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root.theme = theme
	add_child(root)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	panel(hud,Rect2(22,18,312,81),Color(0.08,0.10,0.16,0.92))
	hp_label = label(hud,"LUMI   ·   100 / 100",Vector2(38,25),18)
	hp_bar = bar(hud,Rect2(38,57,280,8),PINK)
	money_label = label(hud,"0 G",Vector2(235,27),16,MINT)
	shield_label = label(hud,"",Vector2(38,74),13,MINT,270)
	relic_strip = HBoxContainer.new()
	relic_strip.position=Vector2(22,105)
	relic_strip.add_theme_constant_override("separation",3)
	hud.add_child(relic_strip)
	time_label = label(hud,"00:00",Vector2(645,17),32,TEXT,150)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label = label(hud,"실습 1 / 5",Vector2(620,59),16,MINT,200)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label = label(hud,"",Vector2(1100,24),18,TEXT,300)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button(hud,"Esc  잠깐 쉬기",Rect2(1220,60,196,36),func():
		if game.state == "combat":
			game.state = "paused"
			show_pause()
	,false,16)
	notice_label = label(hud,"",Vector2(260,143),19,MINT,920)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label=label(hud,"",Vector2(400,143),16,MUTED,640)
	objective_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = bar(hud,Rect2(470,92,500,8),PINK)
	boss_label = label(hud,"끝없는 모범답안",Vector2(580,104),15,PINK,280)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label = label(hud,"Space  회피 준비",Vector2(34,839),17,MINT)
	label(hud,"WASD 이동  ·  마우스 조준\n자동 시전  ·  M 효과음",Vector2(1180,829),15,MUTED)
	recipe_bar = Control.new()
	recipe_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(recipe_bar)
	rebuild_recipe()
	update_hud()

func box(color: Color, border := BORDER, width := 1, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func panel(parent: Node, rect: Rect2, color := PANEL) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",box(color))
	parent.add_child(p)
	return p

func label(parent: Node, text: String, at: Vector2, size := 20, color := TEXT, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	if width > 0:
		l.size.x = width
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	if width > 0: l.set_deferred("size",Vector2(width,0))
	return l

func button(parent: Node, text: String, rect: Rect2, callback: Callable, accent := false, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",size)
	b.add_theme_color_override("font_color",INK if accent else TEXT)
	b.add_theme_color_override("font_hover_color",INK if accent else MINT)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_focus_color",INK if accent else MINT)
	b.add_theme_color_override("font_disabled_color",MUTED.darkened(0.3))
	b.add_theme_stylebox_override("normal",box(MINT if accent else PANEL,MINT if accent else BORDER))
	b.add_theme_stylebox_override("hover",box(MINT.lightened(0.1) if accent else Color("303a50"),MINT))
	b.add_theme_stylebox_override("pressed",box(MINT.darkened(0.15),MINT))
	b.add_theme_stylebox_override("disabled",box(Color("242735"),Color("343b4e")))
	if rect.size.y<40:
		for style_name in ["normal","hover","pressed","disabled"]:
			var style: StyleBoxFlat=b.get_theme_stylebox(style_name)
			style.content_margin_top=3
			style.content_margin_bottom=3
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = rect.position
	b.size = rect.size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := box(INK,INK,0,4)
	var fill := box(color,color,0,4)
	for style in [background,fill]:
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	b.add_theme_stylebox_override("background",background)
	b.add_theme_stylebox_override("fill",fill)
	b.size = rect.size
	parent.add_child(b)
	# Theme minimum-size invalidation is deferred; otherwise the default 27px height persists.
	b.set_deferred("size",rect.size)
	return b

func update_hud() -> void:
	hp_label.text = "LUMI    %d / %d" % [ceili(game.hp),int(game.max_hp)]
	hp_bar.value = game.hp/game.max_hp*100
	money_label.text = "%d G" % game.economy.gold
	time_label.text = "%02d:%02d" % [floori(game.elapsed/60.0),int(game.elapsed)%60]
	wave_label.text = "%d / 5  ·  %s" % [game.wave,game.RunContent.clock(maxf(0,game.Waves.config(game.wave).duration-game.wave_time))]
	wave_label.tooltip_text=game.RunContent.chapter(game.wave).title+"\n"+game.RunContent.chapter(game.wave).goal
	stats_label.text = "처치 %d  ·  위력 ×%.2f" % [game.kills,game.caster_power()]
	shield_label.text = "보호막 %.0f / 10" % game.relics.shield if game.relics.has("soul_coat") else ""
	refresh_relics()
	dash_label.text = "Space  회피 준비" if game.dash_cooldown <= 0 else "회피 충전  %.1f초" % game.dash_cooldown
	dash_label.modulate.a = 1.0 if game.dash_cooldown <= 0 else 0.6
	notice_label.text = game.notice if game.notice_left > 0 else ""
	objective_label.text = game.RunContent.chapter(game.wave).goal
	objective_label.visible = game.notice_left<=0
	if game.wave==1 and game.wave_time<18: objective_label.text="WASD 이동 · 마우스로 조준 · 자동 발사 · Space로 회피"
	var boss_alive: bool = is_instance_valid(game.boss_ref) and not game.boss_ref.dead
	boss_bar.visible = boss_alive
	boss_label.visible = boss_alive
	if boss_alive: boss_bar.value = game.boss_ref.hp/game.boss_ref.max_hp*100

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rebuild_recipe() -> void:
	clear_children(recipe_bar)
	panel(recipe_bar,Rect2(324,806,792,80),Color(0.08,0.10,0.16,0.96))
	button(recipe_bar,"Tab  마법",Rect2(340,828,120,36),func():
		if game.state=="combat": game.open_editor()
	,false,16)
	for i in 2:
		var parts: Array = game.orb_recipes[i]
		var x:=480+i*308
		var color: Color=MINT if i==0 else PINK
		var orb: Panel=panel(recipe_bar,Rect2(x,824,42,42))
		orb.add_theme_stylebox_override("panel",box(Color("273040"),color,2,24))
		Board.centered(self,orb,str(i+1),Rect2(0,0,42,42),18,color)
		for n in 6:
			var p:=Vector2(x+49+n*39,827)
			panel(recipe_bar,Rect2(p,Vector2(35,36)),INK)
			if n<parts.size():
				var id: String=parts[n]
				var item: Label=Board.centered(self,recipe_bar,Board.glyph(id),Rect2(p,Vector2(35,36)),18,Spells.definition(id).color)
				item.mouse_filter=Control.MOUSE_FILTER_STOP
				item.tooltip_text=Spells.definition(id).name+"\n"+Spells.definition(id).desc

func close_modal() -> void:
	close_relics()
	shop_clock_label = null
	trial_stats_label = null
	if is_instance_valid(modal):
		root.remove_child(modal)
		modal.queue_free()
	modal = null
	hud.visible = true
	update_hud()

func new_modal(rect: Rect2) -> Control:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.035,0.065,0.75)
	shade.size = Vector2(1440,900)
	modal.add_child(shade)
	panel(modal,rect,Color("191e2d"))
	return modal

func portrait(parent: Node, rect: Rect2) -> void:
	var pic := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = game.art
	atlas.region = Rect2(0,0,675,675)
	pic.texture = atlas
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = rect.position
	pic.size = rect.size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)

func show_title() -> void:
	new_modal(Rect2(155,116,1130,668))
	hud.visible = false
	label(modal,"W I T C H L I N G S '   M A Y H E M",Vector2(214,163),17,MINT)
	label(modal,"마녀들의\n사고현장",Vector2(208,208),56,TEXT)
	label(modal,"루미의 실험\n교수님이 돌아오기 전에 사고를 수습하자.",Vector2(214,373),23,MUTED)
	label(modal,"자동으로 쏘고, 마석을 모아 나만의 주문을 만들기.\n전투 → 유물 보상 → 구체 제작대 → 다음 실습",Vector2(214,467),19,TEXT)
	button(modal,"첫 실습 시작    →",Rect2(214,563,350,62),show_kits,true,23)
	button(modal,"실험 기록",Rect2(214,638,170,42),show_records,false,18)
	button(modal,"설정",Rect2(394,638,170,42),func():show_settings(true),false,18)
	label(modal,"WASD 이동   /   마우스 조준   /   자동 시전\nSpace 회피   /   Tab 마법 조합   /   Esc 일시정지",Vector2(214,702),16,MUTED)
	portrait(modal,Rect2(787,177,405,410))
	panel(modal,Rect2(790,602,390,108),Color("252b3e"))
	label(modal,"한 판 · 전투 최대 10분 + 자유 제작",Vector2(812,616),16,MINT)
	label(modal,"수습 성공 %d회  ·  %s" % [game.profile.data.wins,"멈춤 조건의 단서 발견" if game.profile.data.lumi_clue else "아직 밝혀내지 못한 실수"],Vector2(812,650),17,TEXT,340)
	label(modal,"LUMI EXPERIMENT  0.9",Vector2(993,740),13,MUTED)

func show_rewards() -> void:
	RelicUI.rewards(self)

func reward_details(id: String) -> Array:
	var d: Dictionary = game.Relics.definition(id)
	return [d.name,d.desc]

func refresh_relics() -> void:
	if not is_instance_valid(relic_strip): return
	var revision := str(game.relics.owned)
	if revision!=relic_revision:
		relic_revision=revision
		clear_children(relic_strip)
		var open := Button.new()
		open.text="유물 %d"%game.relics.owned.size()
		open.add_theme_font_size_override("font_size",13)
		open.pressed.connect(show_relics)
		relic_strip.add_child(open)
		for id in game.relics.owned:
			var badge := Label.new()
			badge.text=game.Relics.definition(id).glyph
			badge.mouse_filter=Control.MOUSE_FILTER_STOP
			badge.set_meta("relic_id",id)
			badge.add_theme_font_size_override("font_size",13)
			badge.add_theme_color_override("font_color",MINT)
			relic_strip.add_child(badge)
	for badge in relic_strip.get_children():
		if badge.has_meta("relic_id"): badge.tooltip_text=game.relics.tooltip(badge.get_meta("relic_id"),game.economy.gold)

func show_relics() -> void: RelicUI.inventory(self)

func close_relics() -> void:
	if is_instance_valid(relic_popup):
		relic_popup.get_parent().remove_child(relic_popup)
		relic_popup.queue_free()
	relic_popup=null
	if relic_resume and game.state=="paused": game.state="combat"
	relic_resume=false

func refresh_workbench() -> void:
	match game.state:
		"shop": show_shop()
		"edit": show_editor()
		"trial": show_trial()

func show_editor() -> void:
	Board.build(self,false)

func update_shop_clock() -> void:
	pass # Preparation has no countdown.

func show_shop() -> void:
	Board.build(self,true)

func show_trial() -> void:
	Board.trial(self)

func update_trial_stats() -> void:
	if is_instance_valid(trial_stats_label):
		trial_stats_label.text = "피해 %.0f  ·  명중 %d  |  위쪽을 조준하세요 · 두 오브 함께 발사" % [game.trial_damage,game.trial_hits]
		trial_stats_label.tooltip_text = "시험 표적은 반격·드롭 없음. 독립 주문은 0.12초 간격으로 순차 시전. 한 바퀴 후 대기는 가장 느린 주문과 보조 효과를 따른다."

func show_pause() -> void:
	new_modal(Rect2(470,260,500,370))
	label(modal,"잠깐, 숨 고르기",Vector2(515,303),32)
	label(modal,"주문이 복잡해졌다면 Tab으로 정리해봐.\n전투 시간만 진행돼. 제작은 서두르지 않아도 돼.",Vector2(515,371),17,MUTED)
	button(modal,"계속하기",Rect2(515,447,410,55),game.resume_game,true)
	button(modal,"설정",Rect2(515,515,195,45),func():show_settings(false),false,18)
	button(modal,"처음부터 다시",Rect2(720,515,205,45),show_kits,false,18)
	button(modal,"타이틀로",Rect2(515,570,410,40),game.return_title,false,17)

func show_results() -> void:
	RunUI.results(self)

func show_intro() -> void: RunUI.intro(self)
func show_ending() -> void: RunUI.ending(self)
func show_records() -> void: RunUI.records(self)
func show_settings(from_title: bool) -> void: RunUI.settings(self,from_title)

func show_kits() -> void:
	if game.state=="trial": game._clear_trial()
	game.state = "title"
	new_modal(Rect2(120,160,1200,580))
	hud.visible = false
	label(modal,"루미 · 오늘은 어떤 주문으로 시작할까?",Vector2(160,195),30,MINT)
	label(modal,"시작 부품만 달라져. 제작대에서 다른 실험으로 자유롭게 바꿀 수 있어.",Vector2(160,250),18,MUTED)
	var index := 0
	for id in game.Economy.KITS:
		var kit: Dictionary = game.Economy.KITS[id]
		var x := 160+index*285
		panel(modal,Rect2(x,305,265,310),PANEL)
		label(modal,kit.name,Vector2(x+18,327),24,MINT)
		label(modal,kit.note,Vector2(x+18,377),18,TEXT,225)
		label(modal,Spells.describe(kit.recipe),Vector2(x+18,445),16,MUTED,225)
		button(modal,"이 실험으로 시작",Rect2(x+18,550,229,44),func():game.begin_lumi_run(id),true,17)
		index += 1
	label(modal,"공통 지급: 별빛탄 · 명중 후  /  마나 없이 자동 시전  /  마우스 조준",Vector2(160,660),17,MUTED)
