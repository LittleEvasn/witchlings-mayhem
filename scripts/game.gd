extends Node2D

const Workbench = preload("res://scripts/spell_workbench.gd")
const Forge = preload("res://scripts/spell_forge.gd")
const RoleMigration = preload("res://scripts/spell_role_migration.gd")
const Spells = preload("res://scripts/spells.gd")
const OrbGrowth = preload("res://scripts/orb_growth.gd")
const Waves = preload("res://scripts/waves.gd")
const Economy = preload("res://scripts/economy.gd")
const Relics = preload("res://scripts/relics.gd")
const SHOP_SECONDS := 60.0
const SpellRuntime = preload("res://scripts/spell_runtime.gd")
const Actor = preload("res://scripts/actor.gd")
const ActorOverlays=preload("res://scripts/actor_overlays.gd")
const Visuals = preload("res://scripts/magic_visuals.gd")
const Interface = preload("res://scripts/interface.gd")
const ArenaWorld = preload("res://scripts/arena_world.gd")
const RunContent = preload("res://scripts/run_content.gd")
const PlayerProfile = preload("res://scripts/player_profile.gd")
const RunCheckpoint = preload("res://scripts/run_checkpoint.gd")
const BossEncounter = preload("res://scripts/boss_encounter.gd")
const AutoTargeting = preload("res://scripts/auto_targeting.gd")
const CombatRewards = preload("res://scripts/combat_rewards.gd")
const FieldEncounters = preload("res://scripts/field_encounters.gd")
const FIELD := Rect2(0,0,4800,3600)
const FIXED_FIELD := Rect2(72,115,1296,656)
const MAX_ENEMIES := 320
const MAX_PROJECTILES := 180
const GRID_SIZE := 96.0

var state := "title"
var personal_tab := ""
var combat_rewards: RefCounted
var encounters: RefCounted
var previous_state := "combat"
var player: Node2D
var camera: Camera2D
var arena: Node2D
var arena_profile := "scroll"
var actors: Node2D
var art: Texture2D
var visuals: Node2D
var ui: CanvasLayer
var enemies: Array = []
var projectiles: Array = []
var hostile_shots: Array = []
var gems: Array = []
var effects: Array = []
var grid: Dictionary = {}
var magic: RefCounted
var meter: RefCounted
var active_orb := 0
var selected_group := 0
var orb_recipes: Array = [[],[]]
var orb_drafts: Array = [[],[]]
var orb_compiled: Array = [[],[]]
var orb_trial: Array = [[],[]]
var orb_clocks: Array = [0.0,0.0]
var orb_cursors: Array = [0,0]
var workbench_message := ""
var role_migration_receipt: Dictionary = {}
var recipe: Array = ["bolt","impact","bloom"]
var economy := Economy.new()
var relics := Relics.new()
var shop_time := 0.0
var shop_message := ""
var shop_tab := "shop"
var forge_target := ""
var forge_material := ""
var forge_message := ""
var compiled: Array = []
var draft: Array = []
var edit_revision := 0
var edit_history: Array = []
var purchased_orb := ""
var trial_stages: Array = []
var trial_snapshot: Dictionary = {}
var trial_damage := 0.0
var trial_hits := 0
var hp := 100.0
var max_hp := 100.0
var invincible := 0.0
var dash_left := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector2.RIGHT
var last_move := Vector2.DOWN
var cast_clock := 0.0
var fire_rate := 1.0
var power := 1.0
var wave := 1
var wave_time := 0.0
var elapsed := 0.0
var director: RefCounted
var kills := 0
var wave_kills := 0
var ui_clock := 0.0
var cast_target := Vector2(960,450)
var selected_kit := "sigil"
var aim := Vector2.RIGHT
var boss_ref: Node2D
var result_win := false
var end_reason := ""
var run_record: Dictionary = {}
var wave_records: Array = []
var prep_elapsed := 0.0
var profile := PlayerProfile.new()
var checkpoint_store := RunCheckpoint.new()
var checkpoint_loading := false
var checkpoint_clock := 0.0
var checkpoint_message := ""
var run_id := ""
var record_runs := DisplayServer.get_name()!="headless"
var boss_encounter: RefCounted
var boss_spawn_wait := 0.0
var final_boss_started := false
var chests: Array = []
var orb_upgrades: Array = [0]
var orb_growth: Array = [OrbGrowth.fresh()]
var orb_buffer_ready: Array = [0.0]
var orb_growth_open := -1
var workshop_relics: Array = []
var actor_shadows: Node2D
var actor_health: Node2D
var music_enabled := false
var music_player: AudioStreamPlayer
var music_phase := ""
var reward_options: Array = []
var reward_taken := false
var notice := ""
var notice_left := 0.0
var sound_enabled := true
var sounds: Dictionary = {}
var audio: Array[AudioStreamPlayer] = []
var sound_index := 0
var sound_clock := 0.0
var rng := RandomNumberGenerator.new()
var metrics := {"casts":0,"triggers":0,"hits":0,"peak_projectiles":0,"peak_enemies":0}

func _ready() -> void:
	get_tree().auto_accept_quit=false
	rng.randomize()
	economy.relics = relics
	_bind_inputs()
	art = load("res://assets/art/characters.png")
	arena = ArenaWorld.new()
	add_child(arena)
	arena.configure(FIELD)
	actors = Node2D.new()
	actors.y_sort_enabled=true
	add_child(actors)
	player = Actor.new()
	actors.add_child(player)
	player.position = FIELD.get_center()
	player.setup(art,0)
	player.radius = 16
	camera=Camera2D.new()
	camera.name="WorldCamera"
	camera.process_callback=Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled=false
	add_child(camera)
	set_arena_profile("scroll")
	visuals = Visuals.new()
	visuals.game = self
	visuals.z_index = 4000
	add_child(visuals)
	actor_shadows=ActorOverlays.new()
	actor_shadows.game=self
	actor_shadows.shadows=true
	actor_shadows.z_index=-1
	add_child(actor_shadows)
	actor_health=ActorOverlays.new()
	actor_health.game=self
	actor_health.z_index=3995
	add_child(actor_health)
	director = Waves.new(self)
	combat_rewards = CombatRewards.new(self)
	encounters = FieldEncounters.new(self)
	boss_encounter = BossEncounter.new(self)
	magic = SpellRuntime.new(self)
	if record_runs: profile.load_profile()
	sound_enabled = profile.data.sound
	# User removed the provisional soundtrack. Old saved settings cannot enable it.
	music_enabled = false
	ui = Interface.new()
	ui.game = self
	add_child(ui)
	compiled = Spells.compile(recipe).stages
	_build_sounds()
	set_music("prepare")
	ui.show_title()
	if not profile.warning.is_empty(): announce(profile.warning,6)

func begin_lumi_run(kit: String, play_intro := true) -> void:
	if not start_run(kit): return
	state="intro"
	set_music("prepare")
	ui.intro_index=0
	if play_intro: ui.show_intro()
	else: begin_combat()

func begin_combat() -> void:
	if state!="intro": return
	profile.data.intro_seen=true
	if record_runs and meter==null: profile.save_profile()
	state="combat"
	ui.close_modal()
	set_music("combat")
	announce(RunContent.chapter(1).lumi,5)

func set_music(phase: String) -> void:
	# Retain phase hooks for a future user-supplied soundtrack, with no audio loading.
	music_phase=phase
	music_enabled=false
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream=null

func save_settings() -> void:
	profile.data.sound=sound_enabled
	profile.data.music=false
	if record_runs: profile.save_profile()

func discover_owned() -> void:
	if checkpoint_loading or meter!=null: return
	if profile.discover(economy.inventory.keys(),relics.owned) and record_runs: profile.save_profile()

func checkpoint_info() -> Dictionary:
	return checkpoint_store.load_data() if record_runs else {}

func save_checkpoint() -> bool:
	if not record_runs or checkpoint_loading or meter!=null: return true
	if state!="shop": return false
	discover_owned()
	var ok: bool=checkpoint_store.write(RunCheckpoint.capture(self))
	checkpoint_message="제작 상태 자동 저장 · 준비 완료 후에는 전투 중 저장하지 않아요." if ok else checkpoint_store.warning
	return ok

func resume_checkpoint() -> bool:
	if state!="title": return false
	var saved:=checkpoint_info()
	if saved.is_empty() or saved.run_id in profile.data.completed_ids:
		checkpoint_message="이어할 제작 상태가 없어요." if checkpoint_store.warning.is_empty() else checkpoint_store.warning
		ui.show_title()
		return false
	checkpoint_loading=true
	return_title()
	start_run(saved.kit)
	RunCheckpoint.apply(self,saved)
	checkpoint_loading=false
	discover_owned()
	checkpoint_message="제작 상태를 이어왔어요. 다음은 %d웨이브예요."%(wave+1)
	ui.rebuild_recipe()
	ui.show_shop()
	return true

func save_and_title() -> void:
	if state=="trial": end_trial()
	if state!="shop": return
	return_title()

func request_quit() -> void:
	if state=="trial": end_trial()
	if state=="shop" and not save_checkpoint():
		ui.show_shop()
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui): request_quit()

func _exit_tree() -> void:
	# A looping playback can otherwise retain its stream during engine shutdown.
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream=null
	for channel in audio:
		if is_instance_valid(channel):
			channel.stop()
			channel.stream=null

func return_title() -> void:
	if not checkpoint_loading:
		if state=="trial": end_trial()
		if state=="shop" and not save_checkpoint():
			ui.show_shop()
			return
	close_personal()
	encounters.clear()
	combat_rewards.reset(0)
	if state=="trial": _clear_trial()
	director.clear()
	boss_encounter.clear()
	clear_magic()
	hostile_shots.clear()
	effects.clear()
	gems.clear()
	for enemy in enemies: enemy.queue_free()
	enemies.clear()
	clear_chests()
	grid.clear()
	boss_ref=null
	state="title"
	set_arena_profile("scroll")
	player.position=FIELD.get_center()
	player.moving=false
	player.facing_left=false
	player.modulate=Color.WHITE
	player.flash=0
	_sync_camera()
	set_music("prepare")
	ui.show_title()

