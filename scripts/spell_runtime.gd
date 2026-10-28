extends RefCounted
## Bounded combat objects; no timers or unbounded recursive spell spawning.
const MAX_ZONES := 256
const MAX_ECHOES := 96
const PROFILE := {
	"bolt":{"speed":440.0,"damage":22.0,"radius":5.0,"life":2.6},
	"bloom":{"speed":290.0,"damage":20.0,"radius":8.0,"life":2.6},
	"boomerang":{"speed":460.0,"damage":24.0,"radius":11.0,"life":5.0},
	"vortex":{"speed":320.0,"damage":2.5,"radius":7.0,"life":0.85},
	"thorn":{"speed":320.0,"damage":45.0,"radius":7.0,"life":0.85}
}
const Behaviors = preload("res://scripts/spell_behaviors.gd")
const FusionEffects = preload("res://scripts/fusion_effects.gd")
const SupportFusions=preload("res://scripts/support_fusions.gd")
var support: RefCounted
var fusion: RefCounted
var behavior: RefCounted
const MAX_EMITS_PER_TICK := 64
const MAX_CHAIN_DEPTH := 6
var emits_this_tick := 0
var installing_batch := false
var generation := 0
var game: Node2D
var zones: Array = []
var zone_serial := 0
var live_zones := {}
var echoes: Array = []

func _init(owner_game: Node2D) -> void:
	game = owner_game
	behavior = Behaviors.new(self)
	fusion = FusionEffects.new(self)
	support = SupportFusions.new(self)

func begin_tick() -> void:
	emits_this_tick = 0

func clear() -> void:
	emits_this_tick = 0
	installing_batch = false
	zones.clear()
	live_zones.clear()
	echoes.clear()
	behavior.clear()
	fusion.clear()
	support.clear()
	generation += 1

func track(event: String, source := "", value := 1.0) -> void:
	if game.meter != null: game.meter.count(event,source,value)

func source_for(stage: Dictionary, lane: String, echo: bool) -> String:
	var label := lane+"/"+str(stage.get("source_id",stage.attack))+("/echo" if echo else "")
	if stage.get("_relic_copy",false): label += "/relic_copy"
	if game.meter!=null and game.meter.detailed_sources:
		label = "o%d/s%d/"%[stage.get("_orb",0),stage.get("slot",-1)]+label
	return label

func finish_projectile(p: Dictionary) -> void:
	track("projectiles_finished",p.get("meter_source",""))
	if not p.get("meter_contacted",false):
		track("projectiles_finished_without_contact",p.get("meter_source",""))
		if p.get("stage",{}).get("charge",false): track("charged_projectiles_missed",p.get("meter_source",""))

