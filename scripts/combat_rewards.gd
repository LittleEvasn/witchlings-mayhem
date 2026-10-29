extends RefCounted
## One paused reward/editor session, released only by the explicit resume action.
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
var view: Dictionary={}
var bag_only:=false
var last_chest_results: Array=[]
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
	view.clear()
	bag_only=false
	last_chest_results.clear()
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
func candidates(chest := false) -> Array:
	var pool: Array=[]
	for id in game.Economy.PRICES:
		if game.economy.can_stock(id) and (not chest or not game.economy.owned_token(id).is_empty()): pool.append(id)
	if chest:
		for id in game.Spells.Progression.FUSIONS:
			if game.economy.fusion_quote(id).ok: pool.append("fuse:"+id)
	else:
		for id in game.Relics.DEFINITIONS:
			if not game.relics.has(id): pool.append("relic:"+id)
	return pool
func weight(id: String) -> float:
	return OWNED_WEIGHT if not id.begins_with("relic:") and not game.economy.owned_token(id).is_empty() else 1.0
func fill_options(existing: Array, chest := false) -> Array:
	var pool := candidates(chest)
	var options: Array=[]
	for id in existing:
		if id in pool and not id in options: options.append(id)
	for id in options: pool.erase(id)
	if chest and not options.any(func(id):return id.begins_with("fuse:")):
		var fusions: Array=pool.filter(func(id):return id.begins_with("fuse:"))
		if not fusions.is_empty():
			if options.size()==3: options.pop_back()
			var fusion: String=fusions[rng.randi_range(0,fusions.size()-1)]
			options.push_front(fusion)
			pool.erase(fusion)
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
	var chest: bool=pending[0].get("source","")=="chest"
	stage=("opening" if game.profile.data.quick_rewards else "chest") if chest else "choice"
	bag_only=false
	game.close_personal()
	game.personal_tab="inventory"
	if not chest: refresh_options()
	if chest and game.profile.data.quick_rewards: reveal_chest.call_deferred(str(pending[0].id))
	else: game.ui.show_level_reward.call_deferred()
	game.play_sound("reward")
func open_chest() -> bool:
	if game.state!="combat" or stage!="chest" or pending.is_empty(): return false
	stage="opening"
	game.ui.show_level_reward.call_deferred()
	return true
func reveal_chest(reward_id: String) -> void:
	if game.state!="combat" or stage!="opening" or pending.is_empty() or pending[0].id!=reward_id: return
	stage="granting" # Repeated animation callbacks cannot claim this chest again.
	pending.pop_front()
	last_chest_results.clear()
	var count:=draw_chest_count()
	for i in count:
		# Recompute after every upgrade/fusion. Consumed parents and maxed spells leave the pool.
		var pool:=candidates(true)
		var fusions: Array=pool.filter(func(id):return str(id).begins_with("fuse:"))
		var id: String="gold"
		if not fusions.is_empty(): id=fusions[rng.randi_range(0,fusions.size()-1)]
		elif not pool.is_empty(): id=pool[rng.randi_range(0,pool.size()-1)]
		if not grant_reward(id,"chest"):
			grant_reward("gold","chest")
		last_chest_results.append({"id":id,"text":receipt,"output":view.get("output",id)})
	revision+=1
	finish_award()

func draw_chest_count() -> int:
	# Initial local tuning (80/17/3), not a claim about VS's original probabilities.
	var roll:=rng.randi_range(0,99)
	return 1 if roll<80 else (3 if roll<97 else 5)
func finish_wave() -> void: pass
func issue(_number: int, _source := "carrier") -> bool:
	# Field rewards now grant growth, not an independent free spell choice.
	gain_xp(6)
	tick()
	return true

func queue_chest() -> void:
	serial+=1
	pending.append({"id":"chest:%d:%d"%[run_serial,serial],"level":level,"source":"chest","options":[]})
	revision+=1
func refresh_options() -> void:
	if pending.is_empty(): return
	var first: Dictionary=pending[0]
	if first.get("source","")=="chest": return
	var next:=fill_options(first.options.filter(func(id):return not str(id).begins_with("fuse:")))
	# One draw per displayed levelup, including a locked 'none'. Editing cannot reroll it.
	if not first.get("fusion_locked",false):
		first["fusion_locked"]=true
		var pool: Array=[]
		for id in game.Spells.Progression.FUSIONS:
			if game.economy.fusion_quote(id).ok: pool.append(id)
		first["fusion_option"]="" if pool.is_empty() else pool[rng.randi_range(0,pool.size()-1)]
	var fusion: String=first.get("fusion_option","")
	if not fusion.is_empty() and game.economy.fusion_quote(fusion).ok: next.append("fuse:"+fusion)
	if next==first.options: return
	first.options=next
	revision+=1
func choose(reward_id: String, id: String, expected_revision: int) -> bool:
	if game.state!="combat" or stage!="choice" or pending.is_empty() or expected_revision!=revision: return false
	var first: Dictionary=pending[0]
	if first.get("source","")=="chest": return false
	if reward_id!=first.id or not id in first.options: return false
	if not grant_reward(id,"level"): return false
	pending.pop_front()
	revision+=1
	last_chest_results.clear()
	finish_award()
	return true

func finish_award() -> void:
	game.discover_owned()
	game.ui.selected_item=view.get("output","") if game.Spells.has_part(view.get("output","")) else ""
	if not game.ui.selected_item.is_empty() and game.remaining_part(game.ui.selected_item)>0:
		var bag: Array=[]
		for id in game.economy.inventory:
			if game.remaining_part(id)>0: bag.append(id)
		game.ui.compact_bag_page=int(bag.find(game.ui.selected_item)/12)
	stage=""
	if not pending.is_empty(): tick()
	else:
		stage="edit"
		game.personal_tab="inventory"
		game.ui.show_level_reward.call_deferred()

func continue_combat() -> bool:
	if game.state!="combat" or stage!="edit" or not pending.is_empty() or not game.valid_draft(): return false
	game._commit_live_board()
	stage=""
	game.close_personal()
	game.ui.close_modal()
	game.invincible=maxf(game.invincible,.5)
	return true

func grant_reward(id: String, source: String) -> bool:
	view=game.AcquisitionView.model(game,id,source,bag_only)
	if id.begins_with("fuse:"):
		var fused:=id.trim_prefix("fuse:")
		if source not in ["chest","level"] or not game.claim_fusion(fused,bag_only): return false
		receipt=game.Spells.definition(fused).name+" 합성 완성!"
	elif id=="gold":
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
		game.apply_acquisition(acquired,bag_only)
		view.placement=acquired.placement
		receipt=game.Spells.definition(acquired.output).name+(" 강화!" if acquired.upgraded else " 획득!")
	return true
func snapshot() -> Dictionary:
	return {"level":level,"xp":xp,"total_xp":total_xp,"serial":serial}
func restore(data: Dictionary) -> void:
	level=int(data.get("level",1))
	xp=int(data.get("xp",0))
	total_xp=int(data.get("total_xp",0))
	serial=int(data.get("serial",0))
	stage=""
	receipt=""
