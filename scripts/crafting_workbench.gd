extends RefCounted
## Preparation uses a broad workbench; combat inventory remains its own non-pausing window.
const Look=preload("res://scripts/mayhem_skin.gd")
const Spells=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Detail=preload("res://scripts/crafting_detail.gd")
const View=preload("res://scripts/acquisition_view.gd")
const WIDTH:=1036.0

static func build(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	g.ensure_orb_growth()
	ui.close_modal()
	ui.modal=Control.new()
	ui.modal.name="CraftWorkbenchRoot"
	ui.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.modal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.modal.set_meta("craft_drawer",true)
	ui.modal.set_meta("wide_workbench",true)
	ui.modal.set_meta("rounded_ui",true)
	ui.root.add_child(ui.modal)
	ui.hud.visible=true
	ui.recipe_bar.visible=false
	for l in [ui.stats_label,ui.notice_label,ui.objective_label,ui.encounter_hint,ui.controls_hint]: l.visible=false
	var x: float=ui.get_viewport().get_visible_rect().size.x-ui.root.position.x-WIDTH-24
	ui.modal.set_meta("drawer_left",x)
	var shell:=Look.card(ui,ui.modal,Rect2(x,30,WIDTH,836),Look.PAPER,36,6)
	shell.name="CraftDrawer"
	shell.mouse_filter=Control.MOUSE_FILTER_STOP
	Look.chip(ui,ui.modal,"LUMI'S WORKSHOP",Rect2(x+28,47,188,28))
	Look.text(ui,ui.modal,"다음 사고를 준비하자!",Vector2(x+28,81),30,Look.INK,0,true)
	Look.chip(ui,ui.modal,"%d  마석"%g.economy.gold,Rect2(x+814,52,192,48),Look.MINT,Look.INK)
	Look.button(ui,ui.modal,"유물 %d"%g.relics.owned.size(),Rect2(x+689,56,108,40),ui.show_relics,false,17)
	for index in g.orb_recipes.size():
		Look.button(ui,ui.modal,"오브 %d +%d"%[index+1,g.orb_growth[index].rank],Rect2(x+355+index*82,106,76,28),func():g.select_orb(index),index==g.active_orb,14)
	var shown: Array=[0] if g.orb_recipes.size()==1 else ([0,1] if g.orb_recipes.size()==2 else [g.active_orb,(g.active_orb+1)%g.orb_recipes.size()])
	for row in shown.size(): orb_row(ui,shown[row],Vector2(x+24,140+row*106))
	for i in 4:
		var tab: Array=[["bag","가방"],["craft","마법 제작"],["fusion","합성 도감"],["workshop","오브·유물"]][i]
		var b:=Look.button(ui,ui.modal,tab[1],Rect2(x+24+i*150,367,142,42),func():ui.craft_tab=tab[0];ui.board_panel="fusion" if tab[0]=="fusion" else "item";ui.show_shop(),ui.craft_tab==tab[0],18)
		b.name="CraftTab_"+tab[0]
	if ui.craft_tab=="bag":
		for i in 4:
			var f: Array=[["all","전체"],["attack","공격"],["modifier","보조"],["connector","연결"]][i]
			Look.button(ui,ui.modal,f[1],Rect2(x+24+i*150,423,139,30),func():ui.bag_filter=f[0];ui.bag_scroll=0;ui.refresh_workbench(),ui.bag_filter==f[0],15)
		ui.Board.bag(ui,Rect2(x+22,463,600,274),6)
	elif ui.craft_tab=="fusion": fusion_catalog(ui,x)
	elif ui.craft_tab=="research": research(ui,x)
	elif ui.craft_tab=="workshop": workshop(ui,x)
	else: offers(ui,x)
	if ui.craft_tab=="fusion" and ui.board_panel=="fusion": Detail.wide_fusion(ui,Vector2(x+646,140))
	else: Detail.wide_item(ui,Vector2(x+646,140))
	var forecast:=Look.text(ui,ui.modal,g.Waves.forecast(g.wave+1),Vector2(x+28,752),13,Look.MUTED,590)
	forecast.name="WaveForecast"
	Look.bounded(forecast,2)
	var undo:=Look.button(ui,ui.modal,"↶ 되돌리기",Rect2(x+24,802,126,42),g.undo_draft,false,16)
	undo.disabled=g.edit_history.is_empty()
	Look.button(ui,ui.modal,"시험 발사",Rect2(x+162,802,164,42),g.start_trial,false,19).disabled=not g.valid_draft()
	Look.button(ui,ui.modal,"준비 완료  →",Rect2(x+754,793,256,55),g.launch_next_wave,true,24).disabled=not g.valid_draft()
	var note: String=g.workbench_message
	if not g.forge_message.is_empty(): note=g.forge_message
	if note.is_empty(): note="끌어서 이동  ·  우클릭으로 빼기"
	Look.bounded(Look.text(ui,ui.modal,note,Vector2(x+345,814),12,Look.MUTED,390),2)
	Look.button(ui,ui.modal,"발견 도감",Rect2(20,714,184,42),func():ui.show_collection("shop"),false,17).name="OpenCollection"
	Look.button(ui,ui.modal,"저장 후 타이틀",Rect2(20,769,224,42),g.save_and_title,false,17).name="SaveAndTitle"
	var save_note: String=g.checkpoint_message
	Look.bounded(Look.text(ui,ui.modal,save_note,Vector2(24,828),12,ui.TEXT,400),2)
	if not g.combat_rewards.pending.is_empty():
		Look.button(ui,ui.modal,"받지 않은 마법 %d"%g.combat_rewards.pending.size(),Rect2(20,659,224,42),func():g.open_personal("reward"),true,17)
	ui.Board.Crafting.apply_skin(ui,ui.modal)

static func workshop(ui: CanvasLayer, x: float) -> void:
	var g: Node2D=ui.game
	var revision: int=g.economy.revision
	var selected_orb: int=g.active_orb
	var value: Dictionary=g.orb_growth[selected_orb]
	Look.text(ui,ui.modal,"오브 %d +%d/5 · %d칸"%[selected_orb+1,value.rank,g.orb_capacity(selected_orb)],Vector2(x+24,426),20,Look.INK)
	var b:=Look.button(ui,ui.modal,"오브 최대 4개" if g.orb_recipes.size()>=4 else "오브 %d 추가 · %d 마석"%[g.orb_recipes.size()+1,g.extra_orb_cost()],Rect2(x+24,463,290,46),func():g.workshop_buy("orb",revision),false,18)
	b.name="BuyExtraOrb"
	b.disabled=not g.extra_orb_unlocked() or g.economy.gold<g.extra_orb_cost()
	b.tooltip_text="6·12·18분 휴식부터 순서대로 해금 · 빈 오브를 추가해요"
	var cost: int=g.OrbGrowth.cost(value)
	b=Look.button(ui,ui.modal,"최대 강화 완료" if value.rank>=5 else "이 오브 강화 · 3중 1택 · %d"%cost,Rect2(x+326,463,294,46),func():g.open_orb_growth(selected_orb,revision),false,17)
	b.name="UpgradeOrb"
	b.disabled=value.rank>=5 or g.economy.gold<cost
	if g.orb_growth_open==selected_orb and value.offers.size()==3:
		Look.text(ui,ui.modal,"하나를 고르면 %d 마석 소비 · 이 오브만 강화"%cost,Vector2(x+24,520),16,Look.PURPLE)
		var row:=HBoxContainer.new()
		row.name="OrbGrowthChoices"
		row.position=Vector2(x+24,550)
		row.size=Vector2(598,178)
		row.add_theme_constant_override("separation",9)
		ui.modal.add_child(row)
		for id in value.offers:
			var model:=View.orb_model(g,id,selected_orb)
			var card:=View.card(ui,row,model,Vector2(190,178),func():
				if g.economy.gold>=cost: g.choose_orb_growth(id,selected_orb,int(value.rank),revision)
			,"ChooseOrb_"+id,true)
			b=card.find_child("ChooseOrb_*",true,false)
			b.disabled=g.economy.gold<cost
	else:
		Look.bounded(Look.text(ui,ui.modal,g.OrbGrowth.summary(value),Vector2(x+24,518),14,Look.MUTED,590),2)
		Look.text(ui,ui.modal,"유물 제작 · 각각 80 마석",Vector2(x+24,560),20,Look.PURPLE)
		for i in g.workshop_relics.size():
			var id: String=g.workshop_relics[i]
			var d: Dictionary=g.Relics.definition(id)
			b=Look.button(ui,ui.modal,d.name,Rect2(x+24+i*201,602,190,100),func():g.workshop_buy("relic:"+id,revision),false,18)
			b.name="CraftRelic_"+id
			b.tooltip_text=d.desc
			b.disabled=g.relics.has(id) or g.economy.gold<80

static func orb_row(ui: CanvasLayer, index: int, at: Vector2) -> void:
	var g: Node2D=ui.game
	var parts: Array=g.orb_drafts[index]
	var color: Color=Look.MINT if index==0 else Look.PINK
	var tray:=Look.card(ui,ui.modal,Rect2(at,Vector2(598,86)),Color("f1eaf5"),23,0)
	tray.add_theme_stylebox_override("panel",Look.style(Color("f1eaf5"),Look.PURPLE if g.active_orb==index else Look.LINE,23))
	var b:=Look.button(ui,ui.modal,str(index+1),Rect2(at+Vector2(10,18),Vector2(54,54)),func():g.select_orb(index),false,28)
	b.name="OrbSelect%d"%index
	b.add_theme_stylebox_override("normal",Look.style(color,Look.PURPLE if g.active_orb==index else Look.LINE,40))
	b.tooltip_text="오브 %d · 클릭해서 편집할 오브 선택"%(index+1)
	var step: float=504.0/parts.size()
	for slot in parts.size():
		ui.Board.cell(ui,ui.modal,str(parts[slot]),Rect2(at+Vector2(80+slot*step,8),Vector2(step-7,70)),index,slot)
	var result: Dictionary=Spells.compile(parts)
	var summary: String=Spells.describe(parts) if Spells.has_content(parts) else "아직 빈 오브예요. 구체를 끌어 넣어보세요."
	var l:=Look.text(ui,ui.modal,summary,at+Vector2(5,88),12,Look.MUTED,588)
	l.name="ProgramSummary%d"%index
	Look.bounded(l)
	for slot in parts.size():
		if parts[slot]==ui.selected_item and Spells.definition(parts[slot]).kind=="modifier" and (ui.inspected_slot<0 or (ui.inspected_orb==index and ui.inspected_slot==slot)):
			for affected in Spells.affected_slots(parts,slot): ui.modal.get_node("Socket_%d_%d"%[index,affected]).set_meta("affected",true)

static func grid(ui: CanvasLayer, key: String, rect: Rect2, columns: int) -> GridContainer:
	var scroll:=ScrollContainer.new()
	scroll.name="CraftCatalog" if key in ["fusion","research"] else "CraftOffers"
	scroll.position=rect.position
	scroll.size=rect.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	scroll.set_deferred("scroll_vertical",int(ui.catalog_scroll.get(key,0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value):ui.catalog_scroll[key]=int(value))
	var grid:=GridContainer.new()
	grid.columns=columns
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	return grid

static func offers(ui: CanvasLayer, x: float) -> void:
	var g: Node2D=ui.game
	var revision: int=g.economy.revision
	Look.text(ui,ui.modal,"새 마법은 가방에 보관 · 원하는 칸에 직접 장착",Vector2(x+24,423),15,Look.MUTED,600)
	var list:=grid(ui,"offers",Rect2(x+24,454,602,230),2)
	for i in g.economy.offers.size():
		var offer: Dictionary=g.economy.offers[i]
		var row:=Control.new()
		row.custom_minimum_size=Vector2(286,122)
		list.add_child(row)
		Look.card(ui,row,Rect2(0,0,286,122),Color("f5edf8"),20,0)
		if not offer.id.is_empty(): ui.Board.cell(ui,row,offer.id,Rect2(10,10,76,77))
		else: Look.icon(ui,row,"charge",Rect2(16,17,62,62))
		if i==0:
			Look.button(ui,row,"직접 고르기",Rect2(97,12,176,34),func():ui.craft_tab="research";ui.show_shop(),false,17).disabled=g.economy.research_sold
		else:
			Look.bounded(Look.text(ui,row,Spells.definition(offer.id).name if not offer.id.is_empty() else "빈 제작안",Vector2(97,15),19,Look.INK,174,true))
		var title: String="제작 완료" if offer.sold else ("구체 선택 필요" if offer.id.is_empty() else "%d 마석 · 제작"%offer.price)
		var b:=Look.button(ui,row,title,Rect2(97,61,176,42),func():ui.Board.Crafting.buy(ui,i,revision),not offer.sold,17)
		b.name="CraftOffer%d"%i
		b.disabled=offer.sold or offer.id.is_empty() or g.economy.gold<offer.price
		if not offer.id.is_empty():
			var view:=View.model(g,offer.id,"craft")
			var placement: String=view.placement.get("text","")
			Look.bounded(Look.text(ui,row,view.badge+" · "+placement,Vector2(10,105),11,Look.PURPLE,266))
			row.tooltip_text=view.title+"\n"+view.change+"\n"+view.compare+"\n"+placement
	var reroll:=Look.button(ui,ui.modal,"↻  제작안 새로 뽑기  ·  5 마석",Rect2(x+24,699,598,38),func():g.reroll_shop(revision),false,17)
	reroll.disabled=g.economy.gold<5

static func fusion_catalog(ui: CanvasLayer, x: float) -> void:
	var list:=grid(ui,"fusion",Rect2(x+24,425,602,312),3)
	for id in P.FUSIONS:
		var recipe: Dictionary=P.FUSIONS[id]
		var owned:=0
		for parent in recipe.parents:
			if ui.game.economy.inventory.get(P.key(parent,3),0)>0: owned+=1
		var b:=Look.button(ui,list,"",Rect2(0,0,186,132),func():ui.fusion_choice=id;ui.board_panel="fusion";ui.show_shop(),ui.fusion_choice==id,17)
		b.custom_minimum_size=Vector2(186,132)
		b.text=recipe.name # Accessible name; custom labels are the visible presentation.
		b.add_theme_color_override("font_color",Color.TRANSPARENT)
		b.add_theme_color_override("font_hover_color",Color.TRANSPARENT)
		b.add_theme_color_override("font_focus_color",Color.TRANSPARENT)
		b.add_theme_color_override("font_pressed_color",Color.TRANSPARENT)
		Look.icon(ui,b,id,Rect2(67,8,50,50))
		var color: Color=Look.PAPER if ui.fusion_choice==id else Look.INK
		var l:=Look.text(ui,b,recipe.name,Vector2(6,65),17,color,174,true)
		l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		Look.bounded(l)
		l=Look.text(ui,b,"재료 %d / 2"%owned,Vector2(6,98),13,color,174)
		l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text=recipe.desc

static func research(ui: CanvasLayer, x: float) -> void:
	Look.button(ui,ui.modal,"← 제작안으로",Rect2(x+24,423,598,34),func():ui.craft_tab="craft";ui.show_shop(),false,17)
	var list:=grid(ui,"research",Rect2(x+24,469,602,268),3)
	var revision: int=ui.game.economy.revision
	for id in Spells.PARTS:
		if not ui.game.economy.can_stock(id): continue
		var b:=Look.button(ui,list,Spells.definition(id).name,Rect2(0,0,186,113),func():ui.craft_tab="craft";ui.game.select_research(id,revision),false,17)
		b.custom_minimum_size=Vector2(186,113)
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(key,Color.TRANSPARENT)
		Look.icon(ui,b,id,Rect2(68,6,47,47))
		var l:=Look.text(ui,b,Spells.definition(id).name,Vector2(4,57),17,Look.INK,178,true)
		l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		Look.bounded(l)
		l=Look.text(ui,b,"%d 마석"%ui.game.Economy.PRICES[id],Vector2(4,83),14,Look.PURPLE,178)
		l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text=Spells.definition(id).desc
