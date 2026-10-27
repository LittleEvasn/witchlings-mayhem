extends RefCounted
## A dedicated encounter on the existing atlas. Tells freeze their targets before impact.
var game: Node2D
var clock := 0.0
var next_attack := 1.8
var index := 0
var phase := 1
var windup := 0.0
var dash_left := 0.0
var attack := ""
var direction := Vector2.RIGHT
var circles: Array = []
var fired := {"fan":0,"circles":0,"dash":0}
func _init(owner_game: Node2D) -> void: game=owner_game
func clear() -> void:
	clock=0; next_attack=1.8; index=0; phase=1; windup=0; dash_left=0; attack=""; circles.clear()
	fired={"fan":0,"circles":0,"dash":0}
func update(enemy: Node2D, delta: float) -> Vector2:
	clock+=delta
	var d: Vector2=enemy.position.direction_to(game.player.position)
	if phase==1 and enemy.hp<=enemy.max_hp*.5:
		phase=2
		game.announce("모범답안 폭주 · 예고를 보고 빈틈으로 이동!",3)
		game.play_sound("reward")
	if dash_left>0:
		dash_left=maxf(0,dash_left-delta)
		return direction*360
	if windup>0:
		windup=maxf(0,windup-delta)
		enemy.windup=windup if attack=="dash" else 0
		if windup<=0: _release(enemy)
		return Vector2.ZERO
	if clock>=next_attack and enemy.position.distance_to(game.player.position)<800:
		attack=["fan","circles","dash"][index%3]
		index+=1
		direction=d
		windup=1.15 if attack=="circles" else .95
		circles.clear()
		if attack=="circles":
			circles.append(game.player.position)
			if phase==2:
				for side in [-1,1]: circles.append((game.player.position+d.orthogonal()*135*side).clamp(game.player_bounds().position,game.player_bounds().end))
		enemy.charge_direction=direction
		enemy.windup=windup if attack=="dash" else 0
		return Vector2.ZERO
	return d*(66 if enemy.position.distance_to(game.player.position)>260 else 28)
func _release(enemy: Node2D) -> void:
	fired[attack]+=1
	match attack:
		"fan":
			# Aimed fan, not a closed ring: ample space on either side and below the cone.
			var count:=7 if phase==2 else 5
			for n in count:
				if game.hostile_shots.size()>=80: break
				game.hostile_shots.append({"pos":enemy.position,"vel":direction.rotated((n-(count-1)*.5)*.19)*190,"life":4.0})
		"circles":
			for point in circles.duplicate():
				game.ring(point,80,Color("ff9cae"),.45)
				if point.distance_to(game.player.position)<80+game.player.radius: game.hurt_player(18)
				if game.state!="combat": return
			circles.clear()
		"dash": dash_left=.65
	next_attack=clock+(2.0 if phase==2 else 2.8)
func tells(canvas: Node2D) -> void:
	if game.state!="combat" or not is_instance_valid(game.boss_ref) or game.boss_ref.dead: return
	var enemy: Node2D=game.boss_ref
	if windup<=0: return
	var color:=Color("ffb174") if attack=="fan" else Color("ff9cae")
	if attack=="circles":
		for point in circles:
			canvas.draw_circle(point,80,Color(color,.12))
			canvas.draw_arc(point,80,0,TAU,48,color,3,true)
			canvas.draw_arc(point,80*clampf(1-windup/1.15,0,1),0,TAU,40,Color(color,.6),2,true)
	elif attack=="fan":
		for side in [-1,1]: canvas.draw_line(enemy.position,enemy.position+direction.rotated(side*.65)*340,Color(color,.7),3,true)
