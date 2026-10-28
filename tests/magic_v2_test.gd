extends SceneTree
const Spells = preload("res://scripts/spells.gd")
const P = preload("res://scripts/spell_progression.gd")
const Economy = preload("res://scripts/economy.gd")
const Migration = preload("res://scripts/spell_role_migration.gd")
const Meter = preload("res://scripts/combat_meter.gd")
var g: Node2D
var checks := 0
var failures := 0
var report := {"version":"magic-user-v2","seed":731,"fusion_events":{},"stress":{}}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+text)
func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.clear()
	g.encounters.enabled = false
	g.meter = Meter.new()
	g.player.position = Vector2(800,450)
	g.cast_target = Vector2(1000,450)
	g.aim = Vector2.RIGHT
	g.rng.seed = 731
func enemy(at: Vector2) -> Node2D:
	var e = g.spawn_enemy(1)
	e.position = at
	e.hp = 100000
	e.max_hp = e.hp
	g._rebuild_grid()
	return e
func emit(parts: Array) -> Dictionary:
	var parsed := Spells.compile(parts)
	if not parsed.ok:
		check(false,"Compile fixture "+str(parts))
		return {}
	var stage: Dictionary = parsed.stages[0]
	g.magic.begin_tick()
	g.emit_stage(stage,g.player.position,Vector2.RIGHT,Spells.follow(stage),1)
	return stage
func tick(seconds: float) -> void:
	for i in ceili(seconds*120):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/120)
		g.magic.update_zones(1.0/120)
		g._update_effects(1.0/120)
