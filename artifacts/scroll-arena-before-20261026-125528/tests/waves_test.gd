extends SceneTree
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else:
		failures += 1
		printerr("FAIL: "+text)
func fresh(number := 1, seed_value := 1843) -> void:
	g.start_run()
	g.wave=number
	g.rng.seed=seed_value
	g.director.reset()
	g.invincible=999
	g.player.position=Vector2(720,450)
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	g.set_physics_process(false)
	g.sound_enabled=false
	var reports: Array=[]
	var fingerprints: Array=[]
	# Free capacity after each tick to record potential pressure, not kill efficiency.
	for seed_value in [1843,7119,1843]:
		var fingerprint: Array=[]
		for number in range(1,6):
			fresh(number,seed_value)
			var c: Dictionary=g.Waves.config(number)
			var normal_times: Array=[]
			var pack_times: Array=[]
			var safe := true
			for tick in int(c.duration*60):
				g.wave_time=(tick+1)/60.0
				var before: int=g.director.stats.scattered
				var packs: int=g.director.stats.packs
				g.director.update()
				if g.director.stats.scattered>before: normal_times.append(g.wave_time)
				if g.director.stats.packs>packs: pack_times.append(g.wave_time)
				for e in g.enemies:
					safe=safe and e.position.distance_to(g.player.position)>=220
					g.director.reward(e.kind)
					e.free()
				g.enemies.clear()
				g.effects.clear()
			var max_gap := 0.0
			for i in range(1,normal_times.size()): max_gap=maxf(max_gap,normal_times[i]-normal_times[i-1])
			verify(safe and max_gap<5.5 and normal_times.size()>8,"Wave %d seed %d: safe continuous scattered pressure"%[number,seed_value])
			verify(pack_times.size()>=3 and g.director.stats.grouped>0,"Wave %d seed %d: intermittent groups also arrive"%[number,seed_value])
			verify(g.director.pending.is_empty() and not g.director.enabled,"Wave duration stops all arrivals")
			verify(g.director.dropped<=c.drop_budget,"More enemies do not inflate wave money cap")
			if number<3: verify(g.director.stats.heavy==0 and g.director.stats.ranged==0,"Early waves remain melee only")
			if number>=3: verify(g.director.stats.heavy>0,"Late wave includes charging elites")
			if number>=4: verify(g.director.stats.ranged>0,"Late wave includes ranged pressure")
			fingerprint.append([normal_times,pack_times,g.director.stats.duplicate()])
			if seed_value==7119: reports.append({"wave":number,"duration":c.duration,"max_scattered_gap":max_gap,"pack_times":pack_times,"spawn_counts":g.director.stats.duplicate(),"drop_budget":c.drop_budget})
		fingerprints.append(fingerprint)
	verify(fingerprints[0]==fingerprints[2],"Same seed reproduces schedules and composition")
	verify(fingerprints[0]!=fingerprints[1],"Different seed changes schedules and composition")
	# Saturated real AI: cap still holds even if the player kills nothing.
	for number in range(1,6):
		fresh(number)
		if number==5: g.spawn_enemy(3,true)
		var c: Dictionary=g.Waves.config(number)
		var bounded := true
		var peak := 0
		for tick in int(c.duration*30):
			g.wave_time=(tick+1)/30.0
			g.director.update()
			g._rebuild_grid()
			g._update_enemies(1.0/30)
			g._update_hostile_shots(1.0/30)
			g._update_effects(1.0/30)
			peak=maxi(peak,g.enemies.size())
			bounded=bounded and g.enemies.size()<=c.cap and g.enemies.filter(func(e):return e.kind==2).size()<=c.ranged_cap and g.enemies.filter(func(e):return e.kind==3 and not e.boss).size()<=c.heavy_cap
		verify(bounded and g.director.pending.is_empty(),"Wave %d full-duration no-kill AI: caps and cleanup, peak %d"%[number,peak])
	fresh(4)
	g.director.enabled=false
	var ranged=g.spawn_enemy(2)
	ranged.position=Vector2(1000,450)
	ranged.cooldown=0
	g._rebuild_grid()
	g._update_enemies(0.01)
	verify(ranged.shot_windup>0.6 and g.hostile_shots.is_empty(),"Ranged attack keeps its windup")
	var direction: Vector2=ranged.shot_direction
	g.player.position.y=620
	for i in 44: g._update_enemies(1.0/60)
	verify(not g.hostile_shots.is_empty() and g.hostile_shots[0].vel.normalized().is_equal_approx(direction),"Ranged aim locks before firing; moving sideways can evade")
	var heavy=g.spawn_enemy(3)
	heavy.cooldown=0
	g._rebuild_grid()
	g._update_enemies(0.01)
	verify(heavy.windup>0.7 and heavy.charge_time==0,"Elite keeps pre-charge warning")
	for i in 50: g._update_enemies(1.0/60)
	verify(heavy.charge_time>0,"Elite charges after warning")
	fresh(3)
	for i in 50:
		var e=g.spawn_enemy(3)
		g.damage_enemy(e,10000,Vector2.ZERO)
		g._remove_dead()
	g.complete_wave()
	verify(g.economy.gold==68,"48G drop budget + existing 20G clear reward")
	g.choose_reward("power")
	var forecast=g.ui.modal.find_child("WaveForecast",true,false)
	verify(forecast!=null and forecast.text==g.Waves.forecast(4),"Shop forecast shares actual wave data")
	var wave_clock: float=g.wave_time
	var shop_clock: float=g.shop_time
	verify(g.start_trial(),"Shop trial opens")
	g._physics_process(0.5)
	verify(g.wave_time==wave_clock and g.shop_time==shop_clock and g.director.pending.is_empty(),"Trial does not progress combat or shopping time")
	g.end_trial()
	g.launch_next_wave()
	verify(g.wave==4 and g.director.enabled and g.wave_time==0 and g.director.dropped==0,"Ready begins a clean randomized next wave")
	g.director.schedule_pack()
	g.hostile_shots.append({"pos":Vector2.ZERO,"vel":Vector2.ONE,"life":4})
	g.complete_wave()
	verify(g.director.pending.is_empty() and g.hostile_shots.is_empty(),"Wave end clears queued group and enemy shots")
	g.choose_reward("power")
	g.launch_next_wave()
	verify(g.wave==5 and g.boss_ref!=null and g.boss_ref.boss,"Fifth wave still starts with boss")
	g.damage_enemy(g.boss_ref,100000,Vector2.ZERO)
	verify(g.state=="ended" and g.result_win and g.director.pending.is_empty(),"Boss death still completes run and cancels scheduler")
	fresh()
	verify(g.enemies.is_empty() and g.wave==1 and g.director.enabled,"Restart clears old actors and resumes first wave")
	var f=FileAccess.open("res://artifacts/wave-randomized-report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(reports,"\t"))
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
