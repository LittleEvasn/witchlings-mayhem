extends RefCounted
const H=preload("res://scripts/personal_window.gd")
const Look=preload("res://scripts/mayhem_skin.gd")
static func build(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	var rewards: RefCounted=g.combat_rewards
	if g.state!="combat" or not rewards.paused() or rewards.stage=="edit": return
	var root: Control=ui.new_modal(Rect2(205,250,1030,410))
	root.name="LevelRewardScreen"
	var shown_level: int=rewards.pending[0].level if rewards.stage=="choice" and not rewards.pending.is_empty() else rewards.level
	var chest: bool=rewards.stage=="choice" and not rewards.pending.is_empty() and rewards.pending[0].get("source","")=="chest"
	ui.label(root,"보상 상자" if chest else "레벨 %d"%shown_level,Vector2(237,270),29,ui.MINT)
	ui.label(root,"선택하는 동안 전투는 멈춰요",Vector2(237,333),16,ui.MUTED)
	if rewards.stage=="ready":
		ui.label(root,rewards.receipt,Vector2(237,389),26,ui.TEXT,960)
		ui.button(root,"조합 편집",Rect2(237,518,456,58),rewards.edit,false,23).name="RewardEdit"
		ui.button(root,"계속 →",Rect2(715,518,486,58),rewards.continue_combat,true,23).name="RewardContinue"
		return
	if rewards.pending.is_empty(): return
	var first: Dictionary=rewards.pending[0]
	var revision: int=rewards.revision
	var row:=HBoxContainer.new()
	row.name="LevelChoices"
	row.position=Vector2(237,376)
	row.size=Vector2(966,252)
	row.add_theme_constant_override("separation",12)
	root.add_child(row)
	for id in first.options:
		var choice: String=id
		var card:=PanelContainer.new()
		card.name="LevelCard_"+choice.replace(":","_")
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.custom_minimum_size=Vector2(310,252)
		card.add_theme_stylebox_override("panel",ui.box(ui.PANEL,ui.BORDER,1,16))
		row.add_child(card)
		var column:=VBoxContainer.new()
		column.add_theme_constant_override("separation",8)
		card.add_child(column)
		var title := ""
		var desc := ""
		var action := "획득"
		if choice.begins_with("fuse:"):
			var fusion_id:=choice.trim_prefix("fuse:")
			var d: Dictionary=g.Spells.definition(fusion_id)
			title=d.name
			desc=" + ".join(g.Spells.Progression.FUSIONS[fusion_id].parents.map(func(p):return g.Spells.definition(p).name+" +3"))+" → 완성"
			action="두 재료를 합성"
		elif choice.begins_with("relic:"):
			var d: Dictionary=g.Relics.definition(choice.trim_prefix("relic:"))
			title=d.name
			desc=d.desc
			action="유물 획득"
		elif choice=="gold":
			title="마석 주머니"
			desc="마석 %d 획득"%rewards.GOLD_REWARD
		elif choice=="heal":
			title="잠깐의 회복"
			desc="체력 %d 회복 · 체력이 가득 차면 마석 지급"%int(rewards.HEAL_REWARD)
		else:
			var old: String=g.economy.owned_token(choice)
			var output: String=choice if old.is_empty() else g.Spells.Progression.key(choice,g.Spells.Progression.rank(old)+1)
			var d: Dictionary=g.Spells.definition(output)
			title=d.name
			desc=d.desc.split("\n")[0]
			action="새 마법 획득" if old.is_empty() else "+%d → +%d 강화"%[g.Spells.Progression.rank(old),g.Spells.Progression.rank(output)]
		var emblem:=Control.new()
		emblem.custom_minimum_size=Vector2(0,42)
		emblem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.add_child(emblem)
		if g.Spells.has_part(choice): Look.icon(ui,emblem,choice,Rect2(116,0,42,42))
		elif choice.begins_with("fuse:"): Look.icon(ui,emblem,choice.trim_prefix("fuse:"),Rect2(116,0,42,42))
		elif choice.begins_with("relic:"):
			ui.Board.centered(ui,emblem,g.Relics.definition(choice.trim_prefix("relic:")).glyph,Rect2(116,0,42,42),28,ui.MINT)
		H.text(ui,column,title,22,ui.MINT)
		var label:=H.text(ui,column,desc,16,ui.TEXT)
		label.custom_minimum_size=Vector2(278,72)
		label.max_lines_visible=3
		label.tooltip_text=desc
		label.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var select:=H.button(ui,column,action,func():g.claim_spell_reward(first.id,choice,revision))
		select.name="Choose_"+choice.replace(":","_")
		select.focus_mode=Control.FOCUS_ALL
		if row.get_child_count()==1: ui.focus_front.call_deferred(weakref(select))
