extends SceneTree
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		printerr("FAIL: "+message)
func fresh(number := 4) -> void:
	g.start_run()
	g.wave = number
	g.rng.seed = 7119
	g.director.reset()
	g.director.enabled = false
	g.invincible = 999
func advance(seconds: float, move := false) -> void:
	for tick in int(seconds*60):
		g.wave_time += 1.0/60
		g.director.update()
		if move:
			g._rebuild_grid()
			g._update_enemies(1.0/60)
		g._update_effects(1.0/60)
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
	verify(seen.all(func(n):return n>0),"Independent arrivals use every edge: "+str(seen))
	var spaced := true
	for e in g.enemies:
		for other in g.enemies:
			if e!=other and e.position.distance_to(other.position)<e.radius+other.radius+3: spaced=false
	verify(spaced,"Arrivals do not overlap bodies")
	fresh(2)
	g.director.schedule_pack()
	var requests: Array = g.director.pending.duplicate(true)
	verify(requests.size()>=7 and requests.size()<=10,"Pack size follows wave data")
	verify(requests.all(func(q):return q.edge==requests[0].edge and q.along==requests[0].along),"One pack shares a local entrance")
	verify(requests[-1].at-requests[0].at>0.8,"Pack members arrive across time, not one overlapping instant")
	var edges: Dictionary = {}
	for i in 20:
		g.director.pending.clear()
		g.director.schedule_pack()
		edges[g.director.pending[0].edge]=true
	verify(edges.size()==4,"Subsequent packs change direction instead of a fixed entrance")
	fresh(2)
	g.director.schedule_pack()
	var planned: int = g.director.pending.size()
	advance(3.5,true)
	verify(g.enemies.size()>=planned-1 and g.director.pending.is_empty(),"Moving pack members clear space for the rest")
	for corner in [Vector2(72,115),Vector2(1368,115),Vector2(72,771),Vector2(1368,771),Vector2(720,450)]:
		fresh(2)
		g.director.schedule_pack()
		g.player.position = corner
		advance(3.5)
		verify(g.enemies.all(func(e):return e.position.distance_to(corner)>=220),"Queued pack rechecks safety at arrival: "+str(corner))
	fresh()
	for i in 70: g.spawn_enemy(1)
	verify(g.enemies.size()==48,"Total enemy cap")
	g.director.schedule_pack()
	advance(3.5)
	for e in g.enemies: e.dead=true
	g._remove_dead()
	advance(2)
	verify(g.enemies.is_empty() and g.director.pending.is_empty(),"Capped requests are discarded, never backlogged")
	fresh()
	for i in 8: g.spawn_enemy(2)
	verify(g.enemies.size()==3,"Ranged enemy cap")
	for i in 8: g.spawn_enemy(3)
	verify(g.enemies.filter(func(e):return e.kind==3).size()==3,"Charging elite cap")
	fresh(5)
	g.player.position=Vector2(720,180)
	var boss = g.spawn_enemy(3,true)
	verify(boss!=null and boss.position.distance_to(g.player.position)>=220,"Boss safely relocates if player occupies its preferred entrance")
	fresh()
	g.director.schedule_pack()
	var count: int = g.director.pending.size()
	g.state="trial"
	advance(0.2)
	verify(g.enemies.is_empty() and g.director.pending.size()==count,"Trial cannot consume arrivals")
	g.state="combat"
	g.end_run(false)
	verify(g.director.pending.is_empty() and not g.director.enabled,"Run end clears and disables scheduler")
	fresh()
	g.director.enabled=true
	g.director.schedule_pack()
	g.wave_time=10
	g.director.update()
	verify(g.enemies.is_empty() and g.director.pending.is_empty() and g.director.next_normal>10 and g.director.next_pack>10,"Long frame skips both missed streams without catch-up burst")
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
