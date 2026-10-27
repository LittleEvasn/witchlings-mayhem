extends SceneTree
const Runner = preload("res://scripts/measurement_runner.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Supply a measurement job JSON path after --")
		quit(1)
		return
	var request = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not request is Dictionary or not request.has("jobs"):
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	var runner := Runner.new(game)
	var reports: Array = []
	var quiet: bool = request.get("quiet",false)
	var compact: bool = request.get("compact",false)
	for job in request.jobs:
		if not runner.begin(job.recipe,job.scenario,int(job.get("seed",731)),job.get("aim","nearest"),float(job.get("seconds",15)),float(job.get("power",1)),float(job.get("fire_rate",1)),job.get("kit","sigil")):
			printerr("Invalid measurement job: "+str(job))
			quit(1)
			return
		while runner.active: runner.step()
		var report := runner.report()
		reports.append(report)
		if not quiet:
			print("MEASURE: "+JSON.stringify({"recipe":job.recipe,"scenario":job.scenario,"seed":job.get("seed",731),"dps":report.effective_dps,"kills":report.totals.get("kills",0),"clear":report.clear_seconds}))
		runner.stop()
		await process_frame
		if compact:
			report.erase("timeline")
			report.erase("kill_times")
			report.erase("victims")
		if quiet and (reports.size() % 500 == 0 or reports.size() == request.jobs.size()):
			print("PROGRESS: %d/%d"%[reports.size(),request.jobs.size()])
	Runner.save_reports(reports,request.output)
	game.queue_free()
	await process_frame
	print("RESULT: %d production-runtime measurements saved"%reports.size())
	quit()