func set_arena_profile(profile: String) -> void:
	assert(profile in ["scroll","trial","measurement"])
	arena_profile=profile
	var rect := FIELD if profile=="scroll" else Rect2(0,0,1440,900)
	arena.configure(rect,profile!="scroll")
	camera.limit_left=int(rect.position.x)
	camera.limit_top=int(rect.position.y)
	camera.limit_right=int(rect.end.x)
	camera.limit_bottom=int(rect.end.y)
	camera.zoom=Vector2.ONE
	_sync_camera()

func logical_view_size() -> Vector2:
	# Canvas-items stretch exposes the 1600x900 logical view at 1920x1080.
	return get_viewport_rect().size

func visible_world_rect() -> Rect2:
	var size := logical_view_size()/camera.zoom
	if arena_profile!="scroll": return Rect2(Vector2(720,450)-size*.5,size)
	var center := player.position.clamp(FIELD.position+size*.5,FIELD.end-size*.5)
	return Rect2(center-size*.5,size)

func _sync_camera() -> void:
	if not is_instance_valid(camera): return
	camera.position=player.position if arena_profile=="scroll" else Vector2(720,450)
	camera.reset_smoothing()
	camera.force_update_scroll()

func player_bounds() -> Rect2:
	return FIELD.grow(-112) if arena_profile=="scroll" else FIXED_FIELD

func enemy_bounds() -> Rect2:
	return FIELD.grow(-32) if arena_profile=="scroll" else Rect2(35,95,1370,700)

func projectile_bounds() -> Rect2:
	return FIELD.grow(96) if arena_profile=="scroll" else Rect2(-80,-80,1600,1060)

func screen_mouse_position() -> Vector2:
	return ui.root.get_local_mouse_position()

