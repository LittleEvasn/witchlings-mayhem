extends SceneTree
const Runner = preload("res://scripts/measurement_runner.gd")
const Meter = preload("res://scripts/combat_meter.gd")
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+note)
func near(a: float, b: float, note: String) -> void: check(is_equal_approx(a,b),note+" (%s vs %s)"%[a,b])
func setup(ids: Array = [], bank: Array = [["bolt"],["bolt"]]) -> void:
	g.start_run()
	g.set_physics_process(false)
	g.set_process_unhandled_input(false)
	g.sound_enabled=false
	g.director.enabled=false
	g.rng.seed=731
	g.relics.rng.seed=919
	g.invincible=0
	g.shop_time=60
	g.orb_recipes=bank.duplicate(true)
	g.orb_drafts=bank.duplicate(true)
	g.orb_compiled=[g.Spells.compile(bank[0]).stages if not bank[0].is_empty() else [],g.Spells.compile(bank[1]).stages if not bank[1].is_empty() else []]
	g.compiled=g.orb_compiled[0]
	g.recipe=bank[0].duplicate()
	g.draft=bank[0].duplicate()
	g.orb_clocks=[0.0,0.0]
	g.orb_cursors=[0,0]
	g.player.position=Vector2(400,430)
	g.cast_target=Vector2(900,430)
	g.aim=Vector2.RIGHT
	g.meter=Meter.new()
	g.meter.detailed_sources=true
	for id in ids: check(g.acquire_relic(id),"Acquire "+str(id))
func stage(parts: Array, orb := 0) -> Dictionary:
	var s: Dictionary=g.Spells.compile(parts).stages[0].duplicate(true)
	s["_orb"]=orb
	return s
func emit(s: Dictionary) -> void:
	g.magic.begin_tick()
	g.emit_stage(s,Vector2(400,430),Vector2.RIGHT,g.Spells.follow(s),1)
