extends SceneTree
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; printerr("FAIL: "+message)
func fresh() -> void:
	seed(20261028)
	g.rng.seed=20261028
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.director.enabled=false
	g.encounters.enabled=false
	g.invincible=100000
func equip(bank: Array) -> void:
	g.orb_recipes=bank.duplicate(true)
	g.orb_drafts=bank.duplicate(true)
	g.orb_compiled=[]
	g.orb_trial=[]
	for parts in bank:
		var c: Dictionary=g.Spells.compile(parts)
		g.orb_compiled.append(c.stages if c.ok else [])
		g.orb_trial.append([])
	g.active_orb=0
	g.recipe=bank[0].duplicate()
	g.draft=bank[0].duplicate()
	g.compiled=g.orb_compiled[0]
	g._reset_orb_clocks()
func resolve() -> void:
	while not g.combat_rewards.pending.is_empty():
		g.combat_rewards.tick()
		var item: Dictionary=g.combat_rewards.pending[0]
		g.claim_spell_reward(item.id,item.options[0],g.combat_rewards.revision)
		g.combat_rewards.continue_combat()
	g.ui.close_modal()
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	check(g.RunContent.combat_limit()==1800,"Combat target is 30 minutes")
	for i in range(1,6):
		check(g.RunContent.chapter(i).duration==360,"Each combat chapter lasts six minutes: %d"%i)
	for phase in range(1,5):
		g.elapsed=phase*360-.05
		g.wave_time=359.95
		g._physics_process(.1)
		check(g.state=="shop" and is_equal_approx(g.elapsed,phase*360.0),"Break at exact combat minute %d"%(phase*6))
		var combat_clock: float=g.elapsed
		g._physics_process(10)
		check(g.elapsed==combat_clock,"Preparation excluded from combat clock")
		g.start_next_wave()
		check(g.state=="combat","Ready advances from preparation")
		g.director.enabled=false
		g.encounters.enabled=false
		check(g.wave==phase+1 and not is_instance_valid(g.boss_ref),"No premature final boss before minute 30")
	check(g.wave==5 and g.elapsed==1440,"Final normal chapter begins at 24 minutes")
	g.elapsed=1799.95
	g.wave_time=359.95
	g._physics_process(.1)
	check(g.final_boss_started and is_instance_valid(g.boss_ref) and g.boss_ref.boss,"Final boss appears at minute 30")
	g.director.enabled=false
	g.encounters.enabled=false
	g.elapsed=1960
	g.wave_time=520
	g._physics_process(.01)
	check(g.state=="combat" and not g.result_win,"No old 150-second forced defeat during final boss")
	g.damage_enemy(g.boss_ref,g.boss_ref.hp+1,Vector2.ZERO)
	check(g.state=="ended" and g.result_win,"Only final boss death wins")
	fresh()
	var r: RefCounted=g.combat_rewards
	var owned: Array=r.candidates(true)
	check(owned.has("bolt") and owned.has("fan") and not owned.has("thunder") and not owned.any(func(id):return id.begins_with("relic:")),"Chest candidates contain owned magic, never fresh magic or relics")
	g.drop_chest(g.player.position+Vector2(300,0))
	g.collect_chests()
	check(g.chests.size()==1 and r.pending.is_empty(),"Distant chest remains on battlefield")
	g.player.position+=Vector2(300,0)
	g.collect_chests()
	check(g.chests.is_empty() and r.pending.size()==1 and r.pending[0].source=="chest","Nearby chest queues one reward")
	r.tick()
	var clock: float=g.elapsed
	g._physics_process(.1)
	check(r.paused() and g.elapsed==clock,"Chest pauses simulation")
	check(g.claim_spell_reward(r.pending[0].id,"bolt",r.revision) and g.economy.inventory.has("bolt@1"),"Ordinary chest upgrades an owned spell")
	r.continue_combat()
	g.economy.inventory={"bolt@3":1,"thunder@3":1,"fan":1,"impact":1}
	equip([["fan","bolt@3","impact","thunder@3"],[]])
	check(g.economy.fusion_quote("storm_spear").ok,"Two designated +3 parents unlock chest fusion")
	check(not g.economy.craft_quote("fuse","bolt@3","thunder@3").ok,"Cannot bypass chest with old paid fusion")
	var gold: int=g.economy.gold
	r.queue_chest()
	r.tick()
	check("fuse:storm_spear" in r.pending[0].options,"Next chest guarantees an eligible fusion choice")
	var reward: String=r.pending[0].id
	var revision: int=r.revision
	check(g.claim_spell_reward(reward,"fuse:storm_spear",revision),"Fusion reward resolves")
	check(not g.economy.inventory.has("bolt@3") and not g.economy.inventory.has("thunder@3") and g.economy.inventory.get("storm_spear",0)==1,"Consumes exactly two parents and creates one fusion")
	check(g.economy.gold==gold and g.Forge.valid(g.orb_recipes,g.economy.inventory),"Fusion is free and equipped ownership remains valid")
	check(g.orb_recipes[0]==["fan","storm_spear"],"Consumed linked parent removes orphan connector, not retargets it")
	check(not g.claim_spell_reward(reward,"fuse:storm_spear",revision),"Stale chest click cannot create another fusion")
	r.continue_combat()
	var got: Dictionary=g.economy.acquire("bolt")
	g.apply_acquisition(got)
	check(got.ok and got.output=="bolt" and g.economy.inventory.get("bolt",0)==1,"Consumed parent reappears at base rank")
	g.economy.inventory.erase("bolt")
	g.economy.inventory["bolt@3"]=1
	g.economy.inventory["thunder@3"]=1
	check(not g.economy.fusion_quote("storm_spear").ok and not "fuse:storm_spear" in r.candidates(true),"Completed fusion cannot repeat even with both parents again")
	fresh()
	g.economy.inventory={"bolt@3":1}
	equip([["bolt@3"],[]])
	check(r.fill_options([],true)==["gold","heal"],"Exhausted chest uses money/heal instead of new spell")

	for sample in [
		{"id":"wave_split","inventory":{"fan@3":1,"echo@3":1,"bolt":1},"bank":[["fan@3","bolt"],["echo@3"]],"expected":[["wave_split","bolt"],[]]},
		{"id":"dual_event","inventory":{"impact@3":1,"expire@3":1,"bolt":1,"thunder":1},"bank":[["bolt","impact@3","thunder"],["expire@3"]],"expected":[["bolt","dual_event","thunder"],[]]}]:
		fresh()
		g.economy.inventory=sample.inventory.duplicate()
		equip(sample.bank)
		r.queue_chest()
		r.tick()
		check("fuse:"+sample.id in r.pending[0].options,"Chest supports modifier/connector fusion: "+sample.id)
		check(g.claim_spell_reward(r.pending[0].id,"fuse:"+sample.id,r.revision) and g.orb_recipes==sample.expected,"Cross-orb parents reconcile into one equipped fusion: "+sample.id)
		check(g.Forge.valid(g.orb_recipes,g.economy.inventory) and g.Spells.compile(g.orb_recipes[0]).ok,"Resulting modifier/connector program still executes: "+sample.id)
		r.continue_combat()
	fresh()
	g.complete_wave()
	g.economy.gold=1000
	var before: int=g.economy.revision
	check(g.workshop_buy("orb",before) and g.orb_recipes.size()==3,"Craft third six-slot orb")
	check(g.economy.gold==820 and not g.workshop_buy("orb",before) and not g.workshop_buy("orb",g.economy.revision),"Third orb charged once; stale request and fourth orb rejected")
	g.select_orb(2)
	check(not g.workshop_buy("upgrade",g.economy.revision,0),"Previous orb upgrade callback rejects changed target")
	check(g.workshop_buy("upgrade",g.economy.revision,g.active_orb) and g.orb_upgrades==[0,0,1],"Upgrade only the selected orb")
	check(is_equal_approx(g.orb_delay(1,2),g.orb_delay(1,0)/1.1),"Orb speed improvement changes actual cast delay")
	for i in 2: g.workshop_buy("upgrade",g.economy.revision,g.active_orb)
	var money: int=g.economy.gold
	check(not g.workshop_buy("upgrade",g.economy.revision,g.active_orb) and g.economy.gold==money,"Max orb rank cannot consume money")
	g.economy.gold=100
	var relic: String=g.workshop_relics[0]
	check(g.workshop_buy("relic:"+relic,g.economy.revision) and g.relics.has(relic) and g.economy.gold==20,"Craft unowned relic from displayed preparation stock")
	check(not g.workshop_buy("relic:"+relic,g.economy.revision),"Unique relic cannot be purchased twice")
	g.economy.acquire("thunder")
	check(g.board_drop(g.board_data("thunder"),2,0),"Third orb accepts owned spell through real editor")
	var saved: Dictionary=g.RunCheckpoint.capture(g)
	check(g.RunCheckpoint.valid(saved),"Three-orb preparation checkpoint validates")
	var current_time: float=g.elapsed
	g.start_trial()
	g.set_physics_process(false)
	check(g.state=="trial" and g.orb_trial.size()==3,"Real trial prepares three orb programs")
	g._physics_process(.05)
	g.end_trial()
	check(g.state=="shop" and g.elapsed==current_time and g.orb_cursors.size()==3,"Trial exit preserves three-orb clocks and combat time")
	r.queue_chest()
	saved=g.RunCheckpoint.capture(g)
	check(g.RunCheckpoint.valid(saved),"Pending level-one chest validates independently of level reward")
	var path: String="res://artifacts/survival-save.json"
	var store=g.RunCheckpoint.new(path)
	check(store.write(saved),"Three-orb checkpoint writes")
	var loaded: Dictionary=store.load_data()
	var damaged: Dictionary=loaded.duplicate(true)
	damaged.erase("run_rules")
	damaged.erase("orb_upgrades")
	check(not g.RunCheckpoint.valid(damaged),"Malformed legacy three-orb checkpoint rejected before apply")
	g.RunCheckpoint.apply(g,loaded)
	check(g.orb_recipes.size()==3 and g.orb_compiled.size()==3 and g.orb_trial.size()==3 and g.orb_clocks.size()==3 and g.orb_cursors.size()==3,"Restore resizes every runtime orb array")
	check(g.orb_upgrades==[0,0,3] and g.workshop_relics==saved.workshop_relics and g.relics.has(relic),"Restore preserves upgrades, relic stock and ownership")
	check(r.pending.size()==1 and r.pending[0].source=="chest","Restore preserves chest source")
	r.pending.clear()
	g.state="combat"
	equip([[],[],["thunder"]])
	g.orb_clocks.fill(0)
	var casts: int=g.metrics.casts
	g._tick_orbs(.016)
	check(g.metrics.casts==casts+1,"Third orb executes an independent actual cast")
	g.state="trial"
	g.orb_compiled=[[],[],[]]
	g.orb_trial=[[],[],g.Spells.compile(["thunder"]).stages]
	g.orb_clocks.fill(0)
	casts=g.metrics.casts
	g._tick_orbs(.016)
	check(g.metrics.casts==casts+1,"Edited third-orb trial casts even if committed orb was empty")
	g.state="combat"
	check(not g.workshop_buy("upgrade",g.economy.revision,g.active_orb),"Cannot buy orb upgrades during combat")
	fresh()
	check(g.orb_recipes.size()==2 and g.orb_upgrades==[0,0] and g.chests.is_empty() and g.workshop_relics.is_empty(),"New run clears extra orbs, upgrades, chest and workshop stock")

	g.complete_wave()
	var legacy: Dictionary=g.RunCheckpoint.capture(g)
	legacy.erase("run_rules")
	legacy.erase("orb_upgrades")
	legacy.erase("workshop_relics")
	legacy.elapsed=60
	legacy.wave_time=60
	check(g.RunCheckpoint.valid(legacy),"Legacy two-orb short preparation remains readable")
	g.RunCheckpoint.apply(g,legacy)
	check(g.elapsed==360 and g.wave_time==360 and g.orb_upgrades==[0,0],"Legacy checkpoint resumes at matching six-minute rest")
	fresh()
	for t in [0,359,719,1079,1439,1799]:
		check(g.Waves.population(t)<=300 and g.Waves.population(t)>=15,"Population curve remains within intended horde bounds at %d"%t)
	check(g.Waves.population(1799)>=290,"Late run targets roughly 300 simultaneous enemies")
	g.wave=5
	g.elapsed=1700
	g.wave_time=260
	g.director.reset()
	g.encounters.enabled=false
	var safe_spawns:=true
	for i in 120:
		g.wave_time+=.25
		g.elapsed+=.25
		g._rebuild_grid()
		g._update_enemies(.25)
		var count: int=g.enemies.size()
		g.director.update()
		for j in range(count,g.enemies.size()):
			var e: Node2D=g.enemies[j]
			if e.position.distance_to(g.player.position)<g.Waves.SAFE_DISTANCE or g.visible_world_rect().grow(24).has_point(e.position): safe_spawns=false
	check(g.enemies.size()>=230,"Director fills a real scattered horde, not just a higher cap (%d)"%g.enemies.size())
	check(safe_spawns,"Horde spawns outside view and player safety radius")
	var near: int=g.enemies.size()
	g.director.clear()
	g.director.update()
	check(g.enemies.size()==near and g.director.pending.is_empty(),"Cleared director leaves no pending spawn burst")
	var earned:=0
	for i in 600: earned+=g.director.reward(1)
	check(earned==200,"Long fight has no obsolete per-wave currency ceiling")
	g.return_title()
	g.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
