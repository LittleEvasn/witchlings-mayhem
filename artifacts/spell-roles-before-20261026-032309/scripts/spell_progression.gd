extends RefCounted
## Run-local attack upgrades. String tokens keep rank-specific copies distinct in recipes.
const MAX_RANK := 4
const FUSION_COST := 12
const FUSIONS := {
	"storm_spear":{"name":"뇌광창","parents":["bolt","thunder"],"base":"bolt","interval":0.9,"color":Color("ffe7a3"),"desc":"관통하는 창 · 첫 명중 자리에 예고 후 낙뢰"},
	"nova_garden":{"name":"초신성 정원","parents":["bloom","vortex"],"base":"vortex","interval":1.1,"color":Color("ffb6d7"),"desc":"적을 모으는 정원 · 수명이 끝나면 크게 폭발"},
	"moon_ring":{"name":"귀환의 달고리","parents":["boomerang","satellite"],"base":"boomerang","interval":0.9,"color":Color("d3c4ff"),"desc":"왕복하는 달 · 돌아오면 주변을 지키는 위성 생성"},
	"frost_blossom":{"name":"빙결화","parents":["frost","thorn"],"base":"thorn","interval":1.0,"color":Color("a4efff"),"desc":"폭발하는 얼음 덫 · 주변 적에게 냉기 3 부여"},
	"firework_trail":{"name":"불꽃 행진","parents":["ember_path","bloom"],"base":"ember_path","interval":1.1,"color":Color("ffb36f"),"desc":"이동 경로의 잔불 · 각 흔적은 첫 접촉 때 한 번 폭발"}
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
	return ceili(base_price*(1.25+0.25*level))
static func damage_multiplier(token: String) -> float:
	return 1.8 if is_fused(token) else 1.0+0.2*rank(token)
static func scale_multiplier(token: String) -> float:
	return 1.16 if is_fused(token) else 1.0+0.04*rank(token)

# Symmetric combination: base adds one rank; two ranked copies sum their ranks.
static func merge_rank(a: String, b: String) -> int:
	if base_id(a)!=base_id(b) or is_fused(a) or is_fused(b): return -1
	var left := rank(a)
	var right := rank(b)
	return left+right if left>0 and right>0 else maxi(left,right)+1

# Reserved representation for future modifier upgrades. No rank effects are enabled yet.
static func modifier_record(token: String) -> Dictionary:
	return {"id":base_id(token),"rank":rank(token)}
