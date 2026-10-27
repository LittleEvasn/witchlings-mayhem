extends SceneTree
const Spells = preload("res://scripts/spells.gd")
const Economy = preload("res://scripts/economy.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const Meter = preload("res://scripts/combat_meter.gd")
var g: Node2D
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if ok: print("PASS: "+text)
	else:
		failures+=1
		printerr("FAIL: "+text)

func fresh(bank: Array = [["bolt"],[]]) -> void:
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	g.director.enabled=false
	g.meter=Meter.new()
	g.player.position=Vector2(300,330)
	g.cast_target=Vector2(420,330)
	g.aim=Vector2.RIGHT
	g.active_orb=0
	g.orb_recipes=bank.duplicate(true)
	g.orb_drafts=bank.duplicate(true)
	g.recipe=bank[0].duplicate()
	g.draft=bank[0].duplicate()
	g.economy.inventory={}
	for row in bank:
		for token in row: g.economy.inventory[token]=int(g.economy.inventory.get(token,0))+1
	g._commit_live_board()
	g.orb_clocks=[0.0,0.0]
	g.orb_cursors=[0,0]

func enemy(at: Vector2) -> Node2D:
	var e=g.spawn_enemy(1)
	e.position=at
	e.hp=10000
	e.max_hp=e.hp
	g._rebuild_grid()
	return e

func emit(parts: Array) -> Dictionary:
	var stage: Dictionary=Spells.compile(parts).stages[0]
	g.magic.begin_tick()
	g.emit_stage(stage,g.player.position,Vector2.RIGHT,Spells.follow(stage),1)
	return stage

func tick(seconds: float) -> void:
	for i in ceili(seconds*120):
		g.magic.begin_tick()
		g._rebuild_grid()
		g._update_projectiles(1.0/120)
		g.magic.update_zones(1.0/120)
		g._update_effects(1.0/120)

func total(id: String) -> float: return float(g.meter.totals.get(id,0))
func profile(parts: Array, id: String) -> Dictionary:
	return Spells.Effects.profile(Spells.compile(parts+["bolt"]).stages[0],id)

func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	fresh()
	var examples: Array = [[0,0,1],[1,0,2],[2,0,3],[3,0,4],[1,1,2],[2,1,3],[2,2,4]]
	for id in Spells.STACK_RULES:
		for rank in range(5):
			var token:=Progression.key(id,rank)
			var result:=Spells.compile([token,"bolt"])
			check(Spells.has_part(token) and result.ok and result.stages[0].modifiers[0].rank==rank and result.stages[0].rank_power==1,"Canonical support rank compiles without attack-rank damage: "+token)
			check(not "기본 공격 피해" in Spells.definition(token).desc,"Support description uses its real effect: "+token)
		for example in examples:
			for reverse in [false,true]:
				var a:=Progression.key(id,example[1] if reverse else example[0])
				var b:=Progression.key(id,example[0] if reverse else example[1])
				var e:=Economy.new()
				e.inventory={a:1}
				e.inventory[b]=int(e.inventory.get(b,0))+1
				var q:=e.craft("merge",a,b,e.revision)
				check(q.ok and q.output==Progression.key(id,example[2]) and e.inventory=={q.output:1},"Support merge consumes exactly two, symmetric ranks: "+id+str(example))
		var e:=Economy.new()
		e.inventory={id+"@2":1,id+"@3":1}
		e.gold=200
		var old:=e.inventory.duplicate()
		var over:=e.craft("merge",id+"@2",id+"@3",e.revision)
		check(not over.ok and over.output_rank==5 and e.inventory==old and e.gold==200,"Over-cap support merge consumes nothing: "+id)
		var paid:=e.craft("upgrade",id+"@2","",e.revision)
		check(paid.ok and paid.output==id+"@3" and e.gold==200-Progression.paid_cost(Economy.PRICES[id],2),"Paid support upgrade uses existing one-step cost: "+id)
	for token in ["fan@0","fan@5","fan@01","fan@-1","fan@1@1","impact@1","expire@4","storm_spear@1"]:
		check(not Spells.has_part(token),"Reject noncanonical/support-ineligible rank: "+token)
	var e:=Economy.new()
	e.inventory={"fan@4":1,"seek@4":1,"impact":1}
	e.gold=200
	check(not e.craft_quote("fuse","fan@4","seek@4").ok and not e.craft_quote("upgrade","impact").ok,"Supports cannot become attack fusions and connectors cannot upgrade")
	check(not e.craft_quote("merge","fan@4","seek@4").ok,"Different support types cannot merge")

	# Balance v3 values are explicit in docs/TWO-ORB-BALANCE-v1.md; the five count/rank cases still exercise the published formulas.
	var cases: Array = [[0],[0,0],[2],[1,1],[4,0]]
	var expected := {
		"fan":[0.40,0.16,0.50,0.2025,0.24],
		"seek":[1.0,1.5,1.5,2.0,2.5],
		"pierce":[1.0,1.0,1.2,1.1,1.2],
		"bounce":[0.5,0.5,0.55,0.525,0.55],
		"giant":[1.6,2.56,1.76,2.688,2.816],
		"charge":[3.0,9.0,3.6,9.9,10.8],
		"sigil":[1.0,2.0,1.3,2.3,2.6]
	}
	for id in expected:
		for i in cases.size():
			var parts: Array=cases[i].map(func(r):return Progression.key(id,r))
			var stats:=profile(parts,id)
			check(is_equal_approx(stats.value,expected[id][i]),"Mixed support count/rank formula: "+id+str(cases[i]))
	check(profile(["echo@4","echo"],"echo").repeats==[0.55,0.35],"Each echo copy retains its rank and strongest repeat is scheduled first")
	check(profile(["echo","echo@4"],"echo")==profile(["echo@4","echo"],"echo"),"Reordering identical supports with different ranks preserves combined effect")
	check(is_equal_approx(Spells.interval(Spells.compile(["giant@4","charge@4","bolt"]).stages),.48*1.2*2.5),"Support ranks do not add cooldown penalties beyond equipped counts")
	var scoped:=Spells.compile(["fan","bolt","fan@4","impact","bloom"])
	check(is_equal_approx(Spells.Effects.value(scoped.stages[0],"fan"),.40) and is_equal_approx(Spells.Effects.value(scoped.stages[1],"fan"),.24),"Each attack and linked child uses only its own right-side scope")

	fresh()
	emit(["fan@4","bolt"])
	check(g.projectiles.size()==3 and is_equal_approx(g.projectiles[0].damage,13.2),"Ranked fan affects actual damage while preserving three branches")
	fresh()
	emit(["giant@4","bolt"])
	check(is_equal_approx(g.projectiles[0].radius,9.6),"Ranked giant changes real collision radius")
	fresh()
	emit(["charge@4","bolt"])
	check(is_equal_approx(g.projectiles[0].damage,92.4),"Ranked charge scales actual damage exactly once")
	fresh()
	var target=enemy(Vector2(640,530))
	emit(["seek","bolt"])
	g.magic.update_projectiles(.01)
	check(g.projectiles[0].target==null,"Base homing cannot acquire the distant test target")
	g.clear_magic()
	emit(["seek@4","bolt"])
	g.magic.update_projectiles(.01)
	check(g.projectiles[0].target==target and g.projectiles[0].dir.y>0,"Ranked homing acquires and turns toward a genuinely reachable distant target")
	fresh()
	var first=enemy(Vector2(420,330))
	var second=enemy(Vector2(540,330))
	var third=enemy(Vector2(660,330))
	emit(["pierce@4","bolt"])
	tick(.9)
	check(is_equal_approx(10000-first.hp,22) and is_equal_approx(10000-second.hp,30.8) and is_equal_approx(10000-third.hp,30.8),"Pierce rank affects post-first contacts without buffing the first hit")
	fresh()
	first=enemy(Vector2(420,330)); second=enemy(Vector2(540,330)); third=enemy(Vector2(660,330))
	emit(["pierce@4","bloom"])
	tick(1.4)
	check(is_equal_approx(10000-first.hp,20) and is_equal_approx(10000-second.hp,28) and is_equal_approx(10000-third.hp,28),"Piercing flower applies rank to later explosions, not a generic attack rank")
	fresh()
	first=enemy(Vector2(420,330)); second=enemy(Vector2(490,330)); third=enemy(Vector2(560,330))
	emit(["pierce@4","boomerang"])
	tick(1.5)
	check(is_equal_approx(10000-first.hp,57.6) and is_equal_approx(10000-second.hp,67.2) and is_equal_approx(10000-third.hp,57.6),"Returning projectile resets first-contact rank bonus per leg")
	for attack in ["vortex","thorn"]:
		fresh()
		emit(["pierce@4",attack])
		var p: Dictionary=g.projectiles[0]
		for i in 3:
			p.pos=Vector2(500+i*100,330)
			g.magic.install(p,1)
		var damage:=0.0
		var mass:=0.0
		var child:=0.0
		for zone in g.magic.zones:
			damage+=zone.damage
			mass+=zone.factor
			child+=zone.child_factor
		check(g.magic.zones.size()==3 and is_equal_approx(damage,(2.5 if attack=="vortex" else 45)*1.4) and is_equal_approx(mass,1) and is_equal_approx(child,.65),"Piercing installation rank improves damage without duplicating growth or payload budget: "+attack)
	fresh()
	for i in 6: enemy(Vector2(350+i*20,330))
	emit(["pierce@4","frost"])
	check(is_equal_approx(10000-g.enemies[0].hp,10) and is_equal_approx(10000-g.enemies[4].hp,14),"Cold cone rank improves only the additional piercing targets")
	for attack in ["thunder","satellite","ember_path"]:
		fresh()
		var at:=Vector2(420,330)
		if attack=="satellite": at=Vector2(395,335)
		if attack=="ember_path": at=Vector2(300,330)
		first=enemy(at); second=enemy(at+Vector2(120,0)); third=enemy(at+Vector2(240,0))
		emit(["pierce@4",attack])
		tick(.6)
		var expected_damage: float={"thunder":25.2,"satellite":12.6,"ember_path":3.85}[attack]
		check(is_equal_approx(10000-second.hp,expected_damage) and is_equal_approx(10000-third.hp,expected_damage),"Ranked support reaches the existing directional extension: "+attack)
	fresh()
	first=enemy(Vector2(420,330)); second=enemy(Vector2(550,415)); third=enemy(Vector2(670,415))
	emit(["bounce@4","bolt"])
	tick(.4)
	check(is_equal_approx(10000-second.hp,13.2) and is_equal_approx(10000-third.hp,7.92) and total("stage_casts")==1,"Ranked chain is 60 then 36 percent without generating new spells")
	fresh()
	first=enemy(Vector2(420,330))
	emit(["echo@4","bolt"])
	tick(.7)
	check(is_equal_approx(10000-first.hp,34.1) and total("stage_casts")==2 and g.magic.echoes.is_empty(),"Ranked echo fires one 55-percent real repeat without self-repeating")
	fresh()
	first=enemy(Vector2(420,330))
	emit(["sigil@4","bolt"])
	tick(.4)
	var status: Dictionary=g.magic.behavior.state_for(first)
	check(is_equal_approx(status.mark_mass,1.6) and is_equal_approx(10000-first.hp,18.7),"Ranked sigil increases actual marks with unchanged direct penalty")
	var c: Dictionary=g.magic.behavior.context(Spells.compile(["sigil@4","bolt"]).stages[0],g.player.position,Vector2.RIGHT,{},1,1,"primary",false,900,g.magic.generation)
	for i in 3:
		g.magic.behavior.clock+=.26
		g.magic.behavior.add_marks(status,c,first.position)
	check(is_equal_approx(status.casts[900].mass,3.2),"Ranked sigil preserves the per-lineage ceiling across repeated hits")
	fresh()
	first=enemy(Vector2(420,330))
	status=g.magic.behavior.state_for(first)
	for rank in [1,4,4]:
		var stage: Dictionary=Spells.compile([Progression.key("sigil",rank),"bolt"]).stages[0]
		var mark: Dictionary=g.magic.behavior.context(stage,g.player.position,Vector2.RIGHT,{},1,1,"chain",false,901,g.magic.generation)
		g.magic.behavior.clock+=.26
		g.magic.behavior.add_marks(status,mark,first.position)
	check(is_equal_approx(status.casts[901].mass,3.2) and is_equal_approx(status.casts[901].limit,3.2),"Mixed sigil ranks share the maximum lineage ceiling instead of resetting it")
	fresh()
	var program: Dictionary=emit(["fan@4","echo@4","charge@4","storm_spear"])
	var parent: Dictionary=g.projectiles[0]
	g.magic.fusion.event(parent,"impact",Vector2(420,330))
	var strike: Dictionary=g.magic.behavior.strikes[0]
	check(strike.points.size()==1 and g.magic.echoes.size()==1 and is_equal_approx(36*g.magic.behavior.damage_scale(strike),36*1.8*.60*.65*4.2),"Intrinsic fusion disables cached fan/echo and applies ranked charge once")

	fresh([["fan@2","bolt"],["fan@2","bloom"]])
	g.economy.gold=100
	g.state="shop";g.shop_time=60
	g.active_orb=1;g.recipe=g.orb_recipes[1].duplicate();g.draft=g.recipe.duplicate()
	check(g.craft_spell("merge","fan@2","fan@2",g.economy.revision),"Equipped supports in both orbs can merge")
	check(g.orb_recipes==[["bolt"],["fan@4","bloom"]] and g.economy.inventory.get("fan@4",0)==1 and g.economy.gold==100,"Cross-orb merge replaces target and consumes only real material")
	fresh([["fan@2","bolt"],["fan@2","bloom"]])
	g.economy.inventory["fan@2"]=3
	g.state="shop";g.shop_time=60
	check(g.craft_spell("merge","fan@2","fan@2",g.economy.revision) and g.orb_recipes[1]==["fan@2","bloom"],"Spare support material is used before another orb's equipped copy")
	fresh([["bolt","impact","fan","bloom"],["fan","bolt"]])
	g.state="shop";g.shop_time=60
	check(g.craft_spell("merge","fan","fan",g.economy.revision) and g.orb_recipes[0]==["bolt","impact","fan@1","bloom"] and g.orb_recipes[1]==["bolt"],"Consuming a support never removes the surrounding attack connector")
	fresh([["fan","bolt","fan","bloom"],[]])
	g.economy.gold=100
	g.state="shop";g.shop_time=60
	g.ui.show_shop()
	g.ui.inspect_item("fan",0,2)
	await process_frame
	await process_frame
	var preview: Node=g.ui.modal.find_child("ForgeEffectPreview",true,false)
	check(preview!=null and "꽃폭탄" in preview.tooltip_text and "별빛탄" in preview.tooltip_text,"Merge preview includes the earlier support consumed as material and its lost scope")
	var paid_button: Node=g.ui.modal.find_child("ForgePaid",true,false)
	check(paid_button!=null and "꽃폭탄" in paid_button.tooltip_text and not "별빛탄" in paid_button.tooltip_text,"Paid preview affects only the selected duplicate slot's right-side scope")
	var stale: Dictionary=g.board_data("fan",0,2)
	check(g.craft_spell("upgrade","fan","",g.economy.revision) and g.orb_recipes[0]==["fan","bolt","fan@1","bloom"],"Paid upgrade targets inspected duplicate slot rather than the first matching support")
	check(not g.board_drop(stale,1,0) and g.edit_history.is_empty(),"Support crafting invalidates stale drags and consumed-item Undo")
	check(g.start_trial(),"Upgraded supports immediately enter firing trial")
	g.orb_clocks=[0.0,0.0]
	g._tick_orbs(.001)
	g._tick_orbs(.121)
	check(g.projectiles.any(func(p):return p.attack=="bloom" and is_equal_approx(p.damage,3.6)),"Trial uses current combined base and upgraded fan factors")
	var wave_time: float=g.wave_time
	var shop_time: float=g.shop_time
	g._physics_process(.1)
	check(g.wave_time==wave_time and g.shop_time==shop_time,"Support trial leaves wave and shop progress frozen")
	g.end_trial()
	check(g.projectiles.is_empty() and g.magic.echoes.is_empty(),"Support trial clears scheduled effects on exit")
	fresh([["fan@1","bolt","fan","bloom"],[]])
	g.state="shop";g.shop_time=60;g.economy.gold=100
	g.ui.inspect_item("fan",0,2)
	check(g.craft_spell("upgrade","fan","",g.economy.revision) and g.ui.inspected_slot==2 and g.orb_recipes[0]==["fan@1","bolt","fan@1","bloom"],"Selection stays on upgraded slot even when an earlier slot already owns the output rank")
	fresh([["fan@4","bolt"],[]])
	g.economy.inventory["fan"]=1
	g.economy.gold=100
	g.state="shop";g.shop_time=60
	var stock: Dictionary=g.economy.inventory.duplicate()
	check(not g.craft_spell("merge","fan@4","fan",g.economy.revision) and g.economy.inventory==stock and g.economy.gold==100,"Visible over-cap support merge preserves equipped and spare items")
	fresh([["fan","bolt"],[]])
	g.state="shop";g.shop_time=60
	g.ui.show_shop()
	g.ui.inspect_item("fan",0,0)
	await process_frame
	await process_frame
	paid_button=g.ui.modal.find_child("ForgePaid",true,false)
	check(paid_button.disabled and "45.0%" in paid_button.tooltip_text and g.economy.gold==0,"Unaffordable upgrade still previews its real benefit without permitting payment")
	print("RESULT: %d checks, %d failures"%[checks,failures])
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
