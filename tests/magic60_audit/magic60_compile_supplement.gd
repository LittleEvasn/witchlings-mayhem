extends SceneTree
const S = preload("res://scripts/spells.gd")
const P = preload("res://scripts/spell_progression.gd")
const C = preload("res://scripts/magic_catalog.gd")
const CHUNK := 5000
var attacks: Array=[];var modifiers: Array=[];var connectors: Array=[];var tokens: Array=[]
var data := {"seed":20261030,"counts":{},"failures":[],"elapsed_ms":{}}
var started := 0
func _initialize() -> void: call_deferred("run")
func call_compile(key: String, recipe: Array) -> void:
	var r: Dictionary=S.compile(recipe)
	data.counts[key]=int(data.counts.get(key,0))+1
	if not r.ok:
		data["failures_count"]=int(data.get("failures_count",0))+1
		if data.failures.size()<20: data.failures.append({"category":key,"recipe":recipe,"error":r.get("error",""),"diagnostics":r.get("diagnostics",[])})
func save_progress(phase: String) -> void:
	data["phase"]=phase
	var f:=FileAccess.open("res://artifacts/magic60_compile_supplement_progress.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"\t"));f.close()
func token(id: String,rank:=0)->String: return P.key(id,rank)
func random_attack() -> String:
	var id:String=attacks[randi_range(0,attacks.size()-1)]
	return token(id,0 if P.is_fused(id) else randi_range(0,3))
func random_modifier() -> String:
	var id:String=modifiers[randi_range(0,modifiers.size()-1)]
	return token(id,0 if P.is_fused(id) else randi_range(0,3))
func run() -> void:
	started=Time.get_ticks_usec()
	for id in S.PARTS:
		match S.PARTS[id].kind:
			"attack":attacks.append(id)
			"modifier":modifiers.append(id)
			"connector":connectors.append(id)
	for id in P.FUSIONS:
		match P.fusion_kind(id):
			"attack":attacks.append(id)
			"modifier":modifiers.append(id)
			"connector":connectors.append(id)
	attacks.sort();modifiers.sort();connectors.sort()
	for id in C.PARTS: tokens.append(id)
	for id in P.FUSIONS: tokens.append(id)
	tokens.sort()
	data["catalog"]={"total":tokens.size(),"attacks":attacks.size(),"modifiers":modifiers.size(),"connectors":connectors.size()}
	for a in tokens:
		for b in tokens:
			call_compile("ordered_pairs",["bolt",a,"bloom",b,"fireball"])
	data.elapsed_ms["ordered_pairs"]=(Time.get_ticks_usec()-started)/1000.0;save_progress("attack_modifier")
	for a in attacks:
		for m in modifiers:
			call_compile("attack_modifier_base",[token(m),token(a)])
			call_compile("attack_modifier_rank3",[token(m,0 if P.is_fused(m) else 3),token(a,0 if P.is_fused(a) else 3)])
	data.elapsed_ms["attack_modifier"]=(Time.get_ticks_usec()-started)/1000.0;save_progress("double_modifiers")
	var work:=0
	for a in attacks:
		for m1 in modifiers:
			for m2 in modifiers:
				call_compile("double_modifiers_base",[token(m1),token(m2),token(a)])
				call_compile("double_modifiers_rank3",[token(m1,0 if P.is_fused(m1) else 3),token(m2,0 if P.is_fused(m2) else 3),token(a,0 if P.is_fused(a) else 3)])
				work+=1
				if work%CHUNK==0: save_progress("double_modifiers");await process_frame
	data.elapsed_ms["double_modifiers"]=(Time.get_ticks_usec()-started)/1000.0;save_progress("seeded_8_slots")
	seed(20261030)
	for i in 50000:
		call_compile("seeded_8_slots",[random_attack(),connectors[randi_range(0,3)],random_attack(),connectors[randi_range(0,3)],random_modifier(),random_attack(),connectors[randi_range(0,3)],random_attack()])
		if (i+1)%CHUNK==0: save_progress("seeded_8_slots");await process_frame
	data.elapsed_ms["seeded_8_slots"]=(Time.get_ticks_usec()-started)/1000.0
	data["status"]="complete"
	data["total_compile_calls"]=0
	for k in data.counts: data.total_compile_calls+=data.counts[k]
	save_progress("complete")
	var f:=FileAccess.open("res://artifacts/magic60_compile_supplement.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"\t"));f.close()
	print("SUPPLEMENT_DONE "+JSON.stringify({"counts":data.counts,"failures":data.get("failures_count",0),"elapsed_ms":data.elapsed_ms,"total":data.total_compile_calls}))
	quit(1 if int(data.get("failures_count",0))>0 else 0)
