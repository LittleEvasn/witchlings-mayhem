extends RefCounted
const Progression = preload("res://scripts/spell_progression.gd")
const Effects = preload("res://scripts/modifier_effects.gd")
## Sparse program: right-side modifiers stop at each event connector.
## Compile once when the player changes their recipe, never for each projectile.
const PARTS = {
	"bolt": {"name":"별빛탄", "symbol":"✦", "kind":"attack", "color":Color("a8efe2"), "desc":"빠른 탄환 · 직접 맞힌 적에게 피해"},
	"bloom": {"name":"꽃폭탄", "symbol":"✺", "kind":"attack", "color":Color("ffc79f"), "desc":"닿으면 폭발 · 주변 적에게 범위 피해\n별빛탄보다 느린 시전"},
	"boomerang": {"name":"달빛 부메랑", "symbol":"☾", "kind":"attack", "color":Color("b8c9ff"), "desc":"호를 그리며 비행 · 도탄 소진 시 즉시 귀환\n같은 시전에서 같은 적 재타격 없음"},
	"vortex": {"name":"소용돌이 씨앗", "hud_name":"소용돌이", "symbol":"◎", "kind":"attack", "color":Color("c6a3ff"), "desc":"설치 후 적을 모으며 지속 피해\n같은 곳에 모아 심으면 범위 성장 · 보스 끌림 없음"},
	"thorn": {"name":"가시꽃 덫", "symbol":"❀", "kind":"attack", "color":Color("b8ed9a"), "desc":"적이 다가오면 터지는 덫\n6초 유지 · 같은 곳에 모아 심으면 범위 성장"},
	"fan": {"name":"갈래", "symbol":"⋔", "kind":"modifier", "color":Color("dfb6f5"), "desc":"뒤 공격에 갈래 추가 · 기본 단발은 3갈래\n오른쪽 각 주문에 한 번씩 적용 · 중복 시 갈래 증가"},
	"seek": {"name":"추적", "symbol":"◎", "kind":"modifier", "color":Color("a8efe2"), "desc":"가까운 적을 따라 조준·이동\n공격의 형태를 유지하며 추적"},
	"pierce": {"name":"관통", "symbol":"»", "kind":"modifier", "color":Color("f7dfa1"), "desc":"진행 방향의 적 2명까지 추가 타격\n탄은 관통 · 설치 씨앗은 위력을 나눠 배치"},
	"bounce": {"name":"연쇄", "symbol":"↝", "kind":"modifier", "color":Color("ffd99c"), "desc":"첫 피해 뒤 다른 적 최대 2명에게 연쇄\n홉마다 위력 50% · 주문·연결은 다시 만들지 않음"},
	"giant": {"name":"거대화", "symbol":"＋", "kind":"modifier", "color":Color("ffb1c6"), "desc":"크기·범위 ×1.6\n한 바퀴 후 대기 ×1.2"},
	"echo": {"name":"메아리", "symbol":"≋", "kind":"modifier", "color":Color("a5d9ff"), "desc":"0.18초 뒤 위력 35%로 재시전\n복사본은 다시 복제하지 않음"},
	"impact": {"name":"명중 후", "symbol":"→", "kind":"connector", "color":Color("ff9cae"), "desc":"첫 명중 지점에서 뒤 마법을 한 번 시전\n주문 개체당 첫 유효 명중 한 번 · 다단계 연결 가능"},
	"charge": {"name":"응축","kind":"modifier","symbol":"✧","color":Color("ffd99c"),"desc":"한 바퀴 후 대기 ×2.5 · 해당 단계 피해 ×3\n상태와 성장량은 증가하지 않음"},
	"frost": {"name":"서리숨결","kind":"attack","symbol":"✧","color":Color("b8eaff"),"desc":"냉기 3이면 얼림 · 보스는 얼음 껍질\n다른 직접 공격으로 깨면 추가 피해 · 동결 해제"},
	"thunder": {"name":"벼락","kind":"attack","symbol":"✧","color":Color("ffe7a3"),"desc":"플레이어 주변 무작위 지점에 예고 후 낙뢰\n추적은 주변 적을 따라가다 낙하 직전에 고정"},
	"expire": {"name":"소멸 후","kind":"connector","symbol":"✧","color":Color("ff9cae"),"desc":"앞 주문이 정상 종료한 자리에서 후속 시전\n부메랑 귀환 시 현재 조준 방향으로 발사"},
	"satellite": {"name":"달무리 위성","kind":"attack","symbol":"✧","color":Color("b8c9ff"),"desc":"일정 거리를 도는 위성 · 궤도에서만 접촉 피해\n후속 주문이면 제자리에 공전"},
	"ember_path": {"name":"잔불 발자국","kind":"attack","symbol":"✧","color":Color("ffc79f"),"desc":"걸음마다 발밑에 원형 불장판을 남김\n정지 시 중첩 설치 안 함 · 겹친 피해는 최강만 적용"}
}
const ATTACK_INTERVALS := {"bolt":0.48,"bloom":0.576,"boomerang":0.624,"vortex":0.864,"thorn":0.72,"frost":0.6,"thunder":0.9,"satellite":1.1,"ember_path":1.0}

