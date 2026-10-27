extends RefCounted
## Deterministic UI fixture; never used by normal startup.
static func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found := find_button(child,prefix)
		if found!=null: return found
	return null
static func click(game: Node, prefix: String) -> bool:
	var button := find_button(game,prefix)
	if button==null or button.disabled: return false
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	game.get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		game.get_viewport().push_input(event,true)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	return true
static func prepare(game: Node) -> Dictionary:
	game.start_run("sigil")
	game.set_physics_process(false)
	game.sound_enabled = false
	game.complete_wave()
	game.choose_reward("power")
	for id in game.Spells.PARTS: game.economy.inventory[id] = 4
	game.orb_drafts = [[],[]]
	game.draft = []
	game.add_part("frost")
	game.add_part("seek")
	game.select_orb(1)
	game.add_part("bolt")
	game.add_part("shatter")
	game.add_part("fan")
	game.apply_recipe()
	game.select_orb(0)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var tab := await click(game,"오브 2 ·")
	var selected: bool = game.active_orb==1
	var move := await click(game,"다른 오브로")
	var moved: bool = game.orb_drafts[1].is_empty() and game.orb_drafts[0].size()==6
	var undo := await click(game,"되돌리기")
	var restored: bool = game.orb_drafts[1]==["shatter","fan","bolt"]
	return {"tab_click":tab and selected,"group_move_click":move and moved,"undo_click":undo and restored}
static func capture_trial(game: Node) -> Dictionary:
	var started := await click(game,"시험 발사")
	game.cast_target = Vector2(820,310)
	game.orb_clocks = [0,0]
	game._tick_orbs(0.02)
	for i in 12:
		game._update_projectiles(1.0/60)
		game.magic.update_zones(1.0/60)
		game._update_effects(1.0/60)
	game.visuals.queue_redraw()
	await game.get_tree().process_frame
	return {"trial_click":started and game.state=="trial","both_orbs":game.orb_trial[0].size()>0 and game.orb_trial[1].size()>0,"projectiles":game.projectiles.size()}
