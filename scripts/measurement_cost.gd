extends RefCounted
## Price a specified loadout by actually replaying purchases and crafting, not rank estimates.
const Economy = preload("res://scripts/economy.gd")
const Progression = preload("res://scripts/spell_progression.gd")
var economy: RefCounted
var reserved := {}
var ledger: Array = []
var route := "merge"

func plan(bank: Array, kit := "sigil", selected_route := "merge") -> Dictionary:
	if selected_route not in ["merge","paid"]: return {"ok":false,"error":"Unknown investment route"}
	economy = Economy.new()
	economy.reset(kit)
	economy.gold = 1000000
	reserved.clear()
	ledger.clear()
	route = selected_route
	for row in bank:
		for token in row:
			if not acquire(token): return {"ok":false,"error":"Cannot acquire loadout token: "+str(token)}
			reserved[token] = int(reserved.get(token,0))+1
	return {"ok":true,"spent":1000000-economy.gold,"route":route,"ledger":ledger.duplicate(true),"inventory":economy.inventory.duplicate()}

func base_stock(id: String, needed: int) -> bool:
	while economy.inventory.get(id,0)-reserved.get(id,0)<needed:
		if not economy.can_stock(id): return false
		var price: int = Economy.PRICES[id]
		economy.offers = [{"id":"","sold":true},{"id":id,"price":price,"sold":false}]
		if not economy.buy(1,economy.revision): return false
		ledger.append({"action":"buy","token":id,"cost":price})
	return true

func craft(action: String, target: String, material := "") -> bool:
	var result: Dictionary = economy.craft(action,target,material,economy.revision)
	if not result.ok: return false
	ledger.append({"action":action,"target":target,"material":material,"output":result.output,"cost":result.cost})
	return true

func acquire(token: String) -> bool:
	if economy.inventory.get(token,0)>reserved.get(token,0): return true
	if Progression.is_fused(token):
		var parents: Array = Progression.FUSIONS[token].parents
		var a := Progression.key(parents[0],3)
		var b := Progression.key(parents[1],3)
		if not acquire(a): return false
		reserved[a] = int(reserved.get(a,0))+1
		if not acquire(b): return false
		reserved[a] -= 1
		return craft("fuse",a,b)
	var base := Progression.base_id(token)
	var level := Progression.rank(token)
	if not Economy.PRICES.has(base): return false
	if level==0: return base_stock(base,1)
	for step in level:
		if route=="paid":
			if step==0 and not base_stock(base,1): return false
			if not craft("upgrade",Progression.key(base,step)): return false
		else:
			if not base_stock(base,2 if step==0 else 1): return false
			if not craft("merge",Progression.key(base,step),base): return false
	return true
