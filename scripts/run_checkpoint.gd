extends RefCounted
## Preparation-only save. Two mirrors include a durable closed record when consumed.
const Spells=preload("res://scripts/spells.gd")
const P=preload("res://scripts/spell_progression.gd")
const Economy=preload("res://scripts/economy.gd")
const Relics=preload("res://scripts/relics.gd")
const Forge=preload("res://scripts/spell_forge.gd")
const Content=preload("res://scripts/run_content.gd")
const PATH="user://checkpoint-v1.json"
var path: String
var warning := ""

func _init(save_path := PATH) -> void: path=save_path

static func rng_data(random: RandomNumberGenerator) -> Dictionary:
	# JSON numbers are floats on parse; preserve every bit of the 64-bit state.
	return {"seed":str(random.seed),"state":str(random.state)}

static func restore_rng(random: RandomNumberGenerator, data: Dictionary) -> void:
	random.seed=int(data.seed)
	random.state=int(data.state)

static func capture(g: Node2D) -> Dictionary:
	g._sync_orb()
	var relics: Dictionary=g.relics.snapshot()
	relics.rng_state=str(g.relics.rng.state)
	var issued: Dictionary={}
	for key in g.combat_rewards.issued: issued[str(key)]=true
	var inventory: Dictionary={}
	for id in g.economy.inventory: inventory[str(id)]=g.economy.inventory[id]
	var ui_state: Dictionary={}
	for key in ["selected_item","craft_tab","bag_filter","bag_scroll","board_panel","fusion_choice","merge_material","inspected_orb","inspected_slot"]: ui_state[key]=g.ui.get(key)
	return {"run_id":g.run_id,"kit":g.selected_kit,"wave":g.wave,"wave_time":g.wave_time,"elapsed":g.elapsed,"prep_elapsed":g.prep_elapsed,
		"hp":g.hp,"max_hp":g.max_hp,"power":g.power,"fire_rate":g.fire_rate,"kills":g.kills,"wave_kills":g.wave_kills,
		"position":[g.player.position.x,g.player.position.y],"aim":[g.aim.x,g.aim.y],"last_move":[g.last_move.x,g.last_move.y],
		"dash_direction":[g.dash_direction.x,g.dash_direction.y],"dash_left":g.dash_left,"dash_cooldown":g.dash_cooldown,"invincible":g.invincible,
		"run_rules":"survival-30-v1","orb_upgrades":g.orb_upgrades.duplicate(),"workshop_relics":g.workshop_relics.duplicate(),
		"orbs":g.orb_recipes.duplicate(true),"drafts":g.orb_drafts.duplicate(true),"active_orb":g.active_orb,"history":g.edit_history.duplicate(true),
		"economy":{"gold":g.economy.gold,"earned":g.economy.total_earned,"inventory":inventory,"offers":g.economy.offers.duplicate(true),"research_sold":g.economy.research_sold},
		"relics":relics,"rng":rng_data(g.rng),"relic_rng":rng_data(g.relics.rng),"reward_rng":rng_data(g.combat_rewards.rng),
		"rewards":{"pending":g.combat_rewards.pending.duplicate(true),"issued":issued,"serial":g.combat_rewards.run_serial},
		"growth":g.combat_rewards.snapshot(),"fusion_history":g.economy.fusion_history.duplicate(),
		"waves":g.wave_records.duplicate(true),"metrics":g.metrics.duplicate(),"ui":ui_state}

static func number(value: Variant, low := 0.0, high := 1.0e9, integral := false) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value>=low and value<=high and (not integral or value==floor(value))

static func string_list(value: Variant, limit: int) -> bool:
	if not value is Array or value.size()>limit: return false
	for id in value:
		if not id is String: return false
	return true

static func token(id: Variant) -> bool:
	if not id is String: return false
	if P.FUSIONS.has(id): return true
	return P.base_id(id) in Spells.PARTS and id==P.key(P.base_id(id),P.rank(id)) and P.rank(id)>=0 and P.rank(id)<=3

static func bank(value: Variant, inventory: Dictionary) -> bool:
	if not value is Array or not value.size() in [2,3]: return false
	for parts in value:
		if not string_list(parts,6): return false
		for id in parts:
			if not token(id): return false
	# An incomplete, silent program is a legitimate editing state.
	return Forge.valid(value,inventory)

