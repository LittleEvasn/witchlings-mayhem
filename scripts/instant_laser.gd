extends RefCounted
## Snapshot ray cast inspired by Magicraft's spell 1004, not its sustained 1011 ray.
## Geometry, direct damage and refraction are resolved on cast; beam lines are only VFX.
const MAX_RANGE := 480.0
const REFRACTION_SEARCH := 260.0
const MAX_LEGS := 16
const BASE_DAMAGE := 18.0
const ORBIT_STEPS := 32

static func fire(c: Dictionary, ext: RefCounted) -> void:
	var game: Node2D = ext.game
	var origin: Vector2 = c.pos
	var aim: Vector2 = c.dir.normalized()
	if aim.length_squared() < 0.0001: aim = Vector2.RIGHT
	# A seeker chooses its initial line, not a continuously damaging tracked beam.
	if c.get("_motion","") == "seek":
		var target: Node2D = game.nearest_enemy(origin,MAX_RANGE*game.Spells.Effects.profile(c.stage,"seek").range)
		if target != null: aim = origin.direction_to(target.position)
	if c.get("_motion","") == "orbit":
		_orbit(c,ext,aim)
		return
	for angle in game.Spells.shot_angles(c.stage):
		if not game.magic_active(): return
		_trace(c,ext,origin,aim.rotated(deg_to_rad(float(angle))))

static func _trace(c: Dictionary, ext: RefCounted, start: Vector2, initial_direction: Vector2) -> void:
	var game: Node2D = ext.game
	var cursor: Vector2 = start
	var direction: Vector2 = initial_direction.normalized()
	var distance_left: float=float(c.get("length",MAX_RANGE))
	var reflected := int(game.Spells.attack_data(c.stage).get("refractions",0))
	# The independent bounce modifier adds to the native refracted paths.
	reflected += int(game.Spells.Effects.profile(c.stage,"bounce").targets)
	var pierce_left := int(game.Spells.Effects.profile(c.stage,"pierce").targets)
	var seen: Dictionary = {}
	for _leg in MAX_LEGS:
		if distance_left <= 2.0 or not game.magic_active(): break
		var end: Vector2 = cursor+direction*distance_left
		var hit: Node2D = null
		var contact_distance: float = distance_left+1.0
		# Sort implicitly by distance along the ray, not by radial distance.
		for enemy in ext.targets((cursor+end)*0.5,distance_left*0.5+c.width+50.0,seen):
			if enemy.dead: continue
			var offset: Vector2 = enemy.position-cursor
			var projection: float = offset.dot(direction)
			if projection < -enemy.radius-c.width or projection > distance_left+enemy.radius+c.width: continue
			var lateral: float = absf(offset.cross(direction))
			var combined: float = enemy.radius+c.width
			if lateral > combined: continue
			var near_face: float = maxf(0.0,projection-sqrt(maxf(0.0,combined*combined-lateral*lateral)))
			if near_face < contact_distance:
				hit=enemy
				contact_distance=near_face
		if hit == null:
			c.segments.append([cursor,end])
			c["_laser_end"]=end
			break
		var point: Vector2 = cursor+direction*maxf(0.25,contact_distance)
		c.segments.append([cursor,point])
		c["_laser_end"]=point
		seen[hit.get_instance_id()]=true
		c._beam_hit_ids[hit.get_instance_id()]=true
		_hit(c,ext,hit,direction)
		if not game.magic_active(): return
		distance_left-=maxf(0.25,contact_distance)
		if reflected > 0:
			var options: Array = ext.targets(hit.position,REFRACTION_SEARCH,seen)
			if not options.is_empty():
				var next_target: Node2D=options[0]
				var next_dir: Vector2=hit.position.direction_to(next_target.position)
				if next_dir.length_squared()>0.001:
					reflected-=1
					ext.runtime.track("laser_refractions",c.meter_source)
					direction=next_dir
					cursor=point+direction*2.0
					distance_left-=2.0
					continue
		if pierce_left>0:
			pierce_left-=1
			cursor=point+direction*2.0
			distance_left-=2.0
			continue
		break
	# Split is a single event per cast, not per damage frame.
	# Split after beam expiry; impact alone does not destroy the laser.

static func _orbit(c: Dictionary, ext: RefCounted, aim: Vector2) -> void:
	var game: Node2D=ext.game
	var center: Vector2 = c._anchor
	if not c.stage.get("_linked",false) and not c.stage.get("_landed",false):
		center=game.player.position
	var radius: float = ext.rank_value(c.stage,"orbit")
	if radius<=0: radius=110.0
	var from: Vector2=center+aim*radius
	var first: Vector2=from
	var seen: Dictionary={}
	for step in ORBIT_STEPS:
		var angle: float=aim.angle()+TAU*float(step+1)/ORBIT_STEPS
		var to: Vector2=center+Vector2.RIGHT.rotated(angle)*radius
		c.segments.append([from,to])
		for enemy in ext.targets((from+to)*0.5,from.distance_to(to)*0.5+c.width+50,seen):
			if enemy.dead: continue
			var nearest: Vector2=Geometry2D.get_closest_point_to_segment(enemy.position,from,to)
			if nearest.distance_to(enemy.position)>enemy.radius+c.width: continue
			seen[enemy.get_instance_id()]=true
			c._beam_hit_ids[enemy.get_instance_id()]=true
			_hit(c,ext,enemy,(to-from).normalized())
			if not game.magic_active(): return
		from=to
	c["_laser_end"]=first
	# Split after beam expiry, once the circular ray has resolved.

static func _hit(c: Dictionary, ext: RefCounted, enemy: Node2D, direction: Vector2) -> void:
	ext.runtime.track("laser_contacts",c.meter_source)
	ext.runtime.behavior.hit(enemy,BASE_DAMAGE*ext.runtime.behavior.damage_scale(c),direction,c)
	if not ext.game.magic_active(): return
	ext.runtime.trigger(c,enemy.position)
	if not ext.game.magic_active(): return
	ext.impact(c,enemy.position)
