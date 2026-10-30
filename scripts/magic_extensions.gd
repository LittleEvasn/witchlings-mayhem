extends RefCounted
## Independent movement, finite derivations and elemental reactions for catalog v1.
## Every derived object consumes its spawn permissions; cancellation is not expiry.
const InstantLaser = preload("res://scripts/instant_laser.gd")
var owner_ref: WeakRef
var runtime: RefCounted:
	get: return owner_ref.get_ref()
var game: Node2D
var jobs: Array=[]
var timed: Array=[]
var beams: Array=[]
var clouds: Array=[]
var replays: Array=[]
var status: Dictionary={}
var clock:=0.0

func _init(owner_runtime: RefCounted) -> void:
	owner_ref=weakref(owner_runtime)
	game=owner_runtime.game

func clear() -> void:
	jobs.clear();timed.clear();beams.clear();clouds.clear();replays.clear();status.clear()

func rank_value(stage: Dictionary, id: String) -> float:
	return game.Spells.Effects.value(stage,id) if stage.get(id,0)>0 else 0.0

func motion(stage: Dictionary) -> String:
	var result:=""
	for m in stage.get("modifiers",[]):
		if m.id in ["seek","orbit"]: result=m.id
		elif m.id in ["chase_pierce","devour_bounce"]: result="seek"
		elif m.id=="orbit_afterimage": result="orbit"
	return result

func schedule(job: Dictionary) -> void:
	if jobs.size()>=128:
		runtime.track("extension_jobs_blocked")
		return
	job["generation"]=runtime.generation
	jobs.append(job)

func intercept(stage: Dictionary, origin: Vector2, direction: Vector2, follow: Dictionary, factor: float, power: float, lane: String, echo: bool, lineage: int, generation: int, point: Vector2) -> bool:
	var fid: String=stage.get("fusion","")
	if (stage.get("fall",0)>0 or fid in ["meteor","meteor_thorn"]) and not stage.get("_landed",false):
		var target:=point if point!=Vector2.INF else origin+direction*200
		if not stage.get("_linked",false):
			var enemy: Node2D=game.nearest_enemy(origin,360)
			if enemy!=null: target=enemy.position
			target=origin.move_toward(target,360)
		var copy:=stage.duplicate(true)
		copy["_landed"]=true
		copy["_landing_anchor"]=target
		var delay:=rank_value(stage,"fall") if stage.get("fall",0)>0 else .55
		schedule({"kind":"land","delay":maxf(.15,delay),"stage":copy,"pos":target,"dir":direction,"follow":follow,"factor":factor,"power":power,"lane":lane,"echo":echo,"lineage":lineage,"point":target})
		runtime.track("falls_scheduled")
		return true
	return false

func attach(c: Dictionary) -> void:
	c["_ended"]=false
	c["_motion"]=motion(c.stage)
	c["_anchor"]=c.stage.get("_landing_anchor",c.pos)
	c["_motion_age"]=0.0
	c["_path_distance"]=c.get("_path_distance",0.0)
	c["_trail_count"]=c.get("_trail_count",0)
	c["_split_fired"]=false
	c["_bounce_left"]=int(game.Spells.Effects.profile(c.stage,"bounce").targets)
	c["_history"]=[]
	c["_history_clock"]=0.0
	if c.stage.get("connector","")=="timer" and not c.follow.is_empty():
		c["_timer_left"]=c.get("_timer_remaining",[.6,.55,.5,.45][clampi(int(c.stage.get("connector_rank",0)),0,3)])
		if timed.size()<512: timed.append(c)
		else: runtime.track("timers_blocked",c.meter_source)
	if c.stage.has("_rejoin_anchor") and c.has("speed"):
		c.life=maxf(.15,2*c.pos.distance_to(c.stage._rejoin_anchor)/c.speed)
	if c.stage.get("fusion","")=="ball_lightning":
		c["speed"]=150.0
		c["life"]=3.0
		c["radius"]=15*c.scale
		c["pierce"]=3
		c["_discharge_left"]=.4
	if c.stage.get("fusion","")=="shining_spear": c["pierce"]=5
	if c.stage.get("fusion","")=="growing_firecore": c["_base_radius"]=c.get("radius",10.0)
	if c.stage.get("_landed",false) and c.attack=="fireball":
		impact(c,c.pos)
		c["life"]=0.0
	if c.stage.get("fusion","")=="timed_thorn" and c.get("kind","")=="thorn":
		for n in 3: schedule({"kind":"thorn_wave","delay":.65+n*.65,"source":c,"pos":c.pos,"last":n==2})
	if c.stage.get("fusion","")=="meteor_thorn" and c.get("kind","")=="thorn":
		c["radius"]=c.get("radius",80.0)*.65
		var twin:=c.duplicate(true)
		twin.stage=twin.stage.duplicate(true)
		twin.stage.fusion=""
		twin.follow={};twin.connector="";twin.pos+=c.dir.orthogonal()*75
		twin["_ended"]=false
		twin["_split_fired"]=true
		runtime.add_zone(twin)
		runtime.behavior.flash({"kind":"arc","pos":c.pos,"to":twin.pos,"life":.5})
	if c.stage.get("fusion","")=="orbit_vortex" and c.get("kind","")=="vortex":
		c["_motion"]="orbit";c["_transfer_ids"]={}
		var twin:=c.duplicate(true)
		twin.stage=twin.stage.duplicate(true)
		twin.stage.fusion=""
		twin["_orbit_phase"]=PI
		twin.follow={};twin.connector=""
		twin.erase("garden_id")
		runtime.add_zone(twin)
	if c.stage.get("fusion","")=="judgement":
		c.life=.8;c.pulses_left=1;c.strike_radius=40*c.scale
	if c.stage.get("fusion","")=="collapse_vortex": c["_captured"]={}
	if not c.stage.get("_split_child",false):
		c["_split_launch"]={"life":float(c.get("initial_life",c.get("life",0.0))),"speed":float(c.get("speed",0.0)),
			"radius":float(c.get("radius",c.get("width",0.0))),"pierce":int(c.get("pierce",0))}

