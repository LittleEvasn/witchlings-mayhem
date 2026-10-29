extends RefCounted
## Bounded species tactics. Shared still sprites use existing bounce/lean, not walk cycles.
const Catalog=preload("res://scripts/monster_catalog.gd")
const HAZARD_CAP:=10
const ACTIVE_TACTICS:=4
var game: Node2D
var hazards: Array=[]
func _init(owner_game: Node2D) -> void: game=owner_game
func clear() -> void: hazards.clear()
func reset_actor(enemy: Node2D) -> void:
	enemy.tactics.clear()
	enemy.windup=0;enemy.charge_time=0;enemy.recovery_left=0;enemy.shot_windup=0
	enemy.jump_height=0
func can_attack(enemy: Node2D) -> bool:
	var active:=0
	for e in game.enemies:
		if e==enemy or e.dead or e.boss: continue
		if e.windup>0 or e.charge_time>0 or e.shot_windup>0 or e.tactics.get("phase","") in ["hop","fuse"]: active+=1
	return active<ACTIVE_TACTICS
func velocity(e: Node2D, delta: float, direction: Vector2, distance: float) -> Vector2:
	if e.boss or e.role in ["carrier","escort","sentinel"]: return Vector2.INF
	match e.monster_id:
		"paper": return (direction+direction.orthogonal()*sin(e.age*2+e.seed_phase)*.18).normalized()*e.speed
		"ink": return direction*e.speed
		"book":
			if not e.tactics.has("guard"): e.tactics.guard=direction
			if e.cooldown<=0 and e.windup<=0:
				e.windup=.65;e.tactics.next_guard=direction;e.cooldown=2.4
			if e.windup>0:
				e.windup=maxf(0,e.windup-delta)
				if e.windup<=0: e.tactics.guard=e.tactics.next_guard
				return Vector2.ZERO
			return direction*e.speed
		"rabbit": return rabbit(e,delta,direction,distance)
		"candle":
			if e.tactics.get("phase","")=="fuse":
				e.windup=maxf(0,e.windup-delta)
				if e.windup<=0:
					e.dead=true # Self-explosion is not a kill or a currency source.
					game.ring(e.position,86,Color("ff9cae"),.35)
					if e.position.distance_to(game.player.position)<86+game.player.radius: game.hurt_player(16)
				return Vector2.ZERO
			if distance<150 and e.cooldown<=0 and can_attack(e):
				e.tactics.phase="fuse";e.windup=1.1
				return Vector2.ZERO
			return direction*e.speed
	return Vector2.INF
func rabbit(e: Node2D, delta: float, direction: Vector2, distance: float) -> Vector2:
	var phase: String=e.tactics.get("phase","")
	if phase.is_empty():
		if e.cooldown<=0 and distance<600 and can_attack(e):
			e.tactics={"phase":"tell","left":.8,"direction":direction,"hops":2}
			e.charge_direction=direction;e.windup=.8
			return Vector2.ZERO
		return direction*e.speed
	var step:=minf(delta,float(e.tactics.left))
	e.tactics.left=maxf(0,float(e.tactics.left)-delta)
	var left: float=e.tactics.left
	match phase:
		"tell":
			e.windup=left
			if left<=0: e.tactics.phase="hop";e.tactics.left=.24
		"hop":
			e.jump_height=sin((1-left/.24)*PI)*25
			if left<=0:
				e.jump_height=0;e.tactics.hops-=1
				e.tactics.phase="gap" if e.tactics.hops>0 else "recover"
				e.tactics.left=.22 if e.tactics.hops>0 else .7
			return e.tactics.direction*300*step/maxf(delta,.00001)
		"gap":
			if left<=0: e.tactics.phase="hop";e.tactics.left=.24
		"recover":
			if left<=0: e.tactics.clear();e.cooldown=3.6
	return Vector2.ZERO
func incoming(enemy: Node2D, damage: float, direction: Vector2) -> float:
	if enemy.monster_id!="book" or enemy.boss or direction.length_squared()<.01: return damage
	var guard: Vector2=enemy.tactics.get("guard",enemy.position.direction_to(game.player.position))
	return damage*.55 if (-direction.normalized()).dot(guard)>.5 and enemy.windup<=0 else damage
func died(enemy: Node2D) -> void:
	if enemy.monster_id!="ink" or game.state!="combat": return
	if hazards.size()>=HAZARD_CAP: return
	hazards.append({"pos":enemy.position,"tell":.75,"life":2.4,"tick":0.0,"radius":50.0})
func update(delta: float) -> void:
	for i in range(hazards.size()-1,-1,-1):
		var h: Dictionary=hazards[i]
		if h.tell>0:
			h.tell=maxf(0,h.tell-delta)
			continue
		h.life-=delta;h.tick-=delta
		if h.life<=0: hazards.remove_at(i);continue
		if h.tick<=0:
			h.tick=.5
			if h.pos.distance_to(game.player.position)<h.radius+game.player.radius: game.hurt_player(8)
			if game.state!="combat": return
func draw(canvas: Node2D) -> void:
	for h in hazards:
		var c:=Color("d49aff")
		canvas.draw_circle(h.pos,h.radius,Color(c,.06 if h.tell>0 else .20))
		canvas.draw_arc(h.pos,h.radius,0,TAU,32,Color(c,.85),2,true)
		if h.tell>0: canvas.draw_arc(h.pos,h.radius*(1-h.tell/.75),0,TAU,24,Color(c,.55),1.5,true)
