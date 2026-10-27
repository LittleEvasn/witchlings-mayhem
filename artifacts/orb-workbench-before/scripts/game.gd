extends Node2D

const Spells = preload("res://scripts/spells.gd")
const Waves = preload("res://scripts/waves.gd")
const Economy = preload("res://scripts/economy.gd")
const SHOP_SECONDS := 60.0
const SpellRuntime = preload("res://scripts/spell_runtime.gd")
const Actor = preload("res://scripts/actor.gd")
const Visuals = preload("res://scripts/magic_visuals.gd")
const Interface = preload("res://scripts/interface.gd")
const FIELD := Rect2(72,115,1296,656)
const MAX_ENEMIES := 90
const MAX_PROJECTILES := 180
const GRID_SIZE := 96.0

var state := "title"
var previous_state := "combat"
var player: Node2D
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
var recipe: Array = ["bolt","impact","bloom"]
var economy := Economy.new()
var shop_time := 0.0
var shop_message := ""
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
	rng.randomize()
	_bind_inputs()
	art = load("res://assets/art/characters.png")
	var background := Sprite2D.new()
	background.texture = load("res://assets/art/arena.png")
	background.position = Vector2(720,450)
	background.scale = Vector2(1440,900) / background.texture.get_size()
	background.z_index = -100
	add_child(background)
	actors = Node2D.new()
	add_child(actors)
	player = Actor.new()
	actors.add_child(player)
	player.position = Vector2(720,450)
	player.setup(art,0)
	player.radius = 16
	visuals = Visuals.new()
	visuals.game = self
	visuals.z_index = 1500
	add_child(visuals)
	director = Waves.new(self)
	magic = SpellRuntime.new(self)
	ui = Interface.new()
	ui.game = self
	add_child(ui)
	compiled = Spells.compile(recipe).stages
	_build_sounds()
	ui.show_title()

