extends Control
## Shared inventory/socket control. Edges insert; the centre swaps/replaces.
const Spells = preload("res://scripts/spells.gd")
var ui: CanvasLayer
var id := ""
var orb_index := -1
var slot := -1
var inventory := false
var backdrop := false
var hover := false
var pressed := false
var dragging := false
var marker := -1
var stamp := -1
var stock := -1
var read_only := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if backdrop else Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stamp = ui.game.edit_revision
	stock = ui.game.economy.revision
	mouse_entered.connect(func(): hover=true; queue_redraw())
	mouse_exited.connect(func(): hover=false; queue_redraw())
	if not id.is_empty(): tooltip_text = Spells.definition(id).name+"\n"+Spells.definition(id).desc

func _gui_input(event: InputEvent) -> void:
	if backdrop or not event is InputEventMouseButton: return
	if stamp!=ui.game.edit_revision or stock!=ui.game.economy.revision: return
	if read_only:
		if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: ui.inspect_item(id)
		accept_event()
		return
	if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and not inventory and not id.is_empty():
		ui.game.board_drop(ui.game.board_data(id,orb_index,slot),-1,0)
		accept_event()
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed=true
			dragging=false
			if event.double_click and inventory and not id.is_empty(): ui.game.board_quick_equip(id)
		elif pressed and not dragging:
			pressed=false
			if id.is_empty() and not inventory and not ui.selected_item.is_empty():
				ui.game.board_drop(ui.game.board_data(ui.selected_item),orb_index,slot)
			elif not id.is_empty(): ui.inspect_item(id,orb_index,slot)
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	if read_only or id.is_empty() or stamp!=ui.game.edit_revision or stock!=ui.game.economy.revision: return null
	var data: Dictionary = ui.game.board_data(id,-1 if inventory else orb_index,-1 if inventory else slot)
	if data.is_empty(): return null
	dragging=true
	pressed=false
	var preview := Control.new()
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var icon := Label.new()
	icon.text=ui.Board.glyph(id)
	icon.position=Vector2(-32,-32)
	icon.size=Vector2(64,64)
	icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_override("font",ui.font)
	icon.add_theme_font_size_override("font_size",42)
	icon.add_theme_color_override("font_color",Spells.definition(id).color)
	preview.add_child(icon)
	set_drag_preview(preview)
	modulate.a=0.4
	return data

func target(at: Vector2) -> Dictionary:
	if inventory: return {"orb":-1,"at":0,"replace":false}
	var parts: Array = ui.game.draft if orb_index==ui.game.active_orb else ui.game.orb_drafts[orb_index]
	var full := slot<parts.size()
	var replace := full and at.x>size.x*0.25 and at.x<size.x*0.75
	return {"orb":orb_index,"at":mini(parts.size(),slot+(1 if full and at.x>=size.x*0.75 else 0)),"replace":replace}

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if read_only: return false
	var t := target(at)
	return not ui.game.board_plan(data,t.orb,t.at,t.replace).is_empty()

func _drop_data(at: Vector2, data: Variant) -> void:
	var t := target(at)
	ui.game.board_drop(data,t.orb,t.at,t.replace)

func _process(_delta: float) -> void:
	var next := -1
	if get_viewport().gui_is_dragging() and Rect2(Vector2.ZERO,size).has_point(get_local_mouse_position()):
		if _can_drop_data(get_local_mouse_position(),get_viewport().gui_get_drag_data()):
			var t := target(get_local_mouse_position())
			next=2 if inventory or t.replace else (0 if get_local_mouse_position().x<size.x*0.5 else 1)
	if next!=marker: marker=next; queue_redraw()

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END:
		modulate.a=1
		dragging=false
		pressed=false
		marker=-1
		queue_redraw()

func _draw() -> void:
	if not backdrop:
		var color: Color = ui.BORDER if id.is_empty() else Spells.definition(id).color
		var selected: bool = not id.is_empty() and id==ui.selected_item
		var available: bool = not inventory or ui.game.remaining_part(id)>0
		var bg := Color("2b3348") if hover else Color("121a2b")
		var skin: StyleBox
		var state_name := "selected" if selected else "hover" if hover else "normal"
		if ui.crafting_theme!=null and ui.crafting_theme.has_stylebox(state_name,"CraftSlot"):
			skin=ui.crafting_theme.get_stylebox(state_name,"CraftSlot")
		draw_style_box(skin if skin!=null else ui.box(bg,color if selected or hover else color.darkened(0.55),2 if selected else 1,12),Rect2(Vector2.ZERO,size))
		if not id.is_empty():
			var center := Vector2(size.x*0.5,size.y*0.40)
			draw_circle(center,size.y*0.27,Color(color,0.12 if available else 0.04))
			draw_arc(center,size.y*0.27,0,TAU,40,Color(color,0.4 if available else 0.1),1.0,true)
	if get_meta("affected",false): draw_style_box(ui.box(Color(0.6,1,0.9,0.10),ui.MINT,3,12),Rect2(Vector2.ONE,size-Vector2.ONE*2))
	if get_meta("invalid",false): draw_style_box(ui.box(Color(1,0.3,0.5,0.08),ui.PINK,3,12),Rect2(Vector2.ONE,size-Vector2.ONE*2))
	if marker==2: draw_style_box(ui.box(Color(0.6,1,0.9,0.12),ui.MINT,2,12),Rect2(Vector2.ONE,size-Vector2.ONE*2))
	elif marker>=0:
		var x:=2.0 if marker==0 else size.x-2
		draw_line(Vector2(x,2),Vector2(x,size.y-2),ui.MINT,4,true)
