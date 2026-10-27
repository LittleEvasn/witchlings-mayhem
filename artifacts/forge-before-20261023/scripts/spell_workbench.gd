extends RefCounted
## UI grouping only; the production compiler remains the source of spell semantics.
const Spells = preload("res://scripts/spells.gd")
static func unpack(recipe: Array) -> Dictionary:
	var result := {"groups":[{"attack":"","mods":[]},{"attack":"","mods":[]}],"connector":""}
	var group := 0
	for id in recipe:
		var kind: String = Spells.PARTS[id].kind
		if kind == "connector":
			result.connector = id
			group = 1
		elif kind == "attack": result.groups[group].attack = id
		else: result.groups[group].mods.append(id)
	return result
static func pack(model: Dictionary) -> Array:
	var result: Array = []
	for i in 2:
		var group: Dictionary = model.groups[i]
		if i==1:
			if group.attack.is_empty() and group.mods.is_empty():
				if not model.connector.is_empty(): result.append(model.connector)
				break
			if not model.connector.is_empty(): result.append(model.connector)
		result.append_array(group.mods)
		if not group.attack.is_empty(): result.append(group.attack)
	return result
static func put(recipe: Array, id: String, target: int, connector := "impact") -> Array:
	var model := unpack(recipe)
	var group: Dictionary = model.groups[clampi(target,0,1)]
	match Spells.PARTS[id].kind:
		"attack": group.attack = id
		"modifier":
			if id in group.mods: return recipe.duplicate()
			group.mods.append(id)
		"connector": model.connector = id
	if not model.groups[1].attack.is_empty() or not model.groups[1].mods.is_empty():
		if model.connector.is_empty(): model.connector = connector
	return pack(model)
