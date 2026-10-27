extends RefCounted
## State effects and non-projectile attacks share the production runtime and cast lineage.
const SIGIL_BURST_DAMAGE := 42.0
var runtime_ref: WeakRef
var runtime: RefCounted:
 get: return runtime_ref.get_ref()
var game: Node2D
var clock := 0.0
var cast_serial := 0
var gathered: Dictionary = {}
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
 gathered.clear()
 strikes.clear()
 orbits.clear()
 statuses.clear()
 path.clear()
 flashes.clear()
 last_path = Vector2.INF
func context(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power: float, lane: String, echo: bool, lineage: int, generation: int) -> Dictionary:
 return {"owner_orb":stage.get("_orb",0),"stage":stage.duplicate(),"attack":stage.attack,"pos":origin,"dir":direction,"original_dir":direction,"follow":follow.duplicate(),"triggered":false,"connector":stage.get("connector","impact"),"factor":factor,"power":power,"child_factor":factor*0.65,"cast_id":lineage,"generation":generation,"meter_source":lane+"/"+str(stage.attack)+("/echo" if echo else ""),"meter_echo":echo,"lane":lane,"scale":(1.6 if stage.giant else 1.0)*stage.get("_growth",1.0)}
func damage_scale(c: Dictionary) -> float:
 return float(c.factor)*float(c.power)*(3.0 if c.stage.get("charge",false) else 1.0)*(0.85 if c.stage.get("sigil",false) else 1.0)
func state_for(enemy: Node2D) -> Dictionary:
 var id: int = enemy.get_instance_id()
 if not statuses.has(id): statuses[id] = {"enemy":enemy,"cold":0.0,"cold_until":0.0,"frozen_until":0.0,"immune_until":0.0,"marks":[],"mark_mass":0.0,"mark_until":0.0,"casts":{}}
 return statuses[id]
func movement_factor(enemy: Node2D) -> float:
 var s: Dictionary = statuses.get(enemy.get_instance_id(),{})
 if s.is_empty(): return 1.0
 if not enemy.boss and s.frozen_until>clock: return 0.0
 return 0.8 if s.cold>=1 else 1.0
func update(delta: float) -> void:
 clock += delta
 for key in gathered.keys():
  if clock-gathered[key].time>12: gathered.erase(key)
 for id in statuses.keys():
  var s: Dictionary = statuses[id]
  if not is_instance_valid(s.enemy) or s.enemy.dead:
   statuses.erase(id)
   continue
  if s.frozen_until>0 and s.frozen_until<=clock:
   s.frozen_until = 0.0
   s.immune_until = clock+1.5
   s.cold = 0.0
  if s.cold_until<=clock: s.cold = 0.0
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
 if frozen and c.stage.get("shatter",false):
  s.frozen_until = 0.0
  s.immune_until = clock+1.5
  s.cold = 0.0
  var extra: float = 30*c.factor*c.power*(3 if c.stage.get("charge",false) else 1)
  var source: String = c.meter_source+"/shatter"
  if enemy.dead:
   runtime.track("damage_raw",source,extra)
   runtime.track("damage_overkill",source,extra)
  else: game.damage_enemy(enemy,extra,direction,source)
  runtime.track("shatters",source)
  game.burst(at,Color("b8eaff"),8)
 if cold>0 and not enemy.dead:
  s.cold_until = clock+3
  if s.frozen_until<=clock:
   s.cold = minf(2.0 if s.immune_until>clock else 3.0,s.cold+cold)
   runtime.track("cold_added",c.meter_source,cold)
   if s.cold>=3:
    s.frozen_until = clock+1.2
    runtime.track("freezes",c.meter_source)
 if c.stage.get("sigil",false): add_marks(s,c,at)
 if c.has("contributors"):
  for part in c.contributors:
   if part.stage.get("sigil",false) and part.cast_id!=c.cast_id: add_marks(s,part,at)
func add_marks(s: Dictionary, c: Dictionary, at: Vector2) -> void:
 var id: int = c.cast_id
 var record: Dictionary = s.casts.get(id,{"mass":0.0,"last":-100.0})
 if clock-record.last<0.25: return
 var amount := minf(float(c.factor),2.0-float(record.mass))
 if amount<=0: return
 record.mass += amount
 record.last = clock
 s.casts[id] = record
 s.mark_mass += amount
 s.mark_until = clock+3
 s.marks.append({"mass":amount,"power":c.power})
 runtime.track("marks_added",c.meter_source,amount)
 if s.mark_mass+0.00001<6: return
 var needed := 6.0
 var weighted := 0.0
 while needed>0.00001 and not s.marks.is_empty():
  var m: Dictionary = s.marks[0]
  var take := minf(needed,m.mass)
  weighted += take*m.power
  m.mass -= take
  needed -= take
  if m.mass<=0.00001: s.marks.pop_front()
 s.mark_mass = maxf(0,s.mark_mass-6)
 runtime.track("sigil_bursts",c.meter_source+"/sigil")
 game.ring(at,48,Color("ff9cae"),0.4)
 game.explode(at,SIGIL_BURST_DAMAGE*weighted/6,48,c.meter_source+"/sigil")