func move(c: Dictionary, delta: float, old: Vector2) -> void:
	c._motion_age+=delta
	if c._motion=="orbit":
		var anchor: Vector2=c._anchor
		if not c.stage.get("_linked",false) and not c.stage.get("_landed",false): anchor=game.player.position
		var radius:=rank_value(c.stage,"orbit")
		if radius<=0: radius=110.0
		var angle: float=c._motion_age*2.5+float(c.get("_orbit_phase",0))
		c.pos=anchor+Vector2.RIGHT.rotated(angle)*radius
		c.dir=Vector2.RIGHT.rotated(angle+PI/2)
		# A local orbit is a movement mode, not another independently growing spell.
		if c.has("speed"): c.speed=maxf(c.speed,150)
	if c.stage.get("fusion","")=="growing_firecore":
		c.radius=c._base_radius*(1+minf(2,c._motion_age)*.7)
		c["_growth_damage"]=1+minf(2,c._motion_age)*.35
	if c.stage.get("fusion","")=="echo_return" and c.has("speed"):
		c._history_clock-=delta
		if c._history_clock<=0 and c._history.size()<96:
			c._history.append(c.pos);c._history_clock=.06
	if c.stage.get("fusion","")=="ball_lightning":
		c._discharge_left-=delta
		if c._discharge_left<=0:
			c._discharge_left+=.4
			arc(c,c.pos,95,9*runtime.behavior.damage_scale(c),{})
	if c.stage.get("fusion","")=="collapse_vortex":
		for e in targets(c.pos,c.radius): c._captured[e.get_instance_id()]=true
	if c.stage.get("fusion","")=="orbit_vortex" and c.has("_transfer_ids"):
		for e in targets(c.pos,c.radius*.4):
			if e.boss or c._transfer_ids.has(e.get_instance_id()): continue
			c._transfer_ids[e.get_instance_id()]=true
			e.position=c._anchor-(c.pos-c._anchor)+Vector2(12,0)
			runtime.track("vortex_transfers",c.meter_source)
	if c.stage.get("trail",0)>0 or c.stage.get("orbit_afterimage",0)>0:
		c._path_distance+=old.distance_to(c.pos)
		var limit:=int(rank_value(c.stage,"trail")) if c.stage.get("trail",0)>0 else 2
		if c._path_distance>=90 and c._trail_count<limit and not c.stage.get("_derived",false) and not c.stage.get("_echo_copy",false):
			c._path_distance-=90;c._trail_count+=1
			if c.has("speed"):
				var child:=derived(c,.2)
				child["_support_scale"]=.7
				if c.stage.get("orbit_afterimage",0)>0:
					child.orbit=0
					child.modifiers=child.modifiers.filter(func(m):return m.id!="orbit_afterimage" and m.id!="orbit")
					child["_rejoin_anchor"]=c._anchor
					schedule_cast(c,child,c.pos,c.pos.direction_to(c._anchor),0)
				else: schedule_cast(c,child,c.pos,c.dir,0)
			else: cloud(c,c.get("_trail_point",c.pos),28*c.scale,.6,4*runtime.behavior.damage_scale(c),"afterimage")
			runtime.track("trail_copies",c.meter_source)

