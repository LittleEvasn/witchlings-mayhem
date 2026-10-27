extends SceneTree
## One seeded invulnerable bot: production combat and actual paid upgrades. Not a fun/difficulty test.
var g: Node2D
var reports: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g); current_scene=g
	await process_frame
	g.record_runs=false; g.start_run("sigil"); g.set_physics_process(false); g.sound_enabled=false
	g.rng.seed=20261026; g.relics.rng.seed=20261026
	g.director.reset()
	var safety:=0
	while g.state=="combat" and safety<5:
		safety+=1
		var chapter: int=g.wave
		var samples: Array=[]
		var start: float=g.elapsed
		for tick in int(g.Waves.config(chapter).duration*60)+2:
			if g.state!="combat": break
			var before:=Time.get_ticks_usec()
			var delta:=1.0/60.0
			g.elapsed+=delta; g.wave_time+=delta; g.invincible=10000
			g.relics.tick(delta)
			g.player.position=Vector2(2400,1800)+Vector2.RIGHT.rotated(g.elapsed*.18)*220
			g._rebuild_grid()
			g._update_enemies(delta)
			var nearest=g.nearest_enemy(g.player.position,1800)
			if nearest!=null: g.cast_target=nearest.position
			g._tick_orbs(delta); g._rebuild_grid(); g._update_projectiles(delta)
			if g.state!="combat": break
			g.magic.update_zones(delta); g._update_hostile_shots(delta); g._update_gems(delta)
			g._update_effects(delta); g.director.update(); g._remove_dead()
			g.metrics.peak_enemies=maxi(g.metrics.peak_enemies,g.enemies.size())
			g.metrics.peak_projectiles=maxi(g.metrics.peak_projectiles,g.projectiles.size())
			if g.wave_time>=g.Waves.config(chapter).duration:
				if chapter<5: g.complete_wave()
				else: g.end_reason="probe timeout";g.end_run(false)
			samples.append((Time.get_ticks_usec()-before)/1000.0)
			if tick%600==0: await process_frame
		g.ui.close_modal()
		samples.sort()
		reports.append({"wave":chapter,"combat":g.elapsed-start,"earned_total":g.economy.total_earned,"money_before_preparation":g.economy.gold,"kills":g.wave_kills,"peak_enemies":g.metrics.peak_enemies,"peak_projectiles":g.metrics.peak_projectiles,"headless_sim_step_p95_ms":samples[int(samples.size()*.95)] if not samples.is_empty() else 0,"won":g.result_win,"recipes":g.orb_recipes.duplicate(true)})
		if g.state=="ended": break
		# Existing deterministic research slot, then paid crafting through the real transaction API.
		g.choose_reward(g.reward_options[0])
		var want: String="vortex" if chapter==1 else "echo"
		if chapter<=2:
			g.economy.select_research(want,g.economy.revision)
			g.buy_orb(0,g.economy.revision)
			if g.economy.inventory.get(want,0)>0:
				g.board_drop(g.board_data(want),1 if chapter==1 else 0,0)
		for repeat in 2:
			var bolt: String=""
			for token in g.economy.inventory:
				if g.Spells.Progression.base_id(token)=="bolt": bolt=token;break
			if not bolt.is_empty(): g.craft_spell("upgrade",bolt,"",g.economy.revision)
		g.launch_next_wave()
	var output={"seed":20261026,"assumptions":"invulnerable nearest-aim moving bot; 60Hz production steps, headless CPU only; no human fun or GPU claim","reports":reports,"ended":g.state=="ended","won":g.result_win,"combat_total":g.elapsed}
	var file:=FileAccess.open("res://artifacts/lumi-run-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  ")); file.close()
	print(JSON.stringify(output))
	g.queue_free(); await process_frame
	print("RESULT: seeded full-route probe completed"); quit()
