extends RefCounted
## Shared real slot controls: one bag strip and one strip per owned orb, no large shell.
const Look=preload("res://scripts/mayhem_skin.gd")
const CELL:=44.0
const GAP:=4
const PAGE_SIZE:=12

static func tray(ui: CanvasLayer, parent: Node, color: Color) -> HBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var style:=Look.style(Color(.055,.065,.105,.93),color.darkened(.4),14)
	style.content_margin_left=5;style.content_margin_right=5
	style.content_margin_top=4;style.content_margin_bottom=4
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",GAP)
	panel.add_child(row)
	return row

static func build(ui: CanvasLayer, parent: Node, reward := false) -> Control:
	var g: Node2D=ui.game
	var shell:=VBoxContainer.new()
	shell.name="CompactInventory"
	var scale_factor: float=minf(1,ui.get_viewport().get_visible_rect().size.y/900.0)
	shell.position=Vector2(20-ui.root.position.x,142*scale_factor)
	shell.scale=Vector2.ONE*scale_factor
	shell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shell.add_theme_constant_override("separation",5)
	parent.add_child(shell)
	var bank: Array=[]
	for id in g.economy.inventory:
		if g.remaining_part(id)>0: bank.append(id)
	var pages:=maxi(1,ceili(bank.size()/float(PAGE_SIZE)))
	ui.compact_bag_page=clampi(ui.compact_bag_page,0,pages-1)
	var bag:=tray(ui,shell,ui.MINT)
	bag.name="CompactBagStrip"
	var badge:=Look.text(ui,bag,"가방",Vector2.ZERO,15,ui.MINT,44,true)
	badge.custom_minimum_size=Vector2(44,CELL)
	badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	# The entire empty bag strip accepts removing an equipped item, including blank slots.
	var drop: Control=ui.Board.Slot.new()
	drop.name="PersonalBagDropArea";drop.ui=ui;drop.inventory=true;drop.backdrop=true
	drop.custom_minimum_size=Vector2(PAGE_SIZE*(CELL+GAP)-GAP,CELL)
	bag.add_child(drop)
	var cells:=HBoxContainer.new()
	cells.add_theme_constant_override("separation",GAP)
	cells.mouse_filter=Control.MOUSE_FILTER_PASS
	drop.add_child(cells)
	for i in PAGE_SIZE:
		var index: int=ui.compact_bag_page*PAGE_SIZE+i
		var token: String=bank[index] if index<bank.size() else ""
		var cell: Control=ui.Board.cell(ui,cells,token,Rect2(0,0,CELL,CELL),-1,-1,true,true)
		cell.custom_minimum_size=Vector2.ONE*CELL
		if token.is_empty(): cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var previous:=Look.button(ui,bag,"‹",Rect2(0,0,28,CELL),func():ui.compact_bag_page-=1;ui.refresh_workbench.call_deferred(),false,21)
	previous.name="BagPreviousPage";previous.custom_minimum_size=Vector2(28,CELL);previous.disabled=ui.compact_bag_page==0
	var page:=Look.text(ui,bag,"%d/%d"%[ui.compact_bag_page+1,pages],Vector2.ZERO,12,ui.MUTED,26)
	page.custom_minimum_size=Vector2(26,CELL);page.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var next:=Look.button(ui,bag,"›",Rect2(0,0,28,CELL),func():ui.compact_bag_page+=1;ui.refresh_workbench.call_deferred(),false,21)
	next.name="BagNextPage";next.custom_minimum_size=Vector2(28,CELL);next.disabled=ui.compact_bag_page>=pages-1
	for orb in g.orb_drafts.size():
		var parts: Array=g.orb_drafts[orb]
		var color: Color=ui.MINT if orb==0 else ui.PINK
		var row:=tray(ui,shell,color)
		row.name="CompactOrb%d"%orb
		var select:=Look.button(ui,row,str(orb+1),Rect2(0,0,CELL,CELL),func():g.select_orb(orb),false,22)
		select.name="OrbSelect%d"%orb;select.custom_minimum_size=Vector2.ONE*CELL
		select.add_theme_stylebox_override("normal",Look.style(Color("273040"),color,24))
		select.add_theme_color_override("font_color",color)
		select.tooltip_text="오브 %d · +%d · %d칸\n%s"%[orb+1,g.orb_growth[orb].rank,parts.size(),g.Spells.describe(parts)]
		for slot in parts.size():
			var cell: Control=ui.Board.cell(ui,row,parts[slot],Rect2(0,0,CELL,CELL),orb,slot,false,true)
			cell.custom_minimum_size=Vector2.ONE*CELL
			if ui.inspected_orb==orb and slot in g.Spells.affected_slots(parts,ui.inspected_slot): cell.set_meta("affected",true)
	if not g.relics.owned.is_empty():
		var row:=HBoxContainer.new()
		row.name="CompactRelics";row.add_theme_constant_override("separation",4)
		shell.add_child(row)
		for id in g.relics.owned:
			var relic: Dictionary=g.Relics.definition(id)
			var b:=Button.new();b.text=relic.glyph;b.custom_minimum_size=Vector2(30,26)
			b.tooltip_text=relic.name+"\n"+g.relics.tooltip(id,g.economy.gold)
			b.add_theme_stylebox_override("normal",Look.style(Color(.055,.065,.105,.9),ui.BORDER,12))
			b.mouse_default_cursor_shape=Control.CURSOR_HELP
			row.add_child(b)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",8)
	shell.add_child(footer)
	var undo:=Look.button(ui,footer,"↶ 되돌리기",Rect2(0,0,112,28),g.undo_draft,false,15)
	undo.name="InventoryUndo";undo.custom_minimum_size=Vector2(112,28);undo.disabled=g.edit_history.is_empty()
	if not reward:
		var close:=Look.button(ui,footer,"닫기 · Tab",Rect2(0,0,112,28),g.close_personal,false,15)
		close.name="CloseCompactInventory";close.custom_minimum_size=Vector2(112,28)
	var hint:=Look.text(ui,footer,"전투 정지 · 자유롭게 편집" if reward else "전투 계속 · 드래그 / 우클릭 해제",Vector2.ZERO,13,ui.MINT)
	hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if not g.workbench_message.is_empty(): hint.text=g.workbench_message;hint.add_theme_color_override("font_color",ui.PINK)
	ui.recipe_bar.visible=false
	return shell
