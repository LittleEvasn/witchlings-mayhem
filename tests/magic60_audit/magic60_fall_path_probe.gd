extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func token(id:String,rank:int)->String:return id if P.is_fused(id) else P.key(id,rank)
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450);g.rng.seed=7301
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g._rebuild_grid()
func run_case(attack:String,rank:int)->void:
	fresh();var recipe:Array=[token("fall",rank),token(attack,rank)];var compiled:Dictionary=S.compile(recipe);var stage:Dictionary=S.roots(compiled.stages)[0];g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450));var sample:Dictionary={"recipe":recipe,"compile":compiled.ok,"target_point":[1100,450],"landing":null,"visible_center":null,"path_anchor":null,"geometric_hit":null,"hp_loss":null,"landed_events":0,"zones_created":0}
	for frame in 600:
		g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60)
		if not sample.has("target") and not g.magic.zones.is_empty():
			var zone:Dictionary=g.magic.zones[0];var victim:Node2D=g.Actor.new();g.actors.add_child(victim);victim.setup(g.art,1);victim.position=zone.pos;victim.hp=100000;victim.max_hp=victim.hp;victim.speed=0;g.enemies.append(victim);g._rebuild_grid();zone.age=.31;zone.pulse=0
			var hp:float=victim.hp;g.magic.update_zones(1.0/60);sample["target"]=true;sample.visible_center=[zone.pos.x,zone.pos.y];sample.path_anchor=[zone.path_points[0].x,zone.path_points[0].y];sample.geometric_hit=g.magic.behavior.path_contains(zone,victim.position,victim.radius);sample.hp_loss=hp-victim.hp;sample.landing=[zone.pos.x,zone.pos.y]
	if not sample.has("target"):sample["target"]="no_zone_after_10s"
	sample.landed_events=g.meter.totals.get("falls_landed",0);sample.zones_created=g.meter.totals.get("path_patches",0);sample.damage_effective=g.meter.totals.get("damage_effective",0);rows.append(sample)
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_fall_path_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	for attack in ["ember_path","thermal_trail"]:
		for rank in [0,3]:run_case(attack,rank)
	var f:=FileAccess.open("res://artifacts/magic60_fall_path_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"cases":rows},"\t"));f.close();print("FALL_PATH_DONE "+JSON.stringify(rows));g.queue_free();await process_frame;quit(0)
