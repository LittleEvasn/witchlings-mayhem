extends RefCounted
## Prefix grammar: modifiers + attack [impact + modifiers + attack].
## Compile once when the player changes their recipe, never for each projectile.
const PARTS = {
	"bolt": {"name":"별빛탄", "symbol":"✦", "kind":"attack", "color":Color("a8efe2"), "desc":"빠른 탄환 · 직접 맞힌 적에게 피해"},
	"bloom": {"name":"꽃폭탄", "symbol":"✺", "kind":"attack", "color":Color("ffc79f"), "desc":"닿으면 폭발 · 주변 적에게 범위 피해"},
	"boomerang": {"name":"달빛 부메랑", "symbol":"☾", "kind":"attack", "color":Color("b8c9ff"), "desc":"왕복 각 구간 1명 타격\n관통 시 각 3명\n도탄·추적은 나갈 때 적용"},
	"vortex": {"name":"소용돌이 씨앗", "hud_name":"소용돌이", "symbol":"◎", "kind":"attack", "color":Color("c6a3ff"), "desc":"설치 후 적을 모으며 지속 피해\n보스는 끌어당기지 않음"},
	"thorn": {"name":"가시꽃 덫", "symbol":"❀", "kind":"attack", "color":Color("b8ed9a"), "desc":"적이 다가오면 터지는 덫\n설치 후 6초 유지"},
	"fan": {"name":"갈래", "symbol":"⋔", "kind":"modifier", "color":Color("dfb6f5"), "desc":"뒤 공격을 3갈래로 · 각 위력 65%"},
	"seek": {"name":"추적", "symbol":"◎", "kind":"modifier", "color":Color("a8efe2"), "desc":"뒤 공격이 가까운 적을 향해 휘어짐"},
	"pierce": {"name":"관통", "symbol":"»", "kind":"modifier", "color":Color("f7dfa1"), "desc":"뒤 공격이 적 2명을 더 통과"},
	"bounce": {"name":"도탄", "symbol":"↝", "kind":"modifier", "color":Color("ffd99c"), "desc":"다른 적에게 최대 2회 도탄\n씨앗은 도탄 뒤 설치"},
	"giant": {"name":"거대화", "symbol":"＋", "kind":"modifier", "color":Color("ffb1c6"), "desc":"크기·범위 ×1.6\n전체 시전 간격 ×1.5"},
	"echo": {"name":"메아리", "symbol":"≋", "kind":"modifier", "color":Color("a5d9ff"), "desc":"0.18초 뒤 위력 55%로 재시전\n복사본은 다시 복제하지 않음"},
	"impact": {"name":"명중 후", "symbol":"→", "kind":"connector", "color":Color("ff9cae"), "desc":"첫 명중 지점에서 뒤 마법을 한 번 시전"}
}

static func blank_stage() -> Dictionary:
	return {"fan":false,"seek":false,"pierce":false,"bounce":false,"giant":false,"echo":false}

static func interval(stages: Array) -> float:
	if stages.is_empty(): return 0.48
	var base: float = {"boomerang":1.3,"vortex":1.8,"thorn":1.5}.get(stages[0].attack,1.0)
	for stage in stages:
		if stage.giant: return 0.48*base*1.5
	return 0.48*base

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
				return {"ok":false,"error":"공격 두 개 사이에는 ‘명중 후’를 넣어줘.","error_index":index}
			stage["attack"] = id
			stages.append(stage)
			expecting_attack = false
		elif kind == "connector":
			if expecting_attack or connected:
				return {"ok":false,"error":"‘명중 후’는 첫 공격 뒤에 한 번만 넣을 수 있어.","error_index":index}
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
		return {"ok":false,"error":"보조 또는 ‘명중 후’ 뒤에 공격 마법이 필요해.","error_index":recipe.size()-1}
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
		chunks.append(s)
	return "  → 첫 명중 지점에서 →  ".join(chunks)
