extends RefCounted
## Prefix grammar: modifiers + attack [impact + modifiers + attack].
## Compile once when the player changes their recipe, never for each projectile.
const PARTS = {
	"bolt": {"name":"별빛탄", "symbol":"✦", "kind":"attack", "color":Color("a8efe2"), "desc":"빠른 탄환 · 직접 맞힌 적에게 피해"},
	"bloom": {"name":"꽃폭탄", "symbol":"✺", "kind":"attack", "color":Color("ffc79f"), "desc":"닿으면 폭발 · 주변 적에게 범위 피해\n별빛탄보다 느린 시전"},
	"boomerang": {"name":"달빛 부메랑", "symbol":"☾", "kind":"attack", "color":Color("b8c9ff"), "desc":"왕복 각 구간 1명 타격\n관통 시 각 3명\n도탄·추적은 나갈 때 적용"},
	"vortex": {"name":"소용돌이 씨앗", "hud_name":"소용돌이", "symbol":"◎", "kind":"attack", "color":Color("c6a3ff"), "desc":"설치 후 적을 모으며 지속 피해\n보스는 끌어당기지 않음"},
	"thorn": {"name":"가시꽃 덫", "symbol":"❀", "kind":"attack", "color":Color("b8ed9a"), "desc":"적이 다가오면 터지는 덫\n설치 후 6초 유지"},
	"fan": {"name":"갈래", "symbol":"⋔", "kind":"modifier", "color":Color("dfb6f5"), "desc":"뒤 공격을 3갈래로 · 각 위력 65%\n갈라진 탄의 연계 주문에도 감소 적용"},
	"seek": {"name":"추적", "symbol":"◎", "kind":"modifier", "color":Color("a8efe2"), "desc":"뒤 공격이 가까운 적을 향해 휘어짐"},
	"pierce": {"name":"관통", "symbol":"»", "kind":"modifier", "color":Color("f7dfa1"), "desc":"뒤 공격이 적 2명을 더 통과\n씨앗은 사거리 ×2 · 최대 3곳에 위력을 나눠 설치"},
	"bounce": {"name":"도탄", "symbol":"↝", "kind":"modifier", "color":Color("ffd99c"), "desc":"다른 적에게 최대 2회 도탄\n씨앗은 도탄 뒤 설치"},
	"giant": {"name":"거대화", "symbol":"＋", "kind":"modifier", "color":Color("ffb1c6"), "desc":"크기·범위 ×1.6\n전체 시전 간격 ×1.2"},
	"echo": {"name":"메아리", "symbol":"≋", "kind":"modifier", "color":Color("a5d9ff"), "desc":"0.18초 뒤 위력 55%로 재시전\n복사본은 다시 복제하지 않음"},
	"impact": {"name":"명중 후", "symbol":"→", "kind":"connector", "color":Color("ff9cae"), "desc":"첫 명중 지점에서 뒤 마법을 한 번 시전\n재시전 간격은 두 공격 중 느린 쪽 기준"},
	"charge": {"name":"응축","kind":"modifier","symbol":"✧","color":Color("ffd99c"),"desc":"시전 간격 ×2.5 · 해당 단계 피해 ×3\n상태와 성장량은 증가하지 않음"},
	"graft": {"name":"접목","kind":"modifier","symbol":"✧","color":Color("b8ed9a"),"desc":"가까운 같은 장판에 투자해 3단계 성장\n소용돌이·가시꽃만 적용"},
	"sigil": {"name":"각인","kind":"modifier","symbol":"✧","color":Color("ff9cae"),"desc":"기본 피해 ×0.85 · 각인 6을 모아 폭발\n같은 시전의 상태량은 제한됨"},
	"shatter": {"name":"파쇄","kind":"modifier","symbol":"✧","color":Color("b8eaff"),"desc":"이미 얼어 있는 적을 깨뜨려 추가 피해\n서리숨결과 함께 사용"},
	"frost": {"name":"서리숨결","kind":"attack","symbol":"✧","color":Color("b8eaff"),"desc":"짧은 부채꼴 · 냉기 3이면 얼림\n보스는 행동 정지 대신 서리 껍질"},
	"thunder": {"name":"벼락","kind":"attack","symbol":"✧","color":Color("ffe7a3"),"desc":"마우스 지점에 예고 후 낙뢰\n추적은 낙하 직전에 위치 고정"},
	"expire": {"name":"소멸 후","kind":"connector","symbol":"✧","color":Color("ff9cae"),"desc":"앞 주문이 정상 종료한 자리에서 후속 시전"},
	"on_return": {"name":"귀환 후","kind":"connector","symbol":"✧","color":Color("b8c9ff"),"desc":"부메랑이 돌아왔을 때 현재 조준 방향으로 후속 시전"},
	"satellite": {"name":"달무리 위성","kind":"attack","symbol":"✧","color":Color("b8c9ff"),"desc":"일정 거리를 도는 위성 · 궤도에서만 접촉 피해\n후속 주문이면 제자리에 공전"},
	"ember_path": {"name":"잔불 발자국","kind":"attack","symbol":"✧","color":Color("ffc79f"),"desc":"방금 이동한 경로에 잔불 · 가만히 있으면 발밑 하나\n겹친 잔불은 가장 강한 피해만 적용"}
}
const ATTACK_INTERVALS := {"bolt":0.48,"bloom":0.576,"boomerang":0.624,"vortex":0.864,"thorn":0.72,"frost":0.6,"thunder":0.9,"satellite":1.1,"ember_path":1.0}

