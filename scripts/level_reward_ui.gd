extends RefCounted
const Look=preload("res://scripts/mayhem_skin.gd")
const View=preload("res://scripts/acquisition_view.gd")
const Gate=preload("res://scripts/reward_input_gate.gd")
const Inventory=preload("res://scripts/compact_inventory.gd")

static func build(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	var r: RefCounted=g.combat_rewards
	if g.state!="combat" or not r.paused(): return
	if r.stage=="choice": r.refresh_options()
	ui.close_modal()
	var root:=Control.new()
	root.name="LevelRewardScreen"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_STOP
	root.set_meta("combined_reward",true)
	ui.root.add_child(root);ui.modal=root
	var shade:=ColorRect.new()
	shade.name="ModalShade";shade.color=Color(.025,.025,.055,.24)
	root.add_child(shade);ui._resize_modal_shade()
	g.personal_tab="inventory"
	ui.personal_root=Inventory.build(ui,root,true)
	ui.update_hud()
	var gate:=Gate.new();gate.name="RewardInputGate";root.add_child(gate)
	var first: Dictionary=r.pending[0] if not r.pending.is_empty() else {}
	var height: float=ui.get_viewport().get_visible_rect().size.y
	var count: int=first.get("options",[]).size() if r.stage=="choice" else 3
	var width: float=count*280+(count-1)*16
	var left: float=(ui.get_viewport().get_visible_rect().size.x-width)*.5-ui.root.position.x
	var top: float=350
	var title: String="조합 정리 · 준비되면 전투 재개"
	if r.stage=="choice": title="레벨 %d · 하나를 골라요"%int(first.get("level",r.level))
	elif r.stage in ["chest","opening"]: title="보상 상자 · 1 / 3 / 5개 자동 획득"
	var heading:=Look.text(ui,root,title,Vector2(left,top),24,Look.PAPER,width,true)
	heading.name="RewardHeading"
	if r.stage=="choice":
		var revision: int=r.revision
		var row:=HBoxContainer.new();row.name="LevelChoices"
		row.position=Vector2(left,top+34);row.size=Vector2(width,398)
		row.add_theme_constant_override("separation",16);root.add_child(row)
		for id in first.options:
			var model:=View.model(g,id,"level")
			var card:=reward_card(ui,row,model,func():
				if gate.allow(): g.claim_spell_reward(first.id,id,revision)
			)
			var b: Button=card.find_child("Choose_*",true,false)
			card.mouse_entered.connect(func():highlight(ui,model))
			card.mouse_exited.connect(func():highlight(ui,{}))
			gate.guard(b)
			if row.get_child_count()==1: gate.preferred=b
	elif r.stage in ["chest","opening"]:
		var panel:=Look.card(ui,root,Rect2(left,top+36,width,132),Look.PAPER,24)
		Look.icon(ui,panel,"charge",Rect2(24,20,72,72))
		Look.text(ui,panel,"상자 보상은 자동으로 받아요." if r.stage=="chest" else "봉인이 열리고 있어요…",Vector2(118,25),23,Look.INK,width-420,true)
		Look.text(ui,panel,"받은 뒤에도 위쪽 가방과 오브를 계속 편집할 수 있어요.",Vector2(118,66),16,Look.MUTED,width-340)
		if r.stage=="chest":
			var b:=Look.button(ui,panel,"열기",Rect2(width-220,38,190,48),func():
				if gate.allow(): r.open_chest()
			,true,22)
			b.name="OpenRewardChest";gate.guard(b);gate.preferred=b
		else:
			var id: String=first.id
			var tween:=root.create_tween();tween.tween_interval(.8)
			tween.tween_callback(func():r.reveal_chest(id))
	else:
		# The card row folds away after a pick; this is still the same editable session.
		var results: Array=r.last_chest_results
		if results.is_empty(): results=[{"id":r.view.get("id",""),"output":r.view.get("output",""),"text":r.receipt}]
		var row:=HBoxContainer.new();row.name="RewardResults"
		row.position=Vector2(left,top+43);row.size=Vector2(minf(width,results.size()*196),72)
		row.add_theme_constant_override("separation",8);root.add_child(row)
		for result in results:
			var card:=PanelContainer.new();card.custom_minimum_size=Vector2(0,68)
			card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			card.add_theme_stylebox_override("panel",Look.style(Color(.055,.065,.105,.92),Look.PURPLE,18))
			row.add_child(card)
			var inside:=HBoxContainer.new();inside.add_theme_constant_override("separation",8);card.add_child(inside)
			var output: String=result.get("output","")
			if g.Spells.has_part(output):
				var icon:=Control.new();icon.custom_minimum_size=Vector2(48,48);inside.add_child(icon)
				Look.icon(ui,icon,output,Rect2(0,0,48,48))
			var l:=View.label(ui,inside,result.text,16,Look.PAPER)
			l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;l.max_lines_visible=2;l.tooltip_text=result.text
		Look.text(ui,root,"원하는 위치에 배치한 뒤 전투를 재개하세요.",Vector2(left,top+137),16,Look.PAPER,width-280)
	var resume:=Look.button(ui,root,"전투 재개 →",Rect2(ui.get_viewport().get_visible_rect().size.x-592-ui.root.position.x,height-66,200,46),func():
		if gate.allow(): r.continue_combat()
	,true,22)
	resume.name="ResumeRewardCombat"
	if r.stage=="edit" and r.pending.is_empty(): gate.guard(resume);gate.preferred=resume
	else: resume.disabled=true;resume.tooltip_text="남은 보상을 먼저 받아주세요."
	if not r.pending.is_empty(): Look.text(ui,root,"남은 보상 %d · 전투 정지"%r.pending.size(),Vector2(ui.get_viewport().get_visible_rect().size.x-592-ui.root.position.x,height-94),14,Look.PAPER,200)

static func reward_card(ui: CanvasLayer, parent: Node, model: Dictionary, action: Callable) -> Control:
	# Restore the tall card silhouette: a large icon, readable change and a fixed CTA.
	var card:=Panel.new();card.name="AcquisitionCard_"+str(model.id).replace(":","_")
	card.custom_minimum_size=Vector2(280,398)
	var color: Color=View.COLOR.get(model.role,Look.LINE)
	card.add_theme_stylebox_override("panel",View.card_style(color,false))
	card.tooltip_text=model.compare+"\n"+model.detail
	parent.add_child(card)
	var badge:=Look.text(ui,card,model.badge,Vector2(16,14),14,Look.PURPLE,248,true)
	badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.name="RewardKind"
	if not model.get("icon","").is_empty(): Look.icon(ui,card,model.icon,Rect2(96,38,88,88))
	else:
		var emblem:=Look.text(ui,card,model.get("glyph","✦"),Vector2(16,38),62,Look.PURPLE,248,true)
		emblem.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var title:=Look.text(ui,card,str(model.title).trim_suffix(" ✧"),Vector2(16,136),24,Look.INK,248,true)
	title.name="RewardName";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.max_lines_visible=2;title.clip_text=true;title.set_deferred("size",Vector2(248,60))
	var desc:=Look.text(ui,card,model.change,Vector2(18,204),20,Look.INK,244,true)
	desc.name="RewardChange";desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;desc.max_lines_visible=3;desc.clip_text=true;desc.set_deferred("size",Vector2(244,72))
	if model.type=="fusion": desc.text=str(model.change).split("\n")[0]
	var comparison: String=model.compare
	if model.type=="fusion": comparison="소비: "+str(model.compare).trim_suffix(" → 완성")
	var compare:=Look.text(ui,card,comparison,Vector2(18,282),14,Look.MUTED,244)
	compare.name="RewardCompare";compare.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;compare.max_lines_visible=2;compare.clip_text=true;compare.set_deferred("size",Vector2(244,42))
	compare.tooltip_text=model.compare+"\n"+model.get("placement",{}).get("text","")
	var b:=Look.button(ui,card,"합성하기" if model.type=="fusion" else "선택",Rect2(16,338,248,44),action,true,20)
	b.name="Choose_"+str(model.id).replace(":","_")
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and Rect2(Vector2.ZERO,card.size).has_point(event.position): action.call()
	)
	b.focus_entered.connect(func():highlight(ui,model);card.add_theme_stylebox_override("panel",View.card_style(Look.PURPLE,false,8)))
	b.focus_exited.connect(func():card.add_theme_stylebox_override("panel",View.card_style(color,false)))
	return card

static func highlight(ui: CanvasLayer, model: Dictionary) -> void:
	if not is_instance_valid(ui.modal): return
	for cell in ui.modal.find_children("Socket_*","Control",true,false):
		var selected: bool=model.get("placement",{}).get("orb",-1)==cell.orb_index and model.get("placement",{}).get("slot",-1)==cell.slot
		if model.get("type","")=="fusion" and cell.id!="":
			selected=ui.game.Spells.Progression.base_id(cell.id) in ui.game.Spells.Progression.FUSIONS[model.output].parents
		cell.set_meta("reward_preview",selected);cell.queue_redraw()
