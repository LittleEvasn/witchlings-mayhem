extends SceneTree
const S=preload("res://scripts/spells.gd")
const E=preload("res://scripts/economy.gd")
const P=preload("res://scripts/player_profile.gd")
const Save=preload("res://scripts/run_checkpoint.gd")
var checks:=0
var failures:=0
var g: Node2D
var report: Dictionary={"catalog":{},"runtime":{},"interactions":{},"stress":{}}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+note)
func fresh() -> void:
	g.clear_magic()
	g.meter=load("res://scripts/combat_meter.gd").new()
	g.meter.detailed_sources=true
	for e in g.enemies: e.queue_free()
	g.enemies.clear()
	g.player.position=Vector2(800,450)
	g.cast_target=Vector2(950,450)
	g.aim=Vector2.RIGHT
	g.rng.seed=7301
	g.state="combat"
	g.combat_rewards.reset(7301)
	g.economy.inventory={"bolt":1}
func enemy(at: Vector2) -> Node2D:
	var e: Node2D=g.Actor.new()
	g.actors.add_child(e)
	e.setup(g.art,1)
	e.position=at;e.hp=100000;e.max_hp=e.hp;e.speed=0
	g.enemies.append(e)
	return e
func grid() -> void:
	for y in 5:
		for x in 6: enemy(Vector2(760+x*45,360+y*45))
	g._rebuild_grid()
func emit(parts: Array) -> Dictionary:
	var program:=S.compile(parts)
	check(program.runnable_count>0,"Program runs: "+str(parts))
	if program.runnable_count==0: return {}
	var stage: Dictionary=S.roots(program.stages)[0]
	g.magic.begin_tick()
	g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(950,450))
	return stage
func step(seconds: float, hz:=60) -> void:
	for frame in ceili(seconds*hz):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/hz)
		g.magic.update_zones(1.0/hz)
