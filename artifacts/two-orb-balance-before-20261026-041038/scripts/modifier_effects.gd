extends RefCounted
## Base-rank behavior is preserved. Counts and ranks are resolved once by the compiler.
const VALUES := {
	"fan":[0.65,0.70,0.75,0.80,0.85],
	"seek":[1.0,1.25,1.50,1.75,2.0],
	"pierce":[1.0,1.10,1.20,1.30,1.40],
	"bounce":[0.50,0.525,0.55,0.575,0.60],
	"giant":[1.0,1.05,1.10,1.15,1.20],
	"echo":[0.55,0.60,0.65,0.70,0.75],
	"charge":[1.0,1.10,1.20,1.30,1.40],
	"sigil":[1.0,1.15,1.30,1.45,1.60]
}

static func resolve(stage: Dictionary) -> Dictionary:
	var result := {}
	for id in VALUES:
		var count := int(stage.get(id,0))
		var ranks: Array = []
		for entry in stage.get("modifiers",[]):
			if entry.id==id and ranks.size()<count: ranks.append(clampi(int(entry.rank),0,4))
		while ranks.size()<count: ranks.append(0)
		var values: Array = ranks.map(func(r):return VALUES[id][r])
		var sum := 0.0
		for value in values: sum += value
		var average := sum/count if count>0 else 1.0
		var effect := {"count":count,"value":1.0,"targets":2*count}
		match id:
			"fan":
				for value in values: effect.value *= value
			"seek": effect.value = 1.0+0.5*maxi(0,count-1)+sum-count
			"pierce": effect.value = average
			"bounce":
				effect.value = average if count>0 else 0.5
				var rank_sum := 0
				for rank in ranks: rank_sum += rank
				effect["distance"] = 160.0+10.0*rank_sum/count if count>0 else 160.0
			"giant":
				effect.value = pow(1.6,count)*average
				effect["cooldown"] = pow(1.2,count)
			"echo":
				values.sort()
				values.reverse()
				effect["repeats"] = values
			"charge":
				effect.value = pow(3.0,count)*average
				effect["cooldown"] = pow(2.5,count)
			"sigil":
				effect.value = sum
				effect["direct"] = pow(0.85,count)
		result[id] = effect
	return result

static func profile(stage: Dictionary, id: String) -> Dictionary:
	var cached: Dictionary = stage.get("modifier_effects",{}).get(id,{})
	# Internal fusion/echo copies explicitly disable selected modifiers.
	if cached.get("count",-1)==int(stage.get(id,0)): return cached
	return resolve(stage)[id]

static func value(stage: Dictionary, id: String) -> float:
	return float(profile(stage,id).value)

static func text(stage: Dictionary, id: String) -> String:
	var e := profile(stage,id)
	if e.count==0: return "미적용"
	match id:
		"fan": return "%d갈래 · 각 위력 %.1f%%"%[1+2*e.count,e.value*100]
		"seek": return "추적 성능 ×%.2f"%e.value
		"pierce": return "추가 %d명 · 관통 뒤/분산 위력 %.0f%%"%[e.targets,e.value*100]
		"bounce": return "추가 %d명 · 홉 위력 %.1f%% · 거리 %.0f"%[e.targets,e.value*100,e.distance]
		"giant": return "크기 ×%.2f · 순환 대기 ×%.2f"%[e.value,e.cooldown]
		"echo":
			var strengths: PackedStringArray = []
			for amount in e.repeats: strengths.append("%.0f%%"%(amount*100))
			return "반복 %d회 · 위력 %s"%[e.count,"/".join(strengths)]
		"charge": return "직접 피해 ×%.2f · 순환 대기 ×%.2f"%[e.value,e.cooldown]
		"sigil": return "각인 %.2f · 직접 피해 %.1f%%"%[e.value,e.direct*100]
	return ""

static func compact(stage: Dictionary, id: String) -> String:
	var e := profile(stage,id)
	if e.count==0: return "미적용"
	match id:
		"fan": return "%d갈래 %.1f%%"%[1+2*e.count,e.value*100]
		"seek": return "추적 ×%.2f"%e.value
		"pierce": return "%d명/%.0f%%"%[e.targets,e.value*100]
		"bounce": return "%d명/%.1f%%"%[e.targets,e.value*100]
		"giant": return "범위 ×%.2f"%e.value
		"charge": return "피해 ×%.2f"%e.value
		"sigil": return "각인 %.2f"%e.value
		"echo": return "%d회/%.0f%%~"%[e.count,e.repeats[0]*100]
	return ""