# Counts select geometry/repeats; rank data selects efficiency. See modifier_effects.gd.
const STACK_RULES := {
	"fan":{"rule":"add","per_copy":2,"text":"강화 단계별 추가 갈래 합산 · 각 위력은 분산"},
	"seek":{"rule":"add","per_copy":0.5,"text":"각 구체의 탐색 거리·회전 반응 합산"},
	"pierce":{"rule":"add","per_copy":2,"text":"각 구체의 추가 관통/설치 수 합산"},
	"bounce":{"rule":"add","per_copy":2,"text":"추가 대상 수 합산 · 거리 평균 · 홉마다 50%"},
	"giant":{"rule":"multiply","per_copy":1.6,"text":"각 구체의 범위 곱연산 · 대기 ×1.2씩"},
	"echo":{"rule":"add","per_copy":1,"text":"각 구체의 추가 반복·총 위력 합산"},
	"charge":{"rule":"multiply","per_copy":3.0,"text":"피해·범위·대기 곱연산 · 첫 밀침 합산"},
}
const MODIFIER_NOTES := {
	"fan":"고유 배치에 갈래 추가 · 강화는 갈래 수 증가",
	"seek":"가까운 적을 따라 조준·이동 · 강화는 추적 반응 증가",
	"pierce":"진행 경로의 적 추가 타격 · 씨앗은 위력을 나눠 설치",
	"bounce":"첫 피해 뒤 다른 적에게 연쇄 · 주문/연결 재생성 없음",
	"giant":"공격 크기·범위 확대 · 강화로 대기는 늘지 않음",
	"echo":"0.18초 간격으로 시전 재현 · 복사본은 재복제하지 않음",
	"charge":"느리고 강한 한 발 · 냉기·성장량은 그대로",
}
const SEQUENCE_GAP := 0.12
const SLOT_COUNT := 6
const MAX_SLOTS := 8

static func fixed_slots(recipe: Array, capacity := SLOT_COUNT) -> Array:
	var result := recipe.duplicate()
	while result.size()<capacity: result.append("")
	return result

static func fixed_bank(bank: Array) -> Array:
	return bank.map(func(row): return fixed_slots(row))

static func has_content(recipe: Array) -> bool:
	return recipe.any(func(id): return id!="")

static func blank_stage() -> Dictionary:
	var stage := {"connector":"", "modifiers":[], "slot":-1, "root":true, "next":{}}
	for id in STACK_RULES: stage[id] = 0
	return stage

static func copies(stage: Dictionary, id: String) -> int:
	return int(stage.get(id,0))

static func branches(stage: Dictionary) -> int:
	return 1+int(Effects.profile(stage,"fan").extra)

static func scale(stage: Dictionary) -> float:
	return Effects.value(stage,"giant")*float(Effects.profile(stage,"charge").size)*float(stage.get("_growth",1.0))*float(stage.get("rank_scale",1.0))*float(stage.get("_relic_scale",1.0))*float(stage.get("_support_scale",1.0))*float(stage.get("_orb_scale",1.0))

static func seek_strength(stage: Dictionary) -> float:
	return Effects.value(stage,"seek")

