extends RefCounted
## Magic v2: rank changes geometry/response; duplicate modifiers add their contributions.
const BALANCE_VERSION := "magic-user-v2"
const VALUES := {
	"fan":[3,4,5,6],"seek":[0.35,0.55,0.8,1.05],"pierce":[2,3,4,5],
	"bounce":[2,3,4,5],"giant":[1.6,1.9,2.2,2.5],"echo":[1,2,3,4],"charge":[1.0,1.1,1.2,1.35]
}
static func resolve(stage: Dictionary) -> Dictionary:
	var result := {}
	for id in VALUES:
		var count := int(stage.get(id,0))
		var ranks: Array = []
		for entry in stage.get("modifiers",[]):
			if entry.id==id and ranks.size()<count: ranks.append(clampi(int(entry.rank),0,3))
		while ranks.size()<count: ranks.append(0)
		var e := {"count":count,"value":1.0,"targets":0,"extra":0,"repeats":[],"range":1.0,"size":1.0,"knockback":0.0,"distance":160.0,"cooldown":1.0}
		for r in ranks:
			match id:
				"fan": e.extra += VALUES.fan[r]-1
				"seek": pass
				"pierce", "bounce": e.targets += VALUES[id][r]
				"giant": e.value *= VALUES.giant[r]
				"echo":
					# Growing total budget, distributed across the visible repeats.
					for n in VALUES.echo[r]: e.repeats.append((0.35+0.15*r)/float(VALUES.echo[r]))
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
		if id=="charge": e.cooldown = pow(2.5,count)
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
	return ""
static func compact(stage: Dictionary, id: String) -> String: return text(stage,id)
