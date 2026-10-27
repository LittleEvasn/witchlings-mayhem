extends SceneTree
var g: Node2D
var observations: Dictionary={}
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	img.save_png("res://artifacts/fhd-"+label+"-20261027.png")
	observations[label]={"image":str(img.get_size()),"window":str(DisplayServer.window_get_size()),"viewport":str(root.get_visible_rect()),"ui":str(g.ui.root.get_global_rect())}
func run() -> void:
	root.mode=Window.MODE_FULLSCREEN
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	g.record_runs=false
	g.sound_enabled=false
	await capture("title")
	var shade: Control=g.ui.modal.get_node("ModalShade")
	observations["shade_covers_view"]=shade.get_global_rect().encloses(root.get_visible_rect())
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.enabled=false
	g.rng.seed=8881
	for i in 3:
		var enemy: Node2D=g.Actor.new()
		g.actors.add_child(enemy)
		enemy.setup(g.art,1)
		enemy.position=g.player.position+Vector2(260+i*110,-120+i*80)
		g.enemies.append(enemy)
	g.ui.update_hud()
	await capture("combat")
	g.open_personal("inventory")
	await capture("inventory")
	observations["drawer_preserves_center"]=not g.ui.personal_root.get_global_rect().has_point(root.get_visible_rect().get_center())
	g.close_personal()
	g.combat_rewards.issue(1,"screen_fixture")
	g.open_personal("reward")
	await capture("reward")
	var stage: Control=g.ui.personal_root
	observations["reward_in_view"]=root.get_visible_rect().encloses(stage.get_global_rect())
	observations["reward_below_center"]=stage.get_global_rect().position.y>root.get_visible_rect().size.y*.5
	g.close_personal()
	g._enter_preparation()
	await capture("crafting")
	var report:=FileAccess.open("res://artifacts/fhd-verification-20261027.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(observations,"  "))
	report.close()
	print(JSON.stringify(observations))
	quit()
