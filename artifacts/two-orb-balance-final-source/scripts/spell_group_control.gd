extends Panel
var game: Node2D
var group_index := 0
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		game.focus_group(group_index)
		accept_event()
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return game.can_drop_group_part(data,group_index)
func _drop_data(_at: Vector2, data: Variant) -> void:
	game.drop_group_part(data,group_index)
