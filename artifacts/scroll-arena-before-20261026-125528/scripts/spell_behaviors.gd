extends RefCounted
## State effects and non-projectile attacks share the production runtime and cast lineage.
const SIGIL_BURST_DAMAGE := 42.0
const DIRECT_DAMAGE := {"frost":10.0,"thunder":36.0,"satellite":18.0,"ember_path":5.5}
var runtime_ref: WeakRef
var runtime: RefCounted:
 get: return runtime_ref.get_ref()
var game: Node2D
var clock := 0.0
var cast_serial := 0
var garden_serial := 0
var path_serial := 0
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
 strikes.clear()
 orbits.clear()
 statuses.clear()
 path.clear()
 flashes.clear()
 last_path = Vector2.INF
func context(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power: float, lane: String, echo: bool, lineage: int, generation: int) -> Dictionary:
 return {"hit_origin":"internal" if stage.get("_intrinsic",false) else "direct","owner_orb":stage.get("_orb",0),"tint":game.Spells.definition(stage.get("source_id",stage.attack)).color,"stage":stage.duplicate(),"attack":stage.attack,"pos":origin,"dir":direction,"original_dir":direction,"follow":follow.duplicate(),"triggered":false,"connector":stage.get("connector","impact"),"factor":factor,"power":power,"child_factor":factor*0.65,"cast_id":lineage,"generation":generation,"meter_source":runtime.source_for(stage,lane,echo),"meter_echo":echo,"lane":lane,"scale":game.Spells.scale(stage)}
func damage_scale(c: Dictionary) -> float:
 return float(c.factor)*float(c.power)*float(c.stage.get("rank_power",1.0))*game.Spells.Effects.value(c.stage,"charge")*pow(0.85,game.Spells.copies(c.stage,"sigil"))
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
   if str(key).begins_with("path_") and clock-float(s[key])>1: s.erase(key)
  if s.frozen_until>clock: runtime.track("frozen_enemy_seconds","",delta)
 if last_path == Vector2.INF or last_path.distance_to(game.player.position)>150:
  path.clear()
  last_path = game.player.position
 if last_path.distance_to(game.player.position)>=24:
  path.append({"pos":game.player.position,"time":clock})
  last_path = game.player.position
 while not path.is_empty() and (clock-path[0].time>0.8 or path.size()>32): path.pop_front()
 for i in range(flashes.size()-1,-1,-1):
  flashes[i].life -= delta
  if flashes[i].life<=0: flashes.remove_at(i)
 update_strikes(delta)
 if game.magic_active(): update_orbits(delta)
func hit(enemy: Node2D, amount: float, direction: Vector2, c: Dictionary, cold := 0.0) -> void:
 if not is_instance_valid(enemy) or enemy.dead: return
 var s := state_for(enemy)
 var frozen: bool = s.frozen_until>clock
 var at: Vector2 = enemy.position
 game.damage_enemy(enemy,amount,direction,c.get("meter_source",""))
 if not game.magic_active(): return
 # The shell belongs to the cold source, never to the finishing spell's modifiers.
 if frozen and cold<=0 and c.get("hit_origin","direct")=="direct":
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
    s.frozen_until = clock+1.2
    runtime.track("freezes",c.meter_source)
 if c.stage.get("sigil",false): add_marks(s,c,at)
 if c.get("hit_origin","direct")=="direct": chain(c,at,enemy,amount,cold)

