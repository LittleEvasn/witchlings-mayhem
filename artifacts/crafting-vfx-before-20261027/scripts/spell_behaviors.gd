extends RefCounted
## State effects and non-projectile attacks share the production runtime and cast lineage.
const DIRECT_DAMAGE := {"frost":10.0,"thunder":36.0,"satellite":18.0,"ember_path":5.5}
var runtime_ref: WeakRef
var runtime: RefCounted:
 get: return runtime_ref.get_ref()
var game: Node2D
var clock := 0.0
var cast_serial := 0
var garden_serial := 0
var path_serial := 0
var trail_emitters: Array = []
var strikes: Array = []
var orbits: Array = []
var statuses: Dictionary = {}
var path: Array = []
var last_path := Vector2.INF
var flashes: Array = []
func _init(owner_runtime: RefCounted) -> void:
 runtime_ref = weakref(owner_runtime)
 game = runtime.game
func clear() -> void:
 garden_serial = 0
 path_serial = 0
 trail_emitters.clear()
 strikes.clear()
 orbits.clear()
 statuses.clear()
 path.clear()
 flashes.clear()
 last_path = Vector2.INF
func context(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power: float, lane: String, echo: bool, lineage: int, generation: int) -> Dictionary:
 return {"hit_origin":"internal" if stage.get("_intrinsic",false) else "direct","owner_orb":stage.get("_orb",0),"tint":game.Spells.definition(stage.get("source_id",stage.attack)).color,"stage":stage.duplicate(),"attack":stage.attack,"pos":origin,"dir":direction,"original_dir":direction,"follow":follow.duplicate(),"triggered":false,"connector":stage.get("connector","impact"),"factor":factor,"power":power,"child_factor":factor*0.65,"cast_id":lineage,"generation":generation,"meter_source":runtime.source_for(stage,lane,echo),"meter_echo":echo,"lane":lane,"scale":game.Spells.scale(stage)}
func damage_scale(c: Dictionary) -> float:
 return float(c.factor)*float(c.power)*float(c.stage.get("rank_power",1.0))*game.Spells.Effects.value(c.stage,"charge")*float(c.get("potency",1.0))
func state_for(enemy: Node2D) -> Dictionary:
 var id: int = enemy.get_instance_id()
 if not statuses.has(id): statuses[id] = {"enemy":enemy,"cold":0.0,"cold_weighted":0.0,"cold_sources":{},"shell_sources":{},"shell_power":1.0,"cold_until":0.0,"frozen_until":0.0,"immune_until":0.0,"marks":[],"mark_mass":0.0,"mark_until":0.0,"casts":{}}
 return statuses[id]
func movement_factor(enemy: Node2D) -> float:
 var s: Dictionary = statuses.get(enemy.get_instance_id(),{})
 if s.is_empty(): return 1.0
 if not enemy.boss and s.frozen_until>clock: return 0.0
 return 0.8 if s.cold>=1 else 1.0
