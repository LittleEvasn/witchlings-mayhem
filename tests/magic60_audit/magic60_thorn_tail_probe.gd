extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1920,1080);var g:Node2D=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_thorn_tail_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999;g.state="combat";g.player.position=Vector2(800,450);g.meter=load("res://scripts/combat_meter.gd").new()
	var stage:Dictionary=S.roots(S.compile(["pierce@3","thorn@3"]).stages)[0];g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(1100,450))
	var snapshots:Array=[]
	for frame in 750:
		g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60)
		if frame in [0,599,659,719,749]:snapshots.append({"seconds":float(frame+1)/60,"zones":g.magic.zones.map(func(z):return {"kind":z.get("kind",""),"age":z.get("age",0),"life":z.get("life",0),"pos":[z.pos.x,z.pos.y]}),"projectiles":g.projectiles.size(),"jobs":g.magic.extensions.jobs.size(),"zone_creations":g.meter.totals.get("zones_created",0),"finishes":g.meter.totals.get("projectiles_finished",0)})
	var f:=FileAccess.open("res://artifacts/magic60_thorn_tail_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"recipe":["pierce@3","thorn@3"],"simulated_seconds":12.5,"snapshots":snapshots},"\t"));f.close();print("THORN_TAIL_DONE "+JSON.stringify(snapshots));g.queue_free();await process_frame;quit(0)
