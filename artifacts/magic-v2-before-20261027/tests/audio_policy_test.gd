extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1;printerr("FAIL: "+message)
func run() -> void:
	var g: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	g.set_physics_process(false)
	g.record_runs=false
	check(not g.music_enabled and not is_instance_valid(g.music_player),"No BGM player starts at title")
	for phase in ["prepare","combat","boss"]:
		g.profile.data.music=true
		g.music_enabled=true
		g.set_music(phase)
		check(not g.music_enabled and not is_instance_valid(g.music_player),"Old settings cannot restart soundtrack: "+phase)
		check(not FileAccess.file_exists("res://assets/audio/"+phase+".wav"),"Provisional WAV removed from assets: "+phase)
	check(g.audio.size()==8 and g.sounds.has("cast") and g.sounds.has("reward"),"Existing gameplay sound effects remain available")
	g.sound_enabled=true
	g.play_sound("cast")
	check(g.audio[0].stream==g.sounds.cast,"Cast sound still routes to effect channel")
	g.start_run("sigil")
	g.complete_wave()
	g.reward_options=["droplet"]
	g.choose_reward("droplet")
	g.wave=4
	g.start_next_wave()
	check(g.state=="combat" and g.music_phase=="boss" and not is_instance_valid(g.music_player),"Preparation and boss transition remain silent")
	g.save_settings()
	check(g.profile.data.sound and not g.profile.data.music,"Effect setting remains independent from disabled BGM")
	g.state="paused"
	g.ui.show_settings(false)
	var buttons: Array=[]
	var stack: Array=[g.ui.modal]
	while not stack.is_empty():
		var node: Node=stack.pop_front()
		if node is Button and node.text.begins_with("배경 음악"): buttons.append(node)
		for child in node.get_children(): stack.append(child)
	check(buttons.size()==1 and buttons[0].disabled,"Settings offers no misleading soundtrack enable switch")
	for channel in g.audio:
		channel.stop()
		channel.stream=null
	await process_frame
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
