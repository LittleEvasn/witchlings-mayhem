extends SceneTree
var g: Node2D
var checks := 0
var failures := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func fresh(number := 4) -> void:
	g.start_run()
	g.wave = number
	g.rng.seed = 7119
	g.director.reset()
	g.director.event_index = g.Waves.config(number).events.size()

func advance(seconds: float) -> void:
	for tick in int(seconds*120):
		g.wave_time += 1.0/120
		g.director.update()

func edge_of(p: Vector2) -> int:
	if p.x==45: return 0
	if p.x==1395: return 1
	if p.y==120: return 2
	return 3

func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_physics_process(false)
	g.sound_enabled = false
	fresh()
	var seen := [0,0,0,0]
	for i in 32:
		var e = g.spawn_enemy(1)
		if e != null: seen[edge_of(e.position)] += 1
	verify(seen.all(func(n):return n>0),"Same wave uses all four edges: "+str(seen))
	var overlap := false
	for e in g.enemies:
		for other in g.enemies:
			if e!=other and e.position.distance_to(other.position)<e.radius+other.radius+3: overlap=true
	verify(not overlap,"Random arrivals do not overlap existing enemy bodies")
	fresh(2)
	g.director.schedule([0,"swarm",12])
	var times: Array = []
	for r in g.director.pending: times.append(r.at)
	times.sort()
	verify(times[-1]-times[0]>1 and times[1]-times[0]!=times[2]-times[1],"Arrivals are spread over irregular times")
	verify(g.director.warnings.is_empty(),"No entrance warning is scheduled")
	advance(3.2)
	verify(g.enemies.size()==12 and g.director.pending.is_empty(),"Scheduled enemy count is preserved")
	for corner in [Vector2(72,115),Vector2(1368,115),Vector2(72,771),Vector2(1368,771),Vector2(720,450)]:
		fresh(2)
		g.director.schedule([0,"swarm",12])
		g.player.position = corner
		advance(3.2)
		verify(g.enemies.size()==12 and g.enemies.all(func(e):return e.position.distance_to(corner)>=220),"Safety uses player position at arrival: "+str(corner))
	fresh()
	for i in 60: g.spawn_enemy(1)
	verify(g.enemies.size()==48,"Wave enemy cap is preserved")
	g.director.schedule([0,"guard",8])
	advance(3.2)
	for e in g.enemies: e.dead=true
	g._remove_dead()
	advance(1)
	verify(g.enemies.is_empty() and g.director.pending.is_empty(),"Capped arrivals are discarded without a later burst")
	fresh()
	for i in 8: g.spawn_enemy(2)
	verify(g.enemies.size()==3,"Ranged cap is preserved")
	fresh()
	g.director.schedule([0,"guard",8])
	g.state = "trial"
	advance(0.2)
	verify(g.enemies.is_empty() and g.director.pending.size()==10,"Trial cannot spawn scheduled enemies")
	g.state = "combat"
	g.end_run(false)
	verify(g.director.pending.is_empty(),"Ending a run clears scheduled enemies")
	fresh()
	g.director.schedule([0,"guard",8])
	g.wave_time = 10
	g.director.update()
	verify(g.enemies.is_empty() and g.director.pending.is_empty(),"Stalled frames discard old arrivals")
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
