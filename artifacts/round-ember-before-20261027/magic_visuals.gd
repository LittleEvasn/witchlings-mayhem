extends Node2D
## Cheap, bounded vector VFX. Combat hit shapes match the visible rings/bolts.
var game: Node2D

func _draw() -> void:
	if game.encounters!=null: game.encounters.draw(self)
	if game.boss_encounter!=null: game.boss_encounter.tells(self)
	_draw_specials()
	if game.state in ["combat","trial","edit","shop"]:
		for i in 2:
			var pos: Vector2 = game.orb_position(i)
			var color := Color("a8efe2") if i==0 else Color("ff9cae")
			var occupied: bool = not (game.orb_drafts[i] if game.state=="trial" else game.orb_recipes[i]).is_empty()
			draw_circle(pos,15,Color(color,0.12 if occupied else 0.04))
			draw_circle(pos,8,Color(color,0.9 if occupied else 0.25))
			draw_circle(pos-Vector2(2,2),3,Color("fff8e8"))
			var stages: Array = game.orb_trial[i] if game.state=="trial" else game.orb_compiled[i]
			if not stages.is_empty():
				var progress := clampf(1-float(game.orb_clocks[i])/game.cast_delay(game.Spells.interval(stages)),0,1)
				draw_arc(pos,12,-PI/2,-PI/2+TAU*progress,24,Color(color,0.7),1.5,true)
	for zone in game.magic.zones:
		if not zone.get("garden_leader",true): continue
		var pos: Vector2 = zone.pos
		var radius: float = zone.radius
		var c := Color("ffc79f") if zone.kind=="ember_path" else (Color("c6a3ff") if zone.kind=="vortex" else Color("b8ed9a"))
		c = zone.get("tint",c)
		var alpha := minf(1,float(zone.get("garden_life",zone.life))/0.4)
		draw_circle(pos,radius,Color(c,0.08*alpha))
		draw_arc(pos,radius,0,TAU,48,Color(c,0.55*alpha),1.8,true)
		if zone.get("tier",0)>0:
			for n in int(zone.tier): draw_arc(pos,9+n*6,0,TAU,24,Color(c,0.8),2,true)
		if zone.kind=="ember_path":
			var points: Array = zone.get("path_points",[pos])
			if points.size()>1:
				draw_polyline(PackedVector2Array(points),Color(c,0.14*alpha),radius*2,true)
				draw_polyline(PackedVector2Array(points),Color(c,0.7*alpha),3,true)
			else: draw_circle(pos,radius,Color(c,0.18*alpha))
			continue
		if zone.kind == "vortex":
			for arm in 3:
				var points := PackedVector2Array()
				for j in 20:
					var f := float(j)/19
					points.append(pos+Vector2.RIGHT.rotated(arm*TAU/3+f*4-zone.age*3)*(radius*f*0.9))
				draw_polyline(points,Color(c,0.65*alpha),2,true)
		else:
			for petal in 6:
				var dir := Vector2.RIGHT.rotated(petal*TAU/6)
				draw_colored_polygon(PackedVector2Array([pos+dir*radius*0.25,pos+dir*radius*0.66+dir.orthogonal()*7,pos+dir*radius*0.84,pos+dir*radius*0.66-dir.orthogonal()*7]),Color(c,0.65*alpha))
			draw_circle(pos,8,Color("ffe3b0"))
	for p in game.projectiles:
		var c: Color = p.get("tint",game.Spells.PARTS[p.attack].color)
		var pos: Vector2 = p.pos
		if p.attack == "boomerang":
			for bud in p.get("buds",[]): draw_circle(bud,6,Color("ffb6d7"))
			var angle: float = p.age*11
			draw_arc(pos,p.radius,angle,angle+PI*1.45,20,c,p.radius*0.5,true)
			draw_line(pos-p.dir*20,pos,Color(c,0.3),3,true)
			continue
		draw_line(pos-p.dir*18,pos,c*Color(1,1,1,0.3),p.radius*2.6,true)
		draw_circle(pos,p.radius*2,Color(c,0.12))
		draw_circle(pos,p.radius,c)
		draw_circle(pos-Vector2(1,1),p.radius*0.44,Color("fff8e8"))
	for p in game.hostile_shots:
		draw_circle(p.pos,8,Color("49263d"))
		draw_circle(p.pos,5,Color("ff6b86"))
		draw_circle(p.pos,2,Color("ffe9cd"))
	for gem in game.gems:
		var pos: Vector2 = gem.pos
		var r := 5.0
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-r),pos+Vector2(r,0),pos+Vector2(0,r),pos+Vector2(-r,0)]),Color("bae9ff"))
	for fx in game.effects:
		var f: float = fx.life / fx.total
		var col: Color = fx.color
		col.a = f * 0.8
		if fx.kind == "ring":
			draw_circle(fx.pos,fx.radius*(1-f*0.2),Color(col, f*0.12))
			draw_arc(fx.pos,fx.radius*(1-f*0.2),0,TAU,32,col,2.5,true)
		else:
			draw_line(fx.pos,fx.pos-fx.vel*0.035,col,2,true)

