extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var recipes:Array=[["echo@3","split@3","clock_satellite"],["echo@3","split@3","cold_flame"],["echo@3","split@3","collapse_vortex"],["echo@3","split@3","disintegration"]]
var runs:Array=[]
func _initialize()->void:call_deferred("run")
func simulate(run_id:int)->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.rng.seed=24061
	for frame in 240:
		var t:=Time.get_ticks_usec();g.magic.begin_tick();g._rebuild_grid()
		if frame%60==0:
			for orb in 4:
				var stage:Dictionary=S.roots(S.compile(recipes[orb]).stages)[0].duplicate(true);stage["_orb"]=orb;g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,g.player.position+Vector2(200,0))
		g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60);samples.append((Time.get_ticks_usec()-t)/1000.0)
	var sorted:=samples.duplicate();sorted.sort();var sum:=0.0;var slow16:=0;var slow33:=0
	for ms in samples:sum+=ms;if ms>16.667:slow16+=1;if ms>33.333:slow33+=1
	var blocks:Dictionary={};for key in g.meter.totals:
		if str(key).ends_with("_blocked") or str(key)=="zones_evicted":blocks[key]=g.meter.totals[key]
	runs.append({"run":run_id,"frames":samples.size(),"warm_state":"same Godot process; no rendered FPS","mean_ms":sum/float(samples.size()),"p50_ms":sorted[int(sorted.size()*.5)],"p95_ms":sorted[int(sorted.size()*.95)],"p99_ms":sorted[int(sorted.size()*.99)],"max_ms":sorted.back(),"frames_over_16_667_ms":slow16,"frames_over_33_333_ms":slow33,"max_objects":{"projectiles":g.projectiles.size(),"zones":g.magic.zones.size(),"beams":g.magic.extensions.beams.size(),"clouds":g.magic.extensions.clouds.size(),"jobs":g.magic.extensions.jobs.size(),"orbits":g.magic.behavior.orbits.size()},"blocked_counters":blocks,"meter":g.meter.totals.duplicate()})
func _dummy()->void:pass
var samples:Array=[]
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_stress_repeat_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999;g.state="combat";g.player.position=Vector2(2400,1800);g.rng.seed=24061
	for n in 300:
		var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=g.player.position+Vector2.RIGHT.rotated(n*TAU/300)*(90+(n%6)*55);e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e)
	for n in 2:
		samples=[];simulate(n+1);print("BATCH2_REPEAT "+str(runs.back().run)+" "+JSON.stringify(runs.back()))
	var f:=FileAccess.open("res://artifacts/magic60_stress_batch2_repeat.json",FileAccess.WRITE);f.store_string(JSON.stringify({"seed":24061,"enemy_count":300,"recipes":recipes,"runs":runs},"\t"));f.close();g.queue_free();await process_frame;quit(0)
