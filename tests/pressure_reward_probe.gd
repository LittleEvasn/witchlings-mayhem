extends SceneTree
## Short fixed-build comparison, not a human fun test or a renderer performance benchmark.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	g.record_runs=false
	g.sound_enabled=false
	g.set_physics_process(false)
	var records: Array=[]
	for number in [1,2]:
		for moving in [false,true]:
			g.rng.seed=8881+number
			g.start_run("frost")
			g.wave=number
			g.director.reset()
			g.encounters.begin_wave()
			g.economy.inventory={"seek":1,"thunder":1,"fan":1,"bolt":1}
			g.orb_recipes=[["seek","thunder"],["fan","bolt"]]
			g.orb_drafts=g.orb_recipes.duplicate(true)
			g.recipe=g.orb_recipes[0].duplicate()
			g.draft=g.recipe.duplicate()
			g.orb_compiled=[g.Spells.compile(g.orb_recipes[0]).stages,g.Spells.compile(g.orb_recipes[1]).stages]
			g.compiled=g.orb_compiled[0]
			g._reset_orb_clocks()
			var peak_enemies:=0
			var peak_shots:=0
			for frame in 3600:
				for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
				if moving: Input.action_press(["move_right","move_down","move_left","move_up"][int(frame/300.0)%4])
				g._physics_process(1.0/60)
				peak_enemies=maxi(peak_enemies,g.enemies.size())
				peak_shots=maxi(peak_shots,g.projectiles.size())
				if g.state!="combat": break
				if frame%120==0: await process_frame
			for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
			records.append({"wave":number,"moving":moving,"seconds":snappedf(g.wave_time,.01),"hp":g.hp,"kills":g.kills,"state":g.state,"peak_enemies":peak_enemies,"peak_projectiles":peak_shots,"opportunities":g.encounters.stats.duplicate()})
	var result: String=JSON.stringify({"seed_base":8881,"duration_limit":60,"build":[["seek","thunder"],["fan","bolt"]],"movement":"square, direction changes every5s, no dash","records":records},"\t")
	var file:=FileAccess.open("res://artifacts/pressure-reward-probe.json",FileAccess.WRITE)
	file.store_string(result)
	file.close()
	print(result)
	g.queue_free()
	await process_frame
	quit()