static func roots(stages: Array) -> Array:
	return stages.filter(func(stage): return stage.get("root",true))

static func follow(stage: Dictionary) -> Dictionary:
	return stage.get("next",{})

static func has_part(id: String) -> bool:
	if PARTS.has(id) or Progression.is_fused(id): return true
	var base := Progression.base_id(id)
	var level := Progression.rank(id)
	return PARTS.has(base) and PARTS[base].kind in ["attack","modifier","connector"] and level in range(1,4) and id==Progression.key(base,level)

static func definition(id: String) -> Dictionary:
	if not has_part(id):
		var old_base := Progression.base_id(id)
		if old_base=="sigil": return {"name":"각인 (이전 기록)","kind":"legacy","color":Color.GRAY,"desc":"삭제된 구체 · 새 실험에서 등장하지 않음"}
		if PARTS.has(old_base) and Progression.rank(id)==4: return {"name":PARTS[old_base].name+" +4 (이전 기록)","kind":"legacy","color":PARTS[old_base].color,"desc":"이전 버전 실험 기록"}
		return {"name":"알 수 없는 구체","kind":"unknown","color":Color.GRAY,"desc":""}
	if Progression.is_fused(id):
		var d: Dictionary = Progression.FUSIONS[id].duplicate()
		d["kind"] = Progression.fusion_kind(id)
		d.name += " ✧"
		d.desc += "\n완성 합성 · 추가 강화 없음"
		if d.kind=="modifier": d.desc += "\n오른쪽 공격에 적용 · 연결 구체를 넘지 않음"
		return d
	var d: Dictionary = PARTS[Progression.base_id(id)].duplicate()
	var level := Progression.rank(id)
	if level>0:
		d.name += " +%d" % level
		d["hud_name"] = d.name
	if d.kind=="modifier":
		var base := Progression.base_id(id)
		d.desc = MODIFIER_NOTES[base]+"\n"+modifier_token_text(id)+"\n오른쪽 공격에 적용 · 연결 구체를 넘지 않음\n중복: "+STACK_RULES[base].text
		if base=="echo": d.desc += "\n반복한 공격은 후속 연결을 다시 발동하지 않음"
	elif d.kind=="connector":
		d.desc += "\n후속 주문 위력 %.0f%% · 직접 후속에만 적용"%(Progression.connector_power(id)*100)
	else:
		d.desc += "\n"+Progression.attack_text(id)
	return d

static func upgradeable(id: String) -> bool:
	return has_part(id) and not Progression.is_fused(id) and definition(id).kind in ["attack","modifier","connector"]

static func populate_modifiers(stage: Dictionary) -> void:
	for mod in stage.modifiers:
		stage[mod.id]=int(stage.get(mod.id,0))+1
		if Progression.is_support(mod.id):
			for effect in Progression.FUSIONS[mod.id].get("effects",[]): stage[effect[0]]+=1

static func modifier_token_stage(id: String) -> Dictionary:
	var stage := blank_stage()
	var base := Progression.base_id(id)
	stage.modifiers = [Progression.modifier_record(id)]
	populate_modifiers(stage)
	stage["modifier_effects"] = Effects.resolve(stage)
	return stage

static func modifier_token_text(id: String) -> String:
	if Progression.is_support(id): return Progression.FUSIONS[id].desc
	return Effects.text(modifier_token_stage(id),Progression.base_id(id))

static func modifier_effect_text(stage: Dictionary, id: String) -> String:
	return Effects.text(stage,Progression.base_id(id))

static func interval(stages: Array) -> float:
	if stages.is_empty(): return 0.48
	var base := 0.0
	var giant := 0
	var charge := 0
	for stage in stages:
		base = maxf(base,float(stage.get("interval",ATTACK_INTERVALS[stage.attack])))
		giant = maxi(giant,copies(stage,"giant"))
		charge = maxi(charge,copies(stage,"charge"))
	return base*pow(1.2,giant)*pow(2.5,charge)

static func next_cast(stages: Array, cursor: int) -> Dictionary:
	var commands := roots(stages)
	if commands.is_empty(): return {}
	var index := posmod(cursor,commands.size())
	var next := (index+1)%commands.size()
	return {"stage":commands[index], "cursor":next, "delay":interval(stages) if next==0 else SEQUENCE_GAP}

