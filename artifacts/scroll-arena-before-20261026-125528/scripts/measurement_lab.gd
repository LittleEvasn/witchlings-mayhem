extends Node
const Runner = preload("res://scripts/measurement_runner.gd")
const PRESETS := {
	"정원 성장":[["giant","vortex"],["bloom","expire","frost"]],
	"집중과 파쇄":[["pierce","charge","bolt"],["frost","impact","thunder"]],
	"이동과 위성":[["giant","ember_path"],["sigil","satellite"]],
	"큰 관통 한 발":["pierce","charge","bolt"],
	"각인 연사":["fan","sigil","bolt"],
	"서리와 낙뢰 파쇄":["frost","impact","thunder"],
	"위성 각인":["sigil","satellite"],
	"이동 후 소용돌이":["ember_path","impact","vortex"],
	"유도·갈래·꽃폭탄 → 소용돌이":[["seek","fan","bloom","impact","vortex"],["bolt"]],
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
var bank: Array = [["seek","fan","bloom","impact","vortex"],["bolt"]]
var active_orb := 0
var rank_choice: OptionButton
var orb_choices: Array = []
var parts: Array:
	get: return bank[active_orb]
	set(value): bank[active_orb] = value
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
var batch_aim := "replay"
var export_stem := ""
var selected_relics: Array = []
var initial_gold := 0
var relic_config: Control

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
	ui.label(screen,"두 오브 · 같은 입력으로 비교",Vector2(250,35),17,ui.MUTED)
	for orb in 2:
		var chosen := orb
		var button = ui.button(screen,"오브 %d"%(orb+1),Rect2(850+orb*116,26,104,40),func():active_orb=chosen;refresh_recipe(),false,17)
		orb_choices.append(button)
		config_buttons.append(button)
	rank_choice = option(Vector2(1090,26),126,["기본","+1","+2","+3","+4"])
	ui.button(screen,"시작 화면",Rect2(1240,26,160,40),func():get_tree().change_scene_to_file("res://scenes/main.tscn"),false,17)
	scenario = option(Vector2(38,89),245,Runner.SCENARIOS.values().map(func(c):return c.name))
	aim_choice = option(Vector2(295,89),230,["공통 마우스 경로","가까운 적 자동 조준","오른쪽 고정 조준"])
	preset = option(Vector2(537,89),308,PRESETS.keys())
	preset.select(PRESETS.keys().find("유도·갈래·꽃폭탄 → 소용돌이"))
	preset.item_selected.connect(func(index):bank=Runner.normalize_bank(PRESETS.values()[index]); refresh_recipe())
	run_button = ui.button(screen,"선택 환경 측정",Rect2(858,89,174,40),func():start(false),true,16)
	all_button = ui.button(screen,"7개 환경 비교",Rect2(1044,89,174,40),func():start(true),false,16)
	stop_button = ui.button(screen,"측정 중단",Rect2(1230,89,170,40),cancel,false,16)
	for orb in 2:
		for i in 6:
			var chosen := orb
			var index := i
			var b = ui.button(screen,"",Rect2(38+i*225,136+orb*39,214,34),func():
				active_orb=chosen
				if index<parts.size(): parts.remove_at(index)
				refresh_recipe()
			,false,15)
			recipe_buttons.append(b)
			config_buttons.append(b)
	info = ui.label(screen,"",Vector2(38,218),14,ui.MUTED,1360)
	ui.panel(screen,Rect2(18,742,860,142),ui.INK)
	var i := 0
	for id in game.Spells.PARTS:
		var orb: String = id
		var b = ui.button(screen,game.Spells.definition(id).name,Rect2(24+(i%6)*142,747+int(i/6)*33,136,30),func():
			if parts.size()<6:
				var token: String = game.Spells.Progression.key(orb,rank_choice.selected) if game.Spells.definition(orb).kind in ["attack","modifier"] and not game.Spells.Progression.is_fused(orb) else orb
				parts.append(token)
				refresh_recipe()
		,false,14)
		config_buttons.append(b)
		i += 1
	ui.panel(screen,Rect2(900,260,522,620),ui.INK)
	var relic_button = ui.button(screen,"유물 설정",Rect2(30,269,120,36),show_relic_config,false,15)
	config_buttons.append(relic_button)
	progress = ui.label(screen,"오브 선택 후 구체 추가 · 슬롯 클릭으로 제거",Vector2(920,277),16,ui.MINT,482)
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
	var error := ""
	for orb in 2:
		for i in 6:
			recipe_buttons[orb*6+i].text = "%d.%d  %s"%[orb+1,i+1,game.Spells.definition(bank[orb][i]).name] if i<bank[orb].size() else "%d.%d  빈 칸"%[orb+1,i+1]
		if not bank[orb].is_empty():
			var compiled: Dictionary = game.Spells.compile(bank[orb])
			if not compiled.ok: error = "오브 %d: %s"%[orb+1,compiled.error]
		orb_choices[orb].text = ("▶ " if active_orb==orb else "")+"오브 %d"%(orb+1)
	if bank==[[],[]]: error="오브에 공격을 넣어줘."
	var quote: Dictionary = Runner.Cost.new().plan(bank)
	if not quote.ok: error=quote.error
	var hint: String = Runner.SCENARIOS.values()[scenario.selected].hint
	info.text = "15초 / 시드 731 / 실제 추가 투자 %d G (기본 구체 합성 경로·제작안 확보 가정) · %s"%[quote.get("spent",0),hint] if error.is_empty() else error
	run_button.disabled = is_running or not error.is_empty()
	all_button.disabled = run_button.disabled
	stop_button.disabled = not is_running
	for b in config_buttons: b.disabled = is_running
	for control in [scenario,aim_choice,preset,rank_choice]: control.disabled = is_running

func start(all_scenarios: bool) -> void:
	if is_running or run_button.disabled: return
	batch_parts = bank.duplicate(true)
	batch_aim = ["replay","nearest","fixed"][aim_choice.selected]
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
	runner.begin(batch_parts,id,731,batch_aim,15,1,1,"sigil",{"relics":selected_relics.duplicate(),"gold":initial_gold})
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
	if not baseline.is_empty(): text += "\n[color=#a8efe2]A 저장: %s / %s[/color]\n"%[Runner.SCENARIOS[baseline.scenario].name,bank_name(baseline.bank)]
	for index in range(reports.size()-1,maxi(-1,reports.size()-6),-1):
		var r: Dictionary = reports[index]
		var t: Dictionary = r.totals
		text += "\n[b]%s · %s[/b]\n%s\n구체 환산가 %d G · 실제 추가 투자 %d G\n%.2f초 · 유효 DPS %.1f\n"%[Runner.SCENARIOS[r.scenario].name,{"nearest":"자동 조준","replay":"공통 입력","fixed":"고정 조준"}.get(r.aim,r.aim),bank_name(r.bank),r.orb_cost,r.purchase_cost,r.seconds,r.effective_dps]
		text += "두 오브 순환 간격 %s초 · CPU step p95 %.3fms\n" % [str(r.orb_intervals),r.step_cpu_ms.p95]
		text += "유물 %s · 시작 마석 %d · 시작 체력 %.0f\n"%[str(r.get("relics",[])),r.get("initial_gold",0),r.get("player_initial_health",0)]
		text += "유효 피해 %.1f / 원피해 %.1f / 과잉 %.1f\n처치 %d / 등장 %d · 전멸 %s\n"%[t.get("damage_effective",0),t.get("damage_raw",0),t.get("damage_overkill",0),t.get("kills",0),r.spawned,"%.2f초"%r.clear_seconds if r.clear_seconds>=0 else "미달"]
		text += "시전 %d · 생성 탄 %d · 접촉률 %.1f%%\n폭발 %d · 폭발 피해 대상 %d · 연계 %d\n설치 %d · 지속 피해 틱 %d · 메아리 %d\n"%[t.get("casts",0),t.get("projectiles_emitted",0),r.contact_rate*100,t.get("explosions",0),t.get("explosion_victims",0),t.get("triggers",0),t.get("zones_created",0),t.get("zone_pulses",0),t.get("echoes_fired",0)]
		text += "끌린 적·초 %.2f · 합산 이동 %.0fpx\n받은 피해 %.0f · 평균 생존 적 %.1f\n"%[t.get("pull_enemy_seconds",0),t.get("pull_distance",0),t.get("player_damage",0),r.mean_alive]
		text += "최대 적/탄/장판 %d/%d/%d\n남은 탄/메아리/장판 %d/%d/%d\n"%[t.get("peak_enemies",0),t.get("peak_projectiles",0),t.get("peak_zones",0),r.pending.projectiles,r.pending.echoes,r.pending.zones]
		if t.get("zones_evicted",0)+t.get("projectiles_blocked",0)+t.get("echoes_blocked",0)>0:
			text += "[color=#ff9cae]상한 영향: 장판 교체 %d / 탄 제한 %d / 메아리 제한 %d[/color]\n"%[t.get("zones_evicted",0),t.get("projectiles_blocked",0),t.get("echoes_blocked",0)]
		var other_limits := PackedStringArray()
		for event in ["orbits_blocked","strikes_blocked","emits_blocked","chain_depth_blocked"]:
			if t.get(event,0)>0: other_limits.append("%s %d"%[{"orbits_blocked":"위성 유지 제한","strikes_blocked":"벼락 제한","emits_blocked":"시전 제한","chain_depth_blocked":"연결 제한"}[event],t[event]])
		if not other_limits.is_empty(): text += "[color=#ff9cae]"+" / ".join(other_limits)+"[/color]\n"
		text += "성장 완성 %d · 각인 폭발 %d · 냉각 %d · 파쇄 %d\n위성 접촉 %d · 잔불 설치 %d\n" % [t.get("garden_full",0),t.get("sigil_bursts",0),t.get("freezes",0),t.get("shatters",0),t.get("orbit_contacts",0),t.get("path_patches",0)]
		text += "[b]피해 기여[/b]\n"
		for source in r.sources:
			var row: Dictionary = r.sources[source]
			var value: float = row.get("damage_effective",0)
			if value>0: text += "%s: %.1f (%.1f%%)\n"%[source_name(source),value,value*100/maxf(1,t.get("damage_effective",0))]
		if not baseline.is_empty() and r.scenario==baseline.scenario and r.ruleset==baseline.ruleset and r.motion==baseline.motion and r.input_policy==baseline.input_policy and r.seed==baseline.seed and r.aim==baseline.aim and r.power==baseline.power and r.fire_rate==baseline.fire_rate and r.get("initial_gold",0)==baseline.get("initial_gold",0) and r.get("player_initial_health",0)==baseline.get("player_initial_health",0) and r.get("relic_ruleset","")==baseline.get("relic_ruleset",""):
			text += "[color=#a8efe2]A 대비 DPS %+.1f / 처치 %+d / 받은 피해 %+.0f[/color]\n"%[r.effective_dps-baseline.effective_dps,int(t.get("kills",0))-int(baseline.totals.get("kills",0)),float(t.get("player_damage",0))-float(baseline.totals.get("player_damage",0))]
	readout.text = text+("\n"+notes if not reports.is_empty() else "")

func recipe_name(recipe: Array) -> String:
	var names := PackedStringArray()
	for id in recipe: names.append(str(game.Spells.definition(id).get("hud_name",game.Spells.definition(id).name)))
	return " → ".join(names)

func bank_name(value: Array) -> String:
	return "오브 1: "+recipe_name(value[0])+"\n오브 2: "+recipe_name(value[1])

func source_name(source: String) -> String:
	var bits := Array(source.split("/"))
	var prefix := ""
	if bits.size()>3 and str(bits[0]).begins_with("o"):
		prefix = "오브 %d·칸 %d "%[int(str(bits[0]).substr(1))+1,int(str(bits[1]).substr(1))+1]
		bits = bits.slice(2)
	if bits.size()<2: return prefix+source
	return prefix+str(game.Spells.definition(bits[1]).name)+( " · "+" / ".join(bits.slice(2).map(func(id):return {"echo":"메아리","sigil":"각인","shatter":"파쇄","chain":"연쇄","intrinsic":"합성 내장","relic_copy":"유물 복제"}.get(id,id))) if bits.size()>2 else "")

func show_relic_config() -> void:
	if is_running or is_instance_valid(relic_config): return
	var ui = game.ui
	relic_config = Control.new()
	relic_config.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	relic_config.mouse_filter=Control.MOUSE_FILTER_STOP
	screen.add_child(relic_config)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0,0,0,.85)
	relic_config.add_child(shade)
	ui.panel(relic_config,Rect2(170,130,1100,640))
	ui.label(relic_config,"측정할 유물 · 시드 731",Vector2(200,155),28,ui.MINT)
	ui.label(relic_config,"시작 마석",Vector2(200,213),18,ui.TEXT)
	var gold := SpinBox.new()
	gold.position=Vector2(320,205)
	gold.size=Vector2(170,40)
	gold.max_value=100000
	gold.value=initial_gold
	gold.value_changed.connect(func(value):initial_gold=int(value))
	relic_config.add_child(gold)
	ui.label(relic_config,"측정 체력 100만 · 생존 난도 검사가 아닙니다",Vector2(530,215),16,ui.MUTED)
	var grid := GridContainer.new()
	grid.position=Vector2(200,275)
	grid.columns=3
	grid.add_theme_constant_override("h_separation",20)
	grid.add_theme_constant_override("v_separation",18)
	relic_config.add_child(grid)
	for id in game.Relics.DEFINITIONS:
		var choice := CheckButton.new()
		choice.text=game.Relics.definition(id).name
		choice.custom_minimum_size=Vector2(326,60)
		choice.button_pressed=id in selected_relics
		choice.tooltip_text=game.relics.tooltip(id,initial_gold)
		choice.toggled.connect(func(on):
			if on and not id in selected_relics: selected_relics.append(id)
			elif not on: selected_relics.erase(id)
		)
		grid.add_child(choice)
	ui.button(relic_config,"확인",Rect2(1020,695,210,44),func():
		relic_config.queue_free()
		relic_config=null
		refresh_recipe()
	,true,19)

func save() -> void:
	if reports.is_empty(): return
	if export_stem.is_empty():
		export_stem = ProjectSettings.globalize_path("res://artifacts/measurements/lab-"+str(Time.get_unix_time_from_system()).replace(".","-"))
	Runner.save_reports(reports,export_stem)
	progress.text = "저장 완료 · artifacts/measurements · JSON + CSV"

