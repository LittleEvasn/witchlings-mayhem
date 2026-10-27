extends Control
## Native Godot drag/drop. The inventory changes only after a validated drop.
var workbench: CanvasLayer
var orb_id := ""
var slot := -1
var inventory := false
var pressed_here := false
var dragged := false
var press_position := Vector2.ZERO
var drop_edge := -1
var background: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not inventory:
			workbench.game.remove_part(slot)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed_here = true
				dragged = false
				press_position = event.position
			elif pressed_here:
				pressed_here = false
				if not dragged and event.position.distance_to(press_position) < 8 and Rect2(Vector2.ZERO,size).has_point(event.position):
					if inventory: workbench.game.add_part(orb_id)
					else: workbench.game.remove_part(slot)
			accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if orb_id.is_empty(): return null
	var data: Dictionary = workbench.game.orb_drag_data(orb_id,-1 if inventory else slot)
	if data.is_empty(): return null
	dragged = true
	pressed_here = false
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := Panel.new()
	card.position = Vector2(-78,-30)
	card.size = Vector2(156,60)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",workbench.box(workbench.PANEL,workbench.Spells.PARTS[orb_id].color,2,10))
	preview.add_child(card)
	var text := Label.new()
	text.text = workbench.Spells.PARTS[orb_id].name
	text.size = card.size
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font",workbench.font)
	text.add_theme_font_size_override("font_size",16)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(text)
	set_drag_preview(preview)
	modulate.a = 0.45
	return data

func boundary(at_position: Vector2) -> int:
	return mini(workbench.game.draft.size(),slot+(1 if at_position.x > size.x*0.5 else 0))

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return workbench.game.can_drop_orb(data,boundary(at_position),inventory)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	workbench.game.drop_orb(data,boundary(at_position),inventory)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1
		pressed_here = false
		dragged = false
		drop_edge = -1
		queue_redraw()

func _process(_delta: float) -> void:
	var edge := -1
	if get_viewport().gui_is_dragging():
		var at := get_local_mouse_position()
		if Rect2(Vector2.ZERO,size).has_point(at) and _can_drop_data(at,get_viewport().gui_get_drag_data()):
			edge = 2 if inventory else (0 if at.x <= size.x*0.5 or slot >= workbench.game.draft.size() else 1)
	if edge != drop_edge:
		drop_edge = edge
		queue_redraw()

func _draw() -> void:
	if background: draw_style_box(background,Rect2(Vector2.ZERO,size))
	if drop_edge == 2:
		draw_rect(Rect2(Vector2.ONE*2,size-Vector2.ONE*4),workbench.MINT,false,3)
	elif drop_edge >= 0:
		var x := 3.0 if drop_edge == 0 else size.x-3
		draw_line(Vector2(x,3),Vector2(x,size.y-3),workbench.MINT,4,true)
