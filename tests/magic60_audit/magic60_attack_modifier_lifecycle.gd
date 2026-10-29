extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Profile=preload("res://scripts/player_profile.gd")
const CHUNK:=12
var g:Node2D
var attacks:Array=[];var modifiers:Array=[];var rows:Array=[];var no_damage_examples:Array=[];var by_attack:Dictionary={};var totals={"attempted":0,"compiled":0,"emitted":0,"effective_damage_positive":0,"normal_end_observed":0,"cleanup_failures":0,"unrunnable":0,"simulated_frames":0,"simulated_seconds_per_case":10.0,"fixed_hz":60,"no_damage_cases":0}
func _initialize()->void:call_deferred("run")
func key(id:String,rank:int)->String:return id if P.is_fused(id) else P.key(id,rank)
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450);g.rng.seed=7301
	for e in g.enemies:e.queue_free()
	g.enemies.clear()
	for n in 32:
		var radius:float=90.0+float(n%4)*35.0;var angle:float=float(n)*TAU/32.0
		var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=g.player.position+Vector2.RIGHT.rotated(angle)*radius;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e)
	g._rebuild_grid()
func cleanup_ok()->bool:
	return g.projectiles.is_empty() and g.magic.zones.is_empty() and g.magic.extensions.jobs.is_empty() and g.magic.extensions.timed.is_empty() and g.magic.extensions.beams.is_empty() and g.magic.extensions.clouds.is_empty() and g.magic.behavior.orbits.is_empty() and g.magic.behavior.strikes.is_empty()
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_lifecycle_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	for id in S.PARTS:
		if S.PARTS[id].kind=="attack":attacks.append(id)
		if S.PARTS[id].kind=="modifier":modifiers.append(id)
	for id in P.FUSIONS:
		if P.fusion_kind(id)=="attack":attacks.append(id)
		if P.fusion_kind(id)=="modifier":modifiers.append(id)
	attacks.sort();modifiers.sort()
	for attack in attacks:
		for mod in modifiers:
			for rank in [0,3]:
				totals.attempted+=1;fresh();var recipe:Array=[key(mod,rank),key(attack,rank)];var compiled:Dictionary=S.compile(recipe)
				if not compiled.ok or S.roots(compiled.stages).is_empty():totals.unrunnable+=1;if rows.size()<30:rows.append({"recipe":recipe,"compile":compiled.get("error","")});continue
				totals.compiled+=1;var stage:Dictionary=S.roots(compiled.stages)[0];g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));totals.emitted+=1
				# Real production-time advancement at a fixed 60 Hz. Ember footprints also get a walking player.
				for frame in 600:
					g.magic.begin_tick()
					if stage.attack=="ember_path":g.player.position+=Vector2(0.5,0)
					g._rebuild_grid();g._update_projectiles(1.0/60.0);g.magic.update_zones(1.0/60.0)
				totals.simulated_frames+=600
				var damage:float=float(g.meter.totals.get("damage_effective",0))
				if damage>0:totals.effective_damage_positive+=1
				else:
					totals.no_damage_cases+=1;by_attack[attack]=int(by_attack.get(attack,0))+1
					if no_damage_examples.size()<100:no_damage_examples.append({"recipe":recipe,"damage_effective":damage,"meter":g.meter.totals.duplicate()})
				if int(g.meter.totals.get("projectiles_finished",0))+int(g.meter.totals.get("falls_landed",0))+int(g.meter.totals.get("lightning_pulses",0))+int(g.meter.totals.get("path_patches",0))>0:totals.normal_end_observed+=1
				var objects={"projectiles":g.projectiles.size(),"zones":g.magic.zones.size(),"jobs":g.magic.extensions.jobs.size(),"timed":g.magic.extensions.timed.size(),"beams":g.magic.extensions.beams.size(),"clouds":g.magic.extensions.clouds.size(),"orbits":g.magic.behavior.orbits.size(),"strikes":g.magic.behavior.strikes.size()}
				if not cleanup_ok():
					totals.cleanup_failures+=1
					if rows.size()<100:rows.append({"recipe":recipe,"objects_after_10s":objects,"remaining_zones":g.magic.zones.map(func(z):return {"kind":z.get("kind",""),"fusion":z.get("stage",{}).get("fusion",""),"age":z.get("age",0),"life":z.get("life",0),"pos":[z.get("pos",Vector2.ZERO).x,z.get("pos",Vector2.ZERO).y]}),"damage_effective":damage,"meter":g.meter.totals.duplicate()})
				g.clear_magic();
				if totals.attempted%CHUNK==0:
					var progress_file:=FileAccess.open("res://artifacts/magic60_attack_modifier_lifecycle_progress.json",FileAccess.WRITE);progress_file.store_string(JSON.stringify(totals,"\t"));progress_file.close()
					print("LIVE_MOD_PROGRESS "+str(totals.attempted)+"/1440; hits="+str(totals.effective_damage_positive)+" lingering="+str(totals.cleanup_failures));await process_frame
	var f:=FileAccess.open("res://artifacts/magic60_attack_modifier_lifecycle.json",FileAccess.WRITE);f.store_string(JSON.stringify({"classification":"fixed 60 Hz, 10.0 simulated seconds per one-shot recipe; no production duration edits","catalog":{"attacks":attacks.size(),"modifiers":modifiers.size()},"totals":totals,"no_damage_by_attack":by_attack,"no_damage_examples":no_damage_examples,"lingering_examples":rows},"\t"));f.close();print("LIVE_MOD_DONE "+JSON.stringify(totals));g.queue_free();await process_frame;quit(1 if totals.unrunnable>0 else 0)
