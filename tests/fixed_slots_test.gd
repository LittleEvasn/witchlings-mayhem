extends SceneTree
const S=preload("res://scripts/spells.gd")
const Store=preload("res://scripts/run_checkpoint.gd")
const Profile=preload("res://scripts/player_profile.gd")
const Forge=preload("res://scripts/spell_forge.gd")
const PREFIX="user://fixed-slots-test"
var checks:=0
var failures:=0
var g: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func roots_of(parts: Array) -> Array:
	return S.roots(S.compile(parts).stages).map(func(stage):return stage.attack)
func equip(bank: Array) -> void:
	g.active_orb=0
	g.orb_drafts=S.fixed_bank(bank)
	g.orb_recipes=S.fixed_bank(bank)
	g.orb_compiled=[]
	g.orb_trial=[]
	g.orb_clocks=[]
	g.orb_cursors=[]
	for _i in bank.size():
		g.orb_compiled.append([])
		g.orb_trial.append([])
		g.orb_clocks.append(0.0)
		g.orb_cursors.append(0)
	g.recipe=g.orb_recipes[0].duplicate()
	g.draft=g.orb_drafts[0].duplicate()
	g._commit_live_board()
	g.edit_history.clear()
func find(node: Node, key: String) -> Node:
	if str(node.name)==key: return node
	for child in node.get_children():
		var found:=find(child,key)
		if found!=null: return found
	return null
func drag_socket(source: String, destination: String) -> void:
	var a: Vector2=find(g.ui.modal,source).get_global_rect().get_center()
	var b: Vector2=find(g.ui.modal,destination).get_global_rect().get_center()
	var down:=InputEventMouseButton.new()
	down.position=a
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	root.push_input(down,true)
	await process_frame
	for point in [a+Vector2(24,4),b]:
		var motion:=InputEventMouseMotion.new()
		motion.position=point
		motion.relative=Vector2(24,4)
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await process_frame
	var up:=InputEventMouseButton.new()
	up.position=b
	up.button_index=MOUSE_BUTTON_LEFT
	up.pressed=false
	root.push_input(up,true)
	await process_frame
