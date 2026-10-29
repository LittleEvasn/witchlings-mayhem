extends SceneTree
const Profile=preload("res://scripts/player_profile.gd")
const Store=preload("res://scripts/run_checkpoint.gd")
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+note)
func fresh() -> void:
	g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false
	g.director.enabled=false;g.encounters.enabled=false;g.profile.data.quick_rewards=false
func settle() -> void:
	await process_frame;await process_frame;await process_frame
func node(name: String) -> Control: return g.ui.root.find_child(name,true,false)
func click(name: String) -> void:
	var b: Control=node(name)
	check(b!=null,"Real control exists: "+name)
	if b==null: return
	var at:=b.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
func drag(source: String, destination: String) -> void:
	var a: Vector2=node(source).get_global_rect().get_center()
	var b: Vector2=node(destination).get_global_rect().get_center()
	var event:=InputEventMouseButton.new();event.position=a;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await process_frame
	for point in [a+Vector2(25,4),b]:
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.relative=Vector2(25,4)
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await process_frame
	event=InputEventMouseButton.new();event.position=b;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
	root.push_input(event,true);await settle()
func arm() -> void:
	var gate: Node=g.ui.modal.get_node("RewardInputGate")
	gate.until=0;gate._process(0)
func levelup() -> void:
	g.combat_rewards.gain_xp(g.combat_rewards.required()-g.combat_rewards.xp)
	g.combat_rewards.tick()
func max_spell(id: String) -> void:
	if g.economy.owned_token(id).is_empty(): g.apply_acquisition(g.economy.acquire(id))
	for i in 3: g.apply_acquisition(g.economy.acquire(id))
