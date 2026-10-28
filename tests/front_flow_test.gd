extends SceneTree
const Profile=preload("res://scripts/player_profile.gd")
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func button(id: String) -> Button: return g.ui.modal.get_node(id)
func click(id: String) -> void: button(id).pressed.emit()
func escape() -> void:
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_ESCAPE
	key.pressed=true
	g._input(key)
func settle() -> void:
	for i in 3: await process_frame
func key_press(key: Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=key
		event.physical_keycode=key
		event.pressed=down
		root.push_input(event,true)
		await process_frame
func buttons_fit() -> bool:
	var screen:=g.get_viewport_rect()
	for node in g.ui.modal.get_children():
		if node is Button and not screen.encloses(node.get_global_rect()): return false
	return true
func run() -> void:
	root.size=Vector2i(1600,900)
	g=load("res://scenes/main.tscn").instantiate()
	g.checkpoint_store=g.RunCheckpoint.new("user://front-flow-checkpoint-test.json")
	g.record_runs=false
	root.add_child(g)
	current_scene=g
	g.set_physics_process(false)
	g.sound_enabled=false
	g.profile=Profile.new("user://front-flow-test.json")
	await settle()
	check(g.state=="title" and g.ui.front_screen=="title","Launch opens title without combat")
	check(not g.ui.hud.visible and not g.player.visible,"Front screen hides battle HUD and duplicate actor")
	check(button("NewExperiment")!=null and button("Records")!=null and button("Settings")!=null and button("Quit")!=null,"Title has real new-run, records, settings and exit actions")
	check(g.ui.modal.get_node_or_null("Continue")==null and g.ui.modal.get_node_or_null("Collection")!=null,"Fresh title hides unavailable continue and provides implemented collection")
	check(buttons_fit(),"Title buttons fit viewport")
	click("NewExperiment")
	await settle()
	check(g.state=="title" and g.ui.front_screen=="prepare","Start opens preparation, not combat")
	check(g.ui.setup_intro,"Unseen introduction is enabled by default")
	var original: Dictionary=g.economy.inventory.duplicate()
	var old_kit: String=g.selected_kit
	for id in g.Economy.KITS:
		click("Kit_"+id)
		g._physics_process(20)
		check(g.ui.setup_kit==id and g.economy.inventory==original and g.selected_kit==old_kit,"Choosing %s only previews, without consuming or starting"%id)
	check(buttons_fit(),"Preparation buttons fit viewport")
	escape()
	check(g.state=="title" and g.ui.front_screen=="title" and g.enemies.is_empty(),"Escape returns cleanly from selection to title")
	click("NewExperiment")
	click("Kit_frost")
	click("StartExperiment")
	check(g.state=="intro" and g.ui.intro_index==0 and g.selected_kit=="frost","Confirm starts selected frost kit at first story line")
	check(g.recipe==g.Economy.KITS.frost.recipe and g.economy.owns_recipe(g.recipe),"Selected starting program has actual inventory")
	check(g.player.visible and not g.ui.hud.visible,"Introduction is over real playfield with player visible")
	check(buttons_fit() and button("IntroBack")!=null,"Story has visible selection-back action within viewport")
	var elapsed_before: float=g.elapsed
	var prep_before: float=g.prep_elapsed
	g._physics_process(80)
	check(g.elapsed==elapsed_before and g.prep_elapsed==prep_before and g.enemies.is_empty() and g.projectiles.is_empty(),"Story does not advance combat, editing time, shots or enemies")
	click("IntroNext")
	check(g.ui.intro_index==1 and g.state=="intro","Next shows second story line")
	escape()
	check(g.state=="title" and g.ui.front_screen=="prepare" and g.ui.setup_kit=="frost","Escape from story returns to same start kit")
	check(not g.profile.data.intro_seen,"Backing out does not mark story complete")
	click("StartExperiment")
	click("IntroNext")
	click("IntroNext")
	check(g.ui.intro_index==2 and g.state=="intro","All three lines precede explicit combat start")
	click("IntroNext")
	check(g.state=="combat" and g.ui.front_screen.is_empty() and g.ui.modal==null and g.ui.hud.visible,"Last line starts combat and removes front input layer")
	check(g.profile.data.intro_seen,"Completing introduction remembers it")
	g.return_title()
	click("NewExperiment")
	check(not g.ui.setup_intro,"Subsequent run skips introduction by default")
	var toggle: CheckButton=g.ui.modal.get_node("ReplayIntro")
	toggle.button_pressed=true
	click("StartExperiment")
	check(g.state=="intro" and g.ui.intro_index==0,"Replay toggle can request introduction again")
	click("IntroSkip")
	check(g.state=="combat" and g.elapsed==0,"Skip starts combat without artificial elapsed time")
	# Persist a result to an isolated test profile, never the user's profile.
	g.record_runs=true
	g.spawn_enemy(0,false,g.player.position+Vector2(340,0))
	g.elapsed=42
	g.prep_elapsed=13
	g.kills=21
	g.economy.grant(51)
	g.relics.acquire("droplet")
	g.end_run(true)
	await settle()
	check(g.state=="ended" and g.ui.front_screen=="results","Victory opens ending and result in one screen")
	check(g.run_record.won and g.run_record.combat==42 and g.run_record.kills==21,"Results retain the concluded run")
	check(g.ui.modal.get_node_or_null("ResultOrb0")!=null and g.ui.modal.get_node_or_null("ResultOrb1")!=null,"Results include both orb programs")
	var slots_ok:=true
	for orb in 2:
		for slot in 6:
			var tile: Control=g.ui.modal.get_node_or_null("ResultSlot%d_%d"%[orb,slot])
			slots_ok=slots_ok and tile!=null
			if tile!=null and slot<g.orb_recipes[orb].size(): slots_ok=slots_ok and tile.tooltip_text.begins_with(g.Spells.definition(g.orb_recipes[orb][slot]).name)
	check(slots_ok,"Results show all twelve ordered slots with actual equipped spell details")
	check(buttons_fit(),"Result actions fit viewport")
	g.end_run(true)
	g.ui.show_results()
	check(g.profile.data.records.size()==1 and g.profile.data.wins==1,"Reopening results and repeated end calls cannot duplicate records")
	var saved:=Profile.new(g.profile.path)
	saved.load_profile()
	check(saved.data.intro_seen and saved.data.wins==1,"Introduction preference survives profile reload with records")
	g.record_runs=false
	click("RetrySame")
	check(g.state=="combat" and g.selected_kit=="frost" and g.ui.front_screen.is_empty(),"Same-kit retry goes straight to combat")
	check(g.economy.gold==0 and g.relics.owned.is_empty() and g.elapsed==0 and g.hp==100 and g.orb_recipes[1].is_empty(),"Retry clears run-local money, relics, time, damage and second orb")
	check(g.enemies.is_empty() and g.projectiles.is_empty() and g.director.pending.is_empty(),"Retry clears surviving enemies, attacks and spawn reservations")
	check(g.economy.owns_recipe(g.recipe) and g.recipe==g.Economy.KITS.frost.recipe,"Retry returns original starting recipe without upgraded copies")
	g.end_reason="테스트 사망"
	g.end_run(false)
	check(g.ui.front_screen=="results" and not g.result_win and g.run_record.reason=="테스트 사망","Death opens unified result with correct failure reason")
	click("RetryOther")
	check(g.state=="title" and g.ui.front_screen=="prepare" and g.enemies.is_empty() and g.projectiles.is_empty(),"Other-kit retry opens selection after clearing encounter")
	click("Kit_garden")
	click("StartExperiment")
	check(g.state=="combat" and g.recipe==g.Economy.KITS.garden.recipe and g.selected_kit=="garden","Different starting kit is used by next run")
	g.end_run(false)
	escape()
	check(g.state=="title" and g.ui.front_screen=="title","Escape from results returns to title")
	click("Records")
	check(g.ui.front_screen=="records","Title records opens existing concluded-run list")
	escape()
	click("Settings")
	check(g.ui.front_screen=="settings_title" and g.state=="title","Settings remember title origin")
	escape()
	check(g.ui.front_screen=="title","Escape from settings returns to title")
	click("Quit")
	await settle()
	check(g.ui.front_screen=="quit" and root.gui_get_focus_owner()==button("CancelQuit"),"Exit requires confirmation and defaults to cancel")
	escape()
	check(g.ui.front_screen=="title","Escape cancels exit")
	escape()
	check(g.ui.front_screen=="quit","Escape on title opens confirmation rather than quitting")
	click("CancelQuit")
	click("NewExperiment")
	await settle()
	check(root.gui_get_focus_owner()==button("Kit_garden"),"Preparation focuses actual previously selected kit")
	var recipe_key:=InputEventKey.new()
	recipe_key.physical_keycode=KEY_TAB
	recipe_key.pressed=true
	g._input(recipe_key)
	check(g.state=="title" and g.ui.front_screen=="prepare","Tab on front end cannot start editing or combat")
	await key_press(KEY_TAB)
	check(root.gui_get_focus_owner()==button("Kit_charge") and g.ui.front_screen=="prepare","Actual Tab input moves GUI focus without invoking combat editor")
	await key_press(KEY_ENTER)
	await settle()
	check(g.ui.setup_kit=="charge" and g.state=="title","Enter previews focused kit without starting combat")
	var legacy: Dictionary=g.profile.data.duplicate(true)
	legacy.erase("intro_seen")
	check(g.profile._valid(legacy),"Old profile lacking intro preference remains valid")
	legacy["intro_seen"]="yes"
	check(not g.profile._valid(legacy),"Invalid intro preference is rejected")
	# Verify battle pause settings do not accidentally return to the title.
	click("StartExperiment")
	g.state="paused"
	g.ui.show_settings(false)
	escape()
	check(g.state=="paused" and g.ui.front_screen.is_empty(),"Pause settings back returns to pause without launching new run")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(g.profile.path+suffix): DirAccess.remove_absolute(g.profile.path+suffix)
	g.queue_free()
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(1 if failures else 0)
