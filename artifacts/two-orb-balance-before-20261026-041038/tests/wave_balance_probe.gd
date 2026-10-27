extends SceneTree
## Actual projectile/field simulation; stationary targets isolate geometry from AI.
var g: Node2D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_physics_process(false)
	g.sound_enabled = false
	var results: Array = []
	var recipes := [["bolt"],["bloom"],["echo","bolt"],["giant","bloom"],["pierce","bolt"],["pierce","boomerang"],["echo","boomerang"],["fan","bloom"],["fan","bolt"],["vortex"],["thorn"],["bolt","impact","bloom"]]
	for layout in ["single","cluster","line"]:
		for recipe in recipes:
			g.start_run()
			g.rng.seed = 731
			g.player.position = Vector2(220,450)
			var stages: Array = g.Spells.compile(recipe).stages
			var targets: Array = []
			var count := 1 if layout == "single" else (9 if layout == "cluster" else 6)
			for i in count:
				var e = g.spawn_enemy(1)
				e.position = Vector2(450,450)
				if layout == "cluster": e.position += Vector2((i%3)*42-42,int(i/3)*42-42)
				if layout == "line": e.position += Vector2(i*65,0)
				e.hp = 1600 if layout == "single" else (45 if layout == "cluster" else 70)
				e.max_hp = e.hp
				e.radius = 24 if layout == "single" else 16
				targets.append(e)
			var clock := 0.0
			var first_clear := -1.0
			for tick in 1440:
				var dt := 1.0/120.0
				g._rebuild_grid()
				clock -= dt
				if clock <= 0:
					var target = g.nearest_enemy(g.player.position,1600)
					if target != null:
						g.aim = g.player.position.direction_to(target.position)
						g.emit_stage(stages[0],g.player.position+g.aim*22,g.aim,stages[1] if stages.size()>1 else {},1.0)
						g.metrics.casts += 1
					clock += g.Spells.interval(stages)
				g._update_projectiles(dt)
				g.magic.update_zones(dt)
				g._update_effects(dt)
				if first_clear < 0 and targets.all(func(e):return e.dead): first_clear = (tick+1)*dt
			var damage := 0.0
			for e in targets: damage += e.max_hp-maxf(0,e.hp)
			var cost := 0
			for id in recipe: cost += g.Economy.PRICES[id]
			results.append({"layout":layout,"recipe":recipe,"cost":cost,"seconds":12,"damage":snappedf(damage,0.1),"kills":g.kills,"casts":g.metrics.casts,"hits":g.metrics.hits,"clear_seconds":snappedf(first_clear,0.01)})
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if not args.is_empty() else "after"
	var f := FileAccess.open("res://artifacts/balance-"+name+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"))
	print("RESULT: balance "+name+" — "+str(results.size())+" actual-runtime scenarios")
	g.queue_free()
	await process_frame
	quit()
