extends RefCounted
## Plans only empty-slot edits. Compare the compiled graph, not just syntax validity.
const S=preload("res://scripts/spells.gd")
static func node_at(result: Dictionary, slot: int) -> Dictionary:
	for node in result.nodes:
		if node.slot==slot: return node
	return {}
static func edge(node: Dictionary) -> int: return int(node.next.get("slot",-1))
static func safe(parts: Array, id: String, slot: int) -> bool:
	if slot<0 or slot>=parts.size() or parts[slot]!="" or not S.has_part(id): return false
	var next:=parts.duplicate()
	next[slot]=id
	var before:=S.compile(parts)
	var after:=S.compile(next)
	if not S.slot_diagnostic(after,slot).is_empty(): return false
	var kind: String=S.definition(id).kind
	var left: Dictionary={}
	var right: Dictionary={}
	if kind=="connector":
		for node in before.nodes:
			if node.slot<slot: left=node
			elif right.is_empty(): right=node
		if left.is_empty() or right.is_empty() or left.disabled or right.disabled or edge(left)>=0 or not right.root: return false
	if kind=="modifier" and S.affected_slots(next,slot).is_empty(): return false
	for node in before.nodes:
		var other:=node_at(after,node.slot)
		if other.is_empty() or other.source_id!=node.source_id or other.disabled!=node.disabled: return false
		var is_left: bool=kind=="connector" and node.slot==left.slot
		var is_right: bool=kind=="connector" and node.slot==right.slot
		if other.root!=(false if is_right else node.root): return false
		if edge(other)!=(int(right.slot) if is_left else edge(node)): return false
		if other.connector!=(S.Progression.base_id(id) if is_left else node.connector): return false
		var mods: Array=other.modifiers.filter(func(m):return not (kind=="modifier" and m.slot==slot))
		if mods!=node.modifiers: return false
	if kind=="attack":
		var attack:=node_at(after,slot)
		if attack.is_empty() or attack.disabled or not attack.root: return false
	return true

static func plan(bank: Array, applied: Array, id: String, preferred := 0) -> Dictionary:
	var none: Dictionary={"orb":-1,"slot":-1,"text":"안전한 빈자리가 없어 가방에 보관"}
	if not S.has_part(id): return none
	var kind: String=S.definition(id).kind
	var order: Array=[]
	if preferred>=0 and preferred<bank.size(): order.append(preferred)
	for i in bank.size():
		if i not in order: order.append(i)
	if kind=="attack":
		var empty: Array=order.filter(func(i):return not S.has_content(bank[i]))
		order=empty+order.filter(func(i):return S.has_content(bank[i]))
	for orb in order:
		var slots: Array=range(bank[orb].size())
		if kind=="attack" and S.has_content(bank[orb]): slots.reverse()
		for slot in slots:
			if safe(bank[orb],id,slot) and orb<applied.size() and safe(applied[orb],id,slot):
				return {"orb":orb,"slot":slot,"text":"오브 %d · %d번 칸에 장착"%[orb+1,slot+1]}
	return none
