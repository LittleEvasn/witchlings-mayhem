extends SceneTree
const Spells = preload("res://scripts/spells.gd")
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
	else: print("PASS: "+message)
func shop() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled = false
	g.complete_wave()
	g.choose_reward("power")
	g.economy.inventory = {}
	for id in Spells.PARTS: g.economy.inventory[id] = 4
	g.orb_drafts = [[],[]]
	g.draft = []
	g.selected_group = 0
func field() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled = false
	g.player.position = Vector2(500,300)
	g.cast_target = Vector2(620,300)
	g.aim = Vector2.RIGHT
	for i in 5:
		var e: Node2D = g.Actor.new()
		g.actors.add_child(e)
		e.setup(g.art,1)
		e.position = Vector2(600+i*42,300)
		e.hp = 1000000
		e.max_hp = e.hp
		g.enemies.append(e)
	g._rebuild_grid()
func emit(parts: Array, owner_orb := 0) -> void:
	var stages: Array = Spells.compile(parts).stages
	stages[0]["_orb"] = owner_orb
	if stages.size()>1: stages[1]["_orb"] = owner_orb
	g.emit_stage(stages[0],g.player.position,Vector2.RIGHT,stages[1] if stages.size()>1 else {},1)
func advance(seconds: float) -> void:
	for i in int(seconds*60):
		g._rebuild_grid()
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
		g._update_effects(1.0/60)
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	shop()
	g.add_part("bolt")
	g.add_part("fan")
	verify(g.draft==["fan","bolt"],"Attack first, modifier later automatically compiles")
	g.add_part("thunder")
	verify(g.draft==["fan","thunder"],"Replacing attack keeps its modifiers")
	g.focus_group(1)
	g.add_part("vortex")
	g.add_part("graft")
	verify(g.draft==["fan","thunder","impact","graft","vortex"],"Second attack automatically uses owned connector")
	g.swap_groups()
	verify(g.draft==["graft","vortex","impact","fan","thunder"],"Swap moves full attack groups")
	g.move_group_to_other(1)
	verify(g.draft==["graft","vortex"] and g.orb_drafts[1]==["fan","thunder"],"Whole attack group transfers to other orb without losing copies")
	g.undo_draft()
	verify(g.draft.size()==5 and g.orb_drafts[1].is_empty(),"Undo restores BOTH orb allocations")
	g.move_group_to_other(1)
	g.select_orb(1)
	verify(g.draft==["fan","thunder"],"Switching orbs preserves drafts")
	g.economy.inventory.fan = 1
	verify(g.remaining_part("fan")==0,"Inventory reservations span both orbs")
	g.select_orb(0)
	g.add_part("fan")
	verify(not "fan" in g.draft,"Cannot equip the same owned copy twice")
	verify(g.apply_recipe(),"Apply commits both independent recipes")
	verify(g.orb_recipes==[["graft","vortex"],["fan","thunder"]],"Applied state contains both recipes")
	g.start_next_wave()
	g.orb_clocks = [0.01,0.5]
	g.cast_target = Vector2(1000,450)
	g._tick_orbs(0.02)
	verify(g.projectiles.size()==1 and g.magic.behavior.strikes.is_empty(),"Orb one fires without waiting for orb two")
	g._tick_orbs(0.5)
	verify(g.magic.behavior.strikes.size()==1,"Orb two follows its own cadence")
	verify(g.projectiles[0].owner_orb==0 and g.magic.behavior.strikes[0].owner_orb==1,"Attack ownership survives runtime contexts")
	g.open_editor()
	g.clear_group(0)
	g.select_orb(1)
	g.clear_group(0)
	verify(not g.valid_draft(),"Cannot apply a loadout with no attacks in either orb")
	g.cancel_editor()
	verify(not g.orb_drafts[0].is_empty() and not g.orb_drafts[1].is_empty(),"Cancel restores both applied orb recipes")
	shop()
	g.add_part("frost")
	g.select_orb(1)
	g.add_part("shatter")
	g.add_part("bolt")
	verify(g.valid_draft(),"Modifiers before or after attack both work in grouped editing")
	g.orb_clocks = [0.31,0.72]
	var before: Array = g.orb_clocks.duplicate()
	var money: int = g.economy.gold
	var time: float = g.shop_time
	verify(g.start_trial(),"Both orb drafts enter production trial")
	g.orb_clocks = [0,0]
	g._tick_orbs(0.02)
	verify(g.projectiles.size()>0 and g.magic.behavior.flashes.size()>0,"Trial emits both orb spells")
	verify(g.economy.gold==money and g.shop_time==time,"Trial does not advance economy or shop time")
	g.end_trial()
	verify(g.orb_clocks==before and g.projectiles.is_empty() and g.enemies.is_empty(),"Trial restores both clocks and clears effects")
	g.select_orb(1)
	var stale: Dictionary = g.orb_drag_data("echo",-1)
	g.select_orb(0)
	verify(not g.can_drop_group_part(stale,0),"Switching orb rejects drag payload from previous orb")
	g.orb_clocks = [0.01,0.01]
	g.start_trial()
	g.add_part("charge")
	verify(g.apply_recipe(),"Trial can commit a changed two-orb loadout")
	g.end_trial()
	verify(g.orb_clocks[0]>=Spells.interval(g.orb_compiled[0])/g.fire_rate,"Trial exit cannot bypass newly committed charge cadence")
	shop()
	g.add_part("bolt")
	g.focus_group(1)
	g.add_part("bloom")
	g.add_part("fan")
	var drag: Dictionary = g.orb_drag_data("fan",2)
	verify(g.drop_group_part(drag,0) and g.draft==["fan","bolt","impact","bloom"],"Dragging modifier between groups preserves prefix compile order")
	g.select_orb(1)
	g.add_part("frost")
	g.focus_group(1)
	g.add_part("thunder")
	g.select_orb(0)
	var full: Array = g.orb_drafts.duplicate(true)
	g.move_group_to_other(0)
	verify(g.orb_drafts==full,"Transfer to an orb with two attacks rejects without losing items")
	# Every modifier can be selected for every attack and actually executes through the runtime.
	for attack in Spells.ATTACK_INTERVALS:
		for mod in Spells.PARTS:
			if Spells.PARTS[mod].kind!="modifier": continue
			var parts: Array = [mod,attack]
			verify(Spells.compile(parts).ok,"Universal compatibility: "+mod+" / "+attack)
			field()
			for i in 3: emit(parts)
			advance(1.0)
			verify(g.projectiles.size()<=g.MAX_PROJECTILES and g.magic.zones.size()<=24,"Bounded runtime: "+mod+" / "+attack)
	field()
	emit(["graft","bolt"])
	emit(["graft","bolt"])
	verify(g.projectiles.is_empty(),"Non-field graft gathers before releasing")
	emit(["graft","bolt"],1)
	verify(g.projectiles.is_empty(),"Orb two cannot spend orb one's graft charge")
	emit(["graft","bolt"])
	verify(g.projectiles.size()==1 and is_equal_approx(g.projectiles[0].damage,22*3.6),"Third investment releases gathered damage with growth bonus")
	field()
	emit(["graft","vortex"])
	g.projectiles.back().pos = Vector2(700,300)
	g.magic.install(g.projectiles.back())
	emit(["graft","vortex"],1)
	g.projectiles.back().pos = Vector2(700,300)
	g.magic.install(g.projectiles.back())
	verify(g.magic.zones.size()==2,"Different orbs do not accidentally merge planted spells")
	field()
	for i in 3: emit(["frost"])
	var target: Node2D = g.enemies[0]
	verify(g.magic.behavior.state_for(target).frozen_until>g.magic.behavior.clock,"Orb one supplies shared cold state")
	var c: Dictionary = g.magic.behavior.context(Spells.compile(["shatter","bolt"]).stages[0],Vector2.ZERO,Vector2.RIGHT,{},1,1,"primary",false,999,0)
	c.owner_orb = 1
	var hp: float = target.hp
	g.magic.behavior.hit(target,22,Vector2.ZERO,c)
	verify(is_equal_approx(hp-target.hp,52),"Orb two consumes orb one's freeze for shatter")
	field()
	emit(["echo","satellite"])
	advance(0.2)
	verify(g.magic.behavior.orbits.size()==2,"Echo repeats orbit sets instead of being forbidden")
	field()
	emit(["pierce","thunder"])
	advance(0.5)
	verify(g.enemies[2].hp<1000000 and g.enemies[3].hp<1000000 and g.enemies[4].hp==1000000,"Piercing lightning extends to exactly two forward targets beyond its impact area")
	field()
	g.aim = Vector2.LEFT
	var stage: Dictionary = Spells.compile(["seek","frost"]).stages[0]
	g.emit_stage(stage,g.player.position,Vector2.LEFT,{},1)
	verify(g.enemies[0].hp<1000000,"Seeking cone turns toward nearby enemy")
	g.clear_magic()
	verify(g.magic.behavior.gathered.is_empty() and g.magic.behavior.orbits.is_empty(),"Cleanup clears new gathered charges and orbit sets")
	print("RESULT: %d checks / %d failures" % [checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
