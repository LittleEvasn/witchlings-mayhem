extends RefCounted
## Dedicated test session only. Does not write player saves. Root physics is paused afterward.
## editor_manage(game_eval): return await load("res://tools/survival_render_probe.gd").measure(get_tree().current_scene)
static func measure(g: Node2D, third := false) -> Dictionary:
 g.record_runs=false
 seed(20261028)
 g.rng.seed=20261028
 g.start_run("sigil")
 g.set_physics_process(false)
 g.director.enabled=false
 g.encounters.enabled=false
 g.sound_enabled=false
 g.invincible=100000
 g.recipe=["fan@3","giant@3","bolt@3","impact@3","thunder@3"]
 g.draft=g.recipe.duplicate()
 g.orb_recipes=[g.recipe.duplicate(),["satellite@3"]]
 g.orb_drafts=g.orb_recipes.duplicate(true)
 for i in 2: g.orb_compiled[i]=g.Spells.compile(g.orb_recipes[i]).stages
 if third:
  g.orb_recipes.append(["bloom@3","expire@3","vortex@3"])
  g.orb_drafts=g.orb_recipes.duplicate(true)
  g.orb_upgrades=[0,0,0]
  g.orb_compiled.append(g.Spells.compile(g.orb_recipes[2]).stages)
 g._reset_orb_clocks()
 for i in 300:
  var e: Node2D=g.Actor.new()
  g.actors.add_child(e)
  e.setup(g.art,1)
  e.position=g.player.position+Vector2((i%20-10)*56,(i/20-7)*48)
  e.hp=1000000
  e.max_hp=e.hp
  e.speed=0
  g.enemies.append(e)
 var cpu: Array=[]
 var frames: Array=[]
 var stamp: int=Time.get_ticks_usec()
 for tick in 240:
  var start: int=Time.get_ticks_usec()
  g._physics_process(1.0/60)
  cpu.append((Time.get_ticks_usec()-start)/1000.0)
  await g.get_tree().process_frame
  var now: int=Time.get_ticks_usec()
  if tick>30: frames.append((now-stamp)/1000.0)
  stamp=now
 cpu.sort()
 frames.sort()
 var report: Dictionary={"enemies":g.enemies.size(),"projectiles":g.projectiles.size(),"zones":g.magic.zones.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"cpu_mean_ms":cpu.reduce(func(a,b):return a+b)/cpu.size(),"cpu_p95_ms":cpu[int(cpu.size()*.95)],"rendered_frame_mean_ms":frames.reduce(func(a,b):return a+b)/frames.size(),"rendered_frame_p95_ms":frames[int(frames.size()*.95)]}
 var f:=FileAccess.open("res://artifacts/survival-render-profile.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 g.get_viewport().get_texture().get_image().save_png("res://artifacts/survival-horde.png")
 return report
