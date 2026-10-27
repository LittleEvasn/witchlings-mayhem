extends SceneTree
const Spells = preload("res://scripts/spells.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const Economy = preload("res://scripts/economy.gd")
const Forge = preload("res://scripts/spell_forge.gd")
const Meter = preload("res://scripts/combat_meter.gd")
var g: Node2D
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if ok: print("PASS: "+text)
	else:
		failures += 1
		printerr("FAIL: "+text)

func fresh(bank: Array = [["bolt"],[]]) -> void:
	g.start_run()
	g.director.enabled=false
	g.set_physics_process(false)
	g.sound_enabled=false
	g.meter=Meter.new()
	g.economy.inventory={}
	for parts in bank:
		for id in parts: g.economy.inventory[id]=int(g.economy.inventory.get(id,0))+1
	g.orb_recipes=bank.duplicate(true)
	g.orb_drafts=bank.duplicate(true)
	g.active_orb=0
	g.recipe=bank[0].duplicate()
	g.draft=bank[0].duplicate()
	g._commit_live_board()
	g.orb_clocks=[0.0,0.0]
	g.orb_cursors=[0,0]
	g.player.position=Vector2(300,330)
	g.cast_target=Vector2(1100,330)
	g.aim=Vector2.RIGHT

func tick(seconds: float) -> void:
	for i in ceili(seconds*120):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/120)
		g.magic.update_zones(1.0/120)
		g._update_effects(1.0/120)