func area(c: Dictionary, at: Vector2, damage: float, radius: float) -> int:
 var count := 0
 runtime.track("explosions",c.meter_source)
 game.ring(at,radius,game.Spells.PARTS[c.attack].color,0.3)
 for enemy in game.nearby(at,radius+45):
  if enemy.dead or enemy.position.distance_to(at)>radius+enemy.radius: continue
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
    var target: Node2D = game.nearest_enemy(c.pos,220*c.scale)
    if target!=null: c.dir = c.pos.direction_to(target.position)
   var length: float = 170*c.scale
   var victims: Array = game.nearby(c.pos,length+45)
   victims.sort_custom(func(a,b):return c.pos.distance_squared_to(a.position)<c.pos.distance_squared_to(b.position))
   var count := 0
   for enemy in victims:
    if enemy.dead or c.pos.distance_to(enemy.position)>length+enemy.radius: continue
    var offset: Vector2 = enemy.position-c.pos
    var inside := false
    for i in (3 if stage.fan else 1):
     var angle: float = (i-1)*0.48 if stage.fan else 0.0
     if absf(c.dir.rotated(angle).angle_to(offset))<=PI/6: inside = true
    if not inside: continue
    hit(enemy,10*damage_scale(c),c.dir,c,c.factor)
    if not game.magic_active(): return
    runtime.trigger(c,enemy.position)
    extra_links(c,enemy.position,enemy,false)
    count += 1
    if count >= (6 if stage.pierce else 4): break
   flash({"kind":"cone","pos":c.pos,"dir":c.dir,"radius":length,"fan":stage.fan,"life":0.22})
   runtime.trigger(c,c.pos+c.dir*length,"expire")
  "thunder":
   if strikes.size()>=32:
    runtime.track("strikes_blocked",c.meter_source)
    return
   var center: Vector2 = game.cast_target if c.lane=="primary" else c.pos
   if c.has("target_point") and c.lane=="primary": center = c.target_point
   center = c.pos+(center-c.pos).limit_length(480) if c.lane=="primary" else center
   var points: Array = []
   for i in (3 if stage.fan else 1):
    var point: Vector2 = center+c.dir.orthogonal()*((i-1)*70 if stage.fan else 0)
    points.append({"pos":point,"target":game.nearest_enemy(point,160) if stage.seek else null})
   c["points"] = points
   c["center"] = center
   c["life"] = 0.45
   strikes.append(c)
   runtime.track("strikes_scheduled",c.meter_source)
  "satellite":
   var active := 0
   for orbit in orbits:
    if orbit.lane==c.lane and orbit.owner_orb==c.owner_orb and orbit.get("meter_echo",false)==c.get("meter_echo",false): active += 1
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
  if c.stage.bounce:
   var from: Vector2 = c.center
   for n in 2:
    var enemy: Node2D = game.nearest_enemy(from,160,hit_ids)
    if enemy==null: break
    hit_ids[enemy.get_instance_id()] = true
    var arc := c.duplicate()
    arc.factor *= 0.5
    hit(enemy,36*damage_scale(arc),Vector2.ZERO,arc)
    if not game.magic_active(): return
    runtime.trigger(c,enemy.position)
    flash({"kind":"arc","pos":from,"to":enemy.position,"life":0.2})
    from = enemy.position
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
  if c.lane=="primary": c.pos = game.player.position
  c.bodies.clear()
  for n in (3 if c.stage.fan else 1):
   var angle: float = c.age*TAU+n*TAU/3
   var radius := 95.0
   if c.stage.seek:
    var target: Node2D = game.nearest_enemy(c.pos,170)
    if target!=null:
     angle = lerp_angle(angle,c.pos.angle_to_point(target.position),0.65)
     radius = clampf(c.pos.distance_to(target.position),55,150)
   var point: Vector2 = c.pos+Vector2.RIGHT.rotated(angle)*radius
   c.bodies.append(point)
   for enemy in game.nearby(point,12*c.scale+45):
    if enemy.dead or enemy.position.distance_to(point)>12*c.scale+enemy.radius: continue
    var id: int = enemy.get_instance_id()
    if clock-float(c.hits.get(id,-100))<0.45: continue
    c.hits[id] = clock
    hit(enemy,14*damage_scale(c),Vector2.ZERO,c)
    if not game.magic_active(): return
    extra_links(c,enemy.position,enemy)
    runtime.track("orbit_contacts",c.meter_source)
    runtime.trigger(c,enemy.position)
  for id in c.hits.keys():
   if clock-c.hits[id]>1: c.hits.erase(id)
func emit_path(c: Dictionary) -> void:
 var points: Array = []
 if c.lane=="primary":
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
  if c.stage.fan: point += c.dir.orthogonal()*([0,-28,28][i%3])
  if c.stage.seek:
   var target: Node2D = game.nearest_enemy(point,100)
   if target!=null: point = point.move_toward(target.position,60)
  var owned: Array = runtime.zones.filter(func(z):return z.kind=="ember_path")
  if owned.size()>=12: runtime.evict_zone(owned[0])
  if runtime.zones.size()>=runtime.MAX_ZONES: runtime.evict_zone(runtime.zones[0])
  var zone := c.duplicate()
  zone.merge({"kind":"ember_path","pos":point,"radius":24*c.scale,"damage":4*damage_scale(c),"life":1.8,"age":0.0,"pulse":0.3,"group":c},true)
  runtime.zones.append(zone)
  runtime.track("path_patches",c.meter_source)