func targets(at: Vector2, radius: float, excluded: Dictionary={}) -> Array:
	return runtime.support.targets(at,radius,excluded)

func internal(c: Dictionary) -> Dictionary:
	var result:=c.duplicate()
	result["hit_origin"]="internal"
	result["meter_source"]=c.meter_source+"/intrinsic"
	return result

func area(c: Dictionary, at: Vector2, damage: float, radius: float) -> void:
	runtime.behavior.area(internal(c),at,damage,radius)

func arc(c: Dictionary, at: Vector2, radius: float, damage: float, excluded: Dictionary) -> void:
	var candidates:=targets(at,radius,excluded)
	if candidates.is_empty(): return
	var enemy: Node2D=candidates[0]
	game.damage_enemy(enemy,damage,Vector2.ZERO,c.meter_source+"/discharge")
	runtime.behavior.flash({"kind":"arc","pos":at,"to":enemy.position,"life":.15})
	runtime.track("discharges",c.meter_source)

func derived(c: Dictionary, share: float) -> Dictionary:
	var stage: Dictionary=c.stage.duplicate(true)
	stage["_derived"]=true;stage["_echo_copy"]=true
	stage["_derived_share"]=share
	stage["_proc_mass"]=float(stage.get("_proc_mass",1.0))*share
	stage["_landed"]=true
	stage["next"]={};stage["connector"]="";stage["fusion"]=""
	stage.modifiers=stage.modifiers.filter(func(m):return m.id not in ["split","trail","echo","growing_echo","orbit_afterimage"])
	for id in ["split","trail","echo","growing_echo","orbit_afterimage"]: stage[id]=0
	stage["modifier_effects"]=game.Spells.Effects.resolve(stage)
	return stage

func schedule_cast(c: Dictionary, stage: Dictionary, at: Vector2, dir: Vector2, delay: float) -> void:
	schedule({"kind":"cast","stage":stage,"pos":at,"dir":dir,"factor":c.factor*float(stage.get("_derived_share",1.0)),"power":c.power,"delay":delay,"lineage":c.cast_id})

func split(c: Dictionary, at: Vector2) -> void:
	if c.get("_split_fired",false) or c.stage.get("split",0)<=0 or c.stage.get("_derived",false) or c.stage.get("_echo_copy",false): return
	c._split_fired=true
	var count:=int(rank_value(c.stage,"split"))
	var launch: Dictionary=c.get("_split_launch",{})
	var radius: float=float(launch.get("radius",c.get("radius",c.get("width",0.0))))*.8
	var first_angle: float=game.rng.randf()*TAU
	for n in count:
		# Magicraft 3013: inherit launch-time buffs and full capacities.
		# Only damage, physical size, speed and knockback shrink.
		var child:=derived(c,1.0)
		child["_split_child"]=true
		child["_split_damage_ratio"]=.33
		child["_split_knockback_scale"]=.5
		child["_support_scale"]=float(child.get("_support_scale",1.0))*.8
		child["_split_radius"]=radius
		child["_split_speed"]=float(launch.get("speed",c.get("speed",0.0)))*.5
		child["_split_life"]=float(launch.get("life",c.get("initial_life",c.get("life",0.0))))
		child["_split_pierce"]=int(launch.get("pierce",c.get("pierce",0)))
		child["_split_range"]=float(c.get("length",0.0))*.5
		child["_linked"]=true
		# Split children start a fresh life: ordinary fireballs must not be
		# treated as already-landed instant explosions. Fall repeats its landing.
		child["_landed"]=false
		# Preserve the original attack identity; disable one-time cast cloning.
		child["fusion"]=str(c.stage.get("fusion",""))
		child["fan"]=0
		child["growing_echo"]=0
		child["attack_profile"]=child.attack_profile.duplicate(true)
		child.attack_profile.angles=[0.0]
		child.modifiers=child.modifiers.filter(func(m):return m.id not in ["fan","growing_echo"])
		child["modifier_effects"]=game.Spells.Effects.resolve(child)
		var direction: Vector2=Vector2.RIGHT.rotated(first_angle+TAU*float(n)/float(count))
		var start: Vector2=at if child.get("fall",0)>0 else at+direction*maxf(radius,0.333)
		schedule_cast(c,child,start,direction,0)
	runtime.track("split_children",c.meter_source,count)

