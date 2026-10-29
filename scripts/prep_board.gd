extends RefCounted
const Look = preload("res://scripts/mayhem_skin.gd")
const Spells = preload("res://scripts/spells.gd")
const Slot = preload("res://scripts/prep_slot.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const Crafting = preload("res://scripts/crafting_board.gd")
const GLYPHS := {"bolt":"✦","bloom":"✿","boomerang":"☽","vortex":"◎","thorn":"♧","frost":"❄","thunder":"ϟ","satellite":"◉","ember_path":"♨","fan":"⋔","seek":"⌖","pierce":"↠","bounce":"↗","giant":"↟","echo":"≋","charge":"◆","impact":"→","expire":"◷","storm_spear":"ϟ↠","nova_garden":"✿◎","moon_ring":"☽◉","frost_blossom":"❄✿","firework_trail":"♨✿","frost_gate":"✦❄","thunder_trap":"ϟ♧","moon_vortex":"◎◉","petal_return":"☽✿"}
static func glyph(id: String) -> String:
	if Progression.is_support(id):
		var parents: Array=Progression.FUSIONS[id].parents
		return GLYPHS.get(parents[0],"✧")+GLYPHS.get(parents[1],"✧")
	return GLYPHS.get(Progression.base_id(id),"✧")
static func short_name(id: String) -> String:
	var data := Spells.definition(id)
	return data.name.replace(" +%d" % Progression.rank(id),"").replace(" ✧","")

static func centered(ui: CanvasLayer, parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var l: Label = ui.label(parent,text,rect.position,font_size,color,rect.size.x)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y=rect.size.y
	return l

static func cell(ui: CanvasLayer, parent: Node, id: String, rect: Rect2, orb := -1, index := -1, inventory := false, compact := false) -> Control:
	var c := Slot.new()
	c.ui=ui
	c.id=id
	c.orb_index=orb
	c.slot=index
	c.inventory=inventory
	c.set_meta("compact_slot",compact)
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
		var icon_size: float=rect.size.y*(.74 if compact else .58)
		Look.icon(ui,c,id,Rect2((rect.size.x-icon_size)*.5,3,icon_size,icon_size))
		var light: bool=is_instance_valid(ui.modal) and ui.modal.get_meta("rounded_ui",false)
		var name: Label = centered(ui,c,short_name(id),Rect2(2,rect.size.y-25,rect.size.x-4,23),12 if rect.size.x<90 else 13,Look.INK if light else (ui.TEXT if available else ui.MUTED))
		name.add_theme_font_override("font",Look.FONT)
		name.max_lines_visible=1
		name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name.visible=not compact
		if Progression.rank(id)>0: ui.label(c,"+%d" % Progression.rank(id),Vector2(4,2),12,Look.PURPLE if light else ui.MINT)
		if Progression.is_fused(id): ui.label(c,"✧",Vector2(4,2),12,Look.PURPLE if light else ui.MINT)
		if inventory:
			var count: int = ui.game.remaining_part(id)
			var badge: Label = ui.label(c,str(count) if count>1 else ("" if compact and count>0 else "장착" if count<=0 else "1"),Vector2(rect.size.x-32,3),11,Look.PURPLE if light else (ui.MINT if count>0 else ui.MUTED),29)
			badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			if id==ui.game.purchased_orb:
				var flash := c.create_tween()
				c.modulate=Color(1.5,1.5,1.5)
				flash.tween_property(c,"modulate",Color.WHITE,0.45)
	if orb>=0:
		var diagnostic := Spells.slot_diagnostic(Spells.compile(ui.game.orb_drafts[orb]),index)
		if not diagnostic.is_empty():
			c.set_meta("inactive",diagnostic.severity=="inactive")
			c.set_meta("invalid",diagnostic.severity!="inactive")
			c.tooltip_text=diagnostic.reason
			ui.label(c,"!",Vector2(rect.size.x-15,1),13,ui.PINK,14)
	return c

static func row(ui: CanvasLayer, index: int, at: Vector2, compact := false, width_override := 0.0) -> void:
	var g: Node2D=ui.game
	var parts: Array = g.draft if index==g.active_orb else g.orb_drafts[index]
	var color: Color=ui.MINT if index==0 else ui.PINK
	var width:=800.0 if compact else 900.0
	var narrow := width_override>0
	if narrow: width = width_override
	var height:=112.0 if compact else 158.0
	var tray: Panel=ui.panel(ui.modal,Rect2(at.x+30,at.y+8,width-40,height-12),Color("1c2638"))
	tray.add_theme_stylebox_override("panel",ui.box(Color("1c2638"),color.darkened(0.58),1,24))
	var orb_size := 48.0 if narrow else (86.0 if compact else 110.0)
	var orb: Button=ui.button(ui.modal,"%d" % (index+1),Rect2(at.x,at.y+22,orb_size,orb_size),func():g.select_orb(index),false,22 if narrow else 32)
	orb.name="OrbSelect%d" % index
	orb.add_theme_stylebox_override("normal",ui.box(Color("273c4b") if index==0 else Color("493041"),color,3 if index==g.active_orb else 1,60))
	orb.add_theme_color_override("font_color",color)
	orb.tooltip_text="오브 %d · 오브들은 각자 자동으로 마법을 쏩니다." % (index+1)
	var x: float=at.x+(110 if compact else 150)
	var w:=91.0 if compact else 108.0
	var h:=61.0 if compact else 86.0
	if narrow:
		x = at.x+62
		w = floorf((width-76-(parts.size()-1)*8)/parts.size())
		h = 64
	if not narrow: w=minf(w,(width-(x-at.x)-20)/parts.size()-8)
	for i in parts.size():
		cell(ui,ui.modal,str(parts[i]) if i<parts.size() else "",Rect2(x+i*(w+8),at.y+19,w,h),index,i)
	var selected_slots: Array = []
	for slot in parts.size():
		if parts[slot]==ui.selected_item and Spells.definition(str(parts[slot])).kind=="modifier" and (ui.inspected_slot<0 or (ui.inspected_orb==index and ui.inspected_slot==slot)):
			for affected in Spells.affected_slots(parts,slot):
				if not affected in selected_slots: selected_slots.append(affected)
	var result := Spells.compile(parts)
	for affected in selected_slots:
		var target: Control = ui.modal.get_node_or_null("Socket_%d_%d" % [index,affected])
		if target: target.set_meta("affected",true);target.queue_redraw()

	var text := "구체를 넣으면 이 오브도 함께 공격해요."
	if Spells.has_content(parts): text=Spells.describe(parts)
	var l: Label=ui.label(ui.modal,text,Vector2(x,at.y+(83 if compact else 116)),12 if compact else 15,color if result.ok or parts.is_empty() else ui.PINK,width-(x-at.x)-18)
	l.max_lines_visible=1
	l.name="ProgramSummary%d" % index
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
	Look.card(ui,bg,Rect2(Vector2.ZERO,rect.size),Color("f4eef8"),20,0) if ui.modal.get_meta("rounded_ui",false) else ui.panel(bg,Rect2(Vector2.ZERO,rect.size),Color("131c2a"))
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(12,12)
	scroll.size=rect.size-Vector2(24,24)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	if ui.modal.get_meta("craft_drawer",false):
		scroll.name="CraftBagScroll"
		scroll.set_deferred("scroll_vertical",ui.bag_scroll)
		scroll.get_v_scroll_bar().value_changed.connect(func(value):ui.bag_scroll=int(value))
	var grid:=GridContainer.new()
	grid.columns=columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	var w:=floorf((rect.size.x-42-(columns-1)*8)/columns)
	var h:=86.0 if ui.modal.get_meta("wide_workbench",false) else 70.0 if ui.modal.get_meta("craft_drawer",false) else 84.0
	for id in ui.game.economy.inventory:
		if ui.game.economy.inventory[id]<=0: continue
		if ui.modal.get_meta("craft_drawer",false) and ui.bag_filter!="all" and Spells.definition(id).kind!=ui.bag_filter: continue
		var c:=cell(ui,grid,id,Rect2(0,0,w,h),-1,-1,true)
		c.custom_minimum_size=Vector2(w,h)

static func build(ui: CanvasLayer, shop: bool) -> void:
	if shop:
		Crafting.build(ui)
		return
	var g: Node2D=ui.game
	ui.new_modal(Rect2(32,32,1376,836))
	ui.hud.visible=false
	ui.label(ui.modal,"마법 준비",Vector2(64,54),32,ui.TEXT)
	ui.label(ui.modal,"다음: "+g.RunContent.chapter(mini(5,g.wave+1)).title if shop else "장착한 오브들이 함께 싸워요",Vector2(66,104),16,ui.MINT,410)
	ui.label(ui.modal,"구체를 끌어 장착 · 우클릭으로 빼기",Vector2(480,112),14,ui.MUTED)
	ui.label(ui.modal,"%d G" % g.economy.gold,Vector2(1220,62),28,ui.MINT)
	ui.button(ui.modal,"보유 유물 %d"%g.relics.owned.size(),Rect2(1010,65,190,38),ui.show_relics,false,16)
	if not g.combat_rewards.pending.is_empty():
		ui.button(ui.modal,"남은 마법 선택 %d"%g.combat_rewards.pending.size(),Rect2(1030,110,300,32),func():g.open_personal("reward"),false,15)
	row(ui,0,Vector2(64,157))
	row(ui,1,Vector2(64,329))
	ui.label(ui.modal,"가방",Vector2(66,512),23,ui.TEXT)
	ui.label(ui.modal,"선택하면 상세 보기 · 두 번 누르면 장착",Vector2(155,521),14,ui.MUTED)
	var undo: Button=ui.button(ui.modal,"↶ 되돌리기",Rect2(798,507,160,38),g.undo_draft,false,16)
	undo.disabled=g.edit_history.is_empty()
	bag(ui,Rect2(64,558,900,218))
	var note: String=g.workbench_message
	if note.is_empty(): note="빈칸: 이동  ·  구체 위: 교환  ·  가방으로 빼면 해제"
	ui.label(ui.modal,note,Vector2(66,788),13,ui.PINK if not g.workbench_message.is_empty() else ui.MUTED,890).max_lines_visible=2
	ui.panel(ui.modal,Rect2(990,150,386,626),Color("111a29"))
	if shop:
		ui.button(ui.modal,"제작대",Rect2(1006,164,110,38),func():ui.board_panel="shop";ui.show_shop(),ui.board_panel=="shop",16)
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
	ui.label(ui.modal,"시간 제한 없이 준비하세요" if shop else "전투 중 조합은 개인 창에서 편집해요",Vector2(66,834),13,ui.MUTED)

static func shop_items(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	var rev: int=g.economy.revision
	var compact: bool = g.economy.offers.size()>4
	for i in g.economy.offers.size():
		var offer: Dictionary=g.economy.offers[i]
		var at:=Vector2(1006+(i%2)*181,222+floori(i/2.0)*(126 if compact else 190))
		ui.panel(ui.modal,Rect2(at,Vector2(173,118 if compact else 176)),Color("202b3c"))
		var id: String=offer.id
		if not id.is_empty():
			cell(ui,ui.modal,id,Rect2(at+Vector2(36,4 if compact else 10),Vector2(101,55 if compact else 92)))
		else: centered(ui,ui.modal,"?",Rect2(at+Vector2(0,4 if compact else 10),Vector2(173,55 if compact else 83)),32,ui.MINT)
		if i==0:
			ui.button(ui.modal,"구체 고르기",Rect2(at+Vector2(12,58 if compact else 107),Vector2(149,25)),func():ui.board_panel="research";ui.show_shop(),false,13).disabled=g.economy.research_sold
		else: centered(ui,ui.modal,"무작위 제작안",Rect2(at+Vector2(0,58 if compact else 106),Vector2(173,25)),12,ui.MUTED)
		var text := "제작 완료" if offer.sold else ("선택 후 제작" if id.is_empty() else ("무료 제작" if offer.price==0 else "%d G · 제작" % offer.price))
		var buy: Button=ui.button(ui.modal,text,Rect2(at+Vector2(12,85 if compact else 138),Vector2(149,30)),func():g.buy_orb(i,rev),not offer.sold,15)
		buy.name="CraftOffer%d"%i
		buy.tooltip_text="마석 소모 없이 제작" if offer.get("free",false) else ""
		buy.disabled=offer.sold or id.is_empty() or g.economy.gold<offer.price
	ui.button(ui.modal,"제작안 재구성  ·  5 G",Rect2(1006,615,354,38),func():g.reroll_shop(rev),false,16).disabled=g.economy.gold<5
	var msg: String=g.shop_message
	ui.label(ui.modal,msg,Vector2(1010,666),14,ui.MINT,342).max_lines_visible=2
	var forecast=ui.label(ui.modal,g.Waves.forecast(g.wave+1),Vector2(1010,719),13,ui.MUTED,342)
	forecast.name="WaveForecast"
	forecast.max_lines_visible=2

static func effect_preview(ui: CanvasLayer, id: String, quote: Dictionary, compact := false) -> String:
	if not quote.has("inventory") or not quote.has("output"): return ""
	var kind: String = Spells.definition(id).kind
	if kind!="modifier":
		var before := Progression.attack_text(id) if kind=="attack" else "후속 위력 %.0f%%"%(Progression.connector_power(id)*100)
		var after := Progression.attack_text(quote.output) if kind=="attack" else "후속 위력 %.0f%%"%(Progression.connector_power(quote.output)*100)
		return before+" → "+after
	var g: Node2D = ui.game
	var selected_slot: int = ui.inspected_slot if ui.inspected_orb==g.active_orb else -1
	var after: Array = g.Forge.reconcile(g.orb_drafts,id,quote,g.active_orb,selected_slot)
	var lines: PackedStringArray = []
	for orb in g.orb_recipes.size():
		var left := Spells.compile(g.orb_drafts[orb])
		var right := Spells.compile(after[orb])
		if not left.ok or not right.ok: continue
		for index in mini(left.stages.size(),right.stages.size()):
			var before := Spells.modifier_effect_text(left.stages[index],id)
			var next := Spells.modifier_effect_text(right.stages[index],id)
			if before!=next:
				if compact:
					return "오브%d %s\n%s → %s"%[orb+1,Spells.definition(right.stages[index].source_id).name,Spells.Effects.compact(left.stages[index],Progression.base_id(id)),Spells.Effects.compact(right.stages[index],Progression.base_id(id))]
				lines.append("오브%d %s\n%s → %s"%[orb+1,Spells.definition(right.stages[index].source_id).name,before,next])
	if lines.is_empty():
		if compact: return "구체 자체\n%s → %s"%[Spells.Effects.compact(Spells.modifier_token_stage(id),Progression.base_id(id)),Spells.Effects.compact(Spells.modifier_token_stage(quote.output),Progression.base_id(id))]
		return "구체 자체\n%s → %s"%[Spells.modifier_token_text(id),Spells.modifier_token_text(quote.output)]
	return "\n".join(lines)

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
	var explanation: Label = ui.label(ui.modal,part.desc,Vector2(1012,414),14,ui.TEXT,340)
	explanation.max_lines_visible=4
	explanation.tooltip_text=part.desc
	if part.kind=="modifier":
		explanation.text=Spells.MODIFIER_NOTES.get(Progression.base_id(id),"완성 보조 · 오른쪽 공격에 적용")+"\n"+Spells.modifier_token_text(id)
		explanation.max_lines_visible=4
	ui.button(ui.modal,"오브 %d에 끼우기" % (g.active_orb+1),Rect2(1006,505,354,38),func():g.board_quick_equip(id),true,17).disabled=g.remaining_part(id)<=0
	if crafting and Spells.upgradeable(id):
		var options := OptionButton.new()
		options.name="ForgeMaterial"
		options.position=Vector2(1006,571)
		options.size=Vector2(354,34)
		options.add_item("재료 자동 선택 · 낮은 단계부터")
		options.set_item_metadata(0,"")
		for level in range(4):
			var token := Progression.key(Progression.base_id(id),level)
			var count: int = g.economy.inventory.get(token,0)-(1 if token==id else 0)
			if count<=0: continue
			var equipped: int = g.equipped_count(token)
			options.add_item("%s · 재료 %d개 / 장착 %d개" % [Spells.definition(token).name,count,equipped])
			var item := options.item_count-1
			options.set_item_metadata(item,token)
			if ui.merge_material==token: options.select(item)
		if options.selected==0: ui.merge_material=""
		ui.modal.add_child(options)
		options.item_selected.connect(func(index):ui.merge_material=options.get_item_metadata(index);ui.refresh_workbench.call_deferred())
		ui.label(ui.modal,"같은 구체 재료 선택 · 최대 +3",Vector2(1010,551),12,ui.MUTED)
		var q: Dictionary=g.economy.craft_quote("upgrade",id)
		var m: Dictionary=g.economy.craft_quote("merge",id,ui.merge_material)
		var rev: int=g.economy.revision
		var preview: String = m.error
		if m.ok: preview="합치기: %s + %s → %s" % [Spells.definition(m.consumed[0]).name,Spells.definition(m.consumed[1]).name,Spells.definition(m.output).name]
		var result_label: Label = ui.label(ui.modal,preview,Vector2(1010,609),12,ui.MINT if m.ok else ui.PINK,342)
		result_label.name="ForgePreview"
		result_label.max_lines_visible=2
		result_label.tooltip_text=preview
		var merge_effect := effect_preview(ui,id,m) if m.ok else ""
		var paid_effect := effect_preview(ui,id,q)
		if Spells.upgradeable(id):
			var selected_quote: Dictionary = m if m.ok else q
			var visible_effect := effect_preview(ui,id,selected_quote,true)
			if not visible_effect.is_empty(): visible_effect=("합치기 · " if m.ok else "마석 강화 · ")+visible_effect
			if visible_effect.is_empty(): visible_effect="현재: "+(Spells.modifier_token_text(id) if part.kind=="modifier" else Progression.attack_text(id) if part.kind=="attack" else "후속 위력 %.0f%%"%(Progression.connector_power(id)*100))
			var effect_label: Label = ui.label(ui.modal,visible_effect,Vector2(1010,645),13,ui.MINT,342)
			effect_label.name="ForgeEffectPreview"
			effect_label.max_lines_visible=2
			effect_label.tooltip_text="합치기\n"+merge_effect+"\n마석 강화\n"+paid_effect
		var rank:=Progression.rank(id)
		var cost:=Progression.paid_cost(g.Economy.PRICES[Progression.base_id(id)],rank)
		var paid: Button=ui.button(ui.modal,"마석 강화 · %d G" % cost,Rect2(1006,697,173,38),func():g.craft_spell("upgrade",id,"",rev),false,15)
		paid.name="ForgePaid"
		if rank>=3: paid.text="최대 강화 +3"
		paid.disabled=not q.ok
		paid.tooltip_text=q.error if not q.ok else "%s 한 개 → %s · %d G 사용" % [part.name,Spells.definition(q.output).name,cost]
		if not paid_effect.is_empty(): paid.tooltip_text+="\n"+paid_effect
		var merge: Button=ui.button(ui.modal,"구체 합치기 · 무료",Rect2(1187,697,173,38),func():g.craft_spell("merge",id,ui.merge_material,rev),false,15)
		merge.name="ForgeMerge"
		merge.disabled=not m.ok
		merge.tooltip_text=preview+("\n"+merge_effect if not merge_effect.is_empty() else "")
	if not g.forge_message.is_empty(): ui.label(ui.modal,g.forge_message,Vector2(1010,744),12,ui.MINT,342).max_lines_visible=2

static func fusion(ui: CanvasLayer, show_catalog := true) -> void:
	var g: Node2D=ui.game
	var selected: String=ui.fusion_choice
	if selected.is_empty(): selected="storm_spear"
	var recipe: Dictionary=Progression.FUSIONS[selected]
	var a:=Progression.key(recipe.parents[0],3)
	var b:=Progression.key(recipe.parents[1],3)
	centered(ui,ui.modal,"두 +3 구체를 새로운 마법으로",Rect2(1006,216,354,26),15,ui.MUTED)
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
	if not show_catalog:
		var note := "완성 구체 한 개가 가방에 들어가요.\n장착 중인 재료도 소비되며 해당 슬롯에 결과가 반영돼요."
		if not q.ok: note = q.error
		ui.label(ui.modal,note,Vector2(1010,550),15,ui.MUTED,342).max_lines_visible=5
		return
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
	ui.label(ui.modal,"원하는 구체 · 제작대당 한 번",Vector2(1008,221),18,ui.MINT)
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
	Crafting.build(ui,true)
