extends RefCounted
const Look=preload("res://scripts/mayhem_skin.gd")
const View=preload("res://scripts/acquisition_view.gd")
const Gate=preload("res://scripts/reward_input_gate.gd")

static func build(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	var r: RefCounted=g.combat_rewards
	if g.state!="combat" or not r.paused(): return
	ui.close_modal()
	var root:=Control.new()
	root.name="LevelRewardScreen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_STOP
	ui.root.add_child(root)
	ui.modal=root
	ui.recipe_bar.visible=false
	for l in [ui.notice_label,ui.objective_label,ui.encounter_hint,ui.controls_hint]: l.visible=false
	var shade:=ColorRect.new()
	shade.name="ModalShade"
	shade.color=Color(.03,.02,.08,.42)
	root.add_child(shade)
	ui._resize_modal_shade()
	var gate:=Gate.new()
	gate.name="RewardInputGate"
	root.add_child(gate)
	var first: Dictionary=r.pending[0] if not r.pending.is_empty() else {}
	var chest: bool=first.get("source","")=="chest"
	var title: String="상자 보상" if chest else "레벨 %d!"%int(first.get("level",r.level))
	var heading:=Look.text(ui,root,title,Vector2(200,110),38,Look.PAPER,1040,true)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	Look.chip(ui,root,"전투 정지 · 보상 자동 획득" if chest else "전투 정지 · 안심하고 골라요",Rect2(565,166,310,32),Look.LILAC)
	if r.stage in ["chest","opening"]:
		Look.card(ui,root,Rect2(460,255,520,360),Look.PAPER,36)
		var seal:=Look.icon(ui,root,"charge",Rect2(650,286,140,140))
		var text:=Look.text(ui,root,"상자 속 재료를 확인해볼까?" if r.stage=="chest" else "봉인이 열리고 있어요…",Vector2(490,450),26,Look.INK,460,true)
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if r.stage=="chest":
			var b:=Look.button(ui,root,"열기",Rect2(575,534,290,52),func():
				if gate.allow(): r.open_chest()
			,true,24)
			b.name="OpenRewardChest"
			gate.guard(b)
			gate.preferred=b
		else:
			var receipt_id: String=first.id
			seal.pivot_offset=Vector2(70,70)
			seal.create_tween().tween_property(seal,"scale",Vector2(1.15,1.15),.65).set_trans(Tween.TRANS_SINE)
			var tween:=root.create_tween()
			tween.tween_interval(.8)
			tween.tween_callback(func():r.reveal_chest(receipt_id))
		return
	if first.is_empty(): return
	var revision: int=r.revision
	var row:=HBoxContainer.new()
	row.name="LevelChoices"
	row.position=Vector2(200,222)
	row.size=Vector2(1040,440)
	row.add_theme_constant_override("separation",18)
	root.add_child(row)
	for id in first.options:
		var model:=View.model(g,id,first.get("source","level"),r.bag_only)
		var card:=View.card(ui,row,model,Vector2(0,440),func():
			if gate.allow(): g.claim_spell_reward(first.id,id,revision)
		,"Choose_"+str(id).replace(":","_"))
		var b: Button=card.find_child("Choose_*",true,false)
		card.mouse_entered.connect(func():highlight(ui,model.get("placement",{})))
		b.focus_entered.connect(func():highlight(ui,model.get("placement",{})))
		gate.guard(b)
		if row.get_child_count()==1: gate.preferred=b
		card.modulate.a=0
		card.create_tween().tween_property(card,"modulate:a",1.0,.18)
	if first.options.any(func(id):return str(id).begins_with("fuse:")):
		var bag:=CheckButton.new()
		bag.name="RewardBagOnly"
		bag.text="합성 결과는 가방에만"
		bag.position=Vector2(200,682)
		bag.button_pressed=r.bag_only
		bag.add_theme_font_size_override("font_size",18)
		root.add_child(bag)
		bag.toggled.connect(func(value):r.bag_only=value;ui.show_level_reward())
	else: Look.text(ui,root,"새 마법은 가방에 보관 · 직접 장착",Vector2(200,689),17,Look.PAPER,520)
	Look.text(ui,root,"← → 선택 · 클릭/Enter 확정 · 남은 보상 %d"%r.pending.size(),Vector2(750,689),17,Look.PAPER,490)
	orb_strip(ui,root)

static func orb_strip(ui: CanvasLayer, parent: Node) -> void:
	var g: Node2D=ui.game
	var row:=HBoxContainer.new()
	row.name="RewardOrbSummary"
	row.position=Vector2(200,747)
	row.size=Vector2(1040,76)
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	for orb in g.orb_drafts.size():
		var tray:=PanelContainer.new()
		tray.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tray.add_theme_stylebox_override("panel",Look.style(Color("2b2340"),Look.PURPLE,18))
		row.add_child(tray)
		var column:=VBoxContainer.new()
		tray.add_child(column)
		View.label(ui,column,"오브 %d  +%d · %d칸"%[orb+1,g.orb_growth[orb].rank,g.orb_capacity(orb)],15,Look.PAPER)
		var glyphs:=HBoxContainer.new()
		column.add_child(glyphs)
		for slot in g.orb_drafts[orb].size():
			var id: String=g.orb_drafts[orb][slot]
			var text:=View.label(ui,glyphs,"·" if id=="" else ui.Board.glyph(id),17,Look.MINT)
			text.name="RewardSlot_%d_%d"%[orb,slot]
			text.set_meta("original",text.text)
			text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			text.tooltip_text="빈칸" if id=="" else g.Spells.definition(id).name

static func highlight(ui: CanvasLayer, placement: Dictionary) -> void:
	if not is_instance_valid(ui.modal): return
	var target: String="RewardSlot_%d_%d"%[placement.get("orb",-1),placement.get("slot",-1)]
	for l in ui.modal.find_children("RewardSlot_*","Label",true,false):
		l.text=("＋" if l.get_meta("original")=="·" else l.get_meta("original")) if str(l.name)==target else l.get_meta("original")
		l.add_theme_color_override("font_color",Look.PINK if str(l.name)==target else Look.MINT)
		l.add_theme_font_size_override("font_size",22 if str(l.name)==target else 17)
