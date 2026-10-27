extends RefCounted
## Pure, repeat-safe conversion of retired role tokens. Equipped items are reservations.
const Progression = preload("res://scripts/spell_progression.gd")
const VERSION := 2
const RETIRED := ["graft","shatter"]

static func recipe(parts: Array) -> Array:
	var result: Array = []
	for token in parts:
		var base := Progression.base_id(str(token))
		if base in RETIRED: continue
		result.append("expire" if base=="on_return" else token)
	return result

static func bank(parts: Array) -> Array:
	return parts.map(func(row): return recipe(row))

static func plan(inventory: Dictionary, applied: Array, drafts: Array) -> Dictionary:
	var stock := {}
	var refund := 0
	for token in inventory:
		var count := int(inventory[token])
		var base := Progression.base_id(str(token))
		if base in RETIRED:
			var price := 18
			for level in clampi(Progression.rank(str(token)),0,4):
				price += Progression.paid_cost(18,level)
			refund += count*price
		else:
			var target: String = "expire" if base=="on_return" else str(token)
			stock[target] = int(stock.get(target,0))+count
	var live := bank(applied)
	var edited := bank(drafts)
	return {"version":VERSION,"inventory":stock,"applied":live,"drafts":edited,"refund":refund,
		"changed":stock!=inventory or live!=applied or edited!=drafts}