func run() -> void:
	root.size=Vector2i(1600,900)
	check(S.fixed_slots(["bolt"])==["bolt","","","","",""],"Legacy rows pad only trailing slots")
	check(roots_of(["","","","","","bolt"])==["bolt"],"Attack in slot six really compiles")
	var spaced:=S.compile(["fan","","bolt","impact","","bloom"])
	check(spaced.ok and spaced.stages[0].slot==2 and spaced.stages[1].slot==5,"Sparse source indices retained")
	check(spaced.stages[0].next.attack=="bloom" and S.roots(spaced.stages).size()==1,"Trigger skips gaps; child is not an independent root")
	check(spaced.stages.all(func(stage):return stage.fan==1),"Existing all-right support scope unchanged")
	check(S.affected_slots(["fan","","bolt","impact","","bloom"],0)==[2,5],"Support highlight uses actual positions")
	for case in [ [["bolt","","bloom"],["bolt","bloom"]], [["bolt","impact"],["bolt"]], [["bolt","fan"],["bolt"]], [["impact","bolt","bloom"],["bolt","bloom"]], [["bolt","impact","expire","bloom","thunder"],["bolt","thunder"]], [["bolt","impact","expire","bloom","impact","thunder"],["bolt"]], [["bolt","unknown","bloom"],["bolt","bloom"]] ]:
		check(roots_of(case[0])==case[1],"Recovery execution matches rule: "+str(case[0]))
	var broken:=S.compile(["bolt","impact","expire","bloom","thunder"])
	for slot in [1,2,3]: check(not S.slot_diagnostic(broken,slot).is_empty(),"Every bad edge/payload diagnosed: %d"%slot)
	check(S.slot_diagnostic(S.compile(["bolt","fan"]),1).severity=="inactive","Unused support is grey/inactive")
	check(S.compile(S.fixed_slots([])).ok and S.compile(S.fixed_slots([])).stages.is_empty(),"Empty row has no fake error")
	check(S.compile(["bolt","impact","bloom","expire","thunder"]).stages[0].next.next.attack=="thunder","Valid multistage chains preserved")
	var cascade:=S.compile(["bolt","impact","expire","bloom","impact","thunder"])
	check(S.slot_diagnostic(cascade,4).code=="inactive_source" and "앞 공격" in S.slot_diagnostic(cascade,4).reason,"Downstream diagnostics name the inactive source instead of a nonexistent missing attack")
	check(roots_of(["bolt","impact","unknown","unknown","bloom"])==["bolt"],"Multiple unknowns do not release a blocked payload as independent attack")
	check(S.compile(["bolt","bloom","thunder","frost","vortex","thorn","bolt","bolt","bolt"]).stages.is_empty(),"Compiler cannot exceed expanded eight-slot maximum")
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	g.profile=Profile.new(PREFIX+"-profile.json")
	g.checkpoint_store=Store.new(PREFIX+"-save.json")
	root.add_child(g)
	current_scene=g
	await process_frame
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.director.enabled=false
	g.encounters.enabled=false
	g.complete_wave()
	check(g.state=="shop","Actual end-wave flow enters preparation")
	for id in S.PARTS: g.economy.inventory[id]=1
	g.economy.gold=500
	equip([["bolt","impact","bloom"],[]])
	g.ui.show_shop()
	await process_frame
	await drag_socket("Socket_0_0","Socket_0_5")
	check(g.draft==["","impact","bloom","","","bolt"],"Native Control drag/drop routes to the exact empty socket")
	equip([["bolt","impact","bloom"],[]])
	var payload: Dictionary=g.board_data("bolt",0,0)
	check(g.board_drop(payload,0,5) and g.draft==["","impact","bloom","","","bolt"],"Exact move to six does not compact any cell")
	check(not g.board_drop(payload,1,4),"Stale drag cannot duplicate the item")
	check(g.board_drop(g.board_data("bolt",0,5),0,2) and g.draft[5]=="bloom" and g.draft[2]=="bolt","Occupied target swaps without moving other cells")
	check(g.board_drop(g.board_data("bolt",0,2),1,4) and g.orb_drafts[0][2]=="" and g.orb_drafts[1][4]=="bolt","Cross-orb move preserves exact coordinates")
	check(g.board_drop(g.board_data("bloom",0,5),1,4) and g.orb_drafts[0][5]=="bolt" and g.orb_drafts[1][4]=="bloom","Cross-orb occupied target swaps both physical items")
	var before: Array=g.orb_drafts.duplicate(true)
	check(g.board_drop(g.board_data("bloom",1,4),-1,0) and g.orb_drafts[1]==S.fixed_slots([]) and g.remaining_part("bloom")==1,"Returning to bag clears only source; no inventory loss")
	g.undo_draft()
	check(g.orb_drafts==before,"Undo restores positions on both orbs")
	check(g.board_drop(g.board_data("frost"),1,5),"New item fills exact target")
	check(g.board_drop(g.board_data("thorn"),1,5) and g.remaining_part("frost")==1 and g.remaining_part("thorn")==0,"Stock replacement returns old item to bag once")
	check(g.board_plan(g.board_data("seek"),1,6).is_empty(),"Invalid seventh cell rejected")
	equip([["bolt","","","","fan"],[]])
	g.ui.show_shop()
	await process_frame
	check(g.valid_draft() and g.orb_compiled[0].size()==1,"Warning permits progression and valid attack execution")
	var bad: Control=find(g.ui.modal,"Socket_0_4")
	check(bad!=null and bad.get_meta("inactive",false) and "5번 칸" in bad.tooltip_text,"Actual UI identifies inactive support and its exact reason")
	check(not find(g.ui.modal,"Socket_0_0").get_meta("invalid",false),"Valid slot stays visually valid")
	check(g.start_trial(),"Partial recipe enters actual trial")
	g.orb_clocks.fill(0.0)
	g._tick_orbs(.001)
	check(not g.projectiles.is_empty() and g.projectiles[0].attack=="bolt","Valid part really fires")
	check(g.board_drop(g.board_data("fan",0,4),0,3),"Trial edits address exact cells")
	g.end_trial()
	check(g.state=="shop" and g.draft[3]=="fan" and g.projectiles.is_empty(),"Trial return preserves edits and cleans attacks")
	check(g.craft_spell("upgrade","bolt","",g.economy.revision),"Equipped attack upgrades despite trailing support warning")
	check(g.draft[0]=="bolt@1" and g.draft[3]=="fan" and g.draft[1]=="","Upgrade preserves all positions and holes")
	var inventory: Dictionary={"storm_spear":1,"impact":1,"fan":1}
	var fused: Array=Forge.reconcile([["","bolt@3","impact","thunder@3","fan",""] ,[]],"bolt@3",{"output":"storm_spear","inventory":inventory},0)
	check(fused[0]==["","storm_spear","","","fan",""] and Forge.valid(fused,inventory),"Fusion clears consumed cells/links without compaction")
	check(not Forge.valid([["bolt","","bolt"],[]],{"bolt":1}),"Duplicate reservations still rejected")
	check(not Forge.valid([["unknown"],[]],{"unknown":1}),"Unknown tokens cannot bypass ownership checks")
	check(g.board_drop(g.board_data("fan",0,3),0,4),"Create reversible sparse edit before saving")
	var saved: Dictionary=Store.capture(g)
	check(Store.valid(saved) and g.checkpoint_store.write(saved),"Actual mirrored save accepts sparse incomplete rows")
	var loaded: Dictionary=g.checkpoint_store.load_data()
	check(not loaded.is_empty() and loaded.orbs==saved.orbs and loaded.drafts==saved.drafts,"JSON round trip retains all empty positions")
	var retained: Array=g.orb_drafts.duplicate(true)
	Store.apply(g,loaded)
	check(g.orb_drafts==retained and g.orb_compiled[0].size()==1,"Restored incomplete program retains valid execution")
	check(g.edit_history.size()==saved.history.size() and not g.edit_history.is_empty(),"Unchanged inventory migration preserves restored undo history")
	g.undo_draft()
	check(g.draft[3]=="fan" and g.draft[4]=="","Undo after restore recovers exact earlier positions")
	var legacy: Dictionary=saved.duplicate(true)
	legacy.erase("orb_growth")
	legacy.orbs=[["bolt@1"],[]]
	legacy.drafts=[["bolt@1","fan"],[]]
	legacy.history=[]
	check(Store.valid(legacy),"Legacy compact save accepted")
	Store.apply(g,legacy)
	check(g.orb_drafts[0]==["bolt@1","fan","","","",""] and g.orb_drafts[1]==S.fixed_slots([]),"Legacy migration pads right without moving contents")
	g.orb_drafts[0][5]="bolt@1"
	g.draft=g.orb_drafts[0].duplicate()
	check(not g.valid_draft(),"Partial syntax permission does not permit ownership duplication")
	equip([[],[]])
	check(g.valid_draft() and g.start_trial(),"All-empty setup may deliberately proceed/test")
	g.end_trial()
	equip([["bolt@1","impact"],[]])
	g.launch_next_wave()
	check(g.state=="combat" and g.orb_compiled[0].size()==1,"Ready allows valid attack plus missing trigger child")
	g.open_editor()
	var elapsed: float=g.elapsed
	g._physics_process(.01)
	check(g.state=="combat" and g.elapsed>elapsed,"Ordinary inventory remains live")
	g.board_drop(g.board_data("bolt@1",0,0),0,5)
	g.board_close()
	check(g.state=="combat" and g.orb_recipes[0][5]=="bolt@1","Combat editing retains rightmost cell after closing")
	g.clear_magic()
	await process_frame
	g.queue_free()
	await process_frame
	for suffix in ["-save.json","-save.json.bak","-save.json.tmp","-save.json.bak.tmp"]:
		if FileAccess.file_exists(PREFIX+suffix): DirAccess.remove_absolute(PREFIX+suffix)
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(1 if failures else 0)
