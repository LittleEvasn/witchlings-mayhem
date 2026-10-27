extends RefCounted
const Spells = preload("res://scripts/spells.gd")
const Slot = preload("res://scripts/prep_slot.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const GLYPHS := {"bolt":"✦","bloom":"✿","boomerang":"☽","vortex":"◎","thorn":"♧","frost":"❄","thunder":"ϟ","satellite":"◉","ember_path":"♨","fan":"⋔","seek":"⌖","pierce":"↠","bounce":"↗","giant":"↟","echo":"≋","charge":"◆","graft":"♧+","sigil":"六","shatter":"✧","impact":"→","expire":"◷","on_return":"↶","storm_spear":"ϟ↠","nova_garden":"✿◎","moon_ring":"☽◉","frost_blossom":"❄✿","firework_trail":"♨✿"}
static func glyph(id: String) -> String: return GLYPHS.get(Progression.base_id(id),"✧")
static func short_name(id: String) -> String:
	var data := Spells.definition(id)
	return data.name.replace(" +%d" % Progression.rank(id),"").replace(" ✧","")

static func centered(ui: CanvasLayer, parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var l: Label = ui.label(parent,text,rect.position,font_size,color,rect.size.x)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y=rect.size.y
	return l

static func cell(ui: CanvasLayer, parent: Node, id: String, rect: Rect2, orb := -1, index := -1, inventory := false) -> Control:
	var c := Slot.new()
	c.ui=ui
	c.id=id
	c.orb_index=orb
	c.slot=index
	c.inventory=inventory
	c.read_only=orb<0 and not inventory
	c.position=rect.position
	c.size=rect.size
	c.name="Bag_"+id if inventory else "Socket_%d_%d" % [orb,index]
	parent.add_child(c)
	if id.is_empty():
		centered(ui,c,"+",Rect2(0,0,rect.size.x,rect.size.y),24,ui.BORDER)
	else:
		var part := Spells.definition(id)
		var available: bool = not inventory or ui.game.remaining_part(id)>0
		var color: Color = part.color if available else ui.MUTED.darkened(0.35)
		centered(ui,c,glyph(id),Rect2(0,2,rect.size.x,rect.size.y*0.63),30 if rect.size.y>70 else 24,color)
		var name: Label = centered(ui,c,short_name(id),Rect2(2,rect.size.y-25,rect.size.x-4,23),12 if rect.size.x<90 else 13,ui.TEXT if available else ui.MUTED)
		name.max_lines_visible=1
		name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if Progression.rank(id)>0: ui.label(c,"+%d" % Progression.rank(id),Vector2(5,3),12,ui.MINT)
		if Progression.is_fused(id): ui.label(c,"✧",Vector2(5,3),12,ui.MINT)
		if inventory:
			var count: int = ui.game.remaining_part(id)
			var badge: Label = ui.label(c,str(count) if count>0 else "장착",Vector2(rect.size.x-32,3),11,ui.MINT if count>0 else ui.MUTED,29)
			badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			if id==ui.game.purchased_orb:
				var flash := c.create_tween()
				c.modulate=Color(1.5,1.5,1.5)
				flash.tween_property(c,"modulate",Color.WHITE,0.45)
	return c

static func row(ui: CanvasLayer, index: int, at: Vector2, compact := false) -> void:
	var g: Node2D=ui.game
	var parts: Array = g.draft if index==g.active_orb else g.orb_drafts[index]
	var color: Color=ui.MINT if index==0 else ui.PINK
	var width:=800.0 if compact else 900.0
	var height:=112.0 if compact else 158.0
	var tray: Panel=ui.panel(ui.modal,Rect2(at.x+40,at.y+8,width-40,height-12),Color("1c2638"))
	tray.add_theme_stylebox_override("panel",ui.box(Color("1c2638"),color.darkened(0.58),1,24))
	var orb: Button=ui.button(ui.modal,"%d" % (index+1),Rect2(at.x,at.y+17,86 if compact else 110,86 if compact else 110),func():g.select_orb(index),false,32)
	orb.name="OrbSelect%d" % index
	orb.add_theme_stylebox_override("normal",ui.box(Color("273c4b") if index==0 else Color("493041"),color,3 if index==g.active_orb else 1,60))
	orb.add_theme_color_override("font_color",color)
	orb.tooltip_text="오브 %d · 두 오브는 각자 자동으로 마법을 쏩니다." % (index+1)
	var x: float=at.x+(110 if compact else 150)
	var w:=91.0 if compact else 108.0
	var h:=61.0 if compact else 86.0
	for i in 6:
		cell(ui,ui.modal,str(parts[i]) if i<parts.size() else "",Rect2(x+i*(w+8),at.y+19,w,h),index,i)
	var result := Spells.compile(parts)
	var text := "구체를 넣으면 이 오브도 함께 공격해요."
	if not parts.is_empty(): text=Spells.describe(parts) if result.ok else "! "+result.error
	var l: Label=ui.label(ui.modal,text,Vector2(x,at.y+(83 if compact else 116)),12 if compact else 15,color if result.ok or parts.is_empty() else ui.PINK,width-(x-at.x)-18)
	l.max_lines_visible=1
	l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text=text

static func bag(ui: CanvasLayer, rect: Rect2, columns := 8) -> void:
	var bg:=Slot.new()
	bg.ui=ui
	bg.inventory=true
	bg.backdrop=true
	bg.position=rect.position
	bg.size=rect.size
	bg.name="BagDropArea"
	ui.modal.add_child(bg)
	ui.panel(bg,Rect2(Vector2.ZERO,rect.size),Color("131c2a"))
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(12,12)
	scroll.size=rect.size-Vector2(24,24)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	var w:=floorf((rect.size.x-42-(columns-1)*8)/columns)
	for id in ui.game.economy.inventory:
		if ui.game.economy.inventory[id]<=0: continue
		var c:=cell(ui,grid,id,Rect2(0,0,w,84),-1,-1,true)
		c.custom_minimum_size=Vector2(w,84)

static func build(ui: CanvasLayer, shop: bool) -> void:
	var g: Node2D=ui.game
	ui.new_modal(Rect2(32,32,1376,836))
	ui.hud.visible=false
	ui.label(ui.modal,"마법 준비",Vector2(64,54),32,ui.TEXT)
	ui.label(ui.modal,"두 오브가 함께 싸워요",Vector2(66,104),16,ui.MINT)
	ui.label(ui.modal,"구체를 끌어 장착 · 우클릭으로 빼기",Vector2(480,112),14,ui.MUTED)
	ui.label(ui.modal,"%d G" % g.economy.gold,Vector2(1220,62),28,ui.MINT)
	row(ui,0,Vector2(64,157))
	row(ui,1,Vector2(64,329))
	ui.label(ui.modal,"가방",Vector2(66,512),23,ui.TEXT)
	ui.label(ui.modal,"선택하면 상세 보기 · 두 번 누르면 장착",Vector2(155,521),14,ui.MUTED)
	var undo: Button=ui.button(ui.modal,"↶ 되돌리기",Rect2(798,507,160,38),g.undo_draft,false,16)
	undo.disabled=g.edit_history.is_empty()
	bag(ui,Rect2(64,558,900,218))
	var note: String=g.workbench_message
	if note.is_empty(): note="칸 가운데: 교체  ·  칸 가장자리: 사이에 넣기  ·  가방으로 빼면 해제"
	ui.label(ui.modal,note,Vector2(66,788),13,ui.PINK if not g.workbench_message.is_empty() else ui.MUTED,890).max_lines_visible=2
	ui.panel(ui.modal,Rect2(990,150,386,626),Color("111a29"))
	if shop:
		ui.button(ui.modal,"상점",Rect2(1006,164,110,38),func():ui.board_panel="shop";ui.show_shop(),ui.board_panel=="shop",16)
		ui.button(ui.modal,"구체",Rect2(1124,164,110,38),func():ui.board_panel="item";ui.show_shop(),ui.board_panel=="item",16)
		ui.button(ui.modal,"합성",Rect2(1242,164,118,38),func():ui.board_panel="fusion";ui.show_shop(),ui.board_panel=="fusion",16)
		match ui.board_panel:
			"item": detail(ui)
			"fusion": fusion(ui)
			"research": research(ui)
			_: shop_items(ui)
		ui.button(ui.modal,"시험 발사",Rect2(1006,795,145,48),g.start_trial,false,19).disabled=not g.valid_draft()
		ui.button(ui.modal,"준비 완료 →",Rect2(1162,795,198,48),g.launch_next_wave,true,21).disabled=not g.valid_draft()
	else:
		detail(ui,false)
		ui.button(ui.modal,"계속하기 · Tab",Rect2(1006,795,354,48),g.board_close,true,21).disabled=not g.valid_draft()
	ui.label(ui.modal,"시간 제한 없이 준비하세요" if shop else "편집 중에는 전투가 멈춰요",Vector2(66,834),13,ui.MUTED)

static func shop_items(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	var rev: int=g.economy.revision
	for i in g.economy.offers.size():
		var offer: Dictionary=g.economy.offers[i]
		var at:=Vector2(1006+(i%2)*181,222+floori(i/2.0)*190)
		ui.panel(ui.modal,Rect2(at,Vector2(173,176)),Color("202b3c"))
		var id: String=offer.id
		if not id.is_empty():
			cell(ui,ui.modal,id,Rect2(at+Vector2(36,10),Vector2(101,92)))
		else: centered(ui,ui.modal,"?",Rect2(at+Vector2(0,10),Vector2(173,83)),38,ui.MINT)
		if i==0:
			ui.button(ui.modal,"구체 고르기",Rect2(at+Vector2(12,107),Vector2(149,27)),func():ui.board_panel="research";ui.show_shop(),false,13).disabled=g.economy.research_sold
		else: centered(ui,ui.modal,"무작위 상품",Rect2(at+Vector2(0,106),Vector2(173,25)),12,ui.MUTED)
		var buy: Button=ui.button(ui.modal,"품절" if offer.sold else ("선택 후 구매" if id.is_empty() else "%d G · 구매" % offer.price),Rect2(at+Vector2(12,138),Vector2(149,30)),func():g.buy_orb(i,rev),not offer.sold,15)
		buy.disabled=offer.sold or id.is_empty() or g.economy.gold<offer.price
	ui.button(ui.modal,"새 상품  ·  5 G",Rect2(1006,615,354,38),func():g.reroll_shop(rev),false,16).disabled=g.economy.gold<5
	var msg: String=g.shop_message
	ui.label(ui.modal,msg,Vector2(1010,666),14,ui.MINT,342).max_lines_visible=2
	var forecast=ui.label(ui.modal,g.Waves.forecast(g.wave+1),Vector2(1010,719),13,ui.MUTED,342)
	forecast.name="WaveForecast"
	forecast.max_lines_visible=2

static func detail(ui: CanvasLayer, crafting := true) -> void:
	var g: Node2D=ui.game
	var id: String=ui.selected_item
	if id.is_empty() or not Spells.has_part(id):
		centered(ui,ui.modal,"구체를 골라보세요",Rect2(1006,320,354,60),22,ui.TEXT)
		centered(ui,ui.modal,"가방이나 장착한 구체를 누르면\n효과를 확인할 수 있어요.",Rect2(1010,390,346,80),16,ui.MUTED)
		return
	var part:=Spells.definition(id)
	centered(ui,ui.modal,glyph(id),Rect2(1094,224,170,95),60,part.color)
	centered(ui,ui.modal,part.name,Rect2(1006,327,354,40),23,ui.TEXT)
	var kind: String={"attack":"공격","modifier":"보조 · 공격 앞에 놓기","connector":"연결 · 두 공격 사이에 놓기"}.get(part.kind,"")
	centered(ui,ui.modal,kind,Rect2(1006,371,354,25),14,part.color)
	ui.label(ui.modal,part.desc,Vector2(1012,414),16,ui.TEXT,340).max_lines_visible=4
	ui.button(ui.modal,"오브 %d에 끼우기" % (g.active_orb+1),Rect2(1006,518,354,38),func():g.board_quick_equip(id),true,17).disabled=g.remaining_part(id)<=0
	if crafting and part.kind=="attack" and not Progression.is_fused(id):
		var q: Dictionary=g.economy.craft_quote("upgrade",id)
		var m: Dictionary=g.economy.craft_quote("merge",id)
		var rev: int=g.economy.revision
		var rank:=Progression.rank(id)
		ui.label(ui.modal,"+%d  →  +%d" % [rank,mini(4,rank+1)] if rank<4 else "최대 강화 · 합성 재료 준비 완료",Vector2(1010,580),17,ui.MINT)
		var cost:=Progression.paid_cost(g.Economy.PRICES[Progression.base_id(id)],rank)
		var paid: Button=ui.button(ui.modal,"강화 · %d G" % cost,Rect2(1006,617,354,40),func():g.craft_spell("upgrade",id,"",rev),false,17)
		paid.disabled=not q.ok
		paid.tooltip_text=q.error if not q.ok else "강화 후: "+Spells.definition(q.output).desc
		var merge: Button=ui.button(ui.modal,"중복 구체로 강화",Rect2(1006,666,354,40),func():g.craft_spell("merge",id,"",rev),false,17)
		merge.disabled=not m.ok
		merge.tooltip_text=m.error if not m.ok else "소모: "+Spells.definition(m.consumed[1]).name+" → 결과: "+Spells.definition(m.output).name
		if m.ok: merge.text=Spells.definition(m.consumed[1]).name+" 소모 · 무료"
	if not g.forge_message.is_empty(): ui.label(ui.modal,g.forge_message,Vector2(1010,721),12,ui.MINT,342).max_lines_visible=2

static func fusion(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	var selected: String=ui.fusion_choice
	if selected.is_empty(): selected="storm_spear"
	var recipe: Dictionary=Progression.FUSIONS[selected]
	var a:=Progression.key(recipe.parents[0],4)
	var b:=Progression.key(recipe.parents[1],4)
	centered(ui,ui.modal,"두 +4 구체를 새로운 마법으로",Rect2(1006,216,354,26),15,ui.MUTED)
	for i in 2:
		var id: String=a if i==0 else b
		cell(ui,ui.modal,id,Rect2(1030+i*196,254,106,85))
		centered(ui,ui.modal,"보유 %d / 1" % g.economy.inventory.get(id,0),Rect2(1020+i*196,343,126,24),12,ui.MINT if g.economy.inventory.get(id,0)>0 else ui.PINK)
	centered(ui,ui.modal,"+",Rect2(1151,270,60,50),26,ui.MUTED)
	centered(ui,ui.modal,"↓  "+recipe.name,Rect2(1006,373,354,35),23,recipe.color)
	ui.label(ui.modal,recipe.desc,Vector2(1014,420),14,ui.TEXT,338).max_lines_visible=2
	var q: Dictionary=g.economy.craft_quote("fuse",a,b)
	var rev: int=g.economy.revision
	var button: Button=ui.button(ui.modal,"합성하기 · 12 G",Rect2(1006,476,354,40),func():g.craft_spell("fuse",a,b,rev),true,18)
	button.disabled=not q.ok
	button.tooltip_text=q.error if not q.ok else "재료 두 개가 사라지고 합성 구체 한 개를 얻습니다."
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(1006,531)
	scroll.size=Vector2(354,227)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	scroll.add_child(list)
	for id in Progression.FUSIONS:
		var entry: Button=ui.button(list,glyph(id)+"   "+Progression.FUSIONS[id].name,Rect2(0,0,330,38),func():ui.fusion_choice=id;ui.show_shop(),id==selected,16)
		entry.custom_minimum_size=Vector2(0,38)
		entry.size_flags_horizontal=Control.SIZE_EXPAND_FILL

static func research(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	ui.label(ui.modal,"원하는 구체 · 상점당 한 번",Vector2(1008,221),18,ui.MINT)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(1006,260)
	scroll.size=Vector2(354,492)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	var rev: int=g.economy.revision
	for id in Spells.PARTS:
		if not g.economy.can_stock(id): continue
		var button: Button=ui.button(grid,glyph(id)+"  "+Spells.definition(id).name+"\n%d G" % g.Economy.PRICES[id],Rect2(0,0,162,68),func():ui.board_panel="shop";g.select_research(id,rev),false,14)
		button.custom_minimum_size=Vector2(162,68)
		button.tooltip_text=Spells.definition(id).desc

static func trial(ui: CanvasLayer) -> void:
	ui.close_modal()
	ui.hud.visible=false
	ui.modal=Control.new()
	ui.modal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.root.add_child(ui.modal)
	ui.panel(ui.modal,Rect2(36,20,1368,78),Color("131c2a"))
	ui.label(ui.modal,"시험 발사",Vector2(60,31),23,ui.MINT)
	ui.trial_stats_label=ui.label(ui.modal,"",Vector2(250,43),15,ui.TEXT,890)
	ui.button(ui.modal,"준비대로 · Esc",Rect2(1180,36,198,42),ui.game.end_trial,false,17)
	ui.panel(ui.modal,Rect2(36,535,1368,345),Color("131c2a"))
	row(ui,0,Vector2(60,544),true)
	row(ui,1,Vector2(60,664),true)
	ui.label(ui.modal,"가방",Vector2(906,548),18,ui.TEXT)
	bag(ui,Rect2(896,580,484,210),5)
	var undo: Button=ui.button(ui.modal,"↶ 되돌리기",Rect2(60,792,160,38),ui.game.undo_draft,false,16)
	undo.disabled=ui.game.edit_history.is_empty()
	ui.label(ui.modal,"위쪽 경기장을 조준해 발사 · 슬롯 변경은 즉시 반영",Vector2(250,802),14,ui.MUTED)
	ui.label(ui.modal,"구체를 끌어 옮기세요 · 상세 효과는 마우스를 올려 확인",Vector2(904,808),12,ui.MUTED,450)
	ui.update_trial_stats()