func _bind_inputs() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"dash":[KEY_SPACE],"recipe":[KEY_TAB],"pause_game":[KEY_ESCAPE],"mute":[KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		sound_enabled = not sound_enabled
		announce("효과음 켜짐" if sound_enabled else "효과음 꺼짐")
	if event.is_action_pressed("recipe"):
		if state == "combat": open_editor()
		elif state in ["edit","shop"]: apply_recipe()
		elif state == "trial": end_trial()
	if event.is_action_pressed("pause_game"):
		if state == "combat":
			state = "paused"
			ui.show_pause()
		elif state == "paused": resume_game()
		elif state == "edit": cancel_editor()
		elif state == "trial": end_trial()

func start_run(kit := "") -> void:
	result_win = false
	if Economy.KITS.has(kit): selected_kit = kit
	if state == "trial": _clear_trial()
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
	recipe = Economy.KITS[selected_kit].recipe.duplicate()
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
	cast_clock = Spells.interval(compiled)/fire_rate
	dash_cooldown = 0
	dash_left = 0
	invincible = 1
	boss_ref = null
	metrics = {"casts":0,"triggers":0,"hits":0,"peak_projectiles":0,"peak_enemies":0}
	player.position = Vector2(720,450)
	player.modulate = Color.WHITE
	state = "combat"
	ui.close_modal()
	ui.rebuild_recipe()
	announce("실습 시작!  마우스 조준 · 자동 시전 · 조각은 돈으로 · Space 회피 · Tab 조합",5)

func _physics_process(delta: float) -> void:
	if is_shopping():
		shop_time = maxf(0,shop_time-delta)
		ui.update_shop_clock()
		if shop_time <= 0: start_next_wave()
	if state == "trial":
		_update_trial(delta)
		return
	if state != "combat":
		player.animate(delta * 0.5)
		return
	elapsed += delta
	wave_time += delta
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
		player.position += movement * 240.0 * delta
	player.position = player.position.clamp(FIELD.position,FIELD.end)
	_update_mouse_aim()
	player.moving = movement.length_squared() > 0.01 or dash_left > 0
	player.facing_left = aim.x < 0
	player.animate(delta)
	player.modulate.a = 0.45 if invincible > 0 and int(elapsed*14)%2 == 0 else 1.0
	_rebuild_grid()
	_update_enemies(delta)
	if state != "combat": return
	cast_clock -= delta
	if cast_clock <= 0:
		cast_clock = Spells.interval(compiled) / fire_rate if cast_spell() else 0.0
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
	_remove_dead()
	if wave < 5 and wave_time >= Waves.config(wave).duration: complete_wave()
	elif wave == 5 and wave_time >= Waves.config(wave).duration: end_run(false)
	metrics.peak_projectiles = maxi(metrics.peak_projectiles,projectiles.size())
	metrics.peak_enemies = maxi(metrics.peak_enemies,enemies.size())
	visuals.queue_redraw()
	ui_clock += delta
	if ui_clock >= 0.1:
		ui_clock = 0
		ui.update_hud()

func try_dash(movement: Vector2) -> bool:
	if dash_cooldown > 0 or not state in ["combat","trial"]: return false
	dash_direction = movement if movement.length_squared() > 0.01 else last_move
	dash_left = 0.19
	dash_cooldown = 1.7
	invincible = maxf(invincible,0.28)
	ring(player.position,36,Color("dfb6f5"),0.3)
	play_sound("dash")
	return true

func _update_mouse_aim() -> void:
	cast_target = get_global_mouse_position()
	var direction := player.position.direction_to(cast_target)
	if not direction.is_zero_approx(): aim = direction
	player.facing_left = aim.x < 0

func cast_spell() -> bool:
	if not magic_active() or (trial_stages if state == "trial" else compiled).is_empty(): return false
	_update_mouse_aim()
	var stages: Array = trial_stages if state == "trial" else compiled
	var follow: Dictionary = stages[1] if stages.size() > 1 else {}
	emit_stage(stages[0],player.position+aim*22,aim,follow,1.0)
	metrics.casts += 1
	play_sound("cast")
	return true

func clear_magic() -> void:
	projectiles.clear()
	magic.clear()
	if is_instance_valid(visuals): visuals.queue_redraw()

func emit_stage(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float) -> void:
	if meter != null and magic_active(): meter.count("casts")
	magic.emit(stage,origin,direction,follow,factor)

func _update_projectiles(delta: float) -> void:
	magic.update_echoes(delta)
	magic.update_projectiles(delta)

func explode(at: Vector2, damage: float, radius: float, source := "") -> void:
	if meter != null: meter.count("explosions",source)
	ring(at,radius,Color("ffc79f"),0.32)
	for enemy in nearby(at,radius+45):
		if not enemy.dead and enemy.position.distance_squared_to(at) <= pow(radius+enemy.radius,2):
			damage_enemy(enemy,damage,at.direction_to(enemy.position),source)
			if meter != null: meter.count("explosion_victims",source)
			if not magic_active(): return
	if sound_clock <= 0:
		play_sound("pop")
		sound_clock = 0.07

func damage_enemy(enemy: Node2D, amount: float, direction: Vector2, source := "") -> void:
	if enemy.dead: return
	if state == "trial":
		trial_damage += amount
		trial_hits += 1
		enemy.flash = 0.1
		return
	if meter != null: meter.damage(source,amount,enemy.hp,enemy.get_instance_id())
	enemy.hp -= amount
	enemy.flash = 0.1
	metrics.hits += 1
	if not enemy.boss: enemy.position += direction*6
	if enemy.hp <= 0:
		enemy.dead = true
		kills += 1
		wave_kills += 1
		var coins: int = director.reward(enemy.kind)
		if coins > 0: gems.append({"pos":enemy.position,"value":coins})
		burst(enemy.position,Color("dfb6f5"),5)
		if enemy.boss: end_run(true)

func spawn_enemy(forced_kind := -1, is_boss := false, requested := Vector2.INF, role := "normal") -> Node2D:
	var config: Dictionary = Waves.config(wave)
	var living := 0
	var ranged := 0
	for e in enemies:
		if not e.dead:
			living += 1
			if e.kind == 2: ranged += 1
	if living >= mini(MAX_ENEMIES,int(config.cap)): return null
	var kind := forced_kind if forced_kind >= 0 else 1
	if kind == 2 and ranged >= int(config.ranged_cap): return null
	var point: Vector2 = requested
	if point == Vector2.INF:
		point = director.random_spawn_point(24.0 if kind==3 else 18.0)
		if point == Vector2.INF: return null
	if is_boss: point = Vector2(720,180)
	if point.distance_to(player.position) < Waves.SAFE_DISTANCE:
		if requested != Vector2.INF and not is_boss: return null
		point = Vector2(1440,900)-point
	# Explicit spawn positions also respect occupied entrances.
	var radius := 16.0 if role == "line" else (24.0 if kind==3 else 18.0)
	if requested != Vector2.INF:
		for e in enemies:
			if not e.dead and e.position.distance_to(point) < e.radius+radius+3: return null
	var enemy := Actor.new()
	actors.add_child(enemy)
	enemy.position = point
	enemy.setup(art,kind,is_boss)
	enemy.role = role
	enemy.hp = (Waves.ENEMY_HEALTH[kind] if role != "swarm" else Waves.SWARM_HEALTH)*float(config.hp_scale)
	enemy.speed = Waves.ENEMY_SPEED[kind]+wave*3
	if role == "line": enemy.speed += 8
	enemy.radius = radius
	enemy.cooldown = rng.randf_range(1.4,2.8)
	if role in ["swarm","line"]: enemy.art_scale *= 0.85
	if is_boss:
		enemy.hp = Waves.BOSS_HEALTH
		enemy.radius = 45
		enemy.speed = 48
		boss_ref = enemy
	enemy.max_hp = enemy.hp
	enemies.append(enemy)
	ring(point,30,Color("ff9cae"),0.5)
	return enemy

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
		if enemy.kind == 2:
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
		if enemy.kind == 3:
			if enemy.windup > 0:
				enemy.windup -= delta
				velocity = Vector2.ZERO
				if enemy.windup <= 0:
					enemy.charge_time = 0.55
					if enemy.boss and hostile_shots.size() <= 88:
						for i in 12:
							hostile_shots.append({"pos":enemy.position,"vel":Vector2.RIGHT.rotated(i*TAU/12)*145,"life":5.0})
			elif enemy.charge_time > 0:
				enemy.charge_time -= delta
				velocity = enemy.charge_direction*(300 if enemy.boss else 345)
			elif enemy.cooldown <= 0:
				enemy.windup = 0.8
				enemy.charge_direction = direction
				enemy.cooldown = 3.8
		# Local separation prevents a single unreadable pile without an O(n²) whole-world pass.
		var separation := Vector2.ZERO
		for other in nearby(enemy.position,50):
			if other == enemy or other.dead: continue
			var offset: Vector2 = enemy.position-other.position
			var d2 := offset.length_squared()
			if d2 > 0.1 and d2 < pow(enemy.radius+other.radius,2):
				separation += offset.normalized()*35
		enemy.position += (velocity+separation.limit_length(60))*delta*status_speed
		enemy.position = enemy.position.clamp(Vector2(35,95),Vector2(1405,795))
		enemy.moving = velocity.length_squared() > 1
		enemy.facing_left = direction.x < 0
		enemy.animate(delta)
		if distance < enemy.radius+player.radius:
			hurt_player(22 if enemy.kind == 3 else 12)
			if state != "combat": return

func hurt_player(amount: float) -> void:
	if invincible > 0 or state != "combat": return
	if meter != null:
		meter.count("player_damage","",minf(hp,amount))
		meter.count("player_hits")
	hp = maxf(0,hp-amount)
	invincible = 0.85
	player.flash = 0.15
	ring(player.position,35,Color("ff778e"),0.25)
	play_sound("hurt")
	if hp <= 0: end_run(false)

func _update_hostile_shots(delta: float) -> void:
	for i in range(hostile_shots.size()-1,-1,-1):
		var shot: Dictionary = hostile_shots[i]
		var old: Vector2 = shot.pos
		shot.pos += shot.vel*delta
		shot.life -= delta
		var nearest := Geometry2D.get_closest_point_to_segment(player.position,old,shot.pos)
		if nearest.distance_to(player.position) < 20:
			hurt_player(10)
			hostile_shots.remove_at(i)
		elif shot.life <= 0: hostile_shots.remove_at(i)

func _update_gems(delta: float) -> void:
	for i in range(gems.size()-1,-1,-1):
		var gem: Dictionary = gems[i]
		var distance: float = gem.pos.distance_to(player.position)
		if distance < 145:
			gem.pos = gem.pos.move_toward(player.position,(200+(145-distance)*5)*delta)
		if distance < 20:
			gain_money(gem.value)
			gems.remove_at(i)
	# Merge old drops rather than accumulating unbounded collectible nodes.
	if gems.size() > 200:
		var first: Dictionary = gems.pop_front()
		gems[0].value += first.value

func gain_money(value: int) -> void:
	economy.grant(value)

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
	director.clear()
	state = "reward"
	for gem in gems: gain_money(gem.value)
	gems.clear()
	for enemy in enemies: enemy.queue_free()
	enemies.clear()
	grid.clear()
	clear_magic()
	hostile_shots.clear()
	effects.clear()
	hp = minf(max_hp,hp+15)
	reward_taken = false
	economy.grant(Economy.CLEAR_REWARD)
	reward_options = ["power","haste","heart"]
	ui.show_rewards()
	visuals.queue_redraw()
	play_sound("reward")

func choose_reward(id: String) -> void:
	if state != "reward" or reward_taken or not reward_options.has(id): return
	reward_taken = true
	match id:
		"power": power += 0.25
		"haste": fire_rate += 0.18
		"heart":
			max_hp += 25
			hp = minf(max_hp,hp+40)
	draft = recipe.duplicate()
	edit_history.clear()
	edit_revision += 1
	purchased_orb = ""
	shop_time = SHOP_SECONDS
	shop_message = "구체를 구입하고 주문에 넣어봐. 준비가 끝나면 바로 출발할 수 있어."
	economy.roll(rng,recipe)
	state = "shop"
	ui.show_shop()

func is_shopping() -> bool:
	return state == "shop" or (state == "edit" and previous_state == "shop")

func buy_orb(index: int, revision: int) -> bool:
	if state != "shop" or shop_time <= 0: return false
	if not economy.buy(index,revision): return false
	purchased_orb = economy.offers[index].id
	shop_message = "%s 구입 완료 · 아래 보유 목록에서 끌어 넣고 시험해봐." % Spells.PARTS[purchased_orb].name
	ui.show_shop()
	play_sound("reward")
	return true

func reroll_shop(revision: int) -> bool:
	if state != "shop" or shop_time <= 0 or revision != economy.revision: return false
	if not economy.reroll(rng,recipe): return false
	shop_message = "진열 상품을 새로 골랐어. 구입한 구체는 그대로 보유 중이야."
	ui.show_shop()
	return true

func start_next_wave() -> void:
	if not is_shopping(): return
	# Timeout never equips an unfinished draft or consumes purchased copies.
	var discarded := draft != recipe
	edit_revision += 1
	edit_history.clear()
	clear_magic()
	effects.clear()
	state = "combat"
	previous_state = "combat"
	shop_time = 0
	draft = recipe.duplicate()
	wave += 1
	wave_time = 0
	wave_kills = 0
	director.reset()
	cast_clock = Spells.interval(trial_stages if state=="trial" else compiled)/fire_rate
	invincible = 1
	ui.close_modal()
	if wave == 5:
		spawn_enemy(3,true)
		announce("마지막 사고!  균열의 수호자를 쓰러뜨려 출구를 열자.",5)
	else: announce("실습 %d / 5 · %s" % [wave,Waves.config(wave).title],4)
	if discarded: announce("준비 시간 종료 · 미적용 편집은 취소했어. 기존 주문과 구매한 구체는 유지돼.",5)

func editing_recipe() -> bool:
	return state in ["shop","edit","trial"]

func valid_draft() -> bool:
	return Spells.compile(draft).ok and economy.owns_recipe(draft)

func open_editor() -> void:
	if state == "shop":
		ui.show_shop()
		return
	if state != "combat": return
	previous_state = state
	draft = recipe.duplicate()
	edit_history.clear()
	edit_revision += 1
	state = "edit"
	ui.show_editor()

func _remember_draft() -> void:
	edit_history.append(draft.duplicate())
	if edit_history.size() > 30: edit_history.pop_front()

func _draft_changed() -> void:
	edit_revision += 1
	if state == "trial":
		clear_magic()
		effects.clear()
		trial_damage = 0
		trial_hits = 0
		var result := Spells.compile(draft)
		trial_stages = result.stages if result.ok and economy.owns_recipe(draft) else []
		cast_clock = Spells.interval(trial_stages if state=="trial" else compiled)/fire_rate
	ui.refresh_workbench.call_deferred()

func add_part(id: String) -> void:
	if not editing_recipe() or not Spells.PARTS.has(id) or draft.size() >= 6 or economy.remaining(id,draft) <= 0: return
	_remember_draft()
	draft.append(id)
	_draft_changed()

func remove_part(index: int) -> void:
	if not editing_recipe() or index < 0 or index >= draft.size(): return
	_remember_draft()
	draft.remove_at(index)
	_draft_changed()

func orb_drag_data(id: String, source_index: int) -> Dictionary:
	if not editing_recipe(): return {}
	if source_index >= 0:
		if source_index >= draft.size() or draft[source_index] != id: return {}
	elif economy.remaining(id,draft) <= 0: return {}
	return {"kind":"recipe_orb","owner":get_instance_id(),"revision":edit_revision,"id":id,"source":source_index}

func can_drop_orb(data: Variant, boundary: int, to_inventory := false) -> bool:
	if not editing_recipe() or not data is Dictionary: return false
	if data.get("kind","") != "recipe_orb" or data.get("owner",0) != get_instance_id() or data.get("revision",-1) != edit_revision: return false
	var id: String = data.get("id","")
	var source: int = data.get("source",-1)
	if not Spells.PARTS.has(id): return false
	if source >= 0:
		if source >= draft.size() or draft[source] != id: return false
		return to_inventory or (boundary >= 0 and boundary <= 6)
	return not to_inventory and boundary >= 0 and boundary <= 6 and draft.size() < 6 and economy.remaining(id,draft) > 0

func drop_orb(data: Variant, boundary: int, to_inventory := false) -> bool:
	if not can_drop_orb(data,boundary,to_inventory): return false
	var source: int = data.source
	var next := draft.duplicate()
	if source >= 0:
		next.remove_at(source)
		if source < boundary: boundary -= 1
	if not to_inventory: next.insert(clampi(boundary,0,next.size()),data.id)
	if next == draft: return true
	_remember_draft()
	draft = next
	_draft_changed()
	return true

func undo_draft() -> void:
	if not editing_recipe() or edit_history.is_empty(): return
	draft = edit_history.pop_back()
	_draft_changed()

func reset_draft() -> void:
	if not editing_recipe() or draft == recipe: return
	_remember_draft()
	draft = recipe.duplicate()
	_draft_changed()

func recommend_recipe() -> void:
	if not editing_recipe(): return
	_remember_draft()
	var start: Array = Economy.KITS[selected_kit].recipe.duplicate()
	if economy.owns_recipe(start): draft = start
	else: draft = ["bolt"]
	for id in ["giant","echo","pierce","seek"]:
		var next: Array = [id]+draft
		if Spells.compile(next).ok and economy.owns_recipe(next): draft = next
	_draft_changed()

func select_research(id: String, revision: int) -> void:
	if state=="shop" and shop_time>0 and economy.select_research(id,revision): ui.show_shop()

func apply_recipe() -> bool:
	if not editing_recipe(): return false
	var result := Spells.compile(draft)
	if not result.ok or not economy.owns_recipe(draft): return false
	var changed := recipe != draft
	recipe = draft.duplicate()
	compiled = result.stages
	if changed:
		magic.generation += 1
		cast_clock = maxf(cast_clock,Spells.interval(compiled)/fire_rate)
	ui.rebuild_recipe()
	edit_revision += 1
	if state == "edit": leave_editor()
	else:
		shop_message = "주문 적용 완료. 시험하거나 다음 웨이브를 시작해봐."
		ui.refresh_workbench.call_deferred()
	return true

func cancel_editor() -> void:
	if state != "edit": return
	draft = recipe.duplicate()
	leave_editor()

func leave_editor() -> void:
	edit_revision += 1
	state = previous_state
	previous_state = "combat"
	if state == "shop": ui.show_shop()
	else: ui.close_modal()

func magic_active() -> bool:
	return state in ["combat","trial"]

func start_trial() -> bool:
	if state != "shop" or not valid_draft() or shop_time <= 0: return false
	trial_snapshot = {"position":player.position,"aim":aim,"facing":player.facing_left,"moving":player.moving,"metrics":metrics.duplicate(),"dash_left":dash_left,"dash_cooldown":dash_cooldown,"cast_clock":cast_clock}
	trial_damage = 0
	trial_hits = 0
	trial_stages = Spells.compile(draft).stages
	clear_magic()
	effects.clear()
	player.position = Vector2(400,330)
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
	cast_clock = Spells.interval(trial_stages if state=="trial" else compiled)/fire_rate
	ui.show_trial()
	return true

func _update_trial(delta: float) -> void:
	var movement := Input.get_vector("move_left","move_right","move_up","move_down")
	dash_cooldown = maxf(0,dash_cooldown-delta)
	if Input.is_action_just_pressed("dash"): try_dash(movement)
	if dash_left>0:
		dash_left -= delta
		player.position += dash_direction*750*delta
	else: player.position += movement*240*delta
	player.position = player.position.clamp(Vector2(90,150),Vector2(1350,480))
	player.moving = not movement.is_zero_approx()
	if Rect2(72,115,1296,400).has_point(get_global_mouse_position()): _update_mouse_aim()
	player.animate(delta)
	for target in enemies: target.animate(delta)
	_rebuild_grid()
	cast_clock -= delta
	# Editing and dragging never redirect an automatic shot into the UI.
	if Rect2(72,115,1296,400).has_point(get_global_mouse_position()) and not get_viewport().gui_is_dragging():
		if cast_clock <= 0:
			if cast_spell(): cast_clock = Spells.interval(trial_stages)/fire_rate
	_update_projectiles(delta)
	magic.update_zones(delta)
	_update_effects(delta)
	visuals.queue_redraw()
	ui.update_trial_stats()

func _clear_trial() -> void:
	clear_magic()
	effects.clear()
	for target in enemies: target.queue_free()
	enemies.clear()
	grid.clear()
	trial_stages.clear()
	if not trial_snapshot.is_empty():
		player.position = trial_snapshot.position
		aim = trial_snapshot.aim
		player.facing_left = trial_snapshot.facing
		player.moving = trial_snapshot.moving
		metrics = trial_snapshot.metrics
		dash_left = trial_snapshot.dash_left
		dash_cooldown = trial_snapshot.dash_cooldown
		cast_clock = trial_snapshot.cast_clock
	trial_snapshot.clear()

func end_trial() -> void:
	if state != "trial": return
	_clear_trial()
	state = "shop"
	edit_revision += 1
	ui.show_shop()

func launch_next_wave() -> void:
	if state != "shop" or not valid_draft(): return
	apply_recipe()
	start_next_wave()

func resume_game() -> void:
	state = "combat"
	ui.close_modal()

func end_run(won: bool) -> void:
	if state == "trial": return
	if state == "ended": return
	state = "ended"
	director.clear()
	hostile_shots.clear()
	clear_magic()
	result_win = won
	ui.show_results()
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