func count(key: String) -> float: return float(g.meter.totals.get(key,0))
func run() -> void:
	root.size=Vector2i(1920,1080)
	check(S.PARTS.size()==30 and S.Progression.FUSIONS.size()==30,"Exactly 30 basic and 30 completed spells")
	var pairs: Dictionary={}
	var partners: Dictionary={}
	for id in S.PARTS:
		check(E.PRICES.has(id),"Reward and crafting price: "+id)
		for rank in 4:
			var token:=S.Progression.key(id,rank)
			check(S.has_part(token) and not S.definition(token).desc.is_empty(),"Named, described and upgradeable: "+token)
	for id in S.Progression.FUSIONS:
		var data: Dictionary=S.Progression.FUSIONS[id]
		var parents: Array=data.parents.duplicate();parents.sort()
		var key:=str(parents)
		check(not pairs.has(key),"Distinct recipe: "+id);pairs[key]=true
		for parent in parents:
			check(S.PARTS.has(parent),"Existing fusion parent: "+id+"/"+parent)
			partners[parent]=int(partners.get(parent,0))+1
		check(S.Progression.fusion_for(parents[0]+"@3",parents[1]+"@3")==id and S.Progression.fusion_for(parents[1]+"@3",parents[0]+"@3")==id,"Recipe symmetric: "+id)
		var econ:=E.new()
		econ.inventory={parents[0]+"@3":1,parents[1]+"@3":1};econ.gold=100
		var quote:=econ.fusion_quote(id)
		check(quote.ok and quote.cost==0 and quote.inventory.size()==1 and quote.inventory.has(id) and econ.inventory.size()==2,"Free fusion quote consumes exactly two after commit, no preview consumption: "+id)
		econ.fusion_history.append(id)
		check(not econ.fusion_quote(id).ok,"Once per recipe per run: "+id)
	for id in partners: check(partners[id]==2,"Every basic has two fusion partners: "+id)
	check(not S.has_part("storm_spear") and not S.has_part("wave_split"),"Retired recipes no longer executable/rewarded")
	var mods: Array=S.PARTS.keys().filter(func(id):return S.PARTS[id].kind=="modifier")
	var attacks: Array=S.PARTS.keys().filter(func(id):return S.PARTS[id].kind=="attack")
	check(attacks.size()==12 and mods.size()==15,"12 attacks, 11 modifiers + 4 elements, 3 connectors")
	for m in mods:
		for a in attacks:
			var c:=S.compile([m,a,"impact","bolt"])
			check(c.ok and c.stages[0].modifiers.size()==1 and c.stages[0].next.modifiers.is_empty(),"Scope and support adapter "+m+"/"+a)
	var hole:=S.compile(["","fall","","bolt","timer","","laser"])
	check(hole.ok and hole.stages[0].slot==3 and hole.stages[1].slot==6 and hole.stages[1].modifiers.is_empty(),"Sparse positions and timer boundary preserved")
	g=load("res://scenes/main.tscn").instantiate();g.record_runs=false
	g.profile=P.new("user://magic60-test-unused.json")
	root.add_child(g);current_scene=g
	await process_frame
	g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false
	g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	# Every basic attack and every completed attack must actually deal production damage.
	var runtime_ids:=attacks.duplicate()
	for id in S.Progression.FUSIONS:
		if S.Progression.fusion_kind(id)=="attack": runtime_ids.append(id)
	for id in runtime_ids:
		fresh();grid()
		emit([id])
		# Random lightning is allowed to miss; place durable targets at its telegraphed points.
		if id in ["thunder","thunder_seal","judgement"]:
			for strike in g.magic.behavior.strikes:
				for point in strike.points: enemy(point.pos)
			g._rebuild_grid()
		for frame in 360:
			g.player.position+=Vector2(.3,0)
			step(1.0/60)
		check(count("damage_effective")>0,"Production damage: "+id)
		report.runtime[id]=g.meter.totals.duplicate()
		g.clear_magic();step(.8)
		check(g.magic.extensions.jobs.is_empty() and g.magic.extensions.timed.is_empty() and g.magic.extensions.beams.is_empty() and g.magic.extensions.clouds.is_empty() and g.magic.extensions.status.is_empty(),"Cleanup cancels all new objects: "+id)
	# Actual modifier behavior, not only descriptive data.
	fresh();grid();emit(["fall","bolt"])
	check(g.projectiles.is_empty() and g.magic.extensions.jobs.size()==1,"Fall waits above landing")
	step(.3);check(count("damage_effective")==0,"No airborne hit")
	step(.3);check(count("falls_landed")==1 and count("damage_effective")>0,"One actual landing then collision")
	fresh();emit(["orbit","bolt"]);step(.3)
	check(not g.projectiles.is_empty() and g.projectiles[0]._motion=="orbit" and g.projectiles[0].pos.distance_to(g.player.position)<160,"Orbit owns actual projectile position")
	check(g.magic.extensions.motion(S.roots(S.compile(["orbit","seek","bolt"]).stages)[0])=="seek" and g.magic.extensions.motion(S.roots(S.compile(["seek","orbit","bolt"]).stages)[0])=="orbit","Rightmost movement wins")
	fresh();grid();emit(["bounce","bolt"]);step(1)
	check(count("bounce_redirects")>0,"Bounce redirects actual projectile")
	fresh();grid();emit(["split@3","echo","bolt","impact","laser"]);step(3)
	check(count("split_children")==5,"Split exactly one generation despite echo and hit/expiry")
	check(count("triggers")<=1,"Derived split/echo do not fire user child chain")
	fresh();emit(["trail@3","bolt"]);step(2)
	check(count("trail_copies")==5,"Distance trail exactly five finite copies")
	fresh();emit(["bolt","timer","bloom"]);step(.7)
	check(count("trigger_timer")==1,"Timer fires once on active source")
	fresh();emit(["bolt","timer","bloom"]);g.projectiles[0].life=.1;step(.8)
	check(count("trigger_timer")==0,"Normal early expiry cancels timer")
	fresh();emit(["fall","bolt","expire","bloom"]);g.clear_magic();step(1)
	check(g.projectiles.is_empty() and count("triggers")==0,"Forced clear cancels queued falls without expiry")
	for element in ["element_fire","element_ice","element_poison","element_lightning"]:
		fresh();grid();emit([element+"@3","laser"]);step(1.2)
		check(not g.magic.extensions.status.is_empty() or count("freezes")>0,"Element applied by continuous attack: "+element)
	# The five independently reviewed defects have explicit regression fixtures.
	fresh();emit(["meteor_thorn"]);step(.6)
	check(g.magic.zones.size()==2 and g.magic.zones.all(func(z):return z.get("kind","")=="thorn"),"F09 produces exactly two valid installed traps, no projectile in zone list")
	fresh();emit(["orbit_vortex"])
	check(g.magic.zones.is_empty(),"F07 flying seed does not create malformed fields")
	step(1)
	check(g.magic.zones.size()==2 and g.magic.zones.all(func(z):return z.get("kind","")=="vortex"),"F07 installs exactly two valid orbiting cores")
	fresh();emit(["timed_thorn"])
	var seed: Dictionary=g.projectiles[0]
	seed.pos=Vector2(930,450);g.magic.install(seed);g.projectiles.clear()
	var trap: Dictionary=g.magic.zones[0]
	enemy(trap.pos);g._rebuild_grid()
	step(.4)
	check(g.magic.zones.size()==1 and count("damage_effective")==0,"F10 approaching target cannot detonate timed trap early")
	step(1.7)
	check(count("explosions")==3 and g.magic.zones.is_empty(),"F10 two timed waves followed by one final explosion")
	fresh();emit(["triple_frost"])
	var cone: Dictionary=g.magic.behavior.flashes.filter(func(f):return f.kind=="cone")[0]
	check(cone.directions.size()==3 and cone.branches==3,"F12 actual primary geometry has three cones")
	fresh();enemy(Vector2(1040,450));g._rebuild_grid();emit(["fall","thunder"])
	var landing: Vector2=g.magic.extensions.jobs[0].pos
	step(.52)
	check(g.magic.behavior.strikes.size()==1 and g.magic.behavior.strikes[0].center.is_equal_approx(landing),"Falling lightning retains actual chosen landing position")
	fresh();enemy(Vector2(1040,450));g._rebuild_grid();emit(["fall","satellite"])
	landing=g.magic.extensions.jobs[0].pos;step(.7)
	check(g.magic.behavior.orbits.size()==1 and g.magic.behavior.orbits[0].pos.is_equal_approx(landing),"Falling satellite retains local landing anchor")
	fresh();var victim:=enemy(Vector2(950,450));g._rebuild_grid();emit(["temperature","laser"])
	var source: Dictionary=g.magic.extensions.beams[0]
	var frozen: Dictionary=g.magic.behavior.state_for(victim)
	frozen.frozen_until=g.magic.behavior.clock+1;frozen.cold=3
	g.magic.extensions.status[victim.get_instance_id()]={"enemy":victim,"burn":1.5,"burn_damage":10.0,"poison":0.0,"poison_damage":0.0,"shock":0.0,"shock_damage":0.0,"pulse":.3,"source":source,"last_pos":victim.position,"reaction_left":0.0}
	var before: float=victim.hp
	g.magic.behavior.hit(victim,1,Vector2.RIGHT,source)
	check(is_equal_approx(before-victim.hp,16) and count("thermal_cashouts")==1,"Thermal reaction consumes only existing 1.5 seconds of burn, never a refilled 3 seconds")
	g.magic.behavior.hit(victim,1,Vector2.RIGHT,source)
	check(count("thermal_cashouts")==1 and frozen.frozen_until==0,"Next continuous hit cannot cash out the same freeze twice")
	for hz in [30,60,120]:
		fresh();emit(["bolt","timer","bloom"]);step(.8,hz)
		check(count("trigger_timer")==1,"Frame-independent timer at "+str(hz)+" Hz")
	# New inventory entries follow the existing award and upgrade transaction paths.
	fresh();g.economy.inventory={"bolt":1};g.orb_recipes=[["bolt","","","","",""]];g.orb_drafts=g.orb_recipes.duplicate(true)
	check(g.combat_rewards.grant_reward("fireball","level"),"New attack enters real acquisition path")
	check(g.economy.inventory.get("fireball",0)==1 and not g.orb_recipes[0].has("fireball"),"New spell stays in bag, never auto-equipped")
	check(g.combat_rewards.grant_reward("fireball","level") and g.economy.inventory.has("fireball@1"),"Duplicate new spell upgrades once")
	fresh();g.power=1;emit(["fall","bolt"]);g.power=3;step(.55)
	check(not g.projectiles.is_empty() and is_equal_approx(g.projectiles[0].damage,22),"Airborne reservation keeps launch power snapshot")
	g.power=1
	fresh();grid();emit(["disintegration"]);step(.2)
	check(count("damage_effective")==0 and g.magic.extensions.beams[0].width<10,"F22 visibly charges a narrow beam without premature damage")
	step(.5);check(count("damage_effective")>0,"F22 charge releases actual continuous damage")
	fresh();g.state="shop";g.shop_time=30;g.economy.inventory={"laser":1,"fireball":1}
	g.orb_recipes=[S.fixed_slots(["laser"])];g.orb_drafts=g.orb_recipes.duplicate(true)
	g.recipe=g.orb_recipes[0].duplicate();g.draft=g.recipe.duplicate();g.orb_compiled=[S.compile(g.recipe).stages]
	check(g.board_drop(g.board_data("fireball"),0,5) and g.draft[5]=="fireball" and g.draft[1]=="","New attack drags into exact sparse slot")
	g.undo_draft();check(g.draft[5]=="" and g.remaining_part("fireball")==1,"Undo returns the same real new spell to bag")
	var prep_time: float=g.wave_time
	var prep_gold: int=g.economy.gold
	check(g.start_trial(),"Actual trial opens with new beam program")
	g.orb_clocks.fill(0);g._tick_orbs(.001)
	check(not g.magic.extensions.beams.is_empty(),"Actual trial scheduler emits new beam")
	g.end_trial()
	check(g.state=="shop" and g.wave_time==prep_time and g.economy.gold==prep_gold and g.magic.extensions.beams.is_empty(),"Trial cleans beam state without spending combat time or money")
	for id in S.Progression.FUSIONS:
		var parents: Array=S.Progression.FUSIONS[id].parents
		g.economy.fusion_history.clear()
		g.economy.inventory={parents[0]+"@3":1,parents[1]+"@3":1}
		g.orb_recipes=[S.fixed_slots([parents[0]+"@3",parents[1]+"@3"])]
		g.orb_drafts=g.orb_recipes.duplicate(true);g.active_orb=0
		g.recipe=g.orb_recipes[0].duplicate();g.draft=g.recipe.duplicate()
		g.orb_compiled=[S.compile(g.recipe).stages]
		var money: int=g.economy.gold
		check(g.claim_fusion(id),"Actual equipped fusion transaction: "+id)
		check(g.economy.inventory=={id:1} and g.economy.gold==money and g.orb_recipes[0].count(id)==1,"No cloned parents or lost output: "+id)
		check(not g.claim_fusion(id),"Duplicate transaction rejected: "+id)
	var old_path:="user://magic60-obsolete-fixture.json"
	var old_file:=FileAccess.open(old_path,FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"version":1,"content":"lumi-magic-v2","sequence":1,"closed":false,"data":{}}));old_file.close()
	var old_save:=Save.new(old_path)
	check(old_save.load_data().is_empty() and not old_save.warning.is_empty() and FileAccess.file_exists(old_path),"Old run checkpoint rejected with notice and original preserved")
	DirAccess.remove_absolute(old_path)
	# Four simultaneous expanded orbs: deterministic 300-enemy stress, CPU only.
	fresh()
	for n in 300: enemy(g.player.position+Vector2.RIGHT.rotated(n*TAU/300)*(90+(n%6)*55))
	g._rebuild_grid()
	var recipes: Array=[["fall","orbit","split","fireball","impact","laser"],["element_poison","trail","flamethrower"],["growing_echo","plasma_beam"],["orbit_afterimage","element_ice","bolt"]]
	var samples: Array=[]
	for frame in 240:
		var start:=Time.get_ticks_usec()
		g.magic.begin_tick()
		g._rebuild_grid()
		if frame%60==0:
			for orb in recipes.size():
				var stage: Dictionary=S.roots(S.compile(recipes[orb]).stages)[0].duplicate(true)
				stage["_orb"]=orb
				g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1)
		g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	report.stress={"seed":7301,"enemies":300,"frames":240,"cpu_p95_ms":samples[int(samples.size()*.95)],"cpu_max_ms":samples.back(),"totals":g.meter.totals.duplicate(),"objects":{"p":g.projectiles.size(),"beams":g.magic.extensions.beams.size(),"zones":g.magic.zones.size(),"clouds":g.magic.extensions.clouds.size()}}
	check(count("emits_blocked")+count("extension_jobs_blocked")+count("beams_blocked")+count("clouds_blocked")==0,"Representative four-orb fixture avoids extension safety clipping")
	var file:=FileAccess.open("res://artifacts/magic60-test-report.json",FileAccess.WRITE)
	report["checks"]=checks;report["failures"]=failures
	file.store_string(JSON.stringify(report,"\t"));file.close()
	g.queue_free();await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
