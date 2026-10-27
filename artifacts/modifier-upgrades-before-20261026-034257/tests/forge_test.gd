extends SceneTree
const Spells = preload("res://scripts/spells.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const Economy = preload("res://scripts/economy.gd")
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
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
	g.economy.gold = 500
func equip(bank: Array) -> void:
	g.active_orb = 0
	g.orb_recipes = bank.duplicate(true)
	g.orb_drafts = bank.duplicate(true)
	g.recipe = bank[0].duplicate()
	g.draft = bank[0].duplicate()
	for i in 2: g.orb_compiled[i] = Spells.compile(bank[i]).stages if not bank[i].is_empty() else []
	g.compiled = g.orb_compiled[0]
func field() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled = false
	g.player.position = Vector2(500,300)
	g.cast_target = Vector2(630,300)
	g.aim = Vector2.RIGHT
	for i in 8:
		var e: Node2D = g.Actor.new()
		g.actors.add_child(e)
		e.setup(g.art,1)
		e.position = Vector2(600+i*24,300)
		e.hp = 1000000
		e.max_hp = e.hp
		g.enemies.append(e)
	g._rebuild_grid()
func emit(parts: Array) -> void:
	var result := Spells.compile(parts)
	check(result.ok,"Compile "+str(parts))
	if result.ok: g.emit_stage(result.stages[0],g.player.position,Vector2.RIGHT,Spells.follow(result.stages[0]),1)
func advance(seconds: float) -> void:
	for i in ceili(seconds*60):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
		g._update_effects(1.0/60)
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	for id in Spells.ATTACK_INTERVALS:
		for level in range(5):
			var token := Progression.key(id,level)
			var parsed := Spells.compile(["fan",token])
			check(parsed.ok and parsed.stages[0].attack==id and is_equal_approx(parsed.stages[0].rank_power,1+level*0.2),"Ranked copy compiles: "+token)
	for token in ["bolt@5","bolt@-1","bolt@01","bolt@1@1","fan@1","garbage@4"]:
		check(not Spells.compile([token]).ok,"Reject noncanonical or unsupported rank "+token)
	for id in Progression.FUSIONS:
		var f: Dictionary = Progression.FUSIONS[id]
		check(Progression.fusion_for(f.parents[0]+"@4",f.parents[1]+"@4")==id and Progression.fusion_for(f.parents[1]+"@4",f.parents[0]+"@4")==id,"Fusion order independent: "+id)
		for mod in Spells.PARTS:
			if Spells.PARTS[mod].kind=="modifier": check(Spells.compile([mod,id]).ok,"Fusion accepts modifier "+id+" / "+mod)
	check(Spells.compile(["moon_ring","expire","bolt@4"]).ok,"Evolved returning spell uses the shared normal-end connector")
	shop()
	g.economy.inventory = {"bolt":2,"fan":1,"impact":1}
	equip([["fan","bolt"],["bolt"]])
	var old_revision: int = g.economy.revision
	var old_gold: int = g.economy.gold
	check(g.craft_spell("merge","bolt","",old_revision),"Two equipped copies merge atomically")
	check(g.economy.inventory.get("bolt",0)==0 and g.economy.inventory.get("bolt@1",0)==1 and g.economy.gold==old_gold,"Duplicate merge consumes two and creates one without money")
	check(g.orb_recipes==[["fan","bolt@1"],[]] and g.orb_drafts==g.orb_recipes,"Target slot upgrades, consumed second slot clears, support retained")
	check(not g.craft_spell("merge","bolt","",old_revision),"Stale craft click cannot repeat transaction")
	var stale: Dictionary = g.orb_drag_data("bolt@1",1)
	for level in range(1,4):
		var target := Progression.key("bolt",level)
		var cost := Progression.paid_cost(8,level)
		old_gold = g.economy.gold
		check(g.craft_spell("upgrade",target,"",g.economy.revision) and g.economy.gold==old_gold-cost,"Paid upgrade to +%d uses quoted money" % (level+1))
	check(g.orb_recipes[0]==["fan","bolt@4"] and g.edit_history.is_empty(),"Equipped upgrades persist and consumed items cannot return through Undo")
	check(not g.can_drop_group_part(stale,0),"Craft invalidates old drag payload")
	var before: Dictionary = g.economy.inventory.duplicate()
	old_gold = g.economy.gold
	check(not g.craft_spell("upgrade","bolt@4","",g.economy.revision) and before==g.economy.inventory and old_gold==g.economy.gold,"Max-rank rejection changes no inventory or money")
	g.economy.inventory["thunder@4"] = 1
	equip([["fan","bolt@4"],["thunder@4"]])
	check(g.craft_spell("fuse","bolt@4","thunder@4",g.economy.revision),"Two +4 attacks fuse")
	check(g.orb_recipes==[["fan","storm_spear"],[]] and g.economy.inventory.get("storm_spear",0)==1 and g.economy.gold==old_gold-12,"Fusion keeps target supports and consumes both individual ingredients")
	check(g.start_trial(),"Fused recipe enters actual trial")
	var money: int = g.economy.gold
	check(not g.craft_spell("upgrade","storm_spear","",g.economy.revision) and g.economy.gold==money,"Cannot craft during trial")
	g.end_trial()
	g.shop_time = 0.01
	g._physics_process(0.02)
	check(g.state=="shop" and g.orb_recipes[0]==["fan","storm_spear"],"Preparation never expires and retains confirmed fusion")
	g.launch_next_wave()
	check(g.state=="combat" and g.orb_recipes[0]==["fan","storm_spear"],"Ready launches with confirmed fusion")
	shop()
	g.economy.gold = 0
	before = g.economy.inventory.duplicate()
	check(not g.craft_spell("upgrade","bolt","",g.economy.revision) and before==g.economy.inventory and g.economy.gold==0,"Insufficient currency transaction is atomic")
	g.economy.gold = 100
	g.economy.inventory={"bolt":1,"bolt@1":1}
	equip([["bolt"],[]])
	check(g.craft_spell("merge","bolt","bolt@1",g.economy.revision) and g.economy.inventory.get("bolt@2",0)==1,"Base target and ranked material follow the symmetric +1 rule")
	g.economy.inventory={"bolt":1,"bolt@1":1}
	equip([["bolt@1"],[]])
	check(g.craft_spell("merge","bolt@1","bolt",g.economy.revision) and g.economy.inventory.get("bolt@2",0)==1,"Reversing base/ranked roles produces the same rank")
	check(not g.craft_spell("fuse","bolt","thunder",g.economy.revision),"Unupgraded fusion rejected")
	g.economy.inventory["fan"]=1
	g.draft=["fan"]
	g._draft_changed()
	check(g.craft_spell("upgrade","bolt@2","",g.economy.revision) and g.draft==["fan"] and g.orb_compiled[0].is_empty(),"Crafting a bag item preserves an unfinished, silent live draft")
	shop()
	g.economy.inventory = {"bolt":6,"bolt@1":6}
	check(not g.economy.can_stock("bolt"),"Shop cap counts twelve copies across all ranks")
	check(g.economy.craft("merge","bolt","",g.economy.revision).ok and g.economy.can_stock("bolt"),"Merging frees capacity to buy ingredients again")
	# One attainable path within unchanged pre-boss income, not a free test grant.
	var economy := Economy.new()
	var budget := 0
	for wave in range(1,5): budget += int(g.Waves.config(wave).drop_budget)+Economy.CLEAR_REWARD
	var cost := Economy.investment_cost("storm_spear")-Economy.PRICES.bolt
	check(cost<=budget-40,"Storm fusion leaves at least 40 G within pre-boss income ceiling")
	print("ECONOMY: storm fusion paid route %d G; drop+clear ceiling %d G; remainder %d G" % [cost,budget,budget-cost])
	field()
	emit(["bolt@4"])
	check(is_equal_approx(g.projectiles[0].damage,39.6),"+4 produces 1.8x actual base projectile damage")
	var snapshot: float = g.projectiles[0].damage
	g.economy.inventory["bolt"] = 1
	check(is_equal_approx(g.projectiles[0].damage,snapshot),"Existing projectile retains rank snapshot")
	field()
	emit(["storm_spear"])
	advance(0.22)
	check(g.magic.behavior.strikes.size()==1,"Storm spear schedules one lightning despite intrinsic pierce")
	advance(0.5)
	check(g.enemies[0].hp<1000000 and g.magic.behavior.strikes.is_empty(),"Fusion lightning resolves actual damage")
	field()
	emit(["nova_garden"])
	advance(0.6)
	check(not g.magic.zones.is_empty(),"Nova creates an actual pulling field")
	var health: float = g.enemies[0].hp
	for z in g.magic.zones: z.life = 0.01
	advance(0.02)
	check(g.enemies[0].hp<health-40 and g.magic.zones.is_empty(),"Nova explodes on natural expiry")
	field()
	emit(["moon_ring"])
	advance(1.5)
	check(not g.magic.behavior.orbits.is_empty(),"Returning moon creates a defensive satellite")
	field()
	emit(["frost_blossom"])
	advance(0.9)
	var frozen := false
	for s in g.magic.behavior.statuses.values(): frozen = frozen or s.frozen_until>g.magic.behavior.clock
	check(frozen,"Ice trap actually freezes affected enemies")
	field()
	g.enemies[0].position = g.player.position
	g._rebuild_grid()
	emit(["firework_trail"])
	advance(0.32)
	var first_damage: float = 1000000-g.enemies[0].hp
	advance(0.32)
	var second_damage: float = 1000000-g.enemies[0].hp-first_damage
	check(first_damage>40 and second_damage<10,"Each fire trail patch bursts only once, then ticks normally")
	# Bounded complex cases through production runtime, no exhaustive unrelated sweep.
	for id in Progression.FUSIONS:
		field()
		for i in 12: emit(["fan","echo",id,"impact","bolt@4"])
		advance(3)
		check(g.projectiles.size()<=g.MAX_PROJECTILES and g.magic.zones.size()<=24 and g.magic.echoes.size()<=32 and g.magic.behavior.strikes.size()<=32,"Fusion fan/echo/connector stays bounded: "+id)
	g.clear_magic()
	check(g.projectiles.is_empty() and g.magic.zones.is_empty() and g.magic.echoes.is_empty() and g.magic.behavior.orbits.is_empty(),"Cleanup removes evolved spells")
	g.start_run("sigil")
	check(not g.economy.inventory.has("storm_spear") and g.shop_tab=="shop" and g.forge_target.is_empty(),"New run resets upgrades, fusions and forge selection")
	print("RESULT: %d checks / %d failures" % [checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
