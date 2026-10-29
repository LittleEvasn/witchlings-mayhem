extends Node2D
## The same existing shadows/health bars, grouped into shared canvas passes.
var game: Node2D
var shadows := false
func _draw() -> void:
	if game==null: return
	if shadows:
		for actor in [game.player]+game.enemies:
			if not is_instance_valid(actor) or actor.dead: continue
			draw_set_transform(actor.position,0,Vector2(1,.36))
			draw_circle(Vector2(0,5),actor.radius,Color(.05,.04,.12,.3))
		draw_set_transform(Vector2.ZERO)
	else:
		var backs:=PackedVector2Array()
		var health:=PackedVector2Array()
		for actor in game.enemies:
			if actor.dead or actor.boss or actor.hp>=actor.max_hp: continue
			var at: Vector2=actor.position+Vector2(-16,-maxf(47,actor.visual_height))
			backs.append(at)
			backs.append(at+Vector2(32,0))
			health.append(at)
			health.append(at+Vector2(32*maxf(0,actor.hp)/actor.max_hp,0))
		if not backs.is_empty():
			draw_multiline(backs,Color("242132"),4)
			draw_multiline(health,Color("ff9cae"),3)
