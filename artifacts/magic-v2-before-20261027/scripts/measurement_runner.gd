extends RefCounted
## Shared by the visible lab and headless batches. Calls the production combat engine.
const Meter = preload("res://scripts/combat_meter.gd")
const Cost = preload("res://scripts/measurement_cost.gd")
const Migration = preload("res://scripts/spell_role_migration.gd")
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
var bank: Array = [[],[]]
var cost_plan: Dictionary = {}
var input_trace: Array = []
var cpu_samples: Array = []
var first_damage := -1.0
var phase_samples := {}

func _init(owner_game: Node2D) -> void:
	game = owner_game

static func normalize_bank(parts: Array) -> Array:
	if parts.is_empty(): return [[],[]]
	if parts[0] is Array:
		if parts.size()!=2 or not parts[1] is Array: return []
		return [Migration.recipe(parts[0]),Migration.recipe(parts[1])]
	return [Migration.recipe(parts),[]]

func begin(recipe: Array, scenario: String, seed_value := 731, aim_mode := "replay", seconds := 15.0, power := 1.0, rate := 1.0, kit := "sigil", options: Dictionary = {}) -> bool:
	if options.get("motion","scenario") not in ["scenario","stationary","orbit"]: return false
	var relic_ids: Array = options.get("relics",[])
	for id in relic_ids:
		if not game.Relics.DEFINITIONS.has(id): return false
	var proposed := normalize_bank(recipe)
	if proposed.is_empty() or proposed==[[],[]] or not SCENARIOS.has(scenario) or aim_mode not in ["nearest","fixed","build","replay"]: return false
	var programs: Array = [[],[]]
	for orb in 2:
		if proposed[orb].is_empty(): continue
		var parsed: Dictionary = game.Spells.compile(proposed[orb])
		if not parsed.ok: return false
		programs[orb] = parsed.stages
	cost_plan = Cost.new().plan(proposed,kit,options.get("economy_route","merge"))
	if not cost_plan.ok: return false
	bank = proposed
	game.meter = null
	game.set_arena_profile("measurement")
	game.start_run(kit)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.sound_enabled = false
	game.wave = 4
	game.director.reset()
	game.director.enabled = false
	game.hp = float(options.get("health",1000000))
	game.max_hp = game.hp
	game.invincible = 0
	game.power = power
	game.fire_rate = rate
	game.rng.seed = seed_value
	game.relics.rng.seed = hash("relics/"+str(seed_value))
	for id in relic_ids: game.acquire_relic(id)
	game.economy.gold = maxi(0,int(options.get("gold",0)))
	scenario_rng.seed = seed_value
	game.player.position = Vector2(480,430) if scenario in ["single","cluster","line"] else Vector2(720,430)
	game.aim = Vector2.RIGHT
	game.orb_recipes = bank.duplicate(true)
	game.orb_drafts = bank.duplicate(true)
	game.orb_compiled = programs
	game.orb_clocks = [0.0,0.0]
	game.orb_cursors = [0,0]
	game.economy.inventory = cost_plan.inventory.duplicate()
	game.active_orb = 0
	game.recipe = bank[0].duplicate()
	game.draft = game.recipe.duplicate()
	stages = programs[0] if not programs[0].is_empty() else programs[1]
	game.compiled = programs[0]
	game.ui.rebuild_recipe()
	sequence_cursor = 0
	clock = 0
	settings = {"schema":2,"ruleset":game.Spells.Effects.BALANCE_VERSION,"recipe":bank[0].duplicate(),"bank":bank.duplicate(true),"scenario":scenario,"seed":seed_value,"aim":aim_mode,"motion":options.get("motion","scenario"),"window_seconds":seconds,"power":power,"fire_rate":rate,"step":STEP,"kit":kit,"economy_route":cost_plan.route,"profile":options.get("profile",false),"opening":"t0","input_policy":"shared deterministic v2"}
	settings["relic_ruleset"] = game.Relics.VERSION
	settings["relics"] = game.relics.owned.duplicate()
	settings["initial_gold"] = game.economy.gold
	settings["player_initial_health"] = game.hp
	input_trace.clear()
	cpu_samples.clear()
	phase_samples.clear()
	first_damage = -1
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
	observer.detailed_sources = true
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
	enemy.set_meta("motion_index",spawned)
	game.enemies.append(enemy)
	spawned += 1
	initial_health += health
	return enemy

