extends Node2D
## Reuses the existing arena: original-scale stone, one central seal, outer foliage.
var bounds := Rect2()
var fixed := false
var texture := preload("res://assets/art/arena.png")

func configure(rect: Rect2, fixed_view := false) -> void:
	if bounds==rect and fixed==fixed_view and get_child_count()>0: return
	bounds=rect
	fixed=fixed_view
	for child in get_children():
		remove_child(child)
		child.queue_free()
	z_index=-100
	var original_scale := Vector2(1440,900)/texture.get_size()
	if fixed_view:
		var image := Sprite2D.new()
		image.texture=texture
		image.position=rect.get_center()
		image.scale=original_scale
		add_child(image)
		return
	# Mirror an unobstructed stone patch; UV repetition keeps the stone scale unchanged.
	var floor := Sprite2D.new()
	floor.texture=texture
	floor.centered=false
	floor.position=rect.position
	floor.scale=rect.size/texture.get_size()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code="""shader_type canvas_item;
uniform vec2 repeats;
uniform vec4 patch;
void fragment() {
 vec2 tile = abs(fract(UV * repeats) * 2.0 - 1.0);
 COLOR = texture(TEXTURE, patch.xy + tile * patch.zw);
}
"""
	material.shader=shader
	var patch := Rect2(200,170,300,190)
	material.set_shader_parameter("patch",Vector4(patch.position.x/texture.get_width(),patch.position.y/texture.get_height(),patch.size.x/texture.get_width(),patch.size.y/texture.get_height()))
	material.set_shader_parameter("repeats",rect.size/(patch.size*original_scale*2))
	floor.material=material
	add_child(floor)
	var seal := Sprite2D.new()
	seal.texture=texture
	seal.position=rect.get_center()
	seal.scale=original_scale
	var fade := ShaderMaterial.new()
	var mask := Shader.new()
	mask.code="""shader_type canvas_item;
void fragment() {
 COLOR = texture(TEXTURE, UV);
 COLOR.a *= 1.0 - smoothstep(0.72, 1.0, length((UV - vec2(0.5)) / vec2(0.37, 0.36)));
}
"""
	fade.shader=mask
	seal.material=fade
	add_child(seal)
	var border := NinePatchRect.new()
	border.texture=texture
	border.position=rect.position
	border.scale=original_scale
	border.size=rect.size/original_scale
	border.draw_center=false
	border.patch_margin_left=140
	border.patch_margin_right=140
	border.patch_margin_top=110
	border.patch_margin_bottom=110
	border.axis_stretch_horizontal=NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	border.axis_stretch_vertical=NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	border.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(border)
