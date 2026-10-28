extends RefCounted
const Spells = preload("res://scripts/spells.gd")
## Tokens reserve fungible inventory copies. Keep equipped copies when spare stock pays.
static func reconcile(bank: Array, target: String, quote: Dictionary, preferred: int, target_slot := -1, output_location: Dictionary = {}) -> Array:
	var result: Array = Spells.fixed_bank(bank)
	output_location.clear()
	output_location["orb"] = -1
	output_location["slot"] = -1
	var order: Array = [preferred]
	for i in bank.size():
		if i!=preferred: order.append(i)
	var chosen_orb := preferred
	var chosen_slot := target_slot
	if chosen_slot<0 or chosen_slot>=result[preferred].size() or result[preferred][chosen_slot]!=target:
		chosen_slot = -1
		for orb in order:
			var found: int = result[orb].find(target)
			if found>=0:
				chosen_orb = orb
				chosen_slot = found
				break
	if chosen_slot>=0: result[chosen_orb][chosen_slot] = quote.output
	var counts := {}
	for orb in order:
		var remove: Array = []
		var original: Array = result[orb].duplicate()
		for index in original.size():
			var token: String = original[index]
			if token.is_empty(): continue
			counts[token] = int(counts.get(token,0))+1
			if counts[token]<=int(quote.inventory.get(token,0)): continue
			remove.append(index)
			if Spells.definition(token).kind=="attack":
				# Removing a consumed attack also removes its incoming/outgoing event links;
				# never silently retarget a connector to the next surviving attack.
				for step in [-1,1]:
					var neighbour: int = index+step
					while neighbour>=0 and neighbour<original.size() and Spells.definition(original[neighbour]).kind!="attack":
						if Spells.definition(original[neighbour]).kind=="connector" and not neighbour in remove: remove.append(neighbour)
						neighbour += step
		for index in remove: result[orb][index] = ""
		if orb==chosen_orb and chosen_slot>=0 and result[orb][chosen_slot]==quote.output:
			output_location.orb = orb
			output_location.slot = chosen_slot

	return result

static func valid(bank: Array, inventory: Dictionary) -> bool:
	var counts := {}
	for parts in bank:
		if parts.size()>6: return false
		for id in parts:
			if id=="": continue
			counts[id] = int(counts.get(id,0))+1
			if not Spells.has_part(id) or counts[id]>int(inventory.get(id,0)): return false
	# An unfinished draft remains editable and silent, including after crafting.
	return true
