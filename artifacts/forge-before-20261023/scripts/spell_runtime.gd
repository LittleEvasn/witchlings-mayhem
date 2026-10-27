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
const Behaviors = preload("res://scripts/spell_behaviors.gd")
var behavior: RefCounted
var generation := 0
var game: Node2D
var zones: Array = []
var echoes: Array = []

func _init(owner_game: Node2D) -> void:
	game = owner_game
	behavior = Behaviors.new(self)

func clear() -> void:
	zones.clear()
	echoes.clear()
	behavior.clear()
	generation += 1

func track(event: String, source := "", value := 1.0) -> void:
	if game.meter != null: game.meter.count(event,source,value)

func finish_projectile(p: Dictionary) -> void:
	track("projectiles_finished",p.get("meter_source",""))
	if not p.get("meter_contacted",false):
		track("projectiles_finished_without_contact",p.get("meter_source",""))
		if p.get("stage",{}).get("charge",false): track("charged_projectiles_missed",p.get("meter_source",""))

func emit(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power_snapshot := -1.0, meter_stage := "primary", meter_echo := false, lineage := -1, emitted_generation := -1, target_point := Vector2.INF) -> void:
	if not game.magic_active(): return
	if stage.get("graft",false) and not stage.attack in ["vortex","thorn"] and not stage.get("_graft_release",false):
		var gathered: Dictionary = behavior.gather(stage,factor,power_snapshot if power_snapshot>=0 else game.power,meter_stage)
		if gathered.is_empty(): return
		stage = gathered.stage
		factor = gathered.factor
		power_snapshot = gathered.power
	if lineage < 0:
		behavior.cast_serial += 1
		lineage = behavior.cast_serial
	if emitted_generation < 0: emitted_generation = generation
	if stage.get("charge",false): track("charged_stages")
	var source := meter_stage+"/"+str(stage.attack)+("/echo" if meter_echo else "")
	var power: float = game.power if power_snapshot < 0 else power_snapshot
	var count := 3 if stage.fan else 1
	var scale: float = (1.6 if stage.get("giant",false) else 1.0)*stage.get("_growth",1.0)
	# Keep the inherited spell factor separate from the caster's power snapshot.
	var shot_factor: float = factor*(0.65 if stage.fan else 1.0)
	var ctx: Dictionary = behavior.context(stage,origin,direction,follow,shot_factor,power,meter_stage,meter_echo,lineage,emitted_generation)
	var strength: float = behavior.damage_scale(ctx)
	if target_point==Vector2.INF: target_point = game.cast_target
	ctx["target_point"] = target_point
	var seed_portions := 3 if stage.pierce and stage.attack in ["vortex","thorn"] else 1
	if stage.get("echo",false) and echoes.size() < MAX_ECHOES:
		var copy := stage.duplicate()
		copy.echo = false
		echoes.append({"stage":copy,"origin":origin,"direction":direction,"follow":follow.duplicate(),"factor":factor*0.55,"power":power,"delay":0.18,"meter_stage":meter_stage,"lineage":lineage,"generation":emitted_generation,"target_point":target_point})
		track("echoes_scheduled",source)
	elif stage.get("echo",false): track("echoes_blocked",source)
	if not PROFILE.has(stage.attack):
		behavior.special(ctx)
		return
	var spec: Dictionary = PROFILE[stage.attack]
	for i in count:
		if game.projectiles.size() >= game.MAX_PROJECTILES:
			track("projectiles_blocked",source,count-i)
			break
		track("projectiles_emitted",source)
		var dir := direction.rotated((i-(count-1)*0.5)*0.24)
		var projectile := ctx.duplicate(true)
		projectile.merge({"pos":origin,"dir":dir,"speed":spec.speed,"damage":spec.damage*strength,
			"attack":stage.attack,"radius":spec.radius*scale,"life":spec.life*(2.0 if seed_portions > 1 else 1.0),"seek":stage.seek,
			"pierce":2 if stage.pierce else 0,"bounces":2 if stage.get("bounce",false) else 0,
			"follow":follow.duplicate(),"triggered":false,"hit":{},"target":null,"seek_clock":0.0,
			"strength":strength,"scale":scale,"power":power,"child_factor":shot_factor*0.65,
			"seed_portion_count":seed_portions,"seed_portions":seed_portions,
			"meter_source":source,"meter_echo":meter_echo,"meter_contacted":false,
			"age":0.0,"returning":false,"leg_hits":0,"leg_limit":3 if stage.pierce else 1},true)
		game.projectiles.append(projectile)

