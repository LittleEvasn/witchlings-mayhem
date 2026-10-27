extends Node
const Runner = preload("res://scripts/measurement_runner.gd")
const PRESETS := {
	"정원 성장":["giant","graft","vortex"],
	"큰 관통 한 발":["pierce","charge","bolt"],
	"각인 연사":["fan","sigil","bolt"],
	"서리와 낙뢰 파쇄":["frost","impact","shatter","thunder"],
	"위성 각인":["sigil","satellite"],
	"이동 후 소용돌이":["ember_path","impact","vortex"],
	"유도·갈래·꽃폭탄 → 소용돌이":["seek","fan","bloom","impact","vortex"],
	"갈래·메아리·꽃폭탄 → 소용돌이":["fan","echo","bloom","impact","vortex"],
	"메아리·별빛탄":["echo","bolt"],
	"거대·꽃폭탄":["giant","bloom"],
	"관통·별빛탄":["pierce","bolt"],
	"관통·달빛 부메랑":["pierce","boomerang"],
	"관통·소용돌이":["pierce","vortex"],
	"관통·가시꽃":["pierce","thorn"],
	"소용돌이 단독":["vortex"],
	"가시꽃 단독":["thorn"]
}
var game: Node2D
var runner: RefCounted
var screen: Control
var parts: Array = ["seek","fan","bloom","impact","vortex"]
var scenario: OptionButton
var aim_choice: OptionButton
var preset: OptionButton
var recipe_buttons: Array = []
var config_buttons: Array = []
var run_button: Button
var all_button: Button
var stop_button: Button
var info: Label
var progress: Label
var readout: RichTextLabel
var queue: Array = []
var reports: Array = []
var baseline: Dictionary = {}
var accumulator := 0.0
var refresh_clock := 0.0
var is_running := false
var batch_parts: Array = []
var batch_aim := "nearest"
var export_stem := ""

func _ready() -> void:
	var container := TextureRect.new()
	container.position = Vector2(18,260)
	container.size = Vector2(860,480)
	container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.stretch_mode = TextureRect.STRETCH_SCALE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	container.texture = viewport.get_texture()
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.sound_enabled = false
	game.ui.hide()
	runner = Runner.new(game)
	var layer := CanvasLayer.new()
	add_child(layer)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = game.ui.root.theme
	layer.add_child(screen)
	var ui = game.ui
	ui.panel(screen,Rect2(18,16,1404,226),ui.INK)
	ui.label(screen,"마법 측정실",Vector2(38,27),28,ui.MINT)
	ui.label(screen,"같은 조건으로 쏘고, 효과별 실제 기여도를 비교해봐",Vector2(250,35),17,ui.MUTED)
	ui.button(screen,"시작 화면",Rect2(1240,26,160,40),func():get_tree().change_scene_to_file("res://scenes/main.tscn"),false,17)
	scenario = option(Vector2(38,89),245,Runner.SCENARIOS.values().map(func(c):return c.name))
	aim_choice = option(Vector2(295,89),230,["매 시전 가까운 적 조준","오른쪽 고정 조준","특화 경로·조준"])
	preset = option(Vector2(537,89),308,PRESETS.keys())
	preset.item_selected.connect(func(index):parts=PRESETS.values()[index].duplicate(); refresh_recipe())
	run_button = ui.button(screen,"선택 환경 측정",Rect2(858,89,174,40),func():start(false),true,16)
	all_button = ui.button(screen,"7개 환경 비교",Rect2(1044,89,174,40),func():start(true),false,16)
	stop_button = ui.button(screen,"측정 중단",Rect2(1230,89,170,40),cancel,false,16)
	for i in 6:
		var index := i
		var b = ui.button(screen,"",Rect2(38+i*225,150,214,44),func():
			if index<parts.size(): parts.remove_at(index); refresh_recipe()
		,false,16)
		recipe_buttons.append(b)
		config_buttons.append(b)
	info = ui.label(screen,"",Vector2(38,207),14,ui.MUTED,1360)
	ui.panel(screen,Rect2(18,742,860,142),ui.INK)
	var i := 0
	for id in game.Spells.PARTS:
		var orb: String = id
		var b = ui.button(screen,game.Spells.definition(id).name,Rect2(24+(i%6)*142,747+int(i/6)*33,136,30),func():
			if parts.size()<6: parts.append(orb); refresh_recipe()
		,false,14)
		config_buttons.append(b)
		i += 1
	ui.panel(screen,Rect2(900,260,522,620),ui.INK)
	progress = ui.label(screen,"구체 클릭으로 추가 · 위 슬롯 클릭으로 제거",Vector2(920,277),16,ui.MINT,482)
	readout = RichTextLabel.new()
	readout.position = Vector2(920,315)
	readout.size = Vector2(480,495)
	readout.bbcode_enabled = true
	readout.add_theme_font_size_override("normal_font_size",16)
	readout.add_theme_color_override("default_color",ui.TEXT)
	screen.add_child(readout)
	ui.button(screen,"최근 결과 → A",Rect2(920,830,166,34),func():
		if not reports.is_empty(): baseline=reports[-1].duplicate(true); show_reports()
	,false,15)
	ui.button(screen,"JSON·CSV 저장",Rect2(1098,830,302,34),save,false,15)
	scenario.item_selected.connect(func(_index):refresh_recipe())
	refresh_recipe()
	show_reports()

