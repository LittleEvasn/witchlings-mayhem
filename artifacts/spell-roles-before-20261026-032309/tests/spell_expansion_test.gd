extends SceneTree
const Spells = preload("res://scripts/spells.gd")
var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		printerr("FAIL: "+message)

func reset() -> void:
	game.start_run()
	game.set_physics_process(false)
	game.sound_enabled = false
	game.director.enabled = false

func target(at: Vector2, boss := false) -> Node2D:
	var enemy: Node2D = game.spawn_enemy(3 if boss else 1,boss)
	enemy.position = at
	enemy.hp = 10000
	enemy.max_hp = 10000
	game._rebuild_grid()
	return enemy

func shoot(recipe: Array, origin := Vector2(720,450)) -> void:
	var result := Spells.compile(recipe)
	if not result.ok:
		check(false,"Test recipe compiles: "+str(recipe))
		return
	game.emit_stage(result.stages[0],origin,Vector2.RIGHT,result.stages[1] if result.stages.size() > 1 else {},1)

func step(frames: int) -> void:
	for i in frames:
		game._rebuild_grid()
		game._update_projectiles(1.0/60)
		game.magic.update_zones(1.0/60)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	reset()
	check(Spells.PARTS.size() == 22 and game.economy.PRICES.size() == 22,"Twenty-two orbs are defined and priced")
	for id in ["boomerang","vortex","thorn","bounce","giant","echo"]:
		var recipe: Array = [id] if Spells.PARTS[id].kind == "attack" else [id,"bolt"]
		check(Spells.compile(recipe).ok,"New orb compiles: "+id)
	check(not Spells.compile(["bolt","bounce"]).ok and not Spells.compile(["echo","echo","bolt"]).ok,"Prefix order and duplicate modifier rules remain enforced")
	check(is_equal_approx(Spells.interval(Spells.compile(["giant","bolt"]).stages),0.576),"Giant increases cast interval by 20 percent")
	check(is_equal_approx(Spells.interval(Spells.compile(["giant","bolt","impact","giant","thorn"]).stages),0.864),"Giant on both stages penalizes the slower attack interval only once")
	check(is_equal_approx(Spells.interval(Spells.compile(["bolt","impact","giant","vortex"]).stages),1.0368),"Child-only giant uses the slower attack interval with one giant penalty")
	check(is_equal_approx(Spells.interval(Spells.compile(["bolt","impact","thorn"]).stages),0.72) and is_equal_approx(Spells.interval(Spells.compile(["thorn","impact","bolt"]).stages),0.72),"Reordering the same attacks cannot bypass the heavier spell's recast interval")
	check(is_equal_approx(Spells.interval(Spells.compile(["echo","bolt","impact","bloom"]).stages),0.576),"Echo does not add a second interval penalty")
	check(Spells.interval(Spells.compile(["vortex"]).stages) > Spells.interval(Spells.compile(["bolt"]).stages),"Persistent attacks have a slower base cast interval")
	reset()
	var victim := target(Vector2(870,450))
	shoot(["boomerang"])
	step(32)
	check(is_equal_approx(victim.hp,9976),"Moon hits target once outbound despite overlapping frames")
	step(60)
	check(is_equal_approx(victim.hp,9952) and game.projectiles.is_empty(),"Moon hits same target once returning and is caught by caster")
	reset()
	shoot(["seek","boomerang"])
	step(41)
	game.player.position += Vector2(0,100)
	step(1)
	check(game.projectiles[0].returning and game.projectiles[0].dir.dot(game.projectiles[0].pos.direction_to(game.player.position)) > 0.99,"Returning moon follows the caster's new position, overriding homing")
	step(100)
	check(game.projectiles.is_empty(),"Moving caster can catch returning moon")
	reset()
	var first := target(Vector2(820,450))
	var second := target(Vector2(910,450))
	shoot(["pierce","boomerang","impact","bolt"])
	step(100)
	check(first.hp < 9952 and second.hp <= 9952 and game.metrics.triggers == 1,"Piercing moon reaches multiple targets; linked spell fires once across both legs")
	reset()
	first = target(Vector2(820,450))
	second = target(Vector2(820,570))
	var third := target(Vector2(960,570))
	shoot(["bounce","bolt","impact","bloom"])
	step(100)
	check(first.hp < 10000 and second.hp < 10000 and third.hp < 10000,"Bounce turns toward and damages three distinct enemies")
	check(game.metrics.triggers == 1,"Bounce does not repeat first-hit connector")
	reset()
	for x in [800,880,960,1040,1120]: target(Vector2(x,450))
	shoot(["bounce","pierce","bolt"])
	step(110)
	var damaged := 0
	for enemy in game.enemies:
		if enemy.hp < 10000: damaged += 1
	check(damaged == 5,"Two bounces then two penetrations damage five distinct enemies")
	reset()
	shoot(["giant","bloom"])
	check(is_equal_approx(game.projectiles[0].radius,12.8) and game.projectiles[0].damage == game.SpellRuntime.PROFILE.bloom.damage,"Giant expands hit radius without a hidden damage multiplier")
	victim = target(Vector2(850,540))
	game.projectiles[0].pos = Vector2(850,450)
	game.projectiles[0].life = 0.001
	step(1)
	check(victim.hp < 10000,"Giant flower explosion uses expanded area, not just a larger visual")
	reset()
	shoot(["echo","fan","bolt","impact","bloom"])
	check(game.projectiles.size() == 3 and game.magic.echoes.size() == 1,"Fan schedules one echo volley rather than one per child")
	var normal_damage: float = game.projectiles[0].damage
	step(10)
	check(game.projectiles.size() == 3,"Echo waits before firing")
	step(2)
	check(game.projectiles.size() == 6 and game.magic.echoes.is_empty() and is_equal_approx(game.projectiles[3].damage,normal_damage*0.55),"Echo emits one reduced volley without recursion")
	reset()
	first = target(Vector2(820,450))
	shoot(["echo","bolt","impact","bloom"])
	step(50)
	check(game.metrics.triggers == 2 and game.magic.echoes.is_empty(),"Original and echo each trigger once with finite children")
	reset()
	shoot(["vortex","impact","bloom"])
	step(53)
	check(game.magic.zones.size() == 1 and game.projectiles.is_empty() and game.metrics.triggers == 0,"Seed installs on range end; empty field cannot trigger linked spell")
	var center: Vector2 = game.magic.zones[0].pos
	first = target(center+Vector2(65,0))
	var boss := target(center+Vector2(60,20),true)
	var boss_position: Vector2 = boss.position
	var start: Vector2 = first.position
	step(8)
	check(first.position.distance_to(center) < start.distance_to(center) and first.hp == 10000,"Vortex gathers enemies before its first damage pulse")
	step(25)
	check(first.hp < 10000 and boss.hp < 10000 and boss.position == boss_position,"Vortex deals periodic damage; boss resists pull")
	check(game.metrics.triggers == 1,"Vortex first damage triggers child only once over all pulses")
	reset()
	shoot(["thorn","impact","bolt"])
	step(75)
	center = game.magic.zones[0].pos
	first = target(center+Vector2(25,0))
	second = target(center+Vector2(0,40))
	step(1)
	check(first.hp <= 9955 and second.hp <= 9955 and game.magic.zones.is_empty() and game.metrics.triggers == 1,"Armed thorn detonates once with area damage and one linked spell")
	reset()
	shoot(["thorn"])
	step(420)
	check(game.magic.zones.is_empty(),"Unstepped thorn expires instead of accumulating forever")
	reset()
	first = target(Vector2(800,450))
	second = target(Vector2(800,560))
	shoot(["bounce","vortex"])
	step(13)
	check(game.magic.zones.is_empty() and game.projectiles.size() == 1 and game.projectiles[0].bounces == 1,"Seed ricochets before installation")
	step(55)
	check(game.magic.zones.size() == 1,"Ricocheting seed eventually installs exactly one field")
	reset()
	for x in [800,870,940]: target(Vector2(x,450))
	shoot(["pierce","vortex","impact","bolt"])
	step(12)
	check(game.magic.zones.size() == 1 and game.magic.zones[0].pos.distance_to(Vector2(800,450)) < 30 and game.projectiles.size() == 1,"Piercing seed plants at its first contact while the seed continues")
	step(55)
	var zone_damage := 0.0
	var child_budget := 0.0
	for zone in game.magic.zones:
		zone_damage += zone.damage
		child_budget += zone.child_factor
	check(game.magic.zones.size() == 3 and is_equal_approx(zone_damage,2.5) and is_equal_approx(child_budget,0.65),"Three piercing fields conserve one seed's total damage and linked-spell strength")
	check(game.metrics.triggers == 3,"Each piercing field can trigger once at its shared strength")
	reset()
	for x in [960,1025,1090]: target(Vector2(x,450))
	shoot(["pierce","vortex"])
	step(100)
	check(game.magic.zones.size() == 3 and game.magic.zones.any(func(zone): return zone.pos.x > 1040),"Extended piercing-seed flight reaches the back of a spaced enemy line")
	reset()
	target(Vector2(800,450),true)
	shoot(["pierce","thorn"])
	step(104)
	zone_damage = 0
	for zone in game.magic.zones: zone_damage += zone.damage
	check(game.magic.zones.size() == 1 and is_equal_approx(zone_damage,30),"After a first-contact trap detonates, unused two-thirds of the seed land at range end")
	reset()
	shoot(["pierce","vortex"])
	step(53)
	check(game.magic.zones.is_empty() and game.projectiles.size() == 1,"Piercing seed travels beyond the normal seed's flight range")
	step(51)
	check(game.magic.zones.size() == 1 and is_equal_approx(game.magic.zones[0].damage,2.5),"A piercing seed that contacts nothing retains its full strength at range end")
	reset()
	for x in [800,860,920,980,1040]: target(Vector2(x,450))
	shoot(["bounce","pierce","vortex"])
	step(60)
	zone_damage = 0
	for zone in game.magic.zones: zone_damage += zone.damage
	check(game.magic.zones.size() <= 3 and is_equal_approx(zone_damage,2.5),"Bounce plus piercing cannot duplicate the seed's field budget")
	reset()
	for n in 4: shoot(["vortex"])
	step(53)
	center = game.magic.zones[0].pos
	first = target(center+Vector2(70,0))
	start = first.position
	game.magic.update_zones(0.1)
	check(first.position.distance_to(start) <= 10.001,"Overlapping vortex pull speed is capped")
	reset()
	for attack in ["boomerang","vortex","thorn"]:
		for modifier in ["fan","seek","pierce","bounce","giant","echo"]:
			shoot([modifier,attack])
	step(230)
	check(game.state == "combat" and game.projectiles.size() <= 180 and game.magic.zones.size() <= 24 and game.magic.echoes.size() <= 32,"Every new attack works with each modifier and stays bounded")
	reset()
	for n in 100: shoot(["echo","fan","vortex"])
	step(53)
	check(game.projectiles.size() <= 180 and game.magic.zones.size() == 24 and game.magic.echoes.size() <= 32,"Extreme spell spam enforces projectile, field, echo limits")
	shoot(["echo","thorn"])
	for id in Spells.PARTS: game.economy.inventory[id] = 2
	game.open_editor()
	game.draft = ["giant","thorn"]
	check(game.apply_recipe() and not game.magic.zones.is_empty() and not game.magic.echoes.is_empty(),"Combat apply preserves old spell snapshots until their normal end")
	shoot(["vortex"])
	step(53)
	shoot(["echo","thorn"])
	game.complete_wave()
	check(game.magic.zones.is_empty() and game.magic.echoes.is_empty(),"Wave completion clears persistent and delayed spells")
	reset()
	shoot(["vortex"])
	step(53)
	shoot(["echo","thorn"])
	game.end_run(false)
	check(game.magic.zones.is_empty() and game.magic.echoes.is_empty() and game.projectiles.is_empty(),"Run end clears spell objects even during delayed effects")
	reset()
	shoot(["vortex","impact","echo","bloom"])
	step(53)
	var dying_boss := target(game.magic.zones[0].pos,true)
	dying_boss.hp = 1
	step(25)
	check(game.state == "ended" and game.result_win and game.magic.zones.is_empty() and game.magic.echoes.is_empty(),"Boss dying inside a field safely ends run during spell iteration")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
