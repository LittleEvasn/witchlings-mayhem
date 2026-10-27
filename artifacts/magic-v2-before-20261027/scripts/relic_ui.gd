extends RefCounted
## Uses the existing theme. Short cards, optional detailed tooltips, no new art layer.
static func card(ui: CanvasLayer, parent: Node, id: String, selectable := false) -> Control:
	var d: Dictionary = ui.game.Relics.definition(id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300,230 if selectable else 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",ui.box(Color("252b3e")))
	panel.tooltip_text = ui.game.relics.tooltip(id,ui.game.economy.gold)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	for item in [[d.name,23,ui.MINT],[d.desc,18,ui.TEXT],[d.note,14,ui.MUTED]]:
		var text := Label.new()
		text.text = item[0]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size",item[1])
		text.add_theme_color_override("font_color",item[2])
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(text)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	if selectable:
		var button := Button.new()
		button.name = "Choose_"+id
		button.text = "이 유물로 준비하기"
		button.custom_minimum_size.y = 44
		button.add_theme_stylebox_override("normal",ui.box(Color("344451"),ui.MINT))
		button.pressed.connect(func():ui.game.choose_reward(id))
		column.add_child(button)
	return panel

static func rewards(ui: CanvasLayer) -> void:
	ui.new_modal(Rect2(170,170,1100,550))
	ui.label(ui.modal,"웨이브 %d 완료 · 유물 제작" % ui.game.wave,Vector2(220,209),32,ui.TEXT)
	ui.label(ui.modal,"마석 회수 · 완료 보너스 20 G · 체력 +15\n이번 실험이 끝날 때까지 함께할 유물 하나를 고르세요.",Vector2(220,268),18,ui.MUTED)
	var row := HBoxContainer.new()
	row.position = Vector2(220,342)
	row.size = Vector2(1000,268)
	row.add_theme_constant_override("separation",20)
	ui.modal.add_child(row)
	for id in ui.game.reward_options: card(ui,row,id,true)
	if row.get_child_count()>0:
		row.get_child(0).find_child("Choose_*",true,false).grab_focus()
	ui.label(ui.modal,"자세한 효과는 카드에 마우스를 올려 확인 · 선택 후 제작대에서 준비",Vector2(220,654),16,ui.MUTED)

static func inventory(ui: CanvasLayer) -> void:
	ui.close_relics()
	ui.relic_resume = ui.game.state=="combat"
	if ui.relic_resume: ui.game.state="paused"
	var overlay := Control.new()
	ui.relic_popup = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.root.add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.025,0.035,0.065,.92)
	overlay.add_child(shade)
	ui.panel(overlay,Rect2(150,110,1140,680))
	ui.label(overlay,"이번 실험의 유물 · %d"%ui.game.relics.owned.size(),Vector2(180,137),28,ui.MINT)
	ui.label(overlay,"실험이 종료되면 마석으로 만든 유물도 사라집니다.",Vector2(180,185),16,ui.MUTED)
	ui.button(overlay,"닫기",Rect2(1140,135,118,40),ui.close_relics,false,18).grab_focus()
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(180,225)
	scroll.size=Vector2(1080,530)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns=3
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	scroll.add_child(grid)
	for id in ui.game.relics.owned: card(ui,grid,id)
	if ui.game.relics.owned.is_empty(): ui.label(overlay,"웨이브를 막아내고 유물을 제작하세요.",Vector2(180,260),21,ui.TEXT)