func redirect(c: Dictionary, at: Vector2) -> bool:
	if c.get("_bounce_left",0)<=0: return false
	var choices:=targets(at,260,c.get("hit",{}))
	if choices.is_empty(): return false
	var enemy: Node2D=choices.back() if c.stage.get("devour_bounce",0)>0 else choices[0]
	c._bounce_left-=1
	c.dir=at.direction_to(enemy.position);c.target=enemy
	if c.has("leg_start"): runtime.moon_leg(c,enemy.position,enemy)
	if c.stage.get("devour_bounce",0)>0:
		for e in targets((at+enemy.position)*.5,at.distance_to(enemy.position)*.5+40,c.get("hit",{})):
			if e==enemy or Geometry2D.get_closest_point_to_segment(e.position,at,enemy.position).distance_to(e.position)>e.radius+6: continue
			c.hit[e.get_instance_id()]=true
			game.damage_enemy(e,c.damage*.4,Vector2.ZERO,c.meter_source+"/hop_path")
	runtime.track("bounce_redirects",c.meter_source)
	return true

func impact(c: Dictionary, at: Vector2) -> void:
	# Impacts only split when they destroy the source; finish() owns the event.
	var fid: String=c.stage.get("fusion","")
	var power: float=runtime.behavior.damage_scale(c)
	if c.attack=="fireball" and not c.get("_fireball_exploded",false):
		c["_fireball_exploded"]=true
		runtime.behavior.area(c,at,28*power*float(c.get("_growth_damage",1)),game.Spells.attack_data(c.stage).radius*c.scale)
	if fid=="shining_spear":
		for side in [-1,1]: area(c,at+c.dir.orthogonal()*side*36,9*power,28*c.scale)
		runtime.track("fusion_"+fid,c.meter_source)
	if c.get("_fusion_once",false): return
	c["_fusion_once"]=true
	match fid:
		"glitter_bomb":
			for n in 8:
				var child:=derived(c,.065)
				child.attack="bolt";child.source_id="bolt";child.attack_profile=game.Spells.Progression.attack_profile("bolt")
				child["_glitter"]=true
				schedule_cast(c,child,at,Vector2.RIGHT.rotated(n*TAU/8),0)
		"poison_mist": cloud(c,at,110*c.scale,3,5*power,"poison")
		"twin_moons":
			c.damage*=.65
			for side in [1]:
				var child:=derived(c,.4)
				schedule_cast(c,child,at,c.dir.rotated(side*.8),0)
		"thunder_seal": cloud(c,at,45*c.scale,2.5,32*power,"seal")
		"judgement":
			for n in 3: schedule({"kind":"area","delay":.1+n*.12,"source":c,"pos":at,"damage":18*power,"radius":(65+n*35)*c.scale})
		"meteor":
			for n in 4: schedule({"kind":"area","delay":n*.12,"source":c,"pos":at,"damage":16*power,"radius":(45+n*30)*c.scale,"annulus":true})
		"growing_firecore": schedule({"kind":"area","delay":.22,"source":c,"pos":at,"damage":28*power,"radius":140*c.scale})
		"plasma_beam": arc(c,at,180,24*power,c.get("_beam_hit_ids",{}))
	if not fid.is_empty(): runtime.track("fusion_"+fid,c.meter_source)

func finish(c: Dictionary, at: Vector2, normal:=true) -> void:
	if c.get("_ended",false): return
	c["_ended"]=true
	if not normal: return
	split(c,at)
	mirror_path(c)
	var power: float=runtime.behavior.damage_scale(c)
	if c.attack=="frost" and c.stage.get("trail",0)>0 and not c.stage.get("_derived",false) and not c.stage.get("_echo_copy",false):
		var points:=mini(2,int(rank_value(c.stage,"trail")))
		for n in points:
			var child:=derived(c,.2)
			schedule_cast(c,child,c.pos+c.dir*90*(n+1),c.dir,.08*(n+1))
			runtime.track("trail_copies",c.meter_source)
	match str(c.stage.get("fusion","")):
		"echo_return":
			if c.get("_history",[]).size()>1 and replays.size()<32:
				replays.append({"source":internal(c),"points":c._history.duplicate(),"index":0,"delay":.25,"hits":{},"generation":runtime.generation})
		"collapse_vortex": area(c,at,(20+mini(20,c.get("_captured",{}).size())*3)*power,c.get("radius",100)*1.25)
		"cold_flame": area(c,at,15*power,60*c.scale)
		"triple_frost":
			for side in [-1,0,1]: area(c,c.pos+c.dir.rotated(side*.24)*150*c.scale,14*power,38*c.scale)
		"dragon_breath": area(c,at,28*power,85*c.scale)
		"disintegration":
			for entry in c.get("_exposure",{}).values():
				if is_instance_valid(entry.enemy) and not entry.enemy.dead: area(c,entry.enemy.position,entry.seconds*30*power,45*c.scale)
	if c.stage.get("_glitter",false): schedule({"kind":"area","delay":.18,"source":c,"pos":at,"damage":18*power,"radius":42})

