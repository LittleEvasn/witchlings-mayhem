extends Node2D
## One generated atlas; animation here is bounce/lean, not a claimed walk cycle.
var role := "normal"
var shot_windup := 0.0
var shot_direction := Vector2.RIGHT
var kind := 0
var hp := 1.0
var max_hp := 1.0
var radius := 18.0
var speed := 75.0
var flash := 0.0
var age := 0.0
var cooldown := 1.5
var windup := 0.0
var charge_time := 0.0
var charge_direction := Vector2.ZERO
var dead := false
var boss := false
var moving := false
var facing_left := false
var sprite: Sprite2D
var art_scale := 1.0
var seed_phase := 0.0

func setup(texture: Texture2D, actor_kind: int, is_boss := false) -> void:
	kind = actor_kind
	boss = is_boss
	seed_phase = randf() * TAU
	sprite = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	# Measured source bounds: the generated sheet is not a perfect equal-cell atlas.
	var regions := [Rect2(0,0,675,675),Rect2(690,120,564,545),Rect2(0,680,690,574),Rect2(690,680,564,574)]
	atlas.region = regions[kind]
	var cell: Vector2 = atlas.region.size
	sprite.texture = atlas
	# Atlas cells contain safe transparent padding. Actor feet align to origin.
	var target_size := 104.0 if kind == 0 else 78.0
	if kind == 3: target_size = 94.0
	if boss: target_size = 182.0
	art_scale = target_size / cell.x
	sprite.scale = Vector2.ONE * art_scale
	sprite.position.y = -target_size * 0.22
	add_child(sprite)
	z_index = int(position.y)

func animate(delta: float) -> void:
	age += delta
	flash = maxf(0, flash - delta)
	var frequency := 12.0 if moving else 3.0
	var bob := sin(age * frequency + seed_phase)
	var amount := 0.035 if moving else 0.012
	sprite.scale = Vector2(1.0 + bob * amount, 1.0 - bob * amount) * art_scale
	sprite.flip_h = facing_left
	sprite.rotation = bob * 0.045 if moving else 0.0
	sprite.modulate = Color(2.2,1.7,1.7) if flash > 0 else Color.WHITE
	z_index = int(position.y)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.36))
	draw_circle(Vector2(0,5),radius,Color(0.05,0.04,0.12,0.3))
	draw_set_transform(Vector2.ZERO)
	if kind == 0:
		draw_arc(Vector2.ZERO,22,0,TAU,36,Color(0.67,0.94,0.89,0.8),1.7,true)
	elif windup > 0:
		draw_arc(Vector2.ZERO,radius+8,0,TAU,36,Color("ff778e"),3,true)
		draw_line(Vector2.ZERO,charge_direction*95,Color(1,0.4,0.5,0.55),5,true)
	if shot_windup > 0:
		draw_arc(Vector2.ZERO,radius+8,0,TAU,32,Color("ffb174"),2.5,true)
		draw_line(Vector2.ZERO,shot_direction*170,Color(1,0.66,0.45,0.7),2,true)
	if hp < max_hp and kind != 0 and not boss:
		draw_line(Vector2(-16,-47),Vector2(16,-47),Color("242132"),4)
		draw_line(Vector2(-16,-47),Vector2(-16+32*hp/max_hp,-47),Color("ff9cae"),3)