func _draw_specials() -> void:
	var b: RefCounted = game.magic.behavior
	var stages: Array = game.trial_stages if game.state=="trial" else game.compiled
	var charged := false
	for stage in stages:
		if stage.get("charge",false): charged = true
	if charged and game.magic_active():
		var interval: float = game.cast_delay(game.Spells.interval(stages))
		var progress := clampf(1-game.cast_clock/interval,0,1)
		draw_arc(game.player.position,28,-PI/2,-PI/2+TAU*progress,32,Color("ffe7a3"),4 if game.cast_clock<0.15 else 2,true)
	for s in b.statuses.values():
		if not is_instance_valid(s.enemy) or s.enemy.dead: continue
		var pos: Vector2 = s.enemy.position
		if s.frozen_until>b.clock:
			var r: float = s.enemy.radius+7
			draw_polyline(PackedVector2Array([pos+Vector2(0,-r),pos+Vector2(r,0),pos+Vector2(0,r),pos-Vector2(r,0),pos-Vector2(0,r)]),Color("b8eaff"),2,true)
		elif s.cold>=1: draw_arc(pos,s.enemy.radius+4,0,PI,16,Color("b8eaff"),2,true)
	for strike in b.strikes:
		for point in strike.points:
			var r: float = strike.strike_radius
			draw_arc(point.pos,r,0,TAU,32,Color("ffe7a3"),2,true)
			draw_line(point.pos-Vector2(8,0),point.pos+Vector2(8,0),Color("ffe7a3"),2,true)
			draw_circle(point.pos,maxf(2,r*(1-strike.life/0.45)),Color(1,0.9,0.6,0.1))
	for orbit in b.orbits:
		draw_arc(orbit.pos,orbit.orbit_radius,0,TAU,48,Color(0.7,0.8,1,0.1),1,true)
		for point in orbit.bodies:
			draw_circle(point,12*orbit.scale,Color("b8c9ff"))
			draw_circle(point,5*orbit.scale,Color("fff8e8"))
	for f in b.flashes:
		match f.kind:
			"cone":
				var count: int = f.get("branches",3 if f.fan else 1)
				var half: float = f.get("half_angle",PI/6)
				for n in count:
					var angle: float = f.dir.angle()+(n-(count-1)*.5)*.48
					var points := PackedVector2Array([f.pos])
					for j in 13: points.append(f.pos+Vector2.RIGHT.rotated(angle-half+j*half/6)*f.radius)
					draw_colored_polygon(points,Color(0.65,0.9,1,0.13))
					draw_arc(f.pos,f.radius,angle-half,angle+half,16,Color("b8eaff"),2,true)
			"lightning": draw_polyline(PackedVector2Array([f.pos+Vector2(14,-150),f.pos+Vector2(-12,-65),f.pos+Vector2(12,-70),f.pos]),Color("ffe7a3"),5,true)
			"arc": draw_line(f.pos,f.to,Color("ffe7a3"),2,true)
