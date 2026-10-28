extends RefCounted
## Completed supports keep their own identity. Pending work is owned by one runtime.
var runtime_ref: WeakRef
var runtime: RefCounted:
	get: return runtime_ref.get_ref()
var jobs: Array=[]
func _init(owner_runtime: RefCounted) -> void: runtime_ref=weakref(owner_runtime)
func count(stage: Dictionary, id: String) -> int: return int(stage.get(id,0))
func clear() -> void: jobs.clear()

func repetitions(stage: Dictionary) -> Dictionary:
	var result: Dictionary={"primary":1.0,"copies":[]}
	if stage.get("_echo_copy",false): return result
	var waves:=count(stage,"wave_split")
	result.primary=1.0/(1+waves*2)
	for n in waves*2:
		result.copies.append({"factor":result.primary,"scale":1.0,"delay":.24*(n+1)})
	for n in count(stage,"growing_echo")*2:
		result.copies.append({"factor":.45*result.primary,"scale":1.3+.4*(n%2),"delay":.25*(n+1)})
	return result

func targets(at: Vector2, radius: float, excluded: Dictionary = {}) -> Array:
	var found: Array=runtime.game.nearby(at,radius).filter(func(e):return not e.dead and not excluded.has(e.get_instance_id()) and e.position.distance_to(at)<=radius)
	found.sort_custom(func(a,b):return at.distance_squared_to(a.position)<at.distance_squared_to(b.position))
	return found

func branch_direction(stage: Dictionary, at: Vector2, original: Vector2, index: int) -> Vector2:
	if count(stage,"swarm_seek")==0: return original
	var choices:=targets(at,320)
	return at.direction_to(choices[index%choices.size()].position) if not choices.is_empty() else original

func retarget(p: Dictionary) -> void:
	if count(p.stage,"chase_pierce")==0: return
	var choices:=targets(p.pos,260,p.hit)
	if choices.is_empty(): return
	p.target=choices[0]
	p.seek_clock=.15
	# A turn toward the next target, not an instantaneous reversal.
	p.dir=p.dir.rotated(clampf(p.dir.angle_to(p.pos.direction_to(p.target.position)),-.65,.65))
	runtime.track("chase_retargets",p.get("meter_source",""))

func stamp_point(c: Dictionary, at: Vector2) -> Vector2:
	if count(c.stage,"chase_pierce")==0 and count(c.stage,"swarm_seek")==0: return at
	var choices:=targets(at,220)
	if choices.is_empty(): return at
	var index: int=int(c.get("support_stamp",0))
	c["support_stamp"]=index+1
	return at.move_toward(choices[index%choices.size()].position,32)

func schedule(job: Dictionary) -> void:
	if jobs.size()>=96:
		runtime.track("support_jobs_blocked",job.get("source",{}).get("meter_source",""))
		return
	job["generation"]=job.get("generation",runtime.generation)
	jobs.append(job)

func terminal(c: Dictionary, at: Vector2) -> void:
	if not runtime.game.magic_active() or c.get("generation",-1)!=runtime.generation: return
	var owner: Dictionary=c.get("group",c)
	if count(c.stage,"leap_pierce")==0 or owner.get("leap_fired",false): return
	owner["leap_fired"]=true
	var amount: float=float(c.get("damage",runtime.behavior.DIRECT_DAMAGE.get(c.attack,22.0)*runtime.behavior.damage_scale(c)))*.5
	var choices:=targets(at,180,c.get("contact_exclusions",{}))
	for n in mini(3*count(c.stage,"leap_pierce"),choices.size()):
		var enemy: Node2D=choices[n]
		runtime.game.damage_enemy(enemy,amount,at.direction_to(enemy.position),c.get("meter_source","")+"/terminal")
		runtime.behavior.flash({"kind":"arc","pos":at,"to":enemy.position,"life":.18})
		runtime.track("terminal_hits",c.get("meter_source",""))
		if not runtime.game.magic_active(): return

func chain_echo(c: Dictionary, at: Vector2, amount: float) -> void:
	if count(c.stage,"echo_chain")==0: return
	schedule({"kind":"trace","pos":at,"damage":amount*.5,"delay":.35,"generation":c.generation,"source":{"meter_source":c.get("meter_source","")}})
	runtime.track("chain_traces_scheduled",c.get("meter_source",""))

func update(delta: float) -> void:
	# Remove first, then execute; emitted child spells may schedule fresh work.
	var ready: Array=[]
	for i in range(jobs.size()-1,-1,-1):
		jobs[i].delay-=delta
		if jobs[i].delay<=0:
			ready.append(jobs[i]);jobs.remove_at(i)
	for job in ready:
		if job.generation!=runtime.generation or not runtime.game.magic_active(): continue
		if job.kind=="child":
			runtime.emit(job.stage,job.pos,job.direction,{},job.factor,job.power,"chain",job.echo,job.lineage,job.generation,job.pos)
			runtime.track("delayed_children_fired",job.source.get("meter_source",""))
		else:
			# A fixed old location, no new targeting, chain, cold or connector events.
			for enemy in targets(job.pos,32):
				runtime.game.damage_enemy(enemy,job.damage,Vector2.ZERO,job.source.meter_source+"/trace")
				if not runtime.game.magic_active(): break
			runtime.game.ring(job.pos,32,Color("ffd99c"),.2)
			runtime.track("chain_traces_fired",job.source.meter_source)
