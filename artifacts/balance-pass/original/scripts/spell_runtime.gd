extends RefCounted
## Bounded combat objects; no timers or unbounded recursive spell spawning.
const MAX_ZONES := 24
const MAX_ECHOES := 32
const PROFILE := {
	"bolt":{"speed":440.0,"damage":22.0,"radius":5.0,"life":2.6},
	"bloom":{"speed":290.0,"damage":20.0,"radius":8.0,"life":2.6},
	"boomerang":{"speed":460.0,"damage":24.0,"radius":11.0,"life":3.5},
	"vortex":{"speed":320.0,"damage":2.5,"radius":7.0,"life":0.85},
	"thorn":{"speed":320.0,"damage":45.0,"radius":7.0,"life":0.85}
}
var game: Node2D
var zones: Array = []
var echoes: Array = []

func _init(owner_game: Node2D) -> void:
	game = owner_game

func clear() -> void:
	zones.clear()
	echoes.clear()

func track(event: String, source := "", value := 1.0) -> void:
	if game.meter != null: game.meter.count(event,source,value)

func finish_projectile(p: Dictionary) -> void:
	track("projectiles_finished",p.get("meter_source",""))
	if not p.get("meter_contacted",false): track("projectiles_finished_without_contact",p.get("meter_source",""))

func emit(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power_snapshot := -1.0, meter_stage := "primary", meter_echo := false) -> void:
	if not game.magic_active(): return
	var source := meter_stage+"/"+str(stage.attack)+("/echo" if meter_echo else "")
	var power: float = game.power if power_snapshot < 0 else power_snapshot
	var count := 3 if stage.fan else 1
	var scale := 1.6 if stage.get("giant",false) else 1.0
	var strength: float = factor*power*(0.65 if stage.fan else 1.0)
	var spec: Dictionary = PROFILE[stage.attack]
	if stage.get("echo",false) and echoes.size() < MAX_ECHOES:
		var copy := stage.duplicate()
		copy.echo = false
		echoes.append({"stage":copy,"origin":origin,"direction":direction,"follow":follow.duplicate(),"factor":factor*0.55,"power":power,"delay":0.18,"meter_stage":meter_stage})
		track("echoes_scheduled",source)
	elif stage.get("echo",false): track("echoes_blocked",source)
	for i in count:
		if game.projectiles.size() >= game.MAX_PROJECTILES:
			track("projectiles_blocked",source,count-i)
			break
		track("projectiles_emitted",source)
		var dir := direction.rotated((i-(count-1)*0.5)*0.24)
		game.projectiles.append({"pos":origin,"dir":dir,"speed":spec.speed,"damage":spec.damage*strength,
			"attack":stage.attack,"radius":spec.radius*scale,"life":spec.life,"seek":stage.seek,
			"pierce":2 if stage.pierce else 0,"bounces":2 if stage.get("bounce",false) else 0,
			"follow":follow.duplicate(),"triggered":false,"hit":{},"target":null,"seek_clock":0.0,
			"strength":strength,"scale":scale,"power":power,"child_factor":factor*0.65,
			"meter_source":source,"meter_echo":meter_echo,"meter_contacted":false,
			"age":0.0,"returning":false,"leg_hits":0,"leg_limit":3 if stage.pierce else 1})

func update_echoes(delta: float) -> void:
	for i in range(echoes.size()-1,-1,-1):
		var echo: Dictionary = echoes[i]
		echo.delay -= delta
		if echo.delay <= 0:
			echoes.remove_at(i)
			track("echoes_fired",echo.meter_stage+"/"+str(echo.stage.attack)+"/echo")
			emit(echo.stage,echo.origin,echo.direction,echo.follow,echo.factor,echo.power,echo.meter_stage,true)

func trigger(source: Dictionary, at: Vector2) -> void:
	if source.triggered or source.follow.is_empty(): return
	source.triggered = true
	# The child has no connector; echo copies carry a reduced child factor too.
	track("triggers",source.get("meter_source",""))
	emit(source.follow,at,source.dir,{},source.child_factor,source.power,"secondary",source.get("meter_echo",false))
	game.metrics.triggers += 1
	game.ring(at,25,Color("ff9cae"),0.2)

func turn_back(p: Dictionary) -> void:
	p.returning = true
	p.hit.clear()
	p.leg_hits = 0
	p.target = null

func install(p: Dictionary) -> void:
	if zones.size() >= MAX_ZONES:
		var removed: Dictionary = zones.pop_front()
		track("zones_evicted",removed.get("meter_source",""))
	track("zones_created",p.get("meter_source",""))
	var vortex: bool = p.attack == "vortex"
	zones.append({"kind":p.attack,"pos":p.pos,"dir":p.dir,"radius":(86.0 if vortex else 62.0)*p.scale,
		"damage":p.damage,"life":3.0 if vortex else 6.0,"age":0.0,"pulse":0.35 if vortex else 0.0,
		"meter_source":p.get("meter_source",""),"meter_echo":p.get("meter_echo",false),
		"follow":p.follow.duplicate(),"triggered":false,"child_factor":p.child_factor,"power":p.power})

func bounce(p: Dictionary, at: Vector2) -> bool:
	if p.bounces <= 0: return false
	var target: Node2D = game.nearest_enemy(at,240,p.hit)
	if target == null: return false
	track("bounces",p.get("meter_source",""))
	p.bounces -= 1
	p.dir = at.direction_to(target.position)
	if p.dir.is_zero_approx(): p.dir = Vector2.RIGHT
	p.pos = at
	p.target = target
	# Preserve a bounce direction briefly even when homing is also equipped.
	p.seek_clock = 0.15
	return true

