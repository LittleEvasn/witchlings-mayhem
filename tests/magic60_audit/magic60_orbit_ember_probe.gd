extends SceneTree
const S = preload("res://scripts/spells.gd")
const Profile = preload("res://scripts/player_profile.gd")
var g: Node2D
var out := {"recipe":"[orbit, ember_path]","rates":{},"seed":7301}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920,1080)
	g = load("res://scenes/main.tscn").instantiate()
	g.record_runs = false
	g.profile = Profile.new("user://magic60_orbit_probe_unused.json")
	root.add_child(g)
	current_scene = g
	await process_frame
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled = false
	g.director.enabled = false
	g.encounters.enabled = false
	g.invincible = 9999
	for hz in [60,120]:
		g.clear_magic()
		g.meter = load("res://scripts/combat_meter.gd").new()
		g.meter.detailed_sources = true
		g.state = "combat"
		g.player.position = Vector2(800,450)
		g.aim = Vector2.RIGHT
		g.cast_target = Vector2(950,450)
		g.rng.seed = 7301
		var stage: Dictionary = S.roots(S.compile(["orbit","ember_path"]).stages)[0]
		g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(950,450))
		var max_center_delta := 0.0
		var max_path_delta := 0.0
		var first_mismatch := {}
		for i in 60:
			g.player.position += Vector2(0.3,0)
			g._rebuild_grid()
			g._update_projectiles(1.0/float(hz))
			g.magic.update_zones(1.0/float(hz))
			if g.magic.zones.is_empty(): continue
			var z: Dictionary = g.magic.zones[0]
			var center_delta: float = z.pos.distance_to(z.path_points[0])
			var enemy: Node2D = g.Actor.new()
			g.actors.add_child(enemy)
			enemy.setup(g.art,1)
			enemy.position = z.pos
			enemy.hp = 100000.0
			enemy.max_hp = enemy.hp
			enemy.speed = 0.0
			g.enemies.append(enemy)
			g._rebuild_grid()
			var geometric_hit: bool = g.magic.behavior.path_contains(z,enemy.position,enemy.radius)
			var before: float = enemy.hp
			g.magic.update_zones(1.0/float(hz))
			var actual_damage: float = before-enemy.hp
			if center_delta>max_center_delta: max_center_delta=center_delta
			if center_delta>max_path_delta: max_path_delta=center_delta
			if center_delta>18.0 and first_mismatch.is_empty():
				first_mismatch={"frame":i+1,"zone_pos":[z.pos.x,z.pos.y],"path_point":[z.path_points[0].x,z.path_points[0].y],"distance":center_delta,"enemy_radius":enemy.radius,"geometric_hit":geometric_hit,"actual_damage":actual_damage,"zone_damage":z.damage,"zone_radius":z.radius}
			if i%8==0: enemy.queue_free();g.enemies.erase(enemy)
		out.rates[str(hz)]={"frames":60,"max_zone_path_distance":max_path_delta,"first_mismatch":first_mismatch,"meter":g.meter.totals.duplicate(),"last_zone_pos":([g.magic.zones[0].pos.x,g.magic.zones[0].pos.y] if not g.magic.zones.is_empty() else null)}
		for e in g.enemies: e.queue_free()
		g.enemies.clear()
	var f := FileAccess.open("res://artifacts/magic60_orbit_ember_probe.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(out,"\t"))
	f.close()
	g.queue_free()
	await process_frame
	print("ORBIT_EMBER_PROBE: "+JSON.stringify(out))
	quit(0)
