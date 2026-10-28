extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const E=preload("res://scripts/economy.gd")
const Meter=preload("res://scripts/combat_meter.gd")
const Checkpoint=preload("res://scripts/run_checkpoint.gd")
var g: Node2D
var checks:=0
var failures:=0
var report: Dictionary={"seed":428,"shapes":{},"events":{},"stress":{}}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+label)
func fresh() -> void:
	g.record_runs=false
	g.meter=null
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.clear()
	g.encounters.enabled=false
	g.meter=Meter.new()
	g.rng.seed=428
	g.player.position=Vector2(800,450)
	g.cast_target=Vector2(1000,450)
	g.aim=Vector2.RIGHT
func victim(at: Vector2) -> Node2D:
	var e: Node2D=g.spawn_enemy(1)
	e.position=at
	e.hp=100000
	e.max_hp=e.hp
	g._rebuild_grid()
	return e
func cast(parts: Array) -> Dictionary:
	var parsed:=S.compile(parts)
	check(parsed.ok,"valid program "+str(parts))
	if not parsed.ok: return {}
	g.magic.begin_tick()
	g.emit_stage(parsed.stages[0],g.player.position,Vector2.RIGHT,S.follow(parsed.stages[0]),1)
	return parsed.stages[0]
func tick(seconds: float) -> void:
	for n in ceili(seconds*120):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/120)
		g.magic.update_zones(1.0/120)
		g._update_effects(1.0/120)
