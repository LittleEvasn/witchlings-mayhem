extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var modifiers:Array=[];var rows:Array=[]
func _initialize()->void:call_deferred("run")
func tok(id:String,rank:int)->String:return id if P.is_fused(id) else P.key(id,rank)
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.rng.seed=7301
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g._rebuild_grid()
func enemy(at:Vector2)->Node2D:
	var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=at;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);g._rebuild_grid();return e
func run_case(mod:String,attack:String,rank:int)->void:
	fresh();var recipe:Array=[tok(mod,rank),tok(attack,rank)];var c:Dictionary=S.compile(recipe);var stage:Dictionary=S.roots(c.stages)[0];g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450))
	if g.magic.zones.is_empty():rows.append({"recipe":recipe,"compile":c.ok,"no_zone":true});return
	# Advance once so orbit position changes, then put a real radius-18 target at the visible/candidate-search center.
	g._rebuild_grid();g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60);var zone:Dictionary=g.magic.zones[0];var center:Vector2=zone.pos;var path:Vector2=zone.path_points[0];var victim:Node2D=enemy(center);zone.age=.31;zone.pulse=0;var hp:float=victim.hp;g._rebuild_grid();g.magic.update_zones(1.0/60)
	rows.append({"recipe":recipe,"hz":60,"player_moved":false,"zone_count":g.magic.zones.size(),"visible_candidate_center":[center.x,center.y],"collision_path_anchor":[path.x,path.y],"center_path_distance":center.distance_to(path),"victim_radius":victim.radius,"path_contains":g.magic.behavior.path_contains(zone,victim.position,victim.radius),"actual_hp_loss":hp-victim.hp,"effective_damage_total":g.meter.totals.get("damage_effective",0),"meter":g.meter.totals.duplicate()})
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_path_matrix_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	for id in S.PARTS:
		if S.PARTS[id].kind=="modifier":modifiers.append(id)
	for id in P.FUSIONS:
		if P.fusion_kind(id)=="modifier":modifiers.append(id)
	modifiers.sort()
	for attack in ["ember_path","thermal_trail"]:
		for mod in modifiers:
			for rank in [0,3]:run_case(mod,attack,rank)
	var hits:=0;var p0_mismatches:=0
	for row in rows:
		if float(row.get("actual_hp_loss",0))>0:hits+=1
		if float(row.get("center_path_distance",0))>36 and not row.get("path_contains",true):p0_mismatches+=1
	var f:=FileAccess.open("res://artifacts/magic60_path_target_matrix.json",FileAccess.WRITE);f.store_string(JSON.stringify({"cases":rows.size(),"positive_actual_damage":hits,"p0_center_path_mismatches":p0_mismatches,"rows":rows},"\t"));f.close();print("PATH_TARGET_MATRIX_DONE "+JSON.stringify({"cases":rows.size(),"damage_positive":hits,"p0_mismatch":p0_mismatches}));g.queue_free();await process_frame;quit(0)
