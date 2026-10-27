extends SceneTree
const Spells = preload("res://scripts/spells.gd")
var checks := 0
var failures := 0
var g: Node2D

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures += 1
		printerr("FAIL: "+message)

func shopping() -> void:
	g.start_run()
	g.recipe = ["bolt","impact","bloom"]
	g.compiled = Spells.compile(g.recipe).stages
	g.economy.inventory = {"bolt":1,"impact":1,"bloom":1,"fan":1}
	g.complete_wave()
	g.choose_reward("power")

func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_physics_process(false)
	g.sound_enabled = false
	shopping()
	verify(g.state == "shop" and g.draft == g.recipe,"Shop opens with editable applied recipe on the same screen")
	var stock: Dictionary = g.economy.inventory.duplicate()
	var data: Dictionary = g.orb_drag_data("fan",-1)
	verify(not data.is_empty() and g.draft == g.recipe,"Picking up a drag reserves no additional copies and removes nothing")
	verify(g.drop_orb(data,0) and g.draft == ["fan","bolt","impact","bloom"],"Inventory drag inserts before first attack and shifts the rest")
	verify(g.economy.inventory == stock and g.economy.remaining("fan",g.draft) == 0,"Equipping reserves one copy without changing ownership")
	verify(not g.drop_orb(data,0) and g.orb_drag_data("fan",-1).is_empty(),"Old drag payload and exhausted stock cannot duplicate an orb")
	g.undo_draft()
	verify(g.draft == g.recipe and g.economy.remaining("fan",g.draft) == 1,"Undo restores order and availability")
	data = g.orb_drag_data("bloom",2)
	verify(g.drop_orb(data,0) and g.draft == ["bloom","bolt","impact"],"Equipped drag moves earlier by insertion, without swapping")
	verify(not g.valid_draft() and Spells.compile(g.draft).error_index == 1,"Incomplete edits are allowed with a specific offending slot")
	verify(not g.apply_recipe() and g.recipe == ["bolt","impact","bloom"],"Invalid draft cannot replace applied combat recipe")
	g.undo_draft()
	data = g.orb_drag_data("bolt",0)
	g.drop_orb(data,3)
	verify(g.draft == ["impact","bloom","bolt"],"Moving right accounts for removed source index")
	g.undo_draft()
	data = g.orb_drag_data("impact",1)
	g.drop_orb(data,0,true)
	verify(g.draft == ["bolt","bloom"] and g.economy.inventory == stock,"Dropping into any inventory cell returns equipped orb without loss")
	g.undo_draft()
	g.add_part("fan")
	verify(g.draft == ["fan","bolt","impact","bloom"],"Click attaches modifier before the focused attack")
	g.remove_part(0)
	verify(g.draft == g.recipe,"Click/right-click removal leaves owned inventory intact")
	for id in Spells.PARTS: g.economy.inventory[id] = 2
	g.draft = ["fan","seek","bolt","impact","pierce","bloom"]
	g._draft_changed()
	verify(not g.can_drop_orb(g.orb_drag_data("echo",-1),2),"Full six-slot recipe rejects new inventory copies")
	verify(g.drop_orb(g.orb_drag_data("pierce",4),0) and g.draft.size() == 6 and g.draft[0] == "pierce","Full recipe still permits reordering existing slots")
	g.reset_draft()
	verify(g.draft == g.recipe,"Reset draft restores applied recipe")
	var foreign: Dictionary = g.orb_drag_data("fan",-1)
	foreign.owner += 1
	verify(not g.can_drop_orb(foreign,0) and not g.can_drop_orb("bad",0),"Foreign or malformed payload is rejected")
	g.economy.gold = 100
	g.economy.inventory.echo = 1
	g.economy.offers = [{"id":"echo","price":18,"sold":false}]
	var before_count: int = g.economy.inventory.echo
	g.add_part("fan")
	g.drop_orb(g.orb_drag_data("fan",3),0)
	var before_draft: Array = g.draft.duplicate()
	verify(g.buy_orb(0,g.economy.revision) and g.economy.inventory.echo == before_count+1 and g.economy.gold == 82,"New purchase enters the editable inventory immediately at correct price")
	verify(g.draft == before_draft and g.purchased_orb == "echo","Buying preserves unfinished edits and highlights the purchased type")
	g.drop_orb(g.orb_drag_data("echo",-1),0)
	verify(g.draft == ["echo","fan","bolt","impact","bloom"] and g.valid_draft(),"Purchased orb can be inserted directly into a valid draft")
	var saved := {"gold":g.economy.gold,"earned":g.economy.total_earned,"inventory":g.economy.inventory.duplicate(),"time":g.shop_time,"wave":g.wave,"hp":g.hp,"elapsed":g.elapsed,"kills":g.kills,"metrics":g.metrics.duplicate(),"position":g.player.position,"compiled":g.compiled.duplicate(true),"recipe":g.recipe.duplicate()}
	verify(g.start_trial() and g.state == "trial" and g.enemies.size() == 4,"Trial creates four stationary targets using draft instead of equipping it")
	g.get_viewport().warp_mouse(Vector2(690,260))
	await process_frame
	g._physics_process(2)
	verify(g.shop_time == saved.time and g.elapsed == saved.elapsed and g.wave == saved.wave,"Trial freezes shop timer and run progression")
	g.clear_magic()
	g.effects.clear()
	g.aim = Vector2.RIGHT
	g.emit_stage(g.trial_stages[0],Vector2(650,260),Vector2.RIGHT,g.trial_stages[1],1)
	for i in 90:
		g._rebuild_grid()
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
	verify(g.trial_hits > 0 and g.trial_damage > 0,"Trial runs actual projectile, echo, and linked explosion hit logic")
	verify(g.enemies.all(func(e):return not e.dead and e.hp == 1000000) and g.gems.is_empty(),"Trial targets survive hits and cannot drop money")
	verify(g.economy.gold == saved.gold and g.hp == saved.hp and g.kills == saved.kills,"Trial hits change neither run currency nor health nor kills")
	verify(g.recipe == saved.recipe and g.compiled == saved.compiled,"Trial does not silently commit draft to combat")
	g.remove_part(4)
	verify(g.trial_stages.is_empty() and g.projectiles.is_empty() and g.magic.echoes.is_empty() and g.magic.zones.is_empty(),"Invalid edit during trial stops casting and clears old spell effects")
	g.undo_draft()
	verify(not g.trial_stages.is_empty() and g.trial_stages[0].echo,"Repairing draft immediately recompiles trial with new modifiers")
	g.drop_orb(g.orb_drag_data("fan",1),0,true)
	verify(g.trial_stages[0].echo and not g.trial_stages[0].fan,"Removing modifier updates trial immediately")
	g.draft = ["giant","vortex","impact","echo","bloom"]
	g._draft_changed()
	g.emit_stage(g.trial_stages[0],Vector2(690,260),Vector2.RIGHT,g.trial_stages[1],1)
	for i in 80:
		g._rebuild_grid()
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
	verify(not g.magic.zones.is_empty() and g.trial_hits > 0,"Trial supports persistent vortex fields and on-damage child spells")
	g.draft = ["echo","thorn"]
	g._draft_changed()
	g.emit_stage(g.trial_stages[0],Vector2(690,260),Vector2.RIGHT,{},1)
	g.magic.update_projectiles(1.0/60)
	verify(not g.magic.echoes.is_empty() and not g.magic.zones.is_empty(),"Trial can own pending echoes and placed traps simultaneously")
	var stale: Dictionary = g.orb_drag_data("thorn",1)
	g.end_trial()
	verify(g.state == "shop" and g.enemies.is_empty() and g.projectiles.is_empty() and g.magic.zones.is_empty() and g.magic.echoes.is_empty() and g.effects.is_empty() and g.grid.is_empty(),"Returning to shop removes targets, projectiles, traps, echoes, and effects")
	verify(g.player.position == saved.position and g.metrics == saved.metrics,"Trial restores player pose and combat statistics")
	verify(g.shop_time == saved.time and g.economy.inventory == saved.inventory and g.draft == ["echo","thorn"],"Return preserves remaining time, purchases, and draft")
	verify(not g.drop_orb(stale,0),"Leaving trial invalidates active drag payload")
	g.start_trial()
	verify(g.apply_recipe() and g.state == "trial" and g.recipe == ["echo","thorn"],"Explicit apply during trial commits valid draft while remaining in trial")
	g.end_trial()
	g.launch_next_wave()
	verify(g.state == "combat" and g.wave == 2 and g.recipe == ["echo","thorn"] and g.enemies.is_empty(),"Starting next wave uses applied recipe and no trial targets")
	shopping()
	g.economy.gold = 40
	g.economy.offers = [{"id":"echo","price":18,"sold":false}]
	g.buy_orb(0,g.economy.revision)
	g.add_part("fan")
	data = g.orb_drag_data("bolt",0)
	g.shop_time = 0.01
	g._physics_process(0.02)
	verify(g.state == "combat" and g.wave == 2 and g.recipe == ["bolt","impact","bloom"] and g.draft == g.recipe,"Timeout discards incomplete draft and uses last applied recipe")
	verify(g.economy.inventory.echo == 1 and g.economy.gold == 22 and not g.drop_orb(data,3),"Timeout preserves purchase and rejects stale drag")
	g.open_editor()
	g.add_part("fan")
	g.cancel_editor()
	verify(g.state == "combat" and g.draft == g.recipe,"Combat editor cancel keeps original applied recipe")
	shopping()
	g.add_part("fan")
	g.drop_orb(g.orb_drag_data("fan",3),0)
	g.launch_next_wave()
	verify(g.state == "combat" and g.recipe == ["fan","bolt","impact","bloom"],"Explicit next-wave button applies valid current draft before launch")
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
