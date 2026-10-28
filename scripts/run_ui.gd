extends RefCounted
const Content=preload("res://scripts/run_content.gd")

static func shell(ui: CanvasLayer, title: String, subtitle: String) -> void:
	ui.new_modal(Rect2(160,100,1120,700))
	ui.hud.visible=false
	ui.label(ui.modal,title,Vector2(208,136),36,ui.MINT)
	ui.label(ui.modal,subtitle,Vector2(210,194),18,ui.MUTED,1000)

static func intro(ui: CanvasLayer) -> void:
	ui.FrontFlow.intro(ui)

static func ending(ui: CanvasLayer) -> void:
	# Ending and result share one screen; no compulsory page between them.
	ui.FrontFlow.results(ui)

static func results(ui: CanvasLayer) -> void:
	ui.FrontFlow.results(ui)

static func records(ui: CanvasLayer) -> void:
	var data: Dictionary=ui.game.profile.data
	shell(ui,"실험 기록", "수습 %d회 · 실패 %d회 · %s" % [data.wins,data.losses,"루미의 멈춤 조건 단서 발견" if data.lumi_clue else "아직 사고 원인을 알아내지 못했어요"])
	ui.front_screen="records"
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(210,260)
	scroll.size=Vector2(1000,390)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var rows:=VBoxContainer.new()
	rows.custom_minimum_size.x=970
	rows.add_theme_constant_override("separation",16)
	scroll.add_child(rows)
	if data.records.is_empty():
		var empty:=Label.new(); empty.text="첫 실험의 결과를 기다리고 있어요."; rows.add_child(empty)
	for r in data.records:
		if not r is Dictionary: continue
		var line:=Label.new()
		line.text="%s · %s · 전투 %s · 처치 %d" % ["수습" if r.get("won",false) else "실패",ui.game.Economy.KITS.get(r.get("kit","sigil"),{}).get("name","실험"),Content.clock(r.get("combat",0)),r.get("kills",0)]
		rows.add_child(line)
	ui.button(ui.modal,"돌아가기",Rect2(850,696,360,60),ui.show_title,true).grab_focus()

static func settings(ui: CanvasLayer, from_title: bool) -> void:
	var g: Node2D=ui.game
	shell(ui,"소리 설정", "설정은 다음 실행에도 유지돼요. 실험 이어하기는 제작 시간에만 저장해요.")
	ui.front_screen="settings_title" if from_title else "settings_pause"
	ui.button(ui.modal,"효과음  "+("켜짐" if g.sound_enabled else "꺼짐"),Rect2(210,290,460,70),func():g.sound_enabled=not g.sound_enabled;g.save_settings();settings(ui,from_title),false,24)
	ui.button(ui.modal,"배경 음악 · 준비 중",Rect2(210,385,460,70),func():pass,false,24).disabled=true
	ui.label(ui.modal,"현재 배경 음악은 없어요.\n효과음은 플레이 중 M으로도 바꿀 수 있어요.",Vector2(210,500),20,ui.MUTED,950)
	ui.button(ui.modal,"돌아가기",Rect2(850,696,360,60),ui.show_title if from_title else ui.show_pause,true).grab_focus()
