extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var rows:Array=[]
func _initialize()->void: call_deferred("run")
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(950,450);g.rng.seed=7301
func tick(hz:int)->void:
	g._rebuild_grid();g._update_projectiles(1.0/float(hz));g.magic.update_zones(1.0/float(hz))
func run_case(parts:Array,hz:int,move_player:bool,label:String)->void:
	fresh();var normalized:Array=[]
	for token in parts:
		var id:String=str(token)
		normalized.append(id.trim_suffix("@0"))
	var compiled:Dictionary=S.compile(normalized)
	if not compiled.ok or S.roots(compiled.stages).is_empty():rows.append({"label":label,"hz":hz,"compile_error":compiled.get("error","")});return
	var stage:Dictionary=S.roots(compiled.stages)[0]
	if stage.is_empty():rows.append({"label":label,"hz":hz,"compile":"no_root"});return
	if parts.has("impact"):
		g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(950,450))
		if not g.projectiles.is_empty():g.magic.trigger(g.projectiles[0],Vector2(900,450),"impact")
	else:g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(950,450))
	var max_delta:=0.0;var first:Dictionary={};var damage_at_center:=0.0
	for i in 60:
		if move_player:g.player.position+=Vector2(0.3,0)
		g._rebuild_grid();g._update_projectiles(1.0/float(hz));g.magic.update_zones(1.0/float(hz))
		if not g.magic.zones.is_empty():
			var z:Dictionary=g.magic.zones[0];var d:float=z.pos.distance_to(z.get("path_points",[z.pos])[0]);max_delta=maxf(max_delta,d)
			if i==0 and first.is_empty():
				var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=z.pos;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);g._rebuild_grid()
				z.age=maxf(z.age,.31);z.pulse=0.0
				var hp:float=e.hp;g.magic.update_zones(1.0/float(hz));damage_at_center=hp-e.hp
				first={"frame":i+1,"center":[z.pos.x,z.pos.y],"path":[z.path_points[0].x,z.path_points[0].y],"distance":d,"geometric_hit":g.magic.behavior.path_contains(z,e.position,e.radius),"damage":hp-e.hp}
	rows.append({"label":label,"recipe":parts,"hz":hz,"moved":move_player,"frames":60,"max_zone_path_distance":max_delta,"first_center_sample":first,"sampled_damage":damage_at_center,"zones":g.magic.zones.size(),"meter":g.meter.totals.duplicate()})
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_orbit_variant_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	for hz in [60,120]:
		for o in 4:
			for e in 4:run_case(["orbit@"+str(o),"ember_path@"+str(e)],hz,false,"root_rank")
		for recipe in [["orbit","fan","ember_path"],["orbit","thermal_trail"],["orbit","mirror_trail"],["orbit_afterimage","ember_path"],["bolt","impact","orbit","ember_path"]]:run_case(recipe,hz,true,"variant" if recipe.size()<5 else "linked_anchor")
	var f:=FileAccess.open("res://artifacts/magic60_orbit_variant_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"rows":rows},"\t"));f.close();print("ORBIT_VARIANTS_DONE cases="+str(rows.size()));g.queue_free();await process_frame;quit(0)