static func invalid(message: String, index: int, nodes: Array = []) -> Dictionary:
	return {"ok":false,"error":message,"error_index":index,"stages":[],"nodes":nodes,"diagnostics":[],"runnable_count":0}

static func compile(recipe: Array) -> Dictionary:
	if recipe.size()>MAX_SLOTS: return invalid("이 오브는 최대 8칸이야.",MAX_SLOTS)
	var nodes: Array = []
	var modifiers: Array = []
	var all_modifiers: Array = []
	var pending: Array = []
	var last_attack := -1
	var blocked_payload := false
	var links: Dictionary = {}
	var diagnostics: Array = []
	var used_modifiers: Dictionary = {}
	for index in recipe.size():
		var id := str(recipe[index])
		if id.is_empty(): continue
		if not has_part(id):
			add_diagnostic(diagnostics,index,"unknown","알 수 없는 구체라 발동하지 않아요.")
			for slot in pending: add_diagnostic(diagnostics,slot,"missing_payload","연결 대상을 해석할 수 없어요.")
			blocked_payload = blocked_payload or not pending.is_empty()
			pending.clear()
			last_attack = -1
			continue
		var kind: String = definition(id).kind
		if kind=="modifier":
			var record := Progression.modifier_record(id)
			record["slot"] = index
			modifiers.append(record)
			all_modifiers.append(record)
		elif kind=="connector":
			# A connector starts a fresh modifier scope, even in an invalid draft.
			modifiers.clear()
			if last_attack<0:
				add_diagnostic(diagnostics,index,"missing_source","연결 앞에 공격이 없어 이 연결은 발동하지 않아요.")
			else: pending.append(index)
		else:
			var stage := blank_stage()
			var fused := Progression.is_fused(id)
			stage.attack = Progression.FUSIONS[id].base if fused else Progression.base_id(id)
			stage["source_id"] = id
			stage["rank_power"] = Progression.damage_multiplier(id)
			stage["rank_scale"] = Progression.scale_multiplier(id)
			stage["attack_profile"] = Progression.attack_profile(id)
			stage["fusion"] = id if fused else ""
			stage.slot = index
			stage.modifiers = modifiers.duplicate(true)
			stage.root = pending.is_empty() and not blocked_payload
			stage["_linked"] = not stage.root
			stage["disabled"] = blocked_payload or pending.size()>1 or (not pending.is_empty() and nodes[last_attack].disabled)
			populate_modifiers(stage)
			stage["modifier_effects"] = Effects.resolve(stage)
			if fused: stage["interval"] = Progression.FUSIONS[id].interval
			if stage.disabled:
				var reason := "앞 공격이 비활성이라 이 연결은 발동하지 않아요."
				if pending.size()>1: reason="연결 사이에 공격이 필요해요. 이 연결은 발동하지 않아요."
				elif blocked_payload: reason="앞 연결의 대상을 해석할 수 없어 이 후속 공격은 발동하지 않아요."
				for slot in pending: add_diagnostic(diagnostics,slot,"broken_chain" if pending.size()>1 else "inactive_source",reason)
				add_diagnostic(diagnostics,index,"blocked_payload",reason)
			elif not pending.is_empty():
				var connector_slot: int = pending[0]
				var connector: String = str(recipe[connector_slot])
				var previous: Dictionary = nodes[last_attack]
				previous.connector = Progression.base_id(connector)
				previous["connector_power"] = Progression.connector_power(connector)
				previous["connector_rank"] = Progression.rank(connector)
				previous["connector_slot"] = connector_slot
				links[last_attack] = nodes.size()
			if not stage.disabled:
				for entry in modifiers: used_modifiers[entry.slot] = true
			pending.clear()
			blocked_payload = false
			nodes.append(stage)
			last_attack = nodes.size()-1
	for slot in pending: add_diagnostic(diagnostics,slot,"missing_payload","연결 뒤에 공격이 없어 이 연결은 발동하지 않아요.")
	for entry in all_modifiers:
		if not used_modifiers.has(entry.slot): add_diagnostic(diagnostics,entry.slot,"unused_modifier","다음 연결 전까지 실행 가능한 공격이 없어 이 보조는 적용되지 않아요.","inactive")
	# Embed only the forward child; flat nodes retain their root flag for scheduling/UI.
	for index in range(nodes.size()-1,-1,-1):
		if links.has(index): nodes[index].next = nodes[links[index]].duplicate(true)
	var stages: Array = nodes.filter(func(stage): return not stage.disabled)
	return {"ok":diagnostics.is_empty(),"stages":stages,"nodes":nodes,"diagnostics":diagnostics,
		"error":"" if diagnostics.is_empty() else diagnostics[0].reason,
		"error_index":-1 if diagnostics.is_empty() else diagnostics[0].slot,"runnable_count":roots(stages).size()}

