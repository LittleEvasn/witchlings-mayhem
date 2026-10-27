extends RefCounted
## Repeatable production-runtime visual fixtures and rendered frame-time probe.
static func prepare(g: Node2D, kind: String) -> void:
 g.start_run("garden" if kind=="garden" else "frost")
 g.set_physics_process(false)
 g.sound_enabled = false
 g.complete_wave()
 g.choose_reward("power")
 for id in g.Spells.PARTS: g.economy.inventory[id]=1
 g.draft = ["giant","graft","vortex"] if kind=="garden" else ["frost","impact","shatter","thunder"]
 g.start_trial()
 g.player.position = Vector2(570,330)
 var stages: Array = g.Spells.compile(g.draft).stages
 for i in 3:
  g.emit_stage(stages[0],g.player.position,Vector2.RIGHT,stages[1] if stages.size()>1 else {},1)
  if kind=="garden":
   g.projectiles.back().pos = Vector2(790,340)
   g.magic.install(g.projectiles.back())
   g.projectiles.clear()
 if kind=="frost":
  g.player.position=Vector2(600,300)
  for i in 3: g.emit_stage(stages[0],g.player.position,Vector2.RIGHT,stages[1],1)
 g.visuals.queue_redraw()
 g.ui.update_trial_stats()
static func performance(g: Node2D, crowded: bool) -> Dictionary:
 g.start_run("garden")
 g.set_physics_process(false)
 g.sound_enabled=false
 g.ui.close_modal()
 g.player.position=Vector2(720,430)
 g.hp=1000000
 g.recipe=["fan","echo","graft","vortex","impact","bloom"]
 g.compiled=g.Spells.compile(g.recipe).stages
 g.fire_rate=1.72
 g.ui.rebuild_recipe()
 for i in (90 if crowded else 10):
  var enemy: Node2D=g.Actor.new()
  g.actors.add_child(enemy)
  enemy.setup(g.art,1)
  enemy.position=Vector2(720,430)+Vector2.RIGHT.rotated(i*TAU/(90 if crowded else 10))*(150+(i%4)*32)
  enemy.hp=1000000
  enemy.max_hp=enemy.hp
  enemy.radius=16
  enemy.speed=35
  g.enemies.append(enemy)
 var frames: Array = []
 var cpu: Array = []
 var casts := 0.0
 var peak_projectiles := 0
 var peak_zones := 0
 var peak_draw_calls := 0
 var previous := Time.get_ticks_usec()
 for i in 420:
  await g.get_tree().process_frame
  var now := Time.get_ticks_usec()
  if i>=60: frames.append((now-previous)/1000.0)
  previous=now
  var begin := Time.get_ticks_usec()
  g.elapsed += 1.0/60
  g._rebuild_grid()
  g._update_enemies(1.0/60)
  g._rebuild_grid()
  casts -= 1.0/60
  if casts<=0:
   g.aim=Vector2.RIGHT.rotated(i*0.025)
   g.emit_stage(g.compiled[0],g.player.position+g.aim*22,g.aim,g.compiled[1],1)
   casts=g.Spells.interval(g.compiled)/g.fire_rate
  g._update_projectiles(1.0/60)
  g.magic.update_zones(1.0/60)
  g._update_effects(1.0/60)
  g.visuals.queue_redraw()
  if i>=60: cpu.append((Time.get_ticks_usec()-begin)/1000.0)
  peak_projectiles=maxi(peak_projectiles,g.projectiles.size())
  peak_zones=maxi(peak_zones,g.magic.zones.size())
  peak_draw_calls=maxi(peak_draw_calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
 frames.sort()
 cpu.sort()
 var report := {"crowded":crowded,"frames":frames.size(),"frame_ms_p50":frames[int(frames.size()*0.5)],"frame_ms_p95":frames[int(frames.size()*0.95)],"frame_ms_p99":frames[int(frames.size()*0.99)],"frame_ms_max":frames.back(),"simulation_ms_p95":cpu[int(cpu.size()*0.95)],"simulation_ms_p99":cpu[int(cpu.size()*0.99)],"peak_projectiles":peak_projectiles,"peak_zones":peak_zones,"enemies":g.enemies.size(),"draw_calls":peak_draw_calls,"note":"Rendered production runtime at fixed 60Hz simulation step; 60 warmup + 360 measured frames. 90 enemies is above ordinary wave caps. Frame time includes rendering and scheduler; CPU sample isolates gameplay update."}
 var file:=FileAccess.open("res://artifacts/magic-builds-performance-"+("crowded" if crowded else "baseline")+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t"))
 g.get_viewport().get_texture().get_image().save_png("res://artifacts/magic-builds-performance.png")
 return report
