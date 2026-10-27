extends RefCounted
## Reproducible UI and rendered combat fixture, not a human balance/fun evaluation.
func capture(g: Node2D, name: String) -> void:
	g.visuals.queue_redraw()
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png("res://artifacts/magic-v2-"+name+".png")

func run(g: Node2D) -> Dictionary:
	g.record_runs = false
	g.sound_enabled = false
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.clear()
	g.encounters.enabled = false
	g.invincible = 9999
	g.wave = 4
	g.meter = load("res://scripts/combat_meter.gd").new()
	g.economy.inventory = {"fan@3":1,"echo@3":1,"seek@3":1,"bolt@3":1,"ember_path@3":1,"boomerang@3":1,"satellite@3":1,"impact@2":1,"impact":1,"frost@3":1}
	g.orb_recipes = [["fan@3","echo@3","seek@3","bolt@3"],["ember_path@3"]]
	g.orb_drafts = g.orb_recipes.duplicate(true)
	g.recipe = g.orb_recipes[0].duplicate()
	g.draft = g.recipe.duplicate()
	g._commit_live_board()
	g.orb_clocks = [0.0,0.0]
	for n in 48:
		var e = g.Actor.new()
		g.actors.add_child(e)
		e.setup(g.art,1)
		e.position = g.player.position+Vector2.RIGHT.rotated(n*TAU/48)*(180+(n%4)*80)
		e.hp = 100000
		e.max_hp = e.hp
		e.speed = 0
		g.enemies.append(e)
	var frame_times: Array = []
	var simulation: Array = []
	var last := Time.get_ticks_usec()
	var peak_p := 0
	var peak_z := 0
	for frame in 180:
		var start := Time.get_ticks_usec()
		g.player.position += Vector2(0.8,0.25)
		g._physics_process(1.0/60)
		simulation.append((Time.get_ticks_usec()-start)/1000.0)
		peak_p = maxi(peak_p,g.projectiles.size())
		peak_z = maxi(peak_z,g.magic.zones.size())
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if frame>30: frame_times.append((now-last)/1000.0)
		last = now
	await capture(g,"rendered-combat")
	frame_times.sort()
	simulation.sort()
	var result := {"seed":731,"fixture":"48 stationary high-health enemies; invulnerable player; fixed 1/60 simulation; two upgraded orbs","frames":180,"frame_p95_ms":frame_times[int(frame_times.size()*.95)],"simulation_p95_ms":simulation[int(simulation.size()*.95)],"peak_projectiles":peak_p,"peak_paths":peak_z,"totals":g.meter.totals.duplicate()}
	g.clear_magic()
	for e in g.enemies: e.queue_free()
	g.enemies.clear()
	g.grid.clear()
	g.orb_recipes = [["bolt@3","impact@2","satellite@3"],[]]
	g.orb_drafts = g.orb_recipes.duplicate(true)
	g.recipe = g.orb_recipes[0].duplicate()
	g.draft = g.recipe.duplicate()
	g._commit_live_board()
	g.state = "shop"
	g.shop_time = INF
	g.economy.gold = 200
	g.ui.selected_item = "impact@2"
	g.ui.inspected_orb = 0
	g.ui.inspected_slot = 1
	g.ui.board_panel = "item"
	g.ui.show_shop()
	await capture(g,"connector-forge")
	var paid = g.ui.modal.find_child("ForgePaid",true,false)
	var at: Vector2 = paid.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	g.get_viewport().push_input(motion,true)
	await g.get_tree().process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		g.get_viewport().push_input(event,true)
		await g.get_tree().process_frame
	result["gui_paid_upgrade"] = g.orb_recipes[0]==["bolt@3","impact@3","satellite@3"] and g.economy.gold==190
	await capture(g,"connector-upgraded")
	g.ui.board_panel = "fusion"
	g.ui.fusion_choice = "frost_gate"
	g.ui.show_shop()
	await capture(g,"fusion-catalog")
	var file := FileAccess.open("res://artifacts/magic-v2-rendered-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	return result
