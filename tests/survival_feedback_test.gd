extends SceneTree
const Profile=preload("res://scripts/player_profile.gd")
const Timeline=preload("res://scripts/survival_timeline.gd")
const Numbers=preload("res://scripts/damage_numbers.gd")
var g: Node2D
var checks:=0
var failures:=0
var report: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+note)
func fresh() -> void:
	g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false
	g.director.enabled=false;g.encounters.enabled=false;g.invincible=10000
	g.damage_numbers.set_process(false);g.profile.data.damage_numbers=true
	g.rng.seed=3221;g.profile.data.quick_rewards=false
func target(hp := 100.0) -> Node2D:
	var e: Node2D=g.Actor.new();g.actors.add_child(e)
	e.kind=1;e.hp=hp;e.max_hp=hp;e.position=g.player.position+Vector2(200,0)
	g.enemies.append(e);return e
func chest(seed_value: int) -> void:
	g.combat_rewards.rng.seed=seed_value
	g.combat_rewards.queue_chest();g.combat_rewards.tick()
	var id: String=g.combat_rewards.pending[0].id
	check(g.combat_rewards.stage=="chest" and g.combat_rewards.pending[0].options.is_empty(),"Chest has no choices")
	check(g.combat_rewards.open_chest(),"Chest opens")
	g.combat_rewards.reveal_chest(id)
	var bank: Dictionary=g.economy.inventory.duplicate()
	var money: int=g.economy.gold
	g.combat_rewards.reveal_chest(id)
	check(bank==g.economy.inventory and money==g.economy.gold,"Duplicate reveal cannot pay twice")
	check(g.combat_rewards.stage=="edit" and g.combat_rewards.pending.is_empty(),"Automatic chest stays in shared editor, no separate receipt")
