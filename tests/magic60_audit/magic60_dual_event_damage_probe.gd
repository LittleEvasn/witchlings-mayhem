extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g:Node2D
var out:Array=[]
func _initialize()->void:call_deferred("run")
func fresh()->void:
	g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT;g.cast_target=Vector2(1100,450)
	for e in g.enemies:e.queue_free()
	g.enemies.clear();g._rebuild_grid()
func enemy(at:Vector2)->Node2D:
	var e:Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1);e.position=at;e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e);g._rebuild_grid();return e
func hit_once(p:Dictionary,label:String)->Dictionary:
	var victim:=enemy(p.pos);var before:float=victim.hp;p.pos=victim.position;var start_count:int=g.projectiles.size();g._update_projectiles(1.0/600.0)
	var emitted:Array=[]
	for q in g.projectiles:
		if q!=p and not emitted.has(q):emitted.append(q)
	return {"label":label,"hp_loss":before-victim.hp,"damage_field":p.damage,"factor":p.factor,"potency":p.get("potency",1.0),"contact_events":g.meter.totals.get("projectile_contacts",0),"new_projectiles":g.projectiles.size()-start_count,"child_count":emitted.size(),"children":emitted}
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_dual_event_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	# Direct baseline for an attack bolt.
	fresh();var direct:Dictionary=S.roots(S.compile(["bolt"]).stages)[0];g.magic.emit(direct,g.player.position,Vector2.RIGHT,{},1.0,-1,"primary",false,-1,-1,g.player.position);var direct_p:Dictionary=g.projectiles[0];var direct_hit:=hit_once(direct_p,"direct_bolt")
	out.append({"label":"direct_bolt","hp_loss":direct_hit.hp_loss,"damage_field":direct_hit.damage_field,"factor":direct_hit.factor,"potency":direct_hit.potency,"contact_events":direct_hit.contact_events})
	# Inject the dual_event event, but let each descendant cause real projectile contacts/damage.
	fresh();var program:Dictionary=S.compile(["bolt","dual_event","bolt","impact@3","bolt"]);var root_stage:Dictionary=S.roots(program.stages)[0];g.magic.emit(root_stage,g.player.position,Vector2.RIGHT,S.follow(root_stage),1.0,-1,"primary",false,-1,-1,g.player.position);var source:Dictionary=g.projectiles[0];g.magic.trigger(source,g.player.position,"impact");var child:Dictionary=g.projectiles.back();g.projectiles.erase(source);var branch0:=hit_once(child,"dual_event_child_impact");var grandchild:Dictionary=g.projectiles.back();var branch0c:=hit_once(grandchild,"dual_event_grandchild_impact")
	# Root expire creates an independent second half-budget branch.
	var before_second:int=g.projectiles.size();g.magic.trigger(source,g.player.position,"expire");var second:Dictionary=g.projectiles.back();var branch1:=hit_once(second,"dual_event_child_expire");var second_grandchild:Dictionary=g.projectiles.back();var branch1c:=hit_once(second_grandchild,"dual_event_grandchild_expire")
	for row in [branch0,branch0c,branch1,branch1c]:
		row.erase("children");out.append(row)
	out.append({"label":"summary","program_compiles":program.ok,"branches":g.projectiles.size()+1,"expected_per_descendant_from_doc":11,"interpretation":"synthetic root event injection; child and grandchild damage measured through actual engine projectile collision"})
	var f:=FileAccess.open("res://artifacts/magic60_dual_event_damage_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"cases":out},"\t"));f.close();print("DUAL_EVENT_DAMAGE_DONE "+JSON.stringify(out));g.queue_free();await process_frame;quit(0)
