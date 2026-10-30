extends SceneTree
## Deterministic simulated player: the production Godot combat runtime, not a JS imitation.
## Every catalog item is used in at least one valid attack/modifier/connector recipe.
const Runner = preload("res://scripts/measurement_runner.gd")
const Spells = preload("res://scripts/spells.gd")
const Catalog = preload("res://scripts/magic_catalog.gd")
const TEST_SECONDS := 5.0
const LONG_SECONDS := 60.0
var checks := 0
var failures := 0
var warnings := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func recipe_for(id: String) -> Array:
	var kind: String = str(Spells.definition(id).kind)
	match kind:
		"attack": return [id]
		"modifier": return [id, "bolt"]
		"connector": return ["bolt", id, "bloom"]
	return []

func all_cases() -> Array:
	var cases: Array = []
	for id in Catalog.PARTS.keys():
		cases.append({"id":id,"kind":str(Spells.definition(id).kind),"recipe":recipe_for(id)})
	for id in Spells.Progression.FUSIONS.keys():
		cases.append({"id":id,"kind":str(Spells.definition(id).kind),"recipe":recipe_for(id)})
	return cases

func report_for(raw: Dictionary, id: String, kind: String, recipe: Array, scenario: String) -> Dictionary:
	var totals: Dictionary = raw.get("totals",{})
	var row := {
		"id":id,"name":str(Spells.definition(id).name),"kind":kind,
		"recipe":recipe.duplicate(),"scenario":scenario,"seed":731,
		"seconds":raw.get("seconds",0),"completed":raw.get("completed",false),
		"casts":totals.get("casts",0),"projectiles":totals.get("projectiles_emitted",0),
		"hits":totals.get("damage_events",0),"damage":totals.get("damage_effective",0),
		"triggers":totals.get("triggers",0),"first_damage":raw.get("first_damage",-1),
		"cpu_p95_ms":raw.get("step_cpu_ms",{}).get("p95",0),
		"peak_projectiles":totals.get("peak_projectiles",0),
		"peak_zones":totals.get("peak_zones",0),"warnings":[]
	}
	if float(row.casts)<=0: row.warnings.append("NO_ROOT_CAST")
	if float(row.damage)<=0: row.warnings.append("NO_EFFECTIVE_DAMAGE")
	if float(totals.get("projectiles_blocked",0))>0: row.warnings.append("PROJECTILE_CAP")
	if float(totals.get("zones_evicted",0))>0: row.warnings.append("ZONE_EVICTED")
	return row

