extends RefCounted
## Contextual actions in the shared preparation/trial drawer; crafting uses existing quotes.
const Spells=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")

static func item(ui: CanvasLayer, x: float, crafting: bool) -> void:
	var g: Node2D=ui.game
	var id: String=ui.selected_item
	if id.is_empty() or not Spells.has_part(id):
		ui.label(ui.modal,"구체를 골라보세요",Vector2(x+24,620),21,ui.TEXT)
		ui.label(ui.modal,"장착한 구체나 가방을 누르면 효과를 볼 수 있어요.",Vector2(x+24,659),14,ui.MUTED,468)
		return
	var part: Dictionary=Spells.definition(id)
	ui.label(ui.modal,ui.Board.glyph(id)+"  "+part.name,Vector2(x+24,601),19,part.color,305).max_lines_visible=1
	ui.button(ui.modal,"오브 %d에 끼우기"%(g.active_orb+1),Rect2(x+334,598,164,30),func():g.board_quick_equip(id),true,13).disabled=g.remaining_part(id)<=0
	var explanation: String=part.desc
	if part.kind=="modifier": explanation=Spells.modifier_token_text(id)
	var label: Label=ui.label(ui.modal,explanation,Vector2(x+24,638),13,ui.TEXT,470)
	label.max_lines_visible=2
	label.tooltip_text=part.desc+("\n"+Spells.MODIFIER_NOTES.get(P.base_id(id),"완성 보조 · 오른쪽 공격에 적용") if part.kind=="modifier" else "")
	if not crafting or not Spells.upgradeable(id):
		ui.label(ui.modal,"시험에서는 조합만 편집해요. 강화는 준비대로 돌아가서." if not crafting else "완성형 합성 구체 · 추가 강화 없음",Vector2(x+24,708),14,ui.MUTED,468)
		return
	var options:=OptionButton.new()
	options.name="ForgeMaterial"
	options.position=Vector2(x+24,679)
	options.size=Vector2(474,29)
	options.add_item("합칠 재료 자동 선택 · 낮은 강화부터")
	options.set_item_metadata(0,"")
	for level in 4:
		var token: String=P.key(P.base_id(id),level)
		var count: int=g.economy.inventory.get(token,0)-(1 if token==id else 0)
		if count<=0: continue
		var equipped: int=g.orb_drafts[0].count(token)+g.orb_drafts[1].count(token)
		options.add_item("%s · %d개 / 장착 %d개"%[Spells.definition(token).name,count,equipped])
		var index:=options.item_count-1
		options.set_item_metadata(index,token)
		if ui.merge_material==token: options.select(index)
	if options.selected==0: ui.merge_material=""
	ui.modal.add_child(options)
	options.item_selected.connect(func(index):ui.merge_material=options.get_item_metadata(index);ui.refresh_workbench.call_deferred())
	var paid: Dictionary=g.economy.craft_quote("upgrade",id)
	var merge: Dictionary=g.economy.craft_quote("merge",id,ui.merge_material)
	var preview: String=merge.error
	if merge.ok: preview="합치기: %s + %s → %s"%[Spells.definition(merge.consumed[0]).name,Spells.definition(merge.consumed[1]).name,Spells.definition(merge.output).name]
	var material: Label=ui.label(ui.modal,preview,Vector2(x+24,712),11,ui.MINT if merge.ok else ui.MUTED,472)
	material.name="ForgePreview"
	material.max_lines_visible=1
	material.tooltip_text=preview
	var effect: String=ui.Board.effect_preview(ui,id,merge if merge.ok else paid,true).replace("\n"," · ")
	var forecast: Label=ui.label(ui.modal,effect,Vector2(x+24,731),12,ui.MINT,472)
	forecast.name="ForgeEffectPreview"
	forecast.max_lines_visible=1
	forecast.tooltip_text=effect
	var revision: int=g.economy.revision
	var cost: int=P.paid_cost(g.Economy.PRICES[P.base_id(id)],P.rank(id))
	var b: Button=ui.button(ui.modal,"최대 강화 +3" if P.rank(id)>=3 else "마석 강화 · %d"%cost,Rect2(x+24,756,230,32),func():g.craft_spell("upgrade",id,"",revision),false,14)
	b.name="ForgePaid"
	b.disabled=not paid.ok
	b.tooltip_text=paid.error if not paid.ok else ui.Board.effect_preview(ui,id,paid)
	b=ui.button(ui.modal,"구체 합치기 · 무료",Rect2(x+266,756,232,32),func():g.craft_spell("merge",id,ui.merge_material,revision),false,14)
	b.name="ForgeMerge"
	b.disabled=not merge.ok
	b.tooltip_text=preview

static func fusion(ui: CanvasLayer, x: float) -> void:
	var g: Node2D=ui.game
	var id: String=ui.fusion_choice if not ui.fusion_choice.is_empty() else "storm_spear"
	var recipe: Dictionary=P.FUSIONS[id]
	var a: String=P.key(recipe.parents[0],3)
	var b: String=P.key(recipe.parents[1],3)
	ui.label(ui.modal,recipe.name+" · "+{"attack":"공격","modifier":"보조","connector":"연결"}[P.fusion_kind(id)],Vector2(x+24,601),20,recipe.color,470)
	for i in 2:
		var token: String=a if i==0 else b
		ui.Board.cell(ui,ui.modal,token,Rect2(x+24+i*254,636,92,64))
		ui.label(ui.modal,"보유 %d / 1"%g.economy.inventory.get(token,0),Vector2(x+126+i*254,655),13,ui.MINT if g.economy.inventory.get(token,0)>0 else ui.PINK,110)
	var q: Dictionary=g.economy.craft_quote("fuse",a,b)
	var revision: int=g.economy.revision
	var desc: Label=ui.label(ui.modal,recipe.desc,Vector2(x+24,710),13,ui.TEXT,472)
	desc.max_lines_visible=2
	desc.tooltip_text=q.error if not q.ok else "재료 두 개를 소비해 완성 구체 한 개를 얻어요. 장착 중인 실물도 소비돼요."
	var button: Button=ui.button(ui.modal,"합성하기 · 12 마석",Rect2(x+24,754,474,34),func():g.craft_spell("fuse",a,b,revision),true,16)
	button.name="ForgeFusion"
	button.disabled=not q.ok
	button.tooltip_text=desc.tooltip_text
