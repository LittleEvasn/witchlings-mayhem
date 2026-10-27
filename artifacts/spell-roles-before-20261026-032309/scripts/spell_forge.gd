extends RefCounted
const Spells = preload("res://scripts/spells.gd")
## Tokens reserve fungible inventory copies. Keep equipped copies when spare stock pays.
static func reconcile(bank: Array, target: String, quote: Dictionary, preferred: int) -> Array:
	var result: Array = bank.duplicate(true)
	var order: Array = [preferred,1-preferred]
	var replaced := false
	for orb in order:
		for index in result[orb].size():
			if not replaced and result[orb][index]==target:
				result[orb][index] = quote.output
				replaced = true
	var counts := {}
	for orb in order:
		var remove: Array = []
		var original: Array = result[orb].duplicate()
		for index in original.size():
			var token: String = original[index]
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
		remove.sort()
		remove.reverse()
		for index in remove: result[orb].remove_at(index)
		if not remove.is_empty():
			while not result[orb].is_empty() and Spells.definition(result[orb].back()).kind!="attack": result[orb].pop_back()
	return result

static func valid(bank: Array, inventory: Dictionary) -> bool:
	var counts := {}
	for parts in bank:
		if parts.size()>6: return false
		for id in parts:
			counts[id] = int(counts.get(id,0))+1
			if not Spells.has_part(id) or counts[id]>int(inventory.get(id,0)): return false
	# An unfinished draft remains editable and silent, including after crafting.
	return true