func mirror_path(c: Dictionary) -> void:
	if c.stage.get("fusion","")!="mirror_trail" or c.get("_mirror_fired",false): return
	c["_mirror_fired"]=true
	var points: Array=c.get("_mirror_points",[])
	for n in points.size():
		var entry: Dictionary=points[points.size()-1-n]
		schedule({"kind":"mirror","delay":.15*(n+1),"source":internal(c),"pos":entry.pos,"dir":entry.dir,"radius":entry.radius,"damage":entry.damage})
	runtime.track("mirror_path_replays",c.meter_source)

func cloud(c: Dictionary, at: Vector2, radius: float, life: float, damage: float, kind: String) -> void:
	# A shared local cell avoids one poison node for every victim/tick.
	for field in clouds:
		if field.kind==kind and field.owner_orb==c.get("owner_orb",0) and field.pos.distance_to(at)<24:
			field.life=maxf(field.life,life);field.damage=maxf(field.damage,damage)
			return
	if clouds.size()>=96: runtime.track("clouds_blocked",c.meter_source);return
	clouds.append({"source":internal(c),"owner_orb":c.get("owner_orb",0),"kind":kind,"pos":at,"radius":radius,"life":life,"age":0.0,"pulse":.25,"damage":damage,"generation":runtime.generation})

func elements(enemy: Node2D, amount: float, c: Dictionary, frozen_before: bool) -> void:
	if c.get("hit_origin","direct")!="direct" or enemy.dead: return
	var id: int=enemy.get_instance_id()
	var stage: Dictionary=c.stage
	# Non-ballistic shapes redirect their next local emission, not a free chain hit.
	if c.attack not in ["bolt","bloom","fireball","boomerang","laser","flamethrower"] and c.get("_bounce_left",0)>0 and not c.get("_redirected",false):
		var seen: Dictionary=c.get("contact_exclusions",{}).duplicate()
		seen[enemy.get_instance_id()]=true
		var choices:=targets(enemy.position,240,seen)
		if not choices.is_empty():
			c["_redirected"]=true
			var redirected:=derived(c,.5)
			redirected.bounce=0
			redirected.modifiers=redirected.modifiers.filter(func(m):return m.id not in ["bounce","devour_bounce"])
			redirected["modifier_effects"]=game.Spells.Effects.resolve(redirected)
			schedule_cast(c,redirected,choices[0].position,c.dir,.12)
			runtime.track("shape_redirects",c.meter_source)
	var proc: float=float(c.factor)
	if not status.has(id): status[id]={"enemy":enemy,"burn":0.0,"poison":0.0,"shock":0.0,"burn_damage":0.0,"poison_damage":0.0,"shock_damage":0.0,"pulse":.3,"source":internal(c),"last_pos":enemy.position,"reaction_left":0.0}
	var s: Dictionary=status[id]
	s.source=internal(c)
	var fire:=rank_value(stage,"element_fire")
	if c.attack in ["fireball","flamethrower","ember_path"] or stage.get("fusion","")=="cold_flame": fire=maxf(fire,1.0)
	var thermal: bool=frozen_before and fire>0
	if thermal:
		# Consume only the previously remaining burn. This hit never refills it first.
		if s.burn>0 and s.burn_damage>0:
			game.damage_enemy(enemy,s.burn*s.burn_damage,Vector2.ZERO,c.meter_source+"/thermal_cashout")
			runtime.track("thermal_cashouts",c.meter_source)
		s.burn=0.0;s.burn_damage=0.0
		var cold_state: Dictionary=runtime.behavior.state_for(enemy)
		cold_state.frozen_until=0.0;cold_state.cold=0.0;cold_state.cold_weighted=0.0
		cold_state.cold_sources.clear();cold_state.immune_until=runtime.behavior.clock+1.5
	elif fire>0:
		s.burn=3.0;s.burn_damage=maxf(s.burn_damage,6*float(c.power)*float(c.stage.get("rank_power",1))*float(c.get("potency",1))*fire*proc)
	if stage.get("element_poison",0)>0:
		s.poison=3.0;s.poison_damage=maxf(s.poison_damage,4*float(c.power)*float(c.stage.get("rank_power",1))*float(c.get("potency",1))*rank_value(stage,"element_poison")*proc)
	if stage.get("element_lightning",0)>0:
		s.shock=3.0;s.shock_damage=maxf(s.shock_damage,amount*.2*rank_value(stage,"element_lightning")*float(stage.get("_proc_mass",1)))
	var frozen_now: bool=runtime.behavior.state_for(enemy).frozen_until>runtime.behavior.clock
	if stage.get("temperature",0)>0 and frozen_now and not frozen_before and s.reaction_left<=0:
		s.reaction_left=1.0
		area(c,enemy.position,14*runtime.behavior.damage_scale(c),70*c.scale)
		runtime.track("temperature_waves",c.meter_source)

