extends SceneTree
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1;printerr("FAIL: "+message)
func setup(parts: Array = [["fan","bolt"],["thunder"]]) -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.complete_wave()
	g.reward_options=["droplet"] # Isolate spell/forge behavior from random relic bonuses.
	g.choose_reward("droplet")
	for id in g.Spells.PARTS: g.economy.inventory[id]=4
	g.economy.gold=200
	g.active_orb=0
	g.orb_drafts=parts.duplicate(true)
	g.draft=parts[0].duplicate()
	g._draft_changed()
	g.edit_history.clear()
	g.ui.show_shop()
func node_named(node: Node, id: String) -> Node:
	if str(node.name)==id: return node
	for child in node.get_children():
		var found:=node_named(child,id)
		if found!=null: return found
	return null
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	setup()
	await process_frame
	check(node_named(g.ui.modal,"Socket_0_5")!=null and node_named(g.ui.modal,"Socket_1_5")!=null,"Both complete six-slot rows are present simultaneously")
	var wave: int=g.wave
	var elapsed: float=g.elapsed
	var timer: float=g.shop_time
	g._physics_process(150.0)
	check(g.state=="shop" and g.wave==wave and g.elapsed==elapsed and g.shop_time==timer,"Preparation has no countdown, no waves or combat advance")
	var data: Dictionary=g.board_data("seek")
	var before: Array=g.orb_drafts.duplicate(true)
	check(not data.is_empty() and g.orb_drafts==before,"Starting/cancelling drag does not remove inventory or equipment")
	check(g.board_drop(data,1,0),"Drop from bag targets other orb without tab switch")
	check(g.orb_recipes[1]==["seek","thunder"] and g.orb_compiled[1][0].seek,"New slots compile and apply immediately")
	check(not g.board_drop(data,1,0),"Stale drag cannot replay")
	var moving: Dictionary=g.board_data("fan",0,0)
	check(g.board_drop(moving,1,1) and g.orb_recipes==[["bolt"],["seek","fan","thunder"]],"Cross-orb move preserves ownership and inserts at boundary")
	g.undo_draft()
	check(g.orb_recipes==[["fan","bolt"],["seek","thunder"]],"Undo restores both live recipes")
	check(g.board_drop(g.board_data("bolt",0,1),1,1,true),"Centre drop swaps across orbs")
	check(g.orb_recipes==[["fan","thunder"],["seek","bolt"]],"Swap retains both original components")
	check(g.board_drop(g.board_data("bloom"),0,1,true),"Inventory centre drop replaces occupied socket")
	check(g.orb_recipes[0]==["fan","bloom"] and g.remaining_part("thunder")==4,"Replaced component returns to available bag count")
	check(g.board_drop(g.board_data("fan",0,0),0,2),"Slot edges allow actual reordering")
	check(g.orb_recipes[0]==["bloom","fan"] and g.orb_compiled[0].is_empty(),"Invalid visible row silences that orb instead of firing old recipe")
	check(not g.valid_draft(),"Incomplete row prevents Ready or trial")
	g.undo_draft()
	check(g.orb_recipes[0]==["fan","bloom"] and not g.orb_compiled[0].is_empty(),"Undo restores firing after invalid intermediate row")
	check(g.board_drop(g.board_data("fan",0,0),-1,0) and g.orb_recipes[0]==["bloom"],"Dropping onto bag removes only selected component")
	g.economy.inventory.seek=1
	check(g.board_data("seek").is_empty(),"Fully equipped inventory cannot create extra copy")
	data=g.board_data("bloom",0,0)
	g.economy.revision+=1
	check(not g.board_drop(data,1,0),"Stock revision invalidates old drag after purchase or crafting")
	setup([["fan","seek","pierce","echo","giant","bolt"],["thunder"]])
	check(not g.board_drop(g.board_data("bounce"),0,3),"Seventh socket insertion rejected")
	check(g.board_drop(g.board_data("bloom"),0,5,true) and g.orb_recipes[0].size()==6,"Full row still permits centre replacement")
	g.economy.inventory["bolt@2"]=1
	check(g.board_drop(g.board_data("bolt@2"),1,0,true) and g.orb_compiled[1][0].rank_power==1.4,"Upgraded copy equips with rank intact")
	g.ui.inspect_item("bolt@2",1)
	await process_frame
	check(g.ui.selected_item=="bolt@2" and g.ui.board_panel=="item","Selecting socket opens contextual item details")
	check(g.craft_spell("upgrade","bolt@2","",g.economy.revision),"Contextual upgrade accepts equipped target")
	check(g.orb_recipes[1]==["bolt@3"] and g.ui.selected_item=="bolt@3","Upgrade refreshes sockets and selected detail")
	check(g.start_trial(),"Current two-orb configuration enters trial directly")
	var clock: float=g.shop_time
	var enemies: int=g.enemies.size()
	g._physics_process(0.1)
	check(g.shop_time==clock and g.wave==2-1 and g.enemies.size()==enemies,"Trial keeps shop and wave progression separate")
	check(g.board_drop(g.board_data("bolt@3",1,0),-1,0),"Trial editor removes equipped component")
	check(g.orb_trial[1].is_empty() and g.orb_recipes[1].is_empty(),"Trial edit immediately stops empty second orb")
	g.undo_draft()
	check(not g.orb_trial[1].is_empty() and g.orb_recipes[1]==["bolt@3"],"Trial undo restores current spell")
	g.end_trial()
	check(g.state=="shop" and g.enemies.is_empty() and g.projectiles.is_empty(),"Returning clears test attacks and targets")
	g.launch_next_wave()
	check(g.state=="combat" and g.wave==2,"Ready starts next wave with visible setup")
	g.open_editor()
	check(g.board_drop(g.board_data("bolt@3",1,0),-1,0),"Combat editor uses same direct slots")
	g.board_close()
	check(g.state=="combat" and g.orb_recipes[1].is_empty(),"Closing editor retains immediate edits")
	g.start_run("sigil")
	check(g.ui.selected_item.is_empty() and g.ui.board_panel=="shop","Restart clears stale selection")
	await process_frame
	print("RESULT: %d checks / %d failures" % [checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
