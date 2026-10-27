extends SceneTree
const Spells = preload("res://scripts/spells.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)
	else: print("PASS: "+message)

func run() -> void:
	var parsed := Spells.compile(["fan","seek","bolt","impact","pierce","bloom"])
	verify(parsed.ok and parsed.stages[0].fan and parsed.stages[0].seek and parsed.stages[1].pierce,"Prefix modifiers attach to correct attacks")
	for recipe in [[],["fan"],["bolt","fan"],["fan","fan","bolt"],["bolt","bloom"],["impact","bolt"],["bolt","impact"],["bolt","impact","bloom","impact","bolt"]]:
		verify(not Spells.compile(recipe).ok,"Reject incomplete/postfix recipe "+str(recipe))
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_physics_process(false)
	g.sound_enabled = false
	g.start_run()
	g.director.event_index = g.Waves.config(g.wave).events.size()
	var mouse_direction: Vector2 = g.player.position.direction_to(g.get_global_mouse_position())
	if mouse_direction.is_zero_approx(): mouse_direction = g.aim
	verify(g.cast_spell(),"Mouse aim permits shots without enemies")
	g.projectiles.clear()
	var far = g.spawn_enemy(1)
	far.position = g.player.position+Vector2(300,0)
	var near = g.spawn_enemy(1)
	near.position = g.player.position+Vector2(0,100)
	g.aim = Vector2.LEFT
	verify(g.cast_spell() and g.projectiles[0].dir.is_equal_approx(mouse_direction),"Mouse direction takes precedence over nearest enemy")
	near.dead = true
	g.projectiles.clear()
	g.cast_spell()
	verify(g.projectiles[0].dir.is_equal_approx(mouse_direction),"Dead targets do not change mouse aim")
	g.open_editor()
	g.draft = ["fan","bolt","impact","bloom"]
	verify(g.apply_recipe() and g.projectiles.is_empty(),"Prefix recipe applies and clears old shots")
	g.cast_spell()
	verify(g.projectiles.size() == 3,"Prefix fan emits three projectiles")
	g._rebuild_grid()
	far.hp = 1000
	g.projectiles.clear()
	var linked := Spells.compile(["pierce","bolt","impact","bloom"])
	g.emit_stage(linked.stages[0],far.position-Vector2(40,0),Vector2.RIGHT,linked.stages[1],1)
	for i in 20: g._update_projectiles(1.0/60)
	verify(g.metrics.triggers == 1 and far.hp < 1000,"New grammar still triggers actual child attack on first hit")
	g.hp = 50
	g.gems = [{"pos":g.player.position,"value":12}]
	g._update_gems(0.016)
	verify(g.economy.gold == 12 and g.hp == 50 and g.power == 1,"Drops now grant money without XP healing or power")
	g.gems = [{"pos":Vector2.ZERO,"value":7}]
	g.complete_wave()
	verify(g.state == "reward" and g.economy.gold == 39 and g.enemies.is_empty(),"Clear collects drops and grants 20 G once")
	g.complete_wave()
	verify(g.economy.gold == 39,"Repeated wave completion cannot duplicate money")
	g._physics_process(10)
	verify(g.shop_time == 0 and g.wave == 1,"Passive choice has no preparation countdown")
	verify(g.reward_options == ["power","haste","heart"],"Free rewards are passives only")
	g.choose_reward("seek")
	verify(g.state == "reward","Orb cannot be selected as passive")
	g.choose_reward("power")
	verify(g.state == "shop" and g.shop_time == 60 and g.power == 1.25 and g.economy.offers.size() == 4,"Passive starts 60 second four-offer shop")
	g.choose_reward("power")
	verify(g.power == 1.25,"Reward callback cannot repeat")
	var offer: Dictionary = g.economy.offers[0].duplicate()
	var revision: int = g.economy.revision
	var copies: int = g.economy.inventory.get(offer.id,0)
	verify(g.buy_orb(0,revision),"Buy affordable orb")
	verify(g.economy.gold == 39-offer.price and g.economy.inventory[offer.id] == copies+1,"Purchase deducts price and adds one copy")
	verify(not g.buy_orb(0,revision),"Sold slot cannot be bought twice")
	g.economy.gold = 0
	verify(not g.buy_orb(1,revision) and not g.reroll_shop(revision),"Insufficient money prevents purchases and rerolls")
	g.economy.grant(30)
	verify(g.reroll_shop(revision) and g.economy.gold == 25,"Paid reroll costs exactly 5 G")
	verify(not g.buy_orb(0,revision) and not g.reroll_shop(revision),"Stale offer callbacks cannot spend money")
	g.economy.inventory["bolt"] = 1
	g.open_editor()
	g.draft = ["bolt"]
	g.add_part("bolt")
	verify(g.draft == ["bolt"],"Equipped copy cannot be added twice")
	g.remove_part(0)
	g.add_part("bolt")
	verify(g.draft == ["bolt"] and g.economy.inventory.bolt == 1,"Removing frees copy without consuming or duplicating")
	g.draft = ["bolt","impact","bolt"]
	verify(not g.apply_recipe(),"Two attacks require two owned copies")
	g.economy.inventory.bolt = 2
	verify(g.apply_recipe() and g.state == "shop" and g.wave == 1,"Second copy permits same attack twice; applying stays in shop")
	var before: Array = g.economy.offers.duplicate(true)
	var before_revision: int = g.economy.revision
	g._physics_process(4)
	g.open_editor()
	g._physics_process(3)
	verify(g.shop_time == 53 and g.state == "edit","Shop countdown continues through editing")
	g.cancel_editor()
	verify(g.shop_time == 53 and g.economy.revision == before_revision and g.economy.offers == before,"Returning preserves offers and time")
	var active: Array = g.recipe.duplicate()
	var inventory: Dictionary = g.economy.inventory.duplicate()
	g.open_editor()
	g.draft = ["fan"]
	g.shop_time = 0.01
	g._physics_process(0.02)
	verify(g.state == "combat" and g.wave == 2 and g.recipe == active and g.economy.inventory == inventory,"Timeout discards invalid draft, preserving applied recipe and purchases")
	g.start_next_wave()
	verify(g.wave == 2,"Start callback cannot advance twice")
	verify(not g.buy_orb(1,g.economy.revision),"Combat blocks stale shop purchases")
	g.wave = 4
	g.complete_wave()
	g.choose_reward("heart")
	g.start_next_wave()
	verify(g.wave == 5 and g.state == "combat" and is_instance_valid(g.boss_ref),"Early start reaches final boss")
	g.start_run()
	verify(g.economy.gold == 0 and g.economy.offers.is_empty() and g.economy.inventory.bolt == 1 and g.power == 1 and g.wave == 1,"Restart resets economy and passives")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
