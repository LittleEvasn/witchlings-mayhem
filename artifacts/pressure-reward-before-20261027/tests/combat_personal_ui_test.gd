extends SceneTree
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1;printerr("FAIL: "+message)
func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.music_enabled=false
	g.director.enabled=false
	g.invincible=100
func clear_enemies() -> void:
	for e in g.enemies: e.queue_free()
	g.enemies.clear()
	g._rebuild_grid()
func enemy(offset: Vector2) -> Node2D:
	var e: Node2D=g.Actor.new()
	g.actors.add_child(e)
	e.setup(g.art,1)
	e.position=g.player.position+offset
	e.hp=100000
	e.max_hp=e.hp
	e.speed=0
	g.enemies.append(e)
	return e
func find(node: Node, name_value: String) -> Node:
	if str(node.name)==name_value: return node
	for child in node.get_children():
		var found:=find(child,name_value)
		if found!=null: return found
	return null
func key(code: int) -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=code
	e.pressed=true
	g._unhandled_input(e)
func mouse_button(point: Vector2, pressed: bool) -> void:
	var e:=InputEventMouseButton.new()
	e.position=point
	e.global_position=point
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=pressed
	g.get_viewport().push_input(e,true)
func mouse_motion(point: Vector2, relative := Vector2.ZERO, dragging := false) -> void:
	var e:=InputEventMouseMotion.new()
	e.position=point
	e.global_position=point
	e.relative=relative
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if dragging else 0
	g.get_viewport().push_input(e,true)
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	var hud_focus:=0
	for child in g.ui.hud.get_children():
		if child is Button and child.focus_mode!=Control.FOCUS_NONE: hud_focus+=1
	for child in g.ui.recipe_bar.get_children():
		if child is Button and child.focus_mode!=Control.FOCUS_NONE: hud_focus+=1
	check(hud_focus==0,"Persistent HUD buttons cannot capture Space dash as GUI activation")
	var c:=enemy(Vector2(0,300))
	var a:=enemy(Vector2(120,0))
	var b:=enemy(Vector2(-220,0))
	var hidden:=enemy(Vector2(1200,0))
	var ranked: Array=g.AutoTargeting.ranked(g)
	check(ranked==[a,b,c],"Ranks use player distance and ignore enemies outside camera")
	check(g.AutoTargeting.target_for(ranked,0)==a and g.AutoTargeting.target_for(ranked,1)==b and g.AutoTargeting.target_for(ranked,2)==c,"Target selector supports third and later orbs without adding orb slots")
	g.orb_compiled=[g.Spells.compile(["bolt"]).stages,g.Spells.compile(["bolt"]).stages]
	g.orb_clocks=[0.0,0.0]
	g._tick_orbs(.01)
	check(g.projectiles.size()==2,"Both orbs cast independently")
	if g.projectiles.size()==2:
		check(g.projectiles[0].dir.dot(g.orb_position(0).direction_to(a.position))>.999,"Orb 1 shoots nearest enemy")
		check(g.projectiles[1].dir.dot(g.orb_position(1).direction_to(b.position))>.999,"Orb 2 shoots second enemy, not active UI orb target")
	a.dead=true
	check(g.AutoTargeting.target_for(ranked,0)==b,"Cached ranks skip a target killed by previous orb in same tick")
	ranked=g.AutoTargeting.ranked(g)
	check(ranked==[b,c],"Dead target removed before queued node deletion")
	b.dead=true
	check(g.AutoTargeting.target_for(g.AutoTargeting.ranked(g),1)==c,"Both orbs share sole remaining target")
	c.dead=true
	check(g.AutoTargeting.target_for(g.AutoTargeting.ranked(g),0)==null,"No target returns safe fallback")
	g.last_move=Vector2.DOWN
	g._update_auto_aim()
	check(g.cast_target==g.player.position+Vector2(0,320),"Without enemies aim follows last movement, never cursor")
	clear_enemies()
	g.clear_magic()
	var lightning: Dictionary=g.Spells.compile(["thunder"]).stages[0]
	g.cast_target=Vector2(-9000,-9000)
	g.rng.seed=12345
	var centers: Array=[]
	for i in 12:
		g.magic.begin_tick()
		g.emit_stage(lightning,g.player.position,Vector2.RIGHT,{},1)
		centers.append(g.magic.behavior.strikes.back().center)
	check(centers.all(func(p):return p.distance_to(g.player.position)>=89.9 and p.distance_to(g.player.position)<=360.1),"Unlinked lightning rains in player annulus, independent of cast_target")
	check(centers[0]!=centers[1],"Lightning positions randomize on successive casts")
	lightning["_linked"]=true
	g.magic.begin_tick()
	var event_point: Vector2=g.player.position+Vector2(500,0)
	g.magic.emit(lightning,event_point,Vector2.RIGHT,{},1)
	check(g.magic.behavior.strikes.back().center==event_point,"Linked lightning retains event location")
	lightning.erase("_linked")
	lightning["_intrinsic"]=true
	g.magic.begin_tick()
	g.magic.emit(lightning,event_point,Vector2.RIGHT,{},1)
	check(g.magic.behavior.strikes.back().center==event_point,"Fusion lightning retains impact location")
	fresh()
	g.open_editor()
	await process_frame
	await process_frame
	check(g.state=="combat" and g.personal_tab=="inventory" and g.ui.modal==null,"Tab editor is personal state, world remains combat with no full-screen modal")
	check(g.ui.hud.visible and is_instance_valid(g.ui.personal_root),"Battle HUD remains visible")
	check(g.ui.personal_root.size.x<=420 and g.ui.personal_root.position.x>=1000,"Personal drawer uses at most thirty percent of screen")
	check(find(g.ui.personal_root,"Socket_0_5")!=null and find(g.ui.personal_root,"Socket_1_5")!=null,"All six slots of both orbs fit in live drawer")
	var before: float=g.wave_time
	var position: Vector2=g.player.position
	Input.action_press("move_right")
	g._physics_process(.1)
	Input.action_release("move_right")
	check(g.wave_time>before and g.player.position.x>position.x,"Combat clock and movement continue while editing")
	var hostile_start: Vector2=g.player.position+Vector2(-100,0)
	g.hostile_shots.append({"pos":hostile_start,"vel":Vector2(100,0),"life":3})
	g._physics_process(.05)
	check(not g.hostile_shots.is_empty() and g.hostile_shots[0].pos.x>hostile_start.x,"Enemy attacks continue behind drawer")
	g.economy.inventory["thunder"]=1
	g.ui.show_personal()
	await process_frame
	await process_frame
	var source: Control=find(g.ui.personal_root,"Bag_thunder")
	var target: Control=find(g.ui.personal_root,"Socket_1_0")
	var source_point:=source.get_global_rect().get_center()
	var target_point:=target.get_global_rect().get_center()
	mouse_motion(source_point)
	mouse_button(source_point,true)
	mouse_motion(source_point+Vector2(12,0),Vector2(12,0),true)
	await process_frame
	mouse_motion(target_point,target_point-source_point,true)
	await process_frame
	mouse_button(target_point,false)
	await process_frame
	check(g.orb_recipes[1]==["thunder"],"Actual GUI drag from bag to second orb equips live spell immediately")
	g.undo_draft()
	check(g.orb_recipes[1].is_empty(),"Undo restores both orb inventory without rewinding combat")
	check(g.board_drop(g.board_data("bolt",0,2),-1,0),"Removing attack allows invalid intermediate row")
	check(g.orb_compiled[0].is_empty(),"Invalid row silences its orb")
	g.close_personal()
	check(g.personal_tab.is_empty() and g.state=="combat","Invalid row does not trap player in drawer")
	g.open_editor()
	g.undo_draft()
	check(not g.orb_compiled[0].is_empty(),"Reopening and undo restores spell")
	var t: float=g.elapsed
	g.open_personal("relics")
	g._physics_process(.05)
	check(g.state=="combat" and g.elapsed>t,"Owned relic view also leaves combat running")
	key(KEY_ESCAPE)
	check(g.state=="combat" and g.personal_tab.is_empty(),"First Esc closes personal window")
	key(KEY_ESCAPE)
	check(g.state=="paused","Second Esc opens existing solo pause")
	g.resume_game()
	fresh()
	check(g.combat_rewards.reserved(1)==18 and g.combat_rewards.reserved(5)==0,"Intermediate spell uses 18G allocation before boss")
	g.wave_time=29.99
	g.wave_kills=100
	g.combat_rewards.tick()
	check(g.combat_rewards.pending.is_empty(),"No mid-wave reward before thirty seconds")
	g.wave_time=30
	g.wave_kills=11
	g.combat_rewards.tick()
	check(g.combat_rewards.pending.is_empty(),"Mid-wave choice requires actual kills")
	g.wave_kills=12
	g.combat_rewards.tick()
	g.combat_rewards.tick()
	check(g.combat_rewards.pending.size()==1 and g.personal_tab.is_empty(),"Choice queues once without forcing a window")
	var options: Array=g.combat_rewards.pending[0].options.duplicate()
	g.open_personal("reward")
	g.close_personal()
	g.open_personal("reward")
	await process_frame
	await process_frame
	check(g.ui.personal_root.get_global_rect().end.y<=g.logical_view_size().y-100,"Reward cards scroll without enlarging drawer across lower battle HUD")
	check(g.combat_rewards.pending[0].options==options and options.size()==3,"Three distinct candidates stay fixed on reopen")
	var reward_id: String=g.combat_rewards.pending[0].id
	var revision: int=g.combat_rewards.revision
	var id: String=options[0]
	var stock: int=g.economy.inventory.get(id,0)
	var recipes: Array=g.orb_recipes.duplicate(true)
	check(g.claim_spell_reward(reward_id,id,revision),"Personal choice grants exactly one component")
	check(g.economy.inventory.get(id,0)==stock+1 and g.orb_recipes==recipes,"Chosen component goes to bag without replacing spells")
	check(not g.claim_spell_reward(reward_id,id,revision),"Duplicate reward click cannot grant twice")
	g.open_editor()
	check(not g.board_data(id).is_empty(),"Chosen component can immediately be dragged into live composition")
	g.close_personal()
	g.wave=2
	g.wave_time=31
	g.wave_kills=12
	g.combat_rewards.tick()
	check(g.combat_rewards.pending.size()==1,"Next wave earns independent choice")
	g.complete_wave()
	check(g.state=="reward" and g.combat_rewards.pending.size()==1 and g.personal_tab.is_empty(),"Wave end clears drawer but preserves already earned choice")
	g.reward_options=["droplet"]
	g.choose_reward("droplet")
	check(g.state=="shop" and g.combat_rewards.pending.size()==1,"Pending spell survives existing relic-to-crafting flow")
	g.open_personal("reward")
	var clock: float=g.wave_time
	g._physics_process(1)
	check(g.wave_time==clock and g.state=="shop","Preparation choice does not start combat")
	var queue_before: Array=g.combat_rewards.pending.duplicate(true)
	g.close_personal()
	check(g.start_trial(),"Crafting trial remains available")
	g._physics_process(.1)
	check(g.combat_rewards.pending==queue_before,"Trial does not issue or consume combat choices")
	g.end_trial()
	var stale_id: String=g.combat_rewards.pending[0].id
	var stale_rev: int=g.combat_rewards.revision
	fresh()
	check(g.combat_rewards.pending.is_empty() and not g.claim_spell_reward(stale_id,id,stale_rev),"Restart discards pending rewards and rejects old callbacks")
	var total:=0
	for i in 100: total+=g.director.reward(1)
	check(total==30 and total+g.CombatRewards.ALLOCATION==g.Waves.config(1).drop_budget,"One allocated choice plus ordinary drops never exceeds original wave budget")
	fresh()
	g.wave_time=29
	for i in 60: g.director.reward(1)
	g.complete_wave()
	check(g.economy.gold==38,"Unearned choice returns only withheld earned value plus clear bonus, not every ordinary drop")
	fresh()
	for p in g.Economy.PRICES: g.economy.inventory[p]=12
	g.wave_time=31
	g.wave_kills=12
	g.combat_rewards.tick()
	var full: Dictionary=g.combat_rewards.pending[0]
	check(full.options.is_empty(),"Full-stock reward has explicit cash fallback")
	g.economy.inventory.bolt=11
	g.combat_rewards.refresh_options()
	check(full.options==["bolt"],"Freeing stock after an empty offer repopulates and unlocks reward queue")
	g.economy.inventory.bolt=12
	g.combat_rewards.refresh_options()
	check(g.claim_spell_reward(full.id,"",g.combat_rewards.revision) and g.economy.gold==18,"Full stock converts reserved value once")
	check(not g.claim_spell_reward(full.id,"",g.combat_rewards.revision),"Cash fallback cannot be duplicated")
	g.wave=2
	g.wave_time=31
	g.wave_kills=12
	g.combat_rewards.tick()
	g.end_run(false)
	check(g.combat_rewards.pending.is_empty(),"Death discards experiment reward queue")
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