func emit(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power_snapshot := -1.0, meter_stage := "primary", meter_echo := false, lineage := -1, emitted_generation := -1, target_point := Vector2.INF) -> void:
	if not game.magic_active(): return
	# Snapshot once per cast tree; descendants carry this value rather than multiply it.
	stage = stage.duplicate()
	if not stage.has("_relic_scale"): stage["_relic_scale"] = game.relics.size_multiplier()
	if int(stage.get("_depth",0))>MAX_CHAIN_DEPTH:
		track("chain_depth_blocked",meter_stage)
		return
	if emits_this_tick>=MAX_EMITS_PER_TICK:
		track("emits_blocked",meter_stage)
		return
	emits_this_tick += 1
	if follow.is_empty(): follow = game.Spells.follow(stage)
	if lineage < 0:
		behavior.cast_serial += 1
		lineage = behavior.cast_serial
	if emitted_generation < 0: emitted_generation = generation
	if stage.get("charge",false): track("charged_stages")
	var source := source_for(stage,meter_stage,meter_echo)
	var power: float = game.caster_power()*float(stage.get("_orb_power",1.0)) if power_snapshot < 0 else power_snapshot
	track("stage_casts",source)
	track("orb_%d_slot_%d" % [stage.get("_orb",0),stage.get("slot",-1)],source)
	var count: int = game.Spells.branches(stage)
	var scale: float = game.Spells.scale(stage)
	# Keep the inherited spell factor separate from the caster's power snapshot.
	# Factor carries the parent's partition, not its connector potency. This stage
	# partitions that inherited budget once among its own outgoing branches.
	var pattern: Dictionary=support.repetitions(stage)
	var shot_factor: float = factor*float(pattern.primary)*game.Spells.Effects.value(stage,"fan")
	var ctx: Dictionary = behavior.context(stage,origin,direction,follow,shot_factor,power,meter_stage,meter_echo,lineage,emitted_generation)
	var strength: float = behavior.damage_scale(ctx)
	if target_point==Vector2.INF: target_point = game.cast_target
	ctx["target_point"] = target_point
	ctx.child_factor = shot_factor
	ctx["potency"] = float(stage.get("_connector_potency",1.0))
	strength = behavior.damage_scale(ctx)
	var seed_portions: int = 1+int(game.Spells.Effects.profile(stage,"pierce").targets) if stage.attack in ["vortex","thorn"] else 1
	var repeats: Array = [] if stage.get("_echo_copy",false) else game.Spells.Effects.profile(stage,"echo").repeats
	for repeat in repeats.size():
		if echoes.size()>=MAX_ECHOES:
			track("echoes_blocked",source)
			continue
		var copy := stage.duplicate(true)
		copy.echo = 0
		copy["_echo_copy"] = true
		echoes.append({"stage":copy,"origin":origin,"direction":direction,"follow":follow.duplicate(true),"factor":factor*float(pattern.primary)*float(repeats[repeat]),"power":power,"delay":0.18*(repeat+1),"meter_stage":meter_stage,"lineage":lineage,"generation":emitted_generation,"target_point":target_point})
		track("echoes_scheduled",source)
	for repeat in pattern.copies:
		if echoes.size()>=MAX_ECHOES:
			track("echoes_blocked",source)
			continue
		var copy:=stage.duplicate(true)
		copy.echo=0
		copy["_echo_copy"]=true
		copy["_support_scale"]=float(stage.get("_support_scale",1.0))*repeat.scale
		echoes.append({"stage":copy,"origin":origin,"direction":direction,"follow":follow.duplicate(true),"factor":factor*repeat.factor,"power":power,"delay":repeat.delay,"meter_stage":meter_stage,"lineage":lineage,"generation":emitted_generation,"target_point":target_point})
		track("support_repeats_scheduled",source)
	if not PROFILE.has(stage.attack):
		behavior.special(ctx)
		return
	var spec: Dictionary = PROFILE[stage.attack]
	var angles: Array = game.Spells.shot_angles(stage)
	count = angles.size()
	for i in count:
		if game.projectiles.size() >= game.MAX_PROJECTILES:
			track("projectiles_blocked",source,count-i)
			break
		track("projectiles_emitted",source)
		var dir: Vector2 = support.branch_direction(stage,origin,direction.rotated(deg_to_rad(float(angles[i]))),i)
		var projectile := ctx.duplicate(true)
		projectile.merge({"pos":origin,"dir":dir,"speed":spec.speed*float(stage.get("_orb_speed",1.0)),"damage":spec.damage*strength,
			"attack":stage.attack,"radius":spec.radius*scale,"life":spec.life*float(stage.get("_orb_life",1.0))*(2.0 if seed_portions > 1 else 1.0),"seek":stage.seek,
			"pierce":int(game.Spells.Effects.profile(stage,"pierce").targets),
			"follow":follow.duplicate(),"triggered":false,"hit":{},"target":null,"seek_clock":0.0,
			"strength":strength,"scale":scale,"power":power,"child_factor":shot_factor,"swarm_index":i,
			"seed_portion_count":seed_portions,"seed_portions":seed_portions,
			"meter_source":source,"meter_echo":meter_echo,"meter_contacted":false,
			"age":0.0,"returning":false,"leg_hits":0,"leg_limit":1+int(game.Spells.Effects.profile(stage,"pierce").targets)},true)
		game.projectiles.append(projectile)
		if stage.attack=="boomerang":
			projectile["ricochets"] = game.Spells.attack_data(stage).ricochets
			projectile["outbound_limit"] = 1.0+0.6*projectile.ricochets+(.3*projectile.pierce if stage.get("chase_pierce",0)>0 else 0.0)
			projectile["buds"] = []
			var target: Node2D = game.nearest_enemy(origin+dir*220,260,{})
			if target!=null and dir.dot(origin.direction_to(target.position))<=0.5: target = null
			var endpoint: Vector2 = target.position if target!=null else origin+dir*300
			moon_leg(projectile,endpoint,target)
		if stage.get("fusion","")=="storm_spear": projectile.pierce += 2

