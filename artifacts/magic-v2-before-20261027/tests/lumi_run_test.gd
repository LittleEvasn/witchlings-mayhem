extends SceneTree
const Content=preload("res://scripts/run_content.gd")
const Profile=preload("res://scripts/player_profile.gd")
class RetryDirector:
	extends "res://scripts/waves.gd"
	func random_spawn_point(_radius := 18.0) -> Vector2: return Vector2.INF
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+text)
	else: print("PASS: "+text)
func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.enabled=false
	g.invincible=10000
	g.sound_enabled=false
	g.music_enabled=false
	g.record_runs=false
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g); current_scene=g
	await process_frame
	fresh()
	check(Content.combat_limit()==600,"Combat cap: 10 minutes")
	check(Content.CHAPTERS.slice(0,4).reduce(func(sum,c):return sum+c.duration,0)==450,"Nonboss combat: 7m30")
	for number in range(1,6):
		var c: Dictionary=g.Waves.config(number)
		check(c.duration==Content.chapter(number).duration and g.Waves.forecast(number).contains(c.title),"Wave, chapter and forecast share timing and name %d"%number)
	g.begin_lumi_run("frost"); g._physics_process(60)
	check(g.state=="intro" and g.elapsed==0 and g.enemies.is_empty(),"Intro freezes combat and spawning")
	g.begin_combat()
	check(g.state=="combat" and g.recipe==g.Economy.KITS.frost.recipe,"Intro preserves chosen kit")
	g.open_editor(); g._physics_process(60)
	check(g.prep_elapsed==60 and g.elapsed==0,"Combat Tab editing is included in preparation/editing clock")
	g.board_close()
	fresh()
	for number in range(1,5):
		g.wave_time=g.Waves.config(number).duration-.01
		g._physics_process(.02)
		check(g.state=="reward" and g.director.pending.is_empty() and g.wave_records.size()==number,"Timed wave reaches reward and clears pending %d"%number)
		var money: int=g.economy.gold
		g.complete_wave()
		check(g.economy.gold==money,"No duplicate clear grant %d"%number)
		g.choose_reward(g.reward_options[0])
		check(g.state=="shop" and g.relics.owned.size()==number,"Relic enters crafting %d"%number)
		var elapsed_before: float=g.elapsed
		var wave_before: float=g.wave_time
		g._physics_process(180)
		check(g.state=="shop" and g.wave_time==wave_before and g.elapsed==elapsed_before,"Unlimited preparation without combat clock %d"%number)
		var prep: float=g.prep_elapsed
		var gold: int=g.economy.gold
		var relics: Dictionary=g.relics.snapshot()
		check(g.start_trial(),"Trial opens %d"%number)
		g._physics_process(.1); g.end_trial()
		check(g.elapsed==elapsed_before and g.prep_elapsed==prep and g.economy.gold==gold and g.relics.snapshot()==relics,"Trial restores clocks, gold and relics %d"%number)
		g.launch_next_wave(); g.director.enabled=false
		check(g.state=="combat" and g.wave==number+1 and g.wave_time==0,"Manual Ready starts wave %d"%number)
	check(is_instance_valid(g.boss_ref),"Fifth wave spawns boss")
	var boss=g.boss_ref
	boss.position=g.player.position+Vector2(360,0)
	var pattern=g.boss_encounter
	pattern.clock=pattern.next_attack; pattern.update(boss,.01)
	check(pattern.attack=="fan" and pattern.windup>.9 and g.hostile_shots.is_empty(),"Fan warns before firing")
	var locked: Vector2=pattern.direction
	g.player.position+=Vector2(0,140); pattern.update(boss,1)
	check(g.hostile_shots.size()==5 and g.hostile_shots[2].vel.normalized().is_equal_approx(locked),"Fan direction stays locked")
	pattern.clock=pattern.next_attack; pattern.update(boss,.01)
	g.player.position+=Vector2(0,150); g.invincible=0
	var health: float=g.hp
	pattern.update(boss,1.2)
	check(g.hp==health and pattern.circles.is_empty(),"Ground strike targets old position and is dodgeable")
	pattern.clock=pattern.next_attack; pattern.update(boss,.01)
	check(pattern.attack=="dash" and pattern.windup>.9,"Dash warns before moving")
	pattern.update(boss,1)
	check(pattern.dash_left>0,"Dash begins after warning")
	boss.hp=boss.max_hp*.49; pattern.update(boss,.01)
	check(pattern.phase==2 and pattern.fired.fan==1 and pattern.fired.circles==1 and pattern.fired.dash==1,"Half health phase and all three attacks")
	g.damage_enemy(boss,100000,Vector2.ZERO)
	check(g.state=="ended" and g.result_win and g.hostile_shots.is_empty() and g.magic.echoes.is_empty(),"Boss death cleans attacks and ends run")
	check(g.run_record.won and g.run_record.recipes.size()==2 and g.run_record.waves.size()==4,"Results retain both orbs and growth steps")
	g.ui.show_results(); g.return_title()
	check(g.state=="title" and g.enemies.is_empty() and g.projectiles.is_empty(),"Title cleans encounter")
	fresh()
	check(g.economy.gold==0 and g.relics.owned.is_empty() and g.wave_records.is_empty() and g.prep_elapsed==0,"Retry resets run-local progression")
	g.wave=5; g.director=RetryDirector.new(g); g.director.enabled=false
	check(g._ensure_boss(),"Deterministic fallback when random boss spawn fails")
	var same=g.boss_ref
	check(g._ensure_boss() and g.boss_ref==same and g.enemies.filter(func(e):return e.boss).size()==1,"Recovery never duplicates boss")
	g.wave_time=g.Waves.config(5).duration; g._physics_process(.01)
	check(g.state=="ended" and not g.result_win and g.end_reason.contains("교수님"),"Timeout has explicit failure ending")
	g.director=g.Waves.new(g); fresh(); g.invincible=0; g.hurt_player(1000)
	check(g.state=="ended" and not g.result_win and g.end_reason.contains("쓰러"),"Death has distinct ending")
	fresh(); g.wave=5; g._ensure_boss(); g.hp=1; g.invincible=0
	g.boss_encounter.attack="circles"
	g.boss_encounter.circles=[g.player.position,g.player.position+Vector2.ONE,g.player.position-Vector2.ONE]
	g.boss_encounter.windup=.01
	g.boss_encounter.update(g.boss_ref,.02)
	check(g.state=="ended" and g.boss_encounter.circles.is_empty() and g.hostile_shots.is_empty(),"Fatal boss circle safely cleans the in-progress attack")
	var total:=0
	for number in range(1,5): total+=g.Waves.config(number).drop_budget+g.Economy.CLEAR_REWARD
	var pair: int=g.Economy.investment_cost("bolt@4")+g.Economy.investment_cost("bloom@4")+g.Spells.Progression.FUSION_COST
	check(total==360 and total>pair+100,"Preboss budget can fund +4 pair plus support choices")
	var p:=Profile.new("user://lumi-profile-test.json")
	check(not p._valid({"version":1,"records":[{"combat":{}}]}),"Structurally corrupt records rejected before rendering or backup")
	p.record_run({"won":true,"combat":540.0,"kit":"sigil","kills":100})
	check(p.save_profile(),"Profile saves")
	var loaded:=Profile.new(p.path); loaded.load_profile()
	check(loaded.data.wins==1 and loaded.data.lumi_clue and loaded.data.records.size()==1,"Profile reopens clue and record")
	p.save_profile()
	var broken:=FileAccess.open(p.path,FileAccess.WRITE); broken.store_string("broken"); broken.close()
	loaded=Profile.new(p.path); loaded.load_profile()
	check(loaded.data.wins==1 and not loaded.warning.is_empty(),"Corrupt primary recovers backup")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(p.path+suffix): DirAccess.remove_absolute(p.path+suffix)
	for phase in ["prepare","combat","boss"]: check(not FileAccess.file_exists("res://assets/audio/"+phase+".wav"),"User removed provisional music: "+phase)
	g.queue_free(); await process_frame
	print("RESULT: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
