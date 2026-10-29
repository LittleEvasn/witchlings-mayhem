extends RefCounted
## Live compact inventory. Preparation keeps its existing crafting workbench.
const Compact=preload("res://scripts/compact_inventory.gd")

static func text(ui: CanvasLayer, parent: Node, value: String, font_size := 16, color := Color("f5f0e6")) -> Label:
	var l:=Label.new()
	l.text=value
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func button(ui: CanvasLayer, parent: Node, value: String, action: Callable) -> Button:
	var b:=Button.new()
	b.text=value
	b.custom_minimum_size=Vector2(0,34)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal",ui.box(ui.PANEL,ui.BORDER,1,9))
	b.add_theme_stylebox_override("hover",ui.box(Color("303a50"),ui.MINT,1,9))
	b.add_theme_font_size_override("font_size",15)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func build(ui: CanvasLayer) -> void:
	ui.close_personal_visual()
	var g: Node2D=ui.game
	g.personal_tab="inventory"
	ui.personal_root=Compact.build(ui,ui.root)
	ui.update_hud()