func apply_input(now: float) -> void:
	var moving: bool = settings.motion=="orbit" or (settings.motion=="scenario" and settings.scenario in ["pressure","relocation","scatter","moving_heavy"])
	if moving:
		var wide: bool = settings.scenario=="relocation"
		game.player.position = Vector2(720,430)+Vector2(cos(now*.7)*(260 if wide else 120),sin(now*.7)*(160 if wide else 90))
	else:
		game.player.position = Vector2(480,430) if settings.scenario in ["single","cluster","line"] else Vector2(720,430)
	game.aim = Vector2.RIGHT
	game.cast_target = game.player.position+Vector2(272,0)
	if settings.aim=="replay":
		match settings.scenario:
			"scatter":
				var angle: float = floor(now/1.1)*TAU/12
				game.cast_target = Vector2(720,430)+Vector2.RIGHT.rotated(angle)*275
			"line": game.cast_target = Vector2(720+65*int(floor(now/1.2))%390,430)
			"single","cluster": game.cast_target = Vector2(790,430)+Vector2(sin(now*1.3)*12,cos(now*.9)*14)
			"moving_heavy": game.cast_target = Vector2(850,430)+Vector2(sin(now*.6)*90,cos(now*1.1)*100)
			_: game.cast_target = game.player.position+Vector2.RIGHT.rotated(now*.8+settings.seed*.01)*275
	elif settings.aim in ["nearest","build"]:
		var closest: Node2D = game.nearest_enemy(game.player.position,2000)
		if closest!=null: game.cast_target = closest.position
	game.aim = game.player.position.direction_to(game.cast_target)
	if game.aim.is_zero_approx(): game.aim = Vector2.RIGHT
	if input_trace.size()<int(now)+1:
		input_trace.append({"at":snappedf(now,.001),"player":game.player.position,"target":game.cast_target})

func step() -> bool:
	if not active: return false
	var started := Time.get_ticks_usec()
	var now: float = observer.time
	game.elapsed = now
	game.invincible = maxf(0,game.invincible-STEP)
	game.relics.tick(STEP)
	game._rebuild_grid()
	apply_input(now)
	if settings.scenario in ["pressure","relocation"]:
		while next_arrival<arrivals.size() and arrivals[next_arrival].at<=now:
			var request: Dictionary = arrivals[next_arrival]
			next_arrival += 1
			if game.enemies.size()<24: target(request.pos,70)
			else: observer.count("arrivals_skipped")
		game._rebuild_grid()
		game._update_enemies(STEP)
	else:
		for enemy in game.enemies:
			if settings.scenario=="moving_heavy":
				enemy.position.y += cos(now*1.1+int(enemy.get_meta("motion_index")))*90*STEP*game.magic.behavior.movement_factor(enemy)
			enemy.animate(STEP)
	game.player.animate(STEP)
	game._rebuild_grid()
	# Exact production scheduler: two origins, clocks, cursors and compiled event trees.
	var phase_start := Time.get_ticks_usec()
	game._tick_orbs(STEP)
	record_phase("scheduler",phase_start)
	phase_start = Time.get_ticks_usec()
	game._update_projectiles(STEP)
	record_phase("projectiles",phase_start)
	phase_start = Time.get_ticks_usec()
	game.magic.update_zones(STEP)
	record_phase("zones",phase_start)
	game._update_hostile_shots(STEP)
	game._update_gems(STEP)
	game._update_effects(STEP)
	game._remove_dead()
	observer.time += STEP
	observer.sample(game,STEP)
	if first_damage<0 and observer.totals.get("damage_effective",0)>0: first_damage=observer.time
	clock = game.orb_clocks[0]
	sequence_cursor = game.orb_cursors[0]
	cpu_samples.append((Time.get_ticks_usec()-started)/1000.0)
	if settings.scenario not in ["pressure","relocation"] and game.enemies.is_empty():
		clear_seconds = observer.time
		active = false
	if observer.time+0.00001 >= float(settings.window_seconds): active = false
	return active

