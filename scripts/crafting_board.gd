extends RefCounted
## Fixed acquisition / composition / action columns. Never changes recipe or craft rules.
const Spells = preload("res://scripts/spells.gd")
const P = preload("res://scripts/spell_progression.gd")

static func build(ui: CanvasLayer) -> void:
	var g: Node2D = ui.game
	ui.new_modal(Rect2(24,26,1392,846))
	ui.hud.visible = false
	ui.label(ui.modal,"마법 제작",Vector2(50,48),30,ui.TEXT)
	ui.label(ui.modal,"실패작의 마석으로 다음 실험을 준비하세요",Vector2(52,93),14,ui.MUTED,480)
	ui.label(ui.modal,"%d G"%g.economy.gold,Vector2(1210,57),28,ui.MINT)
	ui.button(ui.modal,"보유 유물 %d"%g.relics.owned.size(),Rect2(1006,58,184,38),ui.show_relics,false,16)
	ui.panel(ui.modal,Rect2(44,140,286,636),Color("111a29"))
	ui.panel(ui.modal,Rect2(342,140,634,636),Color("162231"))
	ui.panel(ui.modal,Rect2(990,140,386,636),Color("111a29"))
	ui.button(ui.modal,"구체 제작",Rect2(56,154,129,38),func():ui.craft_tab="craft";ui.show_shop(),ui.craft_tab!="fusion",16)
	ui.button(ui.modal,"합성 도감",Rect2(191,154,127,38),func():ui.craft_tab="fusion";ui.board_panel="fusion";ui.show_shop(),ui.craft_tab=="fusion",16)
	match ui.craft_tab:
		"fusion": fusion_catalog(ui)
		"research": research(ui)
		_: offers(ui)
	ui.label(ui.modal,"조합",Vector2(360,155),19,ui.TEXT)
	ui.label(ui.modal,"드래그로 이동 · 칸 가장자리에 놓으면 끼워 넣기",Vector2(425,159),12,ui.MUTED,526)
	ui.Board.row(ui,0,Vector2(354,184),true,614)
	ui.Board.row(ui,1,Vector2(354,309),true,614)
	ui.label(ui.modal,"가방",Vector2(360,439),21,ui.TEXT)
	var filters := [["all","전체"],["attack","공격"],["modifier","보조"],["connector","연결"]]
	for i in filters.size():
		var choice: Array = filters[i]
		ui.button(ui.modal,choice[1],Rect2(523+i*108,436,100,32),func():ui.bag_filter=choice[0];ui.bag_scroll=0;ui.show_shop(),ui.bag_filter==choice[0],14)
	ui.Board.bag(ui,Rect2(354,480,610,282),6)
	ui.label(ui.modal,"선택한 구체 · 효과와 강화",Vector2(1008,158),18,ui.TEXT)
	if ui.board_panel=="fusion": ui.Board.fusion(ui,false)
	else: ui.Board.detail(ui,true)
	var undo: Button = ui.button(ui.modal,"↶ 되돌리기",Rect2(354,795,145,44),g.undo_draft,false,16)
	undo.disabled = g.edit_history.is_empty()
	ui.button(ui.modal,"시험 발사",Rect2(510,795,174,44),g.start_trial,false,18).disabled = not g.valid_draft()
	ui.button(ui.modal,"준비 완료 →",Rect2(1162,795,198,48),g.launch_next_wave,true,21).disabled = not g.valid_draft()
	ui.label(ui.modal,"시간 제한 없음",Vector2(58,809),14,ui.MUTED)
	var note: String = g.workbench_message
	if note.is_empty(): note = "구체를 누르면 상세 확인 · 두 번 누르면 장착 · 우클릭으로 해제"
	ui.label(ui.modal,note,Vector2(354,845),12,ui.MUTED,610).max_lines_visible=1
	if not g.combat_rewards.pending.is_empty():
		ui.button(ui.modal,"남은 마법 선택 %d"%g.combat_rewards.pending.size(),Rect2(697,795,280,44),func():g.open_personal("reward"),false,15)

