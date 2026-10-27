extends RefCounted
## Intrinsic effects have no user connector or fusion recursion. Clear cancels delays.
var runtime_ref: WeakRef
var pending: Array = []
func _init(owner_runtime: RefCounted) -> void: runtime_ref = weakref(owner_runtime)
func clear() -> void: pending.clear()
func update(delta: float) -> void:
	var runtime: RefCounted = runtime_ref.get_ref()
	for i in range(pending.size()-1,-1,-1):
		var item: Dictionary = pending[i]
		item.delay -= delta
		if item.delay>0: continue
		pending.remove_at(i)
		if item.generation!=runtime.generation or not runtime.game.magic_active(): continue
		runtime.behavior.area(item.context,item.pos,item.damage,item.radius)
		if not runtime.game.magic_active(): return

func later(c: Dictionary, at: Vector2, damage: float, radius: float, delay: float) -> void:
	var runtime: RefCounted = runtime_ref.get_ref()
	if pending.size()>=128:
		runtime.track("fusion_delays_blocked",c.meter_source)
		return
	pending.append({"context":c.duplicate(),"pos":at,"damage":damage,"radius":radius,"delay":delay,"generation":c.generation})

func intrinsic(c: Dictionary, attack: String, at: Vector2, options: Dictionary = {}) -> void:
	var runtime: RefCounted = runtime_ref.get_ref()
	var game: Node2D = runtime.game
	var child: Dictionary = c.stage.duplicate()
	child.attack = attack
	child.fusion = ""
	child["source_id"] = attack
	child["attack_profile"] = game.Spells.Progression.attack_profile(game.Spells.Progression.key(attack,3))
	child.fan = 0
	child.echo = 0
	child.bounce = 0
	child["_echo_copy"] = true
	child["_intrinsic"] = true
	child["_linked"] = true
	child["_connector_potency"] = c.get("potency",1.0)
	child.next = {}
	child.connector = ""
	child.merge(options,true)
	runtime.emit(child,at,c.dir,{},c.factor*0.65,c.power,"intrinsic",c.get("meter_echo",false),c.cast_id,c.generation,at)

func event(c: Dictionary, event_name: String, at: Vector2) -> void:
	var runtime: RefCounted = runtime_ref.get_ref()
	var game: Node2D = runtime.game
	var id: String = c.stage.get("fusion","")
	var expected: String = {"storm_spear":"impact","nova_garden":"expire","moon_ring":"on_return","firework_trail":"path_contact","frost_blossom":"activated","frost_gate":"impact","thunder_trap":"activated","moon_vortex":"installed","petal_return":"return_start"}.get(id,"")
	if expected.is_empty() or expected!=event_name or c.get("fusion_fired",false) or not game.magic_active(): return
	c["fusion_fired"] = true
	runtime.track("fusion_"+id,c.meter_source)
	var effect := c.duplicate()
	effect["hit_origin"] = "internal"
	effect["meter_source"] = c.meter_source+"/intrinsic"
	match id:
		"nova_garden":
			runtime.behavior.area(effect,at,32*runtime.behavior.damage_scale(c),c.radius*1.12)
		"firework_trail":
			runtime.behavior.area(effect,at,22*runtime.behavior.damage_scale(c),52*c.scale)
		"frost_blossom":
			effect["finish_cold"] = true
			later(effect,at,20*runtime.behavior.damage_scale(c),c.radius,0.3)
		"petal_return":
			for i in c.buds.size(): later(effect,c.buds[i],28*runtime.behavior.damage_scale(c),75*c.scale,0.08+i*0.15)
		"storm_spear", "thunder_trap": intrinsic(c,"thunder",at)
		"frost_gate": intrinsic(c,"frost",at)
		"moon_ring": intrinsic(c,"satellite",game.player.position,{"_follow_player":true})
		"moon_vortex": intrinsic(c,"satellite",at,{"_orbit_radius":c.radius,"_orbit_life":c.life,"_anchor_zone":c._zone_uid})
