extends RefCounted
const Clicks=preload("res://tools/orb_workbench_visual_probe.gd")
static func find(node: Node, name: String) -> Node:
	if str(node.name)==name: return node
	for child in node.get_children():
		var result:=find(child,name)
		if result!=null: return result
	return null
static func frames(g: Node) -> void:
	await g.get_tree().process_frame
	await g.get_tree().process_frame
static func move(g: Node, at: Vector2, held := false, delta := Vector2.ZERO) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=at
	event.relative=delta
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	g.get_viewport().push_input(event,true)
static func mouse(g: Node, at: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=at
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	g.get_viewport().push_input(event,true)
static func drag(g: Node, source: String, target: String, edge := false) -> bool:
	var a: Control=find(g.ui.modal,source)
	var b: Control=find(g.ui.modal,target)
	if a==null or b==null: return false
	var start:=a.get_global_rect().get_center()
	var end:=b.get_global_rect().get_center()
	if edge: end.x=b.global_position.x+4
	move(g,start)
	mouse(g,start,true)
	move(g,start+Vector2(22,0),true,Vector2(22,0))
	await frames(g)
	move(g,end,true,end-start)
	await frames(g)
	var dragging: bool=g.get_viewport().gui_is_dragging()
	mouse(g,end,false)
	await frames(g)
	return dragging
static func click_cell(g: Node, name: String) -> bool:
	var cell: Control=find(g.ui.modal,name)
	if cell==null: return false
	var at:=cell.get_global_rect().get_center()
	move(g,at)
	mouse(g,at,true)
	mouse(g,at,false)
	await frames(g)
	return true
static func prepare(g: Node) -> Dictionary:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.complete_wave()
	g.choose_reward("power")
	g.economy.gold=180 # Reproducible UI fixture only.
	for id in ["bloom","vortex","seek","thunder","echo","pierce"]: g.economy.inventory[id]=1
	g.ui.show_shop()
	await frames(g)
	var attack:=await drag(g,"Bag_thunder","Socket_1_0")
	var modifier:=await drag(g,"Bag_seek","Socket_1_0",true)
	var equipped: bool=g.orb_recipes[1]==["seek","thunder"]
	var between:=await drag(g,"Socket_1_0","Socket_0_0",true)
	var moved: bool=g.orb_recipes[0]==["seek","fan","sigil","bolt"] and g.orb_recipes[1]==["thunder"]
	var undo:=await Clicks.click(g,"↶ 되돌리기")
	var restored: bool=g.orb_recipes[1]==["seek","thunder"]
	await click_cell(g,"Socket_1_1")
	var inspected: bool=g.ui.selected_item=="thunder" and g.ui.board_panel=="item"
	var upgrade:=await Clicks.click(g,"강화 ·")
	var upgraded: bool=g.orb_recipes[1]==["seek","thunder@1"]
	await Clicks.click(g,"상점")
	var research:=await Clicks.click(g,"구체 고르기")
	var pick:=await Clicks.click(g,g.ui.Board.glyph("bloom")+"  "+g.Spells.definition("bloom").name)
	var buy:=await Clicks.click(g,"12 G · 구매")
	return {"native_drag":attack and modifier and between,"equip":equipped,"cross_orb":moved,"undo":undo and restored,"inspect":inspected,"upgrade":upgrade and upgraded,"research_purchase":research and pick and buy and g.economy.inventory.bloom==2}
static func show_fusion(g: Node) -> bool:
	g.economy.inventory["bolt@4"]=1
	g.economy.inventory["thunder@4"]=1
	g.board_drop(g.board_data("bolt@4"),0,2,true)
	g.board_drop(g.board_data("thunder@4"),1,1,true)
	await frames(g)
	return await Clicks.click(g,"합성")
static func fuse_trial(g: Node) -> Dictionary:
	var fused:=await Clicks.click(g,"합성하기")
	var equipped: bool=g.orb_recipes[0]==["fan","sigil","storm_spear"] and g.orb_recipes[1].is_empty()
	var trial:=await Clicks.click(g,"시험 발사")
	g.cast_target=Vector2(710,260)
	g.orb_clocks=[0,0]
	g._tick_orbs(0.02)
	for i in 42:
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
	g.visuals.queue_redraw()
	g.ui.update_trial_stats()
	await frames(g)
	return {"fused":fused,"auto_equipped":equipped,"trial":trial and g.state=="trial","damage":g.trial_damage}
