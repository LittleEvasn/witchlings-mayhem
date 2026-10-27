extends RefCounted
## A local drawer over the live battlefield. Preparation keeps its existing full board.
const WIDTH := 416.0

static func text(ui: CanvasLayer, parent: Node, value: String, font_size := 16, color := Color("f5f0e6")) -> Label:
	var l:=Label.new()
	l.text=value
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func button(ui: CanvasLayer, parent: Node, value: String, action: Callable) -> Button:
	var b:=Button.new()
	b.text=value
	b.custom_minimum_size=Vector2(0,34)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",ui.box(ui.PANEL,ui.BORDER,1,9))
	b.add_theme_stylebox_override("hover",ui.box(Color("303a50"),ui.MINT,1,9))
	b.add_theme_font_size_override("font_size",15)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func build(ui: CanvasLayer) -> void:
	ui.close_personal_visual()
	var g: Node2D=ui.game
	var panel:=PanelContainer.new()
	panel.name="PersonalWindow"
	ui.root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left=-WIDTH-16
	panel.offset_right=-16
	panel.offset_top=112
	panel.offset_bottom=-106
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",ui.box(Color(0.07,0.09,0.14,.96),ui.BORDER,1,16))
	ui.personal_root=panel
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	var header:=HBoxContainer.new()
	column.add_child(header)
	var title:=text(ui,header,"개인 준비함",21,ui.MINT)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(ui,header,"닫기",g.close_personal).size_flags_horizontal=Control.SIZE_SHRINK_END
	var tabs:=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	column.add_child(tabs)
	for item in [["inventory","조합"],["reward","마법 선택 %d"%g.combat_rewards.pending.size()],["relics","유물"]]:
		var tab: String=item[0]
		var b:=button(ui,tabs,item[1],func():g.open_personal(tab))
		if tab==g.personal_tab: b.add_theme_color_override("font_color",ui.MINT)
	if g.personal_tab=="relics": relics(ui,column)
	else: inventory(ui,column)
	ui.personal_danger=text(ui,column,"",12,ui.PINK)
	text(ui,column,"전투 계속 · WASD 이동 · Space 회피 · Tab 닫기",12,ui.MUTED)

static func inventory(ui: CanvasLayer, parent: Node) -> void:
	var g: Node2D=ui.game
	for index in g.orb_drafts.size():
		var parts: Array=g.orb_drafts[index]
		text(ui,parent,"오브 %d · %d번째 가까운 적"%[index+1,index+1],14,ui.MINT if index==0 else ui.PINK)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",4)
		parent.add_child(row)
		var result: Dictionary=g.Spells.compile(parts)
		for slot in 6:
			var id: String=parts[slot] if slot<parts.size() else ""
			var cell: Control=ui.Board.cell(ui,row,id,Rect2(0,0,56,58),index,slot)
			cell.custom_minimum_size=Vector2(56,58)
			if not parts.is_empty() and not result.ok and result.error_index==slot: cell.set_meta("invalid",true)
			if ui.inspected_orb==index and ui.inspected_slot>=0 and ui.inspected_slot<parts.size():
				if slot in g.Spells.affected_slots(parts,ui.inspected_slot): cell.set_meta("affected",true)
		var error:=text(ui,parent,result.error if not result.ok and not parts.is_empty() else "",12,ui.PINK)
		error.visible=not result.ok and not parts.is_empty()
	var bag_header:=HBoxContainer.new()
	parent.add_child(bag_header)
	text(ui,bag_header,"가방 · 여분 수량",15,ui.MUTED).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(ui,bag_header,"↶ 되돌리기",g.undo_draft).disabled=g.edit_history.is_empty()
	var backdrop: Control=ui.Board.Slot.new()
	backdrop.ui=ui
	backdrop.inventory=true
	backdrop.backdrop=true
	backdrop.name="PersonalBagDropArea"
	backdrop.custom_minimum_size=Vector2(0,130)
	backdrop.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(backdrop)
	var scroll:=ScrollContainer.new()
	backdrop.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode=Control.FOCUS_NONE
	var grid:=GridContainer.new()
	grid.columns=6
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	scroll.add_child(grid)
	for id in g.economy.inventory:
		if g.economy.inventory[id]<=0: continue
		var cell: Control=ui.Board.cell(ui,grid,id,Rect2(0,0,56,58),-1,-1,true)
		cell.custom_minimum_size=Vector2(56,58)
	var selected: String=ui.selected_item
	if not selected.is_empty() and g.Spells.has_part(selected):
		var d: Dictionary=g.Spells.definition(selected)
		text(ui,parent,d.name,16,d.color)
		var description:=text(ui,parent,d.desc,13,ui.MUTED)
		description.max_lines_visible=3
		description.tooltip_text=d.desc
	else: text(ui,parent,"구체 선택 → 빈칸 클릭 / 끌어서 순서 변경",13,ui.MUTED)
	var note:=text(ui,parent,g.workbench_message if not g.workbench_message.is_empty() else "가운데 교체 · 가장자리 삽입 · 우클릭 해제",12,ui.PINK if not g.workbench_message.is_empty() else ui.MUTED)
	note.max_lines_visible=2

static func relics(ui: CanvasLayer, parent: Node) -> void:
	text(ui,parent,"이번 실험의 유물",18,ui.MINT)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	for id in ui.game.relics.owned:
		var d: Dictionary=ui.game.Relics.definition(id)
		text(ui,list,d.name,18,ui.MINT)
		text(ui,list,d.desc,15,ui.TEXT).tooltip_text=ui.game.relics.tooltip(id,ui.game.economy.gold)
	if ui.game.relics.owned.is_empty(): text(ui,list,"웨이브를 마치면 유물을 제작할 수 있어.",15,ui.MUTED)
