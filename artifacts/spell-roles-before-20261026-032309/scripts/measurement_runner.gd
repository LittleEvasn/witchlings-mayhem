extends RefCounted
## Shared by the visible lab and headless batches. Calls the production combat engine.
const Meter = preload("res://scripts/combat_meter.gd")
const STEP := 1.0/120.0
const SCENARIOS := {
	"moving_heavy":{"name":"이동 중장갑", "hint":"3명 × 체력 800 · 횡방향 왕복 · 낙뢰 빗나감과 파쇄"},
	"relocation":{"name":"이동 압박", "hint":"2초마다 4명 · 큰 경로 이동 · 설치 유지 비용"},
	"single":{"name":"단일 표적", "hint":"체력 100만 · 고정 · 끌림 면역 · 지속 화력"},
	"cluster":{"name":"밀집한 적", "hint":"9명 × 체력 60 · 42px 간격 · 광역과 과잉 피해"},
	"line":{"name":"일렬 표적", "hint":"6명 × 체력 100 · 65px 간격 · 관통과 사거리"},
	"scatter":{"name":"흩어진 적", "hint":"12명 × 체력 60 · 사방 분산 · 유도와 조준 부담"},
	"pressure":{"name":"계속 접근", "hint":"실제 적 AI · 2초마다 4명 · 자동 원형 이동 · 받는 피해"}
}
var game: Node2D
var observer: RefCounted
var settings: Dictionary = {}
var stages: Array = []
var sequence_cursor := 0
var active := false
var clock := 0.0
var next_arrival := 0
var arrivals: Array = []
var scenario_rng := RandomNumberGenerator.new()
var spawned := 0
var clear_seconds := -1.0
var initial_health := 0.0
var started_us := 0

func _init(owner_game: Node2D) -> void:
	game = owner_game

func begin(recipe: Array, scenario: String, seed_value := 731, aim_mode := "nearest", seconds := 15.0, power := 1.0, rate := 1.0, kit := "sigil") -> bool:
	var compiled: Dictionary = game.Spells.compile(recipe)
	if not compiled.ok or not SCENARIOS.has(scenario) or aim_mode not in ["nearest","fixed","build"]: return false
	game.meter = null
	game.start_run(kit)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.sound_enabled = false
	game.wave = 4
	game.director.reset()
	game.director.enabled = false
	game.hp = 1000000
	game.max_hp = game.hp
	game.invincible = 0
	game.power = power
	game.fire_rate = rate
	game.rng.seed = seed_value
	scenario_rng.seed = seed_value
	game.player.position = Vector2(480,430) if scenario in ["single","cluster","line"] else Vector2(720,430)
	game.aim = Vector2.RIGHT
	game.recipe = recipe.duplicate()
	stages = compiled.stages
	sequence_cursor = 0
	game.compiled = stages
	settings = {"recipe":recipe.duplicate(),"scenario":scenario,"seed":seed_value,"aim":aim_mode,"window_seconds":seconds,"power":power,"fire_rate":rate,"step":STEP,"kit":kit}
	clock = game.Spells.interval(stages)/rate
	spawned = 0
	initial_health = 0
	clear_seconds = -1
	next_arrival = 0
	arrivals.clear()
	match scenario:
		"single":
			var enemy = target(Vector2(790,430),1000000)
			enemy.boss = true
			enemy.radius = 24
		"cluster":
			for i in 9: target(Vector2(790+(i%3-1)*42,430+(int(i/3)-1)*42),60)
		"line":
			for i in 6: target(Vector2(720+i*65,430),100)
		"scatter":
			for i in 12:
				var angle := i*TAU/12+scenario_rng.randf_range(-0.12,0.12)
				target(Vector2(720,430)+Vector2.RIGHT.rotated(angle)*scenario_rng.randf_range(240,310),60)
		"moving_heavy":
			for i in 3: target(Vector2(780+i*70,340+i*80),800)
		"pressure", "relocation":
			# Build the entire arrival plan before casting; combat RNG cannot change it.
			for group in int(ceil(seconds/2.0)):
				for i in 4:
					var edge := scenario_rng.randi_range(0,3)
					var along := scenario_rng.randf_range(160,710) if edge<2 else scenario_rng.randf_range(160,1280)
					arrivals.append({"at":group*2.0+i*0.14,"pos":game.director.edge_point(edge,along)})
	observer = Meter.new()
	game.meter = observer
	started_us = Time.get_ticks_usec()
	active = true
	return true

func target(position: Vector2, health: float) -> Node2D:
	var enemy = game.Actor.new()
	game.actors.add_child(enemy)
	enemy.position = position
	enemy.setup(game.art,1)
	enemy.hp = health
	enemy.max_hp = health
	enemy.radius = 16
	enemy.speed = 80
	enemy.cooldown = 2
	game.enemies.append(enemy)
	spawned += 1
	initial_health += health
	return enemy

