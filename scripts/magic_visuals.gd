extends Node2D
## Licensed sprite accents; rings retain the actual combat footprints.
const CartoonVFX = preload("res://scripts/cartoon_vfx.gd")
var vfx := CartoonVFX.new()
var ring_unit: PackedVector2Array=[]
var game: Node2D

func _ready() -> void:
	for n in 33: ring_unit.append(Vector2.RIGHT.rotated(n*TAU/32))
	# Pay the six selected texture loads at scene entry, never on the first hit.
	for key in ["bullet","explosion","moon","fire","star","shockwave"]: vfx.texture(key)

func _draw() -> void:
	vfx.draws = 0
	if game.monsters!=null: game.monsters.draw(self)
	if game.encounters!=null: game.encounters.draw(self)
	if game.boss_encounter!=null: game.boss_encounter.tells(self)
	_draw_specials()
	_draw_extensions()
	if game.state in ["combat","trial","edit","shop"]:
		for i in game.orb_recipes.size():
			var pos: Vector2 = game.orb_position(i)
			var color := Color("a8efe2") if i==0 else Color("ff9cae")
			var occupied: bool = game.Spells.has_content(game.orb_drafts[i] if game.state=="trial" else game.orb_recipes[i])
			draw_circle(pos,15,Color(color,0.12 if occupied else 0.04))
			draw_circle(pos,8,Color(color,0.9 if occupied else 0.25))
			draw_circle(pos-Vector2(2,2),3,Color("fff8e8"))
			var stages: Array = game.orb_trial[i] if game.state=="trial" else game.orb_compiled[i]
			if not stages.is_empty():
				var progress := clampf(1-float(game.orb_clocks[i])/game.orb_delay(game.Spells.interval(stages),i),0,1)
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
			draw_circle(pos,radius,Color(c,0.18*alpha))
			vfx.draw(self,"fire",pos,radius*3.0,zone.age,Color(1,1,1,alpha),0,0,true)
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
		if p.stage.get("fusion","")=="shining_spear":
			draw_line(pos-p.dir*70,pos,Color("fff1b5"),5,true)
			vfx.draw(self,"star",pos,22,p.age)
			continue
		if p.stage.get("fusion","")=="ball_lightning":
			draw_circle(pos,p.radius,Color("94dbff"))
			draw_arc(pos,p.radius*1.3,p.age*8,p.age*8+PI,20,Color("f1faff"),2,true)
			continue
		if p.attack=="fireball":
			if vfx.draw(self,"fire",pos,p.radius*5.0,p.age,Color.WHITE,0,p.dir.angle(),true): continue
		if p.attack == "boomerang":
			for bud in p.get("buds",[]): draw_circle(bud,6,Color("ffb6d7"))
			var angle: float = p.age*11
			if not vfx.draw(self,"moon",pos,p.radius*4.0,.12+fmod(p.age,.20),Color.WHITE,0,angle):
				draw_arc(pos,p.radius,angle,angle+PI*1.45,20,c,p.radius*0.5,true)
			draw_line(pos-p.dir*20,pos,Color(c,0.3),3,true)
			continue
		if p.attack=="bolt" and vfx.draw(self,"bullet",pos-p.dir*p.radius*2.0,p.radius*8.0,p.age,Color.WHITE,0,p.dir.angle()): continue
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
	var outlines:=PackedVector2Array()
	var colors:=PackedColorArray()
	for fx in game.effects:
		var f: float=fx.life/fx.total
		var col: Color=fx.color
		col.a=f*.8
		if fx.kind=="ring":
			var radius: float=fx.radius*(1-f*.2)
			draw_circle(fx.pos,radius,Color(col,f*.12))
			append_ring(outlines,fx.pos,radius)
			for n in 32: colors.append(col)
		else:
			outlines.append(fx.pos);outlines.append(fx.pos-fx.vel*.035)
			colors.append(col)
	if not outlines.is_empty(): draw_multiline_colors(outlines,colors,2.5,false)

func append_ring(points: PackedVector2Array, at: Vector2, radius: float) -> void:
	for n in 32:
		points.append(at+ring_unit[n]*radius)
		points.append(at+ring_unit[n+1]*radius)

