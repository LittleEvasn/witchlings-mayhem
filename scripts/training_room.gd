extends RefCounted
const S=preload("res://scripts/spells.gd")

static func build(ui: CanvasLayer) -> void:
	var g: Node2D=ui.game
	ui.close_modal()
	ui.modal=Control.new();ui.modal.name="TrainingEditor"
	ui.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.modal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.root.add_child(ui.modal);ui.hud.visible=false;g.player.visible=true
	ui.label(ui.modal,"마법 훈련장",Vector2(32,16),26,ui.MINT)
	ui.label(ui.modal,"WASD 이동 · Space 회피 · 구체를 드래그 / 우클릭 해제 · Tab 편집창 숨기기",Vector2(32,56),14,ui.TEXT,1000)
	ui.button(ui.modal,"타이틀로 · Esc",Rect2(1130,16,278,43),g.end_trial,false,17).name="TrainingExit"
	ui.trial_stats_label=ui.label(ui.modal,"",Vector2(32,100),18,ui.MINT,990)
	ui.button(ui.modal,"피해·상태 초기화",Rect2(32,138,210,38),func():g.reset_training(),false,15).name="TrainingReset"
	ui.button(ui.modal,"조합 모두 비우기",Rect2(252,138,210,38),func():g.reset_training(true),false,15).name="TrainingClear"
	ui.button(ui.modal,"AI 자동 플레이 중단" if g.ai_running else "AI 자동 플레이 · 60초",Rect2(474,138,230,38),g.stop_ai_autoplay if g.ai_running else g.start_ai_autoplay,false,15).name="TrainingAiAutoplay"
	ui.label(ui.modal,g.ai_status(),Vector2(32,187),15,ui.MINT,1000).name="AiAutoplayStatus"
	ui.panel(ui.modal,Rect2(1074,82,342,777),ui.INK)
	ui.label(ui.modal,"모든 마법 · 자유 장착",Vector2(1090,94),19,ui.MINT)
	var picker:=OptionButton.new();picker.name="TrainingRank"
	picker.position=Vector2(1090,130);picker.size=Vector2(310,35)
	for rank in 4: picker.add_item("기본 구체" if rank==0 else "전체 기본 구체 +%d"%rank)
	picker.select(g.training_rank);picker.item_selected.connect(g.set_training_rank)
	ui.modal.add_child(picker)
	var tabs:=HBoxContainer.new();tabs.position=Vector2(1090,175);tabs.size=Vector2(310,32)
	ui.modal.add_child(tabs)
	for option in [["attack","공격"],["modifier","보조·원소"],["connector","연결"],["fusion","합성"]]:
		var key: String=option[0]
		var button:=Button.new();button.text=option[1];button.toggle_mode=true;button.button_pressed=g.training_filter==key
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():g.training_filter=key;build(ui));tabs.add_child(button)
	var scroll:=ScrollContainer.new();scroll.name="TrainingCatalog"
	scroll.position=Vector2(1090,220);scroll.size=Vector2(310,621)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;ui.modal.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=3
	grid.add_theme_constant_override("h_separation",5);grid.add_theme_constant_override("v_separation",5);scroll.add_child(grid)
	var ids: Array=S.Progression.FUSIONS.keys() if g.training_filter=="fusion" else S.PARTS.keys().filter(func(id):return S.PARTS[id].kind==g.training_filter)
	for base in ids:
		var id: String=base if g.training_filter=="fusion" else S.Progression.key(base,g.training_rank)
		var cell: Control=ui.Board.cell(ui,grid,id,Rect2(0,0,96,82),-1,-1,true)
		cell.custom_minimum_size=Vector2(96,82)
	ui.panel(ui.modal,Rect2(24,588,1024,272),ui.INK)
	for orb in 4:
		ui.label(ui.modal,"오브 %d"%(orb+1),Vector2(38,603+orb*61),17,ui.MINT)
		for slot in 8:
			ui.Board.cell(ui,ui.modal,g.orb_drafts[orb][slot],Rect2(132+slot*72,594+orb*61,66,56),orb,slot,false,true)
	var selected: String=ui.selected_item
	if S.has_part(selected):
		var info:=S.definition(selected)
		ui.label(ui.modal,info.name,Vector2(736,603),18,info.color,290)
		ui.label(ui.modal,info.desc,Vector2(736,641),13,ui.TEXT,290).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else: ui.label(ui.modal,"구체 위에 마우스를 올리면\n효과를 볼 수 있어요.\n\n편집 즉시 시험 발사에 반영돼요.\n허수아비는 반격·사망·보상 없음.",Vector2(736,606),15,ui.MUTED,290)
	ui.update_trial_stats()
