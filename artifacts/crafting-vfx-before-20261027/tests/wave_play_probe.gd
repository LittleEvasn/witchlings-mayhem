extends SceneTree
## Deterministic movement/aim harness, not evidence of human fun or difficulty.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	g.set_physics_process(false)
	g.sound_enabled=false
	var reports: Array = []
	for number in range(1,6):
		g.start_run()
		g.wave=number
		g.rng.seed=1843
		g.director.reset()
		g.power=1+(number-1)*0.25
		if number==5: g.spawn_enemy(3,true)
		var elapsed := 0.0
		var clock := 0.0
		var incoming_damage := 0.0
		var peak := 0
		for tick in int(g.Waves.config(number).duration*60):
			var dt := 1.0/60
			elapsed=(tick+1)*dt
			g.wave_time=elapsed
			g.invincible=maxf(0,g.invincible-dt)
			# Fixed orbit; aim assistance exists only in this verification harness.
			g.player.position=Vector2(720,450)+Vector2(cos(elapsed*0.5)*390,sin(elapsed*0.5)*190)
			var before: float = g.hp
			g._rebuild_grid()
			g._update_enemies(dt)
			if g.state!="combat": break
			clock-=dt
			if clock<=0:
				var target = g.nearest_enemy(g.player.position,1600)
				if target!=null:
					g.aim=g.player.position.direction_to(target.position)
					g.emit_stage(g.compiled[0],g.player.position+g.aim*22,g.aim,g.compiled[1],1)
					g.metrics.casts+=1
				clock=g.Spells.interval(g.compiled)
			g._rebuild_grid()
			g._update_projectiles(dt)
			if g.state!="combat": break
			g.magic.update_zones(dt)
			g._update_hostile_shots(dt)
			incoming_damage+=before-g.hp
			if g.state!="combat": break
			g._update_gems(dt)
			g._update_effects(dt)
			g.director.update()
			g._remove_dead()
			peak=maxi(peak,g.enemies.size())
		var drop_money: int = g.economy.total_earned
		for gem in g.gems: drop_money+=gem.value
		reports.append({"wave":number,"seconds":snappedf(elapsed,0.01),"state":g.state,"boss_won":g.result_win if g.state=="ended" else false,"remaining_hp":g.hp,"kills":g.kills,"drop_money":drop_money,"clear_reward_if_survived":20 if number<5 and g.state=="combat" else 0,"peak_enemies":peak,"recipe":g.recipe,"power":g.power,"note":"Fixed orbit, scripted nearest-target mouse-equivalent aim, no dash; fresh 100HP per wave. Not a continuous run or human-play difficulty rating."})
	var f := FileAccess.open("res://artifacts/wave-basic-play.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(reports,"\t"))
	print("RESULT: 5 controlled basic-recipe combat runs recorded")
	g.queue_free()
	await process_frame
	quit()
