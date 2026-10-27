extends RefCounted
## Render the real randomized director and AI with a fixed seed; not a player skill test.
func snapshot(g: Node2D, number: int, seconds: float) -> Dictionary:
	g.set_physics_process(false)
	g.sound_enabled = false
	g.start_run()
	g.wave = number
	g.rng.seed = 7119
	g.director.reset()
	g.invincible = 999
	g.notice_left = 0
	for tick in int(seconds * 60):
		g.wave_time = (tick + 1) / 60.0
		g.elapsed = g.wave_time
		g.director.update()
		g._rebuild_grid()
		g._update_enemies(1.0 / 60)
		g._update_hostile_shots(1.0 / 60)
		g._update_effects(1.0 / 60)
	g.visuals.queue_redraw()
	g.ui.update_hud()
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/random-wave-%d.png" % number
	g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	return {"wave": number, "time": seconds, "actors": g.enemies.size(), "stats": g.director.stats, "screenshot": path}

func stress(g: Node2D) -> Dictionary:
	await snapshot(g, 4, 32.0)
	g.director.enabled = false
	g.director.pending.clear()
	var frame_ms: Array = []
	var combat_ms: Array = []
	var peaks := {"enemies": 0, "projectiles": 0, "hostile": 0}
	var previous := Time.get_ticks_usec()
	for frame in 180:
		var start := Time.get_ticks_usec()
		g.wave_time += 1.0 / 60
		g.elapsed += 1.0 / 60
		g.player.position = Vector2(720,450) + Vector2.RIGHT.rotated(frame * 0.025) * 180
		g.aim = g.player.position.direction_to(Vector2(720,450))
		g._rebuild_grid()
		g._update_enemies(1.0 / 60)
		g._tick_orbs(1.0 / 60)
		g._rebuild_grid()
		g._update_projectiles(1.0 / 60)
		g.magic.update_zones(1.0 / 60)
		g._update_hostile_shots(1.0 / 60)
		g._update_effects(1.0 / 60)
		g._remove_dead()
		g.visuals.queue_redraw()
		g.ui.update_hud()
		var cpu := (Time.get_ticks_usec() - start) / 1000.0
		peaks.enemies = maxi(peaks.enemies, g.enemies.size())
		peaks.projectiles = maxi(peaks.projectiles, g.projectiles.size())
		peaks.hostile = maxi(peaks.hostile, g.hostile_shots.size())
		await g.get_tree().process_frame
		var now := Time.get_ticks_usec()
		if frame >= 30:
			frame_ms.append((now - previous) / 1000.0)
			combat_ms.append(cpu)
		previous = now
	frame_ms.sort()
	combat_ms.sort()
	var result := {"samples":frame_ms.size(), "render_median_ms":frame_ms[75], "render_p95_ms":frame_ms[142], "combat_cpu_p95_ms":combat_ms[142], "peaks":peaks, "note":"Wave 4 seed 7119 after 32s without killing, then 180 rendered frames with default starter magic and scripted movement/aim; invincible. Not a natural-play difficulty or full performance guarantee."}
	var f := FileAccess.open("res://artifacts/random-wave-window-performance.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	return result

func telegraphs(g: Node2D) -> Dictionary:
	await snapshot(g, 4, 8.0)
	for tick in 600:
		g.wave_time += 1.0 / 60
		g.elapsed = g.wave_time
		g.player.position = Vector2(720,450) + Vector2.RIGHT.rotated(tick * 0.01) * 160
		g.director.update()
		g._rebuild_grid()
		g._update_enemies(1.0 / 60)
		g._update_hostile_shots(1.0 / 60)
		g._update_effects(1.0 / 60)
		var ranged: int = g.enemies.filter(func(e): return e.shot_windup > 0.2).size()
		var heavy: int = g.enemies.filter(func(e): return e.windup > 0.2).size()
		if ranged > 0 and heavy > 0:
			g.visuals.queue_redraw()
			g.ui.update_hud()
			await RenderingServer.frame_post_draw
			g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/random-wave-telegraphs.png"))
			return {"time":g.wave_time,"ranged_windups":ranged,"charge_windups":heavy}
	return {"found":false}
