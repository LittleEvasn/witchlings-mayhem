extends "res://scripts/game.gd"
## A disposable scene: no run/profile/checkpoint writes, no waves or rewards.
const Room=preload("res://scripts/training_room.gd")
var training_rank:=0
var training_filter:="attack"
var training_seconds:=0.0
var training_positions: Array=[]

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
	super._update_trial(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("pause_game"): end_trial()
	elif event.is_action_pressed("recipe"):
		if is_instance_valid(ui.modal): ui.modal.visible=not ui.modal.visible
	elif event.is_action_pressed("mute"): sound_enabled=not sound_enabled

func end_trial() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
