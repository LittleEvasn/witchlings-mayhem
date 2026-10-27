extends SceneTree
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1;printerr("FAIL: "+message)
func fresh(number := 1) -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.record_runs=false
	g.invincible=10000
	g.wave=number
	g.wave_time=31
	g.wave_kills=12
	g.rng.seed=123456+number
	g.director.reset()
	g.director.enabled=false
	g.encounters.begin_wave()
	g.orb_compiled=[[],[]]
func first_carrier() -> Node2D:
	g.combat_rewards.tick()
	g.encounters.update(1.2)
	return g.encounters.carrier
func damage_all_group() -> void:
	var targets: Array=g.encounters.escorts.duplicate()
	if is_instance_valid(g.encounters.carrier): targets.append(g.encounters.carrier)
	for enemy in targets:
		if is_instance_valid(enemy) and not enemy.dead: g.damage_enemy(enemy,99999,Vector2.ZERO)
func find(node: Node, value: String) -> Node:
	if str(node.name)==value: return node
	for child in node.get_children():
		var found:=find(child,value)
		if found!=null: return found
	return null
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	check(g.Waves.ENEMY_SPEED[1]>140 and g.Waves.SWARM_SPEED<g.Waves.ENEMY_SPEED[1],"Common enemies close distance faster while weak packs stay slower")
	check(g.Waves.config(2).heavy_cap==1 and g.Waves.config(3).ranged_cap==2,"Charge and ranged roles appear before final mixed wave")
	var point: Vector2=g.player.position+Vector2(360,0)
	check(not g.director.available(point,22) and g.director.available(point,22,true),"Only explicit warned encounters can spawn within camera")
	g.combat_rewards.tick()
	check(g.encounters.tells.size()==1 and g.enemies.is_empty() and g.combat_rewards.pending.is_empty(),"Eligible growth announces carrier before spawning, not instant free choice")
	g.combat_rewards.tick()
	check(g.encounters.tells.size()==1,"Repeated eligibility does not queue duplicate carriers")
	var origin: Vector2=g.encounters.tells[0].pos
	g.encounters.update(.5)
	check(g.enemies.is_empty(),"Spawn warning has real delay")
	g.encounters.update(.7)
	var carrier: Node2D=g.encounters.carrier
	check(is_instance_valid(carrier) and carrier.role=="carrier" and carrier.hp>0,"Single reward carrier spawns from announced location")
	if not is_instance_valid(carrier): quit(1);return
	check(carrier.position==origin and origin.distance_to(g.player.position)>=220,"Carrier appears at safe warned distance")
	check(g.enemies.size()==1 and g.encounters.escorts.is_empty(),"Odd wave is individual reward enemy")
	g.player.position=carrier.position-Vector2(160,0)
	var direction: Vector2=g.encounters.velocity(carrier)
	check(direction.dot(carrier.position-g.player.position)>0,"Nearby carrier flees away from player")
	g._update_enemies(.01)
	check(not carrier.facing_left,"Fleeing carrier faces its movement rather than running backward toward player")
	carrier.position=g.enemy_bounds().end-Vector2(30,30)
	g.encounters.decision_clock=0
	g.encounters.velocity(carrier)
	check(g.enemy_bounds().has_point(g.encounters.goal) and carrier.position.distance_to(g.encounters.goal)>70,"Fleeing carrier chooses a usable route near world corner")
	carrier.position=origin
	g.damage_enemy(carrier,99999,Vector2.ZERO)
	check(g.encounters.drop_ready and g.combat_rewards.pending.is_empty() and g.gems.is_empty(),"Defeat drops collectible material instead of remote choice or extra currency")
	g.encounters.died(carrier)
	g.encounters.update(30)
	check(g.encounters.drop_ready and g.encounters.stats.escaped==0,"Defeated carrier's material does not expire or produce escape notice")
	g.player.position=g.encounters.drop_at
	g.encounters.update(.01)
	g.encounters.update(.01)
	check(g.combat_rewards.pending.size()==1 and g.encounters.stats.picked==1,"Approach grants one choice exactly once")
	check(not g.combat_rewards.issue(1,"repeat"),"Pickup and fallback share same once-per-wave identity")
	fresh(2)
	carrier=first_carrier()
	check(is_instance_valid(carrier) and g.encounters.escorts.size()==3 and g.enemies.size()==4,"Even wave uses carrier plus three existing escorts")
	var escort: Node2D=g.encounters.escorts[0]
	var anchor: Vector2=carrier.position+escort.get_meta("formation_offset")
	escort.position=anchor+Vector2(60,0)
	check(g.encounters.velocity(escort).x<0,"Distant escort maintains moving formation")
	g.player.position=escort.position-Vector2(70,0)
	check(g.encounters.velocity(escort).x<0,"Nearby escort engages player")
	g.damage_enemy(carrier,99999,Vector2.ZERO)
	check(not g.encounters.drop_ready,"Group reward waits for remaining escorts")
	damage_all_group()
	check(g.encounters.drop_ready and g.gems.is_empty(),"Clearing reward group produces only shared material, no duplicated coin pool")
	fresh(2)
	carrier=first_carrier()
	g.damage_enemy(carrier,99999,Vector2.ZERO)
	for index in g.encounters.escorts.size():
		var guard: Node2D=g.encounters.escorts[index]
		guard.position=g.enemy_bounds().position
		g.damage_enemy(guard,99999,Vector2.ZERO)
	check(g.player_bounds().has_point(g.encounters.drop_at),"Material from edge kill is moved into reachable player bounds")
	fresh()
	carrier=first_carrier()
	g.encounters.update(25)
	check(carrier.dead and not g.encounters.drop_ready and g.combat_rewards.pending.is_empty(),"Carrier expiry removes opportunity without granting immediate loot")
	g.complete_wave()
	check(g.combat_rewards.pending.size()==1 and g.combat_rewards.pending[0].source=="wave_end","Missed carrier preserves earned growth at wave end")
	check(g.encounters.tells.is_empty() and not g.encounters.drop_ready,"Wave end clears tells, enemies and material state")
	fresh()
	g.combat_rewards.tick()
	g.player.position=g.encounters.tells[0].pos
	g.encounters.update(1.2)
	check(g.encounters.carrier==null and g.encounters.stats.cancelled==1,"Moving into arrival area cancels spawn, never spawns on player")
	g.complete_wave()
	check(g.combat_rewards.pending.size()==1,"Unsafe or capped spawn still preserves earned choice")
	fresh(2)
	g.wave_time=55
	g.combat_rewards.tick()
	g.encounters.update(.01)
	check(g.encounters.tells.size()==2 and g.encounters.tells[0].pos.distance_to(g.encounters.tells[1].pos)>=240,"Simultaneous special arrivals reserve separated warning areas")
	g.encounters.update(1.2)
	check(g.enemies.size()==5 and is_instance_valid(g.encounters.carrier),"Elite and escorted carrier can coexist without blocking each other's arrival")
	fresh(2)
	g.wave_time=55
	g.encounters.update(.01)
	check(g.encounters.tells.size()==1 and g.encounters.tells[0].kind=="sentinel","Pressure elite has its own warning")
	g.encounters.update(1.2)
	var sentinel: Node2D=null
	for enemy in g.enemies:
		if enemy.role=="sentinel": sentinel=enemy
	check(sentinel!=null and sentinel.speed<240 and sentinel.speed>190,"One large pressure elite chases slightly slower than player")
	if sentinel==null: quit(1);return
	check(g.spawn_enemy(3,false,g.player.position+Vector2(-400,0),"sentinel")==null,"Pressure elite simultaneous cap is one")
	var before: Vector2=sentinel.position
	g.damage_enemy(sentinel,1,Vector2.RIGHT)
	check(absf(sentinel.position.x-before.x-.6)<.01,"Super armor resists knockback without damage immunity")
	var frost: Dictionary=g.Spells.compile(["frost"]).stages[0]
	var context: Dictionary=g.magic.behavior.context(frost,sentinel.position,Vector2.RIGHT,{},1,1,"primary",false,123,g.magic.generation)
	g.magic.behavior.hit(sentinel,1,Vector2.ZERO,context,3)
	var status: Dictionary=g.magic.behavior.state_for(sentinel)
	check(is_equal_approx(status.frozen_until-g.magic.behavior.clock,.6),"Pressure elite can still freeze, with reduced control duration")
	g.magic.behavior.clear()
	sentinel.position=g.player.position+Vector2(900,0)
	before=sentinel.position
	g._recycle_distant_enemies()
	check(sentinel.position==before,"Special enemies are not silently relocated to another screen edge")
	fresh(2)
	# At logical width 1600, +800 is on-screen and is intentionally not a safe spawn.
	# Spawn outside view first, then position the movement-only fixture.
	var charger: Node2D=g.spawn_enemy(3)
	charger.position=g.player.position+Vector2(800,0)
	charger.charge_time=g.Waves.CHARGE_SECONDS
	charger.charge_direction=Vector2.LEFT
	charger.cooldown=10
	before=charger.position
	for frame in 57: g._update_enemies(1.0/60)
	check(absf(before.distance_to(charger.position)-327.75)<1,"Long dash travels about328 units, not190")
	before=charger.position
	g._update_enemies(.1)
	check(charger.position.distance_to(before)<1 and charger.recovery_left>0,"Long dash leaves visible recovery window")
	fresh()
	g.combat_rewards.issue(1,"fixture")
	g.open_personal("reward")
	await process_frame
	await process_frame
	var stage: Control=g.ui.personal_root
	var choices: HBoxContainer=find(stage,"RewardChoices")
	check(stage.name=="SpellRewardStage" and choices.get_child_count()==3,"Rewards use separate horizontal three-card stage, not inventory drawer")
	check(stage.get_global_rect().position.y>g.logical_view_size().y*.5 and stage.get_global_rect().end.y<=800,"Reward stage leaves player centre and lower HUD visible")
	check(choices.get_child(0).position.x<choices.get_child(1).position.x and choices.get_child(1).position.x<choices.get_child(2).position.x,"Three options are side by side")
	var time: float=g.wave_time
	Input.action_press("move_right")
	g._physics_process(.1)
	Input.action_release("move_right")
	check(g.wave_time>time and g.state=="combat","Movement and combat time continue during reward reveal")
	var reward: Dictionary=g.combat_rewards.pending[0]
	var id: String=reward.options[0]
	var revision: int=g.combat_rewards.revision
	var bank: Array=g.orb_recipes.duplicate(true)
	check(g.claim_spell_reward(reward.id,id,revision),"Selection grants chosen material")
	await process_frame
	check(g.personal_tab.is_empty() and g.ui.personal_root==null and is_instance_valid(g.ui.reward_receipt),"Selection closes reward stage and displays acquisition receipt")
	check(g.orb_recipes==bank and not g.claim_spell_reward(reward.id,id,revision),"Acquisition never auto-equips or duplicates")
	check(g.ui.RewardReveal.note(g,"bolt").contains("+1"),"Cards expose actual same-component upgrade opportunity")
	g.open_editor()
	check(g.ui.reward_receipt==null and g.personal_tab=="inventory","Acquisition leads back to separate live editor")
	g.complete_wave()
	g.reward_options=["droplet"]
	g.choose_reward("droplet")
	check(g.start_trial(),"Trial still works with new encounter controller")
	var stats: Dictionary=g.encounters.stats.duplicate()
	g._physics_process(1)
	check(g.encounters.stats==stats and g.encounters.tells.is_empty(),"Trial does not spawn field events or advance their schedules")
	g.end_trial()
	g.start_run("sigil")
	g.set_physics_process(false)
	check(g.combat_rewards.pending.is_empty() and g.encounters.tells.is_empty() and not g.encounters.drop_ready,"Restart clears all opportunity and reward state")
	print("RESULT: %d checks / %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
