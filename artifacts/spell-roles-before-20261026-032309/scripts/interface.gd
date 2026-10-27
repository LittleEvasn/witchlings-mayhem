extends CanvasLayer
const Spells = preload("res://scripts/spells.gd")
const Board = preload("res://scripts/prep_board.gd")
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
	notice_label = label(hud,"",Vector2(260,119),19,MINT,920)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = bar(hud,Rect2(470,92,500,8),PINK)
	boss_label = label(hud,"균열의 수호자",Vector2(580,104),15,PINK,280)
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
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",size)
	b.add_theme_color_override("font_color",INK if accent else TEXT)
	b.add_theme_color_override("font_hover_color",INK if accent else MINT)
	b.add_theme_color_override("font_pressed_color",INK)
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
	wave_label.text = "실습 %d / 5  ·  %d초" % [game.wave,ceili(maxf(0,game.Waves.config(game.wave).duration-game.wave_time))]
	stats_label.text = "처치 %d  ·  위력 ×%.2f" % [game.kills,game.power]
	dash_label.text = "Space  회피 준비" if game.dash_cooldown <= 0 else "회피 충전  %.1f초" % game.dash_cooldown
	dash_label.modulate.a = 1.0 if game.dash_cooldown <= 0 else 0.6
	notice_label.text = game.notice if game.notice_left > 0 else ""
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
	label(modal,"교수님이 돌아오기 전에,\n우리가 연 균열부터 닫자.",Vector2(214,373),24,MUTED)
	label(modal,"자동으로 쏘고, 돈을 모아 나만의 주문을 만들기.\n전투 → 패시브 보상 → 구체 상점 → 다음 실습",Vector2(214,467),19,TEXT)
	button(modal,"첫 실습 시작    →",Rect2(214,563,350,62),show_kits,true,23)
	button(modal,"마법 측정실",Rect2(214,638,350,42),func():get_tree().change_scene_to_file("res://scenes/measurement_lab.tscn"),false,18)
	label(modal,"WASD 이동   /   마우스 조준   /   자동 시전\nSpace 회피   /   Tab 마법 조합   /   Esc 일시정지",Vector2(214,702),16,MUTED)
	portrait(modal,Rect2(787,177,405,410))
	panel(modal,Rect2(790,602,390,108),Color("252b3e"))
	label(modal,"오늘의 사고 공식",Vector2(812,616),16,MINT)
	label(modal,"접목 · 응축 · 각인 · 냉기 / 파쇄",Vector2(812,650),20,TEXT)
	label(modal,"MAGIC EXPERIMENTS  0.8",Vector2(993,740),13,MUTED)

func show_rewards() -> void:
	new_modal(Rect2(170,170,1100,550))
	label(modal,"실습 %d 완료" % game.wave,Vector2(220,209),34,TEXT)
	label(modal,"흩어진 돈 회수 + 완료 보너스 20 G · 체력 +15 · 무료 패시브 하나를 골라줘.",Vector2(220,269),19,MUTED)
	for i in game.reward_options.size():
		var id: String = game.reward_options[i]
		var details := reward_details(id)
		var x: int = 220+i*340
		panel(modal,Rect2(x,330,320,280),Color("252b3e"))
		label(modal,details[0],Vector2(x+24,355),25,MINT)
		label(modal,details[1],Vector2(x+24,411),19,TEXT,270)
		button(modal,"선택하고 상점으로",Rect2(x+24,536,272,48),func():game.choose_reward(id),true,18)
	label(modal,"선택 후 상점에서 준비하세요. 준비 완료를 누르면 다음 실습이 시작돼요.",Vector2(220,654),17,MUTED)

func reward_details(id: String) -> Array:
	match id:
		"power": return ["위험한 자신감","모든 공격의 기본 위력 +25%.\n이미 가진 부품도 강해져."]
		"haste": return ["빨리 말하기","자동 시전 속도 +18%.\n더 자주, 더 많은 사고를."]
		_: return ["따뜻한 차 한 잔","최대 체력 +25, 체력 +40.\n마지막 실습을 위한 여유."]

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
	label(modal,"주문이 복잡해졌다면 Tab으로 정리해봐.\n효과음은 M으로 켜고 끌 수 있어.",Vector2(515,371),18,MUTED)
	button(modal,"계속하기",Rect2(515,447,410,55),game.resume_game,true)
	button(modal,"처음부터 다시",Rect2(515,523,410,48),show_kits,false,18)

func show_results() -> void:
	new_modal(Rect2(380,190,680,520))
	label(modal,"사고 수습 완료!" if game.result_win else "이번 실습은 여기까지",Vector2(432,232),36,MINT if game.result_win else PINK)
	label(modal,"교수님은 아직 아무것도 몰라." if game.result_win else "조합을 바꾸면 다음 판은 달라질 거야.",Vector2(432,293),20,MUTED)
	label(modal,"생존 %02d:%02d    ·    처치 %d    ·    획득 %d G" % [floori(game.elapsed/60.0),int(game.elapsed)%60,game.kills,game.economy.total_earned],Vector2(432,364),22,TEXT)
	label(modal,"이번 주문\n"+Spells.describe(game.orb_recipes[0])+"\n"+(Spells.describe(game.orb_recipes[1]) if not game.orb_recipes[1].is_empty() else "오브 2 · 비어 있음"),Vector2(432,421),18,MINT,570)
	button(modal,"다른 조합으로 한 판 더    →",Rect2(432,555,576,64),show_kits,true,22)
	label(modal,"다시 시작하면 돈·구체·패시브 보상도 초기화돼.",Vector2(432,650),16,MUTED)

func show_kits() -> void:
	if game.state=="trial": game._clear_trial()
	game.state = "title"
	new_modal(Rect2(120,160,1200,580))
	hud.visible = false
	label(modal,"오늘은 어떤 사고를 낼까?",Vector2(160,195),32,MINT)
	label(modal,"시작 부품만 달라져. 상점에서 다른 실험으로 자유롭게 바꿀 수 있어.",Vector2(160,250),18,MUTED)
	var index := 0
	for id in game.Economy.KITS:
		var kit: Dictionary = game.Economy.KITS[id]
		var x := 160+index*285
		panel(modal,Rect2(x,305,265,310),PANEL)
		label(modal,kit.name,Vector2(x+18,327),24,MINT)
		label(modal,kit.note,Vector2(x+18,377),18,TEXT,225)
		label(modal,Spells.describe(kit.recipe),Vector2(x+18,445),16,MUTED,225)
		button(modal,"이 실험으로 시작",Rect2(x+18,550,229,44),func():game.start_run(id),true,17)
		index += 1
	label(modal,"공통 지급: 별빛탄 · 명중 후  /  마나 없이 자동 시전  /  마우스 조준",Vector2(160,660),17,MUTED)