func cold(c: Dictionary, native: float) -> float:
	if c.get("hit_origin","direct")!="direct": return native
	return maxf(native,rank_value(c.stage,"element_ice")*float(c.factor))

func special(c: Dictionary) -> bool:
	if c.attack not in ["laser","flamethrower"]: return false
	if beams.size()>=48: runtime.track("beams_blocked",c.meter_source);return true
	# Magicraft spell 1004: resolve the entire laser trace at cast time.
	# Keep the separate disintegration fusion as a sustained spell (spell 1011).
	if c.attack=="laser" and c.stage.get("fusion","")!="disintegration":
		var profile: Dictionary=game.Spells.attack_data(c.stage)
		c["life"]=0.20
		c["age"]=0.0
		c["segments"]=[]
		c["_laser_instant"]=true
		c["_laser_end"]=c.pos+c.dir*480.0
		c["_beam_hit_ids"]={}
		c["length"]=float(c.stage.get("_split_range",480.0)) if c.stage.get("_split_child",false) else 480.0
		c["width"]=profile.radius*c.scale
		attach(c)
		beams.append(c)
		runtime.track("beams_created",c.meter_source)
		InstantLaser.fire(c,self)
		return true
	if beams.size()>=48: runtime.track("beams_blocked",c.meter_source);return true
	var data: Dictionary=game.Spells.attack_data(c.stage)
	c["life"]=data.life;c["age"]=0.0;c["pulse"]=0.0;c["segments"]=[];c["_exposure"]={};c["_beam_hit_ids"]={}
	c["length"]=480.0 if c.attack=="laser" else data.radius
	c["width"]=data.radius*c.scale if c.attack=="laser" else 0.0
	if c.stage.get("fusion","")=="disintegration":
		c.life=.9;c.width=6*c.scale;c["_charge_left"]=.35
	c["initial_life"]=c.life
	attach(c)
	beams.append(c)
	runtime.track("beams_created",c.meter_source)
	return true