func update_echoes(delta: float) -> void:
	behavior.update(delta)
	fusion.update(delta)
	support.update(delta)
	if not game.magic_active(): return
	for i in range(echoes.size()-1,-1,-1):
		var echo: Dictionary = echoes[i]
		echo.delay -= delta
		if echo.delay <= 0:
			echoes.remove_at(i)
			if echo.generation!=generation: continue
			track("echoes_fired",source_for(echo.stage,echo.meter_stage,true))
			emit(echo.stage,echo.origin,echo.direction,echo.follow,echo.factor,echo.power,echo.meter_stage,true,echo.lineage,echo.generation,echo.target_point)

func trigger(source: Dictionary, at: Vector2, event := "impact") -> void:
	var mode: String=source.get("connector","impact")
	if mode in ["dual_event","delayed_ignition"] and source.get("generation",generation)!=generation: return
	if mode=="dual_event":
		if event not in ["impact","expire"]: return
	elif ("impact" if mode=="delayed_ignition" else mode)!=event: return
	if source.follow.is_empty(): return
	if mode=="dual_event":
		if not source.has("events"): source["events"]={}
		if source.events.has(event): return
		source.events[event]=true
	else:
		if source.triggered: return
		source.triggered=true
	track("triggers",source.get("meter_source",""))
	track("trigger_"+event,source.get("meter_source",""))
	var direction: Vector2=game.aim if source.get("returned",false) else source.get("original_dir",source.dir)
	var child: Dictionary=source.follow.duplicate(true)
	child["_orb"]=source.get("owner_orb",0)
	child["_linked"]=true
	child["_relic_scale"]=source.stage.get("_relic_scale",1.0)
	child["_relic_copy"]=source.stage.get("_relic_copy",false)
	child["_depth"]=int(source.stage.get("_depth",0))+1
	child["_connector_potency"]=1.0 if mode=="dual_event" else float(source.stage.get("connector_power",0.5))
	var child_budget: float=source.child_factor*(.5 if mode=="dual_event" else 1.0)
	child["_echo_copy"]=source.stage.get("_echo_copy",false)
	if mode=="delayed_ignition":
		support.schedule({"kind":"child","stage":child,"pos":at,"direction":direction,"factor":source.child_factor,"power":source.get("child_power",source.power),"echo":source.get("meter_echo",false),"lineage":source.get("cast_id",-1),"delay":.6,"generation":source.get("generation",generation),"source":{"meter_source":source.get("meter_source","")}})
		track("delayed_children_scheduled",source.get("meter_source",""))
	else:
		emit(child,at,direction,game.Spells.follow(child),child_budget,source.get("child_power",source.power),"chain",source.get("meter_echo",false),source.get("cast_id",-1),source.get("generation",generation),at)
	game.metrics.triggers+=1
	game.ring(at,25,Color("ff9cae"),0.2)

func moon_leg(p: Dictionary, endpoint: Vector2, target: Node2D = null) -> void:
	p["leg_start"] = p.pos
	p["leg_end"] = endpoint
	p["leg_control"] = (p.pos+endpoint)*0.5+p.pos.direction_to(endpoint).orthogonal()*minf(90,p.pos.distance_to(endpoint)*0.3)
	p["leg_age"] = 0.0
	p["leg_duration"] = maxf(0.12,p.pos.distance_to(endpoint)/p.speed)
	p.target = target

func turn_back(p: Dictionary) -> void:
	if p.returning: return
	p.returning = true
	p.leg_hits = 0
	p.target = null
	p.speed = 520.0*float(p.stage.get("_orb_speed",1.0))
	moon_leg(p,game.player.position)
	fusion.event(p,"return_start",p.pos)
	track("boomerang_returns",p.meter_source)

