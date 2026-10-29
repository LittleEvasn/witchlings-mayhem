extends RefCounted
const RunContent = preload("res://scripts/run_content.gd")
const Tempo=preload("res://scripts/combat_tempo.gd")
## Two independent randomized streams: scattered arrivals and occasional local packs.
## Cadence is adapted to our five-wave arena; no fixed entrance or advance warning.
const WAVES := [
	{"title":"첫 실습", "hint":"주변에서 꾸준히 접근 · 가끔 작은 무리", "duration":360.0, "cap":80, "ranged_cap":0, "heavy_cap":1, "hp_scale":1, "drop_budget":0,
		"normal_interval":[2.0,2.8], "normal_count":[1,2], "weights":[60,38,0,2], "first_pack":[15.0,20.0], "pack_interval":[12.0,18.0], "pack_count":[8,12], "pack_swarm":0.5, "elite_chance":0.0, "escort_chance":0.0},
	{"title":"우르르 소동", "hint":"약한 무리와 긴 돌진 · 단독 압박 정예", "duration":360.0, "cap":150, "ranged_cap":2, "heavy_cap":3, "hp_scale":1.5, "drop_budget":0,
		"normal_interval":[1.5,2.1], "normal_count":[1,2], "weights":[25,67,3,5], "first_pack":[15.0,20.0], "pack_interval":[12.0,18.0], "pack_count":[11,16], "pack_swarm":1.0, "elite_chance":0.15, "escort_chance":0.0},
	{"title":"돌진 주의", "hint":"추격·긴 돌진과 소수 사격 적", "duration":360.0, "cap":220, "ranged_cap":4, "heavy_cap":4, "hp_scale":2.2, "drop_budget":0,
		"normal_interval":[1.8,2.4], "normal_count":[1,2], "weights":[20,68,5,7], "first_pack":[15.0,20.0], "pack_interval":[12.0,18.0], "pack_count":[14,20], "pack_swarm":0.55, "elite_chance":0.35, "escort_chance":0.3},
	{"title":"혼성 소동", "hint":"분산된 근접 적 + 무리·정예·원거리 적", "duration":360.0, "cap":280, "ranged_cap":6, "heavy_cap":6, "hp_scale":3, "drop_budget":0,
		"normal_interval":[1.4,2.0], "normal_count":[1,2], "weights":[15,70,6,9], "first_pack":[15.0,20.0], "pack_interval":[12.0,18.0], "pack_count":[17,24], "pack_swarm":0.55, "elite_chance":0.5, "escort_chance":0.65},
	{"title":"마지막 폭주", "hint":"대규모 혼성 무리 · 30분에 최종 보스", "duration":360.0, "cap":300, "ranged_cap":8, "heavy_cap":8, "hp_scale":4, "drop_budget":0,
		"normal_interval":[3.5,4.8], "normal_count":[1,2], "weights":[10,72,8,10], "first_pack":[15.0,20.0], "pack_interval":[12.0,18.0], "pack_count":[20,28], "pack_swarm":0.7, "elite_chance":0.25, "escort_chance":0.35}
]
const ENEMY_HEALTH := [0.0,25.0,34.0,180.0]
const ENEMY_SPEED = Tempo.ENEMY_SPEED
const SWARM_SPEED = Tempo.SWARM_SPEED
const CHARGE_SECONDS = Tempo.CHARGE_SECONDS
const CHARGE_SPEED = Tempo.CHARGE_SPEED
const CHARGE_RECOVERY = Tempo.CHARGE_RECOVERY
const SWARM_HEALTH := 18.0
const BOSS_HEALTH := 30000.0
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
var potential := 0
var drop_counter := 0
var next_elite := 120.0
var stats: Dictionary = {}

func _init(owner_game: Node2D) -> void:
	game = owner_game
	reset()

static func config(number: int) -> Dictionary:
	return WAVES[clampi(number-1,0,4)].duplicate(true)

static func population(seconds: float) -> int:
	var t:=clampf(seconds,0,1800)
	var points: Array=[15,70,140,210,270,300]
	var index:=mini(4,int(t/360))
	return roundi(lerpf(points[index],points[index+1],fmod(t,360)/360.0)) if t<1800 else 180

static func forecast(number: int) -> String:
	var c := config(number)
	return "다음 %d / 5 · %s — %s" % [number,c.title,c.hint]

func reset() -> void:
	clear()
	enabled = true
	last_time = 0.0
	next_normal = game.wave_time+0.5
	next_elite=(floorf(game.elapsed/120.0)+1)*120.0
	drop_counter=0
	next_pack = game.wave_time+roll_range(config(game.wave).first_pack)
	dropped = 0
	potential = 0
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
	var breath:=1.2 if fmod(game.wave_time,30.0)>23.0 else 1.0
	return roll_range(c.normal_interval)*lerpf(1.1,0.85,clampf(game.wave_time/c.duration,0,1))*breath