func run() -> void:
	var cases: Array = all_cases()
	check(cases.size()==60,"All 30 base and 30 fusion items covered")
	var ids := {}
	var g: Node2D=load("res://scenes/main.tscn").instantiate()
	g.record_runs = false
	root.add_child(g)
	current_scene = g
	await process_frame
	g.set_physics_process(false)
	g.set_process_unhandled_input(false)
	g.sound_enabled = false
	var runner = Runner.new(g)
	var results: Array = []
	for item in cases:
		var id: String = item.id
		check(not ids.has(id),"Unique item: "+id)
		ids[id] = true
		var recipe: Array = item.recipe
		var parsed: Dictionary = Spells.compile(recipe)
		check(parsed.ok and not parsed.stages.is_empty(),"Valid recipe: "+id)
		if not parsed.ok: continue
		var scene := "cluster" if item.kind!="connector" else "single"
		var started: bool = runner.begin(recipe,scene,731,"nearest",TEST_SECONDS,1.0,1.0,"sigil",{"motion":"orbit"})
		check(started,"Starts actual combat: "+id)
		if not started: continue
		while runner.active: runner.step()
		var result: Dictionary=runner.report()
		var row: Dictionary=report_for(result,id,item.kind,recipe,scene)
		results.append(row)
		check(row.completed and float(row.seconds)>0,"Finished simulation: "+id)
		if not row.warnings.is_empty():
			warnings += 1
			print("WARN: %s %s"%[id,JSON.stringify(row.warnings)])
		# Yield so queued_free children from the previous test are released.
		await process_frame
	check(results.size()==60,"60 actual runtime sessions with recorded observations")
	# A full 60-second AI-play scenario checks movement, dynamic enemies, damage and survival.
	var long_ok: bool = runner.begin(["seek","fan","bolt","impact","bloom"],"pressure",739,"nearest",LONG_SECONDS,1.0,1.0,"sigil",{"motion":"orbit"})
	check(long_ok,"Start 60-second moving AI scenario")
	var extended := {}
	if long_ok:
		while runner.active: runner.step()
		extended=runner.report()
		check(extended.completed and float(extended.seconds)>=LONG_SECONDS-Runner.STEP,"Full 60-second playback")
		check(float(extended.totals.get("casts",0))>0,"AI cast during full session")
		check(float(extended.totals.get("damage_effective",0))>0,"AI hit enemies in full session")
		check(extended.input_trace.size()>=50,"AI movement and targeting were recorded")
	var path := OS.get_environment("AI_AUTOPLAY_OUTPUT")
	if path.is_empty(): path="res://artifacts/ai-autoplay/report.json"
	if path.begins_with("res://"): path=ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var output={
		"schema":1,"tool":"Godot 4.6.2 actual combat runtime",
		"seed":731,"short_window_seconds":TEST_SECONDS,
		"warnings_are_not_passes":true,"item_count":results.size(),
		"warning_count":warnings,"checks":checks,"failures":failures,
		"cases":results,"long_session":{
			"recipe":["seek","fan","bolt","impact","bloom"],
			"scenario":"pressure","seconds":extended.get("seconds",0),
			"damage":extended.get("totals",{}).get("damage_effective",0),
			"casts":extended.get("totals",{}).get("casts",0),
			"player_final_health":extended.get("player_final_health",0),
			"movement_samples":extended.get("input_trace",[]).size(),
			"cpu_p95_ms":extended.get("step_cpu_ms",{}).get("p95",0)
		}
	}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		check(false,"Cannot write JSON report: "+path)
	else:
		file.store_string(JSON.stringify(output,"  "))
		file.close()
		check(FileAccess.file_exists(path),"Wrote JSON report")
	var csv_path:=path.get_basename()+".csv"
	var csv:=FileAccess.open(csv_path,FileAccess.WRITE)
	if csv!=null:
		csv.store_csv_line(PackedStringArray(["id","kind","recipe","seconds","casts","hits","damage","triggers","warnings","cpu_p95_ms"]))
		for row in results:
			csv.store_csv_line(PackedStringArray([str(row.id),str(row.kind),JSON.stringify(row.recipe),str(row.seconds),str(row.casts),str(row.hits),str(row.damage),str(row.triggers),JSON.stringify(row.warnings),str(row.cpu_p95_ms)]))
		csv.close()
	check(FileAccess.file_exists(csv_path),"Wrote CSV report")
	runner.stop()
	g.queue_free()
	await process_frame
	# Validate the actual web-training UI trigger and restoration, not only scripted battle.
	var training=load("res://scenes/training.tscn").instantiate()
	root.add_child(training)
	current_scene=training
	await process_frame
	training.set_physics_process(false)
	var original: Array=training.orb_drafts.duplicate(true)
	check(training.ui.modal.find_child("TrainingAiAutoplay",true,false)!=null,"AI button visible in training room")
	training.start_ai_autoplay()
	check(training.ai_running and training.enemies.size()==10,"AI button starts 10-target real training session")
	check(training.orb_drafts.size()==4 and training.orb_drafts[3][1]=="frost","AI equipped four independent orbs")
	training._update_trial(1.0/60.0)
	check(training.ai_seconds>0 and training.ai_running,"AI automatic movement step executes")
	training.stop_ai_autoplay()
	check(not training.ai_running and training.enemies.size()==4,"Stopping AI restores four normal targets")
	check(training.orb_drafts==original and not training.ai_report.is_empty(),"Stopping AI restores saved orb loadout and result")
	training.queue_free()
	await process_frame
	print("AUTOPLAY_REPORT: "+path)
	print("RESULT: %d checks / %d failures / %d flagged cases"%[checks,failures,warnings])
	quit(0 if failures==0 else 1)
