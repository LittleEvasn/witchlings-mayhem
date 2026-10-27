extends RefCounted
const Spells = preload("res://scripts/spells.gd")
const Progression = preload("res://scripts/spell_progression.gd")
static func scroll_list(ui: CanvasLayer, rect: Rect2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	return list
static func row(ui: CanvasLayer, list: VBoxContainer, text: String, callback: Callable, selected := false, height := 44) -> Button:
	var button: Button = ui.button(list,text,Rect2(0,0,20,height),callback,selected,15)
	button.custom_minimum_size = Vector2(0,height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	return button
static func build(ui: CanvasLayer) -> void:
	var g: Node2D = ui.game
	var revision: int = g.economy.revision
	ui.label(ui.modal,"공격 구체 +0 → +4 · 중복 두 개 또는 마석(G)으로 강화 · +4 두 종류로 새 마법 합성",Vector2(150,188),16,ui.MINT)
	ui.panel(ui.modal,Rect2(150,225,330,460))
	ui.label(ui.modal,"보유 공격 구체 · 개별 강화",Vector2(168,241),19,ui.TEXT)
	var list := scroll_list(ui,Rect2(166,283,298,386))
	var ids: Array = []
	for id in g.economy.inventory:
		if g.economy.inventory[id]>0 and Spells.has_part(id) and Spells.definition(id).kind=="attack": ids.append(id)
	ids.sort()
	for id in ids:
		var count: int = g.economy.inventory[id]
		var equipped: int = g.orb_recipes[0].count(id)+g.orb_recipes[1].count(id)
		var b := row(ui,list,"%s ×%d%s" % [Spells.definition(id).name,count," · 장착" if equipped>0 else ""],func():g.select_forge_item(id),id==g.forge_target,46)
		b.tooltip_text = Spells.definition(id).desc
	if ids.is_empty(): ui.label(list,"공격 구체가 없어.",Vector2.ZERO,16,ui.MUTED)
	ui.panel(ui.modal,Rect2(500,225,778,206))
	var target: String = g.forge_target
	var material: String = g.forge_material
	var fusion_id := Progression.fusion_for(target,material)
	var is_fusion := not material.is_empty()
	var title: String = "왼쪽에서 구체 또는 아래 합성 목표 선택"
	var note := "보조·연결은 강화 재료로 소모하지 않아."
	if is_fusion and not fusion_id.is_empty():
		title = Spells.definition(fusion_id).name
		note = Spells.definition(target).name+" + "+Spells.definition(material).name+" → 한 개 · 12 G"
	elif not target.is_empty():
		title = Spells.definition(target).name
		note = "기본 공격 피해 ×%.1f · 강화마다 원래 피해의 20%%·크기의 4%% 증가" % Progression.damage_multiplier(target)
		if Progression.is_fused(target): note = Spells.definition(target).desc
	ui.label(ui.modal,title,Vector2(520,242),24,ui.MINT,734)
	var description: Label = ui.label(ui.modal,note,Vector2(520,280),15,ui.TEXT,734)
	description.max_lines_visible = 2
	if is_fusion:
		var q: Dictionary = g.economy.craft_quote("fuse",target,material)
		var b: Button = ui.button(ui.modal,"합성 실행 · 두 +4 구체와 12 G 사용",Rect2(520,330,738,40),func():g.craft_spell("fuse",target,material,revision),q.ok,18)
		b.disabled = not q.ok
		b.tooltip_text = q.error if not q.ok else Spells.definition(q.output).desc
		ui.label(ui.modal,Spells.definition(fusion_id).desc if q.ok else q.error,Vector2(520,380),14,ui.TEXT if q.ok else ui.PINK,730).max_lines_visible = 2
	else:
		var q: Dictionary = g.economy.craft_quote("upgrade",target)
		var m: Dictionary = g.economy.craft_quote("merge",target)
		var cost := 0
		if Spells.has_part(target) and not Progression.is_fused(target): cost = Progression.paid_cost(g.Economy.PRICES[Progression.base_id(target)],Progression.rank(target))
		var upgrade: Button = ui.button(ui.modal,"마석 강화 · %d G" % cost,Rect2(520,330,354,40),func():g.craft_spell("upgrade",target,"",revision),q.ok,18)
		upgrade.disabled = not q.ok
		upgrade.tooltip_text = q.error if not q.ok else "결과: "+Spells.definition(q.output).name
		var merge_text: String = "동종 구체 1개로 강화 · 무료"
		if m.ok: merge_text = "%s 소모 · 무료 강화" % Spells.definition(m.consumed[1]).name
		var merge: Button = ui.button(ui.modal,merge_text,Rect2(890,330,368,40),func():g.craft_spell("merge",target,"",revision),m.ok,16)
		merge.disabled = not m.ok
		merge.tooltip_text = m.error if not m.ok else "대상과 재료 두 개 → "+Spells.definition(m.output).name+" 한 개. 재료는 가장 낮은 강화 단계부터 선택."
		var available: Dictionary = q if q.ok else m
		var status: String = "결과: "+Spells.definition(available.output).name if available.ok else q.error
		ui.label(ui.modal,status,Vector2(520,380),14,ui.MINT if available.ok else ui.MUTED,730).max_lines_visible = 2
	ui.label(ui.modal,"합성 도감 · 필요한 +4 구체를 모아봐",Vector2(500,447),19,ui.TEXT)
	var recipes := scroll_list(ui,Rect2(500,480,778,205))
	for id in Progression.FUSIONS:
		var data: Dictionary = Progression.FUSIONS[id]
		var a := Progression.key(data.parents[0],4)
		var b := Progression.key(data.parents[1],4)
		var text := "%s   ←   %s [%d/1] + %s [%d/1]" % [data.name,Spells.definition(a).name,mini(1,g.economy.inventory.get(a,0)),Spells.definition(b).name,mini(1,g.economy.inventory.get(b,0))]
		var button := row(ui,recipes,text,func():g.select_fusion(id),id==fusion_id,46)
		button.tooltip_text = data.desc
	var message: String = g.forge_message if not g.forge_message.is_empty() else "제작은 즉시 확정돼. 장착 대상은 자동 교체하며, 소모된 공격의 보조 구체는 돌려줘."
	ui.label(ui.modal,message,Vector2(150,703),15,ui.MINT,1128).max_lines_visible = 2
	ui.button(ui.modal,"상점 · 조합으로",Rect2(150,762,200,40),func():g.set_shop_tab("shop"),false,17)
	var trial: Button = ui.button(ui.modal,"시험 발사",Rect2(365,762,170,40),g.start_trial,false,18)
	trial.disabled = not g.valid_draft()
	ui.label(ui.modal,"준비 시간은 계속 흐름\n시험 중에만 시간 정지",Vector2(565,760),13,ui.MUTED,330)
	var launch: Button = ui.button(ui.modal,"적용하고 다음 웨이브 →",Rect2(940,762,338,40),g.launch_next_wave,true,18)
	launch.disabled = not g.valid_draft()
