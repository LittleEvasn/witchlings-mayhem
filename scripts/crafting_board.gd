extends RefCounted
## Compact trial editor; preparation delegates to the broader rounded workbench.
const Spells = preload("res://scripts/spells.gd")
const P = preload("res://scripts/spell_progression.gd")
const Detail = preload("res://scripts/crafting_detail.gd")
const Workbench = preload("res://scripts/crafting_workbench.gd")
const Look = preload("res://scripts/mayhem_skin.gd")
const WIDTH := 520.0

static func build(ui: CanvasLayer, trial := false) -> void:
	if not trial:
		Workbench.build(ui)
		return
	var g: Node2D = ui.game
	ui.close_modal()
	ui.modal = Control.new()
	ui.modal.name = "CraftDrawerRoot"
	ui.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.modal.set_meta("craft_drawer",true)
	ui.modal.set_meta("rounded_ui",true)
	ui.root.add_child(ui.modal)
	ui.hud.visible = true
	if is_instance_valid(ui.recipe_bar): ui.recipe_bar.visible = false
	for hud_label in [ui.stats_label,ui.notice_label,ui.objective_label,ui.encounter_hint,ui.controls_hint]:
		if is_instance_valid(hud_label): hud_label.visible=false
	# root has a centered 1440px legacy safe area; anchor to the actual viewport edge.
	var x: float = ui.get_viewport().get_visible_rect().size.x-ui.root.position.x-WIDTH-24
	ui.modal.set_meta("drawer_left",x)
	var shell: Panel = ui.panel(ui.modal,Rect2(x,36,WIDTH,828),ui.INK)
	shell.name = "CraftDrawer"
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.label(ui.modal,"시험 발사" if trial else "개인 제작함",Vector2(x+22,52),24,ui.TEXT)
	ui.label(ui.modal,"%d 마석"%g.economy.gold,Vector2(x+335,58),18,ui.MINT)
	var owned: Button = ui.button(ui.modal,"유물 %d"%g.relics.owned.size(),Rect2(x+230,54,90,30),ui.show_relics,false,14)
	owned.disabled = trial
	if g.orb_recipes.size()>1:
		ui.button(ui.modal,"오브 %d/%d ↻"%[g.active_orb+1,g.orb_recipes.size()],Rect2(x+118,54,100,30),func():g.select_orb((g.active_orb+1)%g.orb_recipes.size()),false,13).name="TrialCycleOrb"
	var shown: Array=[0] if g.orb_recipes.size()==1 else ([0,1] if g.orb_recipes.size()==2 else [g.active_orb,(g.active_orb+1)%g.orb_recipes.size()])
	for row in shown.size(): orb_row(ui,shown[row],Vector2(x+22,106+row*104))
	var active: String = "bag" if trial else ui.craft_tab
	for i in 3:
		var tab: Array = [["bag","가방"],["craft","제작"],["fusion","합성 도감"]][i]
		var b: Button = ui.button(ui.modal,tab[1],Rect2(x+22+i*160,320,152,36),func():ui.craft_tab=tab[0];ui.board_panel="fusion" if tab[0]=="fusion" else "item";ui.show_shop(),active==tab[0],16)
		b.name="CraftTab_"+tab[0]
		b.disabled = trial
	if active=="bag":
		for i in 4:
			var f: Array = [["all","전체"],["attack","공격"],["modifier","보조"],["connector","연결"]][i]
			ui.button(ui.modal,f[1],Rect2(x+22+i*120,367,112,27),func():ui.bag_filter=f[0];ui.bag_scroll=0;ui.refresh_workbench(),ui.bag_filter==f[0],13)
		ui.Board.bag(ui,Rect2(x+18,402,484,182),6)
	elif active=="fusion": fusion_catalog(ui,x)
	elif active=="research": research(ui,x)
	else: offers(ui,x)
	if ui.board_panel=="fusion" and not trial: Detail.fusion(ui,x)
	else: Detail.item(ui,x,not trial)
	var undo: Button = ui.button(ui.modal,"↶",Rect2(x+22,804,42,38),g.undo_draft,false,20)
	undo.tooltip_text="되돌리기"
	undo.disabled = g.edit_history.is_empty()
	if trial:
		ui.button(ui.modal,"준비대로 · Esc",Rect2(x+78,804,420,38),g.end_trial,true,17)
		ui.trial_stats_label=ui.label(ui.modal,"",Vector2(36,794),14,ui.MINT,850)
		ui.update_trial_stats()
	else:
		ui.button(ui.modal,"시험 발사",Rect2(x+78,804,174,38),g.start_trial,false,17).disabled=not g.valid_draft()
		ui.button(ui.modal,"준비 완료 →",Rect2(x+264,804,234,38),g.launch_next_wave,true,18).disabled=not g.valid_draft()
		ui.button(ui.modal,"발견 도감",Rect2(36,686,220,42),func():ui.show_collection("shop"),false,17).name="OpenCollection"
		ui.button(ui.modal,"저장 후 타이틀",Rect2(36,742,300,42),g.save_and_title,false,17).name="SaveAndTitle"
		ui.label(ui.modal,g.checkpoint_message,Vector2(36,794),13,ui.MUTED,730).max_lines_visible=2
	var note: String = g.workbench_message
	if note.is_empty(): note="드래그로 이동 · 우클릭 해제 · 시간 제한 없음" if not trial else "표적만 있는 시험 · 전투와 마석은 그대로"
	ui.label(ui.modal,note,Vector2(x+24,844),11,ui.MUTED,474).max_lines_visible=1
	Look.restyle(ui,ui.modal)
	apply_skin(ui,ui.modal)

