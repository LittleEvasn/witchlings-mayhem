extends CanvasLayer
const Spells = preload("res://scripts/spells.gd")
const Board = preload("res://scripts/prep_board.gd")
const RelicUI = preload("res://scripts/relic_ui.gd")
const RunUI = preload("res://scripts/run_ui.gd")
const FrontFlow = preload("res://scripts/front_flow.gd")
const CollectionUI = preload("res://scripts/collection_ui.gd")
const PersonalWindow = preload("res://scripts/personal_window.gd")
const RewardReveal = preload("res://scripts/reward_reveal.gd")
const LevelRewardUI = preload("res://scripts/level_reward_ui.gd")
const DESIGN_SIZE := Vector2(1440,900)
const INK := Color("171d2b")
const PANEL := Color("202536")
const BORDER := Color("48516b")
const TEXT := Color("f5f0e6")
const MUTED := Color("a9b6c6")
const MINT := Color("a8efe2")
const PINK := Color("ff9cae")
## Assign the purchased GUI Theme here; null deliberately keeps neutral layout scaffolding.
@export var crafting_theme: Theme
var game: Node2D
var root: Control
var health_group: Control
var pause_button: Button
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
var controls_hint: Label
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
var fusion_choice := "shining_spear"
var craft_tab := "craft"
var bag_filter := "all"
var bag_scroll := 0
var catalog_scroll := {}
var relic_popup: Control
var relic_resume := false
var relic_strip: HBoxContainer
var shield_label: Label
var relic_revision := ""
var personal_root: Control
var personal_danger: Label
var spell_reward_button: Button
var reward_receipt: Control
var encounter_hint: Label
var experience_bar: ProgressBar
var experience_label: Label
var front_screen := ""
var setup_kit := "sigil"
var setup_intro := true
var intro_index := 0
var collection_kind := "spell"
var collection_selected := ""
var collection_origin := "title"

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
	# Keep the existing board's measured geometry in a centred safe area.
	# The battlefield fills the wider 16:9 viewport; no non-uniform UI stretch.
	root.anchor_left=0.5
	root.anchor_right=0.5
	root.anchor_bottom=1.0
	root.offset_left=-DESIGN_SIZE.x*.5
	root.offset_right=DESIGN_SIZE.x*.5
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root.theme = theme
	add_child(root)
	get_viewport().size_changed.connect(_on_viewport_resized)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	health_group=Control.new();health_group.name="HealthHUD"
	health_group.mouse_filter=Control.MOUSE_FILTER_IGNORE
	health_group.size=Vector2(340,76);hud.add_child(health_group)
	panel(health_group,Rect2(0,0,340,76),Color(0.08,0.10,0.16,0.92))
	hp_label=label(health_group,"LUMI   ·   100 / 100",Vector2(14,6),16)
	hp_bar=bar(health_group,Rect2(14,31,312,9),PINK)
	money_label=label(health_group,"0 G",Vector2(246,7),15,MINT)
	shield_label=label(health_group,"",Vector2(186,47),11,MINT,140)
	experience_bar=bar(health_group,Rect2(14,46,158,5),MINT)
	experience_label=label(health_group,"Lv.1",Vector2(14,55),11,MINT,300)
	relic_strip = HBoxContainer.new()
	relic_strip.position=Vector2(22,128)
	relic_strip.add_theme_constant_override("separation",3)
	hud.add_child(relic_strip)
	time_label = label(hud,"00:00",Vector2(645,17),32,TEXT,150)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label = label(hud,"실습 1 / 5",Vector2(620,59),16,MINT,200)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label = label(hud,"",Vector2(1100,24),18,TEXT,300)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pause_button=button(hud,"Esc  잠깐 쉬기",Rect2(928,834,200,46),func():
		if game.state == "combat":
			if game.combat_rewards.paused(): return
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
	controls_hint=label(hud,"WASD 이동  ·  가까운 적 조준\n자동 시전  ·  M 효과음",Vector2(1180,829),15,MUTED)
	spell_reward_button=button(hud,"마법 선택",Rect2(22,151,190,38),func():game.open_personal("reward"),true,16)
	spell_reward_button.name="SpellRewardBadge"
	spell_reward_button.focus_mode=Control.FOCUS_NONE
	encounter_hint=label(hud,"",Vector2(480,182),17,Color("ffe7a3"),500)
	encounter_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	recipe_bar = Control.new()
	recipe_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(recipe_bar)
	rebuild_recipe()
	_layout_combat_hud()
	update_hud()

func _on_viewport_resized() -> void:
	_layout_combat_hud()
	if is_instance_valid(modal) and modal.get_meta("combined_reward",false): show_level_reward.call_deferred()
	elif not game.personal_tab.is_empty(): show_personal.call_deferred()
	else: _resize_modal_shade()

func _layout_combat_hud() -> void:
	# All positions start in viewport coordinates, then convert to the centred root.
	var visible:=get_viewport().get_visible_rect().size
	var offset: float=root.position.x
	if game.state not in ["combat","paused"]:
		health_group.position=Vector2(22,18)
		time_label.position=Vector2(645,17);wave_label.position=Vector2(620,59)
		stats_label.position=Vector2(1100,24)
		pause_button.position=Vector2(1220,60)
		relic_strip.position=Vector2(22,128)
		dash_label.position=Vector2(34,839)
		controls_hint.position=Vector2(1180,829)
		boss_bar.position=Vector2(470,92);boss_label.position=Vector2(580,104)
		return
	health_group.position=Vector2(visible.x-360-offset,visible.y-88)
	time_label.position=Vector2(visible.x*.5-100-offset,visible.y-85)
	time_label.size.x=200
	wave_label.position=Vector2(visible.x*.5-100-offset,visible.y-44)
	stats_label.position=Vector2(visible.x-360-offset,visible.y-113)
	stats_label.add_theme_font_size_override("font_size",13)
	pause_button.position=Vector2(visible.x-592-offset,visible.y-66)
	relic_strip.position=Vector2(20-offset,visible.y-88)
	dash_label.position=Vector2(20-offset,visible.y-42)
	controls_hint.position=Vector2(210-offset,visible.y-42)
	controls_hint.text="WASD 이동 · 자동 시전 · Tab 가방"
	controls_hint.add_theme_font_size_override("font_size",13)
	boss_bar.position=Vector2(visible.x*.5-250-offset,82)
	boss_label.position=Vector2(visible.x*.5-140-offset,96)

func _resize_modal_shade() -> void:
	if not is_instance_valid(modal):
		if game!=null and not game.personal_tab.is_empty(): show_personal.call_deferred()
		return
	if modal.get_meta("combined_reward",false):
		# The builder calls this once to size its shade; only viewport signals rebuild.
		var combined_shade:=modal.get_node_or_null("ModalShade") as ColorRect
		if combined_shade!=null:
			combined_shade.position=-root.position
			combined_shade.size=get_viewport().get_visible_rect().size
		return
	if modal.get_meta("craft_drawer",false):
		refresh_workbench.call_deferred()
		return
	var shade := modal.get_node_or_null("ModalShade") as ColorRect
	if not is_instance_valid(shade): return
	# Modal contents use design coordinates; the input-blocking shade covers
	# the complete viewport, including both sides of the centred safe area.
	shade.position=-root.position
	shade.size=get_viewport().get_visible_rect().size

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
	var in_hud: bool=parent==hud or (is_instance_valid(recipe_bar) and (parent==recipe_bar or recipe_bar.is_ancestor_of(parent)))
	b.focus_mode = Control.FOCUS_NONE if game.state=="combat" or in_hud else Control.FOCUS_ALL
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
	_layout_combat_hud()
	if game.combat_rewards!=null:
		experience_bar.value=float(game.combat_rewards.xp)/game.combat_rewards.required()*100
		experience_label.text="Lv.%d · 경험치 %d / %d"%[game.combat_rewards.level,game.combat_rewards.xp,game.combat_rewards.required()]
	hp_label.text = "LUMI    %d / %d" % [ceili(game.hp),int(game.max_hp)]
	hp_bar.value = game.hp/game.max_hp*100
	money_label.text = "%d G" % game.economy.gold
	time_label.text = "%02d:%02d" % [floori(game.elapsed/60.0),int(game.elapsed)%60]
	wave_label.text = "%d / 5  ·  %s" % [game.wave,game.RunContent.clock(maxf(0,game.Waves.config(game.wave).duration-game.wave_time))]
	if game.final_boss_started: wave_label.text="최종 보스 · 처치하면 승리"
	else: wave_label.text="%s까지 · %s"%["최종 보스" if game.wave==5 else "제작 휴식",game.RunContent.clock(maxf(0,360-game.wave_time))]
	wave_label.tooltip_text=game.RunContent.chapter(game.wave).title+"\n"+game.RunContent.chapter(game.wave).goal
	stats_label.text = "처치 %d  ·  위력 ×%.2f" % [game.kills,game.caster_power()]
	shield_label.text = "보호막 %.0f / 10" % game.relics.shield if game.relics.has("soul_coat") else ""
	refresh_relics()
	pause_button.visible=game.state in ["combat","paused"] and not game.combat_rewards.paused()
	stats_label.visible=game.state=="combat" and not game.combat_rewards.paused()
	dash_label.text = "Space  회피 준비" if game.dash_cooldown <= 0 else "회피 충전  %.1f초" % game.dash_cooldown
	dash_label.modulate.a = 1.0 if game.dash_cooldown <= 0 else 0.6
	notice_label.text = game.notice if game.notice_left > 0 else ""
	objective_label.text = game.RunContent.chapter(game.wave).goal
	objective_label.visible = game.notice_left<=0 and not (is_instance_valid(modal) and modal.get_meta("craft_drawer",false))
	if game.wave==1 and game.wave_time<18: objective_label.text="WASD 이동 · 가까운 적 자동 조준 · Space 회피 · Tab 실시간 조합"
	spell_reward_button.visible=false
	spell_reward_button.text="마법 선택 %d"%game.combat_rewards.pending.size()
	spell_reward_button.disabled=game.state not in ["combat","shop"]
	encounter_hint.text=game.encounters.hint()
	if is_instance_valid(personal_danger):
		var obscured:=0
		var view: Rect2=game.visible_world_rect()
		for enemy in game.enemies:
			if is_instance_valid(enemy) and not enemy.dead and view.has_point(enemy.position) and enemy.position.x>view.end.x-432: obscured+=1
		personal_danger.text="창 뒤쪽에 적 %d · 이동과 회피는 계속할 수 있어"%obscured if obscured>0 else ""
	var boss_alive: bool = is_instance_valid(game.boss_ref) and not game.boss_ref.dead
	boss_bar.visible = boss_alive
	boss_label.visible = boss_alive
	if boss_alive: boss_bar.value = game.boss_ref.hp/game.boss_ref.max_hp*100
	if game.state=="combat" and (not game.personal_tab.is_empty() or game.combat_rewards.paused()):
		recipe_bar.visible=false
		relic_strip.visible=true
		dash_label.visible=not game.combat_rewards.paused()
		for hud_label in [notice_label,objective_label,encounter_hint,controls_hint]: hud_label.visible=false

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rebuild_recipe() -> void:
	game.ensure_orb_growth()
	clear_children(recipe_bar)
	var bag:=button(recipe_bar,"Tab  가방",Rect2(20-root.position.x,12,112,34),func():
		if game.state=="combat": game.open_editor()
	,false,16)
	bag.focus_mode=Control.FOCUS_NONE
	for index in game.orb_recipes.size():
		var color: Color=MINT if index==0 else PINK
		var orb:=button(recipe_bar,str(index+1),Rect2(20-root.position.x,58+index*45,40,40),func():
			if game.state=="combat": game.open_editor();game.select_orb(index)
		,false,18)
		orb.name="ClosedOrb%d"%index
		orb.focus_mode=Control.FOCUS_NONE
		orb.add_theme_stylebox_override("normal",box(Color(.06,.08,.13,.9),color,2,24))
		orb.tooltip_text="오브 %d · %s"%[index+1,Spells.describe(game.orb_recipes[index])]

func close_modal() -> void:
	front_screen=""
	game.player.visible=true
	close_reward_receipt()
	game.personal_tab=""
	close_personal_visual()
	close_relics()
	shop_clock_label = null
	trial_stats_label = null
	if is_instance_valid(modal):
		root.remove_child(modal)
		modal.queue_free()
	modal = null
	hud.visible = true
	relic_strip.visible=true
	dash_label.visible=true
	if is_instance_valid(recipe_bar): recipe_bar.visible = true
	for hud_label in [stats_label,notice_label,objective_label,encounter_hint,controls_hint]:
		if is_instance_valid(hud_label): hud_label.visible=true
	update_hud()

func new_modal(rect: Rect2) -> Control:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var shade := ColorRect.new()
	shade.name="ModalShade"
	shade.color = Color(0.025,0.035,0.065,0.75)
	modal.add_child(shade)
	_resize_modal_shade()
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
	FrontFlow.title(self)

func front_back() -> void: FrontFlow.back(self)

func focus_front(reference: WeakRef) -> void:
	var target=reference.get_ref()
	if is_instance_valid(target) and target.is_inside_tree(): target.grab_focus()

func show_rewards() -> void:
	RelicUI.rewards(self)

func show_level_reward() -> void: LevelRewardUI.build(self)

func acquisition_feedback(id: String, placement: Dictionary) -> void:
	if game.state!="shop": return
	close_reward_receipt()
	var popup:=Control.new()
	popup.name="AcquisitionToast"
	popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(popup)
	reward_receipt=popup
	var at:=Vector2(480,310)
	var target: Control=null
	if placement.get("orb",-1)>=0 and is_instance_valid(modal): target=modal.find_child("Socket_%d_%d"%[placement.orb,placement.slot],true,false)
	if target!=null: at=root.get_global_transform().affine_inverse()*target.get_global_rect().get_center()-Vector2(30,30)
	var pic:=LevelRewardUI.Look.icon(self,popup,id,Rect2(at-Vector2(0,55),Vector2(60,60)))
	var text:=LevelRewardUI.Look.text(self,popup,Spells.definition(id).name+" · "+placement.get("text","가방에 보관"),Vector2(330,205),21,MINT,780,true)
	text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var tween:=popup.create_tween()
	tween.tween_property(pic,"position",at,.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(.6)
	tween.tween_property(popup,"modulate:a",0.0,.2)
	tween.tween_callback(popup.queue_free)

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
		open.focus_mode=Control.FOCUS_NONE
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

func show_relics() -> void:
	if game.state=="combat": game.open_personal("relics")
	else: RelicUI.inventory(self)

func close_personal_visual() -> void:
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	if is_instance_valid(personal_root):
		personal_root.get_parent().remove_child(personal_root)
		personal_root.queue_free()
	personal_root=null
	personal_danger=null

func show_personal() -> void:
	if game.personal_tab.is_empty() or not game.state in ["combat","shop"]: return
	if game.personal_tab=="reward": RewardReveal.build(self)
	else: PersonalWindow.build(self)

func close_reward_receipt() -> void:
	if is_instance_valid(reward_receipt):
		reward_receipt.get_parent().remove_child(reward_receipt)
		reward_receipt.queue_free()
	reward_receipt=null

func show_reward_receipt(id: String, experiment: int) -> void:
	if game.state in ["combat","shop"] and experiment==game.combat_rewards.run_serial: RewardReveal.receipt(self,id)

func close_relics() -> void:
	if is_instance_valid(relic_popup):
		relic_popup.get_parent().remove_child(relic_popup)
		relic_popup.queue_free()
	relic_popup=null
	if relic_resume and game.state=="paused": game.state="combat"
	relic_resume=false

func refresh_workbench() -> void:
	if game.state=="combat" and game.combat_rewards.paused():
		show_level_reward()
		return
	if game.state=="combat" and not game.personal_tab.is_empty():
		show_personal()
		return
	match game.state:
		"shop": show_shop()
		"edit": show_editor()
		"trial": show_trial()

func show_editor() -> void:
	if game.state=="combat": show_personal()
	else: Board.build(self,false)

func update_shop_clock() -> void:
	pass # Preparation has no countdown.

func show_shop() -> void:
	if game.state=="shop": game.save_checkpoint()
	Board.build(self,true)

func show_collection(origin := "title") -> void:
	if not game.state in ["title","shop"]: return
	collection_origin=origin
	CollectionUI.build(self)

func close_collection() -> void:
	if collection_origin=="shop" and game.state=="shop": show_shop()
	else: game.return_title()

func show_trial() -> void:
	if game.training_mode: preload("res://scripts/training_room.gd").build(self)
	else: Board.trial(self)

func update_trial_stats() -> void:
	if is_instance_valid(trial_stats_label):
		trial_stats_label.text = "피해 %.0f  ·  명중 %d  |  가까운 순서대로 오브 자동 조준" % [game.trial_damage,game.trial_hits]
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
	if game.state!="title": game.return_title()
	setup_kit=game.selected_kit
	setup_intro=not game.profile.data.intro_seen
	FrontFlow.prepare(self)
