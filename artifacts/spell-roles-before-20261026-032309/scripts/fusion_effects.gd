extends RefCounted
## Fusion effects use existing bounded projectiles/fields. No recursive child fusion.
var runtime_ref: WeakRef
func _init(owner_runtime: RefCounted) -> void: runtime_ref = weakref(owner_runtime)
func event(c: Dictionary, event_name: String, at: Vector2) -> void:
	var runtime: RefCounted = runtime_ref.get_ref()
	var game: Node2D = runtime.game
	var id: String = c.stage.get("fusion","")
	var expected: String = {"storm_spear":"impact","nova_garden":"expire","moon_ring":"on_return","firework_trail":"path_contact"}.get(id,"")
	if expected.is_empty() or expected!=event_name or c.get("fusion_fired",false) or not game.magic_active(): return
	c["fusion_fired"] = true
	runtime.track("fusion_"+id,c.meter_source)
	match id:
		"nova_garden":
			runtime.behavior.area(c,at,32*runtime.behavior.damage_scale(c),c.radius*1.12)
		"firework_trail":
			runtime.behavior.area(c,at,22*runtime.behavior.damage_scale(c),52*c.scale)
		_:
			var child: Dictionary = c.stage.duplicate()
			child.attack = "thunder" if id=="storm_spear" else "satellite"
			child.fusion = ""
			child.fan = false
			child.echo = false
			child.graft = 0
			child.next = {}
			child.connector = ""
			# An internal fusion effect never carries the user's connector a second time.
			runtime.emit(child,at,c.dir,{},c.factor*0.65,c.power,c.lane,c.get("meter_echo",false),c.cast_id,c.generation,at)