static func orb_row(ui: CanvasLayer, index: int, at: Vector2) -> void:
	var g: Node2D = ui.game
	var parts: Array = g.orb_drafts[index]
	var color: Color = ui.MINT if index==0 else ui.PINK
	var button: Button = ui.button(ui.modal,"오브 %d"%(index+1),Rect2(at,Vector2(84,25)),func():g.select_orb(index),false,14)
	button.name="OrbSelect%d"%index
	button.add_theme_color_override("font_color",color)
	var result: Dictionary = Spells.compile(parts)
	var summary: String = Spells.describe(parts) if Spells.has_content(parts) else "구체를 넣으면 함께 공격해요"
	var label: Label=ui.label(ui.modal,summary,at+Vector2(96,3),12,color,374)
	label.name="ProgramSummary%d"%index
	label.max_lines_visible=1
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text=summary
	var step: float=472.0/parts.size()
	for slot in parts.size():
		ui.Board.cell(ui,ui.modal,str(parts[slot]),Rect2(at+Vector2(slot*step,30),Vector2(step-6,64)),index,slot)
	for slot in parts.size():
		if parts[slot]==ui.selected_item and Spells.definition(parts[slot]).kind=="modifier" and (ui.inspected_slot<0 or (ui.inspected_orb==index and ui.inspected_slot==slot)):
			for affected in Spells.affected_slots(parts,slot):
				ui.modal.get_node("Socket_%d_%d"%[index,affected]).set_meta("affected",true)

