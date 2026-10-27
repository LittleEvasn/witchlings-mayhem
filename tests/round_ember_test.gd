extends SceneTree
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)
func fresh(parts: Array = ["ember_path"]) -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.clear()
	g.encounters.enabled = false
	g.meter = load("res://scripts/combat_meter.gd").new()
	g.player.position = Vector2(1200,900)
	g.aim = Vector2.RIGHT
	var compiled: Dictionary = g.Spells.compile(parts)
	g.magic.begin_tick()
	g.magic.emit(compiled.stages[0],g.player.position,Vector2.RIGHT,{},1)
func tick(seconds: float, velocity := Vector2.ZERO) -> void:
	for frame in ceili(seconds*120):
		g.player.position += velocity/120
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/120)
		g.magic.update_zones(1.0/120)
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.record_runs = false
	g.sound_enabled = false
	g.set_physics_process(false)
	await process_frame
	fresh()
	check(g.magic.zones.size()==1,"Initial footprint is one circle under feet")
	check(g.magic.zones[0].path_points.size()==1 and g.magic.zones[0].pos==g.player.position+Vector2(0,16),"Circle collision has one point, no historical line")
	tick(.9)
	check(g.magic.zones.size()==1,"Standing still never paints more circles during cast")
	fresh()
	tick(.9,Vector2(240,0))
	check(g.magic.zones.size()==5,"Moving216 units paints initial plus four fresh footprints")
	check(g.magic.zones.all(func(z):return z.path_points.size()==1),"Every footprint is a separate circular region")
	var stamps: Array = g.magic.zones.duplicate()
	for i in range(1,stamps.size()):
		check(is_equal_approx(stamps[i-1].pos.distance_to(stamps[i].pos),52.8),"Footprints use distance spacing rather than frame rate")
	var between: Vector2 = stamps[0].pos.lerp(stamps[1].pos,.5)
	check(not g.magic.behavior.path_contains(stamps[0],between) and not g.magic.behavior.path_contains(stamps[1],between),"Separated circles do not retain invisible line damage")
	tick(2)
	check(g.magic.zones.is_empty() and g.magic.behavior.trail_emitters.is_empty(),"All circles expire and emitter closes")
	fresh(["fan","ember_path@3"])
	check(g.magic.zones.size()==3,"Fan lays three parallel circles")
	check(g.magic.zones.all(func(z):return z.radius==42 and z.life==3),"Rank-three width and duration remain intact")
	tick(.8,Vector2(240,0))
	check(g.magic.zones.size()==9,"Parallel lanes continue along fresh movement")
	fresh(["ember_path","expire@3","bolt"])
	tick(1.85)
	check(g.meter.totals.get("trigger_expire",0)==1,"Natural footprint-group end fires one expire connector")
	fresh(["ember_path","expire","bolt"])
	g.clear_magic()
	tick(3)
	check(g.projectiles.is_empty() and g.magic.behavior.trail_emitters.is_empty() and g.meter.totals.get("triggers",0)==0,"Forced clear cancels emitter and connector")
	fresh()
	g.player.position += Vector2(500,0)
	tick(.01)
	check(g.magic.zones.size()==1,"Teleport does not paint a corridor")
	fresh(["bolt","impact","ember_path"])
	var parent: Dictionary = g.projectiles[0]
	var event := Vector2(1800,900)
	g.magic.trigger(parent,event)
	check(g.magic.zones.size()==3 and g.magic.zones.all(func(z):return z.pos.distance_to(event)<54),"Linked effect is three circles at event, not player history")
	check(g.magic.behavior.trail_emitters.is_empty(),"Linked effect never begins following the player")
	fresh(["firework_trail"])
	var e = g.spawn_enemy(1)
	e.position = g.player.position+Vector2(0,16)
	e.hp = 10000
	e.max_hp = e.hp
	tick(.35)
	check(g.meter.totals.get("fusion_firework_trail",0)==1,"Firework fusion detonates first circle contact")
	tick(.35)
	check(g.meter.totals.get("fusion_firework_trail",0)==1,"Same circle does not repeatedly detonate")
	var report := {"checks":checks,"failures":failures,"spacing":52.8,"radius":24,"emission_seconds":1.0,"movement_speed":240,"teleport_cutoff":200}
	FileAccess.open("res://artifacts/round-ember-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RESULT: %d checks / %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures>0 else 0)