func chain(c: Dictionary, at: Vector2, victim: Node2D, amount: float, cold: float) -> void:
 var owner: Dictionary = c.get("group",c)
 if owner.get("chain_fired",false) or not c.stage.get("bounce",false): return
 owner["chain_fired"] = true
 var seen: Dictionary = c.get("chain_exclusions",c.get("contact_exclusions",{})).duplicate()
 seen[victim.get_instance_id()] = true
 var origin := at
 for hop in 2*game.Spells.copies(c.stage,"bounce"):
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
func add_marks(s: Dictionary, c: Dictionary, at: Vector2) -> void:
 var id: int = c.cast_id
 var record: Dictionary = s.casts.get(id,{"mass":0.0,"last":-100.0,"limit":0.0})
 var stacks: float = game.Spells.Effects.value(c.stage,"sigil")
 record.limit = maxf(float(record.get("limit",0)),2.0*stacks)
 s.casts[id] = record
 if clock-record.last<0.25: return
 var amount := minf(float(c.factor)*stacks,record.limit-float(record.mass))
 if amount<=0: return
 record.mass += amount
 record.last = clock
 s.casts[id] = record
 s.mark_mass += amount
 s.mark_until = clock+3
 s.marks.append({"mass":amount,"power":c.power,"scale":c.stage.get("_relic_scale",1.0),"source":c.meter_source})
 runtime.track("marks_added",c.meter_source,amount)
 while s.mark_mass+0.00001>=6:
  var needed := 6.0
  var weighted := 0.0
  var weighted_scale := 0.0
  var contributions := {}
  while needed>0.00001 and not s.marks.is_empty():
   var m: Dictionary = s.marks[0]
   var take := minf(needed,m.mass)
   weighted += take*m.power
   weighted_scale += take*float(m.get("scale",1.0))
   var label: String = str(m.get("source",c.meter_source))+"/sigil"
   contributions[label] = float(contributions.get(label,0))+take*m.power
   m.mass -= take
   needed -= take
   if m.mass<=0.00001: s.marks.pop_front()
  s.mark_mass = maxf(0,s.mark_mass-6)
  runtime.track("sigil_bursts",c.meter_source+"/sigil")
  var radius := 48*weighted_scale/6
  game.ring(at,radius,Color("ff9cae"),0.4)
  # Keep one physical explosion, while exposing copied marks' actual damage share.
  var shares := {}
  if contributions.keys().any(func(label):return "/relic_copy" in label):
   for label in contributions: shares[label] = SIGIL_BURST_DAMAGE*contributions[label]/6
  game.explode(at,SIGIL_BURST_DAMAGE*weighted/6,radius,c.meter_source+"/sigil",shares)
  if not game.magic_active(): return
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
    var target: Node2D = game.nearest_enemy(c.pos,220*c.scale/float(stage.get("_relic_scale",1.0))*game.Spells.seek_strength(stage))
    if target!=null: c.dir = c.pos.direction_to(target.position)
   var length: float = 170*c.scale/float(stage.get("_relic_scale",1.0))
   var half_angle: float = PI/6*float(stage.get("_relic_scale",1.0))
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
    if contacts.size()>=(4+2*game.Spells.copies(stage,"pierce")): break
   c["contact_exclusions"] = {}
   for enemy in contacts: c.contact_exclusions[enemy.get_instance_id()] = true
   for index in contacts.size():
    var enemy: Node2D = contacts[index]
    var amount: float = 10*damage_scale(c)*(game.Spells.Effects.value(stage,"pierce") if index>=4 else 1.0)
    hit(enemy,amount,c.dir,c,c.factor)
    if not game.magic_active(): return
    runtime.trigger(c,enemy.position)
   flash({"kind":"cone","pos":c.pos,"dir":c.dir,"radius":length,"fan":stage.fan,"branches":game.Spells.branches(stage),"half_angle":half_angle,"life":0.22})
   runtime.trigger(c,c.pos+c.dir*length,"expire")
  "thunder":
   if strikes.size()>=32:
    runtime.track("strikes_blocked",c.meter_source)
    return
   var center: Vector2 = game.cast_target if not c.stage.get("_linked",false) else c.pos
   if c.has("target_point") and not c.stage.get("_linked",false): center = c.target_point
   center = c.pos+(center-c.pos).limit_length(480) if not c.stage.get("_linked",false) else center
   var points: Array = []
   for i in game.Spells.branches(stage):
    var point: Vector2 = center+c.dir.orthogonal()*((i-(game.Spells.branches(stage)-1)*0.5)*70)
    points.append({"pos":point,"target":game.nearest_enemy(point,160*game.Spells.seek_strength(stage)) if stage.seek else null})
   c["points"] = points
   c["center"] = center
   c["life"] = 0.45
   strikes.append(c)
   runtime.track("strikes_scheduled",c.meter_source)
  "satellite":
   var active := 0
   for orbit in orbits:
    if orbit.stage.get("slot",-1)==c.stage.get("slot",-1) and orbit.owner_orb==c.owner_orb and orbit.get("meter_echo",false)==c.get("meter_echo",false) and orbit.stage.get("_relic_copy",false)==c.stage.get("_relic_copy",false): active += 1
   if active>=2:
    runtime.track("orbits_blocked",c.meter_source)
    return
   c["life"] = 1.8
   c["age"] = 0.0
   c["hits"] = {}
   c["bodies"] = []
   orbits.append(c)
   runtime.track("orbits_created",c.meter_source)
  "ember_path": emit_path(c)
