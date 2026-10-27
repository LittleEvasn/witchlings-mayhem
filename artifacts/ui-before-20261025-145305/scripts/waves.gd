extends RefCounted
## One small timetable shared by combat and the shop forecast. Times are seconds.
const WAVES := [
	{"title":"첫 실습", "hint":"무작위 방향에서 접근 · 조준과 회피 익히기", "duration":45.0, "cap":28, "ranged_cap":0, "hp_scale":1.0, "drop_budget":30,
		"events":[[1,"scout",4],[7,"scout",4],[16,"scout",5],[23,"scout",4],[32,"scout",5],[38,"scout",4]]},
	{"title":"우르르 소동", "hint":"약한 적 다수 · 여러 방향의 접근에 대비", "duration":45.0, "cap":46, "ranged_cap":0, "hp_scale":1.12, "drop_budget":40,
		"events":[[1,"swarm",9],[7,"swarm",9],[17,"swarm",10],[24,"swarm",10],[34,"swarm",12],[39,"swarm",8]]},
	{"title":"돌진 주의", "hint":"튼튼한 돌진 적과 빠른 적 · 주변을 살피며 대응", "duration":45.0, "cap":40, "ranged_cap":0, "hp_scale":1.25, "drop_budget":48,
		"events":[[1,"line",6],[3,"heavy",2],[15,"line",7],[18,"heavy",2],[30,"line",7],[33,"heavy",2]]},
	{"title":"혼성 소동", "hint":"근접·원거리 적 혼합 · 사격 예고를 보고 회피", "duration":45.0, "cap":48, "ranged_cap":3, "hp_scale":1.38, "drop_budget":50,
		"events":[[1,"guard",8],[8,"line",6],[18,"guard",8],[25,"heavy",2],[33,"guard",9],[39,"swarm",8]]},
	{"title":"균열의 수호자", "hint":"보스 + 소규모 지원 · 보스 화력과 무리 처리를 함께 준비", "duration":120.0, "cap":40, "ranged_cap":2, "hp_scale":1.5, "drop_budget":24,
		"events":[[4,"swarm",6],[15,"guard",5],[29,"line",6],[43,"heavy",1],[57,"swarm",7],[72,"guard",5],[88,"line",6],[103,"swarm",6]]}
]
const ENEMY_HEALTH := [0.0,25.0,34.0,180.0]
const ENEMY_SPEED := [0.0,58.0,68.0,52.0]
const SWARM_HEALTH := 18.0
const BOSS_HEALTH := 3000.0
const SAFE_DISTANCE := 220.0
var game: Node2D
var event_index := 0
var pending: Array = []
var warnings: Array = []
var dropped := 0
var stats := {"spawned":0,"skipped":0,"packs":0}

func _init(owner_game: Node2D) -> void:
	game = owner_game

static func config(number: int) -> Dictionary:
	return WAVES[clampi(number-1,0,WAVES.size()-1)]

static func forecast(number: int) -> String:
	var c := config(number)
	return "다음 %d / 5 · %s — %s" % [number,c.title,c.hint]

func reset() -> void:
	clear()
	event_index = 0
	dropped = 0
	stats = {"spawned":0,"skipped":0,"packs":0}

func clear() -> void:
	pending.clear()
	warnings.clear()

func update() -> void:
	if game.state != "combat": return
	var c := config(game.wave)
	var now: float = game.wave_time
	if now >= c.duration:
		clear()
		return
	while event_index < c.events.size() and float(c.events[event_index][0]) <= now:
		var event: Array = c.events[event_index]
		event_index += 1
		# A stalled frame never replays old pressure phases as a catch-up burst.
		if now-float(event[0]) <= 0.3: schedule(event)
		else: stats.skipped += int(event[2])
	for i in range(pending.size()-1,-1,-1):
		var request: Dictionary = pending[i]
		if now < request.at: continue
		pending.remove_at(i)
		if now-request.at > 0.3:
			stats.skipped += 1
			continue
		var enemy = game.spawn_enemy(request.kind,false,Vector2.INF,request.role)
		if enemy == null: stats.skipped += 1
		else: stats.spawned += 1
	for i in range(warnings.size()-1,-1,-1):
		if now >= warnings[i].until: warnings.remove_at(i)

func edge_point(edge: int, along: float) -> Vector2:
	match edge:
		0: return Vector2(45,clampf(along,180,700))
		1: return Vector2(1395,clampf(along,180,700))
		2: return Vector2(clampf(along,180,1260),120)
		_: return Vector2(clampf(along,180,1260),755)

func random_spawn_point(radius := 18.0) -> Vector2:
	# Pick afresh when the enemy actually spawns, so moving players stay safe.
	# Every enemy rolls all four edges independently; there is no shared entrance.
	for attempt in 24:
		var edge: int = game.rng.randi_range(0,3)
		var along: float = game.rng.randf_range(180,700) if edge<2 else game.rng.randf_range(180,1260)
		var point := edge_point(edge,along)
		if point.distance_to(game.player.position) < SAFE_DISTANCE: continue
		var occupied := false
		for enemy in game.enemies:
			if not enemy.dead and enemy.position.distance_to(point) < enemy.radius+radius+3:
				occupied = true
				break
		if not occupied: return point
	# Crowded entrances skip this arrival instead of building a later backlog.
	return Vector2.INF

func schedule(event: Array) -> void:
	var shape: String = event[1]
	var count: int = event[2]
	var span := clampf(count*0.25,0.8,3.0)
	stats.packs += 1
	for i in count:
		var kind := 3 if shape == "heavy" else 1
		var role := "swarm" if shape == "swarm" else ("line" if shape == "line" else "normal")
		pending.append({"at":game.wave_time+game.rng.randf_range(0.05,span),"kind":kind,"role":role})
	if shape == "guard":
		for i in 2:
			pending.append({"at":game.wave_time+game.rng.randf_range(0.05,span),"kind":2,"role":"normal"})

func reward(kind: int) -> int:
	var remaining := maxi(0,int(config(game.wave).drop_budget)-dropped)
	var coins := mini(3 if kind == 3 else 1,remaining)
	dropped += coins
	return coins
