extends RefCounted
## Two independent randomized streams: scattered arrivals and occasional local packs.
## Cadence is adapted to our five-wave arena; no fixed entrance or advance warning.
const WAVES := [
	{"title":"첫 실습", "hint":"주변에서 꾸준히 접근 · 가끔 작은 무리", "duration":45.0, "cap":28, "ranged_cap":0, "heavy_cap":0, "hp_scale":1.0, "drop_budget":30,
		"normal_interval":[2.0,2.8], "normal_count":[1,2], "weights":[80,20,0,0], "first_pack":[7.0,9.0], "pack_interval":[10.0,13.0], "pack_count":[5,7], "pack_swarm":0.5, "elite_chance":0.0, "escort_chance":0.0},
	{"title":"우르르 소동", "hint":"분산 출현 + 불시에 몰려오는 약한 적 무리", "duration":45.0, "cap":46, "ranged_cap":0, "heavy_cap":0, "hp_scale":1.12, "drop_budget":40,
		"normal_interval":[1.5,2.1], "normal_count":[1,2], "weights":[35,65,0,0], "first_pack":[5.0,7.0], "pack_interval":[8.5,11.5], "pack_count":[7,10], "pack_swarm":1.0, "elite_chance":0.0, "escort_chance":0.0},
	{"title":"돌진 주의", "hint":"무작위 접근 중 정예 돌진 적이 섞임", "duration":45.0, "cap":40, "ranged_cap":0, "heavy_cap":3, "hp_scale":1.25, "drop_budget":48,
		"normal_interval":[1.8,2.4], "normal_count":[1,2], "weights":[65,27,0,8], "first_pack":[5.0,7.0], "pack_interval":[9.0,12.0], "pack_count":[6,9], "pack_swarm":0.55, "elite_chance":0.65, "escort_chance":0.0},
	{"title":"혼성 소동", "hint":"분산된 근접 적 + 무리·정예·원거리 적", "duration":45.0, "cap":48, "ranged_cap":3, "heavy_cap":3, "hp_scale":1.38, "drop_budget":50,
		"normal_interval":[1.4,2.0], "normal_count":[1,2], "weights":[58,24,12,6], "first_pack":[5.0,7.0], "pack_interval":[9.0,12.0], "pack_count":[7,10], "pack_swarm":0.55, "elite_chance":0.5, "escort_chance":0.65},
	{"title":"균열의 수호자", "hint":"보스 + 계속 흩어져 오는 지원병 · 가끔 작은 무리", "duration":120.0, "cap":40, "ranged_cap":2, "heavy_cap":2, "hp_scale":1.5, "drop_budget":24,
		"normal_interval":[3.5,4.8], "normal_count":[1,2], "weights":[65,25,8,2], "first_pack":[10.0,14.0], "pack_interval":[16.0,21.0], "pack_count":[4,6], "pack_swarm":0.7, "elite_chance":0.25, "escort_chance":0.35}
]
const ENEMY_HEALTH := [0.0,25.0,34.0,180.0]
const ENEMY_SPEED := [0.0,58.0,68.0,52.0]
const SWARM_HEALTH := 18.0
const BOSS_HEALTH := 3000.0
const SAFE_DISTANCE := 220.0
const PACK_SPREAD := 120.0
const STALE_SECONDS := 0.5
var game: Node2D
# Measurement fixtures can disable automatic spawning without replacing game rules.
var enabled := true
var next_normal := 0.0
var next_pack := 0.0
var last_time := 0.0
var pending: Array = []
var dropped := 0
var stats: Dictionary = {}

func _init(owner_game: Node2D) -> void:
	game = owner_game
	reset()

static func config(number: int) -> Dictionary:
	return WAVES[clampi(number-1,0,WAVES.size()-1)]

static func forecast(number: int) -> String:
	var c := config(number)
	return "다음 %d / 5 · %s — %s" % [number,c.title,c.hint]

func reset() -> void:
	clear()
	enabled = true
	last_time = 0.0
	next_normal = game.rng.randf_range(0.65,1.0)
	next_pack = roll_range(config(game.wave).first_pack)
	dropped = 0
	stats = {"spawned":0,"skipped":0,"packs":0,"scattered":0,"grouped":0,"heavy":0,"ranged":0}

func clear() -> void:
	pending.clear()
	enabled = false
	next_normal = INF
	next_pack = INF

func roll_range(bounds: Array) -> float:
	return game.rng.randf_range(float(bounds[0]),float(bounds[1]))

func normal_interval() -> float:
	var c := config(game.wave)
	# Gentle pressure growth inside each wave, never a scheduled safe/attack phase.
	return roll_range(c.normal_interval)*lerpf(1.1,0.85,clampf(game.wave_time/c.duration,0,1))

