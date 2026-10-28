extends RefCounted
## Run-local relic state. Definitions contain player text; combat hooks live in game/runtime.
const VERSION := "relics-v1"
const SLOW_RADIUS := 150.0
const DEFINITIONS := {
	"magnifier":{"name":"마녀의 확대경","glyph":"확","desc":"마법이 20% 커집니다.","note":"크기·공격 범위 +20%","detail":"투사체와 폭발·장판이 커집니다. 사거리와 지속시간은 그대로입니다."},
	"gloves":{"name":"변덕쟁이 장갑","glyph":"복","desc":"마법을 4번 시전할 때마다 한 번 더 복제합니다.","note":"복제 위력 40% · 무작위 방향","detail":"모든 오브의 시전을 함께 셉니다. 갈래·메아리·연결로 생긴 추가 마법은 횟수에 포함하지 않습니다. 복제에도 장착한 보조와 후속 마법이 적용됩니다."},
	"crown":{"name":"금이 간 왕관","glyph":"관","desc":"주는 피해가 30%, 받는 피해가 20% 증가합니다.","note":"강한 화력 · 더 큰 위험","detail":"모든 마법 피해 ×1.3, 받는 피해 ×1.2. 보호막에 받는 피해도 증가합니다."},
	"hourglass":{"name":"성급한 모래시계","glyph":"시","desc":"마법을 더 자주 시전하지만, 피해가 15% 감소합니다.","note":"시전 간격·순환 대기 20% 감소","detail":"장판의 피해 주기와 메아리의 반복 간격은 그대로입니다."},
	"droplet":{"name":"느려지는 물방울","glyph":"물","desc":"주변의 적 탄환이 느려집니다.","note":"탄환 속도 35% 감소","detail":"주변 150 거리 안의 적 탄환이 느려집니다. 범위를 벗어나면 원래 속도로 돌아옵니다."},
	"brooch":{"name":"마석 먹는 브로치","glyph":"회","desc":"마석을 10개 주울 때마다 체력을 1 회복합니다.","note":"실패작이 떨어뜨린 마석으로 회복","detail":"마석 수량 기준입니다. 남은 수량은 다음 웨이브로 이어집니다. 체력이 가득 차면 회복은 저장되지 않습니다."},
	"soul_coat":{"name":"영혼 솜옷","glyph":"막","desc":"적을 처치하면 이번 웨이브 동안 보호막을 얻습니다.","note":"10마리당 보호막 1 · 최대 10","detail":"보호막이 피해를 먼저 흡수합니다. 보호막과 처치 누적은 웨이브가 끝나면 사라집니다."},
	"shoes":{"name":"도망쟁이 구두","glyph":"속","desc":"피해를 받으면 잠시 이동 속도가 빨라집니다.","note":"2초간 이동 속도 +35% · 재사용 5초","detail":"체력이나 보호막에 피해를 받으면 발동합니다. 별도의 무적 효과는 없습니다."},
	"piggy":{"name":"욕심쟁이 저금통","glyph":"금","desc":"마석을 많이 가지고 있을수록 피해가 증가합니다.","note":"10마석당 피해 +2% · 최대 +20%","detail":"현재 가진 마석으로 계산합니다. 이미 시전한 마법의 위력은 유지됩니다."},
	"seal":{"name":"검은 거래 도장","glyph":"인","desc":"제작대의 무작위 제작안 하나가 무료가 됩니다.","note":"제작안 재구성 시 다시 적용","detail":"같은 진열에서는 한 번만 무료로 제작합니다. 재구성 비용은 그대로이며, 화면을 다시 열어도 무료 제작안은 바뀌지 않습니다."},
	"toolbox":{"name":"수습 마녀의 공구함","glyph":"공","desc":"마석 강화 비용이 20% 감소합니다.","note":"할인 후 소수점 올림","detail":"마석으로 한 단계 강화할 때 적용합니다. 구체를 합치는 강화와 완성형 합성 비용은 그대로입니다."},
	"display":{"name":"수상한 진열장","glyph":"안","desc":"제작대에서 마법 제작안을 하나 더 제시합니다.","note":"무작위 제작안 +1","detail":"처음 진열할 때와 제작안을 재구성할 때 모두 적용됩니다."}
}
var owned: Array = []
var cast_count := 0
var gem_remainder := 0
var kill_remainder := 0
var shield := 0.0
var speed_left := 0.0
var speed_cooldown := 0.0
var rng := RandomNumberGenerator.new()

