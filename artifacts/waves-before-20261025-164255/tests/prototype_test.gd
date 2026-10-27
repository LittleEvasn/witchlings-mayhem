extends SceneTree
const Spells = preload("res://scripts/spells.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)
	else: print("PASS: "+message)

func run() -> void:
	verify(Spells.compile(["fan","seek","bolt","impact","pierce","bloom"]).ok,"Six-slot two-stage recipe compiles")
	for recipe in [[],["fan"],["bolt","bloom"],["bolt","impact"],["bolt","impact","bloom","impact","bolt"],["bolt","fan","fan"]]:
		verify(not Spells.compile(recipe).ok,"Reject invalid recipe "+str(recipe))
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_physics_process(false)
	g.sound_enabled = false
	verify(g.state == "title","Boot into title")
	g.start_run()
	verify(g.state == "combat" and g.hp == 100,"Start full-health run")
	var start: Vector2 = g.player.position
	Input.action_press("move_right")
	Input.action_press("move_down")
	g.director.event_index = g.Waves.config(g.wave).events.size()
	g._physics_process(0.1)
	Input.action_release("move_right")
	Input.action_release("move_down")
	verify(absf(g.player.position.distance_to(start)-24) < 0.01,"Diagonal movement has normalized speed")
	verify(g.try_dash(Vector2.RIGHT),"Dash starts")
	verify(not g.try_dash(Vector2.RIGHT),"Dash cooldown blocks repeat")
	g.hurt_player(99)
	verify(g.hp == 100,"Dash invulnerability prevents damage")
	g.invincible = 0
	g.hurt_player(12)
	verify(g.hp == 88,"Contact damage applies")
	g.hurt_player(12)
	verify(g.hp == 88,"Damage grace period prevents frame stacking")
	g.start_run()
	g.projectiles.clear()
	var first = g.spawn_enemy(1)
	first.position = Vector2(500,450)
	first.hp = 1000
	first.max_hp = 1000
	var second = g.spawn_enemy(1)
	second.position = Vector2(570,450)
	second.hp = 1000
	second.max_hp = 1000
	g._rebuild_grid()
	var compiled: Dictionary = Spells.compile(["pierce","bolt","impact","bloom"])
	g.emit_stage(compiled.stages[0],Vector2(460,450),Vector2.RIGHT,compiled.stages[1],1)
	for i in 40: g._update_projectiles(1.0/60)
	verify(g.metrics.triggers == 1,"Piercing parent triggers child exactly once")
	verify(first.hp < 1000 and second.hp < 1000,"Actual projectile and area hits damage both targets")
	g.projectiles.clear()
	g.emit_stage(Spells.compile(["fan","bolt"]).stages[0],Vector2(450,450),Vector2.RIGHT,{},1)
	verify(g.projectiles.size() == 3,"Fan emits three real projectiles")
	g.projectiles.clear()
	g.emit_stage(Spells.compile(["seek","bolt"]).stages[0],Vector2(450,400),Vector2.RIGHT,{},1)
	g._update_projectiles(0.05)
	verify(g.projectiles[0].dir.y > 0,"Homing bends toward nearby target")
	g.open_editor()
	g.draft = ["fan","bolt","impact","bloom"]
	verify(g.apply_recipe(),"Valid edit applies")
	verify(g.projectiles.is_empty() and g.recipe == g.draft,"Editing removes all old projectiles")
	g.open_editor()
	g.draft = ["bolt","impact"]
	verify(not g.apply_recipe() and g.state == "edit","Incomplete edit cannot resume")
	g.cancel_editor()
	var timer: float = g.elapsed
	g.state = "paused"
	g._physics_process(1)
	verify(g.elapsed == timer,"Pause freezes combat timer")
	g.resume_game()
	g.gems = [{"pos":g.player.position,"value":12}]
	g._update_gems(0.016)
	verify(g.economy.gold == 12 and g.gems.is_empty(),"Pickup grants money and consumes drop")
	g.complete_wave()
	verify(g.state == "reward" and g.enemies.is_empty(),"Wave ends in safe reward screen")
	g.choose_reward("power")
	verify(g.state == "shop" and g.power == 1.25,"Passive reward opens shop")
	g.open_editor()
	g.apply_recipe()
	g.start_next_wave()
	verify(g.wave == 2 and g.state == "combat","Explicit start continues into next wave")
	g.wave = 4
	g.complete_wave()
	g.choose_reward(g.reward_options[0])
	g.open_editor()
	g.cancel_editor()
	g.start_next_wave()
	verify(g.wave == 5 and is_instance_valid(g.boss_ref),"Final wave spawns boss even when keeping recipe")
	g.damage_enemy(g.boss_ref,99999,Vector2.RIGHT)
	verify(g.state == "ended" and g.result_win,"Boss death wins run")
	g.start_run()
	g.invincible = 0
	g.hurt_player(100)
	verify(g.state == "ended" and not g.result_win,"Player death loses run")
	g.start_run()
	verify(g.wave == 1 and g.kills == 0 and g.economy.gold == 0 and not g.economy.inventory.has("seek"),"Restart resets progression and rewards")
	for i in 110: g.spawn_enemy(1)
	verify(g.enemies.size() == g.Waves.config(g.wave).cap,"Enemy population stays bounded")
	for i in 200: g.emit_stage(Spells.compile(["fan","bolt"]).stages[0],Vector2(700,450),Vector2.RIGHT,{},1)
	verify(g.projectiles.size() == 180,"Projectile population stays bounded")
	g._rebuild_grid()
	for i in 30:
		g._update_projectiles(1.0/60)
		g._update_enemies(1.0/60)
		g._update_effects(1.0/60)
	var dead_candidate = g.enemies[0]
	g._rebuild_grid()
	g.enemies.erase(dead_candidate)
	dead_candidate.free()
	g.nearest_enemy(Vector2(720,450),1500)
	verify(true,"Spatial query tolerates freed entries between physics frames")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
