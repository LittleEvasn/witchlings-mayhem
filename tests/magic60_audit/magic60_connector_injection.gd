extends SceneTree
const S=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Profile=preload("res://scripts/player_profile.gd")
const CHUNK:=144
var g:Node2D
var attacks:Array=[];var connectors:Array=[]
var totals={"attempted_sources":0,"injected_events":0,"expected_events":0,"observed_triggers":0,"mismatches":0,"compile_failures":0}
var examples:Array=[]
func _initialize()->void:call_deferred("run")
func key(id:String)->String:return id if P.is_fused(id) else P.key(id,0)
func run()->void:
	root.size=Vector2i(1920,1080);g=load("res://scenes/main.tscn").instantiate();g.record_runs=false;g.profile=Profile.new("user://magic60_connector_injection_unused.json");root.add_child(g);current_scene=g;await process_frame;g.start_run("sigil");g.set_physics_process(false);g.sound_enabled=false;g.director.enabled=false;g.encounters.enabled=false;g.invincible=9999
	for id in S.PARTS:
		if S.PARTS[id].kind=="attack":attacks.append(id)
		if S.PARTS[id].kind=="connector":connectors.append(id)
	for id in P.FUSIONS:
		if P.fusion_kind(id)=="attack":attacks.append(id)
		if P.fusion_kind(id)=="connector":connectors.append(id)
	attacks.sort();connectors.sort()
	for a in attacks:
		for connector in connectors:
			for b in attacks:
				g.clear_magic();g.meter=load("res://scripts/combat_meter.gd").new();g.meter.detailed_sources=true;g.state="combat";g.player.position=Vector2(800,450);g.aim=Vector2.RIGHT
				var compiled:Dictionary=S.compile([key(a),connector,key(b)])
				totals.attempted_sources+=1
				if not compiled.ok or S.roots(compiled.stages).is_empty():totals.compile_failures+=1;continue
				var stage:Dictionary=S.roots(compiled.stages)[0]
				var source:Dictionary=g.magic.behavior.context(stage,g.player.position,Vector2.RIGHT,S.follow(stage),1.0,1.0,"primary",false,-1,g.magic.generation)
				var events:Array=["impact","expire"] if connector=="dual_event" else ["timer" if connector=="timer" else connector]
				totals.expected_events+=events.size()
				for event in events:g.magic.trigger(source,g.player.position,event);totals.injected_events+=1
				var observed:int=int(g.meter.totals.get("triggers",0));totals.observed_triggers+=observed
				if observed!=events.size():totals.mismatches+=1;if examples.size()<20:examples.append({"recipe":[a,connector,b],"events":events,"observed":observed,"totals":g.meter.totals.duplicate()})
				g.clear_magic()
				if totals.attempted_sources%CHUNK==0:print("EVENT_INJECTION_PROGRESS "+str(totals.attempted_sources)+"/5184");await process_frame
	var f:=FileAccess.open("res://artifacts/magic60_connector_injection.json",FileAccess.WRITE);f.store_string(JSON.stringify({"classification":"synthetic runtime trigger injection only; not natural impact/expiry/timer occurrence","catalog":{"attacks":attacks.size(),"connectors":connectors.size()},"totals":totals,"mismatch_examples":examples},"\t"));f.close();print("EVENT_INJECTION_DONE "+JSON.stringify(totals));g.queue_free();await process_frame;quit(1 if totals.compile_failures>0 or totals.mismatches>0 else 0)