func update(delta: float) -> void:
 clock += delta
 for id in statuses.keys():
  var s: Dictionary = statuses[id]
  if not is_instance_valid(s.enemy) or s.enemy.dead:
   statuses.erase(id)
   continue
  if s.frozen_until>0 and s.frozen_until<=clock:
   s.frozen_until = 0.0
   s.immune_until = clock+1.5
   s.cold = 0.0
   s.cold_weighted = 0.0
   s.cold_sources.clear()
  if s.cold_until<=clock:
   s.cold = 0.0
   s.cold_weighted = 0.0
   s.cold_sources.clear()
  if s.mark_until<=clock and s.mark_mass>0:
   runtime.track("marks_expired","",s.mark_mass)
   s.marks.clear()
   s.mark_mass = 0.0
  for cast_id in s.casts.keys():
   if clock-s.casts[cast_id].last>24: s.casts.erase(cast_id)
  for key in s.keys():
   if (str(key).begins_with("path_") or str(key).begins_with("push_")) and clock-float(s[key])>24: s.erase(key)
  if s.frozen_until>clock: runtime.track("frozen_enemy_seconds","",delta)
 if last_path == Vector2.INF or last_path.distance_to(game.player.position)>150:
  path.clear()
  last_path = game.player.position
 if last_path.distance_to(game.player.position)>=24:
  var destination: Vector2 = game.player.position
  var distance := last_path.distance_to(destination)
  var steps := maxi(1,ceili(distance/24.0))
  for n in steps: path.append({"pos":last_path.lerp(destination,float(n+1)/steps),"time":clock})
  last_path = destination
 while not path.is_empty() and (clock-path[0].time>1.2 or path.size()>32): path.pop_front()
 for i in range(flashes.size()-1,-1,-1):
  flashes[i].life -= delta
  if flashes[i].life<=0: flashes.remove_at(i)
 update_strikes(delta)
 if game.magic_active(): update_orbits(delta)
 if game.magic_active(): update_trails(delta)
func hit(enemy: Node2D, amount: float, direction: Vector2, c: Dictionary, cold := 0.0) -> void:
 if not is_instance_valid(enemy) or enemy.dead: return
 var s := state_for(enemy)
 var frozen: bool = s.frozen_until>clock
 var at: Vector2 = enemy.position
 game.damage_enemy(enemy,amount,direction,c.get("meter_source",""))
 if not game.magic_active(): return
 # The shell belongs to the cold source, never to the finishing spell's modifiers.
 if frozen and cold<=0 and (c.get("hit_origin","direct")=="direct" or c.get("finish_cold",false)):
  s.frozen_until = 0.0
  s.immune_until = clock+1.5
  s.cold = 0.0
  s.cold_weighted = 0.0
  s.cold_sources.clear()
  var extra: float = 20.0*s.shell_power
  var source: String = c.meter_source+"/shatter"
  var shares: Dictionary = s.shell_sources if c.stage.get("_relic_copy",false) or s.shell_sources.keys().any(func(label):return "/relic_copy" in label) else {}
  if enemy.dead:
   if shares.is_empty():
    runtime.track("damage_raw",source,extra)
    runtime.track("damage_overkill",source,extra)
   else:
    for label in shares:
     runtime.track("damage_raw",label,shares[label])
     runtime.track("damage_overkill",label,shares[label])
  else: game.damage_enemy(enemy,extra,direction,source,shares)
  runtime.track("shatters",source)
  game.burst(at,Color("b8eaff"),8)
 if cold>0 and not enemy.dead:
  if s.cold_until<=clock:
   s.cold = 0.0
   s.cold_weighted = 0.0
   s.cold_sources.clear()
  s.cold_until = clock+3
  if s.frozen_until<=clock:
   var accepted := minf(cold,maxf(0,(2.0 if s.immune_until>clock else 3.0)-s.cold))
   s.cold += accepted
   s.cold_weighted += accepted*c.power*float(c.stage.get("rank_power",1.0))
   var cold_source: String = c.meter_source+"/shatter"
   s.cold_sources[cold_source] = float(s.cold_sources.get(cold_source,0))+accepted*c.power*float(c.stage.get("rank_power",1.0))
   runtime.track("cold_added",c.meter_source,accepted)
   if s.cold>=3:
    s.shell_power = s.cold_weighted/3.0
    s.shell_sources = {}
    for label in s.cold_sources: s.shell_sources[label] = 20.0*s.cold_sources[label]/3.0
    s.frozen_until = clock+(.6 if enemy.role=="sentinel" else 1.2)
    runtime.track("freezes",c.meter_source)
 if c.get("hit_origin","direct")=="direct":
  var force: float = game.Spells.Effects.profile(c.stage,"charge").knockback
  var force_key := "push_"+str(c.generation)+"_"+str(c.cast_id)
  if force>0 and not s.has(force_key):
   s[force_key] = clock
   var resistance := 0.0 if enemy.boss else (0.2 if enemy.role=="sentinel" else 1.0)
   var push: Vector2 = direction.normalized() if direction.length_squared()>0 else game.player.position.direction_to(enemy.position)
   var bounds: Rect2 = game.enemy_bounds()
   enemy.position = (enemy.position+push*force*resistance).clamp(bounds.position,bounds.end)
  chain(c,at,enemy,amount,cold)

