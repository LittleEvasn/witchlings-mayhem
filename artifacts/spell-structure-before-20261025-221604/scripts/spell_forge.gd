extends RefCounted
const Spells = preload("res://scripts/spells.gd")
const Workbench = preload("res://scripts/spell_workbench.gd")
## Reconcile one bank of two loadouts with a planned inventory transaction.
## Prefer replacing a target in the selected orb. Spare materials are consumed first.
static func reconcile(bank: Array, target: String, quote: Dictionary, preferred: int) -> Array:
	var models: Array = [Workbench.unpack(bank[0]),Workbench.unpack(bank[1])]
	var order: Array = [preferred,1-preferred]
	var replaced := false
	var touched := [false,false]
	for token in quote.consumed:
		for orb in order:
			for group in models[orb].groups:
				if not replaced and group.attack==token:
					group.attack = quote.output
					touched[orb] = true
					replaced = true
	# Consume any equipped surplus left after the transaction, releasing its supports.
	var counts := {}
	for orb in order:
		for group in models[orb].groups:
			var id: String = group.attack
			if id.is_empty(): continue
			counts[id] = int(counts.get(id,0))+1
			if counts[id]>int(quote.inventory.get(id,0)):
				group.attack = ""
				group.mods = []
				touched[orb] = true
	var result: Array = bank.duplicate(true)
	for orb in 2:
		if not touched[orb]: continue
		var kept: Array = []
		for group in models[orb].groups:
			if not group.attack.is_empty() or not group.mods.is_empty(): kept.append(group)
		if kept.size()<2: models[orb].connector = ""
		while kept.size()<2: kept.append({"attack":"","mods":[]})
		models[orb].groups = kept
		result[orb] = Workbench.pack(models[orb])
	return result

static func valid(bank: Array, inventory: Dictionary) -> bool:
	var counts := {}
	var present := false
	for parts in bank:
		if not parts.is_empty():
			present = true
			if not Spells.compile(parts).ok: return false
		for id in parts:
			counts[id] = int(counts.get(id,0))+1
			if counts[id]>int(inventory.get(id,0)): return false
	return present
