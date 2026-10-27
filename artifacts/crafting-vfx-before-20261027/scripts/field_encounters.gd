extends RefCounted
## One reward opportunity and one pressure elite per wave; no independent timers/nodes.
const TELL_SECONDS := 1.15
const CARRIER_LIFE := 24.0
const SENTINEL_AT := {2:55.0,3:45.0,4:45.0}
var game: Node2D
var enabled := true
var carrier_started := false
var sentinel_started := false
var tells: Array = []
var carrier: Node2D
var escorts: Array = []
var drop_at := Vector2.INF
var drop_ready := false
var carrier_left := 0.0
var goal := Vector2.ZERO
var decision_clock := 0.0
var last_death := Vector2.ZERO
var resolved := false
var stats := {"carriers":0,"escaped":0,"picked":0,"sentinels":0,"cancelled":0}

func _init(owner_game: Node2D) -> void: game=owner_game

func clear() -> void:
	tells.clear()
	carrier=null
	escorts.clear()
	drop_at=Vector2.INF
	drop_ready=false
	carrier_left=0
	resolved=false

func begin_wave() -> void:
	clear()
	enabled=true
	carrier_started=false
	sentinel_started=false
	stats={"carriers":0,"escaped":0,"picked":0,"sentinels":0,"cancelled":0}

func nearby_point(radius: float) -> Vector2:
	for attempt in 24:
		var point: Vector2=game.player.position+Vector2.RIGHT.rotated(game.rng.randf()*TAU)*game.rng.randf_range(340,470)
		if tells.any(func(t):return t.pos.distance_to(point)<240): continue
		if game.visible_world_rect().grow(-130).has_point(point) and game.director.available(point,radius,true): return point
	return Vector2.INF

func request_carrier() -> void:
	if not enabled or carrier_started or game.state!="combat" or game.wave>4: return
	carrier_started=true
	var point:=nearby_point(24)
	if point==Vector2.INF:
		stats.cancelled+=1
		return # The same earned choice is delivered at wave end; never accumulate spawn debt.
	tells.append({"kind":"carrier","pos":point,"left":TELL_SECONDS})
	game.announce("마법 재료를 물고 달아나는 실패작! 잡으면 먼저 주문을 고를 수 있어.",4)

func update(delta: float) -> void:
	if not enabled or game.state!="combat": return
	if SENTINEL_AT.has(game.wave) and not sentinel_started and game.wave_time>=SENTINEL_AT[game.wave]:
		sentinel_started=true
		var point:=nearby_point(32)
		if point!=Vector2.INF:
			tells.append({"kind":"sentinel","pos":point,"left":TELL_SECONDS})
			game.announce("과팽창 정예가 다가와! 밀어내기 어려우니 자리를 옮겨봐.",3)
	for index in range(tells.size()-1,-1,-1):
		var tell: Dictionary=tells[index]
		tell.left-=delta
		if tell.left>0: continue
		tells.remove_at(index)
		if not game.director.available(tell.pos,32 if tell.kind=="sentinel" else 24,true):
			stats.cancelled+=1
			continue
		if tell.kind=="sentinel":
			if game.spawn_enemy(3,false,tell.pos,"sentinel")!=null: stats.sentinels+=1
		else: spawn_carrier(tell.pos)
	if carrier_left>0 and not resolved and not drop_ready:
		carrier_left-=delta
		decision_clock-=delta
		if carrier_left<=0: escape()
	if drop_ready and game.player.position.distance_squared_to(drop_at)<=70.0*70.0:
		drop_ready=false
		drop_at=Vector2.INF
		stats.picked+=1
		resolved=true
		game.combat_rewards.issue(game.wave,"carrier")

func spawn_carrier(at: Vector2) -> void:
	carrier=game.spawn_enemy(1,false,at,"carrier")
	if carrier==null:
		stats.cancelled+=1
		return
	stats.carriers+=1
	carrier_left=CARRIER_LIFE
	decision_clock=0
	goal=at
	last_death=at
	# Even waves use the same carrier with existing enemy escorts, not new enemy species.
	if game.wave%2==0:
		var perpendicular: Vector2=game.player.position.direction_to(at).orthogonal()
		for offset in [-110.0,0.0,110.0]:
			var point: Vector2=at+perpendicular*offset+game.player.position.direction_to(at)*85
			var escort: Node2D=game.spawn_enemy(1,false,point,"escort")
			if escort!=null:
				escort.set_meta("formation_offset",point-at)
				escorts.append(escort)