func chain(c: Dictionary, at: Vector2, victim: Node2D, amount: float, cold: float) -> void:
 var owner: Dictionary = c.get("group",c)
 if owner.get("chain_fired",false) or not c.stage.get("bounce",false): return
 owner["chain_fired"] = true
 var seen: Dictionary = c.get("chain_exclusions",c.get("contact_exclusions",{})).duplicate()
 seen[victim.get_instance_id()] = true
 var origin := at
 for hop in int(game.Spells.Effects.profile(c.stage,"bounce").targets):
  var target: Node2D = game.nearest_enemy(origin,game.Spells.Effects.profile(c.stage,"bounce").distance,seen)
  if target==null: break
  seen[target.get_instance_id()] = true
  var share := pow(game.Spells.Effects.value(c.stage,"bounce"),hop+1)
  var arc := c.duplicate()
  arc["hit_origin"] = "chain"
  arc["meter_source"] = c.meter_source+"/chain"
  arc.factor = c.factor*share
  hit(target,amount*share,Vector2.ZERO,arc,cold*share)
  flash({"kind":"arc","pos":origin,"to":target.position,"life":0.18})
  runtime.track("chain_hits",c.meter_source)
  if not game.magic_active(): return
  origin = target.position
func area(c: Dictionary, at: Vector2, damage: float, radius: float) -> int:
 var victims: Array = game.nearby(at,radius+45).filter(func(e):return not e.dead and e.position.distance_to(at)<=radius+e.radius)
 c["contact_exclusions"] = {}
 for enemy in victims: c.contact_exclusions[enemy.get_instance_id()] = true
 var count := 0
 runtime.track("explosions",c.meter_source)
 game.ring(at,radius,game.Spells.PARTS[c.attack].color,0.3)
 for enemy in victims:
  hit(enemy,damage,at.direction_to(enemy.position),c)
  count += 1
  runtime.track("explosion_victims",c.meter_source)
  if not game.magic_active(): break
 return count
