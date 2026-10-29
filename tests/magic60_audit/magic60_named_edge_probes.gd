extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var cases:Array=[]
func _initialize()->void:call_deferred("run")
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450);g.rng.seed=7301
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g._rebuild_grid()
func enemy(at:Vector2)->Node2D:
	var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=at;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);g._rebuild_grid();return e
func step_frames(n:int,hz:=60)->void:
	for i in n:g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/float(hz));g.magic.update_zones(1.0/float(hz))
func add(name:String,data:Dictionary)->void:cases.append({"name":name,"data":data})
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_named_edges_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	# Orbit + boomerang: both the Bezier leg and orbit controller advance in one projectile update.
	fresh();var moon_stage:Dictionary=S.roots(S.compile(["orbit","boomerang"]).stages)[0];g.magic.emit(moon_stage,g.player.position,Vector2.RIGHT,S.follow(moon_stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var moon:Dictionary=g.projectiles[0];var old:Vector2=moon.pos;var dt:float=1.0/60;var anchor:Vector2=moon._anchor;var rad:float=g.magic.extensions.rank_value(moon.stage,"orbit");g._update_projectiles(dt);var orbit_expected:Vector2=anchor+Vector2.RIGHT.rotated(float(moon._motion_age)*2.5+float(moon.get("_orbit_phase",0)))*rad;var bezier_expected:Vector2=moon.leg_start*(1.0-pow(minf(1.0,moon.leg_age/moon.leg_duration),2))+moon.leg_control*2.0*(1.0-minf(1.0,moon.leg_age/moon.leg_duration))*minf(1.0,moon.leg_age/moon.leg_duration)+moon.leg_end*pow(minf(1.0,moon.leg_age/moon.leg_duration),2);add("P1-04_orbit_boomerang",{"old":[old.x,old.y],"actual":[moon.pos.x,moon.pos.y],"orbit_expected":[orbit_expected.x,orbit_expected.y],"distance_orbit_expected":moon.pos.distance_to(orbit_expected),"bezier_counterfactual":[bezier_expected.x,bezier_expected.y],"distance_bezier_counterfactual":moon.pos.distance_to(bezier_expected),"leg_age":moon.leg_age,"motion":moon._motion})
	# P1-06: installed seeds retain concrete kind and speed field; then exercise split on end.
	for attack in ["vortex","thorn"]:
		fresh();var recipe:Array=["trail","split","orbit",attack];var st:Dictionary=S.roots(S.compile(recipe).stages)[0];g.magic.emit(st,g.player.position,Vector2.RIGHT,S.follow(st),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var seed:Dictionary=g.projectiles[0];seed.life=.001;g._update_projectiles(.02);var z:Dictionary=g.magic.zones[0];var installed={"kind":z.get("kind",""),"attack":z.get("attack",""),"has_speed":z.has("speed"),"speed":z.get("speed",null),"orbit_motion":z.get("_motion",""),"zone_count":g.magic.zones.size()};z.life=.001;g.magic.update_zones(.02);g.magic.update_echoes(.1);add("P1-06_installed_"+attack,{"installed_zone":installed,"split_children":g.meter.totals.get("split_children",0),"jobs_after_end":g.magic.extensions.jobs.size(),"derived_projectiles":g.projectiles.map(func(p):return p.get("attack","")),"zone_kinds_after_split":g.magic.zones.map(func(q):return q.get("kind",""))})
	# P1-07 orbit frost's actual instant geometry/position.
	fresh();var cold_target:Node2D=enemy(Vector2(905,450));var frost:Dictionary=S.roots(S.compile(["orbit","frost"]).stages)[0];g.magic.emit(frost,g.player.position,Vector2.RIGHT,S.follow(frost),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var flash_pos:Vector2=g.magic.behavior.flashes.back().get("pos",Vector2.ZERO);add("P1-07_orbit_frost",{"origin":[g.player.position.x,g.player.position.y],"instant_flash_pos":[flash_pos.x,flash_pos.y],"target":[cold_target.position.x,cold_target.position.y],"target_hp_loss":100000-cold_target.hp,"emitted_projectiles":g.projectiles.size(),"active_orbits":g.magic.behavior.orbits.size()})
	# P2-03 frost+trail at zero movement.
	fresh();var frosttrail:Dictionary=S.roots(S.compile(["trail","frost"]).stages)[0];g.magic.emit(frosttrail,g.player.position,Vector2.RIGHT,S.follow(frosttrail),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));add("P2-03_stationary_frost_trail",{"trail_copies":g.meter.totals.get("trail_copies",0),"jobs":g.magic.extensions.jobs.size(),"player_displacement":g.player.position.distance_to(Vector2(800,450))})
	# P2-04 giant laser geometry.
	fresh();var giant_laser:Dictionary=S.roots(S.compile(["giant@3","laser"]).stages)[0];g.magic.emit(giant_laser,g.player.position,Vector2.RIGHT,S.follow(giant_laser),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var beam:Dictionary=g.magic.extensions.beams[0];add("P2-04_giant_laser",{"length":beam.length,"width":beam.width,"base_attack_radius":S.attack_data(giant_laser).radius,"scale":beam.scale})
	# P2-08 burn ticks under equal 1.2s sim duration and a 0.25s spike sequence.
	for label in ["30hz","60hz","120hz","spike_025s","spike_05s"]:
		fresh();var e:Node2D=enemy(Vector2(800,450));var source:Dictionary=g.magic.behavior.context(S.roots(S.compile(["bolt"]).stages)[0],g.player.position,Vector2.RIGHT,{},1,1,"primary",false,-1,g.magic.generation);g.magic.extensions.status[e.get_instance_id()]={"enemy":e,"burn":5.0,"burn_damage":10.0,"poison":0.0,"poison_damage":0.0,"shock":0.0,"shock_damage":0.0,"pulse":.3,"source":source,"last_pos":e.position,"reaction_left":0.0}
		var steps:Array=[]
		if label=="30hz":
			for i in 45:steps.append(1.0/30.0)
			steps.append(.01)
		elif label=="60hz":
			for i in 90:steps.append(1.0/60.0)
			steps.append(.01)
		elif label=="120hz":
			for i in 180:steps.append(1.0/120.0)
			steps.append(.01)
		elif label=="spike_025s":steps=[.25,.25,.25,.25,.25,.25,.01]
		else:steps=[.5,.5,.5,.01]
		for delta in steps:g.magic.extensions.update_status(delta)
		add("P2-08_status_"+label,{"steps":steps.size(),"simulated_seconds":steps.reduce(func(a,v):return a+v,0.0),"burn_effective_hp_loss":100000-e.hp,"damage_events":g.meter.totals.get("damage_events",0),"remaining_pulse":g.magic.extensions.status[e.get_instance_id()].get("pulse",null) if g.magic.extensions.status.has(e.get_instance_id()) else null})
	var f:=FileAccess.open("res://artifacts/magic60_named_edge_probes.json",FileAccess.WRITE);f.store_string(JSON.stringify({"cases":cases},"\t"));f.close();print("NAMED_EDGE_PROBES_DONE cases="+str(cases.size()));g.queue_free();await process_frame;quit(0)
