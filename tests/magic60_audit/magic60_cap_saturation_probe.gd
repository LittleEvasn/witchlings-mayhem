extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func fresh()->void:g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450);g.projectiles.clear()
func record(name:String,details:Dictionary)->void:rows.append({"name":name,"details":details})
func fill_array(a:Array,n:int,value:Dictionary)->void:
	a.clear();for i in n:a.append(value.duplicate(true))
func emit(id:String,stage:Dictionary)->void:g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450))
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_cap_saturation_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	var cases:Array=[["beams",48,"laser"],["strikes",128,"thunder"],["orbits",128,"satellite"],["projectiles",180,"bolt"]]
	for item in cases:
		fresh();var target:Array=[]
		match item[0]:
			"beams":target=g.magic.extensions.beams
			"strikes":target=g.magic.behavior.strikes
			"orbits":target=g.magic.behavior.orbits
			"projectiles":target=g.projectiles
		var dummy:Dictionary={"stage":{"slot":999},"owner_orb":0,"meter_echo":false,"pos":g.player.position,"life":100,"_ended":false};fill_array(target,item[1],dummy)
		var stage:Dictionary=S.roots(S.compile([item[2]]).stages)[0];emit(item[2],stage)
		record("cap_"+str(item[0]),{"limit":item[1],"before":item[1],"after":target.size(),"blocked_counter":g.meter.totals.get(str(item[0])+"_blocked",0),"projectiles_emitted":g.meter.totals.get("projectiles_emitted",0),"stage_casts":g.meter.totals.get("stage_casts",0)})
	# Fill extension queues with inert nonmatching entries and attempt one actual cloud/job.
	fresh();fill_array(g.magic.extensions.clouds,96,{"kind":"gas","owner_orb":99,"pos":Vector2(5000,5000),"life":5,"age":0,"pulse":.25,"radius":10,"damage":1,"source":{}});var source:Dictionary=g.magic.behavior.context(S.roots(S.compile(["bolt"]).stages)[0],g.player.position,Vector2.RIGHT,{},1,1,"primary",false,-1,g.magic.generation);g.magic.extensions.cloud(source,g.player.position,20,1,5,"poison");record("cap_clouds",{"limit":96,"after":g.magic.extensions.clouds.size(),"blocked":g.meter.totals.get("clouds_blocked",0)})
	fresh();fill_array(g.magic.extensions.jobs,128,{"kind":"cast","delay":5,"generation":g.magic.generation});g.magic.extensions.schedule({"kind":"cast","delay":0,"stage":{},"pos":g.player.position});record("cap_jobs",{"limit":128,"after":g.magic.extensions.jobs.size(),"blocked":g.meter.totals.get("extension_jobs_blocked",0)})
	# Emit quota 64 per tick.
	fresh();g.magic.begin_tick();var bolt:Dictionary=S.roots(S.compile(["bolt"]).stages)[0]
	for i in 65:emit("bolt",bolt)
	record("cap_emits_per_tick",{"limit":64,"objects":g.projectiles.size(),"emits_blocked":g.meter.totals.get("emits_blocked",0),"stage_casts":g.meter.totals.get("stage_casts",0)})
	# Zone cap evicts the oldest finite zone, then installs the current real thorn seed.
	fresh();var thorn:Dictionary=S.roots(S.compile(["thorn"]).stages)[0];emit("thorn",thorn);var p:Dictionary=g.projectiles[0];
	var zone_stage:Dictionary=S.roots(S.compile(["vortex"]).stages)[0]
	for i in 256:g.magic.add_zone({"kind":"vortex","pos":Vector2(1000+i,900),"life":2.0,"age":0.0,"radius":10.0,"damage":1.0,"stage":zone_stage,"generation":g.magic.generation,"owner_orb":0,"slot":0,"_ended":false})
	g.magic.installing_batch=true;g.magic.install(p);g.magic.installing_batch=false
	record("cap_zones",{"limit":256,"after":g.magic.zones.size(),"zones_evicted":g.meter.totals.get("zones_evicted",0),"zones_created":g.meter.totals.get("zones_created",0),"newest_kind":g.magic.zones.back().kind})
	var f:=FileAccess.open("res://artifacts/magic60_cap_saturation_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"classification":"capacity reached by inert test fixtures; then one production emit/install attempt","cases":rows},"\t"));f.close();print("CAP_SATURATION_DONE "+JSON.stringify(rows));g.queue_free();await process_frame;quit(0)