func special(c: Dictionary) -> void:
 var stage: Dictionary = c.stage
 match c.attack:
  "frost":
   if stage.seek:
    var target: Node2D = game.nearest_enemy(c.pos,220*c.scale/float(stage.get("_relic_scale",1.0))*game.Spells.Effects.profile(stage,"seek").range)
    if target!=null: c.dir = c.dir.rotated(clampf(c.dir.angle_to(c.pos.direction_to(target.position)),-0.25*game.Spells.seek_strength(stage),0.25*game.Spells.seek_strength(stage)))
   var length: float = 170*c.scale/float(stage.get("_relic_scale",1.0))
   var half_angle: float = deg_to_rad(float(game.Spells.attack_data(stage).spread))*0.5*float(stage.get("_relic_scale",1.0))
   var victims: Array = game.nearby(c.pos,length+45)
   victims.sort_custom(func(a,b):return c.pos.distance_squared_to(a.position)<c.pos.distance_squared_to(b.position))
   var contacts: Array = []
   for enemy in victims:
    if enemy.dead or c.pos.distance_to(enemy.position)>length+enemy.radius: continue
    var offset: Vector2 = enemy.position-c.pos
    var inside := false
    for i in game.Spells.branches(stage):
     var angle: float = (i-(game.Spells.branches(stage)-1)*0.5)*0.48
     if absf(c.dir.rotated(angle).angle_to(offset))<=half_angle: inside = true
    if not inside: continue
    contacts.append(enemy)
    if contacts.size()>=(int(game.Spells.attack_data(stage).targets)+int(game.Spells.Effects.profile(stage,"pierce").targets)): break
   c["contact_exclusions"] = {}
   for enemy in contacts: c.contact_exclusions[enemy.get_instance_id()] = true
   for index in contacts.size():
    var enemy: Node2D = contacts[index]
    var amount: float = 10*damage_scale(c)*(game.Spells.Effects.value(stage,"pierce") if index>=int(game.Spells.attack_data(stage).targets) else 1.0)
    hit(enemy,amount,c.dir,c,c.factor)
    if not game.magic_active(): return
    runtime.trigger(c,enemy.position)
   flash({"kind":"cone","pos":c.pos,"dir":c.dir,"radius":length,"fan":stage.fan,"branches":game.Spells.branches(stage),"half_angle":half_angle,"life":0.22})
   runtime.trigger(c,c.pos+c.dir*length,"expire")
  "thunder":
   if strikes.size()>=32:
    runtime.track("strikes_blocked",c.meter_source)
    return
   # Root lightning rains around the player; connectors/fusion keep their event location.
   var local_event: bool=c.stage.get("_linked",false) or c.stage.get("_intrinsic",false)
   var center: Vector2=c.pos
   if not local_event:
    var offset := Vector2.RIGHT.rotated(game.rng.randf()*TAU)*sqrt(game.rng.randf_range(90.0*90.0,360.0*360.0))
    center=(game.player.position+offset).clamp(game.projectile_bounds().position+Vector2(100,100),game.projectile_bounds().end-Vector2(100,100))
   var points: Array = []
   for i in game.Spells.branches(stage):
    var point: Vector2 = center+c.dir.orthogonal()*((i-(game.Spells.branches(stage)-1)*0.5)*70)
    points.append({"pos":point,"target":game.nearest_enemy(point,160*game.Spells.Effects.profile(stage,"seek").range) if stage.seek else null})
   c["points"] = points
   c["center"] = center
   c["life"] = 0.45
   c["pulses_left"] = game.Spells.attack_data(stage).pulses
   c["strike_radius"] = game.Spells.attack_data(stage).radius*c.scale
   strikes.append(c)
   runtime.track("strikes_scheduled",c.meter_source)
  "satellite":
   var active := 0
   for orbit in orbits:
    if orbit.stage.get("slot",-1)==c.stage.get("slot",-1) and orbit.owner_orb==c.owner_orb and orbit.get("meter_echo",false)==c.get("meter_echo",false) and orbit.stage.get("_relic_copy",false)==c.stage.get("_relic_copy",false): active += 1
   # Four echoes plus the original must coexist for a complete upgraded cast.
   # Retain a bounded per-program lifetime budget, with every rejection metered.
   if active>=32 or orbits.size()>=128:
    runtime.track("orbits_blocked",c.meter_source)
    return
   c["life"] = float(stage.get("_orbit_life",1.8))
   c["age"] = 0.0
   c["hits"] = {}
   c["bodies"] = []
   c["body_count"] = int(game.Spells.attack_data(stage).bodies)+int(game.Spells.Effects.profile(stage,"fan").extra)
   c["orbit_radius"] = float(stage.get("_orbit_radius",95.0))
   c["orbit_offset"] = 0.0
   orbits.append(c)
   runtime.track("orbits_created",c.meter_source)
  "ember_path": emit_path(c)
func flash(data: Dictionary) -> void:
 if flashes.size()<64: flashes.append(data)
