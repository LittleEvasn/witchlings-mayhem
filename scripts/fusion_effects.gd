extends RefCounted
## Catalog fusion events are handled once by the common extension layer.
var owner_ref: WeakRef
var pending: Array=[]
func _init(owner_runtime: RefCounted) -> void: owner_ref=weakref(owner_runtime)
func clear() -> void: pending.clear()
func update(_delta: float) -> void: pass
func event(c: Dictionary, event_name: String, at: Vector2) -> void:
 var runtime: RefCounted=owner_ref.get_ref()
 if event_name=="impact": runtime.extensions.impact(c,at)
 elif event_name=="path_contact" and c.stage.get("fusion","")=="thermal_trail" and not c.get("_thermal",false):
  var frozen:=false
  for enemy in runtime.extensions.targets(at,30):
   if runtime.behavior.state_for(enemy).frozen_until>runtime.behavior.clock: frozen=true
  if frozen:
   c["_thermal"]=true
   runtime.extensions.area(c,at,24*runtime.behavior.damage_scale(c),70*c.scale)
