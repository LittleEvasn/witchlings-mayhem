extends SceneTree
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+message)
func find_named(node: Node, title: String) -> Node:
	if str(node.name)==title: return node
	for child in node.get_children():
		var found := find_named(child,title)
		if found!=null: return found
	return null
func layout() -> void:
	for n in 4: await process_frame
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.record_runs = false
	g.sound_enabled = false
	await process_frame
	g.start_run("sigil")
	g.set_physics_process(false)
	g.complete_wave()
	g.reward_options = ["droplet"]
	g.choose_reward("droplet")
	g.economy.gold = 300
	for id in g.Spells.PARTS:
		for rank in 4: g.economy.inventory[g.Spells.Progression.key(id,rank)] = 2
	g.ui.craft_tab="bag"
	g.ui.show_shop()
	await layout()
	check(g.ui.hud.visible and not g.ui.recipe_bar.visible,"World HUD remains visible without duplicate recipe strip")
	g.notice_left=0
	g.ui.update_hud()
	check(not g.ui.controls_hint.visible and not g.ui.objective_label.visible,"HUD refresh cannot expose overlapping hints behind drawer")
	check(g.ui.modal.mouse_filter==Control.MOUSE_FILTER_IGNORE and find_named(g.ui.modal,"ModalShade")==null,"Drawer does not dim or block the full battlefield")
	var drawer: Control=find_named(g.ui.modal,"CraftDrawer")
	check(drawer.size.x==520 and drawer.get_global_rect().position.x>=g.get_viewport_rect().size.x*.65,"Purchased-skin scaffold leaves at least 65 percent battlefield width")
	var before: Array = g.orb_recipes.duplicate(true)
	for orb in 2:
		for slot in 6:
			var cell: Control = find_named(g.ui.modal,"Socket_%d_%d"%[orb,slot])
			check(cell!=null and cell.get_global_rect().position.x>=drawer.get_global_rect().position.x and cell.get_global_rect().end.x<=drawer.get_global_rect().end.x,"All six sockets stay inside right drawer")
	var scroll: ScrollContainer = find_named(g.ui.modal,"CraftBagScroll")
	scroll.scroll_vertical = 175
	await layout()
	g.ui.inspect_item("bolt",0,1)
	await layout()
	scroll = find_named(g.ui.modal,"CraftBagScroll")
	check(scroll.scroll_vertical==175,"Selecting an item preserves bag scroll")
	check(find_named(g.ui.modal,"ForgePaid")!=null and g.orb_recipes==before,"Persistent detail does not edit equipment")
	g.ui.bag_filter="connector"
	g.ui.bag_scroll=0
	g.ui.show_shop()
	await layout()
	scroll = find_named(g.ui.modal,"CraftBagScroll")
	var cells: Array = scroll.get_child(0).get_children()
	check(cells.size()==8 and cells.all(func(c):return g.Spells.definition(c.id).kind=="connector"),"Connector filter includes both connectors at all four ranks")
	g.ui.craft_tab="fusion"
	g.ui.board_panel="fusion"
	g.ui.show_shop()
	await layout()
	var catalog: ScrollContainer = find_named(g.ui.modal,"CraftCatalog")
	check(catalog.get_child(0).get_child_count()==18,"All nine attack and nine support/event recipes available in scroll catalog")
	catalog.scroll_vertical=80
	await layout()
	catalog.get_child(0).get_child(8).pressed.emit()
	await layout()
	check(g.ui.fusion_choice==g.Spells.Progression.FUSIONS.keys()[8] and find_named(g.ui.modal,"CraftCatalog").scroll_vertical==80,"Fusion selection updates detail without resetting catalog")
	g.ui.craft_tab="research"
	g.ui.show_shop()
	await layout()
	catalog=find_named(g.ui.modal,"CraftCatalog")
	var stock_before: int = g.economy.inventory.get("bolt",0)
	for button in catalog.get_child(0).get_children():
		if "별빛탄" in button.text: button.pressed.emit(); break
	await layout()
	check(g.ui.craft_tab=="craft" and g.economy.offers[0].id=="bolt","Research returns selected orb to craft offer")
	var price: int = g.economy.offers[0].price
	var gold: int = g.economy.gold
	find_named(g.ui.modal,"CraftOffer0").pressed.emit()
	await layout()
	check(g.economy.inventory.bolt==stock_before+1 and g.economy.gold==gold-price,"Craft button consumes price once and grants one real copy")
	check(g.ui.craft_tab=="bag" and g.ui.selected_item=="bolt","Crafted orb opens in bag for immediate equip")
	check(g.orb_recipes==before,"Purchasing does not silently replace equipment")
	g.ui.bag_filter="attack"
	g.ui.selected_item="bolt"
	g.ui.board_panel="item"
	check(g.start_trial(),"New board enters existing live trial")
	await layout()
	check(find_named(g.ui.modal,"CraftDrawer")!=null and find_named(g.ui.modal,"Socket_1_5")!=null,"Trial uses the same complete drawer")
	check(find_named(g.ui.modal,"ForgePaid")==null and find_named(g.ui.modal,"CraftTab_craft").disabled,"Trial cannot craft or enter purchase tab")
	check(find_named(g.ui.modal,"CraftBagScroll").get_child(0).get_children().all(func(c):return g.Spells.definition(c.id).kind=="attack"),"Trial bag respects the selected filter")
	g.end_trial()
	await layout()
	check(g.state=="shop" and g.ui.bag_filter=="attack" and g.ui.selected_item=="bolt","Trial return preserves selection and filter")
	var fx = load("res://scripts/cartoon_vfx.gd").new()
	for key in ["bullet","explosion","moon","fire","star","shockwave"]:
		check(fx.texture(key)!=null,"Licensed effect imports: "+key)
	check(fx.texture("missing-effect")==null,"Missing effect safely retains previous renderer")
	g.start_run("sigil")
	g.set_physics_process(false)
	check(g.ui.craft_tab=="craft" and g.ui.bag_filter=="all" and g.ui.bag_scroll==0,"Restart resets only new-run UI selection state")
	g.clear_magic()
	var stage: Dictionary = g.Spells.compile(["bloom"]).stages[0]
	var c: Dictionary = g.magic.behavior.context(stage,g.player.position,Vector2.RIGHT,{},1,1,"primary",false,1,g.magic.generation)
	var damage: int = g.magic.behavior.area(c,g.player.position,20,70)
	check(damage==0 and g.magic.behavior.flashes.size()==1 and g.magic.behavior.flashes[0].effect=="explosion","Empty explosion still renders one sprite per event, independent of victim count")
	g.clear_magic()
	check(g.magic.behavior.flashes.is_empty(),"Clearing trial/combat removes presentation reservations")
	print("RESULT: %d checks / %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
