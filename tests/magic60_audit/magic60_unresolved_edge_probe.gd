extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var result:Array=[]
func _initialize()->void:call_deferred("run")
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450);g.rng.seed=7301
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g._rebuild_grid()
func enemy(at:Vector2)->Node2D:
	var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=at;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);g._rebuild_grid();return e
func tick(seconds:float,hz:=60)->void:
	for n in ceili(seconds*hz):g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/float(hz));g.magic.update_zones(1.0/float(hz))
func add(name:String,data:Dictionary)->void:result.append({"name":name,"data":data})
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_unresolved_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	# P2-02 growth versus actual primary and delayed secondary radii (impact event injected at a real emitted fireball).
	fresh();var firecore:Dictionary=S.roots(S.compile(["growing_firecore"]).stages)[0];g.magic.emit(firecore,g.player.position,Vector2.RIGHT,S.follow(firecore),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var core:Dictionary=g.projectiles[0];var distant:Node2D=enemy(core.pos+Vector2(140,0));g.magic.extensions.move(core,1.0,core.pos);var radius_after_growth:float=core.radius;var hp0:float=distant.hp;g.magic.extensions.impact(core,core.pos);var immediate_loss:float=hp0-distant.hp;g.magic.extensions.update(.23);add("P2-02_growing_firecore",{"age":core._motion_age,"projectile_hitbox_radius_after_growth":radius_after_growth,"base_primary_area_radius":S.attack_data(firecore).radius*core.scale,"secondary_job_area_radius":140*core.scale,"target_distance":140,"immediate_hp_loss":immediate_loss,"delayed_hp_loss":hp0-distant.hp,"jobs_remaining":g.magic.extensions.jobs.size()})
	# P2-05 compare actual lightning status after one full direct bolt and one split bolt.
	for with_split in [false,true]:
		fresh();var recipe:Array=["element_lightning@3","bolt"] if not with_split else ["split@3","element_lightning@3","bolt"];var st:Dictionary=S.roots(S.compile(recipe).stages)[0];g.magic.emit(st,g.player.position,Vector2.RIGHT,S.follow(st),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var victim:Node2D
		if with_split:
			var source:Dictionary=g.projectiles[0];g.magic.extensions.split(source,g.player.position);g.projectiles.clear();g.magic.extensions.update(.01);victim=enemy(Vector2(900,450))
		else:victim=enemy(Vector2(850,450))
		tick(1.0);var state:Dictionary=g.magic.extensions.status.get(victim.get_instance_id(),{});var src:Dictionary=state.get("source",{});add("P2-05_lightning_split_"+str(with_split),{"recipe":recipe,"parent_hit_suppressed_for_split_case":with_split,"victim_hp_loss":100000-victim.hp,"shock_damage":state.get("shock_damage",null),"shock_remaining":state.get("shock",null),"source_factor":src.get("factor",null),"source_proc_mass":src.get("stage",{}).get("_proc_mass",null),"source_derived":src.get("stage",{}).get("_derived",false),"split_children":g.meter.totals.get("split_children",0),"status_entries":g.magic.extensions.status.size()})
	# P2-06 poison cloud damage versus poison status application.
	fresh();var poison_victim:Node2D=enemy(Vector2(900,450));var mist:Dictionary=S.roots(S.compile(["poison_mist"]).stages)[0];g.magic.emit(mist,g.player.position,Vector2.RIGHT,S.follow(mist),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var cloud_source:Dictionary=g.projectiles[0];g.magic.extensions.impact(cloud_source,poison_victim.position);var poison_before:float=poison_victim.hp;g.magic.extensions.update_clouds(.31);var ps:Dictionary=g.magic.extensions.status.get(poison_victim.get_instance_id(),{});add("P2-06_poison_mist",{"cloud_count":g.magic.extensions.clouds.size(),"kind":g.magic.extensions.clouds[0].kind if not g.magic.extensions.clouds.is_empty() else "none","victim_hp_loss":poison_before-poison_victim.hp,"poison_status_remaining":ps.get("poison",null),"poison_status_entries":g.magic.extensions.status.size()})
	# P2-07 natural short lifetimes before/after the 0.6s timer.
	for attack in ["thunder","frost"]:
		fresh();var recipe:Array=[attack,"timer","bolt"];var st:Dictionary=S.roots(S.compile(recipe).stages)[0];g.magic.emit(st,g.player.position,Vector2.RIGHT,S.follow(st),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var initial_timers:int=g.magic.extensions.timed.size();tick(.8);add("P2-07_"+attack+"_timer",{"initial_timers":initial_timers,"timer_fires":g.meter.totals.get("trigger_timer",0),"triggers":g.meter.totals.get("triggers",0),"projectiles_emitted":g.meter.totals.get("projectiles_emitted",0),"strikes_left":g.magic.behavior.strikes.size(),"timed_left":g.magic.extensions.timed.size()})
	# P2-10 track real afterimage child crossing of the original orbit anchor.
	fresh();var anchor:Vector2=g.player.position;var rejoin_target:Node2D=enemy(anchor);var after:Dictionary=S.roots(S.compile(["orbit_afterimage","bolt"]).stages)[0];g.magic.emit(after,anchor,Vector2.RIGHT,S.follow(after),1.0,-1,"primary",false,-1,-1,anchor+Vector2(200,0));var tracked:Array=[];var min_distance:float=INF;var damage_before:float=rejoin_target.hp
	for frame in 240:
		g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60)
		for p in g.projectiles:
			if p.stage.has("_rejoin_anchor") and not tracked.has(p):tracked.append(p)
			if p.stage.has("_rejoin_anchor"):min_distance=minf(min_distance,p.pos.distance_to(p.stage._rejoin_anchor))
	add("P2-10_orbit_afterimage_rejoin",{"children_seen":tracked.size(),"min_distance_to_anchor":min_distance,"target_hp_loss":damage_before-rejoin_target.hp,"trail_copies":g.meter.totals.get("trail_copies",0),"projectiles_left":g.projectiles.size(),"anchor":[anchor.x,anchor.y]})
	# P1-02 production damage factors for event budget versus next direct connector.
	fresh();var program:Dictionary=S.compile(["bolt","dual_event","bolt","impact","bolt"]);var root_stage:Dictionary=S.roots(program.stages)[0];g.magic.emit(root_stage,g.player.position,Vector2.RIGHT,S.follow(root_stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var root_shot:Dictionary=g.projectiles[0];g.magic.trigger(root_shot,g.player.position,"impact");var child:Dictionary=g.projectiles.back();var child_factor:float=g.magic.behavior.damage_scale(child);g.magic.trigger(root_shot,g.player.position,"expire");var direct_child_count:int=g.projectiles.size();g.magic.trigger(child,g.player.position,"impact");var grandchild:Dictionary=g.projectiles.back();var grandchild_factor:float=g.magic.behavior.damage_scale(grandchild);add("P1-02_dual_branch_and_next_link",{"program_compiles":program.ok,"source_events":root_shot.get("events",{}),"after_impact_and_expire_projectile_count":direct_child_count,"child_factor":child_factor,"grandchild_factor":grandchild_factor,"child_connector_power":child.stage.get("connector_power",null),"grandchild_potency":grandchild.get("potency",null),"expected_branch_budget_persists":true})
	var f:=FileAccess.open("res://artifacts/magic60_unresolved_edge_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"cases":result},"\t"));f.close();print("UNRESOLVED_EDGE_DONE cases="+str(result.size()));g.queue_free();await process_frame;quit(0)
