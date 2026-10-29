extends ScrollContainer
## Keep a continuous bag usable while dragging across its viewport edges.
func _process(delta: float) -> void:
	if not get_viewport().gui_is_dragging(): return
	var point:=get_global_mouse_position()
	var rect:=get_global_rect()
	if point.y<rect.position.y-10 or point.y>rect.end.y+10: return
	if point.x>=rect.position.x-12 and point.x<rect.position.x+34:
		scroll_horizontal-=ceili(480*delta)
	elif point.x>rect.end.x-34 and point.x<=rect.end.x+12:
		scroll_horizontal+=ceili(480*delta)

func reveal(cell: Control) -> void:
	if is_instance_valid(cell): ensure_control_visible(cell)
