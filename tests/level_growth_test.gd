extends SceneTree
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1;printerr("FAIL: "+message)
func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.enabled=false
	g.encounters.enabled=false
	g.sound_enabled=false
	g.invincible=1000
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	for base in ["bolt","fan","impact"]:
		for rank in range(1,4):
			var r: Dictionary=g.economy.acquire(base)
			check(r.ok and r.output==g.Spells.Progression.key(base,rank),"Duplicate %s upgrades to +%d"%[base,rank])
			g.apply_acquisition(r)
		check(not g.economy.can_stock(base) and not g.economy.acquire(base).ok,"Max +3 excluded and acquisition rejected: "+base)
		check(g.economy.inventory.get(base+"@3",0)==1,"One actual token remains: "+base)
	check(g.orb_recipes[0]==["fan@3","bolt@3"],"Equipped modifiers and attacks update immediately")
	check(not g.orb_compiled[0].is_empty() and g.cast_spell() and g.projectiles.size()>=6,"Upgraded equipped program casts multi-direction projectiles")
	check(not g.economy.craft_quote("merge","bolt@3").ok,"Manual duplicate merge retired")
	fresh()
	var rev: int=g.economy.revision
	g.state="shop"
	g.shop_time=60
	g.economy.gold=100
	g.economy.roll(g.rng,g.recipe)
	g.economy.select_research("bolt",g.economy.revision)
	check(g.buy_orb(0,g.economy.revision),"Crafting duplicate upgrades same owned spell")
	check(g.economy.inventory.get("bolt@1",0)==1 and "bolt@1" in g.orb_recipes[0],"Craft acquisition updates equipped token")
	check(not g.economy.buy(0,rev),"Stale purchase cannot upgrade twice")
	fresh()
	g.gems.append({"pos":g.player.position,"value":3})
	g._update_gems(.016)
	check(g.economy.gold==3 and g.combat_rewards.total_xp==6,"One collected stone grants separately configured money and XP")
	check(g.combat_rewards.level==2 and g.combat_rewards.xp==0,"XP threshold produces level 2")
	g.combat_rewards.tick()
	await process_frame
	var r: RefCounted=g.combat_rewards
	check(r.stage=="choice" and r.pending.size()==1,"Level reward opens automatically")
	check(r.pending[0].options.size()==3,"Three distinct choices")
	var old_time: float=g.elapsed
	var old_wave: float=g.wave_time
	var old_clocks: Array=g.orb_clocks.duplicate()
	var old_hp: float=g.hp
	g._physics_process(.5)
	g.hurt_player(10)
	check(g.elapsed==old_time and g.wave_time==old_wave and g.orb_clocks==old_clocks and g.hp==old_hp,"Reward freezes clock, casts and damage")
	check(not g.try_dash(Vector2.RIGHT) and not g.cast_spell(),"Cannot dash/cast during choice")
	var first: Dictionary=r.pending[0]
	first.options=["bolt","relic:magnifier","thunder"]
	var reward_id: String=first.id
	var revision: int=r.revision
	check(g.claim_spell_reward(reward_id,"bolt",revision),"Existing spell reward accepted")
	check(not g.claim_spell_reward(reward_id,"bolt",revision),"Double click/stale reward rejected")
	check(r.stage=="ready" and r.paused(),"After reward stay paused with Continue/edit choice")
	await process_frame
	r.edit()
	await process_frame
	check(r.stage=="edit" and g.personal_tab=="inventory" and g.editing_recipe(),"Optional paused inventory allows editing")
	g._physics_process(.3)
	check(g.elapsed==old_time,"Editing after reward stays paused")
	g.board_drop(g.board_data("impact"),1,0)
	check(g.orb_recipes[1]==["impact"],"Paused editor changes second orb immediately")
	g.close_personal()
	await process_frame
	check(r.stage=="ready","Close paused editor returns to Continue screen")
	r.continue_combat()
	g._physics_process(.1)
	check(not r.paused() and g.elapsed>old_time,"Continue resumes simulation")
	g.open_personal("inventory")
	old_time=g.elapsed
	g._physics_process(.1)
	check(g.elapsed>old_time,"Ordinary inventory remains live")
	g.close_personal()
	r.gain_xp(r.required())
	r.tick()
	await process_frame
	r.pending[0].options=["relic:magnifier","thunder","gold"]
	check(g.claim_spell_reward(r.pending[0].id,"relic:magnifier",r.revision) and g.relics.has("magnifier"),"Relic in level-up choices grants actual combat effect")
	check(not "relic:magnifier" in r.candidates(),"Owned unique relic excluded")
	r.continue_combat()
	g.economy.inventory.clear()
	for base in g.Economy.PRICES: g.economy.inventory[base+"@3"]=1
	for relic in g.Relics.DEFINITIONS: g.relics.acquire(relic)
	check(r.candidates().is_empty() and r.fill_options([])==["gold","heal"],"Exhausted reward pool provides money/heal fallback")
	fresh()
	check(r.weight("bolt")==3.0 and r.weight("thunder")==1.0,"Owned items weighted above new items")
	var owned_hits:=0
	var new_hits:=0
	for i in 800:
		var options: Array=r.fill_options([])
		if "bolt" in options: owned_hits+=1
		if "thunder" in options: new_hits+=1
		check(options.size()==3 and options.count(options[0])==1 and options.count(options[1])==1,"Weighted draw has no duplicate choices") if i<2 else 0
	check(owned_hits>new_hits*1.7,"Seeded samples prefer owned spells without guaranteeing them")
	r.gain_xp(50)
	check(r.pending.size()>1 and r.xp<r.required(),"Large pickup retains XP overflow and queues level rewards")
	while not r.pending.is_empty():
		r.tick()
		await process_frame
		var item: Dictionary=r.pending[0]
		g.claim_spell_reward(item.id,item.options[0],r.revision)
		r.continue_combat()
	check(not r.paused(),"Queued levels resolve sequentially without losing selections")
	g.state="trial"
	var total: int=r.total_xp
	var money: int=g.economy.gold
	g.gain_money(20,true)
	check(r.total_xp==total and g.economy.gold==money,"Trial cannot award XP or money")
	fresh()
	g.complete_wave()
	check(g.state=="shop" and not r.paused(),"Wave end enters preparation without extra free relic")
	g.state="combat"
	r.gain_xp(15)
	g.state="shop"
	var saved: Dictionary=g.RunCheckpoint.capture(g)
	check(g.RunCheckpoint.valid(saved),"Checkpoint validates new growth fields")
	var save_path: String="res://artifacts/level-growth-save.json"
	var store=g.RunCheckpoint.new(save_path)
	check(store.write(saved),"Checkpoint writes growth under test-only artifacts")
	var loaded: Dictionary=store.load_data()
	check(not loaded.is_empty(),"Growth checkpoint round-trips")
	if not loaded.is_empty():
		g.RunCheckpoint.apply(g,loaded)
		check(r.level==saved.growth.level and r.total_xp==saved.growth.total_xp,"Restore keeps XP/level")
		check(r.pending.size()==saved.rewards.pending.size() and not r.pending.is_empty(),"Pending level choices survive preparation checkpoint")
		g.state="combat"
		var restored_time: float=g.elapsed
		g._physics_process(.1)
		check(r.paused() and g.elapsed==restored_time,"Restored queued reward pauses before combat can advance")
		r.stage=""
		g.ui.close_modal()
	var legacy: Dictionary=saved.duplicate(true)
	legacy.erase("growth")
	legacy.erase("fusion_history")
	legacy.rewards.pending=[]
	legacy.economy.inventory={"bolt":2,"bolt@1":1,"fan":1,"impact":1}
	legacy.orbs=[["fan","bolt"],["bolt@1"]]
	legacy.drafts=legacy.orbs.duplicate(true)
	check(g.RunCheckpoint.valid(legacy),"Old checkpoint remains readable")
	g.RunCheckpoint.apply(g,legacy)
	check(g.economy.inventory.get("bolt@3",0)==1 and g.Forge.valid(g.orb_recipes,g.economy.inventory),"Legacy duplicate ownership migrates to one upgraded equipped token")
	g.return_title()
	g.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
