extends RefCounted
## One distance ordering per casting tick; orb n uses rank n, independently of the cursor.
static func ranked(game: Node2D) -> Array:
	var targets: Array = []
	var view: Rect2 = game.visible_world_rect()
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.hp>0 and view.has_point(enemy.position):
			targets.append(enemy)
	targets.sort_custom(func(a,b):
		var da: float = game.player.position.distance_squared_to(a.position)
		var db: float = game.player.position.distance_squared_to(b.position)
		return a.get_instance_id()<b.get_instance_id() if da==db else da<db)
	return targets

static func target_for(targets: Array, orb_index: int) -> Node2D:
	# An earlier orb can kill a target instantly during the same casting tick.
	var living: Array=targets.filter(func(e):return is_instance_valid(e) and not e.dead and e.hp>0)
	if living.is_empty(): return null
	# With fewer enemies than orbs, reuse the last available rank rather than stop an orb.
	return living[clampi(orb_index,0,living.size()-1)]

static func point_for(game: Node2D, targets: Array, orb_index: int) -> Vector2:
	var target := target_for(targets,orb_index)
	return target.position if target!=null else game.player.position+game.last_move.normalized()*320.0
