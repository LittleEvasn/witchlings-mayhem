extends RefCounted
## Inventory counts include equipped orbs. Editing reserves copies without consuming them.
const PRICES := {"bolt":8,"bloom":12,"fan":14,"seek":16,"pierce":12,"impact":10,"boomerang":14,"vortex":18,"thorn":14,"bounce":14,"giant":14,"echo":18}
const CLEAR_REWARD := 20
const REROLL_COST := 5
var gold := 0
var total_earned := 0
var inventory: Dictionary = {}
var offers: Array = []
var revision := 0

func _init() -> void:
	reset()

func reset() -> void:
	gold = 0
	total_earned = 0
	inventory = {"bolt":1,"bloom":1,"impact":1,"fan":1}
	offers.clear()
	revision += 1

func grant(amount: int) -> void:
	if amount <= 0: return
	gold += amount
	total_earned += amount

func roll(rng: RandomNumberGenerator) -> void:
	var pool := PRICES.keys()
	offers.clear()
	revision += 1
	for i in 4:
		var index := rng.randi_range(0,pool.size()-1)
		var id: String = pool.pop_at(index)
		offers.append({"id":id,"price":PRICES[id],"sold":false})

func buy(index: int, expected_revision: int) -> bool:
	if expected_revision != revision or index < 0 or index >= offers.size(): return false
	var offer: Dictionary = offers[index]
	if offer.sold or gold < offer.price: return false
	gold -= offer.price
	inventory[offer.id] = inventory.get(offer.id,0)+1
	offer.sold = true
	return true

func reroll(rng: RandomNumberGenerator) -> bool:
	if gold < REROLL_COST: return false
	gold -= REROLL_COST
	roll(rng)
	return true

func remaining(id: String, reserved: Array) -> int:
	return maxi(0,int(inventory.get(id,0))-reserved.count(id))

func owns_recipe(recipe: Array) -> bool:
	for id in recipe:
		if recipe.count(id) > int(inventory.get(id,0)): return false
	return true
