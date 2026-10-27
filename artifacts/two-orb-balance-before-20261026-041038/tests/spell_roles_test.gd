extends SceneTree
const Spells = preload("res://scripts/spells.gd")
const Economy = preload("res://scripts/economy.gd")
const Migration = preload("res://scripts/spell_role_migration.gd")
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

func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.director.enabled=false
	g.meter=Meter.new()
	g.player.position=Vector2(300,330)
	g.cast_target=Vector2(420,330)
	g.aim=Vector2.RIGHT

func enemy(at: Vector2) -> Node2D:
	var e=g.spawn_enemy(1)
	e.position=at
	e.hp=10000
	e.max_hp=e.hp
	g._rebuild_grid()
	return e

func total(id: String) -> float: return float(g.meter.totals.get(id,0))
func ctx(parts: Array, power := 1.0) -> Dictionary:
	var stage: Dictionary=Spells.compile(parts).stages[0]
	g.magic.behavior.cast_serial+=1
	return g.magic.behavior.context(stage,g.player.position,Vector2.RIGHT,Spells.follow(stage),1.0,power,"primary",false,g.magic.behavior.cast_serial,g.magic.generation)

func emit(parts: Array, at := Vector2(300,330)) -> void:
	var stage: Dictionary=Spells.compile(parts).stages[0]
	g.magic.begin_tick()
	g.emit_stage(stage,at,Vector2.RIGHT,Spells.follow(stage),1)

func plant(parts: Array, at := Vector2(500,330), orb := 0, factor := 1.0, lineage := -1, slot := -1) -> Dictionary:
	var stage: Dictionary=Spells.compile(parts).stages[0].duplicate(true)
	stage["_orb"]=orb
	if slot>=0: stage.slot=slot
	g.magic.begin_tick()
	g.magic.emit(stage,at,Vector2.RIGHT,Spells.follow(stage),factor,1,"primary",false,lineage)
	var p: Dictionary=g.projectiles.back()
	g.magic.install(p)
	g.projectiles.erase(p)
	return g.magic.zones.back()

func tick(seconds: float) -> void:
	for i in ceili(seconds*120):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/120)
		g.magic.update_zones(1.0/120)
		g._update_effects(1.0/120)

