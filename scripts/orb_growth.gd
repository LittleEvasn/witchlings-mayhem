extends RefCounted
## Per-orb growth is separate from spell ownership and spell ranks.
const MAX_ORBS:=4
const MAX_RANK:=5
const COSTS:=[30,50,75,105,140]
const ORB_COSTS:=[100,160,240]
const OPTIONS:={
	"socket":{"name":"여분 소켓","desc":"오른쪽에 빈 슬롯 1칸 추가 · 최대 8칸","max":2},
	"cycle":{"name":"빠른 순환","desc":"전체 순환 후 대기 8% 감소 · 최대 16%","max":2},
	"power":{"name":"강한 코어","desc":"이 오브의 주문 피해 12% 증가 · 최대 24%","max":2},
	"size":{"name":"넓은 파동","desc":"이 오브의 주문 크기·반경 10% 증가 · 최대 20%","max":2},
	"buffer":{"name":"코어 완충","desc":"피격 시 다음 순차 주문 대기 면제 · 재사용 8초","max":1},
	"sequence":{"name":"빠른 순차","desc":"독립 주문 사이 간격 20% 감소 · 최대 40%","max":2},
	"life":{"name":"오래가는 코어","desc":"투사체·위성·장판 유지시간 15% 증가 · 최대 30%","max":2},
	"speed":{"name":"빠른 전개","desc":"날아가는 투사체 속도 15% 증가 · 최대 30%","max":2},
	"focus":{"name":"집중 조준","desc":"이 오브는 순위 분산 대신 가장 가까운 적 조준","max":1},
	"link":{"name":"연계 안정기","desc":"연결 후속 위력 +10%p · 최대 100%, 발동 횟수 유지","max":1}
}

static func fresh() -> Dictionary:
	return {"rank":0,"picks":{},"legacy_spent":0,"legacy_cycle":1.0,"legacy_sequence":1.0,"offers":[]}

static func migrate(rank: int) -> Dictionary:
	var value:=fresh()
	value.rank=rank
	if rank>0: value.picks.cycle=mini(2,rank)
	value.legacy_spent=maxi(0,rank-2)
	value.legacy_cycle=(1.0/(1.0+.1*rank))/(1.0-.08*mini(2,rank))
	value.legacy_sequence=1.0/(1.0+.1*rank)
	return value

static func capacity(value: Dictionary) -> int: return 6+int(value.picks.get("socket",0))
static func amount(value: Dictionary, id: String) -> int: return int(value.picks.get(id,0))
static func cost(value: Dictionary) -> int: return COSTS[int(value.rank)] if value.rank<MAX_RANK else 0
static func cycle(value: Dictionary) -> float: return (1.0-.08*amount(value,"cycle"))*float(value.legacy_cycle)

static func eligible(value: Dictionary, stages: Array, orb_count: int) -> Array:
	var pool: Array=[]
	if value.rank>=MAX_RANK: return pool
	for id in OPTIONS:
		if amount(value,id)>=OPTIONS[id].max: continue
		if id=="sequence" and stages.filter(func(s):return s.root).size()<2: continue
		if id=="life" and not stages.any(func(s):return s.attack in ["bolt","bloom","boomerang","vortex","thorn","satellite","ember_path"]): continue
		if id=="speed" and not stages.any(func(s):return s.attack in ["bolt","bloom","boomerang","vortex","thorn"]): continue
		if id=="focus" and orb_count<2: continue
		if id=="link" and not stages.any(func(s):return not s.next.is_empty() and s.get("connector_power",1.0)<1.0 and s.connector!="dual_event"): continue
		pool.append(id)
	return pool

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("picks") is Dictionary or not value.get("offers") is Array: return false
	for key in ["rank","legacy_spent"]:
		if not value.get(key) is float and not value.get(key) is int: return false
		if value[key]<0 or value[key]>MAX_RANK or value[key]!=floor(value[key]): return false
	if not value.get("legacy_cycle") is float and not value.get("legacy_cycle") is int: return false
	if not is_finite(value.legacy_cycle) or value.legacy_cycle<.5 or value.legacy_cycle>1.0: return false
	if not value.get("legacy_sequence") is float and not value.get("legacy_sequence") is int: return false
	if not is_finite(value.legacy_sequence) or value.legacy_sequence<.5 or value.legacy_sequence>1.0: return false
	var total: int=int(value.legacy_spent)
	for id in value.picks:
		if id not in OPTIONS: return false
		var n: Variant=value.picks[id]
		if not n is int and not n is float: return false
		if n<1 or n>OPTIONS[id].max or n!=floor(n): return false
		total+=int(n)
	if total!=int(value.rank): return false
	if value.offers.size() not in [0,3] or (value.rank==MAX_RANK and not value.offers.is_empty()): return false
	var seen: Array=[]
	for id in value.offers:
		if id not in OPTIONS or id in seen or amount(value,id)>=OPTIONS[id].max: return false
		seen.append(id)
	return true

static func decorate(stage: Dictionary, value: Dictionary) -> Dictionary:
	var result:=stage.duplicate(true)
	result["_orb_scale"]=1.0+.1*amount(value,"size")
	result["_orb_life"]=1.0+.15*amount(value,"life")
	result["_orb_speed"]=1.0+.15*amount(value,"speed")
	result["_orb_power"]=1.0+.12*amount(value,"power")
	if not result.next.is_empty():
		if result.connector!="dual_event": result.connector_power=minf(1.0,float(result.get("connector_power",.5))+.1*amount(value,"link"))
		result.next=decorate(result.next,value)
	return result

static func summary(value: Dictionary) -> String:
	var names: PackedStringArray=[]
	for id in value.picks: names.append(OPTIONS[id].name+" ×"+str(value.picks[id]))
	if value.legacy_spent>0: names.append("이전 속도 강화 보존")
	return " / ".join(names) if not names.is_empty() else "아직 강화하지 않은 오브"