func run() -> void:
	root.size=Vector2i(1600,900)
	g=load("res://scenes/main.tscn").instantiate();g.record_runs=false
	g.profile=Profile.new("user://survival-feedback-unused.json")
	root.add_child(g);current_scene=g;await process_frame
	fresh()
	for i in 30: g.damage_enemy(target(1),50,Vector2.ZERO)
	check(g.gems.size()==30,"Every ordinary kill leaves an XP stone")
	check(g.gems.all(func(x):return int(x.xp)==1),"All30 kills preserve one XP")
	for gem in g.gems: gem.pos=g.player.position
	g._update_gems(0)
	check(g.economy.gold==10 and g.combat_rewards.total_xp==30,"30 kills give30 XP and10 money")
	report.kills={"kills":30,"stones":30,"xp":g.combat_rewards.total_xp,"money":g.economy.gold}
	fresh()
	for i in 205: g.gems.append({"pos":Vector2.ZERO,"value":i%2,"xp":1})
	for i in 5: g._update_gems(0)
	var xp:=0
	var money:=0
	for gem in g.gems: xp+=int(gem.xp);money+=int(gem.value)
	check(g.gems.size()==200 and xp==205 and money==102,"Compaction conserves both values")
	check(g.recover_remaining_gems()==102 and g.combat_rewards.total_xp==0,"Rest recovery remains money only")
	check(g.recover_remaining_gems()==0,"Recovery cannot duplicate currency")
	fresh();g.director.reset()
	var samples: Array=[]
	for n in 3601:
		g.elapsed=n*.05;g.wave_time=g.elapsed;g.director.update()
		if n in [20,100,200,400,600,1200,1800,2400,3600]: samples.append({"t":g.elapsed,"alive":g.enemies.size(),"target":Timeline.target(g.elapsed)})
		if n==600: check(g.enemies.size()==10,"Opening30s reaches10, not80")
	check(g.director.stats.events.map(func(e):return e.type)==["elite","crossing","ring","elite"],"First3min event order")
	check(g.enemies.size()<=80,"Events obey chapter cap")
	report.population=samples
	check(Timeline.target(239)>Timeline.target(240),"Low-pressure minute exists")
	for seconds in [0,60,120,360,720,1080,1440,1799]:
		check(Timeline.target(seconds)<=280 and Timeline.interval(seconds)>=.25,"Bounded30minute density/cadence")
	fresh();g.director.reset()
	for i in 10:
		var e:=target();e.position+=Vector2(i*70,0)
	g.elapsed=10;g.wave_time=10;g.director.last_time=10;g.director.next_normal=10
	g.director.update();check(g.enemies.size()==10,"At target adds zero enemies")
	g.damage_enemy(g.enemies[0],1000,Vector2.ZERO);g._remove_dead()
	g.elapsed=10.1;g.wave_time=10.1;g.director.update()
	check(g.enemies.size()==9,"A kill is not refilled next frame")
	g.elapsed=130;g.wave_time=130;g.director.update()
	check(g.director.stats.events.is_empty() and g.director.pending.is_empty(),"Hitch discards past events")
	g.director.clear();g.elapsed=180;g.wave_time=180;g.director.update()
	check(g.director.stats.events.is_empty(),"Clear cancels future events")
	fresh();g.director.start_event("crossing")
	check(g.enemies.size()>=12 and g.enemies.all(func(e):return e.role=="event_crossing"),"Actual fixed-direction bat event")
	var bat: Node2D=g.enemies[0]
	var before: Vector2=bat.position
	var direction: Vector2=bat.tactics.event_direction
	g.player.position+=Vector2(0,300);g._rebuild_grid();g._update_enemies(.1)
	check((bat.position-before).normalized().dot(direction)>.99,"Moving player cannot redirect crossing")
	fresh();g.director.start_event("ring")
	check(g.enemies.size()>=18 and g.enemies.size()<=21,"Ring leaves escape gap")
	check(g.enemies.all(func(e):return e.position.distance_to(g.player.position)>350),"Ring respects safe distance")
	var wall: Node2D=g.enemies[0];before=wall.position
	g._rebuild_grid();g._update_enemies(.1)
	check(wall.position==before,"Ring remains on perimeter")
	g.damage_enemy(wall,1000,Vector2.ZERO)
	check(wall.dead and g.gems.size()==1,"Ring member can be killed for XP")
	g.gems.clear();var kills: int=g.kills
	g.elapsed=19;g._update_enemies(.1);g._remove_dead()
	check(g.enemies.is_empty() and g.gems.is_empty() and g.kills==kills,"Event expiry grants no unearned kills/XP")
	var seeds: Dictionary={}
	for n in 1000:
		g.combat_rewards.rng.seed=n
		var count: int=g.combat_rewards.draw_chest_count()
		if not seeds.has(count): seeds[count]=n
		if seeds.size()==3: break
	check(seeds.size()==3,"Chest supports1/3/5")
	for count in [1,3,5]:
		fresh();chest(seeds[count])
		check(g.combat_rewards.last_chest_results.size()==count,"Exact chest payout%d"%count)
		check(g.economy.inventory.keys().all(func(k):return g.Spells.Progression.rank(k)<=3),"No upgrade above+3")
		check(g.economy.inventory.keys().all(func(k):return g.Spells.Progression.base_id(k) in ["bolt","fan","impact"]),"Chest grants owned types only")
	fresh();g.economy.inventory.clear()
	for id in ["bolt","impact","fan"]: g.economy.inventory[g.Spells.Progression.key(id,3)]=1
	chest(seeds[5])
	check(g.economy.gold==50 and g.economy.inventory.size()==3,"Exhausted pool converts five rewards into50 money")
	fresh()
	var bolt: String=g.Spells.Progression.key("bolt",3)
	var thunder: String=g.Spells.Progression.key("thunder",3)
	# Keep the actual starter equipped inventory valid while upgrading the parent in place.
	for id in ["bolt","thunder"]:
		for n in (4 if id=="thunder" else 3):
			var receipt: Dictionary=g.economy.acquire(id)
			g.apply_acquisition(receipt)
	check(g.economy.inventory.has(bolt) and g.economy.inventory.has(thunder),"Fusion parents reach+3 through real acquisition")
	chest(seeds[5])
	check(g.economy.inventory.has("storm_spear") and g.economy.fusion_history.count("storm_spear")==1,"Ready fusion is automatically granted exactly once")
	check(not g.economy.inventory.has(bolt) and not g.economy.inventory.has(thunder),"Fusion consumes both+3 parents")
	check(g.orb_drafts[0][1]=="storm_spear","Automatic fusion preserves equipped parent's slot")
	check(g.combat_rewards.last_chest_results[0].id=="fuse:storm_spear","Ready fusion has chest priority")
	check(g.economy.owned_token("thunder")=="" and g.economy.owned_token("bolt")=="","Remaining chest rewards cannot recreate consumed parents")
	check(g.economy.can_stock("bolt") and g.economy.can_stock("thunder"),"Consumed parents can return as future level/shop rewards")
	fresh();g.combat_rewards.gain_xp(6);g.combat_rewards.tick()
	var reward: Dictionary=g.combat_rewards.pending[0]
	check(g.combat_rewards.stage=="choice" and reward.options.size()==3,"Levelup retains3 choices")
	check(g.claim_spell_reward(reward.id,reward.options[0],g.combat_rewards.revision),"Level choice claims")
	fresh();g.profile.data.quick_rewards=true;g.combat_rewards.queue_chest();g.combat_rewards.tick()
	await process_frame
	check(g.combat_rewards.pending.is_empty() and not g.combat_rewards.last_chest_results.is_empty(),"Quick chest auto pays")
	fresh();g.gems=[{"pos":Vector2.ZERO,"value":41,"xp":99}];g.wave_time=360
	g.profile.data.quick_rewards=true;g.drop_chest(g.player.position);g.complete_wave()
	await process_frame;g.combat_rewards.continue_combat();g.complete_wave()
	check(g.state=="shop" and g.combat_rewards.total_xp==0,"Rest after chest/sweep advances without XP")
	fresh();var enemy:=target(1);g.damage_enemy(enemy,50,Vector2.ZERO)
	check(g.damage_numbers.entries[0].amount==50,"Overkill shows hit strength, not leftover1HP")
	check(Numbers.number_text(4.8)=="5" and Numbers.number_text(.1)=="1","Integer presentation preserves positive tiny hits")
	g.damage_numbers.clear();enemy=target();g.damage_enemy(enemy,7,Vector2.ZERO)
	before=g.damage_numbers.entries[0].pos;enemy.position+=Vector2(30,0);g.damage_numbers.advance(.05)
	check(g.damage_numbers.entries[0].pos==before+Vector2(30,0),"Popup briefly follows target")
	g.damage_numbers.advance(.1);before=g.damage_numbers.entries[0].pos;enemy.position+=Vector2(30,0);g.damage_numbers.advance(.05)
	check(g.damage_numbers.entries[0].pos==before,"Popup releases after initial follow")
	enemy.queue_free();await process_frame;g.damage_numbers.advance(.3)
	check(g.damage_numbers.entries.is_empty(),"Freed target cleanup safe")
	check(g.camera.zoom==Vector2(.8,.8) and g.visible_world_rect().size==Vector2(2000,1125),"Camera scale0.8 keeps HUD untouched")
	g.set_arena_profile("trial");check(g.camera.zoom==Vector2.ONE,"Trial framing independent")
	g.queue_free();await process_frame
	report.checks=checks;report.failures=failures
	FileAccess.open("res://artifacts/survival-feedback-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RESULT: %d checks / %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
