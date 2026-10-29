extends Node2D
## One generated atlas; animation here is bounce/lean, not a claimed walk cycle.
var batched_overlays := true
var overlay_active := false
var role := "normal"
var shot_windup := 0.0
var shot_direction := Vector2.RIGHT
var monster_id := ""
var monster_name := ""
var visual_height:=94.0
var jump_height:=0.0
var tactics: Dictionary={}
var base_sprite_y:=0.0
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
var recovery_left := 0.0
var visual_tint := Color.WHITE
var charge_direction := Vector2.ZERO
var dead := false
var boss := false
var moving := false
var facing_left := false
var sprite: Sprite2D
var art_scale := 1.0
var seed_phase := 0.0
var separation_left := 0.0
var separation_velocity := Vector2.ZERO

func setup(texture: Texture2D, actor_kind: int, is_boss := false) -> void:
	kind = actor_kind
	boss = is_boss
	seed_phase = randf() * TAU
	separation_left=fmod(seed_phase,.1)
	sprite = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	# Measured source bounds: the generated sheet is not a perfect equal-cell atlas.
	var regions := [Rect2(0,0,675,675),Rect2(690,120,564,545),Rect2(0,680,690,574),Rect2(690,680,564,574)]
	atlas.region = regions[kind]
	var cell: Vector2 = atlas.region.size
	sprite.texture = atlas
	# Atlas cells contain safe transparent padding. Actor feet align to origin.
	var target_size := 104.0 if kind == 0 else 94.0
	if kind == 3: target_size = 116.0
	if role=="sentinel": target_size=148.0; visual_tint=Color("dfb6f5")
	if role=="carrier": target_size=106.0; visual_tint=Color("ffe7a3")
	if boss: target_size = 182.0
	art_scale = target_size / cell.x
	sprite.scale = Vector2.ONE * art_scale
	sprite.position.y = -target_size * 0.22
	add_child(sprite)
	base_sprite_y=sprite.position.y
	if role in ["sentinel","carrier"]:
		var nameplate:=Label.new()
		nameplate.text="과팽창 · 밀치기 저항" if role=="sentinel" else "마법 재료 운반자"
		nameplate.position=Vector2(-82,-target_size*.70)
		nameplate.size=Vector2(164,26)
		nameplate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		nameplate.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var font:=SystemFont.new()
		font.font_names=PackedStringArray(["Malgun Gothic","Arial"])
		nameplate.add_theme_font_override("font",font)
		nameplate.add_theme_font_size_override("font_size",13)
		nameplate.add_theme_color_override("font_color",visual_tint)
		nameplate.add_theme_color_override("font_outline_color",Color("151d2b"))
		nameplate.add_theme_constant_override("outline_size",4)
		add_child(nameplate)
	z_index = 0

func animate(delta: float) -> void:
	age += delta
	flash = maxf(0, flash - delta)
	var frequency := 12.0 if moving else 3.0
	var bob := sin(age * frequency + seed_phase)
	var amount := 0.035 if moving else 0.012
	sprite.scale = Vector2(1.0 + bob * amount, 1.0 - bob * amount) * art_scale
	sprite.flip_h = facing_left
	sprite.rotation = bob * 0.045 if moving else 0.0
	sprite.position.y=base_sprite_y-jump_height
	sprite.modulate = Color(2.2,1.7,1.7) if flash > 0 else visual_tint
	z_index = 0
	var needs_overlay: bool=not batched_overlays or kind==0 or role in ["carrier","sentinel"] or windup>0 or shot_windup>0 or monster_id=="book"
	if needs_overlay or overlay_active: queue_redraw()
	overlay_active=needs_overlay

func _draw() -> void:
	if not batched_overlays:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.36))
		draw_circle(Vector2(0,5),radius,Color(0.05,0.04,0.12,0.3))
		draw_set_transform(Vector2.ZERO)
	if role in ["carrier","sentinel"]:
		draw_arc(Vector2.ZERO,radius+5,0,TAU,36,Color("ffe7a3") if role=="carrier" else Color("dfb6f5"),2,true)
	if kind == 0:
		draw_arc(Vector2.ZERO,22,0,TAU,36,Color(0.67,0.94,0.89,0.8),1.7,true)
	elif windup > 0:
		draw_arc(Vector2.ZERO,radius+8,0,TAU,36,Color("ff778e"),3,true)
		draw_line(Vector2.ZERO,charge_direction*95,Color(1,0.4,0.5,0.55),5,true)
	if monster_id=="candle" and windup>0:
		draw_arc(Vector2.ZERO,86,0,TAU,48,Color("ff778e"),3,true)
		draw_arc(Vector2.ZERO,86*(1-windup/1.1),0,TAU,32,Color("ffbf8f"),2,true)
	if monster_id=="book":
		var guard: Vector2=tactics.get("guard",Vector2.DOWN)
		var angle:=guard.angle()
		draw_arc(Vector2.ZERO,radius+10,angle-.95,angle+.95,16,Color("ffe7a3") if windup<=0 else Color("ff9cae"),4,true)
	if shot_windup > 0:
		draw_arc(Vector2.ZERO,radius+8,0,TAU,32,Color("ffb174"),2.5,true)
		draw_line(Vector2.ZERO,shot_direction*170,Color(1,0.66,0.45,0.7),2,true)
	if not batched_overlays and hp < max_hp and kind != 0 and not boss:
		var y: float=-78 if role=="sentinel" else -47
		draw_line(Vector2(-16,y),Vector2(16,y),Color("242132"),4)
		draw_line(Vector2(-16,y),Vector2(-16+32*hp/max_hp,y),Color("ff9cae"),3)
