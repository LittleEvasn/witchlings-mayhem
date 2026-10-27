extends RefCounted
## Optional observer. Only the measurement room attaches one to the game.
var time := 0.0
var totals: Dictionary = {}
var sources: Dictionary = {}
var victims: Dictionary = {}
var kill_times: Array = []
var timeline: Array = []
var next_sample := 1.0

func count(event: String, source := "", value := 1.0) -> void:
	totals[event] = float(totals.get(event,0.0))+value
	if source.is_empty(): return
	if not sources.has(source): sources[source] = {}
	var row: Dictionary = sources[source]
	row[event] = float(row.get(event,0.0))+value

func damage(source: String, amount: float, health: float, target_id: int) -> void:
	var effective := minf(amount,maxf(0,health))
	count("damage_raw",source,amount)
	count("damage_effective",source,effective)
	count("damage_overkill",source,amount-effective)
	count("damage_events",source)
	victims[target_id] = true
	if amount >= health:
		count("kills",source)
		kill_times.append(time)

func sample(game: Node2D, delta: float) -> void:
	var living := 0
	for e in game.enemies:
		if not e.dead: living += 1
	count("living_enemy_seconds","",living*delta)
	for pair in [["peak_enemies",living],["peak_projectiles",game.projectiles.size()],["peak_zones",game.magic.zones.size()],["peak_strikes",game.magic.behavior.strikes.size()],["peak_orbits",game.magic.behavior.orbits.size()]]:
		totals[pair[0]] = maxf(float(totals.get(pair[0],0)),float(pair[1]))
	if time >= next_sample:
		timeline.append({"seconds":snappedf(time,0.01),"damage":totals.get("damage_effective",0),"kills":totals.get("kills",0),"alive":living,"projectiles":game.projectiles.size(),"zones":game.magic.zones.size()})
		next_sample += 1.0

func result() -> Dictionary:
	var fired: float = totals.get("projectiles_emitted",0)
	return {"seconds":time,"totals":totals.duplicate(true),"sources":sources.duplicate(true),"unique_victims":victims.size(),
		"kill_times":kill_times.duplicate(),"timeline":timeline.duplicate(true),
		"effective_dps":float(totals.get("damage_effective",0))/maxf(time,0.001),
		"contact_rate":float(totals.get("projectiles_contacted",0))/fired if fired>0 else 0.0,
		"mean_alive":float(totals.get("living_enemy_seconds",0))/maxf(time,0.001)}
