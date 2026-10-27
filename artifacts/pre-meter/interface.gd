extends CanvasLayer
const OrbControl = preload("res://scripts/orb_control.gd")
const Spells = preload("res://scripts/spells.gd")
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
	label(recipe_bar,"현재 주문",Vector2(342,817),14,MUTED)
	button(recipe_bar,"Tab  조합",Rect2(342,843,116,31),func():
		if game.state == "combat": game.open_editor()
	,false,15)
	for i in 6:
		var rect := Rect2(475+i*103,818,94,56)
		if i < game.recipe.size():
			var id: String = game.recipe[i]
			var part: Dictionary = Spells.PARTS[id]
			var p := panel(recipe_bar,rect,Color("2b3145"))
			p.add_theme_stylebox_override("panel",box(Color("2b3145"),part.color,1,8))
			label(recipe_bar,str(i+1),rect.position+Vector2(8,3),12,MUTED)
			var l := label(recipe_bar,part.get("hud_name",part.name),rect.position+Vector2(6,18),14,part.color,82)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			panel(recipe_bar,rect,Color("1b2030"))
			label(recipe_bar,"·",rect.position+Vector2(42,12),22,BORDER)

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
	button(modal,"첫 실습 시작    →",Rect2(214,563,350,62),game.start_run,true,23)
	label(modal,"WASD 이동   /   마우스 조준   /   자동 시전\nSpace 회피   /   Tab 마법 조합   /   Esc 일시정지",Vector2(214,659),16,MUTED)
	portrait(modal,Rect2(787,177,405,410))
	panel(modal,Rect2(790,602,390,108),Color("252b3e"))
	label(modal,"오늘의 사고 공식",Vector2(812,616),16,MINT)
	label(modal,"별빛탄  →  명중 후  →  꽃폭탄",Vector2(812,650),20,TEXT)
	label(modal,"SOLO PROTOTYPE  0.5",Vector2(993,740),13,MUTED)

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
	label(modal,"선택을 마치면 60초 상점 시간이 시작돼. 지금은 여유롭게 골라도 좋아.",Vector2(220,654),17,MUTED)

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

