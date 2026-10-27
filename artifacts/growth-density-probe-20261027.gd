extends SceneTree
const Runner=preload("res://scripts/measurement_runner.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	g.record_runs=false
	g.set_physics_process(false)
	var rows: Array=[]
	var fixtures := [
		{"id":"bolt_basic","bank":[["bolt"],["bolt"]]},
		{"id":"bolt_max4","bank":[["bolt@4"],["bolt@4"]]},
		{"id":"fan_echo_basic","bank":[["giant","fan","echo","bolt"],["giant","fan","echo","bloom"]]},
		{"id":"fan_echo_max4","bank":[["giant@4","fan@4","echo@4","bolt@4"],["giant@4","fan@4","echo@4","bloom@4"]]}
	]
	for fixture in fixtures:
		var runner:=Runner.new(g)
		if not runner.begin(fixture.bank,"single",731,"replay",15,1,1,"sigil"):
			printerr("FAILED fixture "+fixture.id)
			quit(1)
			return
		while runner.active: runner.step()
		var report: Dictionary=runner.report()
		var totals: Dictionary=report.totals
		var row: Dictionary={"id":fixture.id,"bank":fixture.bank,"seconds":report.seconds,"intervals":report.orb_intervals,"emitted":totals.get("projectiles_emitted",0),"peak_projectiles":totals.get("peak_projectiles",0),"echoes_fired":totals.get("echoes_fired",0),"emits_blocked":totals.get("emits_blocked",0),"projectiles_blocked":totals.get("projectiles_blocked",0),"echoes_blocked":totals.get("echoes_blocked",0),"raw_damage":totals.get("damage_raw",0)}
		rows.append(row)
		print(JSON.stringify(row))
		runner.stop()
	var out:=FileAccess.open("res://artifacts/growth-density-probe-20261027.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"seed":731,"scenario":"single","window_seconds":15,"note":"Existing +4 rules, fixed laboratory target and virtual loadouts; not a human run, affordability or GPU test.","rows":rows},"  "))
	out.close()
	quit()