func update_projectiles(delta: float) -> void:
	for index in range(game.projectiles.size()-1,-1,-1):
		var p: Dictionary = game.projectiles[index]
		p.life -= delta
		p.age += delta
		var seed: bool = p.attack in ["vortex","thorn"]
		var moon: bool = p.attack == "boomerang"
		if p.life <= 0:
			if seed: install(p)
			elif p.attack == "bloom": game.explode(p.pos,p.damage,70*p.scale,p.get("meter_source",""))
			if not game.magic_active(): return
			finish_projectile(p)
			game.projectiles.remove_at(index)
			continue
		if moon and not p.returning and p.age >= 0.65: turn_back(p)
		if moon and p.returning:
			var offset: Vector2 = game.player.position-p.pos
			if offset.length() <= 20+520*delta:
				finish_projectile(p)
				game.projectiles.remove_at(index)
				continue
			p.dir = offset.normalized()
			p.speed = 520.0
		elif p.seek:
			p.seek_clock -= delta
			if p.seek_clock <= 0:
				p.seek_clock = 0.15
				p.target = game.nearest_enemy(p.pos,260,p.hit)
			if is_instance_valid(p.target) and not p.target.dead:
				var desired: Vector2 = p.pos.direction_to(p.target.position)
				p.dir = p.dir.lerp(desired,minf(1,delta*6.0)).normalized()
		var old: Vector2 = p.pos
		p.pos += p.dir*p.speed*delta
		var consumed := false
		if not moon or p.leg_hits < p.leg_limit:
			var candidates: Array = game.nearby((old+p.pos)*0.5,old.distance_to(p.pos)*0.5+45+p.radius)
			candidates.sort_custom(func(a: Node2D,b: Node2D): return old.distance_squared_to(a.position) < old.distance_squared_to(b.position))
			for enemy in candidates:
				if enemy.dead or p.hit.has(enemy.get_instance_id()): continue
				var nearest := Geometry2D.get_closest_point_to_segment(enemy.position,old,p.pos)
				if nearest.distance_squared_to(enemy.position) > pow(enemy.radius+p.radius,2): continue
				track("projectile_contacts",p.get("meter_source",""))
				if not p.get("meter_contacted",false):
					p.meter_contacted = true
					track("projectiles_contacted",p.get("meter_source",""))
				p.hit[enemy.get_instance_id()] = true
				if not seed:
					if p.attack == "bloom": game.explode(nearest,p.damage,70*p.scale,p.get("meter_source",""))
					else: game.damage_enemy(enemy,p.damage,p.dir,p.get("meter_source",""))
					if not game.magic_active(): return
					trigger(p,nearest)
				# Returning moons always head for the caster; outgoing moons can ricochet.
				if not (moon and p.returning) and bounce(p,nearest): break
				if moon:
					p.leg_hits += 1
					if p.leg_hits >= p.leg_limit: break
				else:
					p.pierce -= 1
					if p.pierce < 0:
						if seed:
							p.pos = nearest
							install(p)
						consumed = true
						break
		if consumed or (not moon and not Rect2(-80,-80,1600,1060).has_point(p.pos)):
			finish_projectile(p)
			game.projectiles.remove_at(index)

func update_zones(delta: float) -> void:
	var pulls: Dictionary = {}
	for i in range(zones.size()-1,-1,-1):
		var zone: Dictionary = zones[i]
		zone.life -= delta
		zone.age += delta
		if zone.life <= 0:
			zones.remove_at(i)
			continue
		var victims: Array = game.nearby(zone.pos,zone.radius+45)
		if zone.kind == "vortex":
			for enemy in victims:
				var offset: Vector2 = zone.pos-enemy.position
				if enemy.boss or offset.length() > zone.radius+enemy.radius: continue
				var id: int = enemy.get_instance_id()
				if not pulls.has(id): pulls[id] = {"enemy":enemy,"velocity":Vector2.ZERO}
				# Prevent overshoot and cap combined pulls after all fields contribute.
				pulls[id].velocity += offset.limit_length(100*delta)/maxf(delta,0.0001)
			zone.pulse -= delta
			if zone.pulse <= 0:
				track("zone_pulses",zone.get("meter_source",""))
				zone.pulse = 0.25
				for enemy in victims:
					if enemy.dead or enemy.position.distance_to(zone.pos) > zone.radius+enemy.radius: continue
					game.damage_enemy(enemy,zone.damage,Vector2.ZERO,zone.get("meter_source",""))
					if not game.magic_active(): return
					trigger(zone,enemy.position)
		elif zone.age >= 0.25:
			var activated := false
			for enemy in victims:
				if not enemy.dead and enemy.position.distance_to(zone.pos) <= zone.radius+enemy.radius:
					activated = true
					break
			if activated:
				track("trap_activations",zone.get("meter_source",""))
				game.ring(zone.pos,zone.radius,Color("b8ed9a"),0.32)
				for enemy in victims:
					if enemy.dead or enemy.position.distance_to(zone.pos) > zone.radius+enemy.radius: continue
					game.damage_enemy(enemy,zone.damage,zone.pos.direction_to(enemy.position),zone.get("meter_source",""))
					if not game.magic_active(): return
					trigger(zone,enemy.position)
				zones.remove_at(i)
	for pull in pulls.values():
		var enemy: Node2D = pull.enemy
		if is_instance_valid(enemy) and not enemy.dead:
			var before: Vector2 = enemy.position
			enemy.position += pull.velocity.limit_length(100)*delta
			enemy.position = enemy.position.clamp(Vector2(35,95),Vector2(1405,795))
			track("pull_enemy_seconds","",delta)
			track("pull_distance","",before.distance_to(enemy.position))