func update_strikes(delta: float) -> void:
 for i in range(strikes.size()-1,-1,-1):
  var c: Dictionary = strikes[i]
  c.life -= delta
  if c.life>0.15 and not c.get("strike_locked",false):
   for point in c.points:
    if is_instance_valid(point.target) and not point.target.dead: point.pos = point.pos.move_toward(point.target.position,120*game.Spells.seek_strength(c.stage)*delta)
  if c.life>0: continue
  c["strike_locked"] = true
  c.pulses_left -= 1
  if c.pulses_left>0: c.life = 0.22
  else: strikes.remove_at(i)
  runtime.track("lightning_pulses",c.meter_source)
  var hit_ids := {}
  for point in c.points:
   for enemy in game.nearby(point.pos,c.strike_radius+45):
    if not enemy.dead and enemy.position.distance_to(point.pos)<=c.strike_radius+enemy.radius: hit_ids[enemy.get_instance_id()]=true
  c["chain_exclusions"] = hit_ids
  for point in c.points:
   var contacts := area(c,point.pos,36*damage_scale(c),c.strike_radius)
   if contacts>0:
    runtime.trigger(c,point.pos)
    extra_links(c,point.pos,null,true,false,c.strike_radius)
   if not game.magic_active(): return
   for enemy in game.nearby(point.pos,c.strike_radius+45):
    if enemy.position.distance_to(point.pos)<=c.strike_radius+enemy.radius:
     hit_ids[enemy.get_instance_id()] = true
     runtime.trigger(c,point.pos)
   flash({"kind":"lightning","pos":point.pos,"life":0.2})
  if c.pulses_left==0: runtime.trigger(c,c.center,"expire")
func update_orbits(delta: float) -> void:
 for i in range(orbits.size()-1,-1,-1):
  var c: Dictionary = orbits[i]
  c.life -= delta
  c.age += delta
  if c.stage.has("_anchor_zone") and not runtime.live_zones.has(c.stage._anchor_zone): c.life = 0.0
  if c.life<=0:
   orbits.remove_at(i)
   runtime.trigger(c,c.bodies.back() if not c.bodies.is_empty() else c.pos,"expire")
   continue
  if c.stage.get("_follow_player",false) or not c.stage.get("_linked",false): c.pos = game.player.position
  c.bodies.clear()
  if c.stage.seek:
   var target: Node2D = game.nearest_enemy(c.pos,170*game.Spells.Effects.profile(c.stage,"seek").range)
   if target!=null:
    c.orbit_offset = rotate_toward(c.orbit_offset,c.pos.angle_to_point(target.position)-c.age*TAU,delta*1.5*game.Spells.seek_strength(c.stage))
    c.orbit_radius = move_toward(c.orbit_radius,clampf(c.pos.distance_to(target.position),55,150),delta*45*game.Spells.seek_strength(c.stage))
  for n in int(c.body_count):
   var angle: float = c.age*TAU+n*TAU/c.body_count+c.orbit_offset
   var point: Vector2 = c.pos+Vector2.RIGHT.rotated(angle)*c.orbit_radius
   c.bodies.append(point)
  c["contact_exclusions"] = {}
  for point in c.bodies:
   for enemy in game.nearby(point,12*c.scale+45):
    if not enemy.dead and enemy.position.distance_to(point)<=12*c.scale+enemy.radius: c.contact_exclusions[enemy.get_instance_id()] = true
  for point in c.bodies:
   for enemy in game.nearby(point,12*c.scale+45):
    if enemy.dead or enemy.position.distance_to(point)>12*c.scale+enemy.radius: continue
    var id: int = enemy.get_instance_id()
    if clock-float(c.hits.get(id,-100))<0.45: continue
    c.hits[id] = clock
    hit(enemy,DIRECT_DAMAGE.satellite*damage_scale(c),Vector2.ZERO,c)
    if not game.magic_active(): return
    extra_links(c,enemy.position,enemy)
    runtime.track("orbit_contacts",c.meter_source)
    runtime.trigger(c,enemy.position)
  for id in c.hits.keys():
   if clock-c.hits[id]>1: c.hits.erase(id)