static func valid_rng(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["seed","state"]:
		var text: Variant=value.get(key)
		if not text is String or text.length()>20 or not text.is_valid_int() or str(int(text))!=text: return false
	return true

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if not data.get("run_id") is String or data.run_id.length()!=32 or not data.run_id.is_valid_hex_number(): return false
	if data.get("kit","") not in Economy.KITS or not number(data.get("wave"),1,4,true): return false
	for key in ["wave_time","elapsed","prep_elapsed","kills","wave_kills","dash_left","dash_cooldown","invincible"]:
		if not number(data.get(key)): return false
	for key in ["kills","wave_kills"]:
		if not number(data.get(key),0,1e9,true): return false
	for key in ["hp","max_hp","power","fire_rate"]:
		if not number(data.get(key),.001,1.0e6): return false
	if data.hp>data.max_hp: return false
	if not data.get("orbs") is Array or not number(data.get("active_orb"),0,data.orbs.size()-1,true): return false
	if not data.has("run_rules") and data.orbs.size()!=2: return false
	if data.has("run_rules"):
		if data.run_rules!="survival-30-v1" or not data.get("orb_upgrades") is Array or data.orb_upgrades.size()!=data.orbs.size(): return false
		for rank in data.orb_upgrades:
			if not number(rank,0,3,true): return false
		if not string_list(data.get("workshop_relics"),3): return false
		for id in data.workshop_relics:
			if id not in Relics.DEFINITIONS: return false
	for key in ["position","aim","last_move","dash_direction"]:
		if not data.get(key) is Array or data[key].size()!=2: return false
		for axis in data[key]:
			if not number(axis,-10000,10000): return false
	if not Rect2(0,0,4800,3600).has_point(Vector2(data.position[0],data.position[1])): return false
	var econ: Variant=data.get("economy")
	if not econ is Dictionary or not number(econ.get("gold"),0,1e9,true) or not number(econ.get("earned"),0,1e9,true): return false
	if not econ.get("inventory") is Dictionary or econ.inventory.size()>100: return false
	for id in econ.inventory:
		if not token(id) or not number(econ.inventory[id],1,100000,true): return false
	if not bank(data.get("orbs"),econ.inventory) or not bank(data.get("drafts"),econ.inventory) or data.orbs.size()!=data.drafts.size(): return false
	if not econ.get("research_sold") is bool or not econ.get("offers") is Array or not econ.offers.size() in [4,5]: return false
	for i in econ.offers.size():
		var offer: Variant=econ.offers[i]
		if not offer is Dictionary or not offer.get("id") is String or not offer.get("sold") is bool or not number(offer.get("price"),0,1000,true): return false
		if not offer.id.is_empty() and offer.id not in Economy.PRICES: return false
		if i==0 and offer.get("research")!=true: return false
		if i>0 and offer.get("research",false): return false
		for key in ["free","research"]:
			if offer.has(key) and not offer[key] is bool: return false
		if offer.has("base_price") and not number(offer.base_price,0,1000,true): return false
	if econ.offers[0].sold!=econ.research_sold: return false
	var relics: Variant=data.get("relics")
	if not relics is Dictionary or not string_list(relics.get("owned"),12): return false
	var seen: Array=[]
	for id in relics.owned:
		if id not in Relics.DEFINITIONS or id in seen: return false
		seen.append(id)
	for key in ["casts","gems","kills","shield","speed_left","speed_cooldown"]:
		if not number(relics.get(key)): return false
	for key in ["casts","gems","kills"]:
		if not number(relics.get(key),0,1e9,true): return false
	for key in ["rng","relic_rng","reward_rng"]:
		if not valid_rng(data.get(key)): return false
	if relics.get("rng_state")!=data.relic_rng.state: return false
	var rewards: Variant=data.get("rewards")
	if not rewards is Dictionary or not number(rewards.get("serial"),0,1e9,true) or not rewards.get("issued") is Dictionary: return false
	if not rewards.get("pending") is Array or rewards.pending.size()>512: return false
	for key in rewards.issued:
		if key not in ["1","2","3","4"] or rewards.issued[key]!=true: return false
	seen.clear()
	for item in rewards.pending:
		if data.has("growth"):
			if not item is Dictionary or not item.get("id") is String or item.id in seen or not number(item.get("level"),1 if item.get("source","")=="chest" else 2,100000,true): return false
			seen.append(item.id)
			if not string_list(item.get("options"),3): return false
			var unique_options: Array=[]
			for id in item.options:
				if id in unique_options: return false
				unique_options.append(id)
				if id not in Economy.PRICES and id not in ["gold","heal"] and not (id.begins_with("relic:") and id.trim_prefix("relic:") in Relics.DEFINITIONS) and not (item.get("source","")=="chest" and id.begins_with("fuse:") and id.trim_prefix("fuse:") in P.FUSIONS): return false
			continue
		if not item is Dictionary or not number(item.get("wave"),1,data.wave,true) or not item.get("id") is String or item.id in seen: return false
		seen.append(item.id)
		if not rewards.issued.has(str(int(item.wave))) or item.id!="%d:%d"%[int(rewards.serial),int(item.wave)]: return false
		if not string_list(item.get("options"),3): return false
		var options: Array=[]
		for id in item.options:
			if id not in Economy.PRICES or id in options: return false
			options.append(id)
	if data.has("growth"):
		var growth: Variant=data.growth
		if not growth is Dictionary: return false
		for key in ["level","xp","total_xp","serial"]:
			if not number(growth.get(key),1 if key=="level" else 0,1000000000,true): return false
		if growth.level>100000 or growth.xp>=6+(growth.level-1)*3: return false
		if not string_list(data.get("fusion_history",[]),18): return false
		for fusion in data.get("fusion_history",[]):
			if fusion not in P.FUSIONS: return false
	if not data.get("history") is Array or data.history.size()>30: return false
	for item in data.history:
		if not item is Dictionary or not bank(item.get("drafts"),econ.inventory) or not number(item.get("orb"),0,data.orbs.size()-1,true) or not number(item.get("group"),0,5,true): return false
	if not data.get("waves") is Array or data.waves.size()!=int(data.wave): return false
	for i in data.waves.size():
		var item: Variant=data.waves[i]
		if not item is Dictionary or item.get("wave")!=i+1 or not item.get("recipes") is Array or not item.recipes.size() in [2,3]: return false
		for key in ["seconds","kills","earned"]:
			if not number(item.get(key)): return false
		for parts in item.recipes:
			if not string_list(parts,6): return false
			for id in parts:
				if not token(id): return false
	if not data.get("metrics") is Dictionary: return false
	for key in ["casts","triggers","hits","peak_projectiles","peak_enemies"]:
		if not number(data.metrics.get(key)): return false
	return data.get("ui",{}) is Dictionary

func read_envelope(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var file:=FileAccess.open(file_path,FileAccess.READ)
	if file==null or file.get_length()>2_000_000: return {}
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK: return {}
	var value: Variant=parser.data
	if not value is Dictionary or value.get("version")!=1 or value.get("content")!=Content.VERSION: return {}
	if not number(value.get("sequence"),1,1e12,true) or not value.get("closed") is bool: return {}
	if not value.closed and not valid(value.get("data")): return {}
	return value

func latest() -> Dictionary:
	var primary:=read_envelope(path)
	var backup:=read_envelope(path+".bak")
	if not primary.is_empty() and (backup.is_empty() or primary.sequence>=backup.sequence): return primary
	if not backup.is_empty():
		warning="예비 저장 파일에서 제작 상태를 복구했어요."
		return backup
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"): warning="저장을 읽을 수 없거나 게임 규칙 버전이 달라 이어할 수 없어요. 원본 파일은 보존했어요."
	return {}

func load_data() -> Dictionary:
	var envelope:=latest()
	return {} if envelope.is_empty() or envelope.closed else envelope.data.duplicate(true)

func write(data: Dictionary, closed := false) -> bool:
	if not closed and not valid(data):
		warning="현재 제작 상태를 안전하게 저장할 수 없어요. 구체와 재고를 확인해 주세요."
		return false
	var previous:=latest()
	var envelope: Dictionary={"version":1,"content":Content.VERSION,"sequence":int(previous.get("sequence",0))+1,"closed":closed,"data":data if not closed else {}}
	for destination in [path+".bak",path]:
		if FileAccess.file_exists(destination) and read_envelope(destination).is_empty():
			var preserved: String=destination+".unreadable-"+str(Time.get_unix_time_from_system()).replace(".","-")
			if DirAccess.copy_absolute(destination,preserved)!=OK:
				warning="읽을 수 없는 저장의 원본을 보존하지 못했어요. 덮어쓰지 않고 중단했어요."
				return false
		var file:=FileAccess.open(destination+".tmp",FileAccess.WRITE)
		if file==null:
			warning="저장 파일을 쓰지 못했어요. 현재 화면을 유지하고 다시 시도해 주세요."
			return false
		file.store_string(JSON.stringify(envelope))
		file.flush()
		var error:=file.get_error()
		file.close()
		if error!=OK or DirAccess.rename_absolute(destination+".tmp",destination)!=OK:
			warning="저장 교체에 실패했어요. 현재 화면을 유지하고 다시 시도해 주세요."
			return false
	warning=""
	return true

func close() -> bool:
	var saved:=latest()
	if saved.is_empty() and not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"): return true
	var primary:=read_envelope(path)
	var backup:=read_envelope(path+".bak")
	if not primary.is_empty() and not backup.is_empty() and primary.closed and backup.closed and primary.sequence==backup.sequence: return true
	return write({},true)

static func apply(g: Node2D, data: Dictionary) -> void:
	for key in ["wave","kills","wave_kills"]: g.set(key,int(data[key]))
	for key in ["wave_time","elapsed","prep_elapsed","hp","max_hp","power","fire_rate","dash_left","dash_cooldown","invincible"]: g.set(key,float(data[key]))
	g.run_id=data.run_id
	g.active_orb=int(data.active_orb)
	g.orb_recipes=data.orbs.duplicate(true)
	g.orb_drafts=data.drafts.duplicate(true)
	g.orb_upgrades=data.get("orb_upgrades",[0,0]).duplicate()
	for i in g.orb_upgrades.size(): g.orb_upgrades[i]=int(g.orb_upgrades[i])
	g.workshop_relics=data.get("workshop_relics",[]).duplicate()
	g.final_boss_started=false
	g.clear_chests()
	# Old short-wave checkpoints resume at the matching six-minute preparation.
	if not data.has("run_rules"):
		g.elapsed=float(g.wave)*Content.REST_SECONDS
		g.wave_time=Content.REST_SECONDS
	g.orb_compiled=[]
	g.orb_trial=[]
	for _i in g.orb_recipes.size():
		g.orb_compiled.append([])
		g.orb_trial.append([])
	for i in g.orb_recipes.size():
		var compiled: Dictionary=Spells.compile(g.orb_recipes[i])
		g.orb_compiled[i]=compiled.stages if compiled.ok else []
	g.recipe=g.orb_recipes[g.active_orb].duplicate()
	g.draft=g.orb_drafts[g.active_orb].duplicate()
	g.compiled=g.orb_compiled[g.active_orb]
	g.edit_history=data.history.duplicate(true)
	for item in g.edit_history:
		item.orb=int(item.orb)
		item.group=int(item.group)
	g.economy.inventory.clear()
	for id in data.economy.inventory: g.economy.inventory[id]=int(data.economy.inventory[id])
	g.economy.gold=int(data.economy.gold)
	g.economy.total_earned=int(data.economy.earned)
	g.economy.offers=data.economy.offers.duplicate(true)
	for offer in g.economy.offers:
		offer.price=int(offer.price)
		if offer.has("base_price"): offer.base_price=int(offer.base_price)
	g.economy.research_sold=data.economy.research_sold
	g.economy.revision+=1
	var relics: Dictionary=data.relics.duplicate(true)
	relics.rng_state=int(relics.rng_state)
	g.relics.restore(relics)
	g.combat_rewards.pending=data.rewards.pending.duplicate(true)
	for item in g.combat_rewards.pending:
		if not data.has("growth"):
			item["level"]=2
			item["options"]=[]
	g.combat_rewards.issued.clear()
	for key in data.rewards.issued: g.combat_rewards.issued[int(key)]=true
	g.combat_rewards.run_serial=int(data.rewards.serial)
	g.combat_rewards.restore(data.get("growth",{}))
	g.economy.fusion_history=data.get("fusion_history",[]).duplicate()
	for token in g.economy.inventory:
		if P.is_fused(token) and not token in g.economy.fusion_history: g.economy.fusion_history.append(token)
	g.normalize_owned_spells()
	g.combat_rewards.revision+=1
	g.wave_records=data.waves.duplicate(true)
	for item in g.wave_records:
		for key in ["wave","kills","earned"]: item[key]=int(item[key])
	g.metrics.clear()
	for key in ["casts","triggers","hits","peak_projectiles","peak_enemies"]: g.metrics[key]=int(data.metrics[key])
	g.player.position=Vector2(data.position[0],data.position[1])
	g.aim=Vector2(data.aim[0],data.aim[1])
	g.last_move=Vector2(data.last_move[0],data.last_move[1])
	g.dash_direction=Vector2(data.dash_direction[0],data.dash_direction[1])
	g.set_arena_profile("scroll")
	g._sync_camera()
	g._reset_orb_clocks()
	g.director.clear()
	g.encounters.clear()
	g.reward_taken=true
	g.shop_time=g.SHOP_SECONDS
	g.state="shop"
	# Restore after all initialization that consumes randomness. No offers are rolled.
	restore_rng(g.rng,data.rng)
	restore_rng(g.relics.rng,data.relic_rng)
	restore_rng(g.combat_rewards.rng,data.reward_rng)
	var view: Dictionary=data.get("ui",{})
	g.ui.selected_item=str(view.get("selected_item","")) if token(view.get("selected_item","")) else ""
	g.ui.merge_material=""
	g.ui.inspected_orb=-1
	g.ui.inspected_slot=-1
	g.ui.craft_tab=view.get("craft_tab","bag") if view.get("craft_tab") in ["bag","craft","fusion","research","workshop"] else "bag"
	g.ui.bag_filter=view.get("bag_filter","all") if view.get("bag_filter") in ["all","attack","modifier","connector"] else "all"
	g.ui.bag_scroll=int(view.get("bag_scroll",0)) if number(view.get("bag_scroll",0),0,100000,true) else 0
	g.ui.board_panel="fusion" if g.ui.craft_tab=="fusion" else "item"
	g.ui.fusion_choice=view.get("fusion_choice","storm_spear") if view.get("fusion_choice") in P.FUSIONS else "storm_spear"
