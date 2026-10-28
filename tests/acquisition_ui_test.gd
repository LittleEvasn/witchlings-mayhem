extends SceneTree
const Auto=preload("res://scripts/auto_equip.gd")
const View=preload("res://scripts/acquisition_view.gd")
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func bank(rows: Array) -> void:
	g.active_orb=0
	g.orb_recipes=S.fixed_bank(rows)
	g.orb_drafts=g.orb_recipes.duplicate(true)
	g.orb_growth=[]
	g.orb_upgrades=[]
	g.orb_compiled=[]
	g.orb_trial=[]
	g.orb_clocks=[]
	g.orb_cursors=[]
	for row in rows:
		g.orb_growth.append(g.OrbGrowth.fresh())
		g.orb_upgrades.append(0)
		g.orb_compiled.append(S.compile(row).stages)
		g.orb_trial.append([])
		g.orb_clocks.append(0.0)
		g.orb_cursors.append(0)
	g.recipe=g.orb_recipes[0].duplicate()
	g.draft=g.orb_drafts[0].duplicate()
	g.compiled=g.orb_compiled[0]
	g.economy.inventory={}
	for row in rows:
		for id in row:
			if id!="": g.economy.inventory[id]=1
func choice(options: Array, source := "level") -> void:
	var r: RefCounted=g.combat_rewards
	r.pending=[{"id":"test:%d"%r.revision,"level":2,"source":source,"options":options}]
	r.stage="choice"
	r.bag_only=false
	r.revision+=1
	g.ui.show_level_reward()
func click(name: String) -> void:
	var b: Control=g.ui.modal.find_child(name,true,false)
	var at:=b.get_global_rect().get_center()
	var event:=InputEventMouseButton.new()
	event.position=at
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	root.push_input(event,true)
	await process_frame
	var up:=event.duplicate()
	up.pressed=false
	root.push_input(up,true)
	await process_frame
