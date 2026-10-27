extends RefCounted
const Spells = preload("res://scripts/spells.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const PRICES := {"bolt":8,"bloom":12,"fan":14,"seek":16,"pierce":12,"impact":10,"boomerang":14,"vortex":18,"thorn":14,"bounce":14,"giant":14,"echo":18,"charge":18,"sigil":18,"frost":14,"thunder":16,"expire":10,"satellite":16,"ember_path":14}
const CLEAR_REWARD := 20
const REROLL_COST := 5
const KITS := {
 "garden":{"name":"작은 정원","note":"같은 곳에 심으면 더 자라려나?","orbs":["giant","vortex"],"recipe":["giant","vortex"]},
 "charge":{"name":"큰 한 발","note":"한 번만 크게 하면 덜 귀찮겠지?","orbs":["charge","bloom"],"recipe":["charge","bloom"]},
 "sigil":{"name":"반짝 연사","note":"작은 별도 여섯 번이면 사고가 돼.","orbs":["sigil","fan"],"recipe":["fan","sigil","bolt"]},
 "frost":{"name":"얼음 실험","note":"먼저 얼리고, 다음에 깨뜨리자.","orbs":["frost"],"recipe":["frost","impact","bolt"]}}
const STARTING_INVENTORY := {"bolt":1,"impact":1,"sigil":1,"fan":1}
var gold := 0
var total_earned := 0
var inventory: Dictionary = {}
var offers: Array = []
var revision := 0
var kit := "sigil"
var research_sold := false
var affinity: Array = []
var relics: RefCounted
func _init() -> void: reset()
func reset(selected := "sigil") -> void:
 kit = selected if KITS.has(selected) else "sigil"
 gold = 0
 total_earned = 0
 inventory = {"bolt":1,"impact":1}
 for id in KITS[kit].orbs: inventory[id] = int(inventory.get(id,0))+1
 offers.clear()
 research_sold = false
 revision += 1
func grant(value: int) -> void:
 gold += maxi(0,value)
 total_earned += maxi(0,value)
func remaining(id: String, reserved: Array) -> int: return maxi(0,int(inventory.get(id,0))-reserved.count(id))
func owns_recipe(recipe: Array) -> bool:
 for id in recipe:
  if recipe.count(id)>int(inventory.get(id,0)): return false
 return true
static func purchase_cost(recipe: Array, selected := "sigil") -> int:
 var free := {"bolt":1,"impact":1}
 for id in KITS.get(selected,KITS.sigil).orbs: free[id] = int(free.get(id,0))+1
 var cost := 0
 for id in recipe:
  if free.get(id,0)>0: free[id] -= 1
  else: cost += investment_cost(id)
 return cost
func can_stock(id: String) -> bool:
 if not PRICES.has(id): return false
 var count := 0
 for token in inventory:
  if Progression.base_id(token)==id: count += int(inventory[token])
 return count<12

static func investment_cost(id: String) -> int:
 if Progression.is_fused(id):
  var parents: Array = Progression.FUSIONS[id].parents
  return investment_cost(Progression.key(parents[0],4))+investment_cost(Progression.key(parents[1],4))+Progression.FUSION_COST
 var price: int = PRICES.get(Progression.base_id(id),0)
 var total := price
 for level in Progression.rank(id): total += Progression.paid_cost(price,level)
 return total

func craft_quote(action: String, target: String, material := "") -> Dictionary:
 var fail := {"ok":false,"error":"강화할 공격·보조 구체를 선택해줘."}
 if not Spells.has_part(target) or Spells.definition(target).kind not in ["attack","modifier"]: return fail
 if inventory.get(target,0)<=0: return {"ok":false,"error":"%s 구체가 없어. 보유함 또는 합성 도감의 재료를 확인해줘." % Spells.definition(target).name}
 if Progression.is_fused(target): return {"ok":false,"error":"이미 합성이 완성된 마법이야."}
 var level := Progression.rank(target)
 var consumed: Array = [target]
 var cost := 0
 var output := ""
 match action:
  "merge":
   var feeder := material
   if feeder.is_empty():
    # Prefer a spare low-rank copy, but allow either rank to be the target.
    for candidate_level in range(5):
     var candidate := Progression.key(Progression.base_id(target),candidate_level)
     if int(inventory.get(candidate,0))-(1 if candidate==target else 0)>0:
      if Progression.merge_rank(target,candidate)<=4:
       feeder = candidate
       break
    if feeder.is_empty():
     for candidate in inventory:
      if Progression.base_id(candidate)==Progression.base_id(target) and int(inventory[candidate])-(1 if candidate==target else 0)>0:
       feeder = candidate
       break
   if not Spells.has_part(feeder) or Progression.is_fused(feeder) or Progression.base_id(feeder)!=Progression.base_id(target):
    return {"ok":false,"error":"같은 종류의 구체를 재료로 골라줘."}
   if int(inventory.get(feeder,0))-(1 if feeder==target else 0)<=0:
    return {"ok":false,"error":"선택한 재료 구체가 부족해. 다시 골라줘."}
   var result_rank := Progression.merge_rank(target,feeder)
   consumed.append(feeder)
   if result_rank>Progression.MAX_RANK:
    return {"ok":false,"error":"예상 +%d: 최대 +4를 초과해. 구체와 마석은 사용하지 않아." % result_rank,"output_rank":result_rank,"consumed":consumed,"cost":0}
   output = Progression.key(Progression.base_id(target),result_rank)
  "upgrade":
   if level>=4: return {"ok":false,"error":"+4는 최대 강화야."}
   cost = Progression.paid_cost(PRICES[Progression.base_id(target)],level)
   if relics!=null and relics.has("toolbox"): cost = ceili(cost*.8)
   output = Progression.key(Progression.base_id(target),level+1)
  "fuse":
   output = Progression.fusion_for(target,material)
   if output.is_empty(): return {"ok":false,"error":"도감에 있는 서로 다른 공격 마법 두 개가 모두 +4여야 해."}
   consumed.append(material)
   cost = Progression.FUSION_COST
  _: return fail
 var after := inventory.duplicate()
 for token in consumed:
  if after.get(token,0)<=0: return {"ok":false,"error":"필요한 구체 수량이 부족해. 재료 수량과 강화 단계를 확인해줘."}
  after[token] -= 1
  if after[token]==0: after.erase(token)
 after[output] = int(after.get(output,0))+1
 if gold<cost: return {"ok":false,"error":"마석(G)이 부족해. 필요 %d G / 보유 %d G" % [cost,gold],"cost":cost,"output":output,"inventory":after,"consumed":consumed}
 return {"ok":true,"error":"","cost":cost,"output":output,"consumed":consumed,"inventory":after}

func craft(action: String, target: String, material: String, expected_revision: int) -> Dictionary:
 if expected_revision!=revision: return {"ok":false,"error":"목록이 변경됐어. 다시 선택해줘."}
 var quote := craft_quote(action,target,material)
 if not quote.ok: return quote
 gold -= quote.cost
 inventory = quote.inventory
 revision += 1
 return quote
func roll(rng: RandomNumberGenerator, recipe: Array = [], new_shop := true) -> void:
 if new_shop: research_sold = false
 affinity.clear()
 for id in recipe:
  for tag in Spells.tags(id):
   if not tag in affinity: affinity.append(tag)
 var pool: Array = []
 for id in PRICES:
  if can_stock(id): pool.append(id)
 offers = [{"id":"","price":0,"sold":research_sold,"research":true}]
 for slot in (4 if relics!=null and relics.has("display") else 3):
  var related: Array = []
  if slot == 0:
   for id in pool:
    if not fits_recipe(id,recipe): continue
    for tag in Spells.tags(id):
     if tag in affinity:
      related.append(id)
      break
  var candidates: Array = related if not related.is_empty() else pool
  if candidates.is_empty():
   offers.append({"id":"","price":0,"sold":true})
   continue
  var id: String = candidates[rng.randi_range(0,candidates.size()-1)]
  pool.erase(id)
  offers.append({"id":id,"price":PRICES[id],"base_price":PRICES[id],"sold":false})
 if relics!=null and relics.has("seal"):
  var candidates: Array = []
  for index in range(1,offers.size()):
   if not offers[index].sold and not offers[index].id.is_empty(): candidates.append(index)
  if not candidates.is_empty():
   var chosen: int = candidates[rng.randi_range(0,candidates.size()-1)]
   offers[chosen].price = 0
   offers[chosen]["free"] = true
 revision += 1
func select_research(id: String, expected_revision: int) -> bool:
 if expected_revision != revision or research_sold or not PRICES.has(id) or not can_stock(id) or offers.is_empty(): return false
 offers[0] = {"id":id,"price":PRICES[id],"sold":false,"research":true}
 revision += 1
 return true
func buy(index: int, expected_revision: int) -> bool:
 if expected_revision != revision or index<0 or index>=offers.size(): return false
 var offer: Dictionary = offers[index]
 if offer.sold or offer.id.is_empty() or not can_stock(offer.id) or gold<offer.price: return false
 if index==0 and research_sold: return false
 gold -= int(offer.price)
 inventory[offer.id] = int(inventory.get(offer.id,0))+1
 offer.sold = true
 if index==0: research_sold = true
 revision += 1
 return true
func reroll(rng: RandomNumberGenerator, recipe: Array = []) -> bool:
 if gold<REROLL_COST: return false
 gold -= REROLL_COST
 roll(rng,recipe,false)
 return true

func fits_recipe(id: String, recipe: Array) -> bool:
 if recipe.is_empty(): return true
 var kind: String = Spells.PARTS[id].kind
 for index in recipe.size():
  var old_kind: String = Spells.definition(recipe[index]).kind
  if kind==old_kind:
   var changed := recipe.duplicate()
   changed[index] = id
   if Spells.compile(changed).ok: return true
 if kind=="modifier":
  for index in range(recipe.size()+1):
   var inserted := recipe.duplicate()
   inserted.insert(index,id)
   if Spells.compile(inserted).ok: return true
 if kind=="connector" and Spells.compile(recipe+[id,"bolt"]).ok: return true
 return false