func flash(data: Dictionary) -> void:
 if flashes.size()<64: flashes.append(data)
func update_strikes(delta: float) -> void:
 for i in range(strikes.size()-1,-1,-1):
  var c: Dictionary = strikes[i]
  c.life -= delta
  if c.life>0.15:
   for point in c.points:
    if is_instance_valid(point.target) and not point.target.dead: point.pos = point.target.position
  if c.life>0: continue
  strikes.remove_at(i)
  var hit_ids := {}
  for point in c.points:
   for enemy in game.nearby(point.pos,45*c.scale+45):
    if not enemy.dead and enemy.position.distance_to(point.pos)<=45*c.scale+enemy.radius: hit_ids[enemy.get_instance_id()]=true
  c["chain_exclusions"] = hit_ids
  for point in c.points:
   var contacts := area(c,point.pos,36*damage_scale(c),45*c.scale)
   if contacts>0:
    runtime.trigger(c,point.pos)
    extra_links(c,point.pos,null,true,false,45*c.scale)
   if not game.magic_active(): return
   for enemy in game.nearby(point.pos,45*c.scale+45):
    if enemy.position.distance_to(point.pos)<=45*c.scale+enemy.radius:
     hit_ids[enemy.get_instance_id()] = true
     runtime.trigger(c,point.pos)
   flash({"kind":"lightning","pos":point.pos,"life":0.2})
  runtime.trigger(c,c.center,"expire")
func update_orbits(delta: float) -> void:
 for i in range(orbits.size()-1,-1,-1):
  var c: Dictionary = orbits[i]
  c.life -= delta
  c.age += delta
  if c.life<=0:
   orbits.remove_at(i)
   runtime.trigger(c,c.bodies.back() if not c.bodies.is_empty() else c.pos,"expire")
   continue
  if not c.stage.get("_linked",false): c.pos = game.player.position
  c.bodies.clear()
  for n in game.Spells.branches(c.stage):
   var angle: float = c.age*TAU+n*TAU/game.Spells.branches(c.stage)
   var radius := 95.0
   if c.stage.seek:
    var target: Node2D = game.nearest_enemy(c.pos,170*game.Spells.seek_strength(c.stage))
    if target!=null:
     angle = lerp_angle(angle,c.pos.angle_to_point(target.position),minf(1,0.65*game.Spells.seek_strength(c.stage)))
     radius = clampf(c.pos.distance_to(target.position),55,150)
   var point: Vector2 = c.pos+Vector2.RIGHT.rotated(angle)*radius
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
func emit_path(c: Dictionary) -> void:
 path_serial += 1
 c["path_id"] = path_serial
 var points: Array = []
 if not c.stage.get("_linked",false):
  for item in path:
   if clock-item.time<=0.8: points.append(item.pos)
  if points.size()>4: points = points.slice(points.size()-4)
  if points.is_empty(): points = [game.player.position]
 else:
  for i in 4: points.append(c.pos-c.dir*(72-i*24))
 c["remaining"] = points.size()
 c["cancelled"] = false
 c["last_pos"] = points.back()
 for i in points.size():
  var point: Vector2 = points[i]
  if c.stage.fan: point += c.dir.orthogonal()*([0,-28,28][i%3])*game.Spells.copies(c.stage,"fan")
  if c.stage.seek:
   var target: Node2D = game.nearest_enemy(point,100*game.Spells.seek_strength(c.stage))
   if target!=null: point = point.move_toward(target.position,60*game.Spells.seek_strength(c.stage))
  var owned: Array = runtime.zones.filter(func(z):return z.kind=="ember_path")
  if owned.size()>=12: runtime.evict_zone(owned[0])
  if runtime.zones.size()>=runtime.MAX_ZONES: runtime.evict_zone(runtime.zones[0])
  var zone := c.duplicate()
  zone.merge({"kind":"ember_path","pos":point,"radius":24*c.scale,"damage":DIRECT_DAMAGE.ember_path*damage_scale(c),"life":1.8,"age":0.0,"pulse":0.3,"group":c},true)
  runtime.add_zone(zone)
  runtime.track("path_patches",c.meter_source)
func end_path(zone: Dictionary, normal: bool) -> void:
 var group: Dictionary = zone.group
 group.remaining -= 1
 if not normal: group.cancelled = true
 if group.remaining==0 and not group.cancelled: runtime.trigger(group,group.last_pos,"expire")
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
  for n in 2*game.Spells.copies(c.stage,mode):
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
