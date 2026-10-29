extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+note)
func run() -> void:
	root.size=Vector2i(1920,1080)
	var g: Node2D=load("res://scenes/training.tscn").instantiate()
	root.add_child(g);current_scene=g;await process_frame
	g.set_physics_process(false);g.sound_enabled=false
	check(g.state=="trial" and g.training_mode and not g.record_runs,"Disposable training, no persisted run")
	check(g.economy.inventory.size()==60,"All 30+30 spells freely stocked")
	check(g.orb_drafts.size()==4 and g.orb_capacities()==[8,8,8,8],"Four eight-slot orbs")
	check(g.enemies.size()==4 and not g.director.enabled and not g.encounters.enabled,"Four stationary targets, no combat spawns")
	var hp: float=g.enemies[0].hp
	var gold: int=g.economy.gold
	var xp: int=g.combat_rewards.total_xp
	g.damage_enemy(g.enemies[0],1e12,Vector2.RIGHT)
	check(g.enemies[0].hp==hp and not g.enemies[0].dead and g.trial_damage==1e12,"Dummy takes measured damage without dying")
	check(g.gems.is_empty() and g.economy.gold==gold and g.combat_rewards.total_xp==xp,"Training hit grants no loot or XP")
	check(g.ui.modal.find_child("TrainingCatalog",true,false)!=null and g.ui.modal.find_child("TrainingRank",true,false)!=null,"Catalog and rank controls visible")
	check(g.board_drop(g.board_data("laser"),0,7) and g.orb_drafts[0][7]=="laser","Real drag plan equips in chosen empty slot")
	g.set_training_rank(3)
	check(g.orb_drafts[0][7]=="laser@3" and g.economy.inventory.has("laser@3") and not g.economy.inventory.has("laser"),"Rank selector changes stock and equipped physical spell together")
	check(g.economy.inventory.has("plasma_beam"),"Completed spells stay unranked")
	g.orb_clocks.fill(0);g._tick_orbs(.001);g._tick_orbs(.2)
	check(not g.magic.extensions.beams.is_empty(),"New beam actually casts in room")
	var elapsed: float=g.elapsed
	var wave: float=g.wave_time
	g._update_trial(.2)
	check(g.elapsed==elapsed and g.wave_time==wave,"Practice does not advance combat or wave clock")
	g.reset_training(true)
	check(g.orb_drafts.all(func(row):return row.all(func(id):return id=="")),"Clear removes all equipped programs")
	check(g.magic.extensions.beams.is_empty() and g.projectiles.is_empty() and g.trial_damage==0,"Reset clears attacks, statuses and measured damage")
	check(g.economy.inventory.size()==60,"Clearing does not lose free stock")
	if "--render-check" in OS.get_cmdline_user_args():
		await process_frame;g.visuals.queue_redraw();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/training-room.png")
	g.queue_free();await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
