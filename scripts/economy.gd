extends RefCounted
const Spells = preload("res://scripts/spells.gd")
const Progression = preload("res://scripts/spell_progression.gd")
const PRICES := {"bolt":8,"bloom":12,"fan":14,"seek":16,"pierce":12,"impact":10,"boomerang":14,"vortex":18,"thorn":14,"bounce":14,"giant":14,"echo":18,"charge":18,"frost":14,"thunder":16,"expire":10,"satellite":16,"ember_path":14}
const CLEAR_REWARD := 20
const REROLL_COST := 5
const KITS := {
 "garden":{"name":"작은 정원","note":"같은 곳에 심으면 더 자라려나?","orbs":["giant","vortex"],"recipe":["giant","vortex"]},
 "charge":{"name":"큰 한 발","note":"한 번만 크게 하면 덜 귀찮겠지?","orbs":["charge","bloom"],"recipe":["charge","bloom"]},
 "sigil":{"name":"반짝 연사","note":"별빛을 여러 방향으로 나누어 보자.","orbs":["fan"],"recipe":["fan","bolt"]},
 "frost":{"name":"얼음 실험","note":"먼저 얼리고, 다음에 깨뜨리자.","orbs":["frost"],"recipe":["frost","impact","bolt"]}}
const STARTING_INVENTORY := {"bolt":1,"impact":1,"fan":1}
var gold := 0
var total_earned := 0
var inventory: Dictionary = {}
var offers: Array = []
var revision := 0
var kit := "sigil"
var research_sold := false
var affinity: Array = []
var relics: RefCounted
var last_acquisition: Dictionary = {}
var fusion_history: Array = []
func _init() -> void: reset()
func reset(selected := "sigil") -> void:
 kit = selected if KITS.has(selected) else "sigil"
 gold = 0
 total_earned = 0
 last_acquisition.clear()
 fusion_history.clear()
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
  if id=="": continue
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
 var token := owned_token(id)
 return token.is_empty() or Progression.rank(token)<3

func owned_token(id: String) -> String:
 var base := Progression.base_id(id)
 for token in inventory:
  if inventory[token]>0 and Progression.base_id(token)==base: return token
 return ""

func acquire(id: String) -> Dictionary:
 if not can_stock(id): return {"ok":false,"error":"이미 최대 강화야."}
 var old := owned_token(id)
 var output := id if old.is_empty() else Progression.key(id,Progression.rank(old)+1)
 if not old.is_empty(): inventory.erase(old)
 inventory[output]=1
 revision+=1
 last_acquisition={"ok":true,"old":old,"output":output,"upgraded":not old.is_empty()}
 return last_acquisition.duplicate()

func normalize_owned() -> Dictionary:
 # Legacy saves retain all distinct types. Excess copies become paid investment refunds.
 var before := inventory.duplicate()
 var after := {}
 var refund := 0
 var remap := {}
 for token in before:
  var base := Progression.base_id(token)
  if remap.has(token): continue
  var group: Array=[]
  for other in before:
   if before[other]>0 and Progression.base_id(other)==base: group.append(other)
  group.sort_custom(func(a,b):return Progression.rank(a)>Progression.rank(b))
  var output: String=group[0]
  var level := Progression.rank(output)
  var copies := 0
  for other in group: copies+=int(before[other])
  if not Progression.is_fused(output):
   level=mini(3,level+copies-1)
   output=Progression.key(base,level)
  var investment := 0
  for other in group:
   investment+=investment_cost(other)*int(before[other])
   remap[other]=output
  after[output]=1
  refund+=maxi(0,investment-investment_cost(output))
 inventory=after
 gold+=refund
 revision+=1
 return {"remap":remap,"refund":refund,"changed":before!=after}

static func investment_cost(id: String) -> int:
 if Progression.is_fused(id):
  var parents: Array = Progression.FUSIONS[id].parents
  return investment_cost(Progression.key(parents[0],3))+investment_cost(Progression.key(parents[1],3))+Progression.FUSION_COST
 var price: int = PRICES.get(Progression.base_id(id),0)
 var total := price
 for level in Progression.rank(id): total += Progression.paid_cost(price,level)
 return total

func craft_quote(action: String, target: String, material := "") -> Dictionary:
 var fail := {"ok":false,"error":"강화할 공격·보조·연결 구체를 선택해줘."}
 if not Spells.has_part(target) or Spells.definition(target).kind not in ["attack","modifier","connector"]: return fail
 if inventory.get(target,0)<=0: return {"ok":false,"error":"%s 구체가 없어. 보유함 또는 합성 도감의 재료를 확인해줘." % Spells.definition(target).name}
 if Progression.is_fused(target): return {"ok":false,"error":"이미 합성이 완성된 마법이야."}
 var level := Progression.rank(target)
 var consumed: Array = [target]
 var cost := 0
 var output := ""
 match action:
  "merge":
   return {"ok":false,"error":"같은 마법을 획득하면 자동으로 +1 강화돼. 별도 합치기는 필요 없어."}
  "upgrade":
   if level>=3: return {"ok":false,"error":"+3는 최대 강화야."}
   cost = Progression.paid_cost(PRICES[Progression.base_id(target)],level)
   if relics!=null and relics.has("toolbox"): cost = ceili(cost*.8)
   output = Progression.key(Progression.base_id(target),level+1)
  "fuse":
   return {"ok":false,"error":"두 재료가 +3이면 다음 보상 상자에서 합성을 선택할 수 있어."}
  _: return fail
 var after := inventory.duplicate()
 for token in consumed:
  if after.get(token,0)<=0: return {"ok":false,"error":"필요한 구체 수량이 부족해. 재료 수량과 강화 단계를 확인해줘."}
  after[token] -= 1
  if after[token]==0: after.erase(token)
 after[output] = int(after.get(output,0))+1
 if gold<cost: return {"ok":false,"error":"마석(G)이 부족해. 필요 %d G / 보유 %d G" % [cost,gold],"cost":cost,"output":output,"inventory":after,"consumed":consumed}
 return {"ok":true,"error":"","cost":cost,"output":output,"consumed":consumed,"inventory":after}

func fusion_quote(id: String) -> Dictionary:
 if id not in Progression.FUSIONS or id in fusion_history or inventory.get(id,0)>0: return {"ok":false}
 var consumed: Array=[]
 var after := inventory.duplicate()
 for base in Progression.FUSIONS[id].parents:
  var token := Progression.key(base,3)
  if after.get(token,0)!=1: return {"ok":false}
  consumed.append(token)
  after.erase(token)
 after[id]=1
 return {"ok":true,"output":id,"consumed":consumed,"inventory":after,"cost":0}

func craft(action: String, target: String, material: String, expected_revision: int) -> Dictionary:
 if expected_revision!=revision: return {"ok":false,"error":"목록이 변경됐어. 다시 선택해줘."}
 var quote := craft_quote(action,target,material)
 if not quote.ok: return quote
 gold -= quote.cost
 inventory = quote.inventory
 if action=="fuse": fusion_history.append(quote.output)
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
 acquire(offer.id)
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
 if not Spells.has_content(recipe): return true
 var kind: String = Spells.PARTS[id].kind
 for index in recipe.size():
  var old_kind: String = Spells.definition(recipe[index]).kind
  if kind==old_kind:
   var changed := recipe.duplicate()
   changed[index] = id
   if Spells.compile(changed).ok: return true
 for index in recipe.size():
  if recipe[index]!="": continue
  var placed := recipe.duplicate()
  placed[index]=id
  if Spells.compile(placed).ok: return true
 return false
