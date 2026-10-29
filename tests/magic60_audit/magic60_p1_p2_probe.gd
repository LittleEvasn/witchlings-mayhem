extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var out:Dictionary={"seed":7301,"cases":[]}
func _initialize()->void:call_deferred("run")
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450);g.state="combat";g.rng.seed=7301
func enemy(at:Vector2)->Node2D:
	var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=at;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);g._rebuild_grid();return e
func step(seconds:float,hz:=60)->void:
	for i in ceili(seconds*hz):g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/float(hz));g.magic.update_zones(1.0/float(hz))
func add(label:String,data:Dictionary)->void:out.cases.append({"label":label,"data":data})
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_p1_p2_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	# P1-01: compare natural expiration against actual collision event.
	for id in ["glitter_bomb","poison_mist"]:
		fresh();var st:Dictionary=S.roots(S.compile([id]).stages)[0];g.magic.emit(st,g.player.position,Vector2.RIGHT,S.follow(st),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var p:Dictionary=g.projectiles[0];p.life=.001;step(.1)
		var natural={"projects_left":g.projectiles.size(),"zones":g.magic.zones.size(),"clouds":g.magic.extensions.clouds.size(),"jobs":g.magic.extensions.jobs.size(),"fusion_count":g.meter.totals.get("fusion_"+id,0)}
		fresh();st=S.roots(S.compile([id]).stages)[0];g.magic.emit(st,g.player.position,Vector2.RIGHT,S.follow(st),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var contact:Dictionary=g.projectiles[0];var victim:Node2D=enemy(contact.pos)
		step(.04);var actual={"victim_hp_loss":100000-victim.hp,"projects":g.projectiles.size(),"zones":g.magic.zones.size(),"clouds":g.magic.extensions.clouds.size(),"jobs":g.magic.extensions.jobs.size(),"fusion_count":g.meter.totals.get("fusion_"+id,0)}
		add("P1-01 "+id,{"natural_expiry":natural,"natural_contact":actual})
	# P1-03: single-target first contact cannot be a successful bounce.
	fresh();var moons:Dictionary=S.roots(S.compile(["twin_moons"]).stages)[0];var target:Node2D=enemy(Vector2(850,450));g.magic.emit(moons,g.player.position,Vector2.RIGHT,S.follow(moons),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var initial:int=g.projectiles.size();step(.18);add("P1-03 twin_moons_single_target",{"initial_projectiles":initial,"after_contact_projectiles":g.projectiles.size(),"bounce_redirects":g.meter.totals.get("bounce_redirects",0),"fusion_twin_moons":g.meter.totals.get("fusion_twin_moons",0),"triggers":g.meter.totals.get("triggers",0),"target_hp_loss":100000-target.hp})
	# P1-04/05: measure first orbit step and probe the swept segment away from actual sampled path.
	fresh();var bolt:Dictionary=S.roots(S.compile(["orbit","bolt"]).stages)[0];g.magic.emit(bolt,g.player.position,Vector2.RIGHT,S.follow(bolt),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var shot:Dictionary=g.projectiles[0];var old:Vector2=shot.pos;var dt:float=1.0/60.0;var predicted:Vector2=shot._anchor+Vector2.RIGHT.rotated(dt*2.5+float(shot.get("_orbit_phase",0)))*g.magic.extensions.rank_value(shot.stage,"orbit");var probe:Node2D=enemy((old+predicted)*.5);var hp_before:float=probe.hp;g._update_projectiles(dt);var measured:Vector2=shot.pos if not g.projectiles.is_empty() else predicted;add("P1-04_05 orbit_bolt_first_step",{"old":[old.x,old.y],"predicted":[predicted.x,predicted.y],"actual":[measured.x,measured.y],"step_distance":old.distance_to(measured),"false_sweep_target":[probe.position.x,probe.position.y],"swept_collision_damage":hp_before-probe.hp,"projectiles_left":g.projectiles.size()})
	# P1-09: nearest-enemy override compared with the explicit aim point.
	fresh();var near:Node2D=enemy(Vector2(900,450));var aimed:Vector2=Vector2(1100,450);var fall:Dictionary=S.roots(S.compile(["fall","bolt"]).stages)[0];g.magic.emit(fall,g.player.position,Vector2.RIGHT,S.follow(fall),1.0,-1,"primary",false,-1,-1,aimed);var job:Dictionary=g.magic.extensions.jobs[0];add("P1-09 fall_target",{"explicit_target":[aimed.x,aimed.y],"nearest_enemy":[near.position.x,near.position.y],"scheduled_landing":[job.pos.x,job.pos.y],"distance_to_aim":job.pos.distance_to(aimed),"distance_to_nearest":job.pos.distance_to(near.position)})
	# P2 clock satellite: three overlapping targets near the same line; actual per-target loss.
	fresh();var center:Vector2=g.player.position;var victims:Array=[]
	for pos in [center,center+Vector2(4,0),center+Vector2(8,0)]:victims.append(enemy(pos))
	var clock_stage:Dictionary=S.roots(S.compile(["clock_satellite"]).stages)[0];g.magic.emit(clock_stage,center,Vector2.RIGHT,S.follow(clock_stage),1.0,-1,"primary",false,-1,-1,center+Vector2(200,0));var satellite:Dictionary=g.magic.behavior.orbits[0];satellite.age=.65;var before:Array=victims.map(func(e):return e.hp);g.magic.behavior.update_orbits(.001);var dir:=Vector2.RIGHT.rotated(satellite.age);var a:Vector2=satellite.pos-dir*satellite.orbit_radius;var b:Vector2=satellite.pos+dir*satellite.orbit_radius;var losses:Array=[]
	for i in victims.size():losses.append(before[i]-victims[i].hp)
	add("P2 clock_satellite_overlap",{"target_count":victims.size(),"line_a":[a.x,a.y],"line_b":[b.x,b.y],"per_target_hp_loss":losses,"clock_lines":g.meter.totals.get("clock_lines",0),"damage_effective":g.meter.totals.get("damage_effective",0)})
	var f:=FileAccess.open("res://artifacts/magic60_p1_p2_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify(out,"\t"));f.close();print("P1_P2_PROBE_DONE cases="+str(out.cases.size()));g.queue_free();await process_frame;quit(0)
