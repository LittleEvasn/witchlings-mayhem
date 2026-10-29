extends RefCounted
## One presentation contract for level/chest/craft/orb choices and receipts.
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Look=preload("res://scripts/mayhem_skin.gd")
const ROLE={"attack":"공격","modifier":"보조","connector":"연결"}
const COLOR={"attack":Color("98cfd4"),"modifier":Color("cfb4eb"),"connector":Color("f1bc84"),"relic":Color("e8d08e"),"fusion":Color("f0adc4"),"orb":Color("b9d8b1")}

static func model(g: Node2D, id: String, source := "level", bag_only := false) -> Dictionary:
	var v: Dictionary={"id":id,"source":source,"output":id,"type":"new","role":"attack","badge":"","title":"","change":"","compare":"","detail":"","placement":{},"icon":id,"glyph":"","cost":0}
	if id.begins_with("relic:"):
		var d: Dictionary=g.Relics.definition(id.trim_prefix("relic:"))
		v.merge({"type":"relic","role":"relic","badge":"새 유물","title":d.name,"change":d.desc,"detail":d.desc,"icon":"","glyph":d.glyph,"compare":"유물에 추가 · 장착 칸을 쓰지 않아요"},true)
	elif id.begins_with("fuse:"):
		var key:=id.trim_prefix("fuse:")
		var parents: Array=P.FUSIONS[key].parents
		v.merge({"type":"fusion","role":"fusion","badge":"완성 합성","title":S.definition(key).name,"output":key,"icon":key,"change":S.definition(key).desc,"detail":S.definition(key).desc,"compare":" + ".join(parents.map(func(p):return S.definition(p).name+" +3"))+" → 완성"},true)
		var plan: Dictionary=g.fusion_placement(key,bag_only)
		if plan.ok: v.placement=plan.placement
	elif id in ["gold","heal"]:
		v.merge({"type":"supply","role":"relic","badge":"보급","title":"마석 주머니" if id=="gold" else "잠깐의 회복","icon":"","glyph":"✦" if id=="gold" else "♥","change":"마석 10 획득" if id=="gold" or g.hp>=g.max_hp else "체력 최대 20 회복","compare":"체력이 가득 차 마석으로 지급" if id=="heal" and g.hp>=g.max_hp else "바로 적용돼요"},true)
	elif S.has_part(id):
		var old: String=g.economy.owned_token(id)
		var output: String=id if old.is_empty() else P.key(P.base_id(id),mini(3,P.rank(old)+1))
		var d:=S.definition(output)
		v.merge({"output":output,"icon":output,"role":d.kind,"badge":("새 " if old.is_empty() else "강화 · ")+ROLE.get(d.kind,"마법"),"title":S.definition(P.base_id(id)).name,"type":"new" if old.is_empty() else "upgrade","detail":d.desc},true)
		if old.is_empty():
			v.change=effect(output)
			v.compare="기본 → +1 → +2 → +3" if not P.is_fused(id) else "완성형 · 추가 강화 없음"
			v.placement={"orb":-1,"slot":-1,"text":"가방에 보관 · 직접 장착"}
		else:
			v.change="+%d  →  +%d"%[P.rank(old),P.rank(output)]
			v.compare=effect(old)+" → "+effect(output)
			for orb in g.orb_drafts.size():
				var slot: int=g.orb_drafts[orb].find(old)
				if slot>=0: v.placement={"orb":orb,"slot":slot,"text":"오브 %d · %d번 칸에서 강화"%[orb+1,slot+1]};break
			if v.placement.is_empty(): v.placement={"orb":-1,"slot":-1,"text":"가방의 마법 강화 · 위치 유지"}
	else: v.title="알 수 없는 보상"
	return v

static func effect(id: String) -> String:
	var d:=S.definition(id)
	if d.kind=="attack": return P.attack_text(id)
	if d.kind=="connector": return "후속 공격 위력 %d%%"%roundi(P.connector_power(id)*100)
	return S.modifier_token_text(id)