func moon_contact(p: Dictionary, at: Vector2) -> void:
	if p.returning: return
	if p.stage.get("chase_pierce",0)>0 and p.pierce>0:
		var choices: Array=support.targets(at,260,p.hit)
		if not choices.is_empty():
			p.pierce-=1
			moon_leg(p,choices[0].position,choices[0])
			track("chase_retargets",p.meter_source)
			return
	if p.stage.get("fusion","")=="petal_return": p.buds.append(at)
	if p.ricochets<=0:
		turn_back(p)
		return
	var next: Node2D = game.nearest_enemy(at,300,p.hit)
	if next==null:
		turn_back(p)
	else:
		p.ricochets -= 1
		moon_leg(p,next.position,next)
		track("boomerang_ricochets",p.meter_source)

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
	zone.merge({"kind":p.attack,"pos":p.pos,"dir":p.dir,"radius":game.Spells.attack_data(p.stage).radius*p.scale,
		"damage":p.damage*share*game.Spells.Effects.value(p.stage,"pierce"),"life":game.Spells.attack_data(p.stage).life*float(p.stage.get("_orb_life",1.0)),"age":0.0,"pulse":0.35 if vortex else 0.0,
		"meter_source":p.get("meter_source",""),"meter_echo":p.get("meter_echo",false),
		"follow":p.follow.duplicate(),"triggered":false,"child_factor":p.child_factor*share,"power":p.power},true)
	if zones.size()>=MAX_ZONES: evict_zone(zones[0])
	behavior.register_garden(zone)
	add_zone(zone)
	fusion.event(zone,"installed",zone.pos)
	if not installing_batch: behavior.refresh_gardens()

func update_projectiles(delta: float) -> void:
	installing_batch = true
	for index in range(game.projectiles.size()-1,-1,-1):
		var p: Dictionary = game.projectiles[index]
		p.life -= delta
		p.age += delta
		var seed: bool = p.attack in ["vortex","thorn"]
		var moon: bool = p.attack == "boomerang"
		if p.life <= 0:
			if seed: install(p)
			elif p.attack == "bloom": behavior.area(p,p.pos,p.damage,game.Spells.attack_data(p.stage).radius*p.scale)
			if not game.magic_active(): return
			if not seed:
				trigger(p,p.pos,"expire")
				if not game.magic_active(): return
				support.terminal(p,p.pos)
				if not game.magic_active(): return
			finish_projectile(p)
			game.projectiles.remove_at(index)
			continue
		var old: Vector2 = p.pos
		if moon:
			if not p.returning and (p.age>=p.outbound_limit or (p.target!=null and (not is_instance_valid(p.target) or p.target.dead))): turn_back(p)
			if p.returning and p.pos.distance_to(game.player.position)<=24:
				fusion.event(p,"on_return",game.player.position)
				if not game.magic_active(): return
				p["returned"] = true
				trigger(p,game.player.position,"expire")
				if not game.magic_active(): return
				support.terminal(p,game.player.position)
				if not game.magic_active(): return
				finish_projectile(p)
				game.projectiles.remove_at(index)
				continue
			p.leg_age += delta
			if p.returning: p.leg_end = game.player.position
			elif p.seek and is_instance_valid(p.target) and not p.target.dead:
				p.leg_end = p.leg_end.move_toward(p.target.position,120*game.Spells.seek_strength(p.stage)*delta)
			var t: float = minf(1,p.leg_age/p.leg_duration)
			var next: Vector2 = (1-t)*(1-t)*p.leg_start+2*(1-t)*t*p.leg_control+t*t*p.leg_end
			p.dir = p.pos.direction_to(next)
			p.pos = next
			if t>=1:
				if not p.returning: turn_back(p)
				else: moon_leg(p,game.player.position)
		else:
			if p.seek:
				p.seek_clock -= delta
				if p.seek_clock<=0:
					p.seek_clock = 0.15
					p.target = game.nearest_enemy(p.pos,260*game.Spells.Effects.profile(p.stage,"seek").range,p.hit)
					if p.stage.get("swarm_seek",0)>0:
						var choices: Array=support.targets(p.pos,320,p.hit)
						if not choices.is_empty(): p.target=choices[int(p.swarm_index)%choices.size()]
				if is_instance_valid(p.target) and not p.target.dead:
					var desired: Vector2 = p.pos.direction_to(p.target.position)
					p.dir = p.dir.rotated(clampf(p.dir.angle_to(desired),-delta*3.0*game.Spells.seek_strength(p.stage),delta*3.0*game.Spells.seek_strength(p.stage)))
			p.pos += p.dir*p.speed*delta
		var consumed := false
		if true:
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
					var contacts_before: int = p.leg_hits if moon else p.hit.size()-1
					var hit_damage: float = p.damage*(game.Spells.Effects.value(p.stage,"pierce") if contacts_before>0 else 1.0)
					if p.attack == "bloom": behavior.area(p,nearest,hit_damage,game.Spells.attack_data(p.stage).radius*p.scale)
					else: behavior.hit(enemy,hit_damage,p.dir,p)
					if not game.magic_active(): return
					fusion.event(p,"impact",nearest)
					if not game.magic_active(): return
					trigger(p,nearest)
					if not game.magic_active(): return
				elif p.seed_portion_count > 1:
					p.pos = nearest
					install(p,1)
					if p.seed_portions == 0:
						consumed = true
						break
				if moon:
					p.leg_hits += 1
					if not p.returning and is_instance_valid(p.target) and enemy!=p.target and p.pierce>0:
						p.pierce -= 1
						continue
					moon_contact(p,nearest)
					break
				else:
					p.pierce -= 1
					if p.pierce>=0: support.retarget(p)
					if p.pierce < 0:
						if seed:
							p.pos = nearest
							install(p)
						consumed = true
						break
		if consumed or (not moon and not game.projectile_bounds().has_point(p.pos)):
			if seed and consumed: install(p)
			if consumed and not seed:
				trigger(p,p.pos,"expire")
				if not game.magic_active(): return
				support.terminal(p,p.pos)
				if not game.magic_active(): return
			finish_projectile(p)
			game.projectiles.remove_at(index)

	installing_batch = false

