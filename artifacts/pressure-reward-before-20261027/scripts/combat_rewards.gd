extends RefCounted
## Personal, deferred spell choices. No world pause, enemy faction, or repeatable reroll.
const FIRST_SECONDS := 30.0
const MIN_KILLS := 12
const ALLOCATION := 18
var game: Node2D
var pending: Array = []
var issued: Dictionary = {}
var revision := 0
var run_serial := 0
var rng := RandomNumberGenerator.new()

func _init(owner_game: Node2D) -> void: game=owner_game

func reset(seed_value: int) -> void:
	pending.clear()
	issued.clear()
	run_serial+=1
	revision+=1
	rng.seed=seed_value

func reserved(number: int) -> int:
	return ALLOCATION if number>=1 and number<=4 else 0

func candidates() -> Array:
	var pool: Array=[]
	for id in game.Economy.PRICES:
		if game.economy.can_stock(id): pool.append(id)
	return pool

func fill_options(existing: Array) -> Array:
	var pool := candidates()
	var options: Array=[]
	for id in existing:
		if id in pool and not id in options: options.append(id)
	for id in options: pool.erase(id)
	while options.size()<3 and not pool.is_empty():
		var index := rng.randi_range(0,pool.size()-1)
		options.append(pool[index])
		pool.remove_at(index)
	return options

func tick() -> void:
	if game.state!="combat" or game.wave>4 or issued.has(game.wave): return
	if game.wave_time<FIRST_SECONDS or game.wave_kills<MIN_KILLS: return
	issued[game.wave]=true
	pending.append({"id":"%d:%d"%[run_serial,game.wave],"wave":game.wave,"options":fill_options([])})
	revision+=1
	game.announce("마법 재료를 확보했어!  ‘마법 선택’에서 하나를 골라봐.",4)
	if game.personal_tab=="reward": game.ui.show_personal.call_deferred()

func refresh_options() -> void:
	if pending.is_empty(): return
	var first: Dictionary=pending[0]
	var valid: Array=first.options.filter(func(id):return game.economy.can_stock(id))
	var next:=fill_options(valid)
	if next==first.options: return
	first.options=next
	revision+=1

func choose(reward_id: String, id: String, expected_revision: int) -> bool:
	if not game.state in ["combat","shop"] or pending.is_empty() or expected_revision!=revision: return false
	var first: Dictionary=pending[0]
	if reward_id!=first.id: return false
	if id=="":
		if not candidates().is_empty(): return false
		# Full stock fallback uses this reward's reserved budget, not an extra payout.
		game.economy.grant(ALLOCATION)
	else:
		if not id in first.options or not game.economy.can_stock(id):
			refresh_options()
			return false
		game.economy.inventory[id]=int(game.economy.inventory.get(id,0))+1
	game.economy.revision+=1
	pending.pop_front()
	revision+=1
	return true