func enemy(at: Vector2, hp := 1000.0) -> Node2D:
	var e=g.Actor.new()
	g.actors.add_child(e)
	e.setup(g.art,1)
	e.position=at
	e.hp=hp
	e.max_hp=hp
	e.radius=16
	g.enemies.append(e)
	g._rebuild_grid()
	return e
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	setup()
	check(g.Relics.DEFINITIONS.size()==12,"Exactly twelve relics")
	for id in g.Relics.DEFINITIONS:
		var d: Dictionary=g.Relics.definition(id)
		check(not d.desc.is_empty() and not d.note.is_empty() and not d.detail.is_empty(),"Short and detailed player text: "+id)
		check(d.reward_pool and not d.craft_pool and d.tier=="unassigned","Acquisition pools prepared without assigning tiers: "+id)
	check(not g.acquire_relic("missing"),"Unknown relic rejected")
	check(g.acquire_relic("magnifier") and not g.acquire_relic("magnifier"),"Duplicate acquisition rejected")
	var options: Array=g.relics.choices(g.rng)
	check(options.size()==3 and not "magnifier" in options,"Three unowned candidates")
	for id in g.Relics.DEFINITIONS:
		if id not in ["display","seal"]: g.relics.acquire(id)
	check(g.relics.choices(g.rng).size()==2,"Two remaining candidates")
	g.relics.acquire("display")
	check(g.relics.choices(g.rng)==["seal"],"One remaining candidate")
	g.relics.acquire("seal")
	check(g.relics.choices(g.rng).is_empty(),"Exhausted pool empty")
	g.complete_wave()
	check(g.state=="shop" and g.reward_taken,"Exhausted pool reaches preparation")
	setup()
	g.complete_wave()
	check(g.state=="reward" and g.reward_options.size()==3,"Actual wave reaches relic screen")
	var chosen: String=g.reward_options[0]
	g.choose_reward(chosen)
	check(g.state=="shop" and g.relics.has(chosen),"Reward grants selected relic and opens preparation")
	g.choose_reward(chosen)
	check(g.relics.owned.size()==1 and g.power==1 and g.fire_rate==1 and g.max_hp==100,"No duplicate or old passive bonuses")

	setup(["seal","display","toolbox"])
	g.state="shop"
	g.economy.gold=100
	g.economy.roll(g.rng,g.recipe)
	check(g.economy.offers.size()==5,"Extra random offer plus selection slot")
	check(g.economy.offers.filter(func(o):return o.get("free",false)).size()==1,"One free valid random offer")
	var before: Array=g.economy.offers.duplicate(true)
	for i in 3: g.ui.show_shop()
	check(g.economy.offers==before,"UI rebuild never reassigns free offer")
	var free := -1
	for i in g.economy.offers.size():
		if g.economy.offers[i].get("free",false): free=i
	var revision: int=g.economy.revision
	check(g.buy_orb(free,revision) and g.economy.gold==100,"Free craft deducts zero")
	check(not g.buy_orb(free,revision),"Stale repeated purchase rejected")
	check(g.economy.offers.filter(func(o):return o.price==0 and not o.id.is_empty() and not o.sold).is_empty(),"No second free item in same display")
	check(g.reroll_shop(g.economy.revision) and g.economy.gold==95,"Reconfigure still costs five")
	check(g.economy.offers.filter(func(o):return o.get("free",false) and not o.sold).size()==1,"Reconfiguration grants new free offer")
	g.economy.inventory["bolt"]=2
	var discounted: Dictionary=g.economy.craft_quote("upgrade","bolt")
	g.relics.owned.erase("toolbox")
	var normal: Dictionary=g.economy.craft_quote("upgrade","bolt")
	check(discounted.cost==ceili(normal.cost*.8),"Paid upgrade cost rounded up")
	var merge_normal: Dictionary=g.economy.craft_quote("merge","bolt","bolt")
	g.relics.acquire("toolbox")
	check(g.economy.craft_quote("merge","bolt","bolt").cost==merge_normal.cost,"Merge unaffected")
	var cost_before: int=g.economy.gold
	check(g.craft_spell("upgrade","bolt","",g.economy.revision),"Equipped upgrade succeeds with relic")
	check(g.economy.gold==cost_before-discounted.cost and "bolt@1" in g.orb_recipes[0],"Discount quote matches actual spend and equipped result")

	setup(["crown","hourglass","piggy"])
	g.economy.gold=109
	near(g.caster_power(),1.3*.85*1.2,"All damage bonuses multiply once")
	near(g.cast_delay(.12),.096,"Sequence gap reduced")
	near(g.cast_delay(.48),.384,"Cycle wait reduced")
	var s:=stage(["bolt","impact","bloom","expire","thunder"])
	emit(s)
	var p: Dictionary=g.projectiles[0]
	near(p.damage,22*1.3*.85*1.2,"Direct damage once")
	g.economy.gold=0
	g.magic.trigger(p,Vector2(600,430))
	var child: Dictionary=g.projectiles.back()
	near(child.damage,20*.65*1.3*.85*1.2,"Child retains original power snapshot")
	g.magic.trigger(child,Vector2(600,430),"expire")
	near(g.magic.behavior.damage_scale(g.magic.behavior.strikes.back()),pow(.65,2)*1.3*.85*1.2,"Third stage does not reapply relic multipliers")
	emit(stage(["bolt"]))
	near(g.projectiles.back().damage,22*1.3*.85,"New cast sees spent gold immediately")
	g.economy.gold=19
	near(g.relics.damage_bonus(g.economy.gold),.02,"Piggy uses whole tens")
	g.economy.gold=10000
	near(g.relics.damage_bonus(g.economy.gold),.2,"Piggy caps at twenty percent")

	setup(["magnifier"])
	emit(stage(["bolt","impact","bloom","expire","thunder"]))
	p=g.projectiles[0]
	near(p.radius,6,"Projectile actual hit radius +20%")
	near(p.speed,440,"Projectile speed unchanged")
	near(p.life,2.6,"Projectile lifetime unchanged")
	g.magic.trigger(p,Vector2(600,430))
	child=g.projectiles.back()
	near(child.scale,1.2,"Child scale does not compound")
	g.magic.trigger(child,Vector2(600,430),"expire")
	near(g.magic.behavior.strikes.back().scale,1.2,"Third stage scale does not compound")
	g.clear_magic()
	emit(stage(["storm_spear"]))
	g.magic.fusion.event(g.projectiles[0],"impact",Vector2(600,430))
	near(g.magic.behavior.strikes[0].scale,1.2*1.16,"Fusion built-in scale once")
	g.clear_magic()
	emit(stage(["frost"]))
	near(g.magic.behavior.flashes.back().radius,170,"Frost reach unchanged")
	near(g.magic.behavior.flashes.back().half_angle,PI/6*1.2,"Frost width increased")
	g.clear_magic()
	var edge=enemy(Vector2(400,510),100)
	emit(stage(["bloom"]))
	g.magic.behavior.area(g.projectiles[0],Vector2(400,430),20,70*g.projectiles[0].scale)
	check(edge.hp==80,"Enlarged bloom hits target outside old radius")

	setup(["gloves","magnifier"],[["fan","bolt","impact","bloom","expire","thunder"],[]])
	# A six-slot grammar fixture below exercises fan+echo+two links over two cases.
	var tree:=stage(["fan","bolt","impact","bloom","expire","thunder"])
	for i in 4: emit(tree)
	check(g.relics.cast_count==4 and g.meter.totals.get("relic_copies",0)==1,"Four roots yield exactly one copy despite fan")
	var copied: Dictionary=g.projectiles.filter(func(o):return o.stage.get("_relic_copy",false))[0]
	near(copied.power,.4,"Copy snapshots forty percent power")
	near(copied.damage,22*.4*.4,"Fan and copy each apply once")
	g.magic.trigger(copied,Vector2(650,430))
	child=g.projectiles.back()
	near(child.power,.4,"Copy child retains forty percent, not sixteen")
	near(child.scale,1.2,"Copy child size stays twenty percent")
	check("/relic_copy" in child.meter_source,"Copy child source distinguishable")
	g.magic.trigger(child,Vector2(650,430),"expire")
	near(g.magic.behavior.strikes.back().power,.4,"Third copy stage keeps forty percent")
	check(g.relics.cast_count==4,"Chained stages do not count as direct casts")
	g.clear_magic()
	g.relics.cast_count=3
	emit(stage(["echo","bolt","impact","bloom"]))
	var before_count: int=g.relics.cast_count
	g.magic.begin_tick()
	g._update_projectiles(.19)
	check(g.relics.cast_count==before_count,"Echo and copy do not increment shared count")
	check(g.meter.totals.get("relic_copies",0)==2,"No copy of copy")
	check(g.projectiles.any(func(o):return "/echo/relic_copy" in o.meter_source),"Copied echo tracked separately")
	g.clear_magic()
	g.relics.cast_count=2
	g.orb_compiled=[g.Spells.compile(["bolt"]).stages,g.Spells.compile(["bolt"]).stages]
	g.orb_clocks=[0.0,0.0]
	g._tick_orbs(.01)
	check(g.relics.cast_count==4 and g.projectiles.size()==3,"Both orb clocks share fourth-cast counter")
	check(g.projectiles.back().stage._orb==1,"Fourth cast copy retains actual orb")
	check(g.projectiles.back().pos.is_equal_approx(g.orb_position(1)),"Copy starts at corresponding orb")
	setup(["gloves"])
	var satellite:=stage(["satellite"])
	emit(satellite)
	emit(satellite)
	g.relics.cast_count=3
	emit(satellite)
	check(g.magic.behavior.orbits.any(func(o):return o.stage.get("_relic_copy",false)),"Copied satellite has its own existing lifetime bucket")

	setup(["magnifier","gloves"])
	for id in ["nova_garden","moon_ring","frost_blossom","firework_trail"]:
		g.clear_magic()
		g.relics.cast_count=3
		emit(stage([id]))
		check(g.meter.sources.keys().any(func(k):return id in k and "/relic_copy" in k),"Fusion copy executes and is attributable: "+id)
		check(g.projectiles.size()+g.magic.behavior.orbits.size()+g.magic.zones.size()>0,"Fusion uses actual runtime objects: "+id)
	setup()
	var mixed=enemy(Vector2(600,430),10)
	g.explode(mixed.position,14,30,"mixed",{"primary/bolt/sigil":10,"primary/bolt/relic_copy/sigil":4})
	near(g.meter.totals.damage_effective,10,"Mixed original/copy explosion has one effective budget")
	near(g.meter.totals.kills,1,"Mixed explosion counts one kill")
	near(g.meter.totals.damage_events,1,"Mixed explosion counts one physical hit")
	near(g.meter.sources["primary/bolt/relic_copy/sigil"].damage_raw,4,"Copied mark contribution keeps its real source share")
	setup(["gloves"])
	var ice_target:=enemy(Vector2(450,430),1000)
	var frost_stage:=stage(["frost"])
	frost_stage["_relic_copy"]=true
	g.magic.emit(frost_stage,Vector2(400,430),Vector2.RIGHT,{},1,.4)
	g.magic.emit(frost_stage,Vector2(400,430),Vector2.RIGHT,{},1,.4)
	g.magic.emit(frost_stage,Vector2(400,430),Vector2.RIGHT,{},1,.4)
	var basic:=stage(["bolt"])
	g.magic.emit(basic,Vector2(400,430),Vector2.RIGHT,{},1)
	g.magic.behavior.hit(ice_target,22,Vector2.ZERO,g.projectiles.back())
	near(g.meter.sources["o0/s0/primary/frost/relic_copy/shatter"].damage_raw,8,"Copied cold owns its forty-percent shell damage when original breaks it")
	setup(["gloves"])
	ice_target=enemy(Vector2(450,430),1000)
	for i in 3: g.magic.emit(stage(["frost"]),Vector2(400,430),Vector2.RIGHT,{},1)
	basic=stage(["bolt"])
	basic["_relic_copy"]=true
	g.magic.emit(basic,Vector2(400,430),Vector2.RIGHT,{},1,.4)
	g.magic.behavior.hit(ice_target,8.8,Vector2.ZERO,g.projectiles.back())
	near(g.meter.sources["o0/s0/primary/frost/shatter"].damage_raw,20,"Copied finisher cannot steal original cold's shell attribution")

	setup(["droplet"])
	g.player.position=Vector2(600,430)
	g.hostile_shots=[{"pos":Vector2(700,430),"vel":Vector2(100,0),"life":5}]
	g._update_hostile_shots(.1)
	near(g.hostile_shots[0].pos.x,706.5,"Inside droplet slows displacement")
	g._update_hostile_shots(.1)
	near(g.hostile_shots[0].vel.x,100,"Base velocity never compounded")
	g.hostile_shots[0].pos=Vector2(800,430)
	g._update_hostile_shots(.1)
	near(g.hostile_shots[0].pos.x,810,"Outside droplet restores full displacement")

	setup(["brooch","soul_coat","shoes","crown"])
	g.hp=50
	g.gain_money(19,true)
	near(g.hp,51,"Drop quantity heals once")
	check(g.relics.gem_remainder==9,"Drop remainder preserved")
	g.gain_money(100)
	near(g.hp,51,"Non-drop grant never heals")
	g.gain_money(1,true)
	near(g.hp,52,"Remainder completes heal")
	g.hp=100
	g.gain_money(20,true)
	g.hp=50
	g.gain_money(1,true)
	near(g.hp,50,"Full-health healing not banked")
	for i in 10:
		var e:=enemy(Vector2(850,430),1)
		g.damage_enemy(e,1,Vector2.ZERO)
		g.damage_enemy(e,1,Vector2.ZERO)
	near(g.relics.shield,1,"Each dead enemy counted once")
	g.relics.shield=5
	g.hurt_player(10)
	near(g.hp,43,"Crown amplifies hit once; shield absorbs before health")
	near(g.relics.shield,0,"Shield used up")
	near(g.relics.speed_left,2,"Actual health/shield damage activates shoes")
	g.hurt_player(10)
	near(g.hp,43,"Invulnerability prevents damage and proc")
	g.relics.tick(1)
	g.invincible=0
	g.hurt_player(1)
	near(g.relics.speed_left,1,"Shoes cooldown prevents refresh")
	g.relics.tick(4)
	g.invincible=0
	g.hurt_player(1)
	near(g.relics.speed_left,2,"Shoes rearm after five seconds")
	g.relics.shield=2
	g.relics.kill_remainder=7
	g.relics.gem_remainder=9
	g.complete_wave()
	check(g.relics.shield==0 and g.relics.kill_remainder==0 and g.relics.gem_remainder==9,"Wave cleanup resets shield, not brooch remainder")

	setup(["gloves","shoes","soul_coat","piggy"])
	g.economy.inventory["bolt"]=2
	g.economy.gold=87
	g.relics.cast_count=3
	g.relics.speed_left=1.5
	g.relics.speed_cooldown=4.5
	g.relics.shield=6
	g.hp=60
	g.state="shop"
	var snapshot: Dictionary=g.relics.snapshot()
	var money: int=g.economy.gold
	check(g.start_trial(),"Trial begins with actual relics")
	g._tick_orbs(2)
	g.relics.tick(.5)
	g.gain_money(20,true)
	g.relics.shield=0
	check(g.relics.cast_count>snapshot.casts,"Trial effects actually run")
	g.end_trial()
	check(g.relics.snapshot()==snapshot and g.hp==60 and g.economy.gold==money,"Trial restores counters, RNG, shield, cooldown, HP and money")
	check(g.projectiles.is_empty() and g.magic.echoes.is_empty() and g.magic.behavior.strikes.is_empty(),"Trial reservations cleaned")
	g.start_run()
	g.set_physics_process(false)
	check(g.relics.owned.is_empty() and g.relics.cast_count==0 and g.relics.shield==0 and g.relics.speed_left==0,"New experiment clears all relic state")
	check(g.economy.relics==g.relics and g.caster_power()==1,"Economy retains correct run-local reference")
	setup(["gloves","soul_coat","shoes"])
	g.relics.shield=0
	g.hp=1
	g.hostile_shots=[{"pos":g.player.position,"vel":Vector2.ZERO,"life":1}]
	g._update_hostile_shots(.01)
	check(g.state=="ended" and g.hostile_shots.is_empty() and g.magic.echoes.is_empty(),"Fatal hostile shot cleans reservations without removing cleared-array index")

	var r:=Runner.new(g)
	check(r.begin([["bolt"],["bolt"]],"single",731,"replay",2,1,1,"sigil",{"relics":["gloves","piggy"],"gold":100}),"Measurement accepts explicit relics and gold")
	while r.active: r.step()
	var report: Dictionary=r.report()
	r.stop()
	check(report.relics==["gloves","piggy"] and report.initial_gold==100 and report.player_initial_health==1000000,"Report records comparison conditions")
	check(report.totals.get("relic_copies",0)>0 and report.sources.keys().any(func(k):return "/relic_copy" in k),"Measured copies have distinct source attribution")
	check(r.begin([["bolt"],["bolt"]],"single",731,"replay",2,1,1,"sigil",{"relics":["gloves","piggy"],"gold":100}),"Repeat job valid")
	while r.active: r.step()
	var repeated: Dictionary=r.report()
	check(report.totals==repeated.totals and report.sources==repeated.sources,"Relic combat deterministic with same seed")
	r.stop()
	check(not r.begin([["bolt"],[]],"single",731,"replay",2,1,1,"sigil",{"relics":["wrong"]}),"Invalid measurement relic rejected")
	g.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
