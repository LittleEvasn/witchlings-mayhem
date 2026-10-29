extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var attacks:Array=[]
var reports:Array=[]
var mod_sets:Array=[["orbit@3","fan@3"],["echo@3","split@3"],["trail@3","seek@3"],["element_lightning@3","giant@3"],["fall@3","pierce@3"],["charge@3","echo@3"],["fan@3","element_fire@3"],["element_ice@3","trail@3"],["split@3","bounce@3"]]
func _initialize()->void:call_deferred("run")
func token(id:String)->String:return id if P.is_fused(id) else P.key(id,3)
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_four_orb_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999;g.state="combat";g.player.position=Vector2(2400,1800);g.rng.seed=24061
	for id in S.PARTS:
		if S.PARTS[id].kind=="attack":attacks.append(id)
	for id in P.FUSIONS:
		if P.fusion_kind(id)=="attack":attacks.append(id)
	attacks.sort()
	var enemies:Array=[]
	for n in 300:
		var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=g.player.position+Vector2.RIGHT.rotated(n*TAU/300)*(90+(n%6)*55);e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);enemies.append(e)
	for batch in 9:
		g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true
		for e in enemies:e.dead=false;e.hp=100000;e.position=g.player.position+Vector2.RIGHT.rotated((int(e.get_instance_id())+batch*31)%300*TAU/300)*(90+(batch%6)*55)
		g._rebuild_grid()
		var programs:Array=[]
		for orb in 4:
			var attack:String=attacks[batch*4+orb]
			var recipe:Array=mod_sets[batch].duplicate();recipe.append(token(attack))
			var compiled:Dictionary=S.compile(recipe)
			if not compiled.ok or S.roots(compiled.stages).is_empty():
				reports.append({"batch":batch,"orb":orb,"recipe":recipe,"compile_error":compiled.get("error","")});continue
			var stage:Dictionary=S.roots(compiled.stages)[0].duplicate(true);stage["_orb"]=orb;programs.append(stage)
		var frame_times:Array=[];var max_objects={"projectiles":0,"zones":0,"beams":0,"clouds":0,"jobs":0,"orbits":0,"strikes":0}
		for frame in 240:
			var t:=Time.get_ticks_usec();g.magic.begin_tick();g._rebuild_grid()
			if frame%60==0:
				for stage in programs:g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,g.player.position+Vector2(200,0))
			g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60)
			frame_times.append((Time.get_ticks_usec()-t)/1000.0)
			max_objects.projectiles=maxi(max_objects.projectiles,g.projectiles.size());max_objects.zones=maxi(max_objects.zones,g.magic.zones.size());max_objects.beams=maxi(max_objects.beams,g.magic.extensions.beams.size());max_objects.clouds=maxi(max_objects.clouds,g.magic.extensions.clouds.size());max_objects.jobs=maxi(max_objects.jobs,g.magic.extensions.jobs.size());max_objects.orbits=maxi(max_objects.orbits,g.magic.behavior.orbits.size());max_objects.strikes=maxi(max_objects.strikes,g.magic.behavior.strikes.size())
		frame_times.sort();var blocks:Dictionary={}
		for key in g.meter.totals:
			if str(key).ends_with("_blocked") or str(key)=="zones_evicted":blocks[key]=g.meter.totals[key]
		reports.append({"batch":batch,"seed":24061,"frames":240,"fps_model":"headless CPU only; no rendered FPS claim","recipes":programs.map(func(s):return [s.get("source_id",s.attack),s.get("_orb",0)]),"cpu_p95_ms":frame_times[int(frame_times.size()*.95)],"cpu_max_ms":frame_times.back(),"max_objects":max_objects,"blocked_counters":blocks,"damage_events":g.meter.totals.get("damage_effective",0),"meter":g.meter.totals.duplicate()})
		print("FOUR_ORB_PROGRESS batch="+str(batch+1)+"/9 p95="+str(reports.back().cpu_p95_ms)+" max_objects="+str(max_objects))
	var file:=FileAccess.open("res://artifacts/magic60_four_orb_stress.json",FileAccess.WRITE);file.store_string(JSON.stringify({"seed":24061,"enemy_count":300,"attacks":attacks,"batches":reports},"\t"));file.close();g.queue_free();await process_frame;quit(0)