func run() -> void:
	root.size=Vector2i(1600,900)
	g=load("res://scenes/main.tscn").instantiate();g.record_runs=false
	g.profile=Profile.new("user://compact-rewards-unused.json")
	root.add_child(g);current_scene=g;await settle()
	fresh();g.open_personal("inventory");await settle()
	check(node("CompactInventory")!=null and node("CompactOrb0")!=null,"Ordinary inventory uses horizontal strips")
	check(node("PersonalWindow")==null and not g.combat_rewards.paused(),"No opaque side drawer; ordinary inventory is live")
	var clock: float=g.elapsed
	g._physics_process(.1)
	check(g.elapsed>clock,"Ordinary inventory does not stop combat")
	await drag("Bag_impact","Socket_0_5")
	check(g.orb_drafts[0][5]=="impact" and g.orb_drafts[0][2]=="","Dragging retains exact sparse slot")
	await click("InventoryUndo");await settle()
	check(g.orb_drafts[0][5]=="" and g.remaining_part("impact")==1,"Undo restores bag and empty slot")
	await click("CloseCompactInventory");await settle()
	check(g.personal_tab=="" and node("CompactInventory")==null and g.ui.recipe_bar.visible,"Close folds inventory back to orb badges")
	check(g.ui.controls_hint.visible and g.ui.notice_label.visible,"Closing restores battlefield HUD hints")
	fresh();levelup();await settle()
	check(g.combat_rewards.stage=="choice" and node("LevelChoices").get_child_count()==3,"Normal levelup has3 choices")
	check(node("CompactInventory")!=null and g.editing_recipe(),"Choices and real editable inventory coexist")
	check(node("ResumeRewardCombat").disabled,"Cannot resume with a mandatory pick pending")
	check(not g.combat_rewards.continue_combat(),"Programmatic resume cannot bypass reward")
	clock=g.elapsed;var hp: float=g.hp
	g._physics_process(.3);g.hurt_player(99)
	check(g.elapsed==clock and g.hp==hp,"World/health stay frozen while editing a reward")
	var bank: Array=g.orb_drafts.duplicate(true)
	var options: Array=g.combat_rewards.pending[0].options.duplicate()
	await drag("Socket_0_1","Socket_0_5")
	check(g.orb_drafts[0][1]=="" and g.orb_drafts[0][5]=="bolt","Can edit before choosing")
	check(g.combat_rewards.pending[0].options==options,"Editing preserves offered rewards")
	await click("InventoryUndo");await settle()
	check(g.orb_drafts==bank,"Undo works in paused reward screen")
	# Pick an explicitly new spell through the real button and its release gate.
	g.combat_rewards.pending[0].options=["bloom","bolt","relic:crown"]
	g.combat_rewards.revision+=1;g.ui.show_level_reward();await settle();arm()
	await click("Choose_bloom");await settle()
	check(g.combat_rewards.stage=="edit" and g.combat_rewards.paused(),"Selecting keeps session paused")
	check(node("LevelChoices")==null and node("RewardResults")!=null,"Choice row folds into compact results")
	check(node("CompactInventory")!=null and g.remaining_part("bloom")==1,"New spell is in visible bag, not auto-equipped")
	clock=g.elapsed;g._physics_process(.3);check(g.elapsed==clock,"No combat frame leaks after selection")
	await drag("Bag_bloom","Socket_0_4")
	check(g.orb_drafts[0][4]=="bloom" and g.orb_recipes[0][4]=="bloom","Can equip new spell after selection")
	arm();await click("ResumeRewardCombat");await settle()
	check(not g.combat_rewards.paused() and g.personal_tab=="" and not is_instance_valid(g.ui.modal),"Explicit Resume closes both panels")
	g._physics_process(.1);check(g.elapsed>clock,"Combat actually resumes")
	# Two simultaneously eligible fusions: exactly one, always in the fourth slot.
	fresh()
	for id in ["bolt","thunder","fan","echo"]: max_spell(id)
	levelup();await settle()
	var reward: Dictionary=g.combat_rewards.pending[0]
	check(reward.options.size()==4 and reward.options.slice(0,3).all(func(id):return not id.begins_with("fuse:")),"Three ordinary cards plus fourth fusion")
	check(reward.options.filter(func(id):return id.begins_with("fuse:")).size()==1,"Multiple recipes never add multiple extra cards")
	var fusion: String=reward.options[3]
	check(fusion in ["fuse:storm_spear","fuse:wave_split"],"Fourth card is one eligible actual fusion")
	check(node("LevelChoices").get_child_count()==4,"Four cards are rendered")
	var title: Label=node("AcquisitionCard_"+fusion.replace(":","_")).find_child("RewardName",true,false)
	check(not title.text.is_empty() and title.get_visible_line_count()>0,"Fusion card name is actually visible")
	var saved: Dictionary=Store.capture(g)
	# Save envelopes are preparation-only: supply that fixture's offers/completed record.
	var prep: RefCounted=g.Economy.new();prep.roll(RandomNumberGenerator.new(),[])
	saved.economy.offers=prep.offers.duplicate(true)
	saved.elapsed=360.0;saved.wave_time=360.0
	saved.waves=[{"wave":1,"recipes":saved.orbs.duplicate(true),"seconds":360.0,"kills":0,"earned":0}]
	check(Store.valid(saved),"Checkpoint validator accepts locked fourth fusion")
	check(Store.valid(JSON.parse_string(JSON.stringify(saved))),"Fourth fusion survives JSON types")
	var corrupt: Dictionary=saved.duplicate(true)
	corrupt.rewards.pending[0].options[0]=fusion
	check(not Store.valid(corrupt),"Corrupt repeated/misplaced fusion card rejected")
	corrupt=saved.duplicate(true);corrupt.rewards.pending[0].options=["bloom","thunder","echo","frost"]
	check(not Store.valid(corrupt),"Four ordinary cards cannot masquerade as bonus fusion slot")
	var rng_state: int=g.combat_rewards.rng.state
	for i in 20: g.combat_rewards.refresh_options()
	check(g.combat_rewards.rng.state==rng_state and reward.options[3]==fusion,"Repeated refresh cannot reroll fusion or RNG")
	await drag("Socket_0_1","Socket_0_5")
	check(reward.options[3]==fusion,"Parent relocation cannot reroll fusion")
	var parents: Array=g.Spells.Progression.FUSIONS[fusion.trim_prefix("fuse:")].parents
	var money: int=g.economy.gold
	arm();await click("Choose_"+fusion.replace(":","_"));await settle()
	var result: String=fusion.trim_prefix("fuse:")
	check(g.economy.inventory.get(result,0)==1 and g.economy.fusion_history.count(result)==1,"Levelup fusion really grants once")
	for id in parents: check(g.economy.owned_token(id)=="","Chosen fusion consumes parent "+id)
	check(g.economy.gold==money and g.Forge.valid(g.orb_drafts,g.economy.inventory,g.orb_capacities()),"Levelup fusion is free and preserves valid counts")
	check(not g.claim_spell_reward(reward.id,fusion,g.combat_rewards.revision),"Repeated old click cannot duplicate fusion")
	g.combat_rewards.continue_combat()
	levelup();await settle()
	var declined: Dictionary=g.combat_rewards.pending[0]
	check(declined.options.size()==4,"Other ready fusion remains available next level")
	var untouched: Array=g.Spells.Progression.FUSIONS[str(declined.options[3]).trim_prefix("fuse:")].parents
	var history: Array=g.economy.fusion_history.duplicate()
	check(g.claim_spell_reward(declined.id,declined.options[0],g.combat_rewards.revision),"Ordinary choice is allowed alongside fusion")
	check(g.economy.fusion_history==history and untouched.all(func(id):return g.Spells.Progression.rank(g.economy.owned_token(id))==3),"Declining fusion consumes neither parent nor fusion opportunity")
	g.combat_rewards.continue_combat()
	# Multiple levels remain a single paused session with the edited bank preserved.
	fresh();g.combat_rewards.gain_xp(30);g.combat_rewards.tick();await settle()
	var count: int=g.combat_rewards.pending.size()
	while not g.combat_rewards.pending.is_empty():
		var r: Dictionary=g.combat_rewards.pending[0]
		check(g.claim_spell_reward(r.id,r.options[0],g.combat_rewards.revision),"Queued reward grants once")
		check(g.combat_rewards.paused(),"No gap between queued rewards")
	check(count>=3 and g.combat_rewards.stage=="edit","Last queued pick still waits for Resume")
	await settle();g.combat_rewards.continue_combat()
	# Chest still grants automatically, then exposes the same inventory/editor.
	fresh();g.profile.data.quick_rewards=true;g.combat_rewards.queue_chest();g.combat_rewards.tick();await settle()
	check(g.combat_rewards.stage=="edit" and not g.combat_rewards.last_chest_results.is_empty(),"Quick chest automatically grants then pauses for editing")
	check(node("LevelChoices")==null and node("RewardResults")!=null and node("CompactInventory")!=null,"Chest uses result strip, never3-choice selection")
	var event:=InputEventAction.new();event.action="pause_game";event.pressed=true
	g._unhandled_input(event);check(g.state=="paused","Esc can open pause menu without resuming")
	g.resume_game();await settle()
	check(g.combat_rewards.stage=="edit" and node("CompactInventory")!=null,"Pause menu returns to same editor")
	g.combat_rewards.continue_combat()
	# Four orbs/eight slots and a continuous bag remain inside the viewport and away from choices.
	fresh()
	g.state="shop";g.wave=3;g.elapsed=1080;g.economy.gold=2000
	for i in 3: check(g.workshop_buy("orb",g.economy.revision),"Existing workshop can add orb")
	g.state="combat"
	# Direct fixture capacities: isolate rendering from unrelated purchasing mechanics.
	for i in g.orb_recipes.size():
		g.orb_growth[i].picks={"socket":2};g.orb_growth[i].rank=2;g.orb_upgrades[i]=2
		g.orb_recipes[i].resize(8);g.orb_drafts[i].resize(8)
		for n in 8:
			if g.orb_recipes[i][n]==null: g.orb_recipes[i][n]="";g.orb_drafts[i][n]=""
	g.recipe=g.orb_recipes[0].duplicate();g.draft=g.orb_drafts[0].duplicate()
	for id in g.Economy.PRICES:
		if not g.economy.inventory.has(id): g.economy.inventory[id]=1
	for id in g.Spells.Progression.FUSIONS: g.economy.inventory[id]=1
	levelup();await settle()
	check(node("CompactOrb3")!=null and node("Socket_3_7")!=null,"All four orbs and eight slots render")
	check(node("BagNextPage")==null and node("BagPreviousPage")==null,"No bag pagination")
	var bag_scroll: ScrollContainer=node("BagScroll")
	check(bag_scroll!=null,"One continuous long bag")
	for id in g.economy.inventory:
		if g.remaining_part(id)>0: check(node("Bag_"+id)!=null,"Every spare spell exists in continuous bag "+id)
	bag_scroll.scroll_horizontal=200
	await settle()
	check(bag_scroll.scroll_horizontal>0,"Overflow can scroll without changing inventory pages")
	var last_spare: String=""
	for id in g.economy.inventory:
		if g.remaining_part(id)>0: last_spare=id
	bag_scroll.reveal(node("Bag_"+last_spare));await settle()
	await drag("Bag_"+last_spare,"Socket_3_7")
	check(g.orb_drafts[3][7]==last_spare,"Can drag far end of continuous bag to exact orb slot")
	for size in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(1066,600)]:
		root.size=size;await settle();g.ui.show_level_reward();await settle()
		var inventory: Rect2=node("CompactInventory").get_global_rect()
		var choices: Rect2=node("LevelChoices").get_global_rect()
		# Godot canvas_items keeps1600x900 logical coordinates when the physical window shrinks.
		var visible: Vector2=root.get_visible_rect().size
		check(inventory.position.x>=0 and inventory.end.x<=visible.x,"Inventory stays in viewport "+str(size))
		check(inventory.position.y<=13 and inventory.end.y<choices.position.y,"Inventory and cards do not overlap "+str(size))
		check(node("AcquisitionCard_"+g.combat_rewards.pending[0].options[0].replace(":","_")).size.y>=398,"Tall reward cards retained")
		check(not inventory.intersects(g.ui.health_group.get_global_rect()) and g.ui.health_group.get_global_rect().position.y>=visible.y-90,"Health at lower right, outside editor")
		check(g.ui.time_label.get_global_rect().position.y>=visible.y-90,"Clock at bottom")
		check(not g.ui.pause_button.visible,"Pause button replaced by Resume during rewards")
		check(choices.end.y<=visible.y-48 and node("ResumeRewardCombat").get_global_rect().end.y<=visible.y,"Cards and Resume fit "+str(size))
	g.queue_free();await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
