extends RefCounted
## Native-window probe: exercises the engine's GUI event routing, not just model methods.
var g: Node2D
var reports: Array = []

func record(ok: bool, text: String) -> void:
	reports.append({"ok":ok,"check":text})

func frames(count := 2) -> void:
	for i in count: await g.get_tree().process_frame

func mouse(at: Vector2, pressed: bool) -> void:
	g.get_viewport().warp_mouse(at)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	g.get_viewport().push_input(event,true)

func motion(at: Vector2, relative: Vector2) -> void:
	g.get_viewport().warp_mouse(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	g.get_viewport().push_input(event,true)

func click(at: Vector2) -> void:
	g.get_viewport().warp_mouse(at)
	await frames()
	mouse(at,true)
	mouse(at,false)
	await frames()

func drag_start(at: Vector2) -> void:
	g.get_viewport().warp_mouse(at)
	await frames()
	mouse(at,true)
	motion(at+Vector2(15,-15),Vector2(15,-15))
	await frames()

func drag_end(at: Vector2) -> void:
	motion(at,Vector2(40,-20))
	await frames()
	mouse(at,false)
	await frames()

func run(owner_game: Node2D) -> Array:
	g = owner_game
	g.set_physics_process(false)
	g.sound_enabled = false
	g.start_run()
	g.complete_wave()
	g.choose_reward("power")
	g.economy.gold = 100
	g.economy.offers = [{"id":"echo","price":18,"sold":false},{"id":"vortex","price":18,"sold":false},{"id":"bounce","price":14,"sold":false},{"id":"boomerang","price":14,"sold":false}]
	g.ui.show_shop()
	await click(Vector2(250,321))
	record(g.economy.inventory.get("echo",0) == 1 and g.economy.gold == 82,"Actual shop button buys new orb")
	await click(Vector2(1180,580))
	record(g.draft == ["bolt","impact","bloom","fan"],"Actual inventory click appends an orb")
	await drag_start(Vector2(770,468))
	record(g.get_viewport().gui_is_dragging(),"Engine starts native drag from equipped slot")
	await drag_end(Vector2(158,468))
	record(g.draft == ["fan","bolt","impact","bloom"],"Native equipped drag inserts earlier without release-click removing another orb")
	await drag_start(Vector2(1000,652))
	await drag_end(Vector2(158,468))
	record(g.draft == ["echo","fan","bolt","impact","bloom"],"Native purchased-orb drag inserts into current recipe")
	var before: Array = g.draft.duplicate()
	await drag_start(Vector2(225,468))
	await drag_end(Vector2(40,420))
	record(g.draft == before and not g.get_viewport().gui_is_dragging(),"Invalid native drop cancels without loss")
	await drag_start(Vector2(225,468))
	await drag_end(Vector2(225,580))
	record(g.draft == ["fan","bolt","impact","bloom"] and g.economy.remaining("echo",g.draft) == 1,"Native drop on inventory returns equipped copy")
	await click(Vector2(720,724))
	record(g.state == "trial","Actual trial button opens arena and compact editor")
	g.get_viewport().warp_mouse(Vector2(690,260))
	await frames()
	for i in 100: g._physics_process(1.0/60)
	record(g.trial_hits > 0 and g.shop_time == 60,"Mouse aiming in trial damages targets with paused shop clock")
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/workbench-trial.png"))
	await click(Vector2(1130,845))
	record(g.state == "shop" and g.enemies.is_empty(),"Actual return button clears targets and restores shop")
	await drag_start(Vector2(225,468))
	record(g.get_viewport().gui_is_dragging(),"Native drag can be active when shop timer expires")
	g.shop_time = 0.001
	g._physics_process(0.002)
	await frames()
	await drag_end(Vector2(650,468))
	record(g.state == "combat" and g.draft == g.recipe and g.economy.inventory.echo == 1,"Native drag across timeout cannot change recipe or lose purchased items")
	g.start_run()
	g.open_editor()
	await click(Vector2(1180,468))
	record(g.draft == ["bolt","impact","bloom","fan"],"Combat editor retains click editing")
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	g.get_viewport().push_input(cancel,true)
	await frames()
	record(g.state == "combat" and g.draft == g.recipe,"Actual Escape cancels combat edits")
	g.start_run()
	g.state = "title"
	g.sound_enabled = true
	g.set_physics_process(true)
	g.ui.show_title()
	return reports
