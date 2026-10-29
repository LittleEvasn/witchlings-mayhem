extends SceneTree
const T=preload("res://scripts/combat_tempo.gd")
const Profile=preload("res://scripts/player_profile.gd")
var g: Node2D
var checks:=0
var failures:=0
var metrics: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func fresh() -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.invincible=10000
	g.director.enabled=false
	g.encounters.enabled=false
	g.orb_compiled=[[]]
	g.compiled=[]
	g.rng.seed=3029
func spawn(kind: int, role := "normal") -> Node2D:
	g.wave=5
	var e: Node2D=g.spawn_enemy(kind,false,Vector2.INF,role)
	if e!=null: e.cooldown=1000
	return e
func ticks(seconds: float) -> void:
	for i in roundi(seconds*60):
		g._rebuild_grid()
		g._update_enemies(1.0/60)
func run() -> void:
	root.size=Vector2i(1600,900)
	for wave in range(1,6):
		for kind in [1,2,3]:
			var speed:=T.enemy_speed(kind,"normal",wave)
			check(speed<=T.PLAYER_SPEED*.5 and speed>0,"Normal enemy can be outwalked, wave%d kind%d"%[wave,kind])
		check(T.enemy_speed(3,"sentinel",wave)<=T.PLAYER_SPEED*.7,"Elite walk never exceeds70 percent, wave%d"%wave)
		check(T.enemy_speed(1,"carrier",wave)<T.PLAYER_SPEED,"Carrier can be caught with walking/dash")
		check(T.enemy_speed(1,"swarm",wave)<T.enemy_speed(1,"normal",wave),"Weak pack remains slower than normal")
	check(T.CHARGE_SPEED>T.PLAYER_SPEED and T.CHARGE_SPEED*T.CHARGE_SECONDS>=300,"Charge is an explicit long faster attack")
	check(T.steered_velocity(Vector2.RIGHT*100,Vector2.RIGHT*30,100).is_equal_approx(Vector2.RIGHT*100),"Separation cannot boost pursuit")
	check(T.steered_velocity(Vector2.RIGHT*280,Vector2.RIGHT*30,82).length()<=280.001,"Separation cannot boost charge")
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	g.profile=Profile.new("user://movement-tempo-unused.json")
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	var origin: Vector2=g.player.position
	Input.action_press("move_right")
	for i in 60: g._physics_process(1.0/60)
	Input.action_release("move_right")
	var straight: float=origin.distance_to(g.player.position)
	check(absf(straight-200)<.1,"Actual combat walk200 units per second")
	fresh();origin=g.player.position
	Input.action_press("move_right");Input.action_press("move_down")
	for i in 60: g._physics_process(1.0/60)
	Input.action_release("move_right");Input.action_release("move_down")
	check(absf(origin.distance_to(g.player.position)-straight)<.1,"Actual diagonal speed equals straight walking")
	fresh();origin=g.player.position
	check(g.try_dash(Vector2.RIGHT) and not g.try_dash(Vector2.RIGHT),"Dash cooldown retained")
	for i in 20: g._physics_process(.02)
	var dash_distance: float=origin.distance_to(g.player.position)
	check(absf(dash_distance-104)<.1 and g.dash_left==0,"Dash travels104 once then stops")
	fresh();origin=g.player.position
	g.try_dash(Vector2.RIGHT)
	g._move_player(.4,Vector2.RIGHT)
	check(absf(origin.distance_to(g.player.position)-144)<.1,"Large delta never extends dash; leftover time walks")
	fresh()
	g.state="shop"
	g.shop_time=60
	check(g.start_trial(),"Production trial opens")
	g.player.position=Vector2(700,300);origin=g.player.position
	Input.action_press("move_right")
	for i in 30: g._physics_process(1.0/60)
	Input.action_release("move_right")
	check(absf(origin.distance_to(g.player.position)-100)<.1,"Trial uses same walk speed as combat")
	g.end_trial()
	fresh()
	var e:=spawn(1)
	e.position=g.player.position+Vector2(500,0)
	origin=e.position
	ticks(1)
	check(absf(origin.distance_to(e.position)-100)<.1,"Actual late-wave common walk100")
	var margin_before: float=e.position.distance_to(g.player.position)
	for i in 60:
		g.player.position+=Vector2.LEFT*T.PLAYER_SPEED/60
		ticks(1.0/60)
	check(absf(e.position.distance_to(g.player.position)-margin_before-100)<.2,"Walking away gains100 units of room per second")
	var cold: Dictionary=g.magic.behavior.state_for(e)
	cold.cold=1
	origin=e.position
	ticks(.5)
	check(absf(origin.distance_to(e.position)-40)<.1,"Cold slow still multiplies new walking speed")
	cold.frozen_until=100
	origin=e.position
	ticks(.5)
	check(e.position==origin,"Freeze still stops movement completely")
	fresh()
	e=spawn(3,"sentinel");e.position=g.player.position+Vector2(500,0);origin=e.position
	ticks(1)
	check(absf(origin.distance_to(e.position)-140)<.1,"Actual elite walk140, no normal charge")
	fresh()
	var front:=spawn(1)
	var back:=spawn(1)
	front.position=g.player.position+Vector2(450,0)
	back.position=front.position+Vector2(12,0)
	front.separation_left=0;back.separation_left=0
	origin=front.position
	ticks(1.0/60)
	check(front.separation_velocity.length()>0 and front.position.distance_to(origin)<=100.0/60+.001,"Actual crowded front cannot outrun its walking speed")
	fresh()
	e=spawn(3);e.position=g.player.position+Vector2(500,0);e.cooldown=0
	g._rebuild_grid();g._update_enemies(1.0/60)
	var locked: Vector2=e.charge_direction
	origin=e.position
	check(is_equal_approx(e.windup,T.CHARGE_WINDUP),"Charger advertises1.05-second windup")
	g.player.position+=Vector2(0,220)
	ticks(1.1)
	check(e.charge_direction==locked and e.charge_time>0,"Charge aims once, does not track during windup")
	origin=e.position
	# Measure an exact complete charging phase, independent of timer boundary rounding.
	e.windup=0;e.charge_time=T.CHARGE_SECONDS;e.separation_velocity=Vector2.ZERO
	ticks(1.1)
	var charge_distance: float=e.position.distance_to(origin)
	check(absf(charge_distance-308)<.1,"Full charge travels308 with fixed direction")
	origin=e.position
	ticks(.5)
	check(e.recovery_left>0 and e.position.distance_to(origin)<.1,"Recovery creates a real stationary opening")
	fresh()
	e=spawn(2);e.position=g.player.position+Vector2(400,0);e.cooldown=0
	ticks(.8)
	check(g.hostile_shots.size()==1 and absf(g.hostile_shots[0].vel.length()-140)<.01,"Ranged bullet tempo adjusted with player walking")
	fresh()
	var boss: Node2D=g.spawn_enemy(3,true)
	g.boss_encounter.dash_left=.65;g.boss_encounter.direction=Vector2.RIGHT
	var travel:=Vector2.ZERO
	for i in 39: travel+=g.boss_encounter.update(boss,1.0/60)/60
	check(absf(travel.x-195)<1,"Boss dash has bounded distance at new tempo")
	g.boss_encounter.attack="fan"
	g.boss_encounter._release(boss)
	check(g.hostile_shots.size()==5 and absf(g.hostile_shots[0].vel.length()-160)<.01,"Boss bullets keep comparable evasion ratio to slower player")
	fresh()
	g.wave=5;g.elapsed=1500;g.wave_time=60
	g.director.reset();g.director.next_pack=INF;g.director.next_elite=INF
	g.director.last_time=g.wave_time
	for i in 180:
		g.elapsed+=1.0/60;g.wave_time+=1.0/60
		g.director.update()
	check(g.enemies.size()>=60 and g.enemies.size()<=300,"High-population refill remains active without speeding up enemies")
	metrics={"player_walk":straight,"dash_distance":dash_distance,"normal_wave5":T.enemy_speed(1,"normal",5),"elite_wave5":140,"charge_distance":charge_distance,"refill_after3s":g.enemies.size(),"checks":checks,"failures":failures}
	var file:=FileAccess.open("res://artifacts/movement-tempo-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics));file.close()
	g.queue_free()
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