func step() -> bool:
	if not active: return false
	game.magic.begin_tick()
	observer.time += STEP
	var now: float = observer.time
	game.elapsed = now
	game.invincible = maxf(0,game.invincible-STEP)
	if settings.scenario in ["pressure","relocation"]:
		if not (settings.aim=="build" and stages[0].attack in ["frost","satellite","ember_path"]): game.player.position = Vector2(720,430)+Vector2(cos(now*0.7)*(260 if settings.scenario=="relocation" else 90),sin(now*0.7)*(160 if settings.scenario=="relocation" else 65))
		while next_arrival<arrivals.size() and arrivals[next_arrival].at<=now:
			var request: Dictionary = arrivals[next_arrival]
			next_arrival += 1
			if game.enemies.size()<24: target(request.pos,70)
			else: observer.count("arrivals_skipped")
		game._rebuild_grid()
		game._update_enemies(STEP)
	else:
		for i in game.enemies.size():
			var enemy: Node2D = game.enemies[i]
			if settings.scenario=="moving_heavy" and game.magic.behavior.movement_factor(enemy)>0:
				enemy.position.y += cos(now*1.1+i)*90*STEP*game.magic.behavior.movement_factor(enemy)
			enemy.animate(STEP)
	if settings.aim=="build" and stages[0].attack in ["frost","satellite","ember_path"]:
		game._rebuild_grid()
		var closest: Node2D = game.nearest_enemy(game.player.position,2000)
		if closest!=null:
			var distance := 110.0 if stages[0].attack!="ember_path" else 18.0
			var desired: Vector2 = closest.position+Vector2.RIGHT.rotated(now*0.6)*distance
			game.player.position = game.player.position.move_toward(desired,240*STEP)

	game.player.animate(STEP)
	game._rebuild_grid()
	clock -= STEP
	if clock <= 0:
		game.aim = Vector2.RIGHT
		game.cast_target = game.player.position+Vector2(272,0)
		if settings.aim in ["nearest","build"]:
			var enemy = game.nearest_enemy(game.player.position,2000)
			if enemy != null:
				game.aim = game.player.position.direction_to(enemy.position)
				game.cast_target = enemy.position
		if settings.aim=="build" and stages[0].get("graft",false):
			game.cast_target = Vector2(790,430)
			game.aim = game.player.position.direction_to(game.cast_target)
		var command: Dictionary = game.Spells.next_cast(stages,sequence_cursor)
		game.emit_stage(command.stage,game.player.position+game.aim*22,game.aim,game.Spells.follow(command.stage),1.0)
		sequence_cursor = command.cursor
		clock = command.delay/game.fire_rate
	game.cast_clock = clock
	game._update_projectiles(STEP)
	game.magic.update_zones(STEP)
	game._update_hostile_shots(STEP)
	game._update_effects(STEP)
	game._remove_dead()
	observer.sample(game,STEP)
	if settings.scenario not in ["pressure","relocation"] and game.enemies.is_empty():
		clear_seconds = now
		active = false
	if now+0.00001 >= float(settings.window_seconds): active = false
	return active

func report() -> Dictionary:
	var output: Dictionary = observer.result()
	output.merge(settings,true)
	output.clear_seconds = clear_seconds
	output.completed = not active
	output.spawned = spawned
	output.initial_health = initial_health
	output.cast_interval = game.Spells.interval(stages)/game.fire_rate
	output.orb_cost = 0
	for id in settings.recipe: output.orb_cost += int(game.Economy.investment_cost(id))
	output.purchase_cost = game.Economy.purchase_cost(settings.recipe,settings.kit)
	output.pending = {"projectiles":game.projectiles.size(),"echoes":game.magic.echoes.size(),"zones":game.magic.zones.size(),"strikes":game.magic.behavior.strikes.size(),"orbits":game.magic.behavior.orbits.size()}
	output.wall_elapsed_ms = (Time.get_ticks_usec()-started_us)/1000.0
	return output

func stop() -> void:
	active = false
	game.meter = null
	game.clear_magic()
	game.hostile_shots.clear()

static func save_reports(reports: Array, stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(stem.get_base_dir())
	var json := FileAccess.open(stem+".json",FileAccess.WRITE)
	json.store_string(JSON.stringify({"schema":1,"engine":"production spell runtime","runs":reports},"\t"))
	var csv := FileAccess.open(stem+".csv",FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["recipe","scenario","seed","aim","window_seconds","elapsed_seconds","cost","effective_dps","raw_damage","effective_damage","overkill","kills","clear_seconds","contact_rate","casts","projectiles","explosions","zones","triggers","player_damage","mean_alive","zones_evicted","projectiles_blocked","purchase_cost","power","fire_rate","cast_interval"]))
	for r in reports:
		var t: Dictionary = r.totals
		var row := [" > ".join(r.recipe),r.scenario,r.seed,r.aim,r.window_seconds,r.seconds,r.orb_cost,r.effective_dps,t.get("damage_raw",0),t.get("damage_effective",0),t.get("damage_overkill",0),t.get("kills",0),r.clear_seconds,r.contact_rate,t.get("casts",0),t.get("projectiles_emitted",0),t.get("explosions",0),t.get("zones_created",0),t.get("triggers",0),t.get("player_damage",0),r.mean_alive,t.get("zones_evicted",0),t.get("projectiles_blocked",0),r.purchase_cost,r.power,r.fire_rate,r.cast_interval]
		var strings := PackedStringArray()
		for value in row: strings.append(str(value))
		csv.store_csv_line(strings)