func run() -> void:
	root.size=Vector2i(1600,900)
	check(Auto.safe(["","bolt","","","",""],"fan",0),"Modifier applies to right-hand attack")
	check(not Auto.safe(["bolt","","","","",""],"fan",5),"Unused modifier never auto-installs")
	check(Auto.safe(["bolt","","bloom","","",""],"impact",1),"Connector joins valid independent attacks")
	check(not Auto.safe(["bolt","","impact","bloom","",""],"expire",1),"Do not form double connector")
	check(not Auto.safe(["bolt","","impact","bloom","",""],"thunder",1),"Do not retarget existing child by inserting attack before edge")
	check(not Auto.safe(["bolt","impact","","bloom","",""],"thunder",2),"Do not replace existing event payload")
	check(not Auto.safe(["","impact","bolt","","",""],"bloom",0),"Do not turn a valid independent attack into a child")
	check(not Auto.safe(["bolt","impact","expire","bloom","",""],"fan",4),"Do not enable unused modifier on broken chain")
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	g.profile=Profile.new("user://acquisition-ui-test-profile.json")
	root.add_child(g)
	current_scene=g
	await process_frame
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	bank([["bolt"],[]])
	var preview:=View.model(g,"bloom")
	check(preview.placement.orb==1 and preview.placement.slot==0 and preview.type=="new","New attack preview prefers empty orb")
	var r: Dictionary=g.economy.acquire("bloom")
	g.apply_acquisition(r)
	check(g.orb_drafts[1][0]=="bloom" and g.orb_recipes[1][0]=="bloom" and g.remaining_part("bloom")==0,"New spell acquired once and auto-equipped in predicted position")
	check(g.orb_drafts[0][0]=="bolt" and g.orb_drafts[0][1]=="","Original positions unchanged")
	r=g.economy.acquire("bloom")
	g.apply_acquisition(r)
	check(g.orb_drafts[1][0]=="bloom@1" and g.orb_drafts[1].count("bloom@1")==1,"Upgrade changes same actual token in place")
	check(r.placement.orb==1 and "강화" in r.placement.text,"Upgrade receipt reports original position")
	bank([["bolt","","","","",""],[]])
	g.profile.data.auto_equip=false
	r=g.economy.acquire("bloom")
	g.apply_acquisition(r)
	check(g.remaining_part("bloom")==1 and not S.has_content(g.orb_drafts[1]),"Global automatic equip off keeps bag")
	g.profile.data.auto_equip=true
	r=g.economy.acquire("thorn")
	g.apply_acquisition(r,true)
	check(g.remaining_part("thorn")==1,"Per-choice bag-only overrides global auto on")
	bank([["bolt","bloom","thunder","vortex","frost","satellite"]])
	r=g.economy.acquire("thorn")
	g.apply_acquisition(r)
	check(g.remaining_part("thorn")==1 and r.placement.orb==-1,"Full orb never replaces existing item")
	bank([["bolt","","bloom"]])
	var edge:=Auto.plan(g.orb_drafts,g.orb_recipes,"impact")
	check(edge.slot==1,"Connector preview identifies only useful gap")
	bank([["bolt@3","","impact","thunder@3"]])
	var fused:=View.model(g,"fuse:storm_spear","chest")
	check(fused.type=="fusion" and "+3" in fused.compare,"Fusion card identifies both consumed parents")
	check(g.claim_fusion("storm_spear") and g.orb_drafts[0][0]=="storm_spear" and g.orb_drafts[0][3]=="","Fusion uses front parent and leaves consumed slot empty")
	g.economy.fusion_history.clear()
	bank([["bolt@3","","impact","thunder@3"]])
	check(g.claim_fusion("storm_spear",true) and g.remaining_part("storm_spear")==1 and g.equipped_count("storm_spear")==0,"Bag-only fusion consumes parents once without auto-installing result")
	g.economy.fusion_history.clear()
	bank([["bloom","impact","bolt@3","thorn"]])
	g.economy.inventory["thunder@3"]=1
	check(g.claim_fusion("storm_spear",true),"Bag-only fusion with attached source edge succeeds")
	check(g.orb_drafts[0][1]=="" and S.roots(S.compile(g.orb_drafts[0]).stages).map(func(s):return s.attack)==["bloom","thorn"],"Removing fused parent also removes old event edge; unrelated attack stays independent")
	g.economy.fusion_history.clear()
	bank([["bolt@3","","impact","thunder@3"]])
	g.orb_drafts=[S.fixed_slots([])]
	g.draft=g.orb_drafts[0].duplicate()
	var plan: Dictionary=g.fusion_placement("storm_spear")
	check(plan.ok and g.claim_fusion("storm_spear") and g.Forge.valid(g.orb_recipes,g.economy.inventory) and g.Forge.valid(g.orb_drafts,g.economy.inventory),"Divergent edited/applied fusion cannot duplicate output")
	check(g.orb_drafts[plan.placement.orb][plan.placement.slot]=="storm_spear","Fusion preview uses same transaction plan as receipt")
	bank([["bolt"]])
	choice(["bolt","bloom","relic:crown"])
	check(g.ui.modal.find_child("RewardKind",true,false)!=null and g.ui.modal.find_child("RewardOrbSummary",true,false)!=null,"Choice UI contains role badges and real orb summary")
	var gate: Node=g.ui.modal.get_node("RewardInputGate")
	check(not gate.allow(),"Fresh reward cannot consume held combat input")
	gate.until=0 # deterministic time boundary; real elapsed/input also checked in rendered game
	await process_frame
	check(gate.allow(),"Release/time guard arms reward input")
	var pause_event:=InputEventAction.new()
	pause_event.action="pause_game"
	pause_event.pressed=true
	g._unhandled_input(pause_event)
	check(g.state=="paused" and g.combat_rewards.stage=="choice","Esc preserves pending choice")
	g.resume_game()
	check(g.state=="combat" and g.combat_rewards.stage=="choice" and g.ui.modal.find_child("LevelChoices",true,false)!=null,"Resume restores exact choice UI")
	var start: float=g.elapsed
	var hp: float=g.hp
	g._physics_process(.5)
	g.hurt_player(5)
	check(g.elapsed==start and g.hp==hp and not g.cast_spell(),"Choice stops combat time, damage and casts")
	var reward_id: String=g.combat_rewards.pending[0].id
	var revision: int=g.combat_rewards.revision
	check(g.claim_spell_reward(reward_id,"bloom",revision),"Production choice transaction accepted")
	check(not g.claim_spell_reward(reward_id,"bloom",revision),"Duplicate/stale choice cannot grant twice")
	await process_frame
	check(g.combat_rewards.stage=="ready" and g.combat_rewards.paused(),"Receipt remains paused until Continue/edit")
	check(g.ui.modal.find_child("AcquisitionReceipt",true,false)!=null,"Actual receipt UI displayed")
	g.combat_rewards.edit()
	await process_frame
	check(g.combat_rewards.stage=="edit" and g.personal_tab=="inventory","Reward editing is optional and paused")
	g.close_personal()
	await process_frame
	g.combat_rewards.continue_combat()
	check(not g.combat_rewards.paused(),"Continue releases reward pause")
	g.open_personal("inventory")
	check(not g.combat_rewards.paused(),"Ordinary inventory does not pause")
	g.close_personal()
	# Queued choices must remain a single pause, including the frame between receipts.
	bank([["bolt"]])
	choice(["bloom","bolt","relic:crown"])
	g.combat_rewards.pending.append({"id":"queued:second","source":"level","level":3,"options":["thorn","bolt","relic:crown"]})
	check(g.claim_spell_reward(g.combat_rewards.pending[0].id,"bloom",g.combat_rewards.revision),"First queued reward grants once")
	var queued_time: float=g.elapsed
	g.combat_rewards.continue_combat()
	g._physics_process(.5)
	check(g.combat_rewards.stage=="choice" and g.elapsed==queued_time and g.combat_rewards.pending[0].id=="queued:second","Next queued choice opens without a combat frame")
	g.combat_rewards.pending=[]
	g.combat_rewards.stage=""
	g.combat_rewards.queue_chest()
	g.combat_rewards.tick()
	await process_frame
	check(g.combat_rewards.stage=="chest" and g.ui.modal.find_child("OpenRewardChest",true,false)!=null,"Chest starts at opening screen")
	check(not g.claim_spell_reward(g.combat_rewards.pending[0].id,"bolt",g.combat_rewards.revision),"Cannot claim before chest reveal")
	# Headless simulation timers can advance faster than the real-time input gate.
	await process_frame
	await process_frame
	g.ui.modal.get_node("RewardInputGate").until=0
	await process_frame
	await click("OpenRewardChest")
	check(g.combat_rewards.stage=="opening","Actual chest button opens animation")
	await create_timer(.86).timeout
	check(g.combat_rewards.stage=="choice" and g.ui.modal.find_child("LevelChoices",true,false)!=null,"Chest animation reveals actual choices")
	var first: Dictionary=g.combat_rewards.pending[0]
	check(first.options.all(func(id):return id in ["gold","heal"] or id.begins_with("fuse:") or not g.economy.owned_token(id).is_empty()),"Chest keeps owned-only upgrade/fusion policy")
	g.profile.data.quick_rewards=true
	check(g.claim_spell_reward(first.id,first.options[0],g.combat_rewards.revision),"Quick reward still uses one transaction")
	await create_timer(.35).timeout
	check(not g.combat_rewards.paused(),"Quick receipt resumes without mandatory editor")
	g.combat_rewards.queue_chest()
	g.combat_rewards.tick()
	check(g.combat_rewards.stage=="choice","Quick mode skips opening")
	var crown:=View.model(g,"relic:crown")
	check("20%" in crown.change and crown.type=="relic","Relic drawback remains on main card")
	g.combat_rewards.stage=""
	g.combat_rewards.pending=[]
	g.state="shop"
	g.economy.gold=1000
	g.economy.roll(g.rng,g.recipe)
	g.ui.craft_tab="craft"
	g.ui.show_shop()
	check(g.ui.modal.find_child("CraftAutoEquip",true,false)!=null,"Crafting exposes auto-equip preference")
	g.ui.show_settings(true)
	check(g.ui.modal.find_child("AutoEquipSetting",true,false)!=null,"Setting accessible outside reward")
	check(g.profile.save_profile(),"Preferences save")
	var loaded:=Profile.new(g.profile.path)
	loaded.load_profile()
	check(loaded.data.auto_equip and loaded.data.quick_rewards,"Preferences survive disk round trip")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(g.profile.path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(g.profile.path+suffix))
	g.queue_free()
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
