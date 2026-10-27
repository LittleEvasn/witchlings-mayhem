extends RefCounted
## One small timetable shared by combat and the shop forecast. Times are seconds.
const WAVES := [
	{"title":"첫 실습", "hint":"작은 무리 · 조준과 회피 익히기", "duration":45.0, "cap":28, "ranged_cap":0, "hp_scale":1.0, "drop_budget":30,
		"events":[[1,"scout",4],[7,"scout",4],[16,"scout",5],[23,"scout",4],[32,"scout",5],[38,"scout",4]]},
	{"title":"우르르 소동", "hint":"약한 적 무리 · 광역 공격과 갈래를 시험해봐", "duration":45.0, "cap":46, "ranged_cap":0, "hp_scale":1.12, "drop_budget":40,
		"events":[[1,"swarm",9],[7,"swarm",9],[17,"swarm",10],[24,"swarm",10],[34,"swarm",12],[39,"swarm",8]]},
	{"title":"단단한 행렬", "hint":"튼튼한 돌진 적 + 일렬 진입 · 집중 공격과 관통", "duration":45.0, "cap":40, "ranged_cap":0, "hp_scale":1.25, "drop_budget":48,
		"events":[[1,"line",6],[3,"heavy",2],[15,"line",7],[18,"heavy",2],[30,"line",7],[33,"heavy",2]]},
	{"title":"뒤쪽을 조심해", "hint":"근접 무리 뒤 원거리 적 · 사격 예고를 보고 우선 처치", "duration":45.0, "cap":48, "ranged_cap":3, "hp_scale":1.38, "drop_budget":50,
		"events":[[1,"guard",8],[8,"line",6],[18,"guard",8],[25,"heavy",2],[33,"guard",9],[39,"swarm",8]]},
	{"title":"균열의 수호자", "hint":"보스 + 소규모 지원 · 보스 화력과 무리 처리를 함께 준비", "duration":120.0, "cap":40, "ranged_cap":2, "hp_scale":1.5, "drop_budget":24,
		"events":[[4,"swarm",6],[15,"guard",5],[29,"line",6],[43,"heavy",1],[57,"swarm",7],[72,"guard",5],[88,"line",6],[103,"swarm",6]]}
]
const ENEMY_HEALTH := [0.0,25.0,34.0,180.0]
const ENEMY_SPEED := [0.0,58.0,68.0,52.0]
const SWARM_HEALTH := 18.0
const BOSS_HEALTH := 3000.0
const LEAD := 0.9
const SAFE_DISTANCE := 220.0
var game: Node2D
var event_index := 0
var pending: Array = []
var warnings: Array = []
var dropped := 0
var last_edge := -1
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
	last_edge = -1
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
		var enemy = game.spawn_enemy(request.kind,false,request.pos,request.role)
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

func choose_edge(depth := 0.0) -> int:
	# Each run uses one opposite pair of entrances, leaving lateral escape space.
	var pair := [0,1] if game.wave%2 == 0 else [2,3]
	var viable: Array = []
	for edge in pair:
		var along: float = game.player.position.y if edge < 2 else game.player.position.x
		if edge_point(edge,along).distance_to(game.player.position) >= SAFE_DISTANCE+depth: viable.append(edge)
	if viable.is_empty():
		for edge in 4:
			if edge_point(edge,450 if edge<2 else 720).distance_to(game.player.position) >= SAFE_DISTANCE+depth: viable.append(edge)
	if last_edge in viable and game.rng.randf() < 0.55: return last_edge
	return viable[game.rng.randi_range(0,viable.size()-1)]

func schedule(event: Array) -> void:
	var shape: String = event[1]
	var count: int = event[2]
	var depth := 0.0 if shape in ["line","heavy"] else int((count-1)/3)*48.0+8
	last_edge = choose_edge(depth)
	var along: float = game.player.position.y if last_edge<2 else game.player.position.x
	along += game.rng.randf_range(-70,70)
	var anchor := edge_point(last_edge,along)
	var inward: Vector2 = [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP][last_edge]
	var tangent := inward.orthogonal()
	var start: float = game.wave_time+LEAD
	var label: String = {"scout":"접근", "swarm":"무리 접근", "line":"행렬 접근", "heavy":"돌진 적", "guard":"원거리 호위"}[shape]
	warnings.append({"pos":anchor+inward*65,"until":start,"label":label,"dir":inward})
	stats.packs += 1
	for i in count:
		var kind := 3 if shape == "heavy" else 1
		var role := "swarm" if shape == "swarm" else ("line" if shape == "line" else "normal")
		var pos := anchor
		var delay := 0.0
		if shape == "line":
			delay = i*0.6
		elif shape == "heavy":
			pos += tangent*(i-(count-1)*0.5)*100
			delay = i*0.35
		else:
			var columns := 3
			# Front row enters first; later rows trail behind without reusing occupied cells.
			pos += tangent*((i%columns)-1)*56+inward*(int((count-1)/columns)-int(i/columns))*48
			delay = int(i/columns)*0.22
		pending.append({"at":start+delay,"kind":kind,"role":role,"pos":pos})
	if shape == "guard":
		# The escorts get a head start. Shooters stay behind and keep their distance.
		for i in 2:
			pending.append({"at":start+2.5+i*0.5,"kind":2,"role":"normal","pos":anchor+tangent*(i*110-55)})

func reward(kind: int) -> int:
	var remaining := maxi(0,int(config(game.wave).drop_budget)-dropped)
	var coins := mini(3 if kind == 3 else 1,remaining)
	dropped += coins
	return coins