func orb(parent: Node, rect: Rect2, id: String, slot: int, inventory: bool, text: String) -> Control:
	var c := OrbControl.new()
	c.workbench = self
	c.orb_id = id
	c.slot = slot
	c.inventory = inventory
	c.position = rect.position
	c.size = rect.size
	var color: Color = BORDER if id.is_empty() else Spells.PARTS[id].color
	var available: bool = not inventory or game.economy.remaining(id,game.draft) > 0
	c.background = box(Color("252b3e") if available else INK,color if available else BORDER,1,9)
	if inventory and id == game.purchased_orb:
		c.background.border_color = MINT
		c.background.set_border_width_all(2)
	if not id.is_empty(): c.tooltip_text = Spells.PARTS[id].desc
	parent.add_child(c)
	var l := Label.new()
	l.text = text
	l.position = Vector2(4,2)
	l.size = rect.size-Vector2(8,4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",16)
	l.add_theme_color_override("font_color",color if available else MUTED.darkened(0.3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	return c

func recipe_controls(parent: Node, at: Vector2, inventory_y: float, compact := false) -> void:
	label(parent,"편집 중인 주문 · 끌어서 사이에 삽입 / 클릭·우클릭으로 해제",at,15,MUTED)
	var height := 56.0 if compact else 66.0
	var result := Spells.compile(game.draft)
	for i in 6:
		var id: String = game.draft[i] if i < game.draft.size() else ""
		var title := "%02d  ·  빈 칸" % (i+1) if id.is_empty() else "%02d  %s" % [i+1,Spells.PARTS[id].get("hud_name",Spells.PARTS[id].name)]
		var cell := orb(parent,Rect2(at.x+i*190,at.y+28,178,height),id,i,false,title)
		if i == result.get("error_index",-1):
			cell.background.border_color = PINK
			cell.background.set_border_width_all(3)
			cell.tooltip_text = result.error
			cell.queue_redraw()
	var message: String = Spells.describe(game.draft)
	if result.ok: message = ("적용됨 · " if game.draft == game.recipe else "미적용 · ")+message
	var status := label(parent,message,Vector2(at.x,at.y+height+34),15,MINT if result.ok else PINK,1128)
	status.max_lines_visible = 1
	status.tooltip_text = message
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label(parent,"보유 구체 · 남은 수 / 전체 수 · 장착 구체를 이곳에 놓으면 해제",Vector2(at.x,inventory_y-27),14,MUTED)
	var index := 0
	for id in Spells.PARTS:
		var part: Dictionary = Spells.PARTS[id]
		var total: int = game.economy.inventory.get(id,0)
		var left: int = game.economy.remaining(id,game.draft)
		var text := "%s   %d/%d" % [part.get("hud_name",part.name),left,total] if compact else "%s\n남음 %d / 전체 %d" % [part.name,left,total]
		orb(parent,Rect2(at.x+(index%6)*190,inventory_y+int(index/6)*(51 if compact else 70),178,44 if compact else 62),id,-1,true,text)
		index += 1

func edit_actions(parent: Node, y: float, trial := false) -> void:
	var undo := button(parent,"되돌리기",Rect2(150,y,126,40),game.undo_draft,false,16)
	undo.disabled = game.edit_history.is_empty()
	button(parent,"기존 주문",Rect2(286,y,126,40),game.reset_draft,false,16)
	button(parent,"추천",Rect2(422,y,95,40),game.recommend_recipe,false,16)
	var confirm := button(parent,"주문 적용",Rect2(850,y,180,40),game.apply_recipe,true,18)
	confirm.disabled = not game.valid_draft() or game.draft == game.recipe
	if trial:
		button(parent,"상점으로 · Esc",Rect2(1040,y,238,40),game.end_trial,false,18)
	else:
		var test := button(parent,"시험 발사",Rect2(640,y,196,40),game.start_trial,false,18)
		test.disabled = not game.valid_draft()

func show_editor() -> void:
	new_modal(Rect2(110,110,1220,680))
	label(modal,"나만의 사고 공식",Vector2(150,140),30,TEXT)
	label(modal,"보조 → 공격 → 명중 후 → 보조 → 공격 · 순서를 바꾸는 중에는 불완전해도 괜찮아.",Vector2(150,192),17,MUTED)
	recipe_controls(modal,Vector2(150,245),445)
	var undo := button(modal,"되돌리기",Rect2(150,646,150,44),game.undo_draft,false,17)
	undo.disabled = game.edit_history.is_empty()
	button(modal,"추천 조합",Rect2(316,646,150,44),game.recommend_recipe,false,17)
	button(modal,"기존 주문 유지 · Esc",Rect2(150,718,285,44),game.cancel_editor,false,18)
	var confirm := button(modal,"적용하고 계속 · Tab",Rect2(940,718,338,44),game.apply_recipe,true,20)
	confirm.disabled = not game.valid_draft()

func update_shop_clock() -> void:
	if is_instance_valid(shop_clock_label):
		shop_clock_label.text = "다음 실습까지 %02d초" % ceili(game.shop_time)
		shop_clock_label.add_theme_color_override("font_color",PINK if game.shop_time <= 10 else MINT)

func show_shop() -> void:
	new_modal(Rect2(110,100,1220,718))
	label(modal,"사고 준비 상점",Vector2(150,119),30,TEXT)
	label(modal,"보유 %d G" % game.economy.gold,Vector2(825,131),22,MINT)
	shop_clock_label = label(modal,"",Vector2(1040,135),17,MINT,238)
	shop_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	update_shop_clock()
	var forecast := label(modal,game.Waves.forecast(game.wave+1),Vector2(150,159),14,MINT,1128)
	forecast.name = "WaveForecast"
	forecast.max_lines_visible = 1
	forecast.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	forecast.tooltip_text = forecast.text
	var revision: int = game.economy.revision
	for i in game.economy.offers.size():
		var offer: Dictionary = game.economy.offers[i]
		var part: Dictionary = Spells.PARTS[offer.id]
		var x: int = 150+i*285
		var card := panel(modal,Rect2(x,182,273,170),Color("252b3e"))
		card.add_theme_stylebox_override("panel",box(Color("252b3e"),part.color,1,10))
		label(modal,part.name,Vector2(x+14,194),21,part.color)
		var description := label(modal,part.desc,Vector2(x+14,233),14,TEXT,245)
		description.max_lines_visible = 3
		var buy := button(modal,"판매 완료" if offer.sold else "%d G · 구입" % offer.price,Rect2(x+14,306,245,34),func():game.buy_orb(i,revision),not offer.sold,16)
		buy.disabled = offer.sold or game.economy.gold < offer.price
	var reroll := button(modal,"새 상품 · 5 G",Rect2(150,362,170,34),func():game.reroll_shop(revision),false,16)
	reroll.disabled = game.economy.gold < game.Economy.REROLL_COST
	label(modal,game.shop_message,Vector2(338,368),14,MUTED,940)
	recipe_controls(modal,Vector2(150,411),557)
	edit_actions(modal,704)
	label(modal,"시간 종료: 마지막 적용 주문으로 출발 · 시험 중에는 시간 정지",Vector2(150,774),14,MUTED)
	var launch := button(modal,"적용하고 다음 웨이브 →",Rect2(940,762,338,40),game.launch_next_wave,true,18)
	launch.disabled = not game.valid_draft()

func show_trial() -> void:
	close_modal()
	hud.visible = false
	modal = Control.new()
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal)
	panel(modal,Rect2(110,18,1220,83),Color(0.08,0.10,0.16,0.96))
	label(modal,"주문 시험 · 위쪽 경기장을 마우스로 조준",Vector2(150,30),23,MINT)
	trial_stats_label = label(modal,"",Vector2(150,65),16,TEXT,1100)
	panel(modal,Rect2(110,535,1220,350),Color(0.08,0.10,0.16,0.98))
	recipe_controls(modal,Vector2(150,550),697,true)
	edit_actions(modal,827,true)
	update_trial_stats()

func update_trial_stats() -> void:
	if is_instance_valid(trial_stats_label):
		trial_stats_label.text = "준비 시간 정지 · 시험 표적은 반격·드롭 없음 · 누적 피해 %.0f / 명중 %d · 편집 즉시 시험에 반영" % [game.trial_damage,game.trial_hits]

func show_pause() -> void:
	new_modal(Rect2(470,260,500,370))
	label(modal,"잠깐, 숨 고르기",Vector2(515,303),32)
	label(modal,"주문이 복잡해졌다면 Tab으로 정리해봐.\n효과음은 M으로 켜고 끌 수 있어.",Vector2(515,371),18,MUTED)
	button(modal,"계속하기",Rect2(515,447,410,55),game.resume_game,true)
	button(modal,"처음부터 다시",Rect2(515,523,410,48),game.start_run,false,18)

func show_results() -> void:
	new_modal(Rect2(380,190,680,520))
	label(modal,"사고 수습 완료!" if game.result_win else "이번 실습은 여기까지",Vector2(432,232),36,MINT if game.result_win else PINK)
	label(modal,"교수님은 아직 아무것도 몰라." if game.result_win else "조합을 바꾸면 다음 판은 달라질 거야.",Vector2(432,293),20,MUTED)
	label(modal,"생존 %02d:%02d    ·    처치 %d    ·    획득 %d G" % [floori(game.elapsed/60.0),int(game.elapsed)%60,game.kills,game.economy.total_earned],Vector2(432,364),22,TEXT)
	label(modal,"이번 주문\n"+Spells.describe(game.recipe),Vector2(432,421),18,MINT,570)
	button(modal,"다른 조합으로 한 판 더    →",Rect2(432,555,576,64),game.start_run,true,22)
	label(modal,"다시 시작하면 돈·구체·패시브 보상도 초기화돼.",Vector2(432,650),16,MUTED)
