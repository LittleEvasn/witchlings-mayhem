extends SceneTree
var g: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else:
		failures += 1
		printerr("FAIL: "+text)

func fresh(number := 1) -> void:
	g.start_run()
	g.wave = number
	g.rng.seed = 1843
	g.director.reset()
	g.invincible = 999
	g.player.position = Vector2(720,450)

func advance(seconds: float, move := false) -> void:
	for i in int(seconds*60):
		g.wave_time += 1.0/60
		g.director.update()
		if move:
			g._rebuild_grid()
			g._update_enemies(1.0/60)
		g._update_effects(1.0/60)
		g._remove_dead()

func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_physics_process(false)
	g.sound_enabled = false
	fresh(2)
	g.wave_time = 1
	g.director.update()
	verify(g.enemies.is_empty() and g.director.warnings.is_empty(),"Random arrivals have no advance entrance warning")
	verify(g.director.pending.size()==9,"Swarm timetable schedules one bounded group")
	advance(2.5)
	verify(g.enemies.size()==9,"Swarm arrivals scatter without overlapping bodies")
	verify(g.enemies.all(func(e):return e.role=="swarm" and e.hp<22),"Swarm has smaller bodies and less than one basic bolt of health")
	var spacing := true
	for e in g.enemies:
		spacing = spacing and e.position.distance_to(g.player.position)>=220
		for other in g.enemies:
			if e!=other and e.position.distance_to(other.position)<e.radius+other.radius+3: spacing=false
	verify(spacing,"Pack spawns preserve player safety distance and nonoverlapping bodies")
	fresh(3)
	g.director.schedule([0,"line",6])
	var requests: Array = g.director.pending.duplicate(true)
	verify(requests.all(func(r):return not r.has("pos")),"Arrivals choose positions at spawn time instead of sharing an entrance")
	verify(requests.size()==6 and requests.all(func(r):return r.at>0 and r.at<=1.5),"Fast enemies arrive at irregular times")
	advance(4.2,true)
	verify(g.enemies.filter(func(e):return e.role=="line").size()>=5,"Actual moving line clears its entrance for following members")
	verify(g.enemies.filter(func(e):return e.kind==2).is_empty(),"Wave three does not randomly inject ranged enemies")
	fresh(4)
	g.director.schedule([0,"guard",8])
	verify(g.director.pending.filter(func(r):return r.kind==2).size()==2,"Mixed event retains two ranged arrivals without a fixed formation")
	advance(4.6,true)
	verify(g.enemies.any(func(e):return e.kind==2),"Guard group actually produces ranged escorts")
	var ranged = g.enemies.filter(func(e):return e.kind==2)[0]
	ranged.position = Vector2(1000,450)
	ranged.cooldown = 0
	g.player.position = Vector2(720,450)
	g._rebuild_grid()
	g._update_enemies(0.01)
	verify(ranged.shot_windup>0.6 and g.hostile_shots.is_empty(),"Ranged attack winds up visibly before firing")
	var locked: Vector2 = ranged.shot_direction
	g.player.position.y = 620
	for i in 44: g._update_enemies(1.0/60)
	verify(not g.hostile_shots.is_empty() and g.hostile_shots[0].vel.normalized().is_equal_approx(locked),"Ranged shot keeps announced aim so lateral movement can evade it")
	fresh(3)
	var heavy = g.spawn_enemy(3)
	heavy.cooldown = 0
	g._rebuild_grid()
	g._update_enemies(0.01)
	verify(heavy.windup>0.7 and heavy.charge_time==0 and heavy.hp>180,"Heavy has meaningful health and a separate pre-charge windup")
	var before: Vector2 = heavy.position
	for i in 50: g._update_enemies(1.0/60)
	verify(heavy.charge_time>0 and heavy.position.distance_to(before)>0,"Heavy starts moving only after its charge announcement")
	fresh(4)
	var cap: int = g.Waves.config(4).cap
	g.director.event_index = g.Waves.config(4).events.size()
	for i in cap: g.spawn_enemy(1)
	g.director.schedule([0,"guard",8])
	advance(4.5)
	verify(g.enemies.size()==cap and g.director.pending.is_empty(),"Full cap drops scheduled requests instead of retaining a backlog")
	for e in g.enemies: e.dead=true
	g._remove_dead()
	advance(1)
	verify(g.enemies.is_empty(),"Freeing capacity does not replay dropped requests")
	fresh(4)
	for i in 8: g.spawn_enemy(2)
	verify(g.enemies.size()==3,"Independent ranged cap limits simultaneous shooters")
	fresh(2)
	g.wave_time = 1
	g.director.update()
	g.wave_time = 16
	g.director.update()
	verify(g.enemies.is_empty() and g.director.pending.is_empty(),"A stalled frame skips expired pack members and past timetable entries")
	for corner in [Vector2(72,115),Vector2(1368,115),Vector2(72,771),Vector2(1368,771),Vector2(720,450)]:
		fresh(2)
		g.player.position=corner
		g.director.schedule([0,"swarm",12])
		advance(3.5)
		verify(not g.enemies.is_empty() and g.enemies.all(func(e):return e.position.distance_to(corner)>=220),"Safe pack entrance at player position "+str(corner))
	fresh(3)
	for i in 50:
		var e = g.spawn_enemy(3)
		g.damage_enemy(e,10000,Vector2.ZERO)
		g._remove_dead()
	var coins := 0
	for drop in g.gems: coins+=drop.value
	verify(coins==48 and g.director.dropped==48,"Kill drops obey wave money budget despite repeated heavy kills")
	g.complete_wave()
	verify(g.economy.gold==68 and g.economy.total_earned==68,"Collected drops plus unchanged 20G clear reward settle exactly once")
	g.complete_wave()
	verify(g.economy.gold==68,"Wave completion cannot duplicate the clear reward")
	g.choose_reward("power")
	var forecast = g.ui.modal.get_node("WaveForecast")
	verify(forecast.text==g.Waves.forecast(4),"Shop forecast reads the same next-wave configuration as spawning")
	var time: float = g.wave_time
	var event_index: int = g.director.event_index
	var shop_time: float = g.shop_time
	verify(g.start_trial(),"Integrated shop still opens actual spell trial")
	g._physics_process(0.5)
	verify(g.wave_time==time and g.shop_time==shop_time and g.director.event_index==event_index and g.director.pending.is_empty(),"Trial freezes the wave scheduler and shop clock")
	g.end_trial()
	g.launch_next_wave()
	verify(g.wave==4 and g.director.event_index==0 and g.director.dropped==0 and g.enemies.is_empty(),"Next wave resets timetable and drop budget without trial actors")
	g.director.schedule([0,"guard",8])
	g.hostile_shots.append({"pos":Vector2.ZERO,"vel":Vector2.ONE,"life":4})
	g.complete_wave()
	verify(g.director.pending.is_empty() and g.director.warnings.is_empty() and g.hostile_shots.is_empty(),"Wave completion clears reservations, warnings, and enemy attacks")
	g.start_run()
	verify(g.director.event_index==0 and g.director.pending.is_empty() and g.enemies.is_empty() and g.wave==1,"Restart cannot leak old wave events or actors")
	g.director.schedule([0,"swarm",9])
	g.end_run(false)
	verify(g.director.pending.is_empty() and g.director.warnings.is_empty(),"Death clears pending arrivals as well")
	var summary: Array = []
	for number in range(1,6):
		fresh(number)
		if number==5: g.spawn_enemy(3,true)
		var config: Dictionary = g.Waves.config(number)
		var longest_gap := 0.0
		for i in range(1,config.events.size()): longest_gap=maxf(longest_gap,config.events[i][0]-config.events[i-1][0])
		verify(longest_gap>=8 and config.duration==(120.0 if number==5 else 45.0),"Wave %d retains duration and has a break between pressure groups"%number)
		var peak := 0
		var ranged_peak := 0
		for tick in int(config.duration*60):
			g.wave_time=(tick+1)/60.0
			g.director.update()
			g._rebuild_grid()
			g._update_enemies(1.0/60)
			g._update_hostile_shots(1.0/60)
			g._update_effects(1.0/60)
			peak=maxi(peak,g.enemies.size())
			ranged_peak=maxi(ranged_peak,g.enemies.filter(func(e):return e.kind==2).size())
		verify(peak<=config.cap and ranged_peak<=config.ranged_cap and g.director.pending.is_empty(),"Wave %d full-duration AI soak respects caps and clears expired requests"%number)
		summary.append({"wave":number,"peak":peak,"ranged_peak":ranged_peak,"scheduler":g.director.stats.duplicate()})
	var f := FileAccess.open("res://artifacts/wave-soak.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(summary,"\t"))
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