func _draw_specials() -> void:
	var b: RefCounted = game.magic.behavior
	var stages: Array = game.trial_stages if game.state=="trial" else game.compiled
	var charged := false
	for stage in stages:
		if stage.get("charge",false): charged = true
	if charged and game.magic_active():
		var interval: float = game.orb_delay(game.Spells.interval(stages),game.active_orb)
		var progress := clampf(1-game.cast_clock/interval,0,1)
		draw_arc(game.player.position,28,-PI/2,-PI/2+TAU*progress,32,Color("ffe7a3"),4 if game.cast_clock<0.15 else 2,true)
	for s in b.statuses.values():
		if not is_instance_valid(s.enemy) or s.enemy.dead: continue
		var pos: Vector2 = s.enemy.position
		if s.frozen_until>b.clock:
			var r: float = s.enemy.radius+7
			draw_polyline(PackedVector2Array([pos+Vector2(0,-r),pos+Vector2(r,0),pos+Vector2(0,r),pos-Vector2(r,0),pos-Vector2(0,r)]),Color("b8eaff"),2,true)
		elif s.cold>=1: draw_arc(pos,s.enemy.radius+4,0,PI,16,Color("b8eaff"),2,true)
	var tell_lines:=PackedVector2Array()
	for strike in b.strikes:
		for point in strike.points:
			var r: float=strike.strike_radius
			draw_circle(point.pos,maxf(2,r*(1-strike.life/.45)),Color(1,.9,.6,.1))
			append_ring(tell_lines,point.pos,r)
			tell_lines.append(point.pos-Vector2(8,0));tell_lines.append(point.pos+Vector2(8,0))
	if not tell_lines.is_empty(): draw_multiline(tell_lines,Color("ffe7a3"),2,false)
	for orbit in b.orbits:
		draw_arc(orbit.pos,orbit.orbit_radius,0,TAU,48,Color(0.7,0.8,1,0.1),1,true)
		for point in orbit.bodies:
			if not vfx.draw(self,"star",point,48*orbit.scale,orbit.age):
				draw_circle(point,12*orbit.scale,Color("b8c9ff"))
				draw_circle(point,5*orbit.scale,Color("fff8e8"))
	var lightning_lines:=PackedVector2Array()
	var chain_lines:=PackedVector2Array()
	for f in b.flashes:
		match f.kind:
			"vfx": vfx.draw(self,f.effect,f.pos,f.diameter,f.total-f.life,Color.WHITE,f.total)
			"cone":
				var count: int = f.get("branches",3 if f.fan else 1)
				var half: float = f.get("half_angle",PI/6)
				for n in count:
					var angle: float = f.directions[n].angle() if f.has("directions") else f.dir.angle()+(n-(count-1)*.5)*.48
					var points := PackedVector2Array([f.pos])
					for j in 13: points.append(f.pos+Vector2.RIGHT.rotated(angle-half+j*half/6)*f.radius)
					draw_colored_polygon(points,Color(0.65,0.9,1,0.13))
					draw_arc(f.pos,f.radius,angle-half,angle+half,16,Color("b8eaff"),2,true)
			"lightning":
				var points: Array=[f.pos+Vector2(14,-150),f.pos+Vector2(-12,-65),f.pos+Vector2(12,-70),f.pos]
				for n in 3:
					lightning_lines.append(points[n]);lightning_lines.append(points[n+1])
			"arc":
				chain_lines.append(f.pos);chain_lines.append(f.to)
	if not lightning_lines.is_empty(): draw_multiline(lightning_lines,Color("ffe7a3"),5,false)
	if not chain_lines.is_empty(): draw_multiline(chain_lines,Color("ffe7a3"),2,false)

func _draw_extensions() -> void:
	var x: RefCounted=game.magic.extensions
	for job in x.jobs:
		if job.kind!="land": continue
		var at: Vector2=job.pos
		draw_arc(at,26,0,TAU,24,Color(.75,.7,1,.55),2,true)
		var height: float=job.delay*200
		vfx.draw(self,"star",at-Vector2(0,height),30,job.delay)
		draw_line(at-Vector2(0,height),at,Color(.8,.75,1,.2),2,true)
	for c in x.clouds:
		var color: Color=Color("a6db83") if c.kind in ["poison","gas"] else Color("ffcf80")
		draw_circle(c.pos,c.radius,Color(color,.08))
		draw_arc(c.pos,c.radius,0,TAU,24,Color(color,.35),1.5,true)
		if c.kind=="seal": vfx.draw(self,"star",c.pos,c.radius*1.2,c.age,Color.WHITE,0,0,true)
	for c in x.beams:
		if c.get("_charge_left",0)>0:
			draw_arc(c.pos,20,0,TAU*(1-c._charge_left/.35),24,Color("dcb9ff"),3,true)
			continue
		var alpha: float=minf(1,c.life/.15)
		var color:=Color("80dcff") if c.attack=="laser" else Color("ffad66")
		if c.attack=="laser":
			for segment in c.segments:
				draw_line(segment[0],segment[1],Color(color,.15*alpha),c.width*3,true)
				draw_line(segment[0],segment[1],Color(color,.7*alpha),c.width,true)
				draw_line(segment[0],segment[1],Color(1,1,1,.8*alpha),maxf(2,c.width*.25),true)
		else:
			for segment in c.segments:
				var direction: Vector2=(segment[1]-segment[0]).normalized()
				var half: float=deg_to_rad(game.Spells.attack_data(c.stage).spread*.5)
				var points:=PackedVector2Array([c.pos])
				for n in 13: points.append(c.pos+direction.rotated(-half+n*half/6)*c.length*c.scale)
				draw_colored_polygon(points,Color(color,.10*alpha))
				for n in 3: vfx.draw(self,"fire",c.pos+direction.rotated((n-1)*half*.6)*c.length*.65,65*c.scale,c.age+n*.06,Color(1,1,1,alpha),0,direction.angle(),true)
	for s in x.status.values():
		if not is_instance_valid(s.enemy) or s.enemy.dead: continue
		var at: Vector2=s.enemy.position+Vector2(0,-s.enemy.radius-10)
		if s.burn>0: draw_circle(at,3,Color("ffad66"))
		if s.poison>0: draw_circle(at+Vector2(8,0),3,Color("a6db83"))
		if s.shock>0: draw_line(at+Vector2(-8,-4),at+Vector2(-10,4),Color("ffdf80"),2,true)