func update_echoes(delta: float) -> void:
	behavior.update(delta)
	if not game.magic_active(): return
	for i in range(echoes.size()-1,-1,-1):
		var echo: Dictionary = echoes[i]
		echo.delay -= delta
		if echo.delay <= 0:
			echoes.remove_at(i)
			track("echoes_fired",echo.meter_stage+"/"+str(echo.stage.attack)+"/echo")
			emit(echo.stage,echo.origin,echo.direction,echo.follow,echo.factor,echo.power,echo.meter_stage,true,echo.lineage,echo.generation,echo.target_point)

func trigger(source: Dictionary, at: Vector2, event := "impact") -> void:
	if source.get("connector","impact") != event: return
	if source.triggered or source.follow.is_empty(): return
	source.triggered = true
	# The child has no connector; echo copies carry a reduced child factor too.
	track("triggers",source.get("meter_source",""))
	var direction: Vector2 = game.aim if event=="on_return" else source.get("original_dir",source.dir)
	emit(source.follow,at,direction,{},source.child_factor,source.get("child_power",source.power),"secondary",source.get("meter_echo",false),source.get("cast_id",-1),source.get("generation",generation),at)
	game.metrics.triggers += 1
	game.ring(at,25,Color("ff9cae"),0.2)

func turn_back(p: Dictionary) -> void:
	p.returning = true
	p.hit.clear()
	p.leg_hits = 0
	p.target = null

func install(p: Dictionary, portions := 0) -> void:
	var remaining: int = p.seed_portions
	var used: int = remaining if portions <= 0 else mini(portions,remaining)
	if used <= 0: return
	# A piercing seed spreads one spell's damage/trigger budget over up to three sites.
	# Any unused portions land together at the last contact or at flight expiry.
	var share := float(used)/float(p.seed_portion_count)
	p.seed_portions -= used
	track("zones_created",p.get("meter_source",""))
	var vortex: bool = p.attack == "vortex"
	var zone := p.duplicate(true)
	zone.factor *= share
	zone.merge({"kind":p.attack,"pos":p.pos,"dir":p.dir,"radius":(86.0 if vortex else 62.0)*p.scale,
		"damage":p.damage*share,"life":3.0 if vortex else 6.0,"age":0.0,"pulse":0.35 if vortex else 0.0,
		"meter_source":p.get("meter_source",""),"meter_echo":p.get("meter_echo",false),
		"follow":p.follow.duplicate(),"triggered":false,"child_factor":p.child_factor*share,"power":p.power},true)
	if not behavior.install_graft(zone):
		if zones.size()>=MAX_ZONES: evict_zone(zones[0])
		zones.append(zone)

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
			elif p.attack == "bloom": behavior.area(p,p.pos,p.damage,70*p.scale)
			if not game.magic_active(): return
			if not seed: trigger(p,p.pos,"expire")
			finish_projectile(p)
			game.projectiles.remove_at(index)
			continue
		if moon and not p.returning and p.age >= 0.65: turn_back(p)
		if moon and p.returning:
			var offset: Vector2 = game.player.position-p.pos
			if offset.length() <= 24:
				trigger(p,game.player.position,"on_return")
				trigger(p,game.player.position,"expire")
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
					if p.attack == "bloom": behavior.area(p,nearest,p.damage,70*p.scale)
					else: behavior.hit(enemy,p.damage,p.dir,p)
					if not game.magic_active(): return
					trigger(p,nearest)
				elif p.seed_portion_count > 1:
					p.pos = nearest
					install(p,1)
					if p.seed_portions == 0:
						consumed = true
						break
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
			if seed and consumed: install(p)
			if consumed and not seed: trigger(p,p.pos,"expire")
			finish_projectile(p)
			game.projectiles.remove_at(index)

func evict_zone(zone: Dictionary) -> void:
	if zone.kind=="ember_path": behavior.end_path(zone,false)
	track("zones_evicted",zone.get("meter_source",""))
	zones.erase(zone)