func total(id: String) -> float: return g.meter.totals.get(id,0.0)
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	root.add_child(g)
	current_scene=g
	g.set_physics_process(false)
	await process_frame
	check(S.PARTS.size()==18 and P.FUSIONS.size()==18,"18 originals + 18 completed fusions")
	var supports: Array=P.FUSIONS.keys().filter(func(id):return P.is_support(id))
	check(supports.size()==9,"seven support and two event fusions")
	for id in supports:
		var d: Dictionary=P.FUSIONS[id]
		var a: String=P.key(d.parents[0],3)
		var b: String=P.key(d.parents[1],3)
		check(S.definition(id).kind==P.fusion_kind(id) and not S.upgradeable(id),"typed fixed fusion "+id)
		check(P.fusion_for(a,b)==id and P.fusion_for(b,a)==id and P.fusion_for(d.parents[0],b)=="","symmetric +3 recipe "+id)
		var eco:=E.new()
		eco.inventory={a:1,b:1};eco.gold=12
		var q:=eco.craft("fuse",a,b,eco.revision)
		check(q.ok and eco.gold==0 and eco.inventory=={id:1},"consume two +3 and 12 once "+id)
		check(not eco.craft("fuse",a,b,eco.revision-1).ok and eco.inventory=={id:1},"stale craft cannot duplicate "+id)
		eco.inventory={a:1,b:1};eco.gold=11
		check(not eco.craft("fuse",a,b,eco.revision).ok and eco.gold==11 and eco.inventory=={a:1,b:1},"unaffordable no consumption "+id)
	for support in ["wave_split","compressed_star","dual_event"]:
		for attack in S.PARTS:
			if S.definition(attack).kind!="attack": continue
			fresh()
			victim(Vector2(900,450));victim(Vector2(940,480));victim(Vector2(1080,450))
			var parts: Array=[support,attack] if support!="dual_event" else [attack,support,"bolt"]
			var stage:=cast(parts)
			if support=="compressed_star":
				check(is_equal_approx(S.scale(stage),2.16) and is_equal_approx(S.interval([stage]),S.ATTACK_INTERVALS[attack]*3),"compression size and wait "+attack)
			if attack=="ember_path": g.player.position+=Vector2(80,0)
			tick(4.0)
			check(total("emits_blocked")==0 and total("echoes_blocked")==0 and total("support_jobs_blocked")==0,"representative production not capped "+support+attack)
			report.shapes[support+"/"+attack]={"casts":total("stage_casts"),"triggers":total("triggers")}
	for id in supports:
		if P.fusion_kind(id)!="modifier": continue
		for attack in S.PARTS:
			if S.definition(attack).kind!="attack": continue
			var parsed:=S.compile([id,attack])
			check(parsed.ok and S.compatible(id,attack),"support all original shapes "+id+attack)
		for attack in P.FUSIONS:
			if P.fusion_kind(attack)!="attack": continue
			check(S.compile([id,attack]).ok,"support completed attack "+id+attack)
	# Run the seven supports on every basic and completed attack through production.
	for support in supports:
		if P.fusion_kind(support)!="modifier": continue
		var attacks: Array=S.PARTS.keys().filter(func(id):return S.definition(id).kind=="attack")
		attacks.append_array(P.FUSIONS.keys().filter(func(id):return P.fusion_kind(id)=="attack"))
		for attack in attacks:
			fresh()
			victim(Vector2(1000,450));victim(Vector2(1130,510));victim(Vector2(960,530))
			cast([support,attack])
			if attack=="ember_path" or attack=="firework_trail": g.player.position+=Vector2(120,0)
			tick(.8)
			check(total("emits_blocked")==0 and total("support_jobs_blocked")==0 and total("projectiles_blocked")==0,"all-shape runtime without blocking "+support+"/"+attack)
	fresh()
	var stage:=cast(["wave_split","bolt"])
	check(g.projectiles.size()==3 and g.magic.echoes.size()==2,"wave split three time-separated patterns")
	var first: float=g.projectiles[0].damage
	tick(.5)
	check(total("projectiles_emitted")==9 and total("support_repeats_scheduled")==2,"wave split does not recursively replay")
	check(is_equal_approx(first,22.0/3.0/2.5),"wave pattern partitions power once")
	fresh()
	var boss: Node2D=g.spawn_enemy(1,true)
	boss.position=Vector2(930,450);boss.hp=1;boss.max_hp=1;g._rebuild_grid()
	stage=cast(["leap_pierce","bolt"])
	g.projectiles[0].life=.001
	tick(.03)
	check(g.state=="ended" and g.result_win and g.projectiles.is_empty(),"terminal boss kill finishes run without accessing cleared projectile array")
	fresh()
	stage=cast(["growing_echo","bolt"])
	tick(.51)
	var sizes: Array=g.projectiles.map(func(p):return snapped(p.radius,.01))
	check(sizes==[5.0,6.5,8.5],"growing echoes visible sizes")
	check(total("projectiles_emitted")==3,"growing echoes two copies, no recursion")
	fresh()
	var e1:=victim(Vector2(950,400));var e2:=victim(Vector2(950,500));victim(Vector2(1050,450))
	stage=cast(["swarm_seek","bolt"])
	check(g.projectiles[0].dir!=g.projectiles[1].dir,"swarm branches divide targets")
	fresh()
	victim(Vector2(900,450));victim(Vector2(1040,490))
	stage=cast(["chase_pierce","bolt"])
	tick(.5)
	check(total("chase_retargets")>0,"piercing hit retargets next enemy")
	fresh()
	victim(Vector2(1000,450));e2=victim(Vector2(1130,510))
	stage=cast(["chase_pierce","boomerang"])
	tick(1.0)
	check(e2.hp<100000 and total("chase_retargets")>0,"base boomerang chases extra contacts before return")
	fresh()
	e1=victim(Vector2(900,450));e2=victim(Vector2(1000,450))
	stage=cast(["echo_chain","bolt"])
	tick(.25)
	check(total("chain_traces_scheduled")>0,"chain records actual old hits")
	var scheduled:=total("chain_traces_scheduled")
	e2.position+=Vector2(0,150);g._rebuild_grid()
	var hp: float=e2.hp
	tick(.5)
	check(e2.hp==hp and total("chain_traces_fired")==scheduled,"trace stays at old position and does not retarget/rechain")
	fresh()
	victim(Vector2(900,450))
	stage=cast(["bolt","dual_event","bolt"])
	var source: Dictionary=g.projectiles[0]
	g.magic.trigger(source,Vector2(900,450))
	g.magic.trigger(source,Vector2(900,450))
	g.magic.trigger(source,Vector2(900,450),"expire")
	g.magic.trigger(source,Vector2(900,450),"expire")
	check(total("triggers")==2 and g.projectiles.size()==3,"dual first hit and normal expire once each")
	check(g.projectiles[1].damage==11 and g.projectiles[2].damage==11,"dual direct 50% each")
	check(S.roots(S.compile(["bolt","dual_event","bolt","impact","bloom"]).stages).size()==1,"linked children are never sequence roots")
	fresh()
	stage=cast(["bolt","dual_event","bolt","impact@3","bolt"])
	g.magic.trigger(g.projectiles[0],Vector2(900,450))
	g.magic.trigger(g.projectiles[1],Vector2(1000,450))
	check(g.projectiles[1].damage==11 and g.projectiles[2].damage==11,"dual branch half-budget survives deeper connectors, no reset or double half")
	fresh()
	stage=cast(["bolt","delayed_ignition","bloom"])
	source=g.projectiles[0]
	g.magic.trigger(source,Vector2(1000,400))
	g.magic.trigger(source,Vector2(1000,400))
	check(g.magic.support.jobs.size()==1 and g.projectiles.size()==1,"delayed hit schedules once, not immediate")
	tick(.59)
	check(total("delayed_children_fired")==0,"delayed child waits .6 seconds")
	tick(.02)
	check(total("delayed_children_fired")==1 and g.projectiles.back().attack=="bloom" and g.projectiles.back().pos.distance_to(Vector2(1000,400))<15,"delayed child uses stored event position")
	check(g.projectiles.back().damage==20,"delayed direct child is 100%")
	fresh()
	stage=cast(["bolt","delayed_ignition","bloom"])
	g.magic.trigger(g.projectiles[0],Vector2(1000,450))
	g.clear_magic();tick(1)
	check(g.magic.support.jobs.is_empty() and g.projectiles.is_empty(),"forced cleanup cancels pending event with no expire")
	fresh()
	stage=cast(["bolt","delayed_ignition","bloom"])
	source=g.projectiles[0]
	g.magic.generation+=1
	g.magic.trigger(source,Vector2(1000,450))
	check(g.magic.support.jobs.is_empty(),"old program cannot enqueue new delayed child after edit generation changes")
	# Compiled scope, repeated supports, and descendant budgets are never inherited twice.
	var parsed:=S.compile(["swarm_seek","bolt","dual_event","growing_echo","bloom"])
	check(parsed.ok and parsed.stages[0].swarm_seek==1 and parsed.stages[1].swarm_seek==1 and parsed.stages[0].get("growing_echo",0)==0 and parsed.stages[1].growing_echo==1,"right-side scope crosses connector exactly once")
	check(S.branches(parsed.stages[1])==3 and S.Effects.profile(parsed.stages[1],"seek").count==1,"compiled fusion contributions not doubled")
	parsed=S.compile(["swarm_seek","swarm_seek","bolt"])
	check(S.branches(parsed.stages[0])==5,"duplicate supports add branches, not multiply")
	# Real equipped crafting and both-orb stock reconciliation, then trial and checkpoint.
	fresh();g.state="shop";g.shop_time=60;g.economy.gold=100
	g.economy.inventory={"fan@3":2,"echo@3":1,"bolt":2,"impact":1}
	g.orb_recipes=[["fan@3","echo@3","bolt"],["fan@3","bolt"]]
	g.orb_drafts=g.orb_recipes.duplicate(true);g.active_orb=0
	g.recipe=g.orb_recipes[0].duplicate();g.draft=g.recipe.duplicate();g.compiled=S.compile(g.recipe).stages;g._sync_orb()
	check(g.craft_spell("fuse","fan@3","echo@3",g.economy.revision),"equipped support crafting works")
	check(g.orb_recipes[0]==["wave_split","bolt"] and g.orb_recipes[1]==["fan@3","bolt"] and g.economy.inventory=={"wave_split":1,"fan@3":1,"bolt":2,"impact":1},"one real copy consumed, other orb retained")
	g.undo_draft()
	check(g.edit_history.is_empty() and not g.economy.inventory.has("echo@3"),"craft consumption cannot be undone into duplicate materials")
	check(g.start_trial(),"completed support enters production trial")
	g.end_trial()
	check(g.state=="shop" and g.economy.gold==88 and g.economy.inventory.get("wave_split")==1,"trial preserves crafted stock and payment")
	# Produce a valid actual preparation snapshot and prove new IDs survive JSON.
	g.wave=1;g.wave_time=60;g.wave_records=[{"wave":1,"seconds":60.0,"kills":0,"earned":0,"recipes":g.orb_recipes.duplicate(true)}]
	g.economy.roll(g.rng,g.recipe)
	var snapshot:=Checkpoint.capture(g)
	check(Checkpoint.valid(snapshot),"checkpoint accepts new support token")
	var store:=Checkpoint.new("user://support-fusions-test.json")
	check(store.write(snapshot) and store.load_data().economy.inventory.get("wave_split")==1,"new support round-trips checkpoint")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(store.path+suffix)
	g.profile.discover(supports,[])
	check(supports.all(func(id):return id in g.profile.data.discovered_fusions),"all completed supports register in persistent collection")
	g.ui.show_collection("shop")
	g.ui.collection_kind="fusion";g.ui.collection_selected="dual_event";g.ui.CollectionUI.build(g.ui)
	check(g.ui.modal.find_child("Entry_dual_event",true,false)!=null,"collection includes event fusion")
	g.ui.close_collection()
	fresh()
	for i in 24: victim(Vector2(1020+(i%6)*45,300+int(i/6)*60))
	var programs: Array=[["wave_split","swarm_seek","bolt@3","dual_event","thunder"],["echo_chain","growing_echo","bloom","delayed_ignition","frost"]]
	var begin:=Time.get_ticks_usec()
	var peak:=0
	var peak_strikes:=0
	var frame_us: Array=[]
	for frame in 600:
		if frame%120==0:
			for orb in 2:
				var program: Dictionary=S.compile(programs[orb])
				var root_stage: Dictionary=program.stages[0].duplicate(true)
				root_stage["_orb"]=orb
				g.magic.begin_tick();g.emit_stage(root_stage,g.player.position,Vector2.RIGHT,S.follow(root_stage),1)
		var frame_begin:=Time.get_ticks_usec()
		tick(1.0/120)
		frame_us.append(Time.get_ticks_usec()-frame_begin)
		peak=maxi(peak,g.projectiles.size())
		peak_strikes=maxi(peak_strikes,g.magic.behavior.strikes.size())
	var blocked:=0.0
	for key in g.meter.totals:
		if str(key).ends_with("_blocked"): blocked+=g.meter.totals[key]
	frame_us.sort()
	report.stress={"simulated_seconds":5,"cpu_total_ms":(Time.get_ticks_usec()-begin)/1000.0,"peak_projectiles":peak,"pending_jobs":g.magic.support.jobs.size(),"peak_strikes":peak_strikes,"p95_cpu_ms":frame_us[569]/1000.0,"max_cpu_ms":frame_us.back()/1000.0,"blocked":blocked}
	check(report.stress.blocked==0,"representative two-orb programs do not rely on safety caps")
	g.clear_magic()
	check(g.magic.support.jobs.is_empty() and g.magic.echoes.is_empty(),"wave/trial teardown clears support and ordinary repeats")
	report.events=g.meter.totals.duplicate()
	var file:=FileAccess.open("res://artifacts/support-fusions-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	g.clear_magic();g.queue_free()
	for n in 4: await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(1 if failures else 0)