static func offers(ui: CanvasLayer) -> void:
	var g: Node2D = ui.game
	var revision: int = g.economy.revision
	for i in g.economy.offers.size():
		var offer: Dictionary = g.economy.offers[i]
		var y: float = 210.0+i*84
		ui.panel(ui.modal,Rect2(56,y,262,76),Color("202b3c"))
		if not offer.id.is_empty(): ui.Board.cell(ui,ui.modal,offer.id,Rect2(62,y+5,62,65))
		else: ui.label(ui.modal,"?",Vector2(80,y+10),28,ui.MINT)
		ui.label(ui.modal,"지정 제작" if i==0 else "무작위 제작안",Vector2(133,y+5),12,ui.MUTED,170)
		if i==0:
			ui.button(ui.modal,"구체 고르기",Rect2(133,y+25,172,22),func():ui.craft_tab="research";ui.show_shop(),false,13).disabled = g.economy.research_sold
		elif not offer.id.is_empty(): ui.label(ui.modal,Spells.definition(offer.id).name,Vector2(133,y+25),14,ui.TEXT,174).max_lines_visible=1
		var text := "제작 완료" if offer.sold else ("선택 필요" if offer.id.is_empty() else "제작 · %d G"%offer.price)
		var button: Button = ui.button(ui.modal,text,Rect2(133,y+48,172,23),func():g.buy_orb(i,revision),false,13)
		button.name = "CraftOffer%d"%i
		button.disabled = offer.sold or offer.id.is_empty() or g.economy.gold<offer.price
	ui.button(ui.modal,"제작안 재구성 · 5 G",Rect2(56,650,262,36),func():g.reroll_shop(revision),false,15).disabled = g.economy.gold<5
	ui.label(ui.modal,g.shop_message,Vector2(60,692),12,ui.MINT,252).max_lines_visible=2
	var forecast: Label = ui.label(ui.modal,g.Waves.forecast(g.wave+1),Vector2(60,732),12,ui.MUTED,252)
	forecast.name = "WaveForecast"
	forecast.max_lines_visible = 2

static func scrolling(ui: CanvasLayer, name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "CraftCatalog"
	scroll.position = Vector2(56,245)
	scroll.size = Vector2(262,510)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	scroll.set_deferred("scroll_vertical",int(ui.catalog_scroll.get(name,0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value):ui.catalog_scroll[name]=int(value))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",7)
	scroll.add_child(list)
	return list

static func fusion_catalog(ui: CanvasLayer) -> void:
	ui.label(ui.modal,"재료를 모아 완성하는 마법",Vector2(62,210),13,ui.MUTED,250)
	var list := scrolling(ui,"fusion")
	for id in P.FUSIONS:
		var recipe: Dictionary = P.FUSIONS[id]
		var owned := 0
		for parent in recipe.parents:
			if ui.game.economy.inventory.get(P.key(parent,3),0)>0: owned += 1
		var button: Button = ui.button(list,ui.Board.glyph(id)+"  "+recipe.name+"\n+3 재료 %d / 2"%owned,Rect2(0,0,250,68),func():ui.fusion_choice=id;ui.board_panel="fusion";ui.show_shop(),ui.fusion_choice==id,15)
		button.custom_minimum_size = Vector2(242,68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = recipe.desc

static func research(ui: CanvasLayer) -> void:
	ui.button(ui.modal,"← 제작안으로",Rect2(62,204,245,30),func():ui.craft_tab="craft";ui.show_shop(),false,14)
	var list := scrolling(ui,"research")
	var rev: int = ui.game.economy.revision
	for id in Spells.PARTS:
		if not ui.game.economy.can_stock(id): continue
		var button: Button = ui.button(list,ui.Board.glyph(id)+"  "+Spells.definition(id).name+" · %d G"%ui.game.Economy.PRICES[id],Rect2(0,0,250,40),func():ui.craft_tab="craft";ui.game.select_research(id,rev),false,14)
		button.custom_minimum_size = Vector2(242,40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = Spells.definition(id).desc
