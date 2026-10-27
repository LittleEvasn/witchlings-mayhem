extends SceneTree
const Meter = preload("res://scripts/combat_meter.gd")
const Runner = preload("res://scripts/measurement_runner.gd")
var g: Node2D
var runner: RefCounted
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		printerr("FAIL: "+message)

func fresh() -> void:
	g.meter = null
	g.start_run()
	g.set_physics_process(false)
	g.sound_enabled = false
	g.wave = 4
	g.player.position = Vector2(400,450)
	g.meter = Meter.new()

func fire(recipe: Array) -> void:
	var stages: Array = g.Spells.compile(recipe).stages
	g.emit_stage(stages[0],g.player.position,Vector2.RIGHT,stages[1] if stages.size()>1 else {},1)

func simulate(seconds: float) -> void:
	for tick in int(seconds*120):
		if g.meter != null: g.meter.time += Runner.STEP
		g._rebuild_grid()
		g._update_projectiles(Runner.STEP)
		g.magic.update_zones(Runner.STEP)
		g._update_effects(Runner.STEP)

func total(key: String) -> float:
	return g.meter.totals.get(key,0)

func run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	runner = Runner.new(g)
	fresh()
	var e = runner.target(Vector2(600,450),1000)
	fire(["bolt"])
	simulate(1)
	verify(is_equal_approx(total("damage_effective"),22) and is_equal_approx(e.hp,978),"Observed bolt damage equals the real target HP loss")
	verify(total("casts")==1 and total("projectiles_emitted")==1 and total("projectiles_contacted")==1,"Cast, projectile and unique contacting projectile are separate counters")
	fresh()
	runner.target(Vector2(600,650),1000)
	fire(["bolt"])
	simulate(3)
	verify(total("damage_effective")==0 and total("projectiles_finished_without_contact")==1,"Missed expired projectile records no damage")
	fresh()
	runner.target(Vector2(600,450),5)
	fire(["bolt"])
	simulate(1)
	verify(total("damage_raw")==22 and total("damage_effective")==5 and total("damage_overkill")==17 and total("kills")==1,"Overkill is excluded from useful damage and kill is counted once")
	fresh()
	for p in [Vector2(600,450),Vector2(630,450),Vector2(600,480)]: runner.target(p,100)
	fire(["bloom"])
	simulate(1)
	verify(total("explosions")==1 and total("explosion_victims")==3 and total("projectile_contacts")==1,"One flower contact causes one explosion with three damage victims")
	verify(is_equal_approx(total("damage_effective"),60),"Explosion damage is attributed once per victim")
	fresh()
	for p in [Vector2(600,400),Vector2(600,450),Vector2(600,500)]: runner.target(p,1000)
	fire(["fan","bolt"])
	simulate(1)
	verify(total("projectiles_emitted")==3 and is_equal_approx(total("damage_effective"),42.9),"Fan records three real 65-percent-strength projectiles")
	fresh()
	runner.target(Vector2(600,450),1000)
	fire(["echo","bolt"])
	simulate(1)
	verify(total("casts")==1 and total("echoes_fired")==1 and total("projectiles_emitted")==2,"An echo is not counted as a new root cast")
	verify(is_equal_approx(g.meter.sources["primary/bolt/echo"].damage_effective,12.1),"Echo contribution is separated at its actual 55-percent damage")
	fresh()
	runner.target(Vector2(600,450),1000)
	fire(["bolt","impact","bloom"])
	simulate(1)
	verify(total("triggers")==1 and is_equal_approx(g.meter.sources["secondary/bloom"].damage_effective,13),"Triggered flower contribution retains the actual child multiplier")
	var sum := 0.0
	for row in g.meter.sources.values(): sum += float(row.get("damage_effective",0))
	verify(is_equal_approx(sum,total("damage_effective")) and is_equal_approx(sum,35),"Source contributions reconcile with total real damage")
	fresh()
	runner.target(Vector2(600,450),1000)
	fire(["vortex"])
	simulate(1.5)
	verify(total("zones_created")==1 and total("zone_pulses")>0 and total("pull_distance")>0,"Vortex installation, pulses and actual pull distance are observed")
	verify(g.meter.sources.has("primary/vortex") and total("damage_effective")>0,"Vortex damage is assigned to its own source")
	fresh()
	e = runner.target(Vector2(600,450),1000)
	g.meter = null
	fire(["bolt","impact","bloom"])
	simulate(1)
	verify(is_equal_approx(e.hp,965),"With no observer attached, the combat result stays identical")
	var recipe := ["seek","fan","bloom","impact","vortex"]
	verify(not runner.begin(["impact"],"single"),"Invalid recipes are rejected before measurement")
	runner.begin(recipe,"pressure",731,"nearest",4)
	while runner.active: runner.step()
	var a: Dictionary = runner.report()
	await process_frame
	runner.begin(recipe,"pressure",731,"nearest",4)
	while runner.active: runner.step()
	var b: Dictionary = runner.report()
	verify(a.totals==b.totals and a.sources==b.sources and a.timeline==b.timeline,"Same seed, recipe and scripted controls reproduce identical combat results")
	verify(a.power==1 and a.fire_rate==1 and a.orb_cost==70 and a.step==Runner.STEP,"Report stores comparison conditions and actual orb cost")
	for scenario in Runner.SCENARIOS:
		runner.begin(recipe,scenario,731,"nearest",2)
		while runner.active: runner.step()
		var report: Dictionary = runner.report()
		verify(report.completed and report.seconds>0 and report.totals.get("projectiles_emitted",0)>0,"Scenario executes the real engine: "+scenario)
		await process_frame
	Runner.save_reports([a,b],ProjectSettings.globalize_path("res://artifacts/measurements/verification"))
	var saved = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/measurements/verification.json"))
	verify(saved.runs.size()==2 and FileAccess.file_exists("res://artifacts/measurements/verification.csv"),"JSON detail and CSV summary are exported together")
	runner.stop()
	verify(g.meter==null and g.projectiles.is_empty() and g.magic.zones.is_empty(),"Stopping detaches the observer and clears measurement magic")
	g.queue_free()
	await process_frame
	var lab = load("res://scenes/measurement_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await process_frame
	verify(lab.recipe_buttons.size()==6 and not lab.run_button.disabled and lab.game.meter==null,"Visible lab loads with a valid editable recipe and idle engine")
	lab.parts = ["impact"]
	lab.refresh_recipe()
	verify(lab.run_button.disabled and lab.all_button.disabled,"Invalid visible recipe cannot start a measurement")
	lab.parts = ["bolt"]
	lab.refresh_recipe()
	lab.start(false)
	verify(lab.is_running and lab.game.meter!=null,"Visible start button attaches the shared measurement runner")
	lab.cancel()
	verify(not lab.is_running and lab.game.meter==null and lab.reports.is_empty(),"Cancelled run is cleaned up and excluded from finished reports")
	lab.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