func option(at: Vector2, width: float, choices: Array) -> OptionButton:
	var choice := OptionButton.new()
	choice.position = at
	choice.size = Vector2(width,40)
	choice.add_theme_font_size_override("font_size",16)
	for value in choices: choice.add_item(str(value))
	screen.add_child(choice)
	return choice

func refresh_recipe() -> void:
	for i in 6:
		recipe_buttons[i].text = "%d  %s"%[i+1,game.Spells.definition(parts[i]).name] if i<parts.size() else "%d  빈 칸"%[i+1]
	var compiled: Dictionary = game.Spells.compile(parts)
	var cost := 0
	for id in parts: cost += int(game.Economy.investment_cost(id))
	var hint: String = Runner.SCENARIOS.values()[scenario.selected].hint
	info.text = ("15초 / 시드 731 / 위력·공속 ×1 / 정가 %d G · 추가 구매 %d G · "%[cost,game.Economy.purchase_cost(parts)]+"연타 꾸러미 기준 / "+hint) if compiled.ok else compiled.error
	run_button.disabled = is_running or not compiled.ok
	all_button.disabled = is_running or not compiled.ok
	stop_button.disabled = not is_running
	for b in config_buttons: b.disabled = is_running
	scenario.disabled = is_running
	aim_choice.disabled = is_running
	preset.disabled = is_running

func start(all_scenarios: bool) -> void:
	if is_running: return
	if not game.Spells.compile(parts).ok: return
	batch_parts = parts.duplicate()
	batch_aim = ["nearest","fixed","build"][aim_choice.selected]
	queue = Runner.SCENARIOS.keys().duplicate() if all_scenarios else [Runner.SCENARIOS.keys()[scenario.selected]]
	is_running = true
	refresh_recipe()
	start_next()

func start_next() -> void:
	if queue.is_empty():
		is_running = false
		runner.stop()
		refresh_recipe()
		save()
		return
	var id: String = queue.pop_front()
	runner.begin(batch_parts,id,731,batch_aim)
	game.ui.hide()
	accumulator = 0

func cancel() -> void:
	queue.clear()
	is_running = false
	runner.stop()
	progress.text = "중단됨 · 미완료 측정은 결과에서 제외"
	refresh_recipe()

func _process(delta: float) -> void:
	if not is_running: return
	accumulator += minf(delta,0.1)
	while accumulator >= Runner.STEP and runner.active:
		accumulator -= Runner.STEP
		runner.step()
	game.visuals.queue_redraw()
	refresh_clock += delta
	if refresh_clock>=0.1:
		refresh_clock = 0
		progress.text = "%s · %.1f / 15초 · 피해 %.0f · 처치 %d"%[Runner.SCENARIOS[runner.settings.scenario].name,runner.observer.time,runner.observer.totals.get("damage_effective",0),runner.observer.totals.get("kills",0)]
	if not runner.active:
		reports.append(runner.report())
		show_reports()
		start_next()

