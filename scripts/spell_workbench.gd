extends RefCounted
## Lossless slot groups for legacy group actions; the compiler owns execution rules.
const Spells = preload("res://scripts/spells.gd")
static func unpack(recipe: Array) -> Dictionary:
	var groups: Array = []
	var pending: Array = []
	for id in recipe:
		pending.append(id)
		if Spells.definition(id).kind=="attack":
			groups.append({"attack":id,"mods":pending.filter(func(token):return Spells.definition(token).kind=="modifier"),"tokens":pending.duplicate()})
			pending.clear()
	if not pending.is_empty(): groups.append({"attack":"","mods":pending.duplicate(),"tokens":pending.duplicate()})
	return {"groups":groups}
static func pack(model: Dictionary) -> Array:
	var result: Array = []
	for group in model.groups: result.append_array(group.tokens)
	return result
static func put(recipe: Array, id: String, target: int, _connector := "") -> Array:
	var result := recipe.duplicate()
	result = Spells.fixed_slots(result)
	if target>=0 and target<Spells.SLOT_COUNT: result[target]=id
	return result
