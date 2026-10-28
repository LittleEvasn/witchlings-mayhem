extends RefCounted
## Reward selection/editing freezes simulation; ordinary inventory does not.
const ALLOCATION := 0
const OWNED_WEIGHT := 3.0
const GOLD_REWARD := 10
const HEAL_REWARD := 20.0
const XP_PER_STONE := 2
var game: Node2D
var pending: Array = []
var issued: Dictionary = {}
var revision := 0
var run_serial := 0
var rng := RandomNumberGenerator.new()
var level := 1
var xp := 0
var total_xp := 0
var serial := 0
var stage := ""
var receipt := ""
func _init(owner_game: Node2D) -> void: game=owner_game
func reset(seed_value: int) -> void:
	pending.clear()
	issued.clear()
	run_serial+=1
	revision+=1
	rng.seed=seed_value
	level=1
	xp=0
	total_xp=0
	serial=0
	stage=""
	receipt=""
func required() -> int: return 6+(level-1)*3
func paused() -> bool: return not stage.is_empty()
func reserved(_number: int) -> int: return 0
func gain_xp(amount: int) -> void:
	if amount<=0 or game.state!="combat": return
	xp+=amount
	total_xp+=amount
	while xp>=required():
		xp-=required()
		level+=1
		serial+=1
		pending.append({"id":"xp:%d:%d"%[run_serial,serial],"level":level,"source":"level","options":[]})
	revision+=1
func candidates() -> Array:
	var pool: Array=[]
	for id in game.Economy.PRICES:
		if game.economy.can_stock(id): pool.append(id)
	for id in game.Relics.DEFINITIONS:
		if not game.relics.has(id): pool.append("relic:"+id)
	return pool
func weight(id: String) -> float:
	return OWNED_WEIGHT if not id.begins_with("relic:") and not game.economy.owned_token(id).is_empty() else 1.0
func fill_options(existing: Array) -> Array:
	var pool := candidates()
	var options: Array=[]
	for id in existing:
		if id in pool and not id in options: options.append(id)
	for id in options: pool.erase(id)
	while options.size()<3 and not pool.is_empty():
		var total := 0.0
		for id in pool: total+=weight(id)
		var roll := rng.randf()*total
		var index := pool.size()-1
		for i in pool.size():
			roll-=weight(pool[i])
			if roll<0:
				index=i
				break
		options.append(pool.pop_at(index))
	for fallback in ["gold","heal"]:
		if options.size()<3: options.append(fallback)
	return options
func tick() -> void:
	if game.state!="combat" or paused() or pending.is_empty(): return
	stage="choice"
	game.close_personal()
	refresh_options()
	game.ui.show_level_reward.call_deferred()
	game.play_sound("reward")
func finish_wave() -> void: pass
func issue(_number: int, _source := "carrier") -> bool:
	# Field rewards now grant growth, not an independent free spell choice.
	gain_xp(6)
	tick()
	return true
func refresh_options() -> void:
	if pending.is_empty(): return
	var first: Dictionary=pending[0]
	var next:=fill_options(first.options)
	if next==first.options: return
	first.options=next
	revision+=1
func choose(reward_id: String, id: String, expected_revision: int) -> bool:
	if game.state!="combat" or stage!="choice" or pending.is_empty() or expected_revision!=revision: return false
	var first: Dictionary=pending[0]
	if reward_id!=first.id or not id in first.options: return false
	if id=="gold":
		game.economy.grant(GOLD_REWARD)
		receipt="마석 %d 획득"%GOLD_REWARD
	elif id=="heal":
		if game.hp>=game.max_hp:
			game.economy.grant(GOLD_REWARD)
			receipt="체력이 가득 차 마석 %d 획득"%GOLD_REWARD
		else:
			game.hp=minf(game.max_hp,game.hp+HEAL_REWARD)
			receipt="체력 회복"
	elif id.begins_with("relic:"):
		var relic_id:=id.trim_prefix("relic:")
		if not game.acquire_relic(relic_id): return false
		receipt=game.Relics.definition(relic_id).name+" 획득"
	else:
		var acquired: Dictionary=game.economy.acquire(id)
		if not acquired.ok:
			refresh_options()
			return false
		game.apply_acquisition(acquired)
		receipt=game.Spells.definition(acquired.output).name+(" 강화!" if acquired.upgraded else " 획득!")
	pending.pop_front()
	revision+=1
	stage="ready"
	game.discover_owned()
	return true
func edit() -> void:
	if stage!="ready": return
	stage="edit"
	game.ui.close_modal()
	game.open_personal("inventory")
func continue_combat() -> void:
	if stage!="ready": return
	stage=""
	game.ui.close_modal()
	game.invincible=maxf(game.invincible,.5)
	tick()
func snapshot() -> Dictionary:
	return {"level":level,"xp":xp,"total_xp":total_xp,"serial":serial}
func restore(data: Dictionary) -> void:
	level=int(data.get("level",1))
	xp=int(data.get("xp",0))
	total_xp=int(data.get("total_xp",0))
	serial=int(data.get("serial",0))
	stage=""
	receipt=""