func update_zones(delta: float) -> void:
	var pulls: Dictionary = {}
	var path_hits: Dictionary = {}
	var path_ended: Array = []
	# Iterate a snapshot: a finishing connector may append another field.
	for zone in zones.duplicate():
		if not zones.has(zone): continue
		zone.life -= delta
		zone.age += delta
		if zone.kind=="ember_path":
			zone.pulse -= delta
			if zone.pulse<=0:
				zone.pulse += 0.3
				for enemy in game.nearby(zone.pos,zone.radius+45):
					if enemy.dead or enemy.position.distance_to(zone.pos)>zone.radius+enemy.radius: continue
					var key := str([enemy.get_instance_id(),zone.generation,zone.get("owner_orb",0)])
					var strongest: Dictionary = zone
					for other in zones:
						if other.kind=="ember_path" and other.generation==zone.generation and other.get("owner_orb",0)==zone.get("owner_orb",0) and other.damage>strongest.damage and enemy.position.distance_to(other.pos)<=other.radius+enemy.radius: strongest = other
					if not path_hits.has(key) or path_hits[key].zone.damage<strongest.damage: path_hits[key] = {"zone":strongest,"enemy":enemy}
			if zone.life<=0:
				zones.erase(zone)
				path_ended.append(zone)
			continue
		var graft: bool = zone.stage.get("graft",false)
		var ending: bool = zone.life<=0
		if zone.kind=="thorn" and graft and zone.mature_at>=0 and zone.age>=zone.mature_at: ending = true
		var victims: Array = game.nearby(zone.pos,zone.radius+45)
		if zone.kind=="vortex":
			for enemy in victims:
				var offset: Vector2 = zone.pos-enemy.position
				if enemy.boss or offset.length()>zone.radius+enemy.radius or behavior.movement_factor(enemy)==0: continue
				var id: int = enemy.get_instance_id()
				if not pulls.has(id): pulls[id] = {"enemy":enemy,"velocity":Vector2.ZERO}
				pulls[id].velocity += offset.limit_length(100*delta)/maxf(delta,0.0001)
			zone.pulse -= delta
			if zone.pulse<=0 or (ending and graft):
				zone.pulse += 0.25
				var amount: float = zone.damage
				if graft:
					amount = zone.budget if ending else minf(zone.budget,zone.budget*0.25/maxf(0.25,zone.life))
					zone.budget = maxf(0,zone.budget-amount)
					track("graft_budget_spent",zone.meter_source,amount)
				track("zone_pulses",zone.meter_source)
				for enemy in victims:
					if enemy.dead or enemy.position.distance_to(zone.pos)>zone.radius+enemy.radius: continue
					behavior.hit(enemy,amount,Vector2.ZERO,zone)
					if not game.magic_active(): return
					trigger(zone,enemy.position)
		else:
			var activated := ending and graft
			if not graft and zone.age>=0.25 and not ending:
				for enemy in victims:
					if not enemy.dead and enemy.position.distance_to(zone.pos)<=zone.radius+enemy.radius: activated = true
			if activated:
				track("trap_activations",zone.meter_source)
				var amount: float = zone.budget if graft else zone.damage
				game.ring(zone.pos,zone.radius,Color("b8ed9a"),0.32)
				for enemy in victims:
					if enemy.dead or enemy.position.distance_to(zone.pos)>zone.radius+enemy.radius: continue
					behavior.hit(enemy,amount,Vector2.ZERO,zone)
					if not game.magic_active(): return
					trigger(zone,enemy.position)
				ending = true
		if ending:
			zones.erase(zone)
			trigger(zone,zone.pos,"expire")
	for pair in path_hits.values():
		var zone: Dictionary = pair.zone
		var enemy: Node2D = pair.enemy
		var s: Dictionary = behavior.state_for(enemy)
		var key := "path_"+str(zone.generation)+"_"+str(zone.get("owner_orb",0))
		if behavior.clock-float(s.get(key,-100))<0.299: continue
		s[key] = behavior.clock
		behavior.hit(enemy,zone.damage,Vector2.ZERO,zone)
		if not game.magic_active(): return
		trigger(zone.group,enemy.position)
		behavior.extra_links(zone.group,enemy.position,enemy)
	for zone in path_ended: behavior.end_path(zone,true)
	for pull in pulls.values():
		var enemy: Node2D = pull.enemy
		if is_instance_valid(enemy) and not enemy.dead:
			var before: Vector2 = enemy.position
			enemy.position += pull.velocity.limit_length(100)*delta
			enemy.position = enemy.position.clamp(Vector2(35,95),Vector2(1405,795))
			track("pull_enemy_seconds","",delta)
			track("pull_distance","",before.distance_to(enemy.position))