func path_contains(zone: Dictionary, point: Vector2, extra: float = 0.0) -> bool:
 var points: Array = zone.get("path_points",[zone.pos])
 for i in points.size():
  var closest: Vector2 = points[i] if i==0 else Geometry2D.get_closest_point_to_segment(point,points[i-1],points[i])
  if closest.distance_squared_to(point)<=pow(zone.radius+extra,2): return true
 return false

func emit_path(c: Dictionary) -> void:
 path_serial += 1
 c["path_id"] = path_serial
 c["remaining"] = 0
 c["cancelled"] = false
 c["emitting"] = false
 c["last_pos"] = c.pos
 if not c.stage.get("_linked",false):
  if trail_emitters.size()>=128:
   runtime.track("trail_emitters_blocked",c.meter_source)
   c.cancelled = true
   return
  # This cast lays fresh round footprints while moving, never redraws old history.
  c["emitting"] = true
  c["emit_left"] = 1.0
  c.last_pos = game.player.position+Vector2(0,16)
  trail_emitters.append(c)
  var nearby_patch := false
  for z in runtime.zones:
   if z.kind=="ember_path" and z.owner_orb==c.owner_orb and z.stage.slot==c.stage.slot and z.pos.distance_to(c.last_pos)<z.radius:
    nearby_patch = true
    break
  if not nearby_patch: stamp_path(c,c.last_pos,c.dir)
 else:
  var spacing: float = game.Spells.attack_data(c.stage).radius*c.scale*2.2
  for i in 3: stamp_path(c,c.pos+c.dir*(i-1)*spacing,c.dir)

func update_trails(delta: float) -> void:
 for index in range(trail_emitters.size()-1,-1,-1):
  var c: Dictionary = trail_emitters[index]
  c.emit_left -= delta
  var feet: Vector2 = game.player.position+Vector2(0,16)
  var distance: float = c.last_pos.distance_to(feet)
  var step: float = game.Spells.attack_data(c.stage).radius*c.scale*2.2
  if distance>200:
   c.last_pos = feet # A teleport must not paint an entire corridor.
  elif distance>=step:
   var tangent: Vector2 = c.last_pos.direction_to(feet)
   while c.last_pos.distance_to(feet)>=step:
    c.last_pos += tangent*step
    stamp_path(c,c.last_pos,tangent)
  if c.emit_left<=0:
   c.emitting = false
   trail_emitters.remove_at(index)
   if c.remaining==0 and not c.cancelled: runtime.trigger(c,c.last_pos,"expire")

func stamp_path(c: Dictionary, at: Vector2, tangent: Vector2) -> void:
 var tracks: int = game.Spells.branches(c.stage)
 var data: Dictionary = game.Spells.attack_data(c.stage)
 for n in tracks:
  if runtime.zones.size()>=runtime.MAX_ZONES:
   runtime.track("paths_blocked",c.meter_source)
   c.cancelled = true
   continue
  var point: Vector2 = at+tangent.orthogonal()*(n-(tracks-1)*0.5)*data.radius*c.scale*2.2
  var zone := c.duplicate()
  zone.merge({"kind":"ember_path","pos":point,"path_points":[point],"span":0.0,"radius":data.radius*c.scale,"damage":DIRECT_DAMAGE.ember_path*damage_scale(c),"life":data.life,"age":0.0,"pulse":0.3,"group":c},true)
  c.remaining += 1
  runtime.add_zone(zone)
  runtime.track("path_patches",c.meter_source)

func end_path(zone: Dictionary, normal: bool) -> void:
 var group: Dictionary = zone.group
 group.remaining -= 1
 if not normal: group.cancelled = true
 if group.remaining==0 and not group.get("emitting",false) and not group.cancelled: runtime.trigger(group,group.last_pos,"expire")