func update_beams(delta: float) -> void:
	for c in beams.duplicate():
		if c.get("_laser_instant",false):
			# VFX persists briefly; hits and refraction never repeat on later frames.
			c.life-=delta
			c.age+=delta
			if c.life<=0:
				beams.erase(c)
				var at: Vector2=c.get("_laser_end",c.pos)
				finish(c,at)
				runtime.trigger(c,at,"expire")
			continue
		if c.get("_charge_left",0)>0:
			c._charge_left-=delta
			continue
		c.life-=delta;c.age+=delta;c.pulse-=delta
		if not c.stage.get("_linked",false) and not c.stage.get("_landed",false): c.pos=game.orb_position(c.owner_orb)
		move(c,delta,c.pos)
		if c._motion=="seek":
			var target: Node2D=game.nearest_enemy(c.pos,c.length)
			if target!=null: c.dir=c.dir.rotated(clampf(c.dir.angle_to(c.pos.direction_to(target.position)),-delta*game.Spells.seek_strength(c.stage),delta*game.Spells.seek_strength(c.stage)))
		if c.life<=0:
			beams.erase(c);finish(c,c.pos+c.dir*c.length)
			runtime.trigger(c,c.pos+c.dir*c.length,"expire")
			continue
		if c.pulse>0 and not c.segments.is_empty(): continue
		c.segments.clear()
		var contacts: Dictionary={}
		var branches: int=game.Spells.branches(c.stage)
		if c.stage.get("fusion","")=="dragon_breath": branches+=2
		for n in branches:
			var angle: float=(n-(branches-1)*.5)*.24
			if c.stage.get("fusion","")=="dragon_breath": angle*=maxf(.1,1-c.age/c.initial_life)
			var dir: Vector2=c.dir.rotated(angle)
			var end: Vector2=c.pos+dir*c.length
			var seen: Dictionary={}
			var found:=targets(c.pos,c.length+50)
			found.sort_custom(func(a,b):return (a.position-c.pos).dot(dir)<(b.position-c.pos).dot(dir))
			var remaining: int=(9999 if c.stage.get("fusion","")=="disintegration" else int(game.Spells.attack_data(c.stage).targets))+int(game.Spells.Effects.profile(c.stage,"pierce").targets)
			for e in found:
				var offset: Vector2=e.position-c.pos
				var inside: bool=offset.dot(dir)>=0 and offset.dot(dir)<=c.length and absf(offset.cross(dir))<=c.width+e.radius
				if c.attack=="flamethrower": inside=offset.length()<=c.length*c.scale+e.radius and absf(dir.angle_to(offset))<=deg_to_rad(game.Spells.attack_data(c.stage).spread*.5)
				if not inside: continue
				contacts[e.get_instance_id()]=e;seen[e.get_instance_id()]=true
				if c.attack=="laser":
					remaining-=1
					if remaining<=0: end=e.position;break
			c.segments.append([c.pos,end])
			# Redirected beam sections are actual spatial segments, not automatic chain damage.
			var hop_origin:=end
			for hop in int(game.Spells.Effects.profile(c.stage,"bounce").targets):
				if seen.is_empty(): break
				var options:=targets(hop_origin,200,seen)
				if options.is_empty(): break
				var target: Node2D=options[0]
				c.segments.append([hop_origin,target.position])
				for e in targets((hop_origin+target.position)*.5,hop_origin.distance_to(target.position)*.5+40,seen):
					if Geometry2D.get_closest_point_to_segment(e.position,hop_origin,target.position).distance_to(e.position)<=e.radius+maxf(5,c.width): contacts[e.get_instance_id()]=e;seen[e.get_instance_id()]=true
				hop_origin=target.position
		if c.pulse<=0:
			c.pulse+=.1
			c._beam_hit_ids=contacts.duplicate()
			for e in contacts.values():
				if e.dead: continue
				runtime.behavior.hit(e,(6.0 if c.attack=="laser" else 4.0)*runtime.behavior.damage_scale(c),c.dir,c)
				runtime.trigger(c,e.position)
				impact(c,e.position)
				var id: int=e.get_instance_id()
				if not c._exposure.has(id): c._exposure[id]={"enemy":e,"seconds":0.0}
				c._exposure[id].seconds+=.1
			if c.stage.get("fusion","")=="poison_flame" and not c.get("_gas",false):
				c["_gas"]=true;cloud(c,c.pos+c.dir*c.length,65*c.scale,1.2,4*runtime.behavior.damage_scale(c),"gas")
			if not contacts.is_empty(): split(c,contacts.values()[0].position)

func update(delta: float) -> void:
	clock+=delta
	for c in timed.duplicate():
		if c.get("_ended",false) or c.generation!=runtime.generation:
			timed.erase(c);continue
		c._timer_left-=delta
		if c._timer_left<=0:
			timed.erase(c);runtime.trigger(c,c.pos,"timer")
	var ready: Array=[]
	for i in range(jobs.size()-1,-1,-1):
		jobs[i].delay-=delta
		if jobs[i].delay<=0: ready.append(jobs[i]);jobs.remove_at(i)
	for job in ready:
		if job.generation!=runtime.generation or not game.magic_active(): continue
		match str(job.kind):
			"land":
				runtime.emit(job.stage,job.pos,job.dir,job.follow,job.factor,job.power,job.lane,job.echo,job.lineage,job.generation,job.point)
				runtime.track("falls_landed")
			"cast": runtime.emit(job.stage,job.pos,job.dir,{},job.factor,job.power,"derived",true,job.lineage,job.generation,job.pos)
			"area":
				if job.get("annulus",false):
					for e in targets(job.pos,job.radius):
						if e.position.distance_to(job.pos)<job.radius-35: continue
						game.damage_enemy(e,job.damage,Vector2.ZERO,job.source.meter_source+"/shockwave")
					game.ring(job.pos,job.radius,Color("ffba80"),.25)
				else: area(job.source,job.pos,job.damage,job.radius)
			"thorn_wave":
				if not job.source.get("_ended",false):
					area(job.source,job.source.pos,job.source.damage*(1.0 if job.last else .4),job.source.radius)
					if job.last: job.source.life=0
			"mirror":
				for side in [-1,1]: cloud(job.source,job.pos+job.dir.orthogonal()*side*38,job.radius,.9,job.damage*.35,"mirror")
	update_beams(delta)
	update_status(delta)
	update_clouds(delta)
	for replay in replays.duplicate():
		replay.delay-=delta
		if replay.delay>0: continue
		replay.delay+=.06
		if replay.index>=replay.points.size(): replays.erase(replay);continue
		var at: Vector2=replay.points[replay.index]
		for e in targets(at,22,replay.hits):
			replay.hits[e.get_instance_id()]=true
			game.damage_enemy(e,12*runtime.behavior.damage_scale(replay.source),Vector2.ZERO,replay.source.meter_source+"/replay")
		runtime.behavior.flash({"kind":"vfx","effect":"moon","pos":at,"diameter":40,"total":.18,"life":.18})
		replay.index+=1