func record_phase(label: String, began: int) -> void:
	if not settings.get("profile",false): return
	if not phase_samples.has(label): phase_samples[label]=[]
	phase_samples[label].append((Time.get_ticks_usec()-began)/1000.0)

static func percentile(samples: Array, fraction: float) -> float:
	if samples.is_empty(): return 0.0
	var ordered := samples.duplicate()
	ordered.sort()
	return ordered[mini(ordered.size()-1,int(ceil(fraction*ordered.size()))-1)]

func report() -> Dictionary:
	var output: Dictionary = observer.result()
	output.merge(settings,true)
	output.clear_seconds = clear_seconds
	output.completed = not active
	output.spawned = spawned
	output.initial_health = initial_health
	output.cast_interval = game.cast_delay(game.Spells.interval(stages))
	output.orb_intervals = game.orb_compiled.map(func(p):return game.cast_delay(game.Spells.interval(p)) if not p.is_empty() else 0.0)
	output["final_gold"] = game.economy.gold
	output["player_final_health"] = game.hp
	output["relic_state"] = game.relics.snapshot()
	output.relic_state.erase("rng_state") # RNG int64 state is for local restores, not lossy JSON.
	output.first_damage = first_damage
	output.input_trace = input_trace.duplicate(true)
	output.arrival_plan = arrivals.duplicate(true)
	output.step_cpu_ms = {"p50":percentile(cpu_samples,.5),"p95":percentile(cpu_samples,.95),"p99":percentile(cpu_samples,.99)}
	output.phase_cpu_ms = {}
	for label in phase_samples:
		output.phase_cpu_ms[label] = {"p50":percentile(phase_samples[label],.5),"p95":percentile(phase_samples[label],.95)}
	output.investment_ledger = cost_plan.ledger
	output.purchase_cost = cost_plan.spent
	output.window_dps = float(output.totals.get("damage_effective",0))/float(settings.window_seconds)
	output.orb_cost = 0
	for row in bank:
		for id in row: output.orb_cost += int(game.Economy.investment_cost(id))
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
	json.store_string(JSON.stringify({"schema":2,"engine":"production spell runtime","runs":reports},"\t"))
	var csv := FileAccess.open(stem+".csv",FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["recipe","scenario","seed","aim","window_seconds","elapsed_seconds","cost","effective_dps","raw_damage","effective_damage","overkill","kills","clear_seconds","contact_rate","casts","projectiles","explosions","zones","triggers","player_damage","mean_alive","zones_evicted","projectiles_blocked","purchase_cost","power","fire_rate","cast_interval","motion","bank","step_cpu_p95","first_damage","window_dps","ruleset","relics","initial_gold","final_gold","player_initial_health","player_final_health"]))
	for r in reports:
		var t: Dictionary = r.totals
		var row := [JSON.stringify(r.bank),r.scenario,r.seed,r.aim,r.window_seconds,r.seconds,r.orb_cost,r.effective_dps,t.get("damage_raw",0),t.get("damage_effective",0),t.get("damage_overkill",0),t.get("kills",0),r.clear_seconds,r.contact_rate,t.get("casts",0),t.get("projectiles_emitted",0),t.get("explosions",0),t.get("zones_created",0),t.get("triggers",0),t.get("player_damage",0),r.mean_alive,t.get("zones_evicted",0),t.get("projectiles_blocked",0),r.purchase_cost,r.power,r.fire_rate,r.cast_interval,r.motion,JSON.stringify(r.bank),r.step_cpu_ms.p95,r.first_damage,r.window_dps,r.get("ruleset","legacy-unversioned")]
		row.append_array([JSON.stringify(r.get("relics",[])),r.get("initial_gold",0),r.get("final_gold",0),r.get("player_initial_health",0),r.get("player_final_health",0)])
		var strings := PackedStringArray()
		for value in row: strings.append(str(value))
		csv.store_csv_line(strings)
