extends RefCounted
## Magic v2: rank changes geometry/response; duplicate modifiers add their contributions.
const P=preload("res://scripts/spell_progression.gd")
const BALANCE_VERSION := "magic60-v1"
const VALUES := {
	"fan":[3,4,5,6],"seek":[0.35,0.55,0.8,1.05],"pierce":[2,3,4,5],
	"bounce":[2,3,4,5],"giant":[1.6,1.9,2.2,2.5],"echo":[1,2,3,4],"charge":[1.0,1.1,1.2,1.35],"fall":[.5,.45,.4,.35],"orbit":[90,110,130,150],"split":[3,4,5,6],"trail":[2,3,4,5],"element_fire":[1,1.25,1.5,1.75],"element_ice":[.6,.8,1.0,1.2],"element_poison":[1,1.25,1.5,1.75],"element_lightning":[1,1.25,1.5,1.75]
}
static func resolve(stage: Dictionary) -> Dictionary:
	var result := {}
	var expanded: Array=[]
	for entry in stage.get("modifiers",[]):
		if P.is_support(entry.id):
			for effect in P.FUSIONS[entry.id].get("effects",[]): expanded.append({"id":effect[0],"rank":effect[1]})
		else: expanded.append(entry)
	for id in VALUES:
		var count := int(stage.get(id,0))
		var ranks: Array = []
		for entry in expanded:
			if entry.id==id and ranks.size()<count: ranks.append(clampi(int(entry.rank),0,3))
		while ranks.size()<count: ranks.append(0)
		var e := {"count":count,"value":0.0 if id in ["fall","orbit","split","trail","element_fire","element_ice","element_poison","element_lightning"] else 1.0,"targets":0,"extra":0,"repeats":[],"range":1.0,"size":1.0,"knockback":0.0,"distance":160.0,"cooldown":1.0}
		for r in ranks:
			match id:
				"fan": e.extra += VALUES.fan[r]-1
				"seek": pass
				"pierce", "bounce": e.targets += VALUES[id][r]
				"giant": e.value *= VALUES.giant[r]
				"echo":
					# Growing total budget, distributed across the visible repeats.
					for n in VALUES.echo[r]: e.repeats.append((0.35+0.15*r)/float(VALUES.echo[r]))
				"fall", "orbit", "split", "trail", "element_fire", "element_ice", "element_poison", "element_lightning":
					e.value += VALUES[id][r]
				"charge":
					e.value *= 3.0
					e.size *= VALUES.charge[r]
					e.knockback += [0.0,24.0,40.0,60.0][r]
		if id=="fan":
			var native := 1.0
			var geometry: Dictionary = stage.get("attack_profile",{})
			if stage.get("attack","")=="bolt": native = float(geometry.get("angles",[0]).size())
			elif stage.get("attack","")=="satellite": native = float(geometry.get("bodies",1))
			# Added branches share the native pattern's budget; a six-way bolt must
			# not lose most of its total power just because fan is attached.
			e.value = native/(native+0.75*e.extra)
		if id=="seek" and count>0:
			e.value = 0.0
			e.range = 0.0
			for r in ranks:
				e.value += VALUES.seek[r]
				e.range += [0.6,0.75,0.9,1.05][r]
		if id=="bounce":
			e.value = 0.5
			if count>0:
				e.distance = 0.0
				for r in ranks: e.distance += [160.0,180.0,200.0,220.0][r]/count
		if id=="giant": e.cooldown = pow(1.2,count)
		if id=="charge":
			e.cooldown = pow(2.5,count)
			e.knockback += 40*int(stage.get("compressed_star",0))
		result[id] = e
	return result
static func profile(stage: Dictionary, id: String) -> Dictionary:
	var cached: Dictionary = stage.get("modifier_effects",{}).get(id,{})
	if cached.get("count",-1)==int(stage.get(id,0)): return cached
	return resolve(stage)[id]
static func value(stage: Dictionary, id: String) -> float: return float(profile(stage,id).value)
static func text(stage: Dictionary, id: String) -> String:
	var e := profile(stage,id)
	if e.count==0: return "미적용"
	match id:
		"fan": return "고유 배치에 %d갈래 추가 · 각 위력 %.0f%%"%[e.extra,e.value*100]
		"seek": return "회전 반응 ×%.2f · 탐색 거리 ×%.2f"%[e.value,e.range]
		"pierce": return "진행 경로 추가 %d명 · 씨앗 %d곳 분산"%[e.targets,e.targets+1]
		"bounce": return "추가 %d명 · 홉마다 50%% · 거리 %.0f"%[e.targets,e.distance]
		"giant": return "크기 ×%.2f · 순환 대기 ×%.2f"%[e.value,e.cooldown]
		"echo":
			var total := 0.0
			for strength in e.repeats: total += strength
			return "추가 %d회 · 합계 위력 %.0f%% · 0.18초 간격"%[e.repeats.size(),total*100]
		"charge": return "피해 ×%.2f · 크기 ×%.2f · 첫 밀침 %.0f · 대기 ×%.2f"%[e.value,e.size,e.knockback,e.cooldown]
		"fall": return "착지까지 %.2f초 · 착지 전 무피해"%e.value
		"orbit": return "공전 반경 %.0f · 오른쪽 추적/공전이 이동 방식 결정"%e.value
		"split": return "자식 %d개 · 각각 피해 33%% · 크기 80%% · 비낙하 속도 50%% · 소멸 시 분열 · 재분열/연결 없음"%int(e.value)
		"trail": return "90거리마다 잔상 · 최대 %d개 · 각 20%% · 재복제 없음"%e.value
		"element_fire": return "3초 화상 · 초당 기준 피해 ×%.2f"%(e.value*.12)
		"element_ice": return "유효 명중 냉기 %.2f · 3 누적 동결"%e.value
		"element_poison": return "3초 중독 · 이동 48거리마다 독 흔적 · 위력 ×%.2f"%e.value
		"element_lightning": return "0.6초마다 근처 1명 방전 · 위력 %.0f%%"%(e.value*20)
	return ""
static func compact(stage: Dictionary, id: String) -> String: return text(stage,id)
