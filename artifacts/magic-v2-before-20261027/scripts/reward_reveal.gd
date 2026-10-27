extends RefCounted
## A brief, non-modal reward stage. Inventory remains in its separate side drawer.
const Helpers = preload("res://scripts/personal_window.gd")

static func note(game: Node2D, id: String) -> String:
	var progression=game.Spells.Progression
	var kind: String=game.Spells.definition(id).kind
	if kind in ["attack","modifier"]:
		for token in game.economy.inventory:
			if game.economy.inventory[token]>0 and progression.base_id(token)==id and progression.rank(token)<4:
				return "같은 구체 보유 · 합치면 +%d"%progression.merge_rank(token,id)
	if kind=="connector": return "공격 사이에 넣어 후속 주문 연결"
	if kind=="modifier": return "오른쪽 공격들을 바꾸는 보조 구체"
	return "새 공격 주문" if game.economy.inventory.get(id,0)==0 else "다른 오브에도 장착할 수 있어"

static func build(ui: CanvasLayer) -> void:
	ui.close_personal_visual()
	var g: Node2D=ui.game
	g.combat_rewards.refresh_options()
	var panel:=PanelContainer.new()
	panel.name="SpellRewardStage"
	ui.root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left=-480
	panel.offset_right=480
	panel.offset_top=-400
	panel.offset_bottom=-105
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",ui.box(Color(.07,.09,.14,.96),ui.MINT.darkened(.45),1,20))
	ui.personal_root=panel
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	var header:=HBoxContainer.new()
	column.add_child(header)
	Helpers.text(ui,header,"새 주문의 재료를 발견했어!",23,ui.MINT).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Helpers.button(ui,header,"나중에 · Esc",g.close_personal).size_flags_horizontal=Control.SIZE_SHRINK_END
	var caption:=Helpers.text(ui,column,"하나를 골라 이번 조합을 바꿔봐 · 선택 중에도 이동/회피/자동 시전",13,ui.MUTED)
	caption.name="RewardCaption"
	var row:=HBoxContainer.new()
	row.name="RewardChoices"
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	if g.combat_rewards.pending.is_empty():
		Helpers.text(ui,row,"운반자를 잡고 재료를 회수하면 마법을 먼저 고를 수 있어.\n놓친 선택권은 조건을 채운 웨이브가 끝날 때 받을 수 있어.",17,ui.MUTED)
		return
	var reward: Dictionary=g.combat_rewards.pending[0]
	var revision: int=g.combat_rewards.revision
	for id in reward.options:
		var part: String=id
		var d: Dictionary=g.Spells.definition(part)
		var card:=PanelContainer.new()
		card.name="RewardCard_"+part
		card.custom_minimum_size=Vector2(0,160)
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",ui.box(Color("1b2636"),d.color.darkened(.25),2,14))
		row.add_child(card)
		var inside:=VBoxContainer.new()
		inside.add_theme_constant_override("separation",5)
		card.add_child(inside)
		Helpers.text(ui,inside,ui.Board.glyph(part)+"  "+d.name,22,d.color)
		var summary: String=d.desc.split("\n")[0]
		var desc:=Helpers.text(ui,inside,summary,15,ui.TEXT)
		desc.custom_minimum_size=Vector2(260,42)
		desc.max_lines_visible=2
		desc.tooltip_text=d.desc
		Helpers.text(ui,inside,note(g,part),13,ui.MINT)
		var select:=Helpers.button(ui,inside,"이 재료 받기",func():g.claim_spell_reward(reward.id,part,revision))
		select.name="RewardChoose_"+part
		card.modulate=Color(1.35,1.35,1.35)
		card.create_tween().tween_property(card,"modulate",Color.WHITE,.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if reward.options.is_empty():
		Helpers.text(ui,row,"모든 구체를 한도까지 가지고 있어.",18,ui.MUTED)
		Helpers.button(ui,row,"마석 18G로 회수",func():g.claim_spell_reward(reward.id,"",revision))

static func receipt(ui: CanvasLayer, id: String) -> void:
	ui.close_reward_receipt()
	var panel:=PanelContainer.new()
	panel.name="SpellAcquired"
	ui.root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left=-230
	panel.offset_right=230
	panel.offset_top=175
	panel.offset_bottom=268
	panel.add_theme_stylebox_override("panel",ui.box(Color("202f3c"),ui.MINT,2,16))
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.reward_receipt=panel
	var list:=VBoxContainer.new()
	panel.add_child(list)
	var title: String="마석 18G 회수" if id.is_empty() else ui.Board.glyph(id)+"  "+ui.game.Spells.definition(id).name+" 획득!"
	Helpers.text(ui,list,title,23,ui.MINT)
	Helpers.button(ui,list,"Tab · 조합을 바꿔볼까?",ui.game.open_editor)
	var tween:=panel.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(panel,"modulate:a",0.0,.25)
	tween.tween_callback(func():
		if ui.reward_receipt==panel: ui.close_reward_receipt())
