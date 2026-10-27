extends RefCounted
const Progression = preload("res://scripts/spell_progression.gd")
const Effects = preload("res://scripts/modifier_effects.gd")
## Six-slot program: cumulative right-side modifiers, sequential roots and event chains.
## Compile once when the player changes their recipe, never for each projectile.
const PARTS = {
	"bolt": {"name":"별빛탄", "symbol":"✦", "kind":"attack", "color":Color("a8efe2"), "desc":"빠른 탄환 · 직접 맞힌 적에게 피해"},
	"bloom": {"name":"꽃폭탄", "symbol":"✺", "kind":"attack", "color":Color("ffc79f"), "desc":"닿으면 폭발 · 주변 적에게 범위 피해\n별빛탄보다 느린 시전"},
	"boomerang": {"name":"달빛 부메랑", "symbol":"☾", "kind":"attack", "color":Color("b8c9ff"), "desc":"왕복 각 구간 1명 타격\n관통 시 각 3명\n추적은 나갈 때 적용 · 귀환도 정상 종료"},
	"vortex": {"name":"소용돌이 씨앗", "hud_name":"소용돌이", "symbol":"◎", "kind":"attack", "color":Color("c6a3ff"), "desc":"설치 후 적을 모으며 지속 피해\n같은 곳에 모아 심으면 범위 성장 · 보스 끌림 없음"},
	"thorn": {"name":"가시꽃 덫", "symbol":"❀", "kind":"attack", "color":Color("b8ed9a"), "desc":"적이 다가오면 터지는 덫\n6초 유지 · 같은 곳에 모아 심으면 범위 성장"},
	"fan": {"name":"갈래", "symbol":"⋔", "kind":"modifier", "color":Color("dfb6f5"), "desc":"뒤 공격을 3갈래로 · 각 위력 40%\n오른쪽 각 주문에 한 번씩 적용 · 중복 시 갈래 증가"},
	"seek": {"name":"추적", "symbol":"◎", "kind":"modifier", "color":Color("a8efe2"), "desc":"가까운 적을 따라 조준·이동\n공격의 형태를 유지하며 추적"},
	"pierce": {"name":"관통", "symbol":"»", "kind":"modifier", "color":Color("f7dfa1"), "desc":"진행 방향의 적 2명까지 추가 타격\n탄은 관통 · 설치 씨앗은 위력을 나눠 배치"},
	"bounce": {"name":"연쇄", "symbol":"↝", "kind":"modifier", "color":Color("ffd99c"), "desc":"첫 피해 뒤 다른 적 최대 2명에게 연쇄\n홉마다 위력 50% · 주문·연결은 다시 만들지 않음"},
	"giant": {"name":"거대화", "symbol":"＋", "kind":"modifier", "color":Color("ffb1c6"), "desc":"크기·범위 ×1.6\n한 바퀴 후 대기 ×1.2"},
	"echo": {"name":"메아리", "symbol":"≋", "kind":"modifier", "color":Color("a5d9ff"), "desc":"0.18초 뒤 위력 35%로 재시전\n복사본은 다시 복제하지 않음"},
	"impact": {"name":"명중 후", "symbol":"→", "kind":"connector", "color":Color("ff9cae"), "desc":"첫 명중 지점에서 뒤 마법을 한 번 시전\n주문 개체당 첫 유효 명중 한 번 · 다단계 연결 가능"},
	"charge": {"name":"응축","kind":"modifier","symbol":"✧","color":Color("ffd99c"),"desc":"한 바퀴 후 대기 ×2.5 · 해당 단계 피해 ×3\n상태와 성장량은 증가하지 않음"},
	"sigil": {"name":"각인","kind":"modifier","symbol":"✧","color":Color("ff9cae"),"desc":"기본 피해 ×0.85 · 각인 6을 모아 폭발\n같은 시전의 상태량은 제한됨"},
	"frost": {"name":"서리숨결","kind":"attack","symbol":"✧","color":Color("b8eaff"),"desc":"냉기 3이면 얼림 · 보스는 얼음 껍질\n다른 직접 공격으로 깨면 추가 피해 · 동결 해제"},
	"thunder": {"name":"벼락","kind":"attack","symbol":"✧","color":Color("ffe7a3"),"desc":"마우스 지점에 예고 후 낙뢰\n추적은 낙하 직전에 위치 고정"},
	"expire": {"name":"소멸 후","kind":"connector","symbol":"✧","color":Color("ff9cae"),"desc":"앞 주문이 정상 종료한 자리에서 후속 시전\n부메랑 귀환 시 현재 조준 방향으로 발사"},
	"satellite": {"name":"달무리 위성","kind":"attack","symbol":"✧","color":Color("b8c9ff"),"desc":"일정 거리를 도는 위성 · 궤도에서만 접촉 피해\n후속 주문이면 제자리에 공전"},
	"ember_path": {"name":"잔불 발자국","kind":"attack","symbol":"✧","color":Color("ffc79f"),"desc":"방금 이동한 경로에 잔불 · 가만히 있으면 발밑 하나\n겹친 잔불은 가장 강한 피해만 적용"}
}
const ATTACK_INTERVALS := {"bolt":0.48,"bloom":0.576,"boomerang":0.624,"vortex":0.864,"thorn":0.72,"frost":0.6,"thunder":0.9,"satellite":1.1,"ember_path":1.0}

