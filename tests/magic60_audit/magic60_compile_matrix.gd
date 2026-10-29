extends SceneTree
const S = preload("res://scripts/spells.gd")
const P = preload("res://scripts/spell_progression.gd")
const C = preload("res://scripts/magic_catalog.gd")
const CHUNK := 5000
var attacks: Array = []
var modifiers: Array = []
var connectors: Array = []
var tokens: Array = []
var result := {"seed":20261030,"counts":{},"invalid":{},"errors":[],"elapsed_ms":{}}
var start_us := 0

func _initialize() -> void:
	call_deferred("run")

func check_compile(category: String, recipe: Array, expect_ok := true) -> void:
	var r: Dictionary = S.compile(recipe)
	result.counts[category] = int(result.counts.get(category,0))+1
	if expect_ok and not r.ok:
		result.invalid[category] = int(result.invalid.get(category,0))+1
		if result.errors.size()<12: result.errors.append({"category":category,"recipe":recipe,"error":r.get("error",""),"diagnostics":r.get("diagnostics",[])})

func save_progress(category: String) -> void:
	result["active_category"] = category
	result["updated_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open("res://artifacts/magic60_compile_matrix_progress.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"));f.close()

func _token(id: String, rank := 0) -> String:
	return P.key(id,rank)

func run() -> void:
	start_us = Time.get_ticks_usec()
	for id in S.PARTS:
		match S.PARTS[id].kind:
			"attack": attacks.append(id)
			"modifier": modifiers.append(id)
			"connector": connectors.append(id)
	for id in P.FUSIONS:
		match P.fusion_kind(id):
			"attack": attacks.append(id)
			"modifier": modifiers.append(id)
			"connector": connectors.append(id)
	attacks.sort();modifiers.sort();connectors.sort()
	tokens = C.PARTS.keys()
	for id in P.FUSIONS: tokens.append(id)
	tokens.sort()
	result["catalog"]={"total":tokens.size(),"attacks":attacks.size(),"modifiers":modifiers.size(),"connectors":connectors.size(),"token_ids":tokens}
	if tokens.size()!=60 or attacks.size()!=36 or modifiers.size()!=20 or connectors.size()!=4:
		result.errors.append({"catalog_mismatch":result.catalog})
	# Ordered token pairs; insert anchors so each pair is contained in a runnable context.
	for i in tokens.size():
		for j in tokens.size():
			var a: String=tokens[i];var b: String=tokens[j]
			# The anchor attacks make even trailing modifiers and adjacent connectors runnable.
			var recipe: Array=["bolt",a,"bloom",b,"fireball"]
			check_compile("ordered_pairs",recipe)
	result.elapsed_ms["ordered_pairs"]=(Time.get_ticks_usec()-start_us)/1000.0;save_progress("attack_modifier")
	# All 36x20 rank 0 and rank 3 combinations: compile each twice.
	for a in attacks:
		for m in modifiers:
			check_compile("attack_modifier",[_token(m),_token(a)])
			check_compile("attack_modifier",[_token(m,3),_token(a,3)])
	result.elapsed_ms["attack_modifier"]=(Time.get_ticks_usec()-start_us)/1000.0;save_progress("double_modifiers")
	# 36x20x20 with rank 0 and rank 3 at both modifier positions.
	var work := 0
	for a in attacks:
		for m1 in modifiers:
			for m2 in modifiers:
				check_compile("double_modifiers",[_token(m1),_token(m2),_token(a)])
				check_compile("double_modifiers",[_token(m1,3),_token(m2,3),_token(a,3)])
				work+=2
				if work%CHUNK==0:
					save_progress("double_modifiers");await process_frame
	result.elapsed_ms["double_modifiers"]=(Time.get_ticks_usec()-start_us)/1000.0;save_progress("attack_connector_attack")
	# 36x4x36 compile matrix, rank 0; event injection tracked separately by live tests.
	work=0
	for a in attacks:
		for c in connectors:
			for b in attacks:
				check_compile("attack_connector_attack",[_token(a),c,_token(b)])
				work+=1
				if work%CHUNK==0:
					save_progress("attack_connector_attack");await process_frame
	result.elapsed_ms["attack_connector_attack"]=(Time.get_ticks_usec()-start_us)/1000.0;save_progress("triple_chain")
	# 36x4x36x4x36 = 746,496 compile inputs. Check all compile and link nesting.
	work=0
	for a in attacks:
		for c1 in connectors:
			for b in attacks:
				for c2 in connectors:
					for d in attacks:
						var r: Dictionary=S.compile([_token(a),c1,_token(b),c2,_token(d)])
						result.counts["triple_chain"] = int(result.counts.get("triple_chain",0))+1
						if not r.ok or r.stages.size()!=3 or r.stages[0].next.is_empty() or r.stages[0].next.next.is_empty():
							result.invalid["triple_chain"] = int(result.invalid.get("triple_chain",0))+1
							if result.errors.size()<12: result.errors.append({"category":"triple_chain","recipe":[a,c1,b,c2,d],"ok":r.ok,"stages":r.stages.size(),"error":r.get("error","")})
						work+=1
						if work%CHUNK==0:
							save_progress("triple_chain");await process_frame
							if work%50000==0: print("TRIPLE_PROGRESS "+str(work)+"/746496")
	result.elapsed_ms["triple_chain"]=(Time.get_ticks_usec()-start_us)/1000.0;save_progress("seeded_8_slots")
	# Deterministic 50,000 recipes: four attacks, three links, one support; retain fixed slot order.
	seed(20261030)
	for n in 50000:
		var recipe: Array=[_token(attacks[randi_range(0,attacks.size()-1)],randi_range(0,3)),connectors[randi_range(0,connectors.size()-1)],_token(attacks[randi_range(0,attacks.size()-1)],randi_range(0,3)),connectors[randi_range(0,connectors.size()-1)],_token(modifiers[randi_range(0,modifiers.size()-1)],randi_range(0,3)),_token(attacks[randi_range(0,attacks.size()-1)],randi_range(0,3)),connectors[randi_range(0,connectors.size()-1)],_token(attacks[randi_range(0,attacks.size()-1)],randi_range(0,3))]
		check_compile("seeded_8_slots",recipe)
		if (n+1)%CHUNK==0: save_progress("seeded_8_slots");await process_frame
	result.elapsed_ms["seeded_8_slots"]=(Time.get_ticks_usec()-start_us)/1000.0
	result["status"]="complete"
	result["total_compile_calls"]=0
	for key in result.counts: result.total_compile_calls+=int(result.counts[key])
	save_progress("complete")
	var f := FileAccess.open("res://artifacts/magic60_compile_matrix.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"));f.close()
	print("MATRIX_DONE "+JSON.stringify({"counts":result.counts,"invalid":result.invalid,"elapsed_ms":result.elapsed_ms,"total":result.total_compile_calls}))
	quit(1 if not result.errors.is_empty() else 0)