func register_garden(zone: Dictionary) -> void:
 var key := str([zone.generation,zone.owner_orb,zone.stage.get("slot",-1),zone.stage.get("source_id",zone.attack),zone.stage.get("modifiers",[])])
 zone["garden_key"] = key
 zone["base_radius"] = zone.radius
 zone["garden_anchor"] = zone.pos
 zone["garden_id"] = -1
 var group_sizes := {}
 for existing in runtime.zones:
  var group_id: int = existing.get("garden_id",-1)
  group_sizes[group_id] = int(group_sizes.get(group_id,0))+1
 for other in runtime.zones:
  if other.get("garden_key","")!=key or other.pos.distance_to(zone.pos)>48: continue
  if group_sizes.get(other.garden_id,0)>=12 or other.get("garden_mass",1.0)>=3: continue
  zone.garden_id = other.garden_id
  zone.garden_anchor = other.garden_anchor
  zone.pos = other.garden_anchor
  runtime.track("garden_merges",zone.meter_source)
  break
 if zone.garden_id<0:
  garden_serial += 1
  zone.garden_id = garden_serial

func refresh_gardens() -> void:
 var groups := {}
 for zone in runtime.zones:
  if not zone.has("garden_id"): continue
  if not groups.has(zone.garden_id): groups[zone.garden_id] = []
  groups[zone.garden_id].append(zone)
 for members in groups.values():
  var casts := {}
  for zone in members:
   casts[zone.cast_id] = minf(1,float(casts.get(zone.cast_id,0))+maxf(0,zone.factor))
  var mass := 0.0
  for value in casts.values(): mass += value
  mass = minf(3,mass)
  var growth := 1.0+0.1*maxf(0,mass-1)
  var was_full: bool = members.any(func(z):return z.get("garden_mass",0)>=3)
  var life := 0.0
  for zone in members: life = maxf(life,zone.life)
  if mass>=3 and not was_full: runtime.track("garden_full",members[0].meter_source)
  for i in members.size():
   var zone: Dictionary = members[i]
   zone["garden_life"] = life
   zone["garden_mass"] = mass
   zone["garden_leader"] = i==0
   zone["tier"] = clampi(int(floor(mass+0.0001)),1,3)
   zone.radius = zone.base_radius*growth
func extra_links(c: Dictionary, at: Vector2, victim: Node2D, pierce := true, _bounce := true, skip_radius := 0.0) -> void:
 # Existing directional extension is preserved for the later modifier balance pass.
 for mode in ["pierce"]:
  if not c.stage.get(mode,false) or (mode=="pierce" and not pierce) or c.get("linked_"+mode,false): continue
  c["linked_"+mode] = true
  var seen := {}
  if victim!=null: seen[victim.get_instance_id()]=true
  var origin := at
  for n in int(game.Spells.Effects.profile(c.stage,mode).targets):
   var candidates: Array = game.nearby(origin,240)
   candidates.sort_custom(func(a,b):return a.position.distance_squared_to(origin)<b.position.distance_squared_to(origin))
   var target: Node2D = null
   for enemy in candidates:
    if enemy.dead or seen.has(enemy.get_instance_id()): continue
    var offset: Vector2 = enemy.position-origin
    if n==0 and mode=="pierce" and offset.length()<=skip_radius+enemy.radius: continue
    if mode=="pierce" and (offset.dot(c.dir)<12 or absf(offset.cross(c.dir))>35): continue
    target = enemy
    break
   if target==null: break
   seen[target.get_instance_id()] = true
   var arc := c.duplicate()
   arc.factor *= 0.5*game.Spells.Effects.value(c.stage,"pierce")
   arc["hit_origin"] = "extension"
   var base: float = DIRECT_DAMAGE.get(c.attack,10.0)
   hit(target,base*damage_scale(arc),c.dir,arc,c.factor*0.5 if c.attack=="frost" else 0.0)
   flash({"kind":"arc","pos":origin,"to":target.position,"life":0.18})
   runtime.track("special_"+mode,c.meter_source)
   if not game.magic_active(): return
   origin = target.position
