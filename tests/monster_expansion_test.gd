extends SceneTree
const Profile=preload("res://scripts/player_profile.gd")
const C=preload("res://scripts/monster_catalog.gd")
var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+note)
func fresh(wave := 5) -> void:
	g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false
	g.director.enabled=false;g.encounters.enabled=false;g.wave=wave
	g.invincible=1000;g.hp=1000;g.max_hp=1000;g.rng.seed=2910
func spawn(id: String, offset := Vector2(250,0)) -> Node2D:
	var d: Dictionary=C.definition(id)
	var role: String="sentinel" if id=="cauldron" else ("carrier" if id in ["satchel","trolley"] else "normal")
	var e: Node2D=g.spawn_enemy(d.kind,false,Vector2.INF,role,id)
	if e!=null: e.position=g.player.position+offset
	return e
func run() -> void:
	root.size=Vector2i(1920,1080)
	g=load("res://scenes/main.tscn").instantiate();g.record_runs=false
	g.profile=Profile.new("user://monster-test-unused.json")
	root.add_child(g);current_scene=g
	await process_frame
	fresh()
	check(C.IDS.size()==12 and C.DATA.size()==12,"12 real species, not recolor counters")
	var regions: Array=[]
	for id in C.IDS:
		var e:=spawn(id)
		check(e!=null,"Species spawns: "+id)
		if e==null: continue
		check(e.monster_id==id and e.kind in [1,2,3],"Species and stable combat kind: "+id)
		check(e.sprite.texture.atlas==C.ATLAS and not regions.has(e.sprite.texture.region),"Independent sprite region: "+id)
		regions.append(e.sprite.texture.region)
		check(e.radius==C.DATA[id].radius and e.visual_height>60,"Collision/display data: "+id)
	check(g.spawn_enemy(1,false,Vector2.INF,"normal","absent")==null,"Unknown IDs fail without bad atlas index")
	for wave in range(1,6):
		g.wave=wave
		var found: Dictionary={}
		for n in 1000:
			var id: String=C.pick(g,1,"normal")
			found[id]=true
			if int(C.DATA[id].first)>wave: check(false,"Species unlocked too early: "+id)
		check(found.has("jelly") and found.has("paper") and found.has("bat"),"Basic silhouettes remain through chapter "+str(wave))
		if wave>=2: check(found.has("ink") and found.has("rabbit"),"Midgame ink/rabbit arrivals")
		if wave>=3: check(found.has("book") and found.has("candle"),"Later book/candle arrivals")
	fresh()
	var e:=spawn("rabbit",Vector2(300,0));e.cooldown=0
	var a: Vector2=g.monsters.velocity(e,.01,Vector2.LEFT,300)
	check(a==Vector2.ZERO and e.windup>.7,"Rabbit warns before jumping")
	g.monsters.velocity(e,.81,Vector2.RIGHT,300)
	var v: Vector2=g.monsters.velocity(e,.12,Vector2.RIGHT,300)
	check(v.x<0 and e.jump_height>0,"First hop retains warned direction, not live target")
	g.monsters.velocity(e,.12,Vector2.RIGHT,300)
	check(e.tactics.phase=="gap" and e.tactics.hops==1,"Hop one enters gap")
	g.monsters.velocity(e,.23,Vector2.RIGHT,300)
	v=g.monsters.velocity(e,.24,Vector2.RIGHT,300)
	check(v.x<0 and e.tactics.phase=="recover","Second hop keeps same direction then recovers")
	g.monsters.velocity(e,.71,Vector2.RIGHT,300)
	check(e.tactics.is_empty() and e.cooldown>3,"Rabbit cannot attack endlessly")
	fresh()
	e=spawn("book");e.tactics.guard=Vector2.LEFT;e.cooldown=1
	var before: float=e.hp
	g.damage_enemy(e,100,Vector2.RIGHT)
	check(is_equal_approx(before-e.hp,55),"Shield reduces only frontal damage to55%, never immunity")
	before=e.hp;g.damage_enemy(e,100,Vector2.LEFT)
	check(is_equal_approx(before-e.hp,100),"Rear hits stay full damage")
	e.cooldown=0;g.monsters.velocity(e,.01,Vector2.RIGHT,250)
	before=e.hp;g.damage_enemy(e,100,Vector2.RIGHT)
	check(is_equal_approx(before-e.hp,100),"Turning shield has a visible vulnerable window")
	fresh()
	e=spawn("candle",Vector2(120,0));e.cooldown=0
	var money: int=g.economy.gold
	g.monsters.velocity(e,.01,Vector2.LEFT,120)
	check(e.windup>1 and not e.dead,"Candle warns for1.1s before exploding")
	g.invincible=0;g.player.position=e.position
	var health: float=g.hp
	g.monsters.velocity(e,1.11,Vector2.LEFT,0)
	check(e.dead and g.hp==health-16 and g.economy.gold==money and g.kills==0,"Self explosion hurts once and generates no kill/currency")
	fresh()
	e=spawn("candle",Vector2(100,0));e.cooldown=0
	g.monsters.velocity(e,.01,Vector2.LEFT,100)
	g.damage_enemy(e,100000,Vector2.ZERO)
	check(e.dead and g.monsters.hazards.is_empty() and g.kills==1,"Killing a lit candle safely extinguishes it")
	fresh()
	for n in 13:
		var ink: Node2D=g.Actor.new();ink.monster_id="ink";ink.position=g.player.position;g.monsters.died(ink);ink.free()
	check(g.monsters.hazards.size()==10,"Ink hazards have a bounded10 cap")
	g.invincible=0;health=g.hp
	g.monsters.update(.7)
	check(g.hp==health,"Ink death footprint warns before damaging")
	g.monsters.update(.1);g.monsters.update(.01)
	check(g.hp==health-8,"Ink activates after tell and respects shared invulnerability")
	g.monsters.update(3)
	check(g.monsters.hazards.is_empty(),"Ink expires rather than permanently blocks arena")
	fresh()
	e=spawn("mushroom",Vector2(300,0));e.cooldown=0
	g._rebuild_grid();g._update_enemies(.01)
	check(e.shot_windup>.6 and g.hostile_shots.is_empty(),"Mushroom uses aimed windup before projectile")
	g._update_enemies(.71)
	check(g.hostile_shots.size()==1,"Mushroom fires only one avoidable shot")
	fresh()
	for n in 7:
		e=spawn("rabbit",Vector2(300+n*70,100))
		if n<6: check(e!=null,"Rabbit tactical cap allows6")
		else: check(e==null,"Rabbit tactical cap rejects7")
	fresh(4)
	g.encounters.enabled=true;g.encounters.carrier_started=true
	g.encounters.spawn_carrier(g.player.position+Vector2(400,0))
	e=g.encounters.carrier
	check(e!=null and e.monster_id=="trolley" and g.encounters.escorts.size()==3,"Late supply cart has existing escort formation")
	if e!=null:
		check(g.encounters.goal.distance_to(e.position)>400,"Cart traversal goal is not overwritten by spawn position")
		v=g.encounters.velocity(e)
		check(v.length()>0 and not e.dead,"Cart actually traverses instead of escaping immediately")
		var goal: Vector2=g.encounters.goal
		g.player.position+=Vector2(50,50)
		g.encounters.velocity(e)
		check(g.encounters.goal==goal,"Cart does not retarget into player chase")
	g.encounters.escape()
	check(g.encounters.resolved and g.combat_rewards.pending.is_empty(),"Escaping reward group grants no unearned choice")
	fresh(1)
	g.encounters.enabled=true;g.wave_time=75;g.encounters.update(.01)
	check(g.encounters.carrier_started and g.encounters.tells.size()==1,"Real combat now schedules missing reward carrier")
	g.encounters.update(1.2)
	e=g.encounters.carrier
	check(e!=null and e.monster_id=="satchel","Early reward enemy is distinct satchel")
	if e!=null:
		g.damage_enemy(e,100000,Vector2.ZERO)
		check(g.encounters.drop_ready and g.chests.size()==1,"Defeating actual reward monster drops existing chest")
	fresh()
	for n in 6:
		e=spawn("beetle",Vector2(300+n*70,100));e.cooldown=0
	g._rebuild_grid();g._update_enemies(.01)
	check(g.enemies.filter(func(x):return x.windup>0).size()==4,"No more than4 simultaneous tactical attack tells")
	for chapter in range(1,6):
		fresh(chapter)
		g.elapsed=(chapter-1)*360+20;g.wave_time=20;g.director.reset()
		for n in 60:
			g.elapsed+=.1;g.wave_time+=.1;g.director.update()
		check(not g.enemies.is_empty() and g.enemies.size()<=int(g.Waves.config(chapter).cap),"Production director respects total cap in chapter "+str(chapter))
		check(g.enemies.all(func(x):return x.position.distance_to(g.player.position)>=g.Waves.SAFE_DISTANCE),"Production entrances stay safe in chapter "+str(chapter))
		check(g.enemies.all(func(x):return int(C.DATA[x.monster_id].first)<=chapter),"Production entrances respect species unlocks in chapter "+str(chapter))
		check(g.enemies.filter(func(x):return x.kind==2).size()<=int(g.Waves.config(chapter).ranged_cap),"Production ranged cap chapter "+str(chapter))
		g.director.clear();g.wave_time+=100;g.director.update()
		check(g.director.pending.is_empty(),"Stopped director accumulates no delayed packs")
	fresh()
	var ink: Node2D=g.Actor.new();ink.monster_id="ink";ink.position=g.player.position;g.monsters.died(ink);ink.free()
	g.clear_magic()
	check(g.monsters.hazards.size()==1,"Editing spells cannot erase enemy hazards")
	g.complete_wave()
	# Last chapter does not rest; use next check in a real rest chapter.
	g.wave=1;g.complete_wave()
	check(g.monsters.hazards.is_empty() and g.state=="shop","Rest clears hazards and all enemy attacks")
	fresh()
	ink=g.Actor.new();ink.monster_id="ink";ink.position=g.player.position;g.monsters.died(ink);ink.free()
	g.end_run(false)
	check(g.monsters.hazards.is_empty(),"Run end clears enemy hazards")
	g.queue_free();await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
