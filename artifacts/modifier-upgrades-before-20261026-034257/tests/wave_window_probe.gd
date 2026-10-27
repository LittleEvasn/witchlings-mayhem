extends RefCounted
## Rendered-window stress run; combat is real, position/aim are a deterministic harness.
func run(g: Node2D) -> Dictionary:
	g.set_physics_process(false)
	g.sound_enabled=false
	g.start_run()
	g.wave=4
	g.director.reset()
	g.director.enabled = false
	g.notice_left=0
	g.compiled=g.Spells.compile(["fan","echo","vortex","impact","giant","bloom"]).stages
	var center := Vector2(720,450)
	for i in 48:
		var e = g.spawn_enemy(2 if i<3 else (3 if i<6 else 1))
		if e == null: continue
		e.position=center+Vector2.RIGHT.rotated(i*TAU/48)*(240+i%5*24)
		e.hp=10000
		e.max_hp=e.hp
	var wall_ms: Array = []
	var physics_ms: Array = []
	var process_ms: Array = []
	var peaks := {"enemies":0,"projectiles":0,"hostile":0,"zones":0,"effects":0,"echoes":0}
	var last := Time.get_ticks_usec()
	var cast_clock := 0.0
	for frame in 210:
		g.wave_time+=1.0/60
		g.elapsed+=1.0/60
		g.invincible=999
		g.player.position=center+Vector2.RIGHT.rotated(frame*0.016)*120
		g.aim=g.player.position.direction_to(center)
		var start := Time.get_ticks_usec()
		g._rebuild_grid()
		g._update_enemies(1.0/60)
		cast_clock-=1.0/60
		if cast_clock<=0:
			g.emit_stage(g.compiled[0],g.player.position+g.aim*22,g.aim,g.compiled[1],1)
			cast_clock=g.Spells.interval(g.compiled)
		g._rebuild_grid()
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
		g._update_hostile_shots(1.0/60)
		g._update_effects(1.0/60)
		g.player.animate(1.0/60)
		g.visuals.queue_redraw()
		g.ui.update_hud()
		var cpu := (Time.get_ticks_usec()-start)/1000.0
		peaks.enemies=maxi(peaks.enemies,g.enemies.size())
		peaks.projectiles=maxi(peaks.projectiles,g.projectiles.size())
		peaks.hostile=maxi(peaks.hostile,g.hostile_shots.size())
		peaks.zones=maxi(peaks.zones,g.magic.zones.size())
		peaks.echoes=maxi(peaks.echoes,g.magic.echoes.size())
		peaks.effects=maxi(peaks.effects,g.effects.size())
		await g.get_tree().process_frame
		var now := Time.get_ticks_usec()
		if frame>=30:
			wall_ms.append((now-last)/1000.0)
			physics_ms.append(cpu)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		last=now
	wall_ms.sort()
	physics_ms.sort()
	process_ms.sort()
	var result := {"frames":wall_ms.size(),"fixed_simulation_delta":1.0/60,"render_frame_median_ms":wall_ms[int(wall_ms.size()*0.5)],"render_frame_p95_ms":wall_ms[int(wall_ms.size()*0.95)],"combat_cpu_p95_ms":physics_ms[int(physics_ms.size()*0.95)],"engine_process_p95_ms":process_ms[int(process_ms.size()*0.95)],"peaks":peaks,"recipe":["fan","echo","vortex","impact","giant","bloom"],"note":"Up to 48 high-health actors, 3 shooters and 3 chargers; 180 measured rendered frames after 30 warmup. Harness runs one fixed combat tick per rendered frame, not a natural-play FPS guarantee."}
	var f := FileAccess.open("res://artifacts/wave-window-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"))
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/wave-stress.png"))
	g.start_run()
	g.state="title"
	g.ui.show_title()
	g.set_physics_process(true)
	g.sound_enabled=true
	return result