func _bind_inputs() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"dash":[KEY_SPACE],"recipe":[KEY_TAB],"pause_game":[KEY_ESCAPE],"mute":[KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _input(event: InputEvent) -> void:
	if not ui.front_screen.is_empty():
		if event is InputEventKey and event.echo: return
		if event.is_action_pressed("pause_game"):
			ui.front_back()
			get_viewport().set_input_as_handled()
		# Front screens use Tab for GUI focus; it must not invoke the combat editor.
		return
	# Tab/Esc must reach the game even while a drawer button or slot owns GUI input.
	if event.is_action_pressed("recipe") or event.is_action_pressed("pause_game") or event.is_action_pressed("mute"):
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if combat_rewards.paused() and state=="combat":
		if combat_rewards.stage=="edit" and (event.is_action_pressed("recipe") or event.is_action_pressed("pause_game")): close_personal()
		return
	if event.is_action_pressed("mute"):
		sound_enabled = not sound_enabled
		save_settings()
		announce("효과음 켜짐" if sound_enabled else "효과음 꺼짐")
	if event.is_action_pressed("recipe"):
		if state == "combat":
			if not personal_tab.is_empty(): close_personal()
			else: open_editor()
		elif state in ["edit","shop"]: apply_recipe()
		elif state == "trial": end_trial()
	if event.is_action_pressed("pause_game"):
		if get_viewport().gui_is_dragging():
			get_viewport().gui_cancel_drag()
			get_viewport().set_input_as_handled()
			return
		if not personal_tab.is_empty():
			close_personal()
			get_viewport().set_input_as_handled()
			return
		if state == "combat":
			state = "paused"
			ui.show_pause()
		elif state == "paused": resume_game()
		elif state == "edit": cancel_editor()
		elif state == "trial": end_trial()

func start_run(kit := "") -> bool:
	if record_runs and not checkpoint_loading and not checkpoint_store.close():
		checkpoint_message=checkpoint_store.warning
		return false
	run_id=Crypto.new().generate_random_bytes(16).hex_encode()
	checkpoint_clock=0
	checkpoint_message=""
	close_personal()
	encounters.begin_wave()
	combat_rewards.reset(rng.randi())
	role_migration_receipt = {}
	ui.selected_item=""
	ui.board_panel="shop"
	ui.craft_tab="craft"
	ui.bag_filter="all"
	ui.bag_scroll=0
	ui.catalog_scroll.clear()
	shop_tab = "shop"
	forge_target = ""
	forge_material = ""
	forge_message = ""
	result_win = false
	final_boss_started=false
	orb_upgrades=[0]
	orb_growth=[OrbGrowth.fresh()]
	orb_buffer_ready=[0.0]
	orb_growth_open=-1
	workshop_relics.clear()
	clear_chests()
	end_reason=""
	run_record.clear()
	wave_records.clear()
	prep_elapsed=0
	boss_spawn_wait=0
	if boss_encounter!=null: boss_encounter.clear()
	if Economy.KITS.has(kit): selected_kit = kit
	if state == "trial": _clear_trial()
	relics.reset(rng.randi())
	edit_revision += 1
	edit_history.clear()
	purchased_orb = ""
	for enemy in enemies: enemy.queue_free()
	enemies.clear()
	clear_magic()
	hostile_shots.clear()
	effects.clear()
	gems.clear()
	grid.clear()
	recipe = Spells.fixed_slots(Economy.KITS[selected_kit].recipe)
	active_orb = 0
	selected_group = 0
	orb_recipes = [recipe.duplicate()]
	orb_drafts = orb_recipes.duplicate(true)
	orb_compiled = [Spells.compile(recipe).stages]
	orb_trial = []
	for _i in orb_recipes.size(): orb_trial.append([])
	orb_clocks = [Spells.interval(orb_compiled[0])]
	orb_cursors = [0]
	draft = recipe.duplicate()
	workbench_message = ""
	economy.reset(selected_kit)
	shop_time = 0
	shop_message = ""
	reward_taken = false
	reward_options.clear()
	previous_state = "combat"
	compiled = Spells.compile(recipe).stages
	hp = 100
	max_hp = 100
	power = 1
	fire_rate = 1
	kills = 0
	wave = 1
	wave_time = 0
	elapsed = 0
	wave_kills = 0
	director.reset()
	cast_clock = cast_delay(Spells.interval(compiled))
	dash_cooldown = 0
	dash_left = 0
	invincible = 1
	boss_ref = null
	metrics = {"casts":0,"triggers":0,"hits":0,"peak_projectiles":0,"peak_enemies":0}
	player.position = FIELD.get_center() if arena_profile=="scroll" else Vector2(720,450)
	_sync_camera()
	player.modulate = Color.WHITE
	player.moving=false
	player.flash=0
	state = "combat"
	set_music("combat")
	ui.close_modal()
	ui.rebuild_recipe()
	announce("실습 시작!  가까운 적 자동 조준 · Space 회피 · Tab 실시간 조합",5)
	discover_owned()
	return true

func _physics_process(delta: float) -> void:
	# Preparation ends only with the player's Ready button.
	if state=="combat":
		combat_rewards.tick()
		if combat_rewards.paused(): return
	if state == "trial":
		_update_trial(delta)
		return
	if state != "combat":
		if state in ["shop","edit"]: prep_elapsed+=delta
		if state=="shop":
			checkpoint_clock+=delta
			if checkpoint_clock>=5:
				checkpoint_clock=0
				save_checkpoint()
		player.animate(delta * 0.5)
		return
	if wave<5 and wave_time>=RunContent.REST_SECONDS:
		complete_wave()
		return
	if wave==5 and not final_boss_started and elapsed>=RunContent.RUN_SECONDS:
		begin_final_boss()
	if final_boss_started and not is_instance_valid(boss_ref):
		# Missing boss never consumes the player's fight time. Retry independently of spawn streams.
		boss_spawn_wait+=delta
		if _ensure_boss(): boss_spawn_wait=0
		else: return
	if not final_boss_started: delta=minf(delta,maxf(0,RunContent.REST_SECONDS-wave_time))
	elapsed += delta
	wave_time += delta
	relics.tick(delta)
	invincible = maxf(0,invincible-delta)
	dash_cooldown = maxf(0,dash_cooldown-delta)
	sound_clock = maxf(0,sound_clock-delta)
	notice_left = maxf(0,notice_left-delta)
	var movement := Input.get_vector("move_left","move_right","move_up","move_down")
	if movement.length_squared() > 0.01: last_move = movement
	if Input.is_action_just_pressed("dash"): try_dash(movement)
	if dash_left > 0:
		dash_left -= delta
		player.position += dash_direction * 750.0 * delta
	else:
		player.position += movement * 240.0 * relics.movement_multiplier() * delta
	var walk := player_bounds()
	player.position = player.position.clamp(walk.position,walk.end)
	_sync_camera()
	# Orb targeting is updated only when an orb actually casts.
	player.moving = movement.length_squared() > 0.01 or dash_left > 0
	player.facing_left = aim.x < 0
	player.animate(delta)
	player.modulate.a = 0.45 if invincible > 0 and int(elapsed*14)%2 == 0 else 1.0
	_rebuild_grid()
	_update_enemies(delta)
	if state != "combat": return
	_recycle_distant_enemies()
	_tick_orbs(delta)
	_rebuild_grid()
	_update_projectiles(delta)
	if state != "combat": return
	magic.update_zones(delta)
	if state != "combat": return
	_update_hostile_shots(delta)
	if state != "combat": return
	_update_gems(delta)
	_update_effects(delta)
	director.update()
	encounters.update(delta)
	combat_rewards.tick()
	_remove_dead()
	if combat_rewards.paused():
		ui.update_hud()
		return
	if wave < 5 and wave_time >= RunContent.REST_SECONDS: complete_wave()
	elif wave==5 and not final_boss_started and elapsed>=RunContent.RUN_SECONDS: begin_final_boss()
	metrics.peak_projectiles = maxi(metrics.peak_projectiles,projectiles.size())
	metrics.peak_enemies = maxi(metrics.peak_enemies,enemies.size())
	visuals.queue_redraw()
	actor_shadows.queue_redraw()
	actor_health.queue_redraw()
	ui_clock += delta
	if ui_clock >= 0.1:
		ui_clock = 0
		ui.update_hud()

func try_dash(movement: Vector2) -> bool:
	if combat_rewards.paused(): return false
	if dash_cooldown > 0 or not state in ["combat","trial"]: return false
	dash_direction = movement if movement.length_squared() > 0.01 else last_move
	dash_left = 0.19
	dash_cooldown = 1.7
	invincible = maxf(invincible,0.28)
	ring(player.position,36,Color("dfb6f5"),0.3)
	play_sound("dash")
	return true

func _update_auto_aim(targets: Array = []) -> void:
	if targets.is_empty(): targets=AutoTargeting.ranked(self)
	ensure_orb_growth()
	cast_target = AutoTargeting.point_for(self,targets,0 if OrbGrowth.amount(orb_growth[active_orb],"focus") else active_orb)
	var direction := player.position.direction_to(cast_target)
	if not direction.is_zero_approx(): aim = direction
	player.facing_left = aim.x < 0

func _update_mouse_aim() -> void:
	# Compatibility entry for old probes; no cursor reads remain in the aiming path.
	_update_auto_aim()

func cast_spell() -> bool:
	if not magic_active() or (trial_stages if state=="trial" else compiled).is_empty(): return false
	_update_auto_aim()
	var stages: Array = trial_stages if state=="trial" else compiled
	var command := Spells.next_cast(stages,orb_cursors[active_orb])
	if command.is_empty(): return false
	var stage: Dictionary = command.stage.duplicate(true)
	stage["_orb"] = active_orb
	emit_stage(stage,player.position+aim*22,aim,Spells.follow(stage),1.0)
	orb_cursors[active_orb] = command.cursor
	metrics.casts += 1
	play_sound("cast")
	return true

func clear_magic() -> void:
	projectiles.clear()
	magic.clear()
	if is_instance_valid(visuals): visuals.queue_redraw()
	actor_shadows.queue_redraw()
	actor_health.queue_redraw()

func emit_stage(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, target_point := Vector2.INF) -> void:
	if not magic_active(): return
	if meter != null and magic_active(): meter.count("casts")
	if target_point==Vector2.INF: target_point=cast_target
	ensure_orb_growth()
	stage=OrbGrowth.decorate(stage,orb_growth[int(stage.get("_orb",active_orb))])
	follow=Spells.follow(stage)
	magic.emit(stage,origin,direction,follow,factor,-1.0,"primary",false,-1,-1,target_point)
	if relics.direct_cast() and magic_active():
		var copy := stage.duplicate(true)
		copy["_relic_copy"] = true
		var rotated := direction.rotated(relics.rng.randf_range(-PI,PI))
		var point := origin+rotated*origin.distance_to(target_point)
		magic.track("relic_copies")
		magic.emit(copy,origin,rotated,follow,factor,caster_power()*.4*float(stage.get("_orb_power",1.0)),"primary",false,-1,-1,point)
		ring(origin,26,Color("dfb6f5"),.2)

func caster_power() -> float:
	return power*relics.damage_multiplier(economy.gold)

func cast_delay(delay: float) -> float:
	return delay/fire_rate*relics.timing_multiplier()

func acquire_relic(id: String) -> bool:
	if not relics.acquire(id): return false
	discover_owned()
	announce("유물 완성 · "+Relics.definition(id).name)
	ui.refresh_relics()
	return true

func _update_projectiles(delta: float) -> void:
	magic.update_echoes(delta)
	magic.update_projectiles(delta)

func explode(at: Vector2, damage: float, radius: float, source := "", shares: Dictionary = {}) -> void:
	if meter != null: meter.count("explosions",source)
	ring(at,radius,Color("ffc79f"),0.32)
	for enemy in nearby(at,radius+35):
		if not enemy.dead and enemy.position.distance_squared_to(at) <= pow(radius+enemy.radius,2):
			damage_enemy(enemy,damage,at.direction_to(enemy.position),source,shares)
			if meter != null: meter.count("explosion_victims",source)
			if not magic_active(): return
	if sound_clock <= 0:
		play_sound("pop")
		sound_clock = 0.07

func damage_enemy(enemy: Node2D, amount: float, direction: Vector2, source := "", shares: Dictionary = {}) -> void:
	if enemy.dead: return
	if state == "trial":
		trial_damage += amount
		trial_hits += 1
		enemy.flash = 0.1
		return
	if meter != null:
		if shares.is_empty(): meter.damage(source,amount,enemy.hp,enemy.get_instance_id())
		else: meter.damage_split(amount,enemy.hp,enemy.get_instance_id(),shares)
	enemy.hp -= amount
	enemy.flash = 0.1
	metrics.hits += 1
	if not enemy.boss: enemy.position += direction*(.6 if enemy.role=="sentinel" else 6.0)
	if enemy.hp <= 0:
		enemy.dead = true
		kills += 1
		wave_kills += 1
		if relics.kill():
			ring(player.position,30,Color("a8efe2"),.3)
			magic.track("relic_shield_gained")
		encounters.died(enemy)
		if enemy.role=="sentinel": drop_chest(enemy.position)
		var coins: int = 0 if enemy.role in ["carrier","escort"] else director.reward(enemy.kind)
		if coins > 0: gems.append({"pos":enemy.position,"value":coins})
		burst(enemy.position,Color("dfb6f5"),5)
		if enemy.boss: end_run(true)

func clear_chests() -> void:
	for chest in chests:
		if is_instance_valid(chest.label): chest.label.queue_free()
	chests.clear()

func drop_chest(at: Vector2) -> void:
	var label:=Label.new()
	label.text="▣ 보상 상자"
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",Color("ffe7a3"))
	label.add_theme_color_override("font_outline_color",Color("171d2b"))
	label.add_theme_constant_override("outline_size",5)
	label.position=at+Vector2(-50,-28)
	actors.add_child(label)
	chests.append({"pos":at,"label":label})
	ring(at,32,Color("ffe7a3"),1)

func collect_chests(all := false) -> void:
	for i in range(chests.size()-1,-1,-1):
		if not all and chests[i].pos.distance_squared_to(player.position)>70.0*70.0: continue
		combat_rewards.queue_chest()
		chests[i].label.queue_free()
		chests.remove_at(i)

func claim_fusion(id: String) -> bool:
	_sync_orb()
	var quote: Dictionary=economy.fusion_quote(id)
	if not quote.ok: return false
	var target: String=quote.consumed[0]
	var applied:=Forge.reconcile(orb_recipes,target,quote,active_orb)
	var edited:=Forge.reconcile(orb_drafts,target,quote,active_orb)
	if not Forge.valid(applied,quote.inventory) or not Forge.valid(edited,quote.inventory): return false
	economy.inventory=quote.inventory
	economy.fusion_history.append(id)
	economy.revision+=1
	orb_recipes=applied
	orb_drafts=edited
	for i in orb_recipes.size():
		var parsed:=Spells.compile(applied[i])
		orb_compiled[i]=parsed.stages
	recipe=orb_recipes[active_orb].duplicate()
	draft=orb_drafts[active_orb].duplicate()
	compiled=orb_compiled[active_orb]
	edit_history.clear()
	edit_revision+=1
	magic.generation+=1
	_reset_orb_clocks()
	ui.selected_item=id
	return true

func begin_final_boss() -> void:
	final_boss_started=true
	clear_magic()
	hostile_shots.clear()
	boss_encounter.clear()
	_ensure_boss()
	director.reset()
	set_music("boss")
	announce("30분 생존! 마지막 폭주를 멈추면 승리야.",6)

func spawn_enemy(forced_kind := -1, is_boss := false, requested := Vector2.INF, role := "normal") -> Node2D:
	var config: Dictionary = Waves.config(wave)
	var living := 0
	var ranged := 0
	var heavy := 0
	var sentinels := 0
	for e in enemies:
		if not e.dead:
			living += 1
			if e.kind == 2: ranged += 1
			if e.role=="sentinel": sentinels+=1
			elif e.kind == 3 and not e.boss: heavy += 1
	if is_boss and is_instance_valid(boss_ref) and not boss_ref.dead: return boss_ref
	if not is_boss and living >= mini(MAX_ENEMIES,int(config.cap)): return null
	var kind := forced_kind if forced_kind >= 0 else 1
	if kind == 2 and ranged >= int(config.ranged_cap): return null
	if role=="sentinel" and sentinels>=1: return null
	if kind == 3 and not is_boss and role!="sentinel" and heavy >= int(config.heavy_cap): return null
	var radius := 45.0 if is_boss else (32.0 if role=="sentinel" else (16.0 if role == "line" else (26.0 if kind==3 else 20.0)))
	var point: Vector2 = requested
	if is_boss and arena_profile!="scroll" and point == Vector2.INF and director.available(Vector2(720,180),radius):
		point = Vector2(720,180)
	if point == Vector2.INF:
		point = director.random_spawn_point(radius)
	if point == Vector2.INF or not director.available(point,radius,role in ["carrier","escort","sentinel"]): return null
	var enemy := Actor.new()
	actors.add_child(enemy)
	enemy.position = point
	enemy.role = role
	enemy.setup(art,kind,is_boss)
	enemy.hp = (Waves.ENEMY_HEALTH[kind] if role != "swarm" else Waves.SWARM_HEALTH)*float(config.hp_scale)
	enemy.speed = Waves.ENEMY_SPEED[kind]+wave*3
	if role=="swarm": enemy.speed=Waves.SWARM_SPEED+wave*2
	if role=="carrier": enemy.hp=85+wave*12; enemy.speed=185; enemy.radius=22
	if role=="escort": enemy.hp=35*float(config.hp_scale); enemy.speed=145
	if role=="sentinel": enemy.hp=(350+elapsed*1.5); enemy.speed=192+wave*3
	if role == "line": enemy.speed += 8
	if role!="carrier": enemy.radius = radius
	enemy.cooldown = rng.randf_range(1.4,2.8)
	if role in ["swarm","line"]: enemy.art_scale *= 0.85
	if is_boss:
		enemy.hp = Waves.BOSS_HEALTH
		enemy.radius = 45
		enemy.speed = 48
		boss_ref = enemy
		enemy.visual_tint=Color("e0b4f4")
	enemy.max_hp = enemy.hp
	enemies.append(enemy)
	ring(point,30,Color("ff9cae"),0.5)
	return enemy

func _ensure_boss() -> bool:
	if is_instance_valid(boss_ref) and not boss_ref.dead: return true
	if spawn_enemy(3,true)!=null: return true
	# Deterministic fallback searches the off-screen perimeter, never directly on the player.
	var frame: Rect2=director.spawn_frame()
	for edge in 4:
		for fraction in [.1,.3,.5,.7,.9]:
			var along: float=lerpf(frame.position.y,frame.end.y,fraction) if edge<2 else lerpf(frame.position.x,frame.end.x,fraction)
			var point: Vector2=director.edge_point(edge,along,frame)
			if director.available(point,45) and spawn_enemy(3,true,point)!=null: return true
	if boss_spawn_wait>3:
		# Remove only off-screen support blocking entrances; those enemies give no currency.
		for enemy in enemies:
			if not enemy.boss and not visible_world_rect().grow(24).has_point(enemy.position): enemy.dead=true
		_remove_dead()
	return false

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.dead: continue
		var status_speed: float = magic.behavior.movement_factor(enemy)
		if status_speed<=0:
			enemy.moving = false
			enemy.animate(delta)
			continue
		enemy.cooldown -= delta
		var direction: Vector2 = enemy.position.direction_to(player.position)
		var distance: float = enemy.position.distance_to(player.position)
		var velocity: Vector2 = direction*enemy.speed
		if enemy.boss:
			velocity=boss_encounter.update(enemy,delta)
			if state!="combat": return
		elif enemy.role in ["carrier","escort"]:
			velocity=encounters.velocity(enemy)
		elif enemy.kind == 2:
			if distance < 240: velocity = -direction*enemy.speed*0.5
			elif distance < 330: velocity = direction.orthogonal()*enemy.speed*0.4
			if enemy.shot_windup > 0:
				velocity = Vector2.ZERO
				enemy.shot_windup -= delta
				if enemy.shot_windup <= 0:
					if hostile_shots.size() < 100:
						hostile_shots.append({"pos":enemy.position,"vel":enemy.shot_direction*165,"life":5.0})
					enemy.cooldown = 2.7
			elif enemy.cooldown <= 0 and distance < 650:
				enemy.shot_windup = 0.7
				enemy.shot_direction = direction
		if enemy.kind == 3 and not enemy.boss and enemy.role!="sentinel":
			if enemy.windup > 0:
				enemy.windup -= delta
				velocity = Vector2.ZERO
				if enemy.windup <= 0:
					enemy.charge_time = Waves.CHARGE_SECONDS
					if enemy.boss and hostile_shots.size() <= 88:
						for i in 12:
							hostile_shots.append({"pos":enemy.position,"vel":Vector2.RIGHT.rotated(i*TAU/12)*145,"life":5.0})
			elif enemy.charge_time > 0:
				var step: float=minf(delta,enemy.charge_time)
				enemy.charge_time=maxf(0,enemy.charge_time-delta)
				velocity = enemy.charge_direction*Waves.CHARGE_SPEED*step/maxf(delta,.00001)
				if enemy.charge_time<=0: enemy.recovery_left=Waves.CHARGE_RECOVERY
			elif enemy.recovery_left>0:
				enemy.recovery_left=maxf(0,enemy.recovery_left-delta)
				velocity=Vector2.ZERO
			elif enemy.cooldown <= 0:
				enemy.windup = 0.8
				enemy.charge_direction = direction
				enemy.cooldown = 3.8
		# Cache local steering at 10Hz; movement/attacks still simulate every physics tick.
		enemy.separation_left-=delta
		if enemy.separation_left<=0:
			enemy.separation_left=.10
			var separation := Vector2.ZERO
			for other in nearby(enemy.position,50):
				if other==enemy or other.dead: continue
				var offset: Vector2=enemy.position-other.position
				var d2:=offset.length_squared()
				if d2>.1 and d2<pow(enemy.radius+other.radius,2): separation+=offset.normalized()*35
			enemy.separation_velocity=separation.limit_length(60)
		enemy.position+=(velocity+enemy.separation_velocity)*delta*status_speed
		var bounds := enemy_bounds()
		enemy.position = enemy.position.clamp(bounds.position,bounds.end)
		enemy.moving = velocity.length_squared() > 1
		enemy.facing_left = velocity.x<0 if enemy.role in ["carrier","escort"] and absf(velocity.x)>.01 else direction.x<0
		enemy.animate(delta)
		if enemy.role!="carrier" and enemy.position.distance_to(player.position) < enemy.radius+player.radius:
			hurt_player(22 if enemy.kind == 3 else 12)
			if state != "combat": return

func _recycle_distant_enemies() -> void:
	if arena_profile!="scroll": return
	var keep := visible_world_rect().grow(420)
	var relocated := 0
	for enemy in enemies:
		if relocated>=3: break
		if enemy.dead or enemy.boss or enemy.role in ["carrier","escort","sentinel"] or keep.has_point(enemy.position): continue
		var point: Vector2=director.random_spawn_point(enemy.radius)
		if point==Vector2.INF: continue
		enemy.position=point
		enemy.windup=0
		enemy.charge_time=0
		enemy.shot_windup=0
		enemy.cooldown=maxf(enemy.cooldown,1)
		if meter!=null: meter.count("enemies_relocated")
		relocated+=1

func hurt_player(amount: float) -> void:
	if combat_rewards.paused(): return
	if invincible > 0 or state != "combat": return
	if amount<=0: return
	var result := relics.take_damage(amount)
	if meter != null:
		meter.count("player_damage","",minf(hp,result.health))
		meter.count("shield_absorbed","",result.shield)
		meter.count("player_hits")
	hp = maxf(0,hp-result.health)
	if result.health>0 or result.shield>0:
		ensure_orb_growth()
		for i in orb_recipes.size():
			if OrbGrowth.amount(orb_growth[i],"buffer")>0 and elapsed>=float(orb_buffer_ready[i]):
				orb_clocks[i]=0.0
				orb_buffer_ready[i]=elapsed+8.0
	if result.speed:
		announce("도망쟁이 구두 · 이동 속도 증가",1.2)
		magic.track("relic_shoes_activated")
	invincible = 0.85
	player.flash = 0.15
	ring(player.position,35,Color("ff778e"),0.25)
	play_sound("hurt")
	if hp <= 0:
		end_reason="실패작에게 쓰러졌어. 교수님이 실험을 멈춰줬다."
		end_run(false)

func _update_hostile_shots(delta: float) -> void:
	for i in range(hostile_shots.size()-1,-1,-1):
		var shot: Dictionary = hostile_shots[i]
		var old: Vector2 = shot.pos
		var slow := .65 if relics.has("droplet") and shot.pos.distance_squared_to(player.position)<=Relics.SLOW_RADIUS*Relics.SLOW_RADIUS else 1.0
		shot.pos += shot.vel*delta*slow
		if slow<1: magic.track("hostile_slow_seconds","",delta)
		shot.life -= delta
		var nearest := Geometry2D.get_closest_point_to_segment(player.position,old,shot.pos)
		if nearest.distance_to(player.position) < 20:
			hurt_player(10)
			if not magic_active(): return # A fatal hit clears the hostile array.
			hostile_shots.remove_at(i)
		elif shot.life <= 0 or not projectile_bounds().has_point(shot.pos): hostile_shots.remove_at(i)

func _update_gems(delta: float) -> void:
	collect_chests()
	for i in range(gems.size()-1,-1,-1):
		var gem: Dictionary = gems[i]
		var distance: float = gem.pos.distance_to(player.position)
		if distance < 145:
			gem.pos = gem.pos.move_toward(player.position,(200+(145-distance)*5)*delta)
		if distance < 20:
			gain_money(gem.value,true)
			gems.remove_at(i)
	# Merge old drops rather than accumulating unbounded collectible nodes.
	if gems.size() > 200:
		var first: Dictionary = gems.pop_front()
		gems[0].value += first.value

func gain_money(value: int, combat_drop := false) -> void:
	if state=="trial": return
	economy.grant(value)
	if combat_drop and state=="combat": combat_rewards.gain_xp(value*combat_rewards.XP_PER_STONE)
	if combat_drop and state in ["combat","reward"]:
		var healing := relics.collect(value)
		if healing>0:
			var restored := minf(max_hp-hp,healing)
			hp += restored
			magic.track("relic_healing","",restored)
			if restored>0: ring(player.position,24,Color("a8efe2"),.25)

func _rebuild_grid() -> void:
	grid.clear()
	for enemy in enemies:
		if enemy.dead: continue
		var key := Vector2i(floori(enemy.position.x/GRID_SIZE),floori(enemy.position.y/GRID_SIZE))
		if not grid.has(key): grid[key] = []
		grid[key].append(enemy)

func nearby(at: Vector2, radius: float) -> Array:
	var result: Array = []
	var low := Vector2i(floori((at.x-radius)/GRID_SIZE),floori((at.y-radius)/GRID_SIZE))
	var high := Vector2i(floori((at.x+radius)/GRID_SIZE),floori((at.y+radius)/GRID_SIZE))
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			for candidate in grid.get(Vector2i(x,y),[]):
				# A caller can query between physics frames after queued deaths were freed.
				if is_instance_valid(candidate) and not candidate.dead:
					result.append(candidate)
	return result

func nearest_enemy(at: Vector2, radius: float, excluded: Dictionary = {}) -> Node2D:
	var best: Node2D = null
	var best_distance := radius*radius
	for enemy in nearby(at,radius):
		if enemy.dead or excluded.has(enemy.get_instance_id()): continue
		var d: float = at.distance_squared_to(enemy.position)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best

func _remove_dead() -> void:
	for i in range(enemies.size()-1,-1,-1):
		if enemies[i].dead:
			enemies[i].queue_free()
			enemies.remove_at(i)

func complete_wave() -> void:
	if state != "combat" or wave >= 5: return
	collect_chests(true)
	for gem in gems: gain_money(gem.value,true)
	gems.clear()
	combat_rewards.tick()
	if combat_rewards.paused(): return
	close_personal()
	combat_rewards.finish_wave()
	encounters.clear()
	# If no spell choice was earned, return only withheld value from actual kills.
	if not combat_rewards.issued.has(wave):
		var restored: int=maxi(0,director.potential-director.dropped)
		if restored>0: gain_money(restored,true)
	director.clear()
	set_music("prepare")
	for gem in gems: gain_money(gem.value,true)
	gems.clear()
	state = "reward"
	for enemy in enemies: enemy.queue_free()
	enemies.clear()
	grid.clear()
	clear_magic()
	hostile_shots.clear()
	effects.clear()
	hp = minf(max_hp,hp+15)
	relics.end_wave()
	reward_taken = false
	economy.grant(Economy.CLEAR_REWARD)
	wave_records.append({"wave":wave,"seconds":wave_time,"kills":wave_kills,"earned":economy.total_earned,"recipes":orb_recipes.duplicate(true)})
	reward_options.clear()
	_enter_preparation()
	visuals.queue_redraw()
	actor_shadows.queue_redraw()
	actor_health.queue_redraw()
	play_sound("reward")

func choose_reward(id: String) -> void:
	migrate_spell_roles()
	if state != "reward" or reward_taken or not reward_options.has(id): return
	if not acquire_relic(id): return
	reward_taken = true
	_enter_preparation()

func _enter_preparation() -> void:
	reward_taken = true
	_sync_orb()
	orb_drafts = orb_recipes.duplicate(true)
	draft = recipe.duplicate()
	edit_history.clear()
	edit_revision += 1
	purchased_orb = ""
	shop_time = SHOP_SECONDS
	shop_tab = "shop"
	shop_message = RunContent.chapter(wave).craft
	ui.board_panel="shop"
	economy.roll(rng,recipe)
	workshop_relics=relics.choices(rng)
	state = "shop"
	ui.show_shop()

func is_shopping() -> bool:
	return state == "shop" or (state == "edit" and previous_state == "shop")

func ensure_orb_growth() -> void:
	while orb_growth.size()<orb_recipes.size(): orb_growth.append(OrbGrowth.fresh())
	while orb_upgrades.size()<orb_recipes.size(): orb_upgrades.append(0)
	orb_buffer_ready.resize(orb_recipes.size())
	for i in orb_buffer_ready.size():
		if orb_buffer_ready[i]==null: orb_buffer_ready[i]=0.0

func orb_capacity(index: int) -> int:
	ensure_orb_growth()
	return OrbGrowth.capacity(orb_growth[index])

func orb_capacities() -> Array:
	ensure_orb_growth()
	return orb_growth.slice(0,orb_recipes.size()).map(func(value):return OrbGrowth.capacity(value))

func orb_delay(delay: float, index: int, sequential := false) -> float:
	ensure_orb_growth()
	var value: Dictionary=orb_growth[index]
	return cast_delay(delay)*((1.0-.2*OrbGrowth.amount(value,"sequence"))*float(value.legacy_sequence) if sequential else OrbGrowth.cycle(value))

func extra_orb_cost() -> int:
	return OrbGrowth.ORB_COSTS[orb_recipes.size()-1] if orb_recipes.size()<OrbGrowth.MAX_ORBS else 0

func extra_orb_unlocked() -> bool:
	return state=="shop" and orb_recipes.size()<OrbGrowth.MAX_ORBS and wave>=orb_recipes.size()

func open_orb_growth(index: int, revision: int) -> bool:
	if state!="shop" or revision!=economy.revision or index!=active_orb: return false
	ensure_orb_growth()
	var value: Dictionary=orb_growth[index]
	if value.rank>=OrbGrowth.MAX_RANK: return false
	var pool:=OrbGrowth.eligible(value,Spells.compile(orb_drafts[index]).stages,orb_recipes.size())
	if value.offers.size()!=3 or not value.offers.all(func(id):return id in pool):
		value.offers=[]
		while value.offers.size()<3 and not pool.is_empty():
			value.offers.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	if value.offers.size()!=3: return false
	orb_growth_open=index
	ui.show_shop()
	return true

func choose_orb_growth(id: String, index: int, rank: int, revision: int) -> bool:
	if state!="shop" or revision!=economy.revision or index!=active_orb or index!=orb_growth_open: return false
	var value: Dictionary=orb_growth[index]
	if rank!=value.rank or rank>=OrbGrowth.MAX_RANK or id not in value.offers: return false
	if id not in OrbGrowth.eligible(value,Spells.compile(orb_drafts[index]).stages,orb_recipes.size()): return false
	var price:=OrbGrowth.cost(value)
	if economy.gold<price: return false
	economy.gold-=price
	economy.revision+=1
	value.picks[id]=OrbGrowth.amount(value,id)+1
	value.rank+=1
	value.offers=[]
	orb_upgrades[index]=value.rank
	orb_growth_open=-1
	if id=="socket":
		orb_recipes[index].append("")
		orb_drafts[index].append("")
		if index==active_orb:
			recipe=orb_recipes[index].duplicate()
			draft=orb_drafts[index].duplicate()
	edit_revision+=1
	ui.rebuild_recipe()
	ui.show_shop()
	play_sound("reward")
	return true

func equipped_count(id: String, use_draft := true) -> int:
	var count:=0
	for parts in (orb_drafts if use_draft else orb_recipes): count+=parts.count(id)
	return count

func other_orb_parts() -> Array:
	var parts: Array=[]
	for i in orb_drafts.size():
		if i!=active_orb: parts.append_array(orb_drafts[i])
	return parts

func workshop_buy(action: String, revision: int, expected_orb := -1) -> bool:
	if state!="shop" or revision!=economy.revision: return false
	var price := 0
	if action=="orb":
		if not extra_orb_unlocked(): return false
		price=extra_orb_cost()
	elif action=="upgrade":
		return open_orb_growth(expected_orb,revision)
	elif action.begins_with("relic:"):
		var id:=action.trim_prefix("relic:")
		if not id in workshop_relics or relics.has(id): return false
		price=80
	else: return false
	if economy.gold<price: return false
	economy.gold-=price
	economy.revision+=1
	if action=="orb":
		orb_recipes.append(Spells.fixed_slots([]))
		orb_drafts.append(Spells.fixed_slots([]))
		orb_compiled.append([])
		orb_trial.append([])
		orb_clocks.append(0.0)
		orb_cursors.append(0)
		orb_upgrades.append(0)
		orb_growth.append(OrbGrowth.fresh())
		orb_buffer_ready.append(0.0)
		edit_history.clear()
		edit_revision+=1
	else: acquire_relic(action.trim_prefix("relic:"))
	ui.rebuild_recipe()
	ui.show_shop()
	return true

func buy_orb(index: int, revision: int) -> bool:
	if state != "shop" or shop_time <= 0: return false
	if not economy.buy(index,revision): return false
	apply_acquisition(economy.last_acquisition)
	purchased_orb = economy.last_acquisition.output
	discover_owned()
	shop_message = "%s 제작 완료 · 아래 보유 목록에서 끌어 넣고 시험해봐." % Spells.definition(purchased_orb).name
	ui.show_shop()
	play_sound("reward")
	return true

func set_shop_tab(tab: String) -> void:
	if state!="shop" or not tab in ["shop","forge"]: return
	shop_tab = tab
	ui.show_shop()

func select_forge_item(id: String) -> void:
	if state!="shop" or not Spells.has_part(id) or economy.inventory.get(id,0)<=0: return
	forge_target = id
	forge_material = ""
	forge_message = ""
	ui.show_shop()

func select_fusion(id: String) -> void:
	if state!="shop" or not Spells.Progression.FUSIONS.has(id): return
	var parents: Array = Spells.Progression.FUSIONS[id].parents
	forge_target = Spells.Progression.key(parents[0],3)
	forge_material = Spells.Progression.key(parents[1],3)
	forge_message = ""
	ui.show_shop()

func craft_spell(action: String, target: String, material: String, expected_revision: int) -> bool:
	if state!="shop" or shop_time<=0 or expected_revision!=economy.revision: return false
	_sync_orb()
	var quote: Dictionary = economy.craft_quote(action,target,material)
	if not quote.ok:
		forge_message = quote.error
		ui.show_shop()
		return false
	var selected_slot: int = ui.inspected_slot if ui.inspected_orb==active_orb and ui.selected_item==target else -1
	var applied := Forge.reconcile(orb_recipes,target,quote,active_orb,selected_slot)
	var output_location := {}
	var edited := Forge.reconcile(orb_drafts,target,quote,active_orb,selected_slot,output_location)
	if not Forge.valid(applied,quote.inventory) or not Forge.valid(edited,quote.inventory):
		forge_message = "조합의 빈 공격·연결을 먼저 정리해줘. 재료와 마석은 사용하지 않았어."
		ui.show_shop()
		return false
	var receipt: Dictionary = economy.craft(action,target,material,expected_revision)
	if not receipt.ok: return false
	orb_recipes = applied
	orb_drafts = edited
	for i in orb_recipes.size():
		orb_compiled[i] = Spells.compile(applied[i]).stages if not applied[i].is_empty() else []
		orb_cursors[i] = 0
		orb_clocks[i] = maxf(orb_clocks[i],orb_delay(Spells.interval(orb_compiled[i]),i))
	recipe = orb_recipes[active_orb].duplicate()
	draft = orb_drafts[active_orb].duplicate()
	compiled = orb_compiled[active_orb]
	cast_clock = orb_clocks[active_orb]
	edit_history.clear()
	edit_revision += 1
	magic.generation += 1
	forge_target = receipt.output
	forge_material = ""
	forge_message = "%s 완성 · %d G 사용 · 장착·여분 수량 반영" % [Spells.definition(receipt.output).name,receipt.cost]
	purchased_orb = receipt.output
	discover_owned()
	ui.selected_item=receipt.output
	ui.inspected_orb=output_location.orb
	ui.inspected_slot=output_location.slot
	ui.merge_material=""
	ui.board_panel="item"
	ui.rebuild_recipe()
	ui.show_shop()
	play_sound("reward")
	return true

func reroll_shop(revision: int) -> bool:
	if state != "shop" or shop_time <= 0 or revision != economy.revision: return false
	if not economy.reroll(rng,recipe): return false
	shop_message = "제작안을 새로 골랐어. 제작한 구체는 그대로 보유 중이야."
	ui.show_shop()
	return true

func start_next_wave() -> void:
	if not is_shopping(): return
	# Retire BOTH save mirrors before any combat reward can be earned.
	if record_runs and not checkpoint_store.close():
		checkpoint_message=checkpoint_store.warning
		ui.show_shop()
		return
	# Timeout never equips an unfinished draft or consumes purchased copies.
	var discarded := has_draft_changes()
	edit_revision += 1
	edit_history.clear()
	clear_magic()
	effects.clear()
	state = "combat"
	previous_state = "combat"
	shop_time = 0
	orb_drafts = orb_recipes.duplicate(true)
	draft = recipe.duplicate()
	_reset_orb_clocks()
	wave += 1
	wave_time = 0
	wave_kills = 0
	encounters.begin_wave()
	director.reset()
	boss_spawn_wait=0
	cast_clock = cast_delay(Spells.interval(trial_stages if state=="trial" else compiled))
	invincible = 1
	ui.close_modal()
	set_music("combat")
	announce(RunContent.chapter(wave).lumi,5)
	if discarded: announce("준비 시간 종료 · 미적용 편집은 취소했어. 기존 주문과 제작한 구체는 유지돼.",5)

func editing_recipe() -> bool:
	return state in ["shop","edit","trial"] or (state=="combat" and personal_tab=="inventory")

func _sync_orb() -> void:
	ensure_orb_growth()
	orb_recipes = Spells.fixed_bank(orb_recipes)
	orb_drafts = Spells.fixed_bank(orb_drafts)
	for i in orb_recipes.size():
		orb_recipes[i]=Spells.fixed_slots(orb_recipes[i],orb_capacity(i))
		orb_drafts[i]=Spells.fixed_slots(orb_drafts[i],orb_capacity(i))
	recipe = Spells.fixed_slots(recipe,orb_capacity(active_orb))
	draft = Spells.fixed_slots(draft,orb_capacity(active_orb))
	orb_recipes[active_orb] = recipe.duplicate()
	orb_drafts[active_orb] = draft.duplicate()

func reserved_parts() -> Array:
	var all_parts: Array = []
	for i in orb_recipes.size(): all_parts.append_array(draft if i==active_orb else orb_drafts[i])
	return all_parts.filter(func(id):return id!="")

func remaining_part(id: String) -> int:
	return economy.remaining(id,reserved_parts())

func has_draft_changes() -> bool:
	_sync_orb()
	return orb_drafts != orb_recipes

func valid_draft() -> bool:
	_sync_orb()
	return Forge.valid(orb_drafts,economy.inventory,orb_capacities())

func select_orb(index: int) -> void:
	if not editing_recipe() or index==active_orb or index<0 or index>=orb_recipes.size(): return
	_sync_orb()
	active_orb = index
	workbench_message = ""
	recipe = orb_recipes[index].duplicate()
	draft = orb_drafts[index].duplicate()
	compiled = orb_compiled[index]
	trial_stages = orb_trial[index]
	cast_clock = orb_clocks[index]
	selected_group = 0
	edit_revision += 1
	ui.refresh_workbench.call_deferred()

func focus_group(index: int) -> void:
	selected_group = clampi(index,0,5)
	ui.refresh_workbench.call_deferred()

func orb_position(index: int) -> Vector2:
	return player.position+([Vector2(-36,-19),Vector2(36,-19),Vector2(-28,-65),Vector2(28,-65)][index])+Vector2(0,sin(elapsed*2.5+index*PI)*5)

func _reset_orb_clocks() -> void:
	orb_cursors.resize(orb_recipes.size())
	orb_cursors.fill(0)
	orb_clocks.resize(orb_recipes.size())
	for i in orb_recipes.size(): orb_clocks[i] = orb_delay(Spells.interval(orb_compiled[i]),i)
	cast_clock = orb_clocks[active_orb]

func _tick_orbs(delta: float, allow_cast := true) -> void:
	ensure_orb_growth()
	magic.begin_tick()
	var due := false
	for i in orb_compiled.size():
		var scheduled: Array=orb_trial[i] if state=="trial" else orb_compiled[i]
		if not scheduled.is_empty() and float(orb_clocks[i])<=delta: due=true
	if not due:
		for i in orb_clocks.size(): orb_clocks[i]=maxf(-.1,float(orb_clocks[i])-delta)
		cast_clock=orb_clocks[active_orb]
		return
	var targets: Array=AutoTargeting.ranked(self)
	_update_auto_aim(targets)
	for i in orb_compiled.size():
		var stages: Array = orb_trial[i] if state=="trial" else orb_compiled[i]
		if stages.is_empty(): continue
		orb_clocks[i] = maxf(-0.1,float(orb_clocks[i])-delta)
		if not allow_cast or orb_clocks[i]>0: continue
		var command := Spells.next_cast(stages,orb_cursors[i])
		if command.is_empty(): continue
		var stage: Dictionary = command.stage.duplicate(true)
		stage["_orb"] = i
		var origin := orb_position(i)
		var point: Vector2=AutoTargeting.point_for(self,targets,0 if OrbGrowth.amount(orb_growth[i],"focus")>0 else i)
		var direction := origin.direction_to(point)
		if direction.is_zero_approx(): direction = aim
		emit_stage(stage,origin,direction,Spells.follow(stage),1.0,point)
		if not magic_active(): return
		metrics.casts += 1
		orb_cursors[i] = command.cursor
		orb_clocks[i] = orb_delay(command.delay,i,command.cursor!=0)
		play_sound("cast")
	cast_clock = orb_clocks[active_orb]

func open_editor() -> void:
	migrate_spell_roles()
	if state == "shop":
		ui.show_shop()
		return
	if state != "combat": return
	if combat_rewards.paused(): return
	open_personal("inventory")

func open_personal(tab := "inventory") -> void:
	if not state in ["combat","shop"] or not tab in ["inventory","reward","relics"]: return
	if state=="combat" and combat_rewards.paused() and combat_rewards.stage!="edit": return
	if tab=="reward":
		combat_rewards.tick()
		return
	if state=="shop" and tab=="inventory":
		close_personal()
		ui.show_shop()
		return
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	ui.close_reward_receipt()
	if personal_tab.is_empty() and state=="combat":
		_sync_orb()
		orb_drafts=orb_recipes.duplicate(true)
		draft=recipe.duplicate()
	personal_tab=tab
	edit_revision+=1
	ui.show_personal()

func close_personal() -> void:
	if not is_instance_valid(ui):
		personal_tab=""
		return
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	personal_tab=""
	edit_revision+=1
	ui.close_personal_visual()
	if combat_rewards!=null and combat_rewards.stage=="edit":
		combat_rewards.stage="ready"
		ui.show_level_reward.call_deferred()

func claim_spell_reward(reward_id: String, id: String, revision: int) -> bool:
	if not combat_rewards.choose(reward_id,id,revision):
		ui.show_level_reward.call_deferred()
		return false
	play_sound("reward")
	ui.rebuild_recipe()
	ui.update_hud()
	ui.show_level_reward.call_deferred()
	return true

func apply_acquisition(receipt: Dictionary) -> void:
	if not receipt.get("ok",false): return
	_sync_orb()
	var old: String=receipt.old
	var output: String=receipt.output
	if not old.is_empty():
		for bank in [orb_recipes,orb_drafts]:
			for parts in bank:
				for i in parts.size():
					if parts[i]==old: parts[i]=output
	for i in orb_recipes.size():
		var parsed:=Spells.compile(orb_recipes[i])
		orb_compiled[i]=parsed.stages
	recipe=orb_recipes[active_orb].duplicate()
	draft=orb_drafts[active_orb].duplicate()
	compiled=orb_compiled[active_orb]
	edit_history.clear()
	edit_revision+=1
	magic.generation+=1
	purchased_orb=output
	ui.selected_item=output
	ui.rebuild_recipe()

func normalize_owned_spells() -> void:
	_sync_orb()
	var before_applied: Array=orb_recipes.duplicate(true)
	var before_edited: Array=orb_drafts.duplicate(true)
	var migration: Dictionary=economy.normalize_owned()
	for bank in [orb_recipes,orb_drafts]:
		for orb in bank.size():
			var parts: Array=[]
			for old in bank[orb]:
				var token: String=migration.remap.get(old,old)
				parts.append(token)
			bank[orb]=parts
	var quote := {"output":"","inventory":economy.inventory}
	orb_recipes=Forge.reconcile(orb_recipes,"",quote,active_orb)
	orb_drafts=Forge.reconcile(orb_drafts,"",quote,active_orb)
	for i in orb_recipes.size():
		var parsed:=Spells.compile(orb_recipes[i])
		orb_compiled[i]=parsed.stages
	recipe=orb_recipes[active_orb].duplicate()
	draft=orb_drafts[active_orb].duplicate()
	compiled=orb_compiled[active_orb]
	if migration.changed or orb_recipes!=before_applied or orb_drafts!=before_edited: edit_history.clear()
	edit_revision+=1
	if migration.changed: checkpoint_message="이전 중복 구체를 자동 강화로 정리했어요. 초과 투자 %d마석 반환."%migration.refund

func migrate_spell_roles() -> bool:
	# Disk saves validate the content version; this handles imported/debug run state.
	var plan := RoleMigration.plan(economy.inventory,orb_recipes,orb_drafts)
	var old_offer: bool = economy.offers.any(func(o):return o.get("id","") in ["graft","shatter","sigil","on_return"])
	if not plan.changed and not old_offer: return false
	if state=="trial": end_trial()
	plan = RoleMigration.plan(economy.inventory,orb_recipes,orb_drafts)
	if not Forge.valid(plan.applied,plan.inventory) or not Forge.valid(plan.drafts,plan.inventory):
		workbench_message = "이전 구체 변환을 보류했어. 원본과 보유 수량은 그대로야."
		return false
	clear_magic()
	economy.inventory = plan.inventory
	economy.gold += plan.refund
	economy.revision += 1
	for offer in economy.offers:
		if offer.get("id","") in ["graft","shatter","sigil"]:
			offer.id = ""
			offer.sold = true
		elif offer.get("id","")=="on_return": offer.id = "expire"
	orb_recipes = plan.applied
	orb_drafts = plan.drafts
	orb_compiled = []
	for _i in orb_recipes.size(): orb_compiled.append([])
	for i in orb_recipes.size():
		var parsed := Spells.compile(orb_recipes[i])
		orb_compiled[i] = parsed.stages
	orb_cursors.resize(orb_recipes.size())
	orb_cursors.fill(0)
	orb_clocks.resize(orb_recipes.size())
	for i in orb_recipes.size(): orb_clocks[i]=orb_delay(Spells.interval(orb_compiled[i]),i)
	recipe = orb_recipes[active_orb].duplicate()
	draft = orb_drafts[active_orb].duplicate()
	compiled = orb_compiled[active_orb]
	cast_clock = orb_clocks[active_orb]
	edit_history.clear()
	trial_snapshot.clear()
	orb_trial = []
	for _i in orb_recipes.size(): orb_trial.append([])
	trial_stages.clear()
	edit_revision += 1
	forge_target = ""
	forge_material = ""
	purchased_orb = ""
	ui.selected_item = ""
	ui.merge_material = ""
	ui.inspected_slot = -1
	role_migration_receipt = {"version":RoleMigration.VERSION,"refund":plan.refund}
	workbench_message = "구체 규칙 갱신 · 각인 제거 / 최대 +3 · 이전 재료 %d G 환급"%plan.refund
	ui.rebuild_recipe()
	return true

func _remember_draft() -> void:
	_sync_orb()
	edit_history.append({"drafts":orb_drafts.duplicate(true),"orb":active_orb,"group":selected_group})
	if edit_history.size()>30: edit_history.pop_front()

func _draft_changed() -> void:
	_sync_orb()
	edit_revision += 1
	_commit_live_board()
	if state=="shop": save_checkpoint()
	if state=="trial":
		clear_magic()
		effects.clear()
		trial_damage = 0
		trial_hits = 0
		_refresh_trial_orbs()
	ui.refresh_workbench.call_deferred()

func _commit_live_board() -> void:
	# The visible slots are authoritative. Only invalid segments stop, never stale spells.
	for i in orb_recipes.size():
		var different: bool = orb_recipes[i]!=orb_drafts[i]
		var result := Spells.compile(orb_drafts[i])
		orb_recipes[i] = orb_drafts[i].duplicate()
		orb_compiled[i] = result.stages
		if different:
			orb_cursors[i] = 0
			orb_clocks[i] = maxf(orb_clocks[i],orb_delay(Spells.interval(orb_compiled[i]),i))
			if not trial_snapshot.is_empty():
				trial_snapshot.orb_clocks[i] = orb_clocks[i]
				trial_snapshot.orb_cursors[i] = 0
	recipe = orb_recipes[active_orb].duplicate()
	compiled = orb_compiled[active_orb]
	magic.generation += 1
	ui.rebuild_recipe()

func board_data(id: String, orb_index := -1, slot := -1) -> Dictionary:
	if not editing_recipe() or not Spells.has_part(id): return {}
	_sync_orb()
	if orb_index>=0:
		if orb_index>=orb_recipes.size() or slot<0 or slot>=orb_drafts[orb_index].size() or orb_drafts[orb_index][slot]!=id: return {}
	elif remaining_part(id)<=0: return {}
	return {"kind":"board_orb","owner":get_instance_id(),"revision":edit_revision,"stock":economy.revision,"id":id,"orb":orb_index,"slot":slot}

func board_plan(data: Variant, target: int, boundary: int, replace := false) -> Dictionary:
	if not editing_recipe() or not data is Dictionary: return {}
	if data.get("kind","")!="board_orb" or data.get("owner",0)!=get_instance_id() or data.get("revision",-1)!=edit_revision or data.get("stock",-1)!=economy.revision: return {}
	var id: String = data.get("id","")
	if not Spells.has_part(id) or target < -1 or target >= orb_recipes.size(): return {}
	_sync_orb()
	var bank: Array = orb_drafts.duplicate(true)
	var src: int = data.get("orb",-1)
	var index: int = data.get("slot",-1)
	if src>=0:
		if src>=orb_recipes.size() or index<0 or index>=bank[src].size() or bank[src][index]!=id: return {}
	elif remaining_part(id)<=0 or target<0: return {}
	if target<0:
		bank[src][index] = ""
	else:
		if boundary<0 or boundary>=orb_capacity(target): return {}
		if src==target and index==boundary: return {"bank":bank}
		var old: String = bank[target][boundary]
		bank[target][boundary] = id
		if src>=0: bank[src][index] = old

	var all_parts: Array = []
	for orb in bank.size():
		var row: Array=bank[orb]
		if row.size()>orb_capacity(orb): return {}
		all_parts.append_array(row)
	if not economy.owns_recipe(all_parts): return {}
	return {"bank":bank}

func board_drop(data: Variant, target: int, boundary: int, replace := false) -> bool:
	var plan := board_plan(data,target,boundary,replace)
	if plan.is_empty(): return false
	if plan.bank==orb_drafts: return true
	_remember_draft()
	orb_drafts = plan.bank
	if target>=0: active_orb = target
	draft = orb_drafts[active_orb].duplicate()
	recipe = orb_recipes[active_orb].duplicate()
	workbench_message = ""
	_draft_changed()
	return true

func board_quick_equip(id: String) -> void:
	_sync_orb()
	var at := draft.find("")
	if Spells.definition(id).kind=="modifier":
		for i in draft.size():
			if Spells.has_part(draft[i]) and Spells.definition(draft[i]).kind=="attack":
				for empty in i:
					if draft[empty]=="": at=empty; break
				break
	if at<0 or not board_drop(board_data(id),active_orb,at):
		workbench_message = "빈칸이나 남은 구체가 없어. 장착한 구체를 가방으로 빼줘."
		ui.refresh_workbench.call_deferred()

func board_close() -> void:
	if state=="combat":
		close_personal()
		return
	if state!="edit": return
	if not valid_draft():
		workbench_message = "보유 수량과 장착 상태가 맞지 않아. 구체를 확인해줘."
		ui.show_editor()
		return
	leave_editor()

func _refresh_trial_orbs() -> void:
	_sync_orb()
	orb_cursors.resize(orb_recipes.size())
	orb_cursors.fill(0)
	orb_clocks.resize(orb_recipes.size())
	for i in orb_recipes.size():
		var result := Spells.compile(orb_drafts[i])
		orb_trial[i] = result.stages if economy.owns_recipe(reserved_parts()) else []
		orb_clocks[i] = orb_delay(Spells.interval(orb_trial[i]),i)
	trial_stages = orb_trial[active_orb]
	cast_clock = orb_clocks[active_orb]

func _accept_group_recipe(next: Array) -> bool:
	var all_parts: Array = []
	for i in orb_recipes.size(): all_parts.append_array(next if i==active_orb else orb_drafts[i])
	if next.size()>orb_capacity(active_orb):
		workbench_message = "이 오브는 현재 %d칸이야. 빈칸을 확인해줘."%orb_capacity(active_orb)
		ui.refresh_workbench.call_deferred()
		return false
	if not economy.owns_recipe(all_parts):
		workbench_message = "다른 오브에 장착 중이거나 보유 수량이 부족해."
		ui.refresh_workbench.call_deferred()
		return false
	if next==draft: return true
	_remember_draft()
	draft = Spells.fixed_slots(next)
	workbench_message = ""
	_draft_changed()
	return true

func add_part(id: String) -> void:
	if not editing_recipe() or not Spells.has_part(id): return
	board_quick_equip(id)

func _available_connector() -> String:
	return ""

func can_drop_group_part(data: Variant, target: int) -> bool:
	if not data is Dictionary or not editing_recipe(): return false
	if data.get("owner",0)!=get_instance_id() or data.get("revision",-1)!=edit_revision or data.get("kind","")!="recipe_orb": return false
	return target>=0 and target<orb_capacity(active_orb) and Spells.has_part(data.get("id",""))

func drop_group_part(data: Variant, target: int) -> bool:
	if not can_drop_group_part(data,target): return false
	return drop_orb(data,target)

func swap_groups() -> void:
	if not editing_recipe(): return
	var model := Workbench.unpack(draft)
	model.groups.reverse()
	_accept_group_recipe(Workbench.pack(model))

func move_group_to_other(index: int) -> void:
	if not editing_recipe(): return
	_sync_orb()
	var src := Workbench.unpack(draft)
	if index<0 or index>=src.groups.size(): return
	var tokens: Array = src.groups[index].tokens.filter(func(id):return id!="")
	var target: int = (active_orb+1)%orb_recipes.size()
	var next: Array = Spells.fixed_slots(orb_drafts[target])
	if next.count("")<tokens.size(): return
	_remember_draft()
	for token in tokens: next[next.find("")]=token
	var offset := 0
	for n in index: offset += src.groups[n].tokens.size()
	for n in src.groups[index].tokens.size(): draft[offset+n]=""
	orb_drafts[target] = next
	_draft_changed()

func remove_part(index: int) -> void:
	if not editing_recipe() or index < 0 or index >= draft.size(): return
	_remember_draft()
	if draft[index]=="": return
	draft[index] = ""
	_draft_changed()

func orb_drag_data(id: String, source_index: int) -> Dictionary:
	if not editing_recipe(): return {}
	if source_index >= 0:
		if source_index >= draft.size() or draft[source_index] != id: return {}
	elif remaining_part(id) <= 0: return {}
	return {"kind":"recipe_orb","owner":get_instance_id(),"revision":edit_revision,"id":id,"source":source_index}

func can_drop_orb(data: Variant, boundary: int, to_inventory := false) -> bool:
	if not editing_recipe() or not data is Dictionary: return false
	if data.get("kind","")!="recipe_orb" or data.get("owner",0)!=get_instance_id() or data.get("revision",-1)!=edit_revision: return false
	var source: int = data.get("source",-1)
	var payload := board_data(data.get("id",""),active_orb if source>=0 else -1,source)
	return not board_plan(payload,-1 if to_inventory else active_orb,boundary,true).is_empty()

func drop_orb(data: Variant, boundary: int, to_inventory := false) -> bool:
	if not can_drop_orb(data,boundary,to_inventory): return false
	var source: int = data.source
	return board_drop(board_data(data.id,active_orb if source>=0 else -1,source),-1 if to_inventory else active_orb,boundary,true)

func undo_draft() -> void:
	if not editing_recipe() or edit_history.is_empty(): return
	var previous: Dictionary = edit_history.pop_back()
	workbench_message = ""
	orb_drafts = previous.drafts
	active_orb = previous.orb
	selected_group = previous.group
	draft = orb_drafts[active_orb].duplicate()
	recipe = orb_recipes[active_orb].duplicate()
	compiled = orb_compiled[active_orb]
	_draft_changed()

func reset_draft() -> void:
	if not editing_recipe() or draft == recipe: return
	workbench_message = ""
	_remember_draft()
	draft = recipe.duplicate()
	_draft_changed()

func recommend_recipe() -> void:
	if not editing_recipe(): return
	_remember_draft()
	var start: Array = Economy.KITS[selected_kit].recipe.duplicate()
	if economy.owns_recipe(start+other_orb_parts()): draft = start
	else: draft = []
	for id in ["giant","echo","pierce","seek"]:
		var next: Array = [id]+draft.filter(func(token):return token!="")
		if Spells.compile(next).ok and economy.owns_recipe(next+other_orb_parts()): draft = next
	_draft_changed()

func select_research(id: String, revision: int) -> void:
	if state=="shop" and shop_time>0 and economy.select_research(id,revision): ui.show_shop()

func apply_recipe() -> bool:
	if not editing_recipe() or not valid_draft(): return false
	var changed := orb_recipes != orb_drafts
	for i in orb_recipes.size():
		var parts: Array = orb_drafts[i]
		var different: bool = parts != orb_recipes[i]
		orb_compiled[i] = Spells.compile(parts).stages if not parts.is_empty() else []
		if different: orb_clocks[i] = maxf(orb_clocks[i],orb_delay(Spells.interval(orb_compiled[i]),i))
		if different and not trial_snapshot.is_empty():
			trial_snapshot.orb_clocks[i] = maxf(trial_snapshot.orb_clocks[i],orb_delay(Spells.interval(orb_compiled[i]),i))
	orb_recipes = orb_drafts.duplicate(true)
	recipe = orb_recipes[active_orb].duplicate()
	compiled = orb_compiled[active_orb]
	cast_clock = maxf(cast_clock,orb_clocks[active_orb]) if changed else cast_clock
	if changed: magic.generation += 1
	ui.rebuild_recipe()
	edit_revision += 1
	if state=="edit": leave_editor()
	else:
		shop_message = "오브들의 주문을 적용했어. 함께 시험하거나 출발해봐."
		ui.refresh_workbench.call_deferred()
	return true

func cancel_editor() -> void:
	if state != "edit": return
	board_close()

func leave_editor() -> void:
	edit_revision += 1
	state = previous_state
	previous_state = "combat"
	if state == "shop": ui.show_shop()
	else: ui.close_modal()

func magic_active() -> bool:
	return state=="trial" or (state=="combat" and not combat_rewards.paused())

func start_trial() -> bool:
	migrate_spell_roles()
	if state != "shop" or not valid_draft() or shop_time <= 0: return false
	if not save_checkpoint(): return false
	trial_snapshot = {"position":player.position,"aim":aim,"facing":player.facing_left,"moving":player.moving,"metrics":metrics.duplicate(),"dash_left":dash_left,"dash_cooldown":dash_cooldown,"cast_clock":cast_clock,"orb_clocks":orb_clocks.duplicate(),"orb_cursors":orb_cursors.duplicate(),"relics":relics.snapshot(),"hp":hp,"rng_state":rng.state,"gold":economy.gold,"arena_profile":arena_profile}
	trial_snapshot["dash_direction"]=dash_direction
	trial_snapshot["invincible"]=invincible
	trial_damage = 0
	trial_hits = 0
	_refresh_trial_orbs()
	clear_magic()
	effects.clear()
	player.position = Vector2(400,330)
	set_arena_profile("trial")
	player.moving = false
	state = "trial"
	edit_revision += 1
	for pos in [Vector2(690,260),Vector2(820,310),Vector2(930,420),Vector2(710,450)]:
		var target := Actor.new()
		actors.add_child(target)
		target.position = pos
		target.setup(art,1)
		target.hp = 1000000
		target.max_hp = target.hp
		enemies.append(target)
	_rebuild_grid()
	cast_clock = cast_delay(Spells.interval(trial_stages if state=="trial" else compiled))
	ui.show_trial()
	return true

func _update_trial(delta: float) -> void:
	relics.tick(delta)
	var movement := Input.get_vector("move_left","move_right","move_up","move_down")
	dash_cooldown = maxf(0,dash_cooldown-delta)
	if Input.is_action_just_pressed("dash"): try_dash(movement)
	if dash_left>0:
		dash_left -= delta
		player.position += dash_direction*750*delta
	else: player.position += movement*240*relics.movement_multiplier()*delta
	player.position = player.position.clamp(Vector2(90,150),Vector2(1350,480))
	player.moving = not movement.is_zero_approx()
	_update_auto_aim()
	player.animate(delta)
	for target in enemies: target.animate(delta)
	_rebuild_grid()
	_tick_orbs(delta)
	_update_projectiles(delta)
	magic.update_zones(delta)
	_update_effects(delta)
	visuals.queue_redraw()
	actor_shadows.queue_redraw()
	actor_health.queue_redraw()
	ui.update_trial_stats()

func _clear_trial() -> void:
	clear_magic()
	effects.clear()
	for target in enemies: target.queue_free()
	enemies.clear()
	grid.clear()
	trial_stages = []
	orb_trial = []
	for _i in orb_recipes.size(): orb_trial.append([])
	if not trial_snapshot.is_empty():
		player.position = trial_snapshot.position
		aim = trial_snapshot.aim
		player.facing_left = trial_snapshot.facing
		player.moving = trial_snapshot.moving
		metrics = trial_snapshot.metrics
		dash_left = trial_snapshot.dash_left
		dash_cooldown = trial_snapshot.dash_cooldown
		dash_direction = trial_snapshot.get("dash_direction",dash_direction)
		invincible = trial_snapshot.get("invincible",invincible)
		orb_clocks = trial_snapshot.orb_clocks
		orb_cursors = trial_snapshot.get("orb_cursors",[0,0])
		cast_clock = orb_clocks[active_orb]
		relics.restore(trial_snapshot.relics)
		hp = trial_snapshot.hp
		economy.gold = trial_snapshot.gold
		rng.state = trial_snapshot.rng_state
		set_arena_profile(trial_snapshot.get("arena_profile","scroll"))
	trial_snapshot.clear()

func end_trial() -> void:
	if state != "trial": return
	_clear_trial()
	state = "shop"
	edit_revision += 1
	ui.show_shop()

func launch_next_wave() -> void:
	migrate_spell_roles()
	if state != "shop" or not valid_draft(): return
	apply_recipe()
	start_next_wave()

func resume_game() -> void:
	state = "combat"
	ui.close_modal()

func end_run(won: bool) -> void:
	if state == "trial": return
	if state == "ended": return
	if state!="combat": return
	close_personal()
	combat_rewards.reset(0)
	encounters.clear()
	state = "ended"
	director.clear()
	hostile_shots.clear()
	clear_magic()
	relics.end_wave()
	result_win = won
	if not won and end_reason.is_empty(): end_reason="실험을 끝내지 못했어. 다음에는 주문을 바꿔보자."
	if won:
		for gem in gems: economy.grant(gem.value)
		end_reason="마법 조수의 폭주를 멈췄어."
	gems.clear()
	boss_encounter.clear()
	run_record={"won":won,"character":"lumi","kit":selected_kit,"combat":elapsed,"preparation":prep_elapsed,"kills":kills,"earned":economy.total_earned,"wave":wave,"reason":end_reason,"recipes":orb_recipes.duplicate(true),"relics":relics.owned.duplicate(),"waves":wave_records.duplicate(true)}
	run_record["run_id"]=run_id
	if record_runs and meter==null:
		checkpoint_store.close()
		profile.record_run(run_record)
		profile.save_profile()
	set_music("prepare")
	ui.show_ending()
	play_sound("reward" if won else "hurt")

func announce(message: String, duration := 3.0) -> void:
	notice = message
	notice_left = duration

func ring(at: Vector2, radius: float, color: Color, duration: float) -> void:
	if effects.size() >= 150: return
	effects.append({"kind":"ring","pos":at,"radius":radius,"color":color,"life":duration,"total":duration,"vel":Vector2.ZERO})

func burst(at: Vector2, color: Color, count: int) -> void:
	for i in count:
		if effects.size() >= 150: break
		effects.append({"kind":"spark","pos":at,"radius":3,"color":color,"life":0.35,"total":0.35,"vel":Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(50,130)})

func _update_effects(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= delta
		effects[i].pos += effects[i].vel*delta
		if effects[i].life <= 0: effects.remove_at(i)

func _build_sounds() -> void:
	for spec in [["cast",650.0,0.055],["pop",180.0,0.12],["hurt",95.0,0.18],["dash",400.0,0.09],["reward",880.0,0.22]]:
		var data := PackedByteArray()
		var rate := 22050
		var count := int(rate*spec[2])
		data.resize(count*2)
		for i in count:
			var t := float(i)/rate
			var envelope := pow(1-float(i)/count,2)
			var frequency: float = spec[1]*(1.0-t*1.8)
			var sample := sin(TAU*frequency*t)*envelope*0.28
			data.encode_s16(i*2,int(sample*32767))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.data = data
		sounds[spec[0]] = wav
	for i in 8:
		var channel := AudioStreamPlayer.new()
		channel.volume_db = -18
		add_child(channel)
		audio.append(channel)

func play_sound(id: String) -> void:
	if not sound_enabled or audio.is_empty(): return
	var channel := audio[sound_index%audio.size()]
	sound_index += 1
	channel.stream = sounds[id]
	channel.play()

func clear_group(index: int) -> void:
	if not editing_recipe(): return
	var model := Workbench.unpack(draft)
	if index<0 or index>=model.groups.size(): return
	var offset := 0
	for n in index: offset += model.groups[n].tokens.size()
	var next := draft.duplicate()
	for n in model.groups[index].tokens.size(): next[offset+n]=""
	_accept_group_recipe(next)
