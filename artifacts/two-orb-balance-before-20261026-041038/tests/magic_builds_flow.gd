extends SceneTree
## Automated controls: measures run flow and first-wave viability, not player enjoyment.
var reports: Array = []
var g: Node2D
var failures := 0
func _initialize() -> void: call_deferred("run")
func setup(kit: String, seed_value: int, flow: bool) -> void:
 g.start_run(kit)
 g.set_physics_process(false)
 g.sound_enabled = false
 g.rng.seed = seed_value
 if flow:
  g.hp = 100000
  g.max_hp = 100000
func simulate_wave(kit: String, flow: bool) -> Dictionary:
 var casts: float = g.Spells.interval(g.compiled)/g.fire_rate
 var elapsed := 0.0
 var peak := 0
 var before_hp: float = g.hp
 var stages: Array = g.compiled
 var number: int = g.wave
 for i in int(g.Waves.config(number).duration*60):
  var dt := 1.0/60
  elapsed += dt
  g.elapsed += dt
  g.wave_time += dt
  g.invincible = maxf(0,g.invincible-dt)
  # Same speed-limited circular pilot for all kits. No invulnerability in viability runs.
  var destination := Vector2(720,430)+Vector2(cos(elapsed*0.55)*310,sin(elapsed*0.55)*170)
  g.player.position = g.player.position.move_toward(destination,240*dt)
  g._rebuild_grid()
  g._update_enemies(dt)
  if g.state!="combat": break
  g._rebuild_grid()
  casts -= dt
  if casts<=0:
   var enemy: Node2D = g.nearest_enemy(g.player.position,1600)
   if enemy!=null:
    g.aim = g.player.position.direction_to(enemy.position)
    g.cast_target = enemy.position
   else:
    g.aim = Vector2.RIGHT
    g.cast_target = g.player.position+Vector2(270,0)
   g.emit_stage(stages[0],g.player.position+g.aim*22,g.aim,stages[1] if stages.size()>1 else {},1)
   casts = g.Spells.interval(stages)/g.fire_rate
  g._update_projectiles(dt)
  if g.state!="combat": break
  g.magic.update_zones(dt)
  if g.state!="combat": break
  g._update_hostile_shots(dt)
  if g.state!="combat": break
  g._update_gems(dt)
  g._update_effects(dt)
  g.director.update()
  g._remove_dead()
  peak = maxi(peak,g.enemies.size())
 var incoming: float = before_hp-g.hp
 if g.state=="combat":
  if number<5: g.complete_wave()
  else: g.end_run(false)
 return {"kit":kit,"wave":number,"seconds":elapsed,"state":g.state,"won":g.result_win,"health":g.hp,"damage_taken":incoming,"kills":g.wave_kills,"gold":g.economy.gold,"peak_enemies":peak,"flow_only_high_health":flow,"recipe":g.recipe.duplicate()}
func run() -> void:
 g = load("res://scenes/main.tscn").instantiate()
 root.add_child(g)
 current_scene = g
 for kit in g.Economy.KITS:
  for seed_value in [731,732,733]:
   setup(kit,seed_value,false)
   var r := simulate_wave(kit,false)
   r["seed"] = seed_value
   reports.append(r)
   await process_frame
  setup(kit,731,true)
  for wave in 5:
   var r := simulate_wave(kit,true)
   reports.append(r)
   if not g.projectiles.is_empty() or not g.magic.zones.is_empty() or not g.magic.behavior.strikes.is_empty() or not g.hostile_shots.is_empty(): failures += 1
   if wave==4:
    if g.state!="ended": failures += 1
    break
   if g.state!="reward":
    failures += 1
    break
   g.choose_reward("haste")
   if g.state!="shop": failures += 1
   # Buy a legal supplementary component via the real research slot and ownership checks.
   var candidates: Array = ["giant","echo","pierce","seek"]
   if kit=="frost": candidates = ["thunder","giant","echo"]
   for id in candidates:
    if g.economy.inventory.get(id,0)>0: continue
    if g.economy.select_research(id,g.economy.revision) and g.buy_orb(0,g.economy.revision):
     var proposed: Array = [id]+g.recipe
     if id=="thunder": proposed = ["frost","impact","shatter","thunder"]
     if g.Spells.compile(proposed).ok and g.economy.owns_recipe(proposed): g.draft = proposed
     break
   g.launch_next_wave()
   if g.wave!=wave+2 or g.state!="combat": failures += 1
   await process_frame
 var file := FileAccess.open("res://artifacts/magic-builds-wave-flow.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"note":"Same deterministic circle pilot, nearest-target simulated mouse aim, no dash. Only first-wave runs use normal health; full-run tests explicitly use high health to check state transitions, not difficulty.","failures":failures,"runs":reports},"\t"))
 g.queue_free()
 await process_frame
 print("RESULT: %d wave records, %d flow failures" % [reports.size(),failures])
 quit(1 if failures else 0)