func update() -> void:
	if game.state != "combat": return
	var c := config(game.wave)
	var now: float = game.wave_time
	if now >= c.duration and not game.final_boss_started:
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
	if enabled and game.elapsed>=next_elite and not game.final_boss_started:
		var elite: Node2D=game.spawn_enemy(3,false,Vector2.INF,"sentinel")
		next_elite=game.elapsed+(120.0 if elite!=null else 1.0)
	if enabled and now >= next_normal:
		var living: int=game.enemies.size()
		var desired:=population(game.elapsed)
		var count:=clampi(desired-living,1,10)
		if living>=int(c.cap): count=0
		for i in count:
			var choice:=choose_normal()
			spawn(choice.kind,choice.role,Vector2.INF,false)
		next_normal=now+.25
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
		var point := pack_point(request.edge,request.along,24.0 if request.kind==3 else 18.0,request.get("frame",Rect2()))
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

func spawn_frame() -> Rect2:
	return game.visible_world_rect().grow(64) if game.arena_profile=="scroll" else Rect2(45,120,1350,635)

func edge_of(point: Vector2, frame: Rect2) -> int:
	if is_equal_approx(point.x,frame.position.x): return 0
	if is_equal_approx(point.x,frame.end.x): return 1
	if is_equal_approx(point.y,frame.position.y): return 2
	return 3

func edge_point(edge: int, along: float, frame := Rect2()) -> Vector2:
	if game.arena_profile=="scroll":
		if frame.size==Vector2.ZERO: frame=spawn_frame()
		var bounds: Rect2=game.enemy_bounds().grow(-28)
		var low: float=maxf(frame.position.y,bounds.position.y) if edge<2 else maxf(frame.position.x,bounds.position.x)
		var high: float=minf(frame.end.y,bounds.end.y) if edge<2 else minf(frame.end.x,bounds.end.x)
		if high<=low: return Vector2.INF
		along=clampf(along,low,high)
		match edge:
			0: return Vector2(frame.position.x,along)
			1: return Vector2(frame.end.x,along)
			2: return Vector2(along,frame.position.y)
			_: return Vector2(along,frame.end.y)
	match edge:
		0: return Vector2(45,clampf(along,180,700))
		1: return Vector2(1395,clampf(along,180,700))
		2: return Vector2(clampf(along,180,1260),120)
		_: return Vector2(clampf(along,180,1260),755)

func available(point: Vector2, radius: float, nearby_event := false) -> bool:
	if point==Vector2.INF or not game.enemy_bounds().grow(-radius).has_point(point): return false
	if not nearby_event and game.arena_profile=="scroll" and game.visible_world_rect().grow(24).has_point(point): return false
	if point.distance_to(game.player.position) < SAFE_DISTANCE: return false
	for enemy in game.enemies:
		if not enemy.dead and enemy.position.distance_to(point) < enemy.radius+radius+3: return false
	return true

func random_spawn_point(radius := 18.0) -> Vector2:
	var frame := spawn_frame()
	for attempt in 32:
		var edge: int = game.rng.randi_range(0,3)
		var along: float
		if game.arena_profile=="scroll":
			along=game.rng.randf_range(frame.position.y,frame.end.y) if edge<2 else game.rng.randf_range(frame.position.x,frame.end.x)
		else: along=game.rng.randf_range(180,700) if edge<2 else game.rng.randf_range(180,1260)
		var point := edge_point(edge,along,frame)
		if available(point,radius): return point
	return Vector2.INF

func pack_point(edge: int, along: float, radius: float, frame := Rect2()) -> Vector2:
	for attempt in 20:
		var point := edge_point(edge,along+game.rng.randf_range(-PACK_SPREAD,PACK_SPREAD),frame)
		if available(point,radius): return point
	return Vector2.INF

func schedule_pack() -> void:
	var c := config(game.wave)
	var center := random_spawn_point(28)
	if center == Vector2.INF:
		stats.skipped += int(c.pack_count[0])
		return
	var frame := spawn_frame()
	var edge := edge_of(center,frame)
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
		pending.append({"at":at,"kind":member.kind,"role":member.role,"edge":edge,"along":along,"frame":frame})
	stats.packs += 1

func reward(kind: int) -> int:
	# No fixed per-wave currency ceiling: kills remain useful for the entire run.
	drop_counter+=1
	var coins:=3 if kind==3 else (1 if drop_counter%3==0 else 0)
	dropped+=coins
	potential=dropped
	return coins