func show_reports() -> void:
	var notes := "[b]측정 기준[/b]\n접촉률 = 적에 닿은 탄 / 생성된 탄.\n폭발로 맞은 적은 피해 횟수에 따로 기록.\n씨앗은 빗나가도 설치될 수 있어.\n표적을 전멸시키면 측정 종료.\n\n조준은 자동화된 비교 조건이야.\n플레이어의 조작 난이도·재미 점수는 아니야.\n"
	var text := notes if reports.is_empty() else ""
	if not baseline.is_empty(): text += "\n[color=#a8efe2]A 저장: %s / %s[/color]\n"%[Runner.SCENARIOS[baseline.scenario].name,recipe_name(baseline.recipe)]
	for index in range(reports.size()-1,maxi(-1,reports.size()-6),-1):
		var r: Dictionary = reports[index]
		var t: Dictionary = r.totals
		text += "\n[b]%s · %s[/b]\n%s\n정가 %d G · 추가 구매 %d G\n%.2f초 · 유효 DPS %.1f\n"%[Runner.SCENARIOS[r.scenario].name,"자동 조준" if r.aim=="nearest" else "오른쪽 고정",recipe_name(r.recipe),r.orb_cost,r.purchase_cost,r.seconds,r.effective_dps]
		text += "재시전 간격 %.3f초\n" % r.cast_interval
		text += "유효 피해 %.1f / 원피해 %.1f / 과잉 %.1f\n처치 %d / 등장 %d · 전멸 %s\n"%[t.get("damage_effective",0),t.get("damage_raw",0),t.get("damage_overkill",0),t.get("kills",0),r.spawned,"%.2f초"%r.clear_seconds if r.clear_seconds>=0 else "미달"]
		text += "시전 %d · 생성 탄 %d · 접촉률 %.1f%%\n폭발 %d · 폭발 피해 대상 %d · 연계 %d\n설치 %d · 지속 피해 틱 %d · 메아리 %d\n"%[t.get("casts",0),t.get("projectiles_emitted",0),r.contact_rate*100,t.get("explosions",0),t.get("explosion_victims",0),t.get("triggers",0),t.get("zones_created",0),t.get("zone_pulses",0),t.get("echoes_fired",0)]
		text += "끌린 적·초 %.2f · 합산 이동 %.0fpx\n받은 피해 %.0f · 평균 생존 적 %.1f\n"%[t.get("pull_enemy_seconds",0),t.get("pull_distance",0),t.get("player_damage",0),r.mean_alive]
		text += "최대 적/탄/장판 %d/%d/%d\n남은 탄/메아리/장판 %d/%d/%d\n"%[t.get("peak_enemies",0),t.get("peak_projectiles",0),t.get("peak_zones",0),r.pending.projectiles,r.pending.echoes,r.pending.zones]
		if t.get("zones_evicted",0)+t.get("projectiles_blocked",0)+t.get("echoes_blocked",0)>0:
			text += "[color=#ff9cae]상한 영향: 장판 교체 %d / 탄 제한 %d / 메아리 제한 %d[/color]\n"%[t.get("zones_evicted",0),t.get("projectiles_blocked",0),t.get("echoes_blocked",0)]
		text += "성장 완성 %d · 각인 폭발 %d · 냉각 %d · 파쇄 %d\n위성 접촉 %d · 잔불 설치 %d\n" % [t.get("graft_matured",0),t.get("sigil_bursts",0),t.get("freezes",0),t.get("shatters",0),t.get("orbit_contacts",0),t.get("path_patches",0)]
		text += "[b]피해 기여[/b]\n"
		for source in r.sources:
			var row: Dictionary = r.sources[source]
			var value: float = row.get("damage_effective",0)
			if value>0: text += "%s: %.1f (%.1f%%)\n"%[source_name(source),value,value*100/maxf(1,t.get("damage_effective",0))]
		if not baseline.is_empty() and r.scenario==baseline.scenario and r.seed==baseline.seed and r.aim==baseline.aim and r.power==baseline.power and r.fire_rate==baseline.fire_rate:
			text += "[color=#a8efe2]A 대비 DPS %+.1f / 처치 %+d / 받은 피해 %+.0f[/color]\n"%[r.effective_dps-baseline.effective_dps,int(t.get("kills",0))-int(baseline.totals.get("kills",0)),float(t.get("player_damage",0))-float(baseline.totals.get("player_damage",0))]
	readout.text = text+("\n"+notes if not reports.is_empty() else "")

func recipe_name(recipe: Array) -> String:
	var names := PackedStringArray()
	for id in recipe: names.append(str(game.Spells.definition(id).get("hud_name",game.Spells.definition(id).name)))
	return " → ".join(names)

func source_name(source: String) -> String:
	var bits := source.split("/")
	if bits.size()<2: return source
	return ("주문 " if bits[0]=="primary" else "연계 ")+str(game.Spells.definition(bits[1]).name)+(" · "+" / ".join(Array(bits).slice(2).map(func(id):return {"echo":"메아리","sigil":"각인 폭발","shatter":"파쇄"}.get(id,id))) if bits.size()>2 else "")

func save() -> void:
	if reports.is_empty(): return
	if export_stem.is_empty():
		export_stem = ProjectSettings.globalize_path("res://artifacts/measurements/lab-"+str(Time.get_unix_time_from_system()).replace(".","-"))
	Runner.save_reports(reports,export_stem)
	progress.text = "저장 완료 · artifacts/measurements · JSON + CSV"