func end_path(zone: Dictionary, normal: bool) -> void:
 var group: Dictionary = zone.group
 group.remaining -= 1
 if not normal: group.cancelled = true
 if group.remaining==0 and not group.cancelled: runtime.trigger(group,group.last_pos,"expire")
func install_graft(zone: Dictionary) -> bool:
 if not zone.stage.get("graft",false): return false
 var config: Dictionary = zone.stage.duplicate()
 config.erase("echo")
 var key := str([zone.generation,zone.get("owner_orb",0),zone.lane,config])
 zone["graft_key"] = key
 var nearest: Dictionary = {}
 var distance := 48.001
 for other in runtime.zones:
  if other.get("graft_key","")!=key or other.mass>=3: continue
  var d: float = other.pos.distance_to(zone.pos)
  if d<distance:
   distance = d
   nearest = other
 var budget: float = zone.damage*(11 if zone.kind=="vortex" else 1)
 if nearest.is_empty():
  zone["mass"] = minf(1,zone.factor)
  zone["growth_casts"] = {zone.cast_id:zone.mass}
  zone["budget"] = budget
  zone["base_radius"] = zone.radius
  zone["tier"] = 1
  zone["contributors"] = []
  zone["mature_at"] = -1.0
  zone.life = 6.0
  zone.pulse = 0.25
  runtime.track("graft_budget_added",zone.meter_source,budget)
  return false
 var prior: float = nearest.growth_casts.get(zone.cast_id,0)
 var add := minf(zone.factor,1.0-prior)
 nearest.growth_casts[zone.cast_id] = prior+add
 nearest.mass = minf(3,nearest.mass+add)
 nearest.budget += budget
 # Each input retains its own status and power snapshot. No consumed damage is restored.
 if nearest.contributors.size()<48: nearest.contributors.append(zone)
 if zone.child_factor*zone.power>nearest.child_factor*nearest.get("child_power",nearest.power):
  nearest.child_factor = zone.child_factor
  nearest["child_power"] = zone.power
 nearest.tier = clampi(int(floor(nearest.mass+0.0001)),1,3)
 nearest.radius = nearest.base_radius*(1.0+0.2*(nearest.tier-1))
 runtime.track("graft_merges",zone.meter_source)
 runtime.track("graft_growth",zone.meter_source,add)
 runtime.track("graft_budget_added",zone.meter_source,budget)
 flash({"kind":"arc","pos":zone.pos,"to":nearest.pos,"life":0.3})
 if nearest.tier==3:
  nearest.mass = 3.0
  nearest.budget *= 1.2
  nearest.child_factor *= 1.2
  nearest.mature_at = nearest.age+0.4
  runtime.track("graft_matured",zone.meter_source)
  runtime.track("graft_growth_seconds",zone.meter_source,nearest.age)
 return true

func gather(stage: Dictionary, factor: float, power: float, lane: String) -> Dictionary:
 var key := str([runtime.generation,stage.get("_orb",0),lane,stage])
 if not gathered.has(key):
  if gathered.size()>=32: return {}
  gathered[key] = {"count":0,"factor":0.0,"weighted":0.0,"time":clock,"owner_orb":stage.get("_orb",0)}
 var bank: Dictionary = gathered[key]
 bank.count += 1
 bank.factor += factor
 bank.weighted += factor*power
 bank.time = clock
 runtime.track("graft_casts_gathered")
 if bank.count<3: return {}
 var release := stage.duplicate()
 release["_graft_release"] = true
 release["_growth"] = 1.4
 gathered.erase(key)
 runtime.track("graft_casts_released")
 return {"stage":release,"factor":bank.factor*1.2,"power":bank.weighted/maxf(0.001,bank.factor)}

func extra_links(c: Dictionary, at: Vector2, victim: Node2D, pierce := true, bounce := true, skip_radius := 0.0) -> void:
 # Area attacks extend through the forward line or jump to nearby targets, once per cast context.
 for mode in ["pierce","bounce"]:
  if not c.stage.get(mode,false) or (mode=="pierce" and not pierce) or (mode=="bounce" and not bounce) or c.get("linked_"+mode,false): continue
  c["linked_"+mode] = true
  var seen := {}
  if victim!=null: seen[victim.get_instance_id()]=true
  var origin := at
  for n in 2:
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
   arc.factor *= 0.5
   var base: float = {"frost":10.0,"thunder":36.0,"satellite":14.0,"ember_path":4.0}.get(c.attack,10.0)
   hit(target,base*damage_scale(arc),c.dir,arc,c.factor*0.5 if c.attack=="frost" else 0.0)
   flash({"kind":"arc","pos":origin,"to":target.position,"life":0.18})
   runtime.track("special_"+mode,c.meter_source)
   if not game.magic_active(): return
   origin = target.position