# Counts select geometry/repeats; rank data selects efficiency. See modifier_effects.gd.
const STACK_RULES := {
	"fan":{"rule":"add","per_copy":2,"text":"개당 갈래 +2 · 각 구체의 분산 위력 곱연산"},
	"seek":{"rule":"add","per_copy":0.5,"text":"추가 구체당 +50% · 각 강화 보너스 합산"},
	"pierce":{"rule":"add","per_copy":2,"text":"개당 관통/설치 수 +2 · 강화 효율은 평균"},
	"bounce":{"rule":"add","per_copy":2,"text":"개당 연쇄 대상 +2 · 홉 효율은 강화 평균"},
	"giant":{"rule":"multiply","per_copy":1.6,"text":"개당 범위 ×1.6/대기 ×1.2 · 강화 효율은 평균"},
	"echo":{"rule":"add","per_copy":1,"text":"개당 반복 +1회 · 높은 강화부터 0.18초 간격"},
	"charge":{"rule":"multiply","per_copy":3.0,"text":"개당 피해 ×3/대기 ×2.5 · 강화 효율은 평균"},
	"sigil":{"rule":"add","per_copy":1,"text":"각 구체의 축적량 합산 · 직접 피해 ×0.85씩"},
}
const MODIFIER_NOTES := {
	"fan":"여러 갈래로 발사 · 강화는 각 탄 위력 증가",
	"seek":"가까운 적을 따라 조준·이동 · 강화는 추적 반응 증가",
	"pierce":"진행 경로의 적 추가 타격 · 씨앗은 위력을 나눠 설치",
	"bounce":"첫 피해 뒤 다른 적에게 연쇄 · 주문/연결 재생성 없음",
	"giant":"공격 크기·범위 확대 · 강화로 대기는 늘지 않음",
	"echo":"0.18초 간격으로 시전 재현 · 복사본은 재복제하지 않음",
	"charge":"느리고 강한 한 발 · 냉기·각인·성장량은 그대로",
	"sigil":"각인 6을 모아 폭발 · 강화는 축적량 증가"
}
const SEQUENCE_GAP := 0.12

static func blank_stage() -> Dictionary:
	var stage := {"connector":"", "modifiers":[], "slot":-1, "root":true, "next":{}}
	for id in STACK_RULES: stage[id] = 0
	return stage

static func copies(stage: Dictionary, id: String) -> int:
	return int(stage.get(id,0))

static func branches(stage: Dictionary) -> int:
	return 1+int(STACK_RULES.fan.per_copy)*copies(stage,"fan")

static func scale(stage: Dictionary) -> float:
	return Effects.value(stage,"giant")*float(stage.get("_growth",1.0))*float(stage.get("rank_scale",1.0))

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
	return PARTS.has(base) and PARTS[base].kind in ["attack","modifier"] and level in range(1,5) and id==Progression.key(base,level)

static func definition(id: String) -> Dictionary:
	if not has_part(id): return {"name":"알 수 없는 구체","kind":"unknown","color":Color.GRAY,"desc":""}
	if Progression.is_fused(id):
		var d: Dictionary = Progression.FUSIONS[id].duplicate()
		d["kind"] = "attack"
		d.name += " ✧"
		d.desc += "\n합성 완성 · +4 위력 계승 · 보조 부착 가능"
		return d
	var d: Dictionary = PARTS[Progression.base_id(id)].duplicate()
	var level := Progression.rank(id)
	if level>0:
		d.name += " +%d" % level
		d["hud_name"] = d.name
	if d.kind=="modifier":
		var base := Progression.base_id(id)
		d.desc = MODIFIER_NOTES[base]+"\n"+modifier_token_text(id)+"\n같은 오브의 오른쪽 모든 공격에 적용\n중복: "+STACK_RULES[base].text
	elif level>0:
		d.desc += "\n기본 공격 피해 ×%.1f · 크기 ×%.2f" % [Progression.damage_multiplier(id),Progression.scale_multiplier(id)]
	return d

