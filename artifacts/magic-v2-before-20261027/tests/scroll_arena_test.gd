extends SceneTree
const Runner = preload("res://scripts/measurement_runner.gd")
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+note)
func fresh() -> void:
	g.start_run()
	g.set_physics_process(false)
	g.set_process_unhandled_input(false)
	g.sound_enabled=false
	g.director.enabled=false
	g.rng.seed=731
	g.invincible=1000
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	check(g.FIELD.size==Vector2(4800,3600),"Finite 4800x3600 world")
	check(g.player.position==Vector2(2400,1800),"Run begins in world center")
	check(g.camera.is_current() and g.camera.zoom==Vector2.ONE,"Active camera preserves actor scale")
	check(not g.camera.position_smoothing_enabled,"Camera has no trailing acceleration")
	check(g.logical_view_size()==Vector2(1440,900),"Logical view is not divided by window stretch twice")
	var hud: Vector2=g.ui.hp_label.get_global_transform_with_canvas().origin
	var start: Vector2=g.player.position
	Input.action_press("move_right")
	Input.action_press("move_down")
	for frame in 300: g._physics_process(1.0/60)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(absf(g.player.position.distance_to(start)-1200)<1,"Five seconds diagonal travel stays normalized at speed240")
	check(g.player.position.x>3000 and g.player.position.y>2500,"Player can leave the old one-screen field")
	check(g.camera.get_screen_center_position().distance_to(g.player.position)<1,"Camera follows the real moving player")
	check(g.ui.hp_label.get_global_transform_with_canvas().origin==hud,"HUD remains fixed during scroll")
	check(g.visuals.z_index>g.player.z_index,"VFX ordering supports world y beyond1500")
	fresh()
	var corners: Array=[Vector2(112,112),Vector2(4688,112),Vector2(112,3488),Vector2(4688,3488)]
	for corner in corners:
		g.player.position=corner
		g._sync_camera()
		var rect: Rect2=g.visible_world_rect()
		check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=4800 and rect.end.y<=3600,"Camera view stays inside finite world at "+str(corner))
		check(rect.has_point(corner),"Player remains visible at "+str(corner))
		check(g.camera.get_screen_center_position().distance_to(rect.get_center())<1,"Camera limits match actual spawn view at "+str(corner))
		var produced := 0
		for i in 16:
			var point: Vector2=g.director.random_spawn_point()
			if point==Vector2.INF: continue
			produced+=1
			check(not rect.grow(24).has_point(point) and g.enemy_bounds().grow(-18).has_point(point),"Boundary arrivals use available offscreen world space")
			check(point.distance_to(corner)>=220,"Boundary arrival respects player safety")
		check(produced>0,"Map corner still has usable spawn directions")
	g.player.position=Vector2(-1000,10000)
	g._physics_process(0)
	check(g.player.position==Vector2(112,3488),"Movement clamps to world, not old window")

	fresh()
	var edges: Dictionary={}
	for i in 40:
		var p: Vector2=g.director.random_spawn_point()
		check(p!=Vector2.INF,"Center produces spawn points")
		edges[g.director.edge_of(p,g.director.spawn_frame())]=true
	check(edges.size()==4,"Unpredictable scattered arrivals retain all four directions")
	g.wave=2
	g.director.reset()
	g.director.enabled=false
	g.director.schedule_pack()
	var plan: Array=g.director.pending.duplicate(true)
	check(plan.size()>=7 and plan.size()<=10,"Existing pack size retained")
	check(plan.all(func(p):return p.frame==plan[0].frame and p.edge==plan[0].edge),"Each pack retains a world-space entrance")
	g.player.position+=Vector2(250,0)
	g._sync_camera()
	for frame in 210:
		g.wave_time+=1.0/60
		g.director.update()
		g._rebuild_grid()
		g._update_enemies(1.0/60)
	check(g.director.pending.is_empty(),"Moving camera does not leave queued spawn debt")
	check(g.director.stats.spawned>0,"Pack can arrive while camera scrolls")

	fresh()
	var spell: Dictionary=g.Spells.compile(["bolt"]).stages[0]
	g.emit_stage(spell,Vector2(3300,2400),Vector2.RIGHT,{},1)
	g.magic.update_projectiles(.1)
	check(g.projectiles.size()==1 and g.projectiles[0].pos.x>3300,"Projectiles survive beyond old1600x1060 cutoff")
	var life: float=g.projectiles[0].life
	g.player.position=Vector2(1200,1000)
	g._sync_camera()
	g.magic.update_projectiles(.1)
	check(g.projectiles.size()==1 and g.projectiles[0].life<life,"Camera movement does not erase an offscreen spell")
	g.projectiles[0].pos=Vector2(4900,2400)
	g.magic.update_projectiles(.1)
	check(g.projectiles.is_empty(),"World-outside projectile is safely removed")
	g.hostile_shots=[{"pos":Vector2(3300,2500),"vel":Vector2.RIGHT*100,"life":5}]
	g._update_hostile_shots(.1)
	check(g.hostile_shots.size()==1 and g.hostile_shots[0].pos.x==3310,"Enemy projectiles use world coordinates")

	fresh()
	var actor=g.Actor.new()
	g.actors.add_child(actor)
	actor.setup(g.art,1)
	actor.position=Vector2(4300,3000)
	actor.hp=7
	actor.max_hp=25
	actor.cooldown=0
	actor.windup=.5
	g.enemies.append(actor)
	var old_id: int=actor.get_instance_id()
	g._recycle_distant_enemies()
	check(actor.get_instance_id()==old_id and actor.hp==7,"Far-enemy recycling preserves instance and damage")
	check(not g.visible_world_rect().grow(24).has_point(actor.position) and actor.position.distance_to(g.player.position)>=220,"Recycled enemy stays offscreen and safe")
	check(actor.windup==0 and actor.cooldown>=1,"Recycled enemies cannot instantly finish a stale attack")
	check(g.kills==0 and g.gems.is_empty() and g.economy.gold==0,"Recycling creates no kills or income")
	actor.boss=true
	actor.position=Vector2(4400,3000)
	g._recycle_distant_enemies()
	check(actor.position==Vector2(4400,3000),"Boss is not teleported by generic recycling")
	actor.boss=false
	actor.position=Vector2(3300,2500)
	g.player.position=Vector2(3400,2500)
	g._rebuild_grid()
	g._update_enemies(.1)
	check(actor.position.x>3000,"Enemy AI no longer clamps to x1405")
	g.gems=[{"pos":g.player.position,"value":7}]
	g._update_gems(.01)
	check(g.economy.gold==7 and g.gems.is_empty(),"World-space pickup remains collectible")

	g._sync_camera()
	var saved: Vector2=g.player.position
	g.complete_wave()
	g.reward_options=["droplet"]
	g.choose_reward("droplet")
	check(g.player.position==saved and g.arena_profile=="scroll","Preparation retains world position and camera profile")
	check(g.start_trial(),"Can enter trial from far across world")
	check(g.arena_profile=="trial" and g.camera.get_screen_center_position().distance_to(Vector2(720,450))<1,"Trial has isolated fixed camera")
	g.orb_clocks=[0.0,0.0]
	g._tick_orbs(.01)
	check(g.projectiles.size()>0,"Trial still emits current spells")
	g.end_trial()
	check(g.player.position==saved and g.arena_profile=="scroll","Trial exit restores world position and profile")
	check(g.camera.get_screen_center_position().distance_to(g.visible_world_rect().get_center())<1,"Trial exit restores camera without trailing travel")
	check(g.projectiles.is_empty() and g.magic.echoes.is_empty(),"Trial attacks cannot leak into world")
	g.launch_next_wave()
	check(g.state=="combat" and g.wave==2 and g.player.position==saved,"Next wave resumes at actual world location")
	g.start_run()
	g.set_physics_process(false)
	check(g.player.position==g.FIELD.get_center() and g.arena_profile=="scroll","Restart recenters world cleanly")

	var runner:=Runner.new(g)
	check(runner.begin([["bolt"],["bolt"]],"single",731,"replay",1),"Existing measurement fixture begins")
	check(g.arena_profile=="measurement" and g.camera.get_screen_center_position().distance_to(Vector2(720,450))<1,"Measurement uses its own one-screen profile")
	while runner.active: runner.step()
	check(runner.report().totals.get("damage_effective",0)>0,"Fixed-profile measurement still damages its real targets")
	runner.stop()
	g.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
