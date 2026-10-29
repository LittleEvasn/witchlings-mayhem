extends SceneTree
const S=preload("res://scripts/spells.gd")
const Profile=preload("res://scripts/player_profile.gd")
var checks:=0
var failures:=0
var g: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func cast(parts: Array) -> Dictionary:
	g.clear_magic()
	var stage: Dictionary=S.roots(S.compile(parts).stages)[0]
	g.magic.emit(stage,Vector2(700,400),Vector2.RIGHT,S.follow(stage),1.0)
	return g.projectiles[0]
func run() -> void:
	root.size=Vector2i(1600,900)
	var mods: Array=S.PARTS.keys().filter(func(id):return S.PARTS[id].kind=="modifier")
	for id in S.Progression.FUSIONS:
		if S.Progression.fusion_kind(id)=="modifier": mods.append(id)
	for edge in ["impact","expire","dual_event","timer"]:
		for id in mods:
			var result:=S.compile([id,"bolt",edge,"bloom"])
			check(result.ok and result.stages[0].modifiers.size()==1 and result.stages[0].next.modifiers.is_empty(),"No modifier crosses "+edge+": "+id)
			result=S.compile(["bolt",edge,id,"bloom"])
			check(result.ok and result.stages[0].modifiers.is_empty() and result.stages[0].next.modifiers[0].id==id,"Modifier after edge applies directly to child: "+edge+"/"+id)
	var r:=S.compile(["giant","bolt","bloom"])
	check(r.ok and r.stages.all(func(s):return s.giant==1),"Independent attacks share support within one scope")
	r=S.compile(["giant","bolt","impact","bloom","expire","echo","thunder"])
	check(r.ok and r.stages[0].giant==1 and r.stages[1].modifiers.is_empty() and r.stages[2].echo==1 and r.stages[2].giant==0,"Every multistage edge resets scope independently")
	check(S.affected_slots(["giant","bolt","impact","bloom","expire","echo","thunder"],0)==[1] and S.affected_slots(["giant","bolt","impact","bloom","expire","echo","thunder"],5)==[6],"Highlight equals actual source indices")
	r=S.compile(["bolt","giant","impact","bloom"])
	check(S.slot_diagnostic(r,1).code=="unused_modifier" and r.stages.size()==2,"Unconsumed support before edge is grey without blocking valid attacks")
	r=S.compile(["giant","","bolt","impact","","echo","","bloom"])
	check(r.ok and r.stages[0].next.slot==7 and r.stages[0].next.giant==0 and r.stages[0].next.echo==1,"Empty slots preserve positions and scope")
	r=S.compile(["giant","bolt","impact","expire","bloom","thunder"])
	check(not r.ok and S.roots(r.stages).map(func(s):return s.attack)==["bolt","thunder"] and r.stages.back().giant==0,"Invalid connectors still terminate support and allow valid recovery")
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	g.profile=Profile.new("user://connector-scope-test-unused.json")
	root.add_child(g)
	current_scene=g
	await process_frame
	g.start_run("sigil")
	g.set_physics_process(false)
	g.sound_enabled=false
	for edge in ["impact","expire"]:
		var source:=cast(["giant","echo","bolt",edge,"bloom"])
		check(is_equal_approx(source.radius,8.0) and g.magic.echoes.size()==1,"Root gets its own size and one echo: "+edge)
		g.magic.trigger(source,Vector2(750,400),edge)
		var child: Dictionary=g.projectiles.back()
		check(child.attack=="bloom" and is_equal_approx(child.radius,8.0) and child.stage.echo==0 and g.magic.echoes.size()==1,"Actual child has base size and no inherited repeat: "+edge)
		var emitted: int=g.projectiles.size()
		g.magic.trigger(source,Vector2(750,400),edge)
		check(g.projectiles.size()==emitted,"First event still fires once: "+edge)
		g.magic.update_echoes(.2)
		var copy: Dictionary=g.projectiles.back()
		check(g.projectiles.size()==3 and copy.attack=="bolt" and copy.follow.is_empty(),"Root echo repeats only its attack: "+edge)
		g.magic.trigger(copy,Vector2(800,400),edge)
		check(g.projectiles.size()==3 and g.magic.echoes.is_empty(),"Echo cannot repeat child chain: "+edge)
		if edge=="impact":
			check(is_equal_approx(child.damage,10.0),"Original connector potency remains 50 percent")
	var source:=cast(["bolt","impact","giant","echo","bloom"])
	g.magic.trigger(source,Vector2(750,400))
	check(g.projectiles.back().stage.giant==1 and is_equal_approx(g.projectiles.back().radius,12.8) and g.magic.echoes.size()==1,"Explicit child support works in production runtime")
	g.magic.update_echoes(.2)
	check(g.projectiles.size()==3 and g.projectiles.back().attack=="bloom" and g.magic.echoes.is_empty(),"Explicit child echo repeats once")
	source=cast(["echo","bolt","impact","echo","bloom"])
	g.magic.trigger(source,Vector2(750,400))
	g.magic.update_echoes(.2)
	check(g.projectiles.size()==4 and g.projectiles.filter(func(p):return p.attack=="bloom").size()==2,"Separate parent/child echoes do not multiply")
	source=cast(["echo","bolt","expire","bloom"])
	g.clear_magic()
	g.magic.update_echoes(1.0)
	check(g.projectiles.is_empty() and g.magic.echoes.is_empty(),"Forced cleanup cancels repeats without child spells")
	g.queue_free()
	await process_frame
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