static func upgradeable(id: String) -> bool:
	return has_part(id) and not Progression.is_fused(id) and definition(id).kind in ["attack","modifier"]

static func modifier_token_stage(id: String) -> Dictionary:
	var stage := blank_stage()
	var base := Progression.base_id(id)
	stage[base] = 1
	stage.modifiers = [Progression.modifier_record(id)]
	stage["modifier_effects"] = Effects.resolve(stage)
	return stage

static func modifier_token_text(id: String) -> String:
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
	return {"ok":false,"error":message,"error_index":index,"stages":[],"nodes":nodes}

static func compile(recipe: Array) -> Dictionary:
	if recipe.is_empty(): return invalid("공격을 고른 뒤 보조를 붙여줘.",0)
	if recipe.size()>6: return invalid("이 오브는 최대 6칸이야.",6)
	var stages: Array = []
	var modifiers: Array = []
	var pending := ""
	var pending_slot := -1
	var links: Dictionary = {}
	for index in recipe.size():
		var id := str(recipe[index])
		if not has_part(id): return invalid("알 수 없는 마법 부품.",index,stages)
		var kind: String = definition(id).kind
		if kind=="modifier":
			var record := Progression.modifier_record(id)
			record["slot"] = index
			modifiers.append(record)
		elif kind=="connector":
			if stages.is_empty() or not pending.is_empty(): return invalid("연결 앞에 공격이 필요해.",index,stages)
			var previous: Dictionary = stages.back()
			pending = id
			pending_slot = index
			previous.connector = id
		else:
			var stage := blank_stage()
			var fused := Progression.is_fused(id)
			stage.attack = Progression.FUSIONS[id].base if fused else Progression.base_id(id)
			stage["source_id"] = id
			stage["rank_power"] = Progression.damage_multiplier(id)
			stage["rank_scale"] = Progression.scale_multiplier(id)
			stage["fusion"] = id if fused else ""
			stage.slot = index
			stage.modifiers = modifiers.duplicate(true)
			stage.root = pending.is_empty()
			stage["_linked"] = not stage.root
			for mod in modifiers: stage[mod.id] += 1
			stage["modifier_effects"] = Effects.resolve(stage)
			if fused: stage["interval"] = Progression.FUSIONS[id].interval
			if not pending.is_empty():
				links[stages.size()-1] = stages.size()
				stages.back()["connector_slot"] = pending_slot
				pending = ""
			stages.append(stage)
	if not pending.is_empty(): return invalid("연결 뒤에 실행할 공격이 필요해.",pending_slot,stages)
	if stages.is_empty(): return invalid("보조 뒤에 공격 마법이 필요해.",recipe.size()-1,stages)
	if definition(str(recipe.back())).kind=="modifier": return invalid("마지막 보조의 오른쪽에 공격 마법이 필요해.",recipe.size()-1,stages)
	# Embed only the forward child; flat nodes retain their root flag for scheduling/UI.
	for index in range(stages.size()-1,-1,-1):
		if links.has(index): stages[index].next = stages[links[index]].duplicate(true)
	return {"ok":true,"stages":stages,"nodes":stages,"error":"","error_index":-1}

static func affected_slots(recipe: Array, modifier_slot: int) -> Array:
	var affected: Array = []
	if modifier_slot<0 or modifier_slot>=recipe.size() or not has_part(str(recipe[modifier_slot])) or definition(str(recipe[modifier_slot])).kind!="modifier": return affected
	for i in range(modifier_slot+1,recipe.size()):
		if has_part(str(recipe[i])) and definition(str(recipe[i])).kind=="attack": affected.append(i)
	return affected

static func describe(recipe: Array) -> String:
	var result := compile(recipe)
	if not result.ok: return "%d번 칸: %s" % [result.error_index+1,result.error]
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
			text = (" — "+PARTS[previous.connector].name+" → " if not stage.root else " → 순차 → ")+text
		chunks.append(text)
	return "".join(chunks)

static func compatible(mod: String, attack: String) -> bool:
	return has_part(mod) and PARTS.has(Progression.base_id(mod)) and PARTS[Progression.base_id(mod)].kind=="modifier" and has_part(attack) and definition(attack).kind=="attack"

static func tags(id: String) -> Array:
	if Progression.is_fused(id): id = Progression.FUSIONS[id].base
	id = Progression.base_id(id)
	if id in ["vortex","thorn","expire"]: return ["garden"]
	if id in ["charge","bloom","pierce","thunder"]: return ["heavy"]
	if id in ["sigil","bolt","fan","seek","echo","satellite"]: return ["repeat"]
	if id in ["frost","boomerang"]: return ["cold"]
	return []