static func definition(id: String) -> Dictionary:
	var result: Dictionary = DEFINITIONS.get(id,{}).duplicate()
	if not result.is_empty():
		result["reward_pool"] = true
		result["craft_pool"] = false
		result["tier"] = "unassigned"
	return result

func has(id: String) -> bool: return id in owned
func acquire(id: String) -> bool:
	if not DEFINITIONS.has(id) or has(id): return false
	owned.append(id)
	return true
func reset(seed_value: int) -> void:
	owned.clear()
	cast_count = 0
	gem_remainder = 0
	end_wave()
	rng.seed = seed_value
func end_wave() -> void:
	kill_remainder = 0
	shield = 0
	speed_left = 0
	speed_cooldown = 0
func choices(random: RandomNumberGenerator) -> Array:
	var pool: Array = DEFINITIONS.keys().filter(func(id): return not has(id))
	var result: Array = []
	while not pool.is_empty() and result.size()<3:
		result.append(pool.pop_at(random.randi_range(0,pool.size()-1)))
	return result
func damage_bonus(gold: int) -> float:
	return minf(.2,floori(maxi(0,gold)/10.0)*.02) if has("piggy") else 0.0
func damage_multiplier(gold: int) -> float:
	return (1.3 if has("crown") else 1.0)*(.85 if has("hourglass") else 1.0)*(1.0+damage_bonus(gold))
func size_multiplier() -> float: return 1.2 if has("magnifier") else 1.0
func timing_multiplier() -> float: return .8 if has("hourglass") else 1.0
func movement_multiplier() -> float: return 1.35 if speed_left>0 else 1.0
func tick(delta: float) -> void:
	speed_left = maxf(0,speed_left-delta)
	speed_cooldown = maxf(0,speed_cooldown-delta)
func direct_cast() -> bool:
	if not has("gloves"): return false
	cast_count += 1
	return cast_count%4==0
func collect(value: int) -> int:
	if not has("brooch"): return 0
	gem_remainder += maxi(0,value)
	var healing := floori(gem_remainder/10.0)
	gem_remainder %= 10
	return healing
func kill() -> bool:
	if not has("soul_coat"): return false
	kill_remainder += 1
	if kill_remainder<10: return false
	kill_remainder = 0
	var old := shield
	shield = minf(10,shield+1)
	return shield>old
func take_damage(amount: float) -> Dictionary:
	var total := maxf(0,amount)*(1.2 if has("crown") else 1.0)
	var absorbed := minf(shield,total)
	shield -= absorbed
	var speed := total>0 and has("shoes") and speed_cooldown<=0
	if speed:
		speed_left = 2
		speed_cooldown = 5
	return {"health":total-absorbed,"shield":absorbed,"speed":speed}
func snapshot() -> Dictionary:
	return {"owned":owned.duplicate(),"casts":cast_count,"gems":gem_remainder,"kills":kill_remainder,"shield":shield,"speed_left":speed_left,"speed_cooldown":speed_cooldown,"rng_state":rng.state}
func restore(data: Dictionary) -> void:
	owned = data.owned.duplicate()
	cast_count = data.casts
	gem_remainder = data.gems
	kill_remainder = data.kills
	shield = data.shield
	speed_left = data.speed_left
	speed_cooldown = data.speed_cooldown
	rng.state = data.rng_state
func tooltip(id: String, gold: int) -> String:
	var d := definition(id)
	var text: String = d.name+"\n"+d.desc+"\n"+d.note+"\n\n"+d.detail
	if id=="piggy": text += "\n현재 피해 보너스 +%d%%%s" % [roundi(damage_bonus(gold)*100)," (최대)" if damage_bonus(gold)>=.2 else ""]
	if id=="gloves": text += "\n다음 복제까지 %d회" % [4-cast_count%4]
	if id=="soul_coat": text += "\n보호막 %.0f / 10 · 처치 %d / 10" % [shield,kill_remainder]
	return text
