extends Node2D
## Cheap, bounded vector VFX. Combat hit shapes match the visible rings/bolts.
var game: Node2D

func _draw() -> void:
	for zone in game.magic.zones:
		var pos: Vector2 = zone.pos
		var radius: float = zone.radius
		var c := Color("c6a3ff") if zone.kind == "vortex" else Color("b8ed9a")
		var alpha := minf(1,zone.life/0.4)
		draw_circle(pos,radius,Color(c,0.08*alpha))
		draw_arc(pos,radius,0,TAU,48,Color(c,0.55*alpha),1.8,true)
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
		var c: Color = game.Spells.PARTS[p.attack].color
		var pos: Vector2 = p.pos
		if p.attack == "boomerang":
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