static func orb_model(g: Node2D, id: String, index: int) -> Dictionary:
	var value: Dictionary=g.orb_growth[index]
	var spec: Dictionary=g.OrbGrowth.OPTIONS[id]
	return {"id":id,"source":"orb","type":"orb","role":"orb","badge":"오브 %d 성장"%[index+1],"title":spec.name,"change":spec.desc,"compare":"오브 %d   +%d → +%d / 5"%[index+1,value.rank,value.rank+1],"detail":spec.desc,"icon":"","glyph":str(index+1),"placement":{},"cost":g.OrbGrowth.cost(value)}

static func card(ui: CanvasLayer, parent: Node, v: Dictionary, size: Vector2, action: Callable, button_name: String, compact := false) -> Control:
	var card:=PanelContainer.new()
	card.name="AcquisitionCard_"+str(v.id).replace(":","_")
	card.custom_minimum_size=size
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var color: Color=COLOR.get(v.role,Look.LINE)
	card.add_theme_stylebox_override("panel",card_style(color,compact))
	parent.add_child(card)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",6 if compact else 10)
	card.add_child(column)
	var badge:=label(ui,column,v.badge,12 if compact else 15,Look.PURPLE)
	badge.name="RewardKind"
	if not compact:
		var emblem:=Control.new()
		emblem.custom_minimum_size=Vector2(0,96)
		emblem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.add_child(emblem)
		if not v.get("icon","").is_empty():
			var icon:=Look.icon(ui,emblem,v.icon,Rect2(0,0,96,96))
			emblem.resized.connect(func():icon.position.x=(emblem.size.x-96)*.5)
		else:
			var glyph:=label(ui,emblem,v.get("glyph","✦"),58,Look.PURPLE)
			glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			glyph.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var name:=label(ui,column,v.title,18 if compact else 26,Look.INK)
	name.name="RewardName"
	name.max_lines_visible=2
	name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var change:=label(ui,column,v.change,14 if compact else 22,Look.INK)
	change.name="RewardChange"
	change.max_lines_visible=3 if compact else 2
	change.tooltip_text=v.get("detail",v.change)
	change.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if not compact:
		var compare:=label(ui,column,v.compare,14,Look.MUTED)
		compare.name="RewardCompare"
		compare.max_lines_visible=3
		compare.tooltip_text=v.compare
	var preview: String=v.get("placement",{}).get("text","")
	if not preview.is_empty() and not compact:
		var l:=label(ui,column,preview,14,Look.PURPLE)
		l.name="EquipPreview"
		l.max_lines_visible=2
	var b:=Button.new()
	b.name=button_name
	b.text=("선택 · %d"%v.cost if v.get("cost",0)>0 else "선택")
	b.custom_minimum_size=Vector2(0,34 if compact else 44)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Look.decorate_button(b,true)
	b.add_theme_font_size_override("font_size",16 if compact else 20)
	b.pressed.connect(action)
	column.add_child(b)
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and Rect2(Vector2.ZERO,card.size).has_point(event.position): action.call())
	# The same focus/hover border is visible without relying on role colors alone.
	b.focus_entered.connect(func():card.add_theme_stylebox_override("panel",card_style(Look.PURPLE,compact,8)))
	b.focus_exited.connect(func():card.add_theme_stylebox_override("panel",card_style(color,compact)))
	return card

static func card_style(color: Color, compact: bool, depth := 5) -> StyleBoxFlat:
	var skin:=Look.style(Look.PAPER,color,26,depth)
	skin.content_margin_top=8 if compact else 16
	skin.content_margin_bottom=8 if compact else 14
	return skin

static func label(ui: CanvasLayer, parent: Node, value: String, size: int, color: Color) -> Label:
	var l:=Label.new()
	l.text=value
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font",Look.FONT)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l
