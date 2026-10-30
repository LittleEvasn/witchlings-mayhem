extends "res://scripts/game.gd"
## A disposable scene: no run/profile/checkpoint writes, no waves or rewards.
const Room=preload("res://scripts/training_room.gd")
var training_rank:=0
var training_filter:="attack"
var training_seconds:=0.0
var training_positions: Array=[]
const AI_SECONDS := 60.0
var ai_running := false
var ai_seconds := 0.0
var ai_original: Array = []
var ai_added_targets: Array = []
var ai_report: Dictionary = {}

func ai_status() -> String:
	if ai_running:
		return "AI 플레이 %.1f / 60초 · 10개 표적 · 4오브 자동 장착 · 피해 %.0f · 명중 %d" % [ai_seconds,trial_damage,trial_hits]
	if not ai_report.is_empty():
		return "최근 AI 결과 · %.1f초 · 피해 %.0f · 명중 %d · 시전 %d" % [ai_report.seconds,ai_report.damage,ai_report.hits,ai_report.casts]
	return "AI 플레이: 10개 표적 / 4오브 / 60초 자동 이동·조준·발사 · 기존 장착은 종료 후 복구"

func start_ai_autoplay() -> void:
	if ai_running or state!="trial": return
	ai_original=orb_drafts.duplicate(true)
	ai_report.clear()
	reset_training(true)
	var rows: Array=[
		["seek","fan","bolt"],
		["echo","bloom"],
		["orbit","satellite"],
		["element_ice","frost"]
	]
	for i in 4: orb_drafts[i]=Spells.fixed_slots(rows[i],8)
	draft=orb_drafts[active_orb].duplicate()
	_draft_changed()
	for i in 6:
		var enemy:=Actor.new()
		actors.add_child(enemy)
		enemy.position=Vector2(650+(i%3)*125,210+int(i/3)*205)
		enemy.setup(art,1)
		enemy.hp=1000000
		enemy.max_hp=enemy.hp
		enemies.append(enemy)
		ai_added_targets.append(enemy)
	ai_seconds=0.0
	player.position=Vector2(475,330)
	ai_running=true
	_rebuild_grid()
	Room.build(ui)

func stop_ai_autoplay() -> void:
	if not ai_running: return
	ai_running=false
	ai_report={"seconds":ai_seconds,"damage":trial_damage,"hits":trial_hits,"casts":metrics.casts}
	for enemy in ai_added_targets:
		enemies.erase(enemy)
		if is_instance_valid(enemy): enemy.queue_free()
	ai_added_targets.clear()
	orb_drafts=ai_original.duplicate(true)
	ai_original.clear()
	draft=orb_drafts[active_orb].duplicate()
	_draft_changed()
	reset_training()
	Room.build(ui)

func _ready() -> void:
	record_runs=false
	training_mode=true
	super._ready()
	start_run("sigil")
	director.enabled=false;encounters.enabled=false
	state="shop";shop_time=9999
	orb_recipes=[Spells.fixed_slots(["bolt"],8)]
	for n in 3: orb_recipes.append(Spells.fixed_slots([],8))
	orb_drafts=orb_recipes.duplicate(true)
	orb_compiled=[];orb_trial=[];orb_growth=[];orb_upgrades=[];orb_buffer_ready=[]
	for row in orb_recipes:
		orb_compiled.append(Spells.compile(row).stages);orb_trial.append([])
		var growth:=OrbGrowth.fresh();growth.picks.socket=2;growth.rank=2
		orb_growth.append(growth);orb_upgrades.append(2);orb_buffer_ready.append(0.0)
	active_orb=0;recipe=orb_recipes[0].duplicate();draft=recipe.duplicate()
	refill_stock()
	_reset_orb_clocks()
	start_trial()
	for target in enemies: training_positions.append(target.position)
	notice="";notice_left=0
	Room.build(ui)

func refill_stock() -> void:
	economy.inventory.clear()
	for id in Spells.PARTS: economy.inventory[Spells.Progression.key(id,training_rank)]=1
	for id in Spells.Progression.FUSIONS: economy.inventory[id]=1
	economy.revision+=1

func set_training_rank(rank: int) -> void:
	training_rank=clampi(rank,0,3)
	for row in orb_drafts:
		for i in row.size():
			if not row[i].is_empty() and not Spells.Progression.is_fused(row[i]): row[i]=Spells.Progression.key(Spells.Progression.base_id(row[i]),training_rank)
	refill_stock();draft=orb_drafts[active_orb].duplicate()
	edit_history.clear();_draft_changed()

func reset_training(clear_loadout:=false) -> void:
	if ai_running: stop_ai_autoplay(); return
	clear_magic();effects.clear();damage_numbers.clear()
	trial_damage=0;trial_hits=0;training_seconds=0
	for n in enemies.size():
		enemies[n].position=training_positions[n]
		enemies[n].flash=0
	if clear_loadout:
		for row in orb_drafts: row.fill("")
		draft=orb_drafts[active_orb].duplicate();edit_history.clear();_draft_changed()
	else: _reset_orb_clocks()
	Room.build(ui)

func _update_trial(delta: float) -> void:
	training_seconds+=delta
	if ai_running:
		ai_seconds+=delta
		# Deterministic scripted movement. Real aim and spells remain the production engine.
		player.position=Vector2(520+110*cos(ai_seconds*.6),330+95*sin(ai_seconds*.6))
	super._update_trial(delta)
	if ai_running and ai_seconds>=AI_SECONDS: stop_ai_autoplay()
	if ai_running and is_instance_valid(ui.modal):
		var label: Label=ui.modal.get_node_or_null("AiAutoplayStatus")
		if label!=null: label.text=ai_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("pause_game"): end_trial()
	elif event.is_action_pressed("recipe"):
		if is_instance_valid(ui.modal): ui.modal.visible=not ui.modal.visible
	elif event.is_action_pressed("mute"): sound_enabled=not sound_enabled

func end_trial() -> void:
	if ai_running: stop_ai_autoplay()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