func totals(id: String) -> float: return g.meter.totals.get(id,0.0)
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	g.set_physics_process(false)
	g.sound_enabled=false
	var basic := Spells.compile(["bolt","bloom"])
	check(basic.ok and Spells.roots(basic.stages).size()==2,"Two unlinked attacks compile as two sequential roots")
	var before := Spells.compile(["fan","bolt","bloom"])
	check(before.ok and before.stages[0].fan==1 and before.stages[1].fan==1,"Prefix modifier affects every right-hand attack")
	var middle := Spells.compile(["bolt","fan","bloom"])
	check(middle.ok and middle.stages[0].fan==0 and middle.stages[1].fan==1,"Middle modifier affects only later attacks")
	var chain := Spells.compile(["fan","bolt","impact","bloom","expire","thunder"])
	check(chain.ok and chain.stages.size()==3 and Spells.roots(chain.stages).size()==1,"Three-stage chain has only one independently scheduled root")
	check(chain.stages[0].next.attack=="bloom" and chain.stages[0].next.next.attack=="thunder","Nested forward event payload preserves both connectors")
	check(chain.stages.all(func(s):return s.fan==1),"Inherited scope does not duplicate a modifier at later stages")
	var mixed := Spells.compile(["bolt","bloom","impact","thunder","frost"])
	check(mixed.ok and Spells.roots(mixed.stages).map(func(s):return s.attack)==["bolt","bloom","frost"],"Independent sequence and event payload coexist")
	var duplicate := Spells.compile(["fan","fan","pierce","pierce","bolt"])
	check(duplicate.ok and duplicate.stages[0].fan==2 and Spells.branches(duplicate.stages[0])==5,"Two fan copies add four branches")
	check(duplicate.stages[0].modifiers.size()==4 and duplicate.stages[0].modifiers[0].rank==0,"Modifier instances retain source slot and rank records")
	for invalid in [["impact","bolt"],["bolt","impact"],["bolt","impact","expire","bloom"],["bolt","fan"],["on_return","bolt"]]:
		var result := Spells.compile(invalid)
		check(not result.ok and result.error_index>=0 and result.stages.is_empty(),"Invalid draft reports its slot and has no executable stale program: "+str(invalid))
	check(Spells.affected_slots(["fan","bolt","fan","impact","bloom"],2)==[4],"A selected duplicate modifier highlights only its own right-hand scope")
	check(Spells.roots(Spells.compile(["bolt","bolt","bolt","bolt","bolt","bolt"]).stages).size()==6,"All six slots can be independent attacks")

	fresh([["bolt","bloom"],["boomerang"]])
	g._tick_orbs(0.001)
	check(g.projectiles.size()==2 and g.projectiles[0].attack=="bolt" and g.projectiles[1].attack=="boomerang","Both orbs launch their own first root")
	g._tick_orbs(0.121)
	check(g.projectiles.size()==3 and g.projectiles.back().attack=="bloom","Second root follows after the sequential gap")
	check(g.orb_cursors==[0,0] and g.orb_clocks[0]>0.5,"Last root begins the distinct cycle cooldown")
	g._tick_orbs(0.5)
	check(g.projectiles.size()==3,"Cycle cooldown does not release the first root early")
	g._tick_orbs(0.08)
	check(totals("orb_0_slot_0")==2 and totals("orb_1_slot_0")==2,"Two orbs independently repeat their sequence")

	fresh([["fan","fan","pierce","pierce","bolt"],[]])
	g._tick_orbs(0.001)
	check(g.projectiles.size()==5 and g.projectiles.all(func(p):return p.pierce==4),"Repeated modifiers affect real projectile count and piercing")
	check(is_equal_approx(g.projectiles[0].damage,22*0.40*0.40),"Fan damage multiplier applies once per equipped copy")
	fresh([["echo","echo","bolt"],[]])
	g._tick_orbs(0.001)
	check(g.magic.echoes.size()==2,"Two repeat copies schedule two delayed casts")
	tick(0.5)
	check(totals("stage_casts")==3 and g.magic.echoes.is_empty(),"Repeat casts do not recursively repeat themselves")
	fresh([["giant","giant","charge","charge","bolt"],[]])
	g._tick_orbs(0.001)
	check(is_equal_approx(g.projectiles[0].damage,198) and is_equal_approx(g.projectiles[0].radius,12.8),"Repeated charge and size modifiers affect real damage and collision size")
	check(is_equal_approx(g.orb_clocks[0],0.48*1.44*6.25),"Repeated cooldown multipliers apply to cycle delay")

	fresh([["bolt","impact","bloom","expire","thunder"],[]])
	var enemy=g.spawn_enemy(1)
	enemy.position=Vector2(420,330)
	enemy.hp=100000
	g._rebuild_grid()
	g._tick_orbs(0.001)
	tick(1.0)
	check(totals("stage_casts")==3 and totals("trigger_impact")==1 and totals("trigger_expire")==1,"Physical hit then normal end executes the full three-stage chain exactly once")
	check(totals("strikes_scheduled")==1 and enemy.hp<100000,"Final lightning actually schedules and damages the target")
	var snapshot: float=totals("triggers")
	g.clear_magic()
	tick(0.5)
	check(totals("triggers")==snapshot,"Forced clear does not trigger an expire payload")
	fresh([["thorn","expire","bolt"],[]])
	g._tick_orbs(0.001)
	g.magic.install(g.projectiles[0])
	g.magic.evict_zone(g.magic.zones[0])
	check(totals("triggers")==0,"Field-cap eviction is forced removal and cannot fire an expire payload")

	fresh([["bolt","impact","bloom"],[]])
	g._tick_orbs(0.001)
	var parent: Dictionary=g.projectiles[0]
	g.magic.trigger(parent,Vector2(500,330))
	g.magic.trigger(parent,Vector2(510,330))
	check(totals("triggers")==1 and totals("stage_casts")==2,"Repeated hit events on one projectile cannot duplicate its payload")
	var child: Dictionary=g.projectiles.back()
	check(child.stage.get("_orb",-1)==0 and child.stage.get("_linked",false),"Linked child retains orb ownership and event-origin targeting")

	fresh([["echo","bolt","expire","thunder"],[]])
	g._tick_orbs(0.001)
	check(not g.magic.echoes.is_empty(),"Cleanup test has a pending repeat")
	g.complete_wave()
	check(g.magic.echoes.is_empty() and g.projectiles.is_empty() and g.magic.behavior.strikes.is_empty(),"Wave end clears delayed casts and attack objects")
	fresh()
	var stage: Dictionary=Spells.compile(["bolt"]).stages[0]
	for i in 70: g.emit_stage(stage,Vector2(300,330),Vector2.RIGHT,{},1.0)
	check(totals("emits_blocked")==6 and g.projectiles.size()==64,"Per-tick emission safety cap is bounded and observable")
	g.magic.begin_tick()
	stage["_depth"]=7
	g.emit_stage(stage,Vector2(300,330),Vector2.RIGHT,{},1.0)
	check(totals("chain_depth_blocked")==1,"Chain-depth cap is observable")

	var examples := [[0,0,1],[1,0,2],[2,0,3],[3,0,4],[1,1,2],[2,1,3],[2,2,4]]
	for example in examples:
		for reverse in [false,true]:
			var a:=Progression.key("bolt",example[1] if reverse else example[0])
			var b:=Progression.key("bolt",example[0] if reverse else example[1])
			var economy:=Economy.new()
			economy.inventory={a:1}
			economy.inventory[b]=int(economy.inventory.get(b,0))+1
			var q:=economy.craft_quote("merge",a,b)
			check(q.ok and Progression.rank(q.output)==example[2] and q.consumed.size()==2,"Symmetric upgrade %s + %s -> +%d"%[a,b,example[2]])
	var economy:=Economy.new()
	economy.inventory={"bolt@3":1,"bolt@2":1}
	economy.gold=100
	var inv:=economy.inventory.duplicate()
	var overflow:=economy.craft("merge","bolt@3","bolt@2",economy.revision)
	check(not overflow.ok and overflow.output_rank==5 and economy.inventory==inv and economy.gold==100,"Over-cap merge previews +5 and consumes neither items nor money")
	for pair in [[0,4],[4,0],[2,3],[4,4]]:
		var a:=Progression.key("bolt",pair[0])
		var b:=Progression.key("bolt",pair[1])
		economy.inventory={a:1}
		economy.inventory[b]=int(economy.inventory.get(b,0))+1
		var previous_inventory:=economy.inventory.duplicate()
		var rejected:=economy.craft("merge",a,b,economy.revision)
		check(not rejected.ok and economy.inventory==previous_inventory and economy.gold==100,"Overflow rejection is atomic for both material orders: "+str(pair))
	economy.inventory={"bolt@2":1,"bolt@3":1}
	check(not economy.craft_quote("merge","bolt@2","bloom").ok,"Different spell types cannot merge")
	var paid:=economy.craft("upgrade","bolt@2","",economy.revision)
	check(paid.ok and paid.output=="bolt@3" and economy.gold==100-paid.cost,"Money upgrade still advances exactly one rank")

	fresh([["bolt@2"],["bolt@2"]])
	g.economy.gold=100
	g.state="shop"
	g.shop_time=60
	check(g.craft_spell("merge","bolt@2","bolt@2",g.economy.revision),"Two equipped +2 copies can merge")
	check(g.economy.inventory=={"bolt@4":1} and g.orb_drafts==[["bolt@4"],[]],"Equipped merge replaces one target and releases the consumed copy across orbs")
	check(g.orb_compiled[0][0].source_id=="bolt@4" and g.orb_compiled[1].is_empty(),"Equipped upgrade immediately updates executable programs")
	check(g.ui.merge_material.is_empty(),"Craft result clears the old material selection")
	check(g.start_trial(),"Upgraded program can enter the firing trial")
	g.orb_clocks=[0.0,0.0]
	g._tick_orbs(0.001)
	check(g.projectiles[0].stage.source_id=="bolt@4","Trial fires the upgraded item")
	var wave_clock:float=g.wave_time
	var shop_clock:float=g.shop_time
	g._physics_process(0.25)
	check(g.wave_time==wave_clock and g.shop_time==shop_clock,"Trial leaves wave and shop clocks frozen")
	g.end_trial()
	check(g.projectiles.is_empty() and g.magic.echoes.is_empty(),"Trial exit clears its attack reservations")

	fresh([["bolt@2"],["bolt@2"]])
	g.economy.inventory["bolt@2"]=3
	g.state="shop"
	g.shop_time=60
	check(g.craft_spell("merge","bolt@2","bolt@2",g.economy.revision) and g.orb_drafts[1]==["bolt@2"],"Spare material is consumed before removing the other orb's equipped copy")
	check(g.Forge.valid(g.orb_drafts,g.economy.inventory) and g.remaining_part("bolt@2")==0,"Post-craft reservations match the inventory exactly")
	var q:Dictionary=g.economy.craft_quote("upgrade","bolt@2")
	check(not q.ok or q.output=="bolt@3","Subsequent quote uses remaining real stock")
	var chain_bank:Array=[["bolt@2","impact","bolt@2","expire","thunder"],[]]
	var merged:=Forge.reconcile(chain_bank,"bolt@2",{"output":"bolt@4","inventory":{"bolt@4":1,"impact":1,"expire":1,"thunder":1}},0)
	check(merged==[["bolt@4","thunder"],[]],"Consuming a middle attack releases adjacent connectors instead of retargeting them")

	fresh([["bolt"],["bloom"]])
	g.economy.inventory["fan"]=2
	g.open_editor()
	check(g.board_drop(g.board_data("fan"),0,0),"Bag modifier inserts without replacing an attack")
	check(g.board_drop(g.board_data("fan"),0,1),"A duplicate modifier can occupy another slot")
	check(g.draft==["fan","fan","bolt"] and g.orb_compiled[0][0].fan==2,"Live edit compiles both modifier copies")
	g.undo_draft()
	check(g.draft==["fan","bolt"] and g.orb_compiled[0][0].fan==1,"Undo restores slots and executable scope")
	g.economy.inventory["impact"]=1
	check(g.board_drop(g.board_data("impact"),0,g.draft.size()),"Unfinished connector may be temporarily placed")
	check(g.orb_compiled[0].is_empty() and not g.orb_compiled[1].is_empty(),"Invalid orb goes silent while the other orb remains executable")
	g.undo_draft()
	check(g.valid_draft(),"Undo repairs the temporary grammar error")
	g.economy.inventory["thunder"]=1
	var old:Array=g.draft.duplicate()
	g.board_quick_equip("thunder")
	check(g.draft==old+["thunder"] and not "impact" in g.draft,"Quick equip adds a sequential attack without inserting a connector")
	var stale:Dictionary=g.board_data("thunder",0,g.draft.size()-1)
	g.undo_draft()
	check(not g.board_drop(stale,1,0),"Stale drag payload cannot duplicate an item")
	var summary:Node=g.ui.modal.find_child("ProgramSummary0",true,false)
	check(summary!=null,"Editor exposes the program summary")
	g.ui.inspect_item("fan",0,0)
	await process_frame
	await process_frame
	var target:Node=g.ui.modal.find_child("Socket_0_1",true,false)
	check(target!=null and target.get_meta("affected",false),"Inspected support highlights its affected attack in the real UI")
	var runner=load("res://scripts/measurement_runner.gd").new(g)
	check(runner.begin(["bolt","bloom"],"single",731,"fixed",2.0),"Existing measurement room accepts a sequential program")
	while runner.active: runner.step()
	var report:Dictionary=runner.report()
	check(report.totals.get("orb_0_slot_0",0)>0 and report.totals.get("orb_0_slot_1",0)>0,"Measurement uses the same sequence scheduler and records both attacks")
	runner.stop()

	var file:=FileAccess.open("res://artifacts/spell-program-test-results.txt",FileAccess.WRITE)
	file.store_string("RESULT: %d checks, %d failures\n"%[checks,failures])
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