func update() -> void:
	if game.state != "combat": return
	var c := config(game.wave)
	var now: float = game.wave_time
	if now >= c.duration:
		clear()
		return
	# Resume from the present after a hitch; neither stream accumulates spawn debt.
	if now-last_time > STALE_SECONDS:
		stats.skipped += pending.size()
		pending.clear()
		if enabled:
			next_normal = now+normal_interval()
			next_pack = now+roll_range(c.pack_interval)
		last_time = now
		return
	last_time = now
	if enabled and now >= next_normal:
		for i in game.rng.randi_range(c.normal_count[0],c.normal_count[1]):
			var choice := choose_normal()
			spawn(choice.kind,choice.role,Vector2.INF,false)
		next_normal = now+normal_interval()
	if enabled and now >= next_pack:
		schedule_pack()
		next_pack = now+roll_range(c.pack_interval)
	for i in range(pending.size()-1,-1,-1):
		var request: Dictionary = pending[i]
		if now < request.at: continue
		pending.remove_at(i)
		if now-request.at > STALE_SECONDS:
			stats.skipped += 1
			continue
		# Player movement can make a previously safe pack entrance unsafe: skip it.
		var point := pack_point(request.edge,request.along,24.0 if request.kind==3 else 18.0)
		if point == Vector2.INF:
			stats.skipped += 1
			continue
		spawn(request.kind,request.role,point,true)

func choose_normal() -> Dictionary:
	var weights: Array = config(game.wave).weights
	var ticket: int = game.rng.randi_range(0,int(weights.reduce(func(a,b):return a+b))-1)
	for i in weights.size():
		ticket -= int(weights[i])
		if ticket < 0:
			return {"kind":2 if i==2 else (3 if i==3 else 1),"role":"swarm" if i==1 else "normal"}
	return {"kind":1,"role":"normal"}

func spawn(kind: int, role: String, point: Vector2, grouped: bool) -> void:
	var enemy = game.spawn_enemy(kind,false,point,role)
	if enemy == null:
		stats.skipped += 1
		return
	stats.spawned += 1
	stats["grouped" if grouped else "scattered"] += 1
	if kind == 3: stats.heavy += 1
	if kind == 2: stats.ranged += 1

func edge_point(edge: int, along: float) -> Vector2:
	match edge:
		0: return Vector2(45,clampf(along,180,700))
		1: return Vector2(1395,clampf(along,180,700))
		2: return Vector2(clampf(along,180,1260),120)
		_: return Vector2(clampf(along,180,1260),755)

func available(point: Vector2, radius: float) -> bool:
	if point.distance_to(game.player.position) < SAFE_DISTANCE: return false
	for enemy in game.enemies:
		if not enemy.dead and enemy.position.distance_to(point) < enemy.radius+radius+3: return false
	return true

func random_spawn_point(radius := 18.0) -> Vector2:
	for attempt in 32:
		var edge: int = game.rng.randi_range(0,3)
		var along: float = game.rng.randf_range(180,700) if edge<2 else game.rng.randf_range(180,1260)
		var point := edge_point(edge,along)
		if available(point,radius): return point
	return Vector2.INF

func pack_point(edge: int, along: float, radius: float) -> Vector2:
	for attempt in 20:
		var point := edge_point(edge,along+game.rng.randf_range(-PACK_SPREAD,PACK_SPREAD))
		if available(point,radius): return point
	return Vector2.INF

func schedule_pack() -> void:
	var c := config(game.wave)
	var center := random_spawn_point(28)
	if center == Vector2.INF:
		stats.skipped += int(c.pack_count[0])
		return
	var edge := 0 if center.x==45 else (1 if center.x==1395 else (2 if center.y==120 else 3))
	var along := center.y if edge<2 else center.x
	var count: int = game.rng.randi_range(c.pack_count[0],c.pack_count[1])
	var elite: bool = game.rng.randf() < float(c.elite_chance)
	var escort: bool = game.rng.randf() < float(c.escort_chance)
	# A heavy replaces two ordinary members; it is not an extra full-sized wave.
	var roles: Array = []
	if elite: roles.append({"kind":3,"role":"normal"})
	for i in maxi(1,count-(2 if elite else 0)-(1 if escort else 0)):
		roles.append({"kind":1,"role":"swarm" if game.rng.randf()<float(c.pack_swarm) else "normal"})
	if escort: roles.append({"kind":2,"role":"normal"})
	var at: float = game.wave_time
	for member in roles:
		at += game.rng.randf_range(0.16,0.30)
		pending.append({"at":at,"kind":member.kind,"role":member.role,"edge":edge,"along":along})
	stats.packs += 1

func reward(kind: int) -> int:
	var remaining := maxi(0,int(config(game.wave).drop_budget)-dropped)
	var coins := mini(3 if kind == 3 else 1,remaining)
	dropped += coins
	return coins