# Dictionary Array.has/erase compares nested spell programs by value. IDs keep
# snapshot membership/removal independent of program size and lookalike fields.
func add_zone(zone: Dictionary) -> void:
	zone_serial += 1
	zone["_zone_uid"] = zone_serial
	live_zones[zone_serial] = true
	zones.append(zone)

func remove_zone(zone: Dictionary) -> void:
	live_zones.erase(zone._zone_uid)
	for i in zones.size():
		if zones[i]._zone_uid==zone._zone_uid:
			zones.remove_at(i)
			return

func evict_zone(zone: Dictionary) -> void:
	if zone.kind=="ember_path": behavior.end_path(zone,false)
	track("zones_evicted",zone.get("meter_source",""))
	remove_zone(zone)

func update_zones(delta: float) -> void:
	behavior.refresh_gardens()
	var pulls: Dictionary = {}
	var path_hits: Dictionary = {}
	var path_ended: Array = []
	# Iterate a snapshot: a finishing connector may append another field.
	for zone in zones.duplicate():
		if not live_zones.has(zone._zone_uid): continue
		zone.life -= delta
		zone.age += delta
		if zone.kind=="ember_path":
			# Collect strongest overlap in one pass, not an O(paths²) scan per victim.
			if zone.age>=0.3:
				for enemy in game.nearby(zone.pos,zone.radius+45+float(zone.get("span",0))):
					if enemy.dead or not behavior.path_contains(zone,enemy.position,enemy.radius): continue
					var key := str([enemy.get_instance_id(),zone.generation,zone.get("owner_orb",0)])
					if not path_hits.has(key) or path_hits[key].zone.damage<zone.damage: path_hits[key] = {"zone":zone,"enemy":enemy}
			if zone.life<=0:
				remove_zone(zone)
				path_ended.append(zone)
			continue
		var ending: bool = zone.life<=0
		var victims: Array = game.nearby(zone.pos,zone.radius+45).filter(func(e):return not e.dead and e.position.distance_to(zone.pos)<=zone.radius+e.radius)
		zone["contact_exclusions"] = {}
		for enemy in victims: zone.contact_exclusions[enemy.get_instance_id()] = true
		if zone.kind=="vortex":
			for enemy in victims:
				var offset: Vector2 = zone.pos-enemy.position
				if enemy.boss or offset.length()>zone.radius+enemy.radius or behavior.movement_factor(enemy)==0: continue
				var id: int = enemy.get_instance_id()
				if not pulls.has(id): pulls[id] = {"enemy":enemy,"velocity":Vector2.ZERO}
				pulls[id].velocity += offset.limit_length(100*delta)/maxf(delta,0.0001)
			zone.pulse -= delta
			if zone.pulse<=0:
				zone.pulse += 0.25
				var amount: float = zone.damage
				track("zone_pulses",zone.meter_source)
				for enemy in victims:
					if enemy.dead or enemy.position.distance_to(zone.pos)>zone.radius+enemy.radius: continue
					behavior.hit(enemy,amount,Vector2.ZERO,zone)
					if not game.magic_active(): return
					trigger(zone,enemy.position)
					if not game.magic_active(): return
		else:
			var activated := false
			if zone.age>=0.25 and not ending:
				for enemy in victims:
					if not enemy.dead and enemy.position.distance_to(zone.pos)<=zone.radius+enemy.radius: activated = true
			if activated:
				fusion.event(zone,"activated",zone.pos)
				track("trap_activations",zone.meter_source)
				var amount: float = zone.damage
				game.ring(zone.pos,zone.radius,Color("b8ed9a"),0.32)
				for enemy in victims:
					if enemy.dead or enemy.position.distance_to(zone.pos)>zone.radius+enemy.radius: continue
					behavior.hit(enemy,amount,Vector2.ZERO,zone,3.0 if zone.stage.get("fusion","")=="frost_blossom" else 0.0)
					if not game.magic_active(): return
					trigger(zone,enemy.position)
					if not game.magic_active(): return
				ending = true
		if ending:
			remove_zone(zone)
			fusion.event(zone,"expire",zone.pos)
			if not game.magic_active(): return
			trigger(zone,zone.pos,"expire")
			if not game.magic_active(): return
			support.terminal(zone,zone.pos)
			if not game.magic_active(): return
	for pair in path_hits.values():
		var zone: Dictionary = pair.zone
		var enemy: Node2D = pair.enemy
		var s: Dictionary = behavior.state_for(enemy)
		var key := "path_"+str(zone.generation)+"_"+str(zone.get("owner_orb",0))
		if behavior.clock-float(s.get(key,-100))<0.299: continue
		s[key] = behavior.clock
		if zone.stage.get("bounce",false) and not zone.group.get("chain_fired",false):
			zone["chain_exclusions"] = {}
			for other in zones:
				if other.kind!="ember_path" or other.group.path_id!=zone.group.path_id: continue
				for candidate in game.nearby(other.pos,other.radius+45+float(other.get("span",0))):
					if not candidate.dead and behavior.path_contains(other,candidate.position,candidate.radius): zone.chain_exclusions[candidate.get_instance_id()]=true
		behavior.hit(enemy,zone.damage,Vector2.ZERO,zone)
		if not game.magic_active(): return
		fusion.event(zone,"path_contact",enemy.position)
		if not game.magic_active(): return
		trigger(zone.group,enemy.position)
		if not game.magic_active(): return
		behavior.extra_links(zone.group,enemy.position,enemy)
	for zone in path_ended: behavior.end_path(zone,true)
	behavior.refresh_gardens()
	for pull in pulls.values():
		var enemy: Node2D = pull.enemy
		if is_instance_valid(enemy) and not enemy.dead:
			var before: Vector2 = enemy.position
			enemy.position += pull.velocity.limit_length(100)*delta*(.2 if enemy.role=="sentinel" else 1.0)
			var bounds: Rect2=game.enemy_bounds()
			enemy.position = enemy.position.clamp(bounds.position,bounds.end)
			track("pull_enemy_seconds","",delta)
			track("pull_distance","",before.distance_to(enemy.position))