func total(id: String) -> float: return float(g.meter.totals.get(id,0))
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.record_runs = false
	g.sound_enabled = false
	g.set_physics_process(false)
	await process_frame
	check(Spells.PARTS.size()==18 and P.FUSIONS.keys().filter(func(id):return P.fusion_kind(id)=="attack").size()==9,"18 basic spell types and nine fusions")
	check(not Spells.has_part("sigil") and not Economy.PRICES.has("sigil"),"Sigil is unavailable")
	for id in Spells.PARTS:
		for r in 4:
			var token := P.key(id,r)
			check(Spells.has_part(token) and Spells.upgradeable(token),"All spells upgrade: "+token)
			check(not Spells.has_part(P.key(id,4)),"Rank four is not an active token")
			if r<3:
				var eco := Economy.new()
				eco.inventory = {token:1}
				eco.gold = 999
				var q := eco.craft("upgrade",token,"",eco.revision)
				check(q.ok and eco.inventory=={P.key(id,r+1):1} and eco.gold==999-ceili(Economy.PRICES[id]*(0.5+0.25*r)),"Paid upgrade exact consumption: "+token)
		var eco := Economy.new()
		eco.inventory = {P.key(id,3):1,id:1}
		eco.gold = 500
		var before := eco.inventory.duplicate()
		check(not eco.craft("merge",P.key(id,3),id,eco.revision).ok and eco.inventory==before and eco.gold==500,"Overflow loses nothing: "+id)
	for example in [[0,0,1],[1,0,2],[2,0,3],[1,1,2],[2,1,3],[2,2,4]]:
		for reverse in [false,true]:
			var a := P.key("impact",example[1] if reverse else example[0])
			var b := P.key("impact",example[0] if reverse else example[1])
			check(P.merge_rank(a,b)==example[2],"Symmetric merge result "+str(example))
	fresh()
	check(not g.economy.inventory.has("sigil") and g.economy.inventory.has("fan"),"Legacy starter ID remains compatible without sigil")
	var plan := Migration.plan({"bolt@4":1,"sigil@3":1},[["sigil@3","bolt@4"],[]],[["bolt@4"],[]])
	check(plan.inventory=={"bolt@3":1,"bolt":1} and plan.refund==0 and plan.applied[0]==["bolt@3"],"Legacy rank four retains final ingredient; retired sigil gives no free replacement")
	check(not Migration.plan(plan.inventory,plan.applied,plan.drafts).changed,"Migration is repeat-safe")
	for r in 4:
		fresh()
		emit([P.key("bolt",r)])
		check(g.projectiles.size()==[1,3,4,6][r],"Native bolt count rank "+str(r))
		var actual: Array = []
		for p in g.projectiles: actual.append(roundi(fposmod(rad_to_deg(p.dir.angle()),360)))
		check(actual==[[0],[0,150,210],[0,90,180,270],[0,60,120,180,240,300]][r],"Native bolt directions "+str(r))
		fresh()
		emit([P.key("satellite",r)])
		tick(0.01)
		check(g.magic.behavior.orbits[0].bodies.size()==[2,4,6,8][r],"Native satellite count "+str(r))
		fresh()
		var st := emit([P.key("thunder",r)])
		var strike: Dictionary = g.magic.behavior.strikes[0]
		check(strike.strike_radius==[45.0,60.0,75.0,90.0][r] and strike.pulses_left==[1,1,2,3][r],"Lightning radius and pulses "+str(r))
		tick(1.1)
		check(total("lightning_pulses")==[1,1,2,3][r],"Actual repeated strikes "+str(r))
		fresh()
		st = emit([P.key("frost",r)])
		var cone: Dictionary = g.magic.behavior.flashes[0]
		check(is_equal_approx(rad_to_deg(cone.half_angle)*2,[60,70,80,90][r]),"Cold cone width "+str(r))
		check(Spells.attack_data(st).targets==[4,6,8,10][r],"Cold target count "+str(r))
		fresh()
		emit([P.key("echo",r),"bolt"])
		check(g.magic.echoes.size()==r+1,"Echo repeats rank "+str(r))
		tick(1.0)
		check(total("projectiles_emitted")==r+2,"Echo copies never recursively copy")
		var seek: Dictionary = Spells.Effects.profile(Spells.compile([P.key("seek",r),"bolt"]).stages[0],"seek")
		check(is_equal_approx(seek.value,[0.35,0.55,0.8,1.05][r]) and is_equal_approx(seek.range,[0.6,0.75,0.9,1.05][r]),"Weak tracking rank "+str(r))
	fresh()
	emit(["fan@3","bolt@3"])
	check(g.projectiles.size()==11,"Native six directions plus five, never 36")
	var bundle_damage := 0.0
	for p in g.projectiles: bundle_damage += p.damage
	check(bundle_damage>=6*22 and bundle_damage<6*22*1.3,"Fan preserves the native six-direction damage budget instead of penalizing multi-shot upgrades")
	fresh()
	emit(["fan@3","satellite@3"])
	tick(.01)
	check(g.magic.behavior.orbits[0].bodies.size()==13,"Eight orbitals plus five, never 48")
	# Exercise connector factors directly against real runtime objects, including a three-stage chain.
	for r in 4:
		fresh()
		emit(["bolt",P.key("impact",r),"bolt","expire","bolt"])
		var parent: Dictionary = g.projectiles[0]
		g.magic.trigger(parent,parent.pos)
		g.magic.trigger(parent,parent.pos)
		var child: Dictionary = g.projectiles[1]
		check(g.projectiles.size()==2 and is_equal_approx(child.damage,22*[.5,.65,.8,1.0][r]),"First impact once and connector potency "+str(r))
		g.magic.trigger(child,child.pos,"expire")
		check(is_equal_approx(g.projectiles.back().damage,11.0),"Grandchild uses its own 50%, never compounded attenuation")
	fresh()
	emit(["fan","bolt","impact","bolt"])
	var parent: Dictionary = g.projectiles[0]
	g.magic.trigger(parent,parent.pos)
	check(is_equal_approx(g.projectiles.back().damage,22*.4*.4*.5),"Parent partition survives; child's own fan partitions again without connector compounding")
	fresh()
	emit(["echo@3","satellite"])
	tick(.8)
	check(g.magic.behavior.orbits.size()==5 and total("orbits_blocked")==0,"All four upgraded orbital echoes coexist with the original")
	fresh()
	var victim := enemy(Vector2(1000,450))
	emit(["boomerang"])
	var moon: Dictionary = g.projectiles[0]
	tick(.14)
	check(absf(moon.pos.y-450)>8,"Boomerang physically follows an arc")
	tick(.5)
	check(moon.returning and total("boomerang_returns")==1,"Zero ricochets immediately returns after first hit")
	var hp_after: float = victim.hp
	tick(1)
	check(victim.hp==hp_after,"Returning moon does not strike the same enemy again")
	fresh()
	for point in [Vector2(1000,450),Vector2(1090,530),Vector2(1170,450),Vector2(1240,530)]: enemy(point)
	emit(["boomerang@3"])
	tick(2.5)
	check(total("boomerang_ricochets")==3 and total("projectile_contacts")==4,"Rank-three moon hits four distinct targets")
	fresh()
	for n in 10:
		g.player.position = Vector2(560+n*24,450)
		g.magic.behavior.update(.1)
	emit(["fan","ember_path@3"])
	check(g.magic.zones.size()==3 and g.magic.zones.all(func(z):return z.path_points.size()==1),"Three circular footprints are placed at current feet instead of replaying history")
	var tracks: Array = g.magic.zones
	check(tracks[0].pos.y!=tracks[1].pos.y and tracks[1].pos.y!=tracks[2].pos.y,"Fan creates parallel circles, not alternating wiggles")
	var middle: Vector2 = tracks[1].pos
	check(g.magic.behavior.path_contains(tracks[1],middle) and not g.magic.behavior.path_contains(tracks[1],middle+Vector2(60,0)),"Footprint collision is circular with no invisible connecting line")
	check(tracks[0].life==3.0 and tracks[0].radius==42.0,"Ember rank controls width and persistence")
	fresh()
	for n in 12:
		g.player.position = Vector2(500+n*24,450)
		g.magic.behavior.update(.05)
	emit(["firework_trail"])
	var contact := enemy(g.player.position)
	tick(.32)
	var contact_rings: Array = g.effects.filter(func(f):return f.kind=="ring" and f.pos.distance_to(contact.position)<30)
	check(not contact_rings.is_empty() and total("fusion_firework_trail")==1,"Trail-end contact explodes at the victim, not historical path origin")
	# Every fusion is crafted from two +3 physical items and must produce its own observable event.
	var covered := {}
	for id in P.FUSIONS:
		if P.fusion_kind(id)!="attack": continue
		var data: Dictionary = P.FUSIONS[id]
		var eco := Economy.new()
		var a := P.key(data.parents[0],3)
		var b := P.key(data.parents[1],3)
		eco.inventory = {a:1,b:1}
		eco.gold = 12
		var result := eco.craft("fuse",a,b,eco.revision)
		check(result.ok and result.output==id and eco.inventory=={id:1} and eco.gold==0,"Exact fusion materials/cost: "+id)
		check(not Spells.upgradeable(id),"Completed fusion has no upgrade: "+id)
		covered[data.parents[0]] = true
		covered[data.parents[1]] = true
		fresh()
		for point in [Vector2(1000,450),Vector2(1100,500),Vector2(1200,450)]: enemy(point)
		if id=="firework_trail": g.player.position=Vector2(1000,450)
		emit([id])
		tick(6)
		check(total("fusion_"+id)>0,"Observable fusion behavior: "+id)
		report.fusion_events[id] = total("fusion_"+id)
		check(total("chain_depth_blocked")==0 and total("emits_blocked")==0,"No runaway intrinsic program: "+id)
		g.clear_magic()
		check(g.magic.fusion.pending.is_empty() and g.magic.behavior.orbits.is_empty() and g.magic.behavior.strikes.is_empty(),"Forced cleanup cancels fusion delayed work: "+id)
	check(covered.size()==9,"Every attack has at least one fusion route")
	fresh()
	g.state = "shop"
	g.shop_time = INF
	g.economy.inventory = {"bolt@1":1,"bolt":1}
	g.economy.gold = 100
	g.orb_recipes = [["bolt@1"],["bolt"]]
	g.orb_drafts = g.orb_recipes.duplicate(true)
	g.recipe = g.orb_recipes[0].duplicate()
	g.draft = g.recipe.duplicate()
	g._commit_live_board()
	check(g.craft_spell("merge","bolt@1","bolt",g.economy.revision),"Manual merge consumes equipped copies across two orbs")
	check(g.economy.inventory=={"bolt@2":1} and g.orb_drafts==[["bolt@2"],[]],"One physical result replaces target and releases consumed second orb")
	check(g.orb_compiled[0][0].source_id=="bolt@2" and g.orb_compiled[1].is_empty(),"Manual upgrade immediately replaces executable program")
	check(g.start_trial(),"Reconciled upgraded program enters trial")
	g.orb_clocks = [0.0,0.0]
	g._tick_orbs(.001)
	check(g.projectiles.size()==4,"Equipped rank-two trial actually fires four directions")
	var held_gold: int = g.economy.gold
	var held_time: float = g.wave_time
	tick(.4)
	g.end_trial()
	check(g.state=="shop" and g.economy.gold==held_gold and g.wave_time==held_time and g.projectiles.is_empty(),"Trial ends without changing combat time, money or leaving attacks")
	check(g.Waves.config(1).duration==60 and g.Waves.config(4).duration==105 and g.Waves.config(5).duration==150,"Shorter wave sequence and boss hard limit")
	# Repeated two-orb high-count fixture: record actual workload and every limit counter.
	fresh()
	g.wave = 4
	for n in 48:
		var e = g.spawn_enemy(1)
		e.position = g.player.position+Vector2.RIGHT.rotated(n*TAU/48)*(180+(n%4)*100)
		e.hp = 100000
		e.max_hp = e.hp
	var programs := [Spells.compile(["fan@3","echo@3","seek@3","bolt@3"]).stages[0],Spells.compile(["fan@3","echo@3","ember_path@3"]).stages[0]]
	programs[1]["_orb"] = 1
	var peak_p := 0
	var peak_z := 0
	var samples: Array = []
	for step in 1200:
		var start := Time.get_ticks_usec()
		g.player.position += Vector2(1.0,0.2)
		if step%120==0:
			for st in programs: g.magic.emit(st,g.player.position,Vector2.RIGHT,{},1)
		tick(1.0/120)
		peak_p = maxi(peak_p,g.projectiles.size())
		peak_z = maxi(peak_z,g.magic.zones.size())
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	report.stress = {"seconds":10,"stationary_high_health_enemies":48,"peak_projectiles":peak_p,"peak_paths":peak_z,"p95_sim_ms":samples[int(samples.size()*.95)],"max_sim_ms":samples.back(),"totals":g.meter.totals}
	check(total("projectiles_blocked")+total("echoes_blocked")+total("paths_blocked")+total("emits_blocked")+total("orbits_blocked")+total("zones_evicted")==0,"Representative two-orb high-count fixture avoids safety clipping")
	g.clear_magic()
	report["checks"] = checks
	report["failures"] = failures
	var file := FileAccess.open("res://artifacts/magic-v2-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RESULT: %d checks / %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures>0 else 0)
