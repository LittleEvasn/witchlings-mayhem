extends RefCounted
## Run-local attack and support upgrades. String tokens keep rank-specific copies distinct in recipes.
const MAX_RANK := 3
const FUSION_COST := 12
const FUSIONS := {
	"storm_spear":{"name":"뇌광창","parents":["bolt","thunder"],"base":"bolt","interval":0.9,"color":Color("ffe7a3"),"desc":"관통하는 창 · 첫 명중 자리에 예고 후 낙뢰"},
	"nova_garden":{"name":"초신성 정원","parents":["bloom","vortex"],"base":"vortex","interval":1.1,"color":Color("ffb6d7"),"desc":"적을 모으는 정원 · 수명이 끝나면 크게 폭발"},
	"moon_ring":{"name":"귀환의 달고리","parents":["boomerang","satellite"],"base":"boomerang","interval":0.9,"color":Color("d3c4ff"),"desc":"왕복하는 달 · 돌아오면 주변을 지키는 위성 생성"},
	"frost_blossom":{"name":"빙결화","parents":["frost","thorn"],"base":"thorn","interval":1.0,"color":Color("a4efff"),"desc":"적 접근 시 냉기 · 잠시 뒤 가시 폭발로 얼음 파쇄"},
	"firework_trail":{"name":"불꽃 행진","parents":["ember_path","bloom"],"base":"ember_path","interval":1.1,"color":Color("ffb36f"),"desc":"이동 경로의 잔불 · 각 흔적은 첫 접촉 때 한 번 폭발"},
	"frost_gate":{"name":"별서리 관문","parents":["bolt","frost"],"base":"bolt","interval":0.9,"color":Color("a4efff"),"desc":"별빛탄의 첫 명중 지점에서 냉기 부채꼴 방출"},
	"thunder_trap":{"name":"천둥꽃 덫","parents":["thunder","thorn"],"base":"thorn","interval":1.0,"color":Color("ffe7a3"),"desc":"적을 감지한 덫 자리에 고정된 낙뢰 세 번"},
	"moon_vortex":{"name":"달무리 소용돌이","parents":["vortex","satellite"],"base":"vortex","interval":1.1,"color":Color("d3c4ff"),"desc":"적을 당기는 소용돌이 가장자리에서 위성 공전"},
	"petal_return":{"name":"꽃잎 귀환","parents":["boomerang","bloom"],"base":"boomerang","interval":0.9,"color":Color("ffb6d7"),"desc":"도탄 명중점에 꽃봉오리 · 귀환을 시작하면 차례로 폭발"}
}
static func base_id(token: String) -> String: return token.get_slice("@",0)
static func rank(token: String) -> int:
	return int(token.get_slice("@",1)) if "@" in token else 0
static func key(id: String, level: int) -> String:
	return id if level==0 else "%s@%d" % [id,level]
static func is_fused(token: String) -> bool: return FUSIONS.has(token)
static func fusion_for(a: String, b: String) -> String:
	if rank(a)!=MAX_RANK or rank(b)!=MAX_RANK: return ""
	for id in FUSIONS:
		var parents: Array = FUSIONS[id].parents
		if (base_id(a)==parents[0] and base_id(b)==parents[1]) or (base_id(a)==parents[1] and base_id(b)==parents[0]): return id
	return ""
static func paid_cost(base_price: int, level: int) -> int:
	return ceili(base_price*(0.5+0.25*level))
static func damage_multiplier(token: String) -> float:
	return 1.8 if is_fused(token) else 1.0
static func scale_multiplier(token: String) -> float:
	return 1.16 if is_fused(token) else 1.0

# Symmetric combination: base adds one rank; two ranked copies sum their ranks.
static func merge_rank(a: String, b: String) -> int:
	if base_id(a)!=base_id(b) or is_fused(a) or is_fused(b): return -1
	var left := rank(a)
	var right := rank(b)
	return left+right if left>0 and right>0 else maxi(left,right)+1

# Source identity is preserved independently of modifier count and rank effects.
static func modifier_record(token: String) -> Dictionary:
	return {"id":base_id(token),"rank":rank(token)}

# Geometry, not hidden damage inflation, is the ordinary attack upgrade.
static func attack_profile(token: String) -> Dictionary:
	var id: String = FUSIONS[token].base if is_fused(token) else base_id(token)
	var r := 3 if is_fused(token) else clampi(rank(token),0,MAX_RANK)
	var data := {"rank":r,"angles":[0.0],"radius":0.0,"life":0.0,"targets":1,"pulses":1,"bodies":1,"ricochets":0,"spread":60.0}
	match id:
		"bolt": data.angles = [[0.0],[0.0,150.0,210.0],[0.0,90.0,180.0,270.0],[0.0,60.0,120.0,180.0,240.0,300.0]][r]
		"bloom": data.radius = [70.0,90.0,115.0,140.0][r]
		"boomerang": data.ricochets = r
		"vortex":
			data.radius = [86.0,105.0,125.0,150.0][r]
			data.life = [3.0,3.5,4.0,4.5][r]
		"thorn":
			data.radius = [62.0,80.0,100.0,125.0][r]
			data.life = [6.0,7.0,8.0,9.0][r]
		"frost":
			data.spread = [60.0,70.0,80.0,90.0][r]
			data.targets = [4,6,8,10][r]
		"thunder":
			data.radius = [45.0,60.0,75.0,90.0][r]
			data.pulses = [1,1,2,3][r]
		"satellite": data.bodies = [2,4,6,8][r]
		"ember_path":
			data.radius = [24.0,30.0,36.0,42.0][r]
			data.life = [1.8,2.2,2.6,3.0][r]
	# Completed recipes have a fixed silhouette; parent shot counts do not multiply.
	if is_fused(token):
		data.angles = [0.0]
		if id=="boomerang": data.ricochets = 3
	return data

static func attack_text(token: String) -> String:
	var d := attack_profile(token)
	match base_id(token):
		"bolt": return "%d방향 발사"%d.angles.size()
		"bloom": return "폭발 반경 %.0f"%d.radius
		"boomerang": return "호형 비행 · 추가 도탄 %d회 후 즉시 귀환"%d.ricochets
		"vortex", "thorn", "ember_path": return "반경 %.0f · %.1f초 유지"%[d.radius,d.life]
		"frost": return "170거리 · %.0f도 · 최대 %d명"%[d.spread,d.targets]
		"thunder": return "반경 %.0f · 같은 지점 %d회 낙뢰"%[d.radius,d.pulses]
		"satellite": return "위성 %d개 공전"%d.bodies
	return "완성형 합성 · 추가 강화 없음"

static func connector_power(token: String) -> float:
	return [0.5,0.65,0.8,1.0][clampi(rank(token),0,MAX_RANK)]