func update_status(delta: float) -> void:
	for id in status.keys():
		var s: Dictionary=status[id]
		if not is_instance_valid(s.enemy) or s.enemy.dead: status.erase(id);continue
		s.burn-=delta;s.poison-=delta;s.shock-=delta;s.pulse-=delta;s.reaction_left-=delta
		if s.poison>0 and s.last_pos.distance_to(s.enemy.position)>=48:
			s.last_pos=s.enemy.position
			cloud(s.source,s.last_pos,25,1.5,s.poison_damage,"poison")
		if s.pulse<=0:
			s.pulse+=.3
			if s.burn>0: game.damage_enemy(s.enemy,s.burn_damage*.3,Vector2.ZERO,s.source.meter_source+"/burn")
			if s.poison>0 and not s.enemy.dead: game.damage_enemy(s.enemy,s.poison_damage*.3,Vector2.ZERO,s.source.meter_source+"/poison")
			if s.shock>0 and not s.enemy.dead:
				s["shock_clock"]=float(s.get("shock_clock",0))+.3
				if s.shock_clock>=.6:
					s.shock_clock-=.6
					arc(s.source,s.enemy.position,150,s.shock_damage,{id:true})
					spread_status(s,id)
		if maxf(s.burn,maxf(s.poison,s.shock))<=0: status.erase(id)

func update_clouds(delta: float) -> void:
	for c in clouds.duplicate():
		c.life-=delta;c.age+=delta;c.pulse-=delta
		var enemies:=targets(c.pos,c.radius)
		if c.kind=="seal" and not enemies.is_empty() and c.age>.25:
			area(c.source,c.pos,c.damage,c.radius);c.life=0
		elif c.pulse<=0:
			c.pulse+=.3
			for e in enemies: game.damage_enemy(e,c.damage*.3,Vector2.ZERO,c.source.meter_source+"/"+c.kind)
		if c.life<=0:
			clouds.erase(c)
			if c.kind=="gas": area(c.source,c.pos,c.damage*4,c.radius*1.2)

func spread_status(s: Dictionary, source_id: int) -> void:
	var choices:=targets(s.enemy.position,150,{source_id:true})
	if choices.is_empty(): return
	var enemy: Node2D=choices[0]
	if enemy.dead: return
	var id: int=enemy.get_instance_id()
	if not status.has(id): status[id]={"enemy":enemy,"burn":0.0,"poison":0.0,"shock":0.0,"burn_damage":0.0,"poison_damage":0.0,"shock_damage":0.0,"pulse":.3,"source":s.source,"last_pos":enemy.position,"reaction_left":0.0}
	var target: Dictionary=status[id]
	# Transferred statuses carry no shock: a reaction cannot start another propagation tree.
	for kind in ["burn","poison"]:
		if s[kind]<=0: continue
		target[kind]=maxf(target[kind],minf(1,s[kind]))
		target[kind+"_damage"]=maxf(target[kind+"_damage"],s[kind+"_damage"]*.3)
	var cold_state: Dictionary=runtime.behavior.state_for(s.enemy)
	if cold_state.cold>0:
		runtime.behavior.hit(enemy,0,Vector2.ZERO,s.source,.3)
	runtime.track("status_spreads",s.source.meter_source)