static func blank_stage() -> Dictionary:
	return {"fan":false,"seek":false,"pierce":false,"bounce":false,"giant":false,"echo":false,"charge":false,"graft":false,"sigil":false,"shatter":false,"connector":"impact"}

static func interval(stages: Array) -> float:
	if stages.is_empty(): return 0.48
	var base := 0.0
	var giant := false
	var charge := false
	for stage in stages:
		base = maxf(base,float(ATTACK_INTERVALS[stage.attack]))
		giant = giant or stage.giant
		charge = charge or stage.get("charge",false)
	return base*(1.2 if giant else 1.0)*(2.5 if charge else 1.0)

static func compile(recipe: Array) -> Dictionary:
	if recipe.is_empty():
		return {"ok":false,"error":"보조를 먼저 넣고, 마지막에 공격 마법을 넣어줘."}
	if recipe.size() > 6:
		return {"ok":false,"error":"이번 실습에서는 최대 6칸까지 사용할 수 있어."}
	var stages: Array = []
	var stage: Dictionary = blank_stage()
	var expecting_attack := true
	var connected := false
	for index in recipe.size():
		var id := str(recipe[index])
		if not PARTS.has(id):
			return {"ok":false,"error":"알 수 없는 마법 부품.","error_index":index}
		var kind: String = PARTS[id].kind
		if kind == "attack":
			if not expecting_attack:
				return {"ok":false,"error":"공격 두 개 사이에는 연결 구체를 넣어줘.","error_index":index}
			stage["attack"] = id
			for mod in stage:
				if mod in PARTS and PARTS[mod].kind == "modifier" and stage[mod] and not compatible(mod,id):
					return {"ok":false,"error":"%s에는 %s을(를) 적용할 수 없어." % [PARTS[id].name,PARTS[mod].name],"error_index":index}
			stages.append(stage)
			expecting_attack = false
		elif kind == "connector":
			if expecting_attack or connected:
				return {"ok":false,"error":"연결 구체는 첫 공격 뒤에 한 번만 넣을 수 있어.","error_index":index}
			if id == "on_return" and stages[0].attack != "boomerang":
				return {"ok":false,"error":"귀환 후는 달빛 부메랑 뒤에만 사용할 수 있어.","error_index":index}
			stages[0].connector = id
			expecting_attack = true
			connected = true
			stage = blank_stage()
		else:
			if not expecting_attack:
				return {"ok":false,"error":"‘%s’는 적용할 공격보다 앞에 넣어줘." % PARTS[id].name,"error_index":index}
			if stage[id]:
				return {"ok":false,"error":"한 공격에 같은 보조 부품은 한 번만 넣어줘.","error_index":index}
			stage[id] = true
	if expecting_attack:
		return {"ok":false,"error":"보조 또는 연결 구체 뒤에 공격 마법이 필요해.","error_index":recipe.size()-1}
	return {"ok":true,"stages":stages,"error":""}

static func describe(recipe: Array) -> String:
	var result := compile(recipe)
	if not result.ok:
		return result.error
	var chunks: PackedStringArray = []
	for stage in result.stages:
		var s: String = PARTS[stage.attack].name
		if stage.fan: s = "3갈래 " + s
		if stage.seek: s = "추적 " + s
		if stage.pierce: s = "관통 " + s
		if stage.bounce: s = "도탄 " + s
		if stage.giant: s = "거대 " + s
		if stage.echo: s = "메아리 " + s
		for mod in ["charge","graft","sigil","shatter"]:
			if stage.get(mod,false): s = PARTS[mod].name+" "+s
		chunks.append(s)
	var text: String = ("  → "+PARTS[result.stages[0].connector].name+" →  ").join(chunks)
	if "shatter" in recipe and not "frost" in recipe: text += " · 냉기 공급 없음: 파쇄 추가 피해 없음"
	return text

static func compatible(mod: String, attack: String) -> bool:
	if mod == "graft": return attack in ["vortex","thorn"]
	if attack == "frost": return mod not in ["seek","bounce"]
	if attack == "thunder": return mod != "pierce"
	if attack in ["satellite","ember_path"]: return mod not in ["seek","pierce","bounce","echo"]
	return true

static func tags(id: String) -> Array:
	if id in ["graft","vortex","thorn","expire"]: return ["garden"]
	if id in ["charge","bloom","pierce","thunder"]: return ["heavy"]
	if id in ["sigil","bolt","fan","seek","echo","satellite"]: return ["repeat"]
	if id in ["frost","shatter","on_return","boomerang"]: return ["cold"]
	return []
