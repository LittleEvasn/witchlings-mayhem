extends RefCounted
const Spells=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Relics=preload("res://scripts/relics.gd")

static func ids(kind: String) -> Array:
	if kind=="fusion": return P.FUSIONS.keys()
	if kind=="relic": return Relics.DEFINITIONS.keys()
	return Spells.PARTS.keys()

static func discovered(ui: CanvasLayer, kind: String, id: String) -> bool:
	var key: String={"spell":"discovered_spells","fusion":"discovered_fusions","relic":"discovered_relics"}[kind]
	return id in ui.game.profile.data[key]

static func text(ui: CanvasLayer, parent: Node, content: String, font_size := 17, color := Color("f5f0e6")) -> Label:
	var l: Label=ui.label(parent,content,Vector2.ZERO,font_size,color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return l

static func build(ui: CanvasLayer) -> void:
	var kind: String=ui.collection_kind
	if kind not in ["spell","fusion","relic"]: kind="spell"
	ui.collection_kind=kind
	var pool:=ids(kind)
	if ui.collection_selected not in pool:
		ui.collection_selected=pool[0]
		for id in pool:
			if discovered(ui,kind,id):
				ui.collection_selected=id
				break
	ui.FrontFlow.open(ui,"collection",.48)
	ui.label(ui.modal,"발견 도감",Vector2(96,64),36,ui.TEXT)
	ui.label(ui.modal,"실제로 얻은 주문과 유물은 다음 실험에도 기억해요.",Vector2(98,119),18,ui.MUTED)
	for i in 3:
		var tab: Array=[["spell","주문"],["fusion","완성 합성"],["relic","유물"]][i]
		var count:=0
		for id in ids(tab[0]):
			if discovered(ui,tab[0],id): count+=1
		ui.FrontFlow.action(ui,"CollectionTab_"+tab[0],"%s  %d / %d"%[tab[1],count,ids(tab[0]).size()],Rect2(96+i*252,171,238,46),func():ui.collection_kind=tab[0];ui.collection_selected="";build(ui),kind==tab[0],17)
	var scroll:=ScrollContainer.new()
	scroll.name="CollectionGridScroll"
	scroll.position=Vector2(96,239)
	scroll.size=Vector2(680,540)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for id in pool:
		var known:=discovered(ui,kind,id)
		var data: Dictionary=Relics.definition(id) if kind=="relic" else Spells.definition(id)
		var glyph: String=data.glyph if kind=="relic" else ui.Board.glyph(id)
		var b: Button=ui.button(grid,(glyph+"\n"+data.name) if known else "?\n미발견",Rect2(0,0,156,96),func():ui.collection_selected=id;build(ui),id==ui.collection_selected,15)
		b.name="Entry_"+id
		b.clip_text=true
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size=Vector2(156,96)
		b.set_meta("discovered",known)
		b.tooltip_text=data.name if known else "획득하면 기록돼요."
	ui.panel(ui.modal,Rect2(820,239,510,540),ui.INK)
	var details:=ScrollContainer.new()
	details.name="CollectionDetails"
	details.position=Vector2(842,257)
	details.size=Vector2(468,500)
	details.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(details)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",15)
	details.add_child(column)
	var selected: String=ui.collection_selected
	var found:=discovered(ui,kind,selected)
	var selected_data: Dictionary=Relics.definition(selected) if kind=="relic" else Spells.definition(selected)
	text(ui,column,selected_data.name if found else "아직 발견하지 못했어요",26,ui.MINT if found else ui.MUTED)
	text(ui,column,"획득 기록" if found else "미발견",14,ui.MINT if found else ui.MUTED)
	if found:
		text(ui,column,selected_data.desc)
		if kind=="fusion": text(ui,column,{"attack":"완성 공격 · 보조 부착 가능","modifier":"완성 보조 · 오른쪽 공격들에 적용","connector":"완성 연결 · 두 공격 사이에 배치"}[selected_data.kind],15,ui.MINT)
		if kind=="relic":
			text(ui,column,selected_data.note,16,ui.MINT)
			text(ui,column,selected_data.detail,16,ui.MUTED)
		elif kind=="spell":
			text(ui,column,{"attack":"공격 주문","modifier":"오른쪽 공격들에 적용하는 보조","connector":"앞 주문의 사건에 후속을 연결"}.get(selected_data.kind,""),15,ui.MUTED)
			for rank in 4:
				var token: String=P.key(selected,rank)
				var effect: String=P.attack_text(token) if selected_data.kind=="attack" else Spells.modifier_token_text(token) if selected_data.kind=="modifier" else "후속 주문 위력 %.0f%% · 첫 사건 1회"%(P.connector_power(token)*100)
				text(ui,column,("기본" if rank==0 else "+%d"%rank)+" · "+effect,16,ui.TEXT)
	else:
		text(ui,column,"시작 조합이나 전투 보상·제작으로 구체를 얻으면 기록돼요." if kind=="spell" else "레벨업 보상이나 제작으로 유물을 얻으면 기록돼요." if kind=="relic" else "지정 재료를 +3까지 강화한 뒤 보상 상자에서 합성을 골라보세요.",17,ui.MUTED)
	if kind=="fusion":
		text(ui,column,"합성 재료 힌트",18,ui.MINT)
		for parent in P.FUSIONS[selected].parents:
			var b: Button=ui.button(column,Spells.definition(parent).name+" +3  →",Rect2(0,0,430,42),func():ui.collection_kind="spell";ui.collection_selected=parent;build(ui),false,17)
			b.custom_minimum_size=Vector2(430,42)
		text(ui,column,"지정 +3 두 개 → 보상 상자에서 무료 합성 · 한 판에 한 번",15,ui.MUTED)
	elif kind=="spell":
		for fusion in P.FUSIONS:
			if selected not in P.FUSIONS[fusion].parents: continue
			var ingredients: Array=[]
			for parent in P.FUSIONS[fusion].parents: ingredients.append(Spells.definition(parent).name)
			var name: String=P.FUSIONS[fusion].name if discovered(ui,"fusion",fusion) else " + ".join(ingredients)
			var b: Button=ui.button(column,name+" →",Rect2(0,0,430,40),func():ui.collection_kind="fusion";ui.collection_selected=fusion;build(ui),false,16)
			b.custom_minimum_size=Vector2(430,40)
	ui.FrontFlow.action(ui,"CollectionBack","← 제작함" if ui.collection_origin=="shop" else "← 타이틀",Rect2(96,810,260,47),ui.close_collection,false,18)
	ui.label(ui.modal,"도감에서는 재료를 지급하거나 장착하지 않아요.",Vector2(820,819),14,ui.MUTED)
	ui.FrontFlow.finish(ui,"CollectionTab_"+kind,["CollectionTab_spell","CollectionTab_fusion","CollectionTab_relic","CollectionBack"])
