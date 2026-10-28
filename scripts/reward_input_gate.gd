extends Node
## A held combat click/confirm must be released before any reward action is armed.
var armed:=false
var until:=0
var buttons: Array=[]
var preferred: Button
func _ready() -> void: until=Time.get_ticks_msec()+180
func held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0,JOY_BUTTON_A)
func allow() -> bool: return armed
func _process(_delta: float) -> void:
	if armed: return
	if Time.get_ticks_msec()<until or held(): return
	armed=true
	for button in buttons:
		if is_instance_valid(button): button.disabled=false
	if is_instance_valid(preferred): preferred.grab_focus()
func guard(button: Button) -> void:
	button.focus_mode=Control.FOCUS_ALL
	button.disabled=true
	buttons.append(button)
