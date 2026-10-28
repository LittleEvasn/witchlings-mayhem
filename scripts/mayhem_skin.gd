extends RefCounted
## Shared rounded UI presentation. No gameplay state or economy lives here.
const FONT = preload("res://assets/fonts/Jua-Regular.ttf")
const P = preload("res://scripts/spell_progression.gd")
const INK := Color("49345f")
const MUTED := Color("887893")
const PURPLE := Color("8561bd")
const LILAC := Color("eee6fa")
const PAPER := Color("fffcf5")
const MINT := Color("caf2df")
const PINK := Color("f6c9dd")
const LINE := Color("d8c8e5")
static var icons: Dictionary = {}

static func style(fill: Color, edge := LINE, radius := 22, depth := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.corner_detail=10
	s.content_margin_left=14
	s.content_margin_right=14
	s.content_margin_top=5
	s.content_margin_bottom=5
	if depth>0:
		s.shadow_color=Color(Color("563b73"),.15)
		s.shadow_size=2
		s.shadow_offset=Vector2(0,depth)
	return s

static func card(ui: CanvasLayer, parent: Node, rect: Rect2, fill := PAPER, radius := 26, depth := 4) -> Panel:
	var p: Panel=ui.panel(parent,rect,fill)
	p.add_theme_stylebox_override("panel",style(fill,LINE,radius,depth))
	return p

static func text(ui: CanvasLayer, parent: Node, content: String, at: Vector2, size := 20, color := INK, width := 0.0, display := false) -> Label:
	var l: Label=ui.label(parent,content,at,size,color,width)
	if display: l.add_theme_font_override("font",FONT)
	return l

static func button(ui: CanvasLayer, parent: Node, content: String, rect: Rect2, callback: Callable, primary := false, size := 20) -> Button:
	var b: Button=ui.button(parent,content,rect,callback,primary,size)
	decorate_button(b,primary)
	return b

static func decorate_button(b: Button, primary := false) -> void:
	b.set_meta("rounded_button",true)
	b.add_theme_font_override("font",FONT)
	var base: Color=PURPLE if primary else PAPER
	var edge: Color=INK if primary else LINE
	b.add_theme_stylebox_override("normal",style(base,edge,22,4))
	b.add_theme_stylebox_override("hover",style(base.lightened(.07) if primary else LILAC,PURPLE,22,5))
	b.add_theme_stylebox_override("pressed",style(PURPLE.darkened(.12) if primary else Color("dac9ee"),INK,22))
	b.add_theme_stylebox_override("disabled",style(Color("e9e2ed"),Color("ded5e4"),22))
	var focus := style(Color(1,1,1,0),Color("efb34d"),22)
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		b.add_theme_color_override(state,PAPER if primary else INK)
	b.add_theme_color_override("font_disabled_color",Color("a99eae"))

static func chip(ui: CanvasLayer, parent: Node, content: String, rect: Rect2, fill := LILAC, color := PURPLE) -> Panel:
	var p := card(ui,parent,rect,fill,30,0)
	p.add_theme_stylebox_override("panel",style(fill,fill,30))
	var l := text(ui,p,content,Vector2(8,1),16,color,rect.size.x-16,true)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y=rect.size.y-2
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return p

static func icon(ui: CanvasLayer, parent: Node, id: String, rect: Rect2) -> Control:
	var frame := Control.new()
	frame.name="SpellIcon"
	frame.position=rect.position
	frame.size=rect.size
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var base: String=P.base_id(id)
	if P.is_fused(base):
		var parents: Array=P.FUSIONS[base].parents
		add_icon(frame,parents[0],Rect2(Vector2.ZERO,rect.size*.78))
		add_icon(frame,parents[1],Rect2(rect.size*.34,rect.size*.66))
	else: add_icon(frame,base,Rect2(Vector2.ZERO,rect.size))
	return frame

static func add_icon(parent: Control, id: String, rect: Rect2) -> void:
	if not icons.has(id):
		var path := "res://assets/ui/spells/"+id+".svg"
		if ResourceLoader.exists(path): icons[id]=load(path)
		else: return
	var pic := TextureRect.new()
	pic.texture=icons[id]
	pic.position=rect.position
	pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	pic.size=rect.size
	pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)
	# Texture minimum-size invalidation is deferred; re-apply the requested UI size afterwards.
	pic.set_deferred("size",rect.size)

static func backdrop(ui: CanvasLayer) -> void:
	ui.modal.set_meta("rounded_ui",true)
	var bg := TextureRect.new()
	bg.name="MenuBackdrop"
	bg.texture=load("res://assets/ui/menu_backdrop.svg")
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.position=-ui.root.position
	bg.size=ui.get_viewport().get_visible_rect().size
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.modal.add_child(bg)

static func bounded(l: Label, lines := 1) -> Label:
	l.max_lines_visible=lines
	l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text=l.text
	return l

static func restyle(ui: CanvasLayer, node: Node) -> void:
	# Compact trial shares the same palette and symbols without widening over the targets.
	if node is Button and not node.get_meta("rounded_button",false):
		var primary: bool=node.get_theme_color("font_color")==ui.INK
		decorate_button(node,primary)
	elif node is Panel:
		node.add_theme_stylebox_override("panel",style(PAPER,LINE,24,0))
	elif node is Label and node!=ui.trial_stats_label:
		var color: Color=node.get_theme_color("font_color")
		node.add_theme_color_override("font_color",MUTED if color==ui.MUTED else INK)
		if node.get_theme_font_size("font_size")>=18: node.add_theme_font_override("font",FONT)
	for child in node.get_children(): restyle(ui,child)
