extends RefCounted
const Meter = preload("res://scripts/combat_meter.gd")

func setup(g: Node2D) -> Dictionary:
	g.set_physics_process(false)
	g.sound_enabled=false
	g.start_run()
	g.complete_wave()
	g.choose_reward("power")
	g.economy.gold=200
	g.economy.inventory={"fan":2,"bolt":1,"impact":1,"bloom":2,"expire":1,"thunder":1,"bolt@2":2,"echo":2}
	g.orb_drafts=[["fan","bolt","impact","bloom","expire","thunder"],["bolt@2","bloom"]]
	g.draft=g.orb_drafts[0].duplicate()
	g._draft_changed()
	g.ui.inspect_item("fan",0,0)
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/spell-program-scope.png"))
	return {"summary":g.Spells.describe(g.draft),"state":g.state}

func forge(g: Node2D) -> Dictionary:
	g.ui.merge_material="bolt@2"
	g.ui.inspect_item("bolt@2",1,0)
	g.ui.merge_material="bolt@2"
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/spell-program-forge.png"))
	return controls(g)

func controls(g: Node2D) -> Dictionary:
	var result := {"state":g.state,"recipes":g.orb_drafts,"gold":g.economy.gold}
	for name in ["ForgeMerge","ForgeMaterial","ForgePreview","Bag_fan","Socket_1_1"]:
		var c:Control=g.ui.modal.find_child(name,true,false)
		if c:
			var rect:=c.get_global_rect()
			result[name]={"x":rect.get_center().x,"y":rect.get_center().y,"left":rect.position.x,"text":c.get("text") if c is Label or c is Button else ""}
	for child in g.ui.modal.get_children():
		if child is Button and child.text.begins_with("시험 발사"):
			var rect:Rect2=child.get_global_rect()
			result.trial={"x":rect.get_center().x,"y":rect.get_center().y}
	return result

func trial(g: Node2D) -> Dictionary:
	g.meter=Meter.new()
	g.start_trial()
	g.cast_target=Vector2(820,310)
	g.aim=Vector2.RIGHT
	g.orb_clocks=[0.0,0.0]
	var frames:Array=[]
	var cpu:Array=[]
	var peaks:Dictionary={"projectiles":0,"zones":0,"strikes":0,"echoes":0}
	var previous:=Time.get_ticks_usec()
	for frame in 180:
		var start:=Time.get_ticks_usec()
		g._rebuild_grid()
		g._tick_orbs(1.0/60)
		g._update_projectiles(1.0/60)
		g.magic.update_zones(1.0/60)
		g._update_effects(1.0/60)
		g.visuals.queue_redraw()
		g.ui.update_trial_stats()
		peaks.projectiles=maxi(peaks.projectiles,g.projectiles.size())
		peaks.zones=maxi(peaks.zones,g.magic.zones.size())
		peaks.strikes=maxi(peaks.strikes,g.magic.behavior.strikes.size())
		peaks.echoes=maxi(peaks.echoes,g.magic.echoes.size())
		var combat:float=(Time.get_ticks_usec()-start)/1000.0
		await g.get_tree().process_frame
		var now:=Time.get_ticks_usec()
		if frame>=30:
			frames.append((now-previous)/1000.0)
			cpu.append(combat)
		previous=now
		if frame==145:
			await RenderingServer.frame_post_draw
			g.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/spell-program-trial.png"))
	frames.sort()
	cpu.sort()
	var result:Dictionary={"recipe":g.orb_drafts.duplicate(true),"frames":frames.size(),"render_median_ms":frames[75],"render_p95_ms":frames[142],"combat_cpu_p95_ms":cpu[142],"peaks":peaks,"events":g.meter.totals.duplicate(),"note":"180 rendered frames at fixed 1/60 simulation with four trial targets. One representative program, not a full-combination performance guarantee."}
	var f:=FileAccess.open("res://artifacts/spell-program-window.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"))
	g.end_trial()
	return result
