extends SceneTree
const Runner = preload("res://scripts/measurement_runner.gd")
var checks := 0
var failures := 0
var g: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+note)
func measure(bank: Array, scenario := "single", seconds := 2.0, seed_value := 731, options: Dictionary = {}) -> Dictionary:
	var r := Runner.new(g)
	check(r.begin(bank,scenario,seed_value,"replay",seconds,1,1,"sigil",options),"Valid real two-orb job begins")
	while r.active: r.step()
	var report := r.report()
	r.stop()
	check(g.projectiles.is_empty() and g.magic.echoes.is_empty() and g.magic.zones.is_empty() and g.magic.behavior.strikes.is_empty(),"No reservations after stop")
	return report
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	g.set_physics_process(false)
	var r := Runner.new(g)
	for invalid in [[[],[]],[["bolt"]],[["impact"],["bolt"]],[["bolt"],["bolt"],[]]]:
		check(not r.begin(invalid,"single"),"Reject malformed/invalid bank")
	var first:=measure([["bolt","bloom"],["thunder"]])
	check(first.sources.has("o0/s0/primary/bolt") and first.sources.has("o0/s1/primary/bloom") and first.sources.has("o1/s0/primary/thunder"),"Sources keep both orbs and all sequence roots")
	check(first.totals.get("stage_casts",0)>=8,"Real production clocks repeat independent programs")
	check(first.first_damage<1,"No artificial initial cycle wait")
	var alone:=measure([[],["bolt"]])
	check(alone.sources.has("o1/s0/primary/bolt") and not alone.sources.has("o0/s0/primary/bolt"),"Empty first orb does not duplicate the second")
	var a:=measure([["fan","bloom","impact","vortex"],["bolt"]],"pressure",5)
	var b:=measure([["charge","bolt"],["thunder"]],"pressure",5)
	var repeat:=measure([["fan","bloom","impact","vortex"],["bolt"]],"pressure",5)
	check(a.input_trace==b.input_trace and a.arrival_plan==b.arrival_plan,"Shared mouse/movement/arrivals cannot depend on build or combat RNG")
	check(a.totals==repeat.totals and a.sources==repeat.sources,"Identical seed and inputs produce identical combat results")
	check(a.sources.keys().any(func(s):return s.begins_with("o0/s3/chain/vortex")),"Child attributed to its own orb and source slot")
	check(a.arrival_plan.size()==12 and a.spawned==12,"No stale scheduled arrivals between jobs")
	var orbit:=measure([["bolt"],["bloom"]],"single",2,731,{"motion":"orbit"})
	check(orbit.input_trace!=first.input_trace,"Separate movement condition is visible in trace")
	var cost:=Runner.Cost.new()
	check(cost.plan([["bolt"],["bolt"]]).spent==8,"Starting free stock counted only once across both orbs")
	var ranked: Array=[["fan@2","bolt","impact","bloom"],["pierce","bolt"]]
	check(cost.plan(ranked).spent==60,"Merge route uses three base fan copies including one free copy")
	check(cost.plan(ranked,"sigil","paid").spent==71,"Paid route replays actual two upgrade quotes")
	check(cost.plan([["storm_spear"],[]]).spent==124,"Fusion route obtains distinct +4 parents and pays fusion fee")
	var duplicates:=cost.plan([["fan@2","bolt"],["fan@2","bolt"]])
	check(duplicates.ok and duplicates.inventory.get("fan@2",0)==2 and duplicates.spent==78,"Ranked duplicates reserve distinct real stock")
	check(r.begin([["fan","bolt","impact","bloom","expire","thunder"],[]],"single"),"Deep fan chain begins")
	r.step()
	var parent: Dictionary=g.projectiles[0]
	check(is_equal_approx(parent.child_factor,.4*.65),"Each branch transmits its reduced factor, not a new full-power payload")
	g.magic.trigger(parent,Vector2(600,430))
	var child: Dictionary=g.projectiles.back()
	check(child.attack=="bloom" and child.stage.fan==1 and is_equal_approx(child.damage,20*.4*.65*.4),"Child applies its compiled fan once to the inherited portion")
	g.magic.trigger(child,Vector2(600,430),"expire")
	var strike: Dictionary=g.magic.behavior.strikes.back()
	check(strike.stage.fan==1 and is_equal_approx(g.magic.behavior.damage_scale(strike),.4*.65*.4*.65*.4),"Third event stage preserves weighted budget without duplicating modifiers")
	r.stop()
	check(r.begin([["vortex"],[]],"single"),"Zone identity fixture begins")
	r.step()
	var seed: Dictionary=g.projectiles[0].duplicate(true)
	seed.pos=Vector2(700,430)
	g.magic.install(seed)
	seed.seed_portions=1
	g.magic.install(seed)
	var z0: Dictionary=g.magic.zones[0]
	var z1: Dictionary=g.magic.zones[1]
	check(z0._zone_uid!=z1._zone_uid and g.magic.live_zones.size()==2,"Lookalike fields have distinct IDs")
	g.magic.evict_zone(z0)
	check(g.magic.zones.size()==1 and g.magic.live_zones.has(z1._zone_uid) and not g.magic.live_zones.has(z0._zone_uid),"Removing one lookalike preserves the other's membership")
	r.stop()
	check(g.magic.live_zones.is_empty(),"Force cleanup clears field ID registry")
	var csvstem: String=ProjectSettings.globalize_path("res://artifacts/measurements/two-orb-test")
	Runner.save_reports([first],csvstem)
	var file:=FileAccess.open(csvstem+".csv",FileAccess.READ)
	check(file.get_csv_line().size()==file.get_csv_line().size(),"CSV header and values align")
	var lab=load("res://scripts/measurement_lab.gd").new()
	root.add_child(lab)
	check(lab.recipe_buttons.size()==12 and lab.bank.size()==2,"Visible lab exposes both six-slot rows")
	lab.active_orb=1
	lab.parts=["echo@2","bolt"]
	lab.refresh_recipe()
	check(lab.bank[0]!=lab.bank[1] and not lab.run_button.disabled,"Lab edits second orb and accepts upgraded supports")
	lab.queue_free()
	g.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