static func add_diagnostic(items: Array, slot: int, code: String, reason: String, severity := "error") -> void:
	items.append({"slot":slot,"code":code,"reason":"%d번 칸: %s"%[slot+1,reason],"severity":severity})

static func slot_diagnostic(result: Dictionary, slot: int) -> Dictionary:
	for item in result.get("diagnostics",[]):
		if item.slot==slot: return item
	return {}

static func affected_slots(recipe: Array, modifier_slot: int) -> Array:
	var affected: Array = []
	if modifier_slot<0 or modifier_slot>=recipe.size() or not has_part(str(recipe[modifier_slot])) or definition(str(recipe[modifier_slot])).kind!="modifier": return affected
	for stage in compile(recipe).stages:
		if stage.modifiers.any(func(entry):return entry.slot==modifier_slot): affected.append(stage.slot)
	return affected

static func describe(recipe: Array) -> String:
	var result := compile(recipe)
	if result.stages.is_empty(): return result.error if not result.ok else "빈 오브 · 공격 구체를 넣으면 발사해요."
	var chunks: PackedStringArray = []
	for stage in result.stages:
		var names: PackedStringArray = []
		var variants := {}
		for entry in stage.modifiers:
			var token := Progression.key(entry.id,entry.rank)
			variants[token] = int(variants.get(token,0))+1
		for token in variants:
			var count: int = variants[token]
			names.append(definition(token).name+("×%d"%count if count>1 else ""))
		var text: String = definition(stage.source_id).name
		if not names.is_empty(): text = "/".join(names)+" "+text
		if not chunks.is_empty():
			var previous: Dictionary = result.stages[chunks.size()-1]
			text = (" — "+definition(previous.connector).name+" → " if not stage.root else " → 순차 → ")+text
		chunks.append(text)
	return "".join(chunks)+("  ·  ! "+result.error if not result.ok else "")

static func compatible(mod: String, attack: String) -> bool:
	return has_part(mod) and definition(mod).kind=="modifier" and has_part(attack) and definition(attack).kind=="attack"

static func tags(id: String) -> Array:
	if Progression.is_fused(id): id = Progression.FUSIONS[id].base
	id = Progression.base_id(id)
	if id in ["vortex","thorn","expire"]: return ["garden"]
	if id in ["charge","bloom","pierce","thunder"]: return ["heavy"]
	if id in ["bolt","fan","seek","echo","satellite"]: return ["repeat"]
	if id in ["frost","boomerang"]: return ["cold"]
	return []

static func attack_data(stage: Dictionary) -> Dictionary:
	if stage.has("attack_profile"): return stage.attack_profile
	return Progression.attack_profile(str(stage.get("source_id",stage.attack)))
static func shot_angles(stage: Dictionary) -> Array:
	var angles: Array = attack_data(stage).angles.duplicate()
	var extra := int(Effects.profile(stage,"fan").extra)
	if stage.attack!="bolt" or angles.size()==1:
		angles.clear()
		for i in 1+extra: angles.append(rad_to_deg((i-extra*0.5)*0.24))
		return angles
	for n in extra:
		angles.sort()
		var gap := -1.0
		var added := 0.0
		for i in angles.size():
			var start := float(angles[i])
			var end := float(angles[(i+1)%angles.size()])+(360.0 if i==angles.size()-1 else 0.0)
			if end-start>gap:
				gap = end-start
				added = fposmod((start+end)*0.5,360.0)
		angles.append(added)
	return angles
