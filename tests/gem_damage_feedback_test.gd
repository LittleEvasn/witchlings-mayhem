extends SceneTree
const Profile=preload("res://scripts/player_profile.gd")
const Numbers=preload("res://scripts/damage_numbers.gd")
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+note)
func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.director.enabled=false;g.encounters.enabled=false
	g.damage_numbers.set_process(false)
	g.profile.data.damage_numbers=true
	g.rng.seed=4421
func target(hp := 100.0, pos := Vector2.INF) -> Node2D:
	var e: Node2D=g.Actor.new()
	g.actors.add_child(e)
	e.kind=1;e.hp=hp;e.max_hp=hp
	e.position=g.player.position+Vector2(100,0) if pos==Vector2.INF else pos
	g.enemies.append(e)
	return e
func run() -> void:
	root.size=Vector2i(1600,900)
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	g.profile=Profile.new("user://gem-damage-test-profile.json")
	root.add_child(g);current_scene=g
	await process_frame
	fresh()
	var gold: int=g.economy.gold
	g.gems=[{"pos":g.player.position,"value":2}]
	g._update_gems(.01)
	check(g.economy.gold==gold+2 and g.combat_rewards.total_xp==4,"Natural pickup still grants both money and XP")
	check(g.gems.is_empty(),"Natural pickup consumes stone once")
	g.gems=[{"pos":Vector2.ZERO,"value":41}]
	g.recover_remaining_gems()
	check(g.combat_rewards.total_xp==4 and g.economy.gold==gold+43,"Sweep preserves XP already earned by natural pickup")
	fresh()
	g.acquire_relic("brooch");g.hp=50
	gold=g.economy.gold
	g.gems=[{"pos":Vector2.ZERO,"value":20},{"pos":Vector2.ONE,"value":21}]
	check(g.recover_remaining_gems()==41 and g.economy.gold==gold+41,"Bulk recovery preserves entire coin value")
	check(g.combat_rewards.total_xp==0 and g.combat_rewards.level==1 and g.combat_rewards.pending.is_empty(),"Bulk recovery grants no XP or levelup")
	check(g.hp==50 and g.relics.gem_remainder==0,"Money-only sweep does not trigger pickup healing")
	check(g.recover_remaining_gems()==0 and g.economy.gold==gold+41,"Sweep is idempotent")
	fresh()
	gold=g.economy.gold
	g.wave_time=360
	g.gems=[{"pos":Vector2.ZERO,"value":41}]
	g.complete_wave()
	check(g.state=="shop" and g.economy.gold==gold+41+g.Economy.CLEAR_REWARD,"Production rest still pays sweep and clear reward")
	check(g.combat_rewards.total_xp==0 and g.combat_rewards.pending.is_empty(),"Rest sweep cannot open an XP reward")
	gold=g.economy.gold
	g.complete_wave()
	check(g.economy.gold==gold,"Re-entering completed rest cannot pay twice")
	fresh()
	gold=g.economy.gold
	g.profile.data.quick_rewards=true
	g.drop_chest(g.player.position)
	g.gems=[{"pos":Vector2.ZERO,"value":41}]
	g.complete_wave()
	check(g.combat_rewards.stage=="opening" and g.economy.gold==gold+41,"Automatic chest at rest does not prevent money-only recovery")
	g.complete_wave()
	check(g.economy.gold==gold+41 and g.combat_rewards.total_xp==0,"Pending chest/reentry does not repeat sweep or grant XP")
	await process_frame
	check(not g.combat_rewards.last_chest_results.is_empty(),"Earned chest is automatically paid")
	g.complete_wave()
	check(g.state=="shop" and g.economy.gold==gold+41+g.Economy.CLEAR_REWARD,"After chest, rest completes once")
	fresh()
	gold=g.economy.gold
	g.gems=[{"pos":Vector2.ZERO,"value":41}]
	g.end_run(true)
	check(g.economy.gold==gold+41 and g.gems.is_empty() and g.combat_rewards.total_xp==0,"Victory keeps money-only leftover recovery")
	fresh()
	var e:=target()
	var rng_before: int=g.rng.state
	g.damage_enemy(e,22,Vector2.ZERO)
	check(e.hp==78 and g.damage_numbers.entries[0].amount==22,"Popup matches actual health damage")
	check(g.damage_numbers.entries[0].text=="22" and g.rng.state==rng_before,"Number formatting consumes no gameplay RNG")
	g.damage_enemy(e,.25,Vector2.ZERO)
	check(g.damage_numbers.entries.size()==1 and g.damage_numbers.entries[0].amount==22.25 and g.damage_numbers.entries[0].hits==2,"Same-target rapid hits aggregate only their actual damage")
	var held: float=g.damage_numbers.entries[0].started
	g.damage_numbers.advance(.13)
	g.damage_enemy(e,1,Vector2.ZERO)
	check(g.damage_numbers.entries.size()==2 and g.damage_numbers.entries[0].started==held,"Later hit starts a separate popup; old lifetime is not reset")
	g.damage_numbers.advance(.13)
	g.damage_enemy(e,1,Vector2.ZERO)
	check(g.damage_numbers.entries.size()==Numbers.PER_TARGET,"Continuous boss/hits never stack more than2 popups per target")
	g.damage_numbers.advance(.7)
	check(g.damage_numbers.entries.is_empty(),"All popups fade and expire")
	e=target(10)
	g.damage_enemy(e,50,Vector2.ZERO)
	check(e.dead and g.damage_numbers.entries[0].amount==50,"Overkill displays resolved hit50, not remaining HP10")
	g.damage_enemy(e,50,Vector2.ZERO)
	check(g.damage_numbers.entries[0].amount==50,"Dead target cannot display a second hit")
	g.damage_numbers.clear()
	e=target()
	g.damage_enemy(e,0,Vector2.ZERO);g.damage_enemy(e,-1,Vector2.ZERO);g.damage_enemy(e,INF,Vector2.ZERO)
	check(g.damage_numbers.entries.is_empty() and e.hp==100,"Zero/negative/nonfinite damage never produces fake numbers")
	e=target(100,g.player.position+Vector2(3000,0))
	g.damage_enemy(e,7,Vector2.ZERO)
	check(e.hp==93 and g.damage_numbers.entries.is_empty(),"Offscreen damage still applies without unreadable offscreen popups")
	g.profile.data.damage_numbers=false
	e=target()
	g.damage_enemy(e,7,Vector2.ZERO)
	check(e.hp==93 and g.damage_numbers.entries.is_empty(),"Display setting cannot change damage")
	g.profile.data.damage_numbers=true
	g.state="trial"
	e=target()
	g.damage_enemy(e,7.25,Vector2.ZERO)
	check(e.hp==100 and g.trial_damage==7.25 and g.damage_numbers.entries[0].amount==7.25,"Trial dummy shows recorded damage without losing dummy HP")
	check(g.recover_remaining_gems()==0,"Trial never pays bulk recovery")
	fresh()
	var nodes_before: int=g.damage_numbers.get_child_count()
	for i in 130:
		e=target(100,g.player.position+Vector2(i%13*20-120,i/13*10))
		g.damage_enemy(e,1,Vector2.ZERO)
	check(g.damage_numbers.entries.size()==Numbers.MAX_VISIBLE,"Crowd burst has a hard64 popup cap")
	check(g.damage_numbers.get_child_count()==nodes_before and nodes_before==0,"130 hits create no per-hit nodes or tweens")
	var shown: Dictionary=g.damage_numbers.entries[0]
	g.combat_rewards.stage="choice"
	g.damage_numbers._process(.3)
	check(g.damage_numbers.clock==0 and g.damage_numbers.entries.size()==64,"Reward pause freezes damage presentation")
	g.combat_rewards.stage=""
	g.damage_numbers._process(.7)
	check(g.damage_numbers.entries.is_empty(),"Resume expires old visual feedback")
	check(Numbers.number_text(.04)=="1" and Numbers.number_text(.001)=="1","Compact display never rounds positive hits down to zero")
	g.damage_enemy(target(),1,Vector2.ZERO)
	g.clear_magic()
	check(g.damage_numbers.entries.is_empty(),"Trial/recipe/run cleanup removes old numbers")
	g.state="title"
	g.ui.show_settings(true)
	check(g.ui.modal.find_child("DamageNumberSetting",true,false)!=null,"Damage display can be toggled in settings")
	var toggle: Button=g.ui.modal.find_child("DamageNumberSetting",true,false)
	toggle.pressed.emit()
	check(not g.profile.data.damage_numbers and g.damage_numbers.entries.is_empty(),"Real settings button disables and clears numbers")
	check(g.profile.save_profile(),"Display preference saves")
	var restored:=Profile.new(g.profile.path)
	restored.load_profile()
	check(not restored.data.damage_numbers and Profile.new().data.damage_numbers,"Preference persists; new/old profiles default on")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(g.profile.path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(g.profile.path+suffix))
	g.queue_free()
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
