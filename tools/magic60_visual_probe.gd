extends SceneTree
const S=preload("res://scripts/spells.gd")
var g: Node2D
var results: Dictionary={}
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	g.visuals.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/magic60-"+name+".png")
func fixture(parts: Array) -> void:
	g.clear_magic()
	g.ui.close_modal()
	g.state="combat"
	for e in g.enemies: e.queue_free()
	g.enemies.clear()
	g.player.position=Vector2(800,450)
	for n in 80:
		var e: Node2D=g.Actor.new();g.actors.add_child(e);e.setup(g.art,1)
		e.position=g.player.position+Vector2.RIGHT.rotated(n*TAU/80)*(100+n%5*42)
		e.hp=100000;e.max_hp=e.hp;e.speed=0;g.enemies.append(e)
	g._rebuild_grid()
	var stage: Dictionary=S.roots(S.compile(parts).stages)[0]
	g.magic.begin_tick()
	g.magic.emit(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,-1,"primary",false,-1,-1,Vector2(970,450))
func advance(seconds: float) -> void:
	for n in ceili(seconds*60):
		g.magic.begin_tick();g._rebuild_grid();g._update_projectiles(1.0/60);g.magic.update_zones(1.0/60)
	await process_frame
func run() -> void:
	root.size=Vector2i(1920,1080)
	g=load("res://scenes/main.tscn").instantiate();g.record_runs=false
	root.add_child(g);current_scene=g;await process_frame
	g.start_run("sigil");g.set_arena_profile("measurement");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false
	fixture(["orbit","plasma_beam"]);await advance(.23);await capture("beam")
	fixture(["fall","split","fireball"]);await advance(.25);await capture("fall")
	fixture(["dragon_breath"]);await advance(.35);await capture("breath")
	fixture(["disintegration"]);await advance(.5);await capture("disintegration")
	fixture(["orbit_vortex"]);await advance(1.2);await capture("vortex")
	g.clear_magic();g.economy.inventory.clear()
	for id in S.PARTS: g.economy.inventory[id]=1
	g.orb_recipes=[["fall","orbit","fireball","impact","laser",""]]
	g.orb_drafts=g.orb_recipes.duplicate(true);g.recipe=g.orb_recipes[0].duplicate();g.draft=g.recipe.duplicate()
	g.compiled=S.compile(g.recipe).stages;g.orb_compiled=[g.compiled]
	g.ui.selected_item="fireball";g.open_personal("inventory")
	await process_frame;await capture("inventory")
	results["catalog_icons"]=true
	for id in S.PARTS:
		if not ResourceLoader.exists("res://assets/ui/spells/"+id+".svg"): results.catalog_icons=false
	g.close_personal();g.ui.collection_kind="fusion";g.ui.show_collection()
	await process_frame;await capture("collection")
	var file:=FileAccess.open("res://artifacts/magic60-visual-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results));file.close()
	print("MAGIC60_VISUAL_DONE "+JSON.stringify(results))
	quit()
