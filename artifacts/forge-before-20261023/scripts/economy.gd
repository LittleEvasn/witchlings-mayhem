extends RefCounted
const Spells = preload("res://scripts/spells.gd")
const PRICES := {"bolt":8,"bloom":12,"fan":14,"seek":16,"pierce":12,"impact":10,"boomerang":14,"vortex":18,"thorn":14,"bounce":14,"giant":14,"echo":18,"charge":18,"graft":18,"sigil":18,"shatter":18,"frost":14,"thunder":16,"expire":10,"on_return":10,"satellite":16,"ember_path":14}
const CLEAR_REWARD := 20
const REROLL_COST := 5
const KITS := {
 "garden":{"name":"작은 정원","note":"같은 곳에 심으면 더 자라려나?","orbs":["graft","vortex"],"recipe":["graft","vortex"]},
 "charge":{"name":"큰 한 발","note":"한 번만 크게 하면 덜 귀찮겠지?","orbs":["charge","bloom"],"recipe":["charge","bloom"]},
 "sigil":{"name":"반짝 연사","note":"작은 별도 여섯 번이면 사고가 돼.","orbs":["sigil","fan"],"recipe":["fan","sigil","bolt"]},
 "frost":{"name":"얼음 실험","note":"먼저 얼리고, 다음에 깨뜨리자.","orbs":["frost","shatter"],"recipe":["frost","impact","shatter","bolt"]}}
const STARTING_INVENTORY := {"bolt":1,"impact":1,"sigil":1,"fan":1}
var gold := 0
var total_earned := 0
var inventory: Dictionary = {}
var offers: Array = []
var revision := 0
var kit := "sigil"
var research_sold := false
var affinity: Array = []
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
  else: cost += int(PRICES.get(id,0))
 return cost
func can_stock(id: String) -> bool:
 var count: int = inventory.get(id,0)
 if count == 0: return true
 if count >= 4: return false
 if Spells.PARTS[id].kind == "connector": return true
 # A second copy must fit in an actually legal two-stage recipe.
 if Spells.PARTS[id].kind == "attack": return true
 for attack in Spells.ATTACK_INTERVALS:
  if Spells.compile([id,attack,"impact",id,attack]).ok: return true
 return false
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
 for slot in 3:
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
  offers.append({"id":id,"price":PRICES[id],"sold":false})
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
  var old_kind: String = Spells.PARTS[recipe[index]].kind
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