func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	check(Spells.PARTS.values().filter(func(d):return d.kind=="attack").size()==9,"All nine basic attacks remain")
	check(Spells.STACK_RULES.size()==8 and Spells.PARTS.values().filter(func(d):return d.kind=="connector").size()==2,"Eight supports and two common connectors")
	for id in ["graft","shatter","on_return"]:
		check(not Spells.has_part(id) and not Economy.PRICES.has(id) and not g.economy.can_stock(id),"Retired token is unavailable in active catalog, research and shop: "+id)
	check(Spells.definition("bounce").name=="연쇄","Bounce token retains identity with chain display name")
	for kit in Economy.KITS:
		g.start_run(kit)
		g.set_physics_process(false)
		check(Spells.compile(g.recipe).ok and g.economy.owns_recipe(g.recipe),"Starting kit is executable and owns every equipped item: "+kit)
	var rng:=RandomNumberGenerator.new()
	rng.seed=731
	var clean:=true
	for i in 10:
		g.economy.roll(rng,g.recipe)
		for offer in g.economy.offers:
			clean=clean and not offer.id in ["graft","shatter","on_return"]
	check(clean,"Shop generation never offers retired roles")

	fresh()
	g.economy.inventory={"graft":2,"shatter":1,"vortex":1,"bolt":2,"boomerang":1,"expire":1,"on_return":2}
	g.economy.gold=7
	g.orb_recipes=[["graft","vortex","expire","shatter","bolt"],["boomerang","on_return","bolt"]]
	g.orb_drafts=g.orb_recipes.duplicate(true)
	g.edit_history=[{"drafts":g.orb_recipes.duplicate(true)}]
	g.economy.offers=[{"id":"shatter","sold":false},{"id":"on_return","sold":false}]
	check(g.migrate_spell_roles(),"Live migration accepts reserved inventory in both orbs")
	check(g.economy.gold==61 and not g.economy.inventory.has("graft") and g.economy.inventory.expire==3,"Refund counts owned items once and combines return/end stock")
	check(g.orb_recipes==[["vortex","expire","bolt"],["boomerang","expire","bolt"]],"Migration preserves attack order and connector targets")
	check(g.edit_history.is_empty() and g.ui.selected_item.is_empty() and g.role_migration_receipt.refund==54,"Migration clears stale UI/Undo and records refund")
	check(g.economy.offers[0].sold and g.economy.offers[1].id=="expire","Existing offers are retired or converted")
	check(not g.migrate_spell_roles() and g.economy.gold==61,"Repeated migration cannot refund twice")
	check(Migration.recipe(["graft","bolt","on_return","bloom","shatter"])==["bolt","expire","bloom"],"Imported legacy recipe normalization preserves its program")
	fresh()
	g.economy.offers=[{"id":"graft","sold":false}]
	check(g.migrate_spell_roles() and g.economy.offers[0].sold and g.economy.gold==0,"Legacy offers alone are cleaned without inventing refund money")
	fresh()
	g.economy.inventory={"graft":1,"bolt":1}
	g.orb_recipes=[["graft","bolt"],["bolt"]]
	g.orb_drafts=g.orb_recipes.duplicate(true)
	var before: Dictionary=g.economy.inventory.duplicate()
	check(not g.migrate_spell_roles() and g.economy.inventory==before and g.economy.gold==0,"Invalid reservation migration is atomic and preserves originals")

	fresh()
	var e=enemy(Vector2(420,330))
	var cold:=ctx(["frost"])
	for i in 3: g.magic.behavior.hit(e,10,Vector2.ZERO,cold,1)
	var state: Dictionary=g.magic.behavior.state_for(e)
	check(state.frozen_until>g.magic.behavior.clock and total("shatters")==0,"Cold freezes naturally without a shatter orb or same-hit shatter")
	g.magic.behavior.hit(e,10,Vector2.ZERO,cold,1)
	check(total("shatters")==0,"Further cold preserves the frozen shell")
	var direct:=ctx(["bolt"])
	direct.owner_orb=1
	var health: float=e.hp
	g.magic.behavior.hit(e,22,Vector2.RIGHT,direct)
	check(is_equal_approx(health-e.hp,42) and total("shatters")==1,"Other orb's direct hit adds the base 20 shell damage")
	check(state.frozen_until==0 and state.cold==0 and state.immune_until>g.magic.behavior.clock,"Breaking a shell trades away freeze and starts immunity")
	g.magic.behavior.hit(e,22,Vector2.RIGHT,direct)
	check(total("shatters")==1,"A shell cannot shatter twice")
	for i in 4: g.magic.behavior.hit(e,10,Vector2.ZERO,cold,1)
	check(state.frozen_until==0 and state.cold<=2,"Immunity prevents immediate refreeze")

	fresh()
	e=enemy(Vector2(420,330))
	var weak:=ctx(["frost"])
	var strong:=ctx(["frost@4"],2)
	g.magic.behavior.hit(e,10,Vector2.ZERO,weak,1)
	g.magic.behavior.hit(e,10,Vector2.ZERO,strong,2)
	state=g.magic.behavior.state_for(e)
	check(is_equal_approx(state.shell_power,(1+2*3.6)/3),"Shell stores cold-weighted power times rank, not independent averages")
	var secondary:=ctx(["bolt"])
	secondary.hit_origin="chain"
	g.magic.behavior.hit(e,5,Vector2.ZERO,secondary)
	check(total("shatters")==0 and state.frozen_until>g.magic.behavior.clock,"Chain secondary damage cannot consume a shell")
	secondary.hit_origin="internal"
	g.magic.behavior.hit(e,5,Vector2.ZERO,secondary)
	check(total("shatters")==0,"Intrinsic fusion secondary damage cannot consume a shell")
	health=e.hp
	g.magic.behavior.hit(e,1,Vector2.ZERO,ctx(["charge","bolt"],99))
	check(is_equal_approx(health-e.hp,1+20*(1+2*3.6)/3),"Finishing spell's charge and power do not multiply shell damage")
	fresh()
	e=enemy(Vector2(420,330))
	e.boss=true
	g.magic.behavior.hit(e,45,Vector2.ZERO,ctx(["frost_blossom"]),3)
	check(g.magic.behavior.movement_factor(e)>0 and total("freezes")==1,"Boss gets a breakable shell without movement freeze")
	g.magic.behavior.hit(e,22,Vector2.RIGHT,ctx(["bolt"]))
	check(total("shatters")==1,"Boss shell is naturally breakable")
	fresh()
	e=enemy(Vector2(420,330))
	g.magic.behavior.hit(e,10,Vector2.ZERO,ctx(["frost"]),3)
	tick(1.3)
	g.magic.behavior.hit(e,22,Vector2.RIGHT,ctx(["bolt"]))
	check(total("shatters")==0,"An expired shell cannot yield shatter damage")
	fresh()
	e=enemy(Vector2(420,330))
	for i in 3:
		emit(["frost","impact","bolt"])
		tick(.15)
	check(total("freezes")==1 and total("shatters")==1 and total("trigger_impact")==3,"Real frost-to-projectile chain naturally freezes then breaks the shell")

	fresh()
	var z1:=plant(["vortex"])
	z1.life=1.7
	var z2:=plant(["vortex"],Vector2(520,330))
	check(z1.garden_id==z2.garden_id and is_equal_approx(z1.radius,86*1.1),"Repeated nearby planting grows a shared visible field without a support orb")
	check(is_equal_approx(z1.life,1.7) and is_equal_approx(z2.life,3) and is_equal_approx(z1.damage,2.5),"Planting preserves each input's lifespan and base damage")
	var z3:=plant(["vortex"])
	check(is_equal_approx(z3.radius,86*1.2) and total("garden_full")==1,"Third independent planting reaches 20-percent range growth once")
	check(g.magic.zones.filter(func(z):return z.garden_leader).size()==1,"Shared garden renders one field while retaining three logical inputs")
	z1.life=.001
	g.magic.update_zones(.01)
	check(g.magic.zones.size()==2 and is_equal_approx(z2.radius,86*1.1),"Expired contributions shrink the cluster instead of refreshing damage/life")
	var remote:=plant(["vortex"],Vector2(700,330))
	check(remote.garden_id!=z2.garden_id,"Distant planting is a separate field")
	var other_orb:=plant(["vortex"],Vector2(500,330),1)
	check(other_orb.garden_id!=z2.garden_id,"Two orbs cannot merge away independent fields")
	var other_slot:=plant(["vortex"],Vector2(500,330),0,1,-1,1)
	check(other_slot.garden_id!=z2.garden_id,"Different source slots retain separate field groups")
	fresh()
	for i in 3: plant(["vortex"],Vector2(500,330),0,.65,900)
	check(g.magic.zones.all(func(z):return is_equal_approx(z.garden_mass,1) and is_equal_approx(z.radius,86)),"Multiple branches of one cast cannot instantly mature a garden")
	fresh()
	for i in 3: plant(["vortex","impact","bolt"])
	e=enemy(Vector2(500,330))
	g.magic.update_zones(.36)
	check(is_equal_approx(10000-e.hp,7.5) and total("triggers")==3,"Merged fields keep each input's damage and first-hit connector")
	fresh()
	for i in 3: plant(["thorn","expire","bolt"])
	e=enemy(Vector2(500,330))
	g.magic.update_zones(.26)
	check(is_equal_approx(10000-e.hp,135) and g.magic.zones.is_empty(),"Grown traps still activate on approach without a maturation wait")
	check(total("trigger_expire")==3,"Every consumed trap preserves its own normal-end payload")
	fresh()
	plant(["thorn","expire","bolt"])
	g.magic.update_zones(6.01)
	check(total("trap_activations")==0 and total("trigger_expire")==1,"Unused trap naturally expires without damage and retains its end payload")
	fresh()
	for i in 3: plant(["vortex","expire","bolt"])
	for zone in g.magic.zones: zone.life=.001
	g.magic.update_zones(.01)
	check(total("trigger_expire")==3,"Garden contributions each expire exactly once")
	fresh()
	var forced:=plant(["vortex","expire","bolt"])
	g.magic.evict_zone(forced)
	g.clear_magic()
	check(total("triggers")==0,"Forced garden eviction/cleanup cannot trigger end payloads")
	fresh()
	for i in 13: plant(["vortex"],Vector2(500,330),0,.05,1000+i)
	check(g.magic.zones.size()==13 and g.magic.zones.filter(func(z):return z.garden_leader).size()==2,"Full logical contribution list starts a new visible group without losing inputs")

	# Exercise common chain through all nine actual delivery/attack paths.
	for attack in Spells.ATTACK_INTERVALS:
		fresh()
		var first:=Vector2(420,330)
		if attack=="satellite": first=Vector2(395,335)
		if attack=="ember_path": first=Vector2(300,330)
		e=enemy(first)
		var next=enemy(first+Vector2(130,85))
		var last=enemy(first+Vector2(250,85))
		if attack in ["vortex","thorn"]: plant(["bounce",attack],first)
		else: emit(["bounce",attack])
		tick(.7)
		check(total("chain_hits")==2 and next.hp<10000 and last.hp<10000,"Common chain works after first damage: "+attack)
		check(total("stage_casts")==1,"Chain adds hits without cloning spells or restarting itself: "+attack)
		var count:=total("chain_hits")
		tick(.7)
		check(total("chain_hits")==count,"Repeated contacts do not restart chain: "+attack)
	fresh()
	e=enemy(Vector2(420,330))
	var second=enemy(Vector2(550,415))
	var third=enemy(Vector2(670,415))
	emit(["bounce","bolt","impact","thunder"])
	tick(.4)
	check(is_equal_approx(10000-second.hp,11) and is_equal_approx(10000-third.hp,5.5),"Common chain uses first-hit damage at 50 then 25 percent")
	check(total("trigger_impact")==1 and total("stage_casts")==2,"Chain targets do not independently fire the first-hit connector")
	fresh()
	e=enemy(Vector2(420,330))
	var same_area=enemy(Vector2(460,360))
	var far=enemy(Vector2(550,400))
	emit(["bounce","bloom"])
	tick(.5)
	check(is_equal_approx(10000-same_area.hp,20) and is_equal_approx(10000-far.hp,10),"Area chain excludes enemies already hit by the original explosion")
	fresh()
	e=enemy(Vector2(420,330))
	for i in 4: enemy(Vector2(500+i*70,400))
	emit(["bounce","bounce","bolt"])
	tick(.4)
	check(total("chain_hits")==4 and total("stage_casts")==1,"Duplicate chain supports add targets without recursive spell generation")

	fresh()
	var moon: Dictionary=Spells.compile(["boomerang","expire","bolt"]).stages[0]
	g.magic.emit(moon,Vector2(300,330),Vector2.RIGHT,Spells.follow(moon),1)
	g.projectiles[0].returning=true
	g.projectiles[0].pos=g.player.position
	g.cast_target=Vector2(300,100)
	g.aim=Vector2.UP
	g.magic.update_projectiles(.001)
	check(total("trigger_expire")==1 and g.projectiles.size()==1 and g.projectiles[0].dir.is_equal_approx(Vector2.UP),"Normal return uses common end connector and current aim exactly once")
	fresh()
	moon=Spells.compile(["moon_ring","expire","bolt"]).stages[0]
	g.magic.emit(moon,Vector2(300,330),Vector2.RIGHT,Spells.follow(moon),1)
	g.projectiles[0].returning=true
	g.projectiles[0].pos=g.player.position
	g.magic.update_projectiles(.001)
	check(total("trigger_expire")==1 and total("orbits_created")==1,"Moon fusion retains its intrinsic satellite alongside one user end payload")
	fresh()
	emit(["boomerang","expire","bolt"])
	g.projectiles[0].life=.001
	g.magic.update_projectiles(.01)
	check(total("trigger_expire")==1,"Unreturned boomerang expiry also emits one end payload")

	fresh()
	g.complete_wave()
	g.choose_reward("power")
	g.economy.inventory["vortex"]=1
	check(g.board_drop(g.board_data("vortex"),1,0),"Role-cleaned attack still supports direct cross-orb editing")
	g.undo_draft()
	check(g.orb_recipes[1].is_empty(),"Undo remains available after role-cleaned editing")
	check(g.start_trial(),"Updated starting configuration enters firing trial")
	var wave_time: float=g.wave_time
	var shop_time: float=g.shop_time
	g._physics_process(.1)
	check(g.wave_time==wave_time and g.shop_time==shop_time,"Trial still isolates combat from wave and shop clocks")
	g.end_trial()
	check(g.projectiles.is_empty() and g.magic.zones.is_empty(),"Ending trial clears role objects")
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