func velocity(enemy: Node2D) -> Vector2:
	if enemy.role=="escort":
		if not is_instance_valid(carrier) or carrier.dead or enemy.position.distance_to(game.player.position)<210:
			return enemy.position.direction_to(game.player.position)*enemy.speed
		return (carrier.position+enemy.get_meta("formation_offset",Vector2.ZERO)-enemy.position).limit_length(enemy.speed)
	if decision_clock<=0 or enemy.position.distance_to(goal)<30:
		decision_clock=.8
		var fleeing: bool=enemy.position.distance_to(game.player.position)<350
		var direction: Vector2=game.player.position.direction_to(enemy.position) if fleeing else Vector2.RIGHT.rotated(game.rng.randf()*TAU)
		var bounds: Rect2=game.enemy_bounds().grow(-65)
		var best:=enemy.position
		var score: float=-INF
		for turn in [0.0,.6,-.6,1.2,-1.2,PI]:
			var candidate: Vector2=(enemy.position+direction.rotated(turn)*240).clamp(bounds.position,bounds.end)
			var value: float=candidate.distance_to(game.player.position) if fleeing else candidate.distance_to(enemy.position)
			if candidate.distance_to(enemy.position)>70 and value>score:
				best=candidate
				score=value
		goal=best
	var speed: float=enemy.speed if enemy.position.distance_to(game.player.position)<350 else 75.0
	return enemy.position.direction_to(goal)*speed

func died(enemy: Node2D) -> void:
	if enemy.role not in ["carrier","escort"]: return
	last_death=enemy.position
	var leader_alive: bool=is_instance_valid(carrier) and not carrier.dead
	var guards_alive: bool=escorts.any(func(e):return is_instance_valid(e) and not e.dead)
	if not leader_alive and not guards_alive and carrier_started and not drop_ready and not resolved:
		var walk: Rect2=game.player_bounds()
		drop_at=last_death.clamp(walk.position,walk.end)
		drop_ready=true
		game.ring(drop_at,48,Color("ffe7a3"),.7)
		game.announce("마법 재료를 떨어뜨렸어! 가까이 가서 회수해봐.",3)

func escape() -> void:
	if is_instance_valid(carrier): carrier.dead=true
	for escort in escorts:
		if is_instance_valid(escort): escort.dead=true
	carrier=null
	escorts.clear()
	stats.escaped+=1
	resolved=true
	game.announce("운반자가 달아났어. 확보한 선택권은 웨이브가 끝나면 받을 수 있어.",3)

func hint() -> String:
	var guards: Array=escorts.filter(func(e):return is_instance_valid(e) and not e.dead)
	var at:=drop_at if drop_ready else (carrier.position if is_instance_valid(carrier) and not carrier.dead else Vector2.INF)
	if at==Vector2.INF and not guards.is_empty(): at=guards[0].position
	if at==Vector2.INF: return ""
	var arrow: Vector2=game.player.position.direction_to(at)
	var direction: String="→" if absf(arrow.x)>absf(arrow.y) and arrow.x>0 else ("←" if absf(arrow.x)>absf(arrow.y) else ("↓" if arrow.y>0 else "↑"))
	if drop_ready: return "마법 재료 회수 "+direction
	if not is_instance_valid(carrier) or carrier.dead: return "남은 호위 %d · %s"%[guards.size(),direction]
	return "재료 운반자 %s · %.0f초"%[direction,carrier_left]

func draw(canvas: Node2D) -> void:
	for tell in tells:
		var color:=Color("ffe7a3") if tell.kind=="carrier" else Color("dfb6f5")
		canvas.draw_arc(tell.pos,32,0,TAU,32,Color(color,.8),3,true)
		canvas.draw_arc(tell.pos,45,0,TAU,32,Color(color,.3),1.5,true)
	if drop_ready:
		canvas.draw_circle(drop_at,24,Color(1,.85,.5,.16))
		canvas.draw_arc(drop_at,18,0,TAU,24,Color("ffe7a3"),2,true)
		canvas.draw_colored_polygon(PackedVector2Array([drop_at+Vector2(0,-10),drop_at+Vector2(9,0),drop_at+Vector2(0,10),drop_at+Vector2(-9,0)]),Color("ffe7a3"))
