extends SceneTree
func _initialize() -> void:
 var s = preload("res://scripts/spells.gd")
 var definitions := {"attacks":[],"modifiers":[],"connectors":[],"allowed":{}}
 for id in s.PARTS:
  match s.PARTS[id].kind:
   "attack": definitions.attacks.append(id)
   "modifier": definitions.modifiers.append(id)
   "connector": definitions.connectors.append(id)
 for attack in definitions.attacks:
  definitions.allowed[attack] = []
  for mod in definitions.modifiers:
   if s.compatible(mod,attack): definitions.allowed[attack].append(mod)
 var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
 file.store_string(JSON.stringify(definitions))
 file.close()
 quit()