static func scrolling(ui: CanvasLayer, key: String, rect: Rect2) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.name="CraftCatalog" if key in ["fusion","research"] else "CraftOffers"
	scroll.position=rect.position
	scroll.size=rect.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	scroll.set_deferred("scroll_vertical",int(ui.catalog_scroll.get(key,0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value):ui.catalog_scroll[key]=int(value))
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",7)
	scroll.add_child(list)
	return list

static func buy(ui: CanvasLayer, index: int, revision: int) -> void:
	if not ui.game.buy_orb(index,revision): return
	ui.craft_tab="bag"
	ui.inspect_item(ui.game.purchased_orb)

static func offers(ui: CanvasLayer, x: float) -> void:
	var g: Node2D=ui.game
	var revision: int=g.economy.revision
	var list:=scrolling(ui,"offers",Rect2(x+22,368,476,145))
	for i in g.economy.offers.size():
		var offer: Dictionary=g.economy.offers[i]
		var row:=Control.new()
		row.custom_minimum_size=Vector2(452,64)
		list.add_child(row)
		ui.panel(row,Rect2(0,0,452,64),ui.PANEL)
		if not offer.id.is_empty(): ui.Board.cell(ui,row,offer.id,Rect2(4,2,65,60))
		if i==0:
			ui.button(row,"지정 구체 고르기",Rect2(78,4,240,26),func():ui.craft_tab="research";ui.show_shop(),false,14).disabled=g.economy.research_sold
		else:
			ui.label(row,Spells.definition(offer.id).name,Vector2(78,6),16,ui.TEXT,235).max_lines_visible=1
		var title: String="제작 완료" if offer.sold else ("선택 필요" if offer.id.is_empty() else "%d 마석 · 제작"%offer.price)
		var b: Button=ui.button(row,title,Rect2(78,34,360,26),func():buy(ui,i,revision),false,14)
		b.name="CraftOffer%d"%i
		b.disabled=offer.sold or offer.id.is_empty() or g.economy.gold<offer.price
	ui.button(ui.modal,"제작안 재구성 · 5 마석",Rect2(x+22,520,476,28),func():g.reroll_shop(revision),false,14).disabled=g.economy.gold<5
	var forecast: Label=ui.label(ui.modal,g.Waves.forecast(g.wave+1),Vector2(x+24,554),12,ui.MUTED,472)
	forecast.name="WaveForecast"
	forecast.max_lines_visible=2
	forecast.tooltip_text=g.shop_message

static func fusion_catalog(ui: CanvasLayer, x: float) -> void:
	var list:=scrolling(ui,"fusion",Rect2(x+22,368,476,215))
	for id in P.FUSIONS:
		var recipe: Dictionary=P.FUSIONS[id]
		var owned:=0
		for parent in recipe.parents:
			if ui.game.economy.inventory.get(P.key(parent,3),0)>0: owned+=1
		var b: Button=ui.button(list,ui.Board.glyph(id)+"  "+recipe.name+"  ·  재료 %d/2"%owned,Rect2(0,0,452,43),func():ui.fusion_choice=id;ui.board_panel="fusion";ui.show_shop(),ui.fusion_choice==id,16)
		b.custom_minimum_size=Vector2(452,43)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.tooltip_text=recipe.desc

static func research(ui: CanvasLayer, x: float) -> void:
	ui.button(ui.modal,"← 제작안으로",Rect2(x+22,367,476,28),func():ui.craft_tab="craft";ui.show_shop(),false,14)
	var list:=scrolling(ui,"research",Rect2(x+22,402,476,180))
	var revision: int=ui.game.economy.revision
	for id in Spells.PARTS:
		if not ui.game.economy.can_stock(id): continue
		var b: Button=ui.button(list,ui.Board.glyph(id)+"  "+Spells.definition(id).name+"  ·  %d 마석"%ui.game.Economy.PRICES[id],Rect2(0,0,452,36),func():ui.craft_tab="craft";ui.game.select_research(id,revision),false,15)
		b.custom_minimum_size=Vector2(452,36)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.tooltip_text=Spells.definition(id).desc

static func apply_skin(ui: CanvasLayer, node: Node) -> void:
	if ui.crafting_theme==null: return
	if node==ui.modal: ui.modal.theme=ui.crafting_theme
	var type_name: String="CraftButton" if node is Button else "CraftPanel" if node is Panel else ""
	if not type_name.is_empty() and ui.crafting_theme.has_stylebox("normal" if node is Button else "panel",type_name):
		node.theme_type_variation=type_name
		for key in ["normal","hover","pressed","disabled","focus"] if node is Button else ["panel"]:
			node.remove_theme_stylebox_override(key)
	for child in node.get_children(): apply_skin(ui,child)
