extends RefCounted
## Stable combat kinds stay 1/2/3; visual species are separate from those array indices.
const ATLAS=preload("res://assets/art/enemies/monsters-v1.png")
const IDS:=["jelly","bat","beetle","paper","ink","rabbit","cauldron","mushroom","book","candle","satchel","trolley"]
const DATA:={
	"jelly":{"name":"잎 젤리","kind":1,"size":94.0,"radius":20.0,"hp":25.0,"speed":90.0,"first":1,"cap":300},
	"bat":{"name":"먹물 박쥐","kind":1,"size":94.0,"radius":18.0,"hp":25.0,"speed":90.0,"first":1,"cap":60},
	"beetle":{"name":"갑주 딱정벌레","kind":3,"size":124.0,"radius":26.0,"hp":180.0,"speed":82.0,"first":1,"cap":8},
	"paper":{"name":"달리는 답안지","kind":1,"size":82.0,"radius":16.0,"hp":18.0,"speed":104.0,"first":1,"cap":100},
	"ink":{"name":"잉크단지","kind":1,"size":104.0,"radius":23.0,"hp":65.0,"speed":58.0,"first":2,"cap":8},
	"rabbit":{"name":"태엽 토끼","kind":1,"size":122.0,"radius":19.0,"hp":50.0,"speed":100.0,"first":2,"cap":6},
	"cauldron":{"name":"걸어다니는 가마솥","kind":3,"size":164.0,"radius":32.0,"hp":350.0,"speed":130.0,"first":1,"cap":1},
	"mushroom":{"name":"포자 방울버섯","kind":2,"size":112.0,"radius":22.0,"hp":55.0,"speed":62.0,"first":2,"cap":6},
	"book":{"name":"방패 마도서","kind":1,"size":118.0,"radius":24.0,"hp":100.0,"speed":60.0,"first":3,"cap":6},
	"candle":{"name":"뛰는 촛대","kind":1,"size":112.0,"radius":19.0,"hp":30.0,"speed":96.0,"first":3,"cap":4},
	"satchel":{"name":"마석 도둑 주머니","kind":1,"size":108.0,"radius":22.0,"hp":85.0,"speed":168.0,"first":1,"cap":1},
	"trolley":{"name":"보급 손수레","kind":1,"size":144.0,"radius":26.0,"hp":150.0,"speed":112.0,"first":4,"cap":1}
}
# Pools replace ordinary arrivals rather than adding a second spawn stream.
const POOLS:=[[["jelly",55],["paper",30],["bat",15]],[["jelly",40],["paper",30],["bat",10],["ink",10],["rabbit",10]],[["jelly",32],["bat",10],["paper",27],["ink",8],["rabbit",9],["book",9],["candle",5]],[["jelly",27],["bat",10],["paper",28],["ink",8],["rabbit",10],["book",10],["candle",7]],[["jelly",24],["bat",10],["paper",28],["ink",8],["rabbit",10],["book",12],["candle",8]]]
static func definition(id: String) -> Dictionary: return DATA.get(id,DATA.jelly)
static func default_id(kind: int, role: String, wave: int) -> String:
	if role=="sentinel": return "cauldron"
	if role=="carrier": return "trolley" if wave>=4 else "satchel"
	return "mushroom" if kind==2 else ("beetle" if kind==3 else "jelly")
static func pick(game: Node2D, kind: int, role: String) -> String:
	if role in ["carrier","sentinel"]: return default_id(kind,role,game.wave)
	if kind==3: return "beetle"
	if kind==2: return "mushroom"
	var pool: Array=POOLS[clampi(game.wave-1,0,4)]
	if role=="swarm": return "paper" if game.rng.randf()<.35 else "jelly"
	var roll: int=game.rng.randi_range(0,99)
	for entry in pool:
		roll-=int(entry[1])
		if roll<0: return entry[0]
	return "jelly"
static func apply(enemy: Node2D, id: String) -> void:
	var d:=definition(id)
	enemy.monster_id=id
	enemy.monster_name=d.name
	var texture:=AtlasTexture.new()
	texture.atlas=ATLAS
	var i:=IDS.find(id)
	texture.region=Rect2((i%4)*256,(i/4)*256,256,256)
	enemy.sprite.texture=texture
	enemy.art_scale=float(d.size)/256.0
	enemy.sprite.scale=Vector2.ONE*enemy.art_scale
	enemy.sprite.position.y=-float(d.size)*.5+float(d.size)/16.0
	enemy.base_sprite_y=enemy.sprite.position.y
	enemy.visual_height=float(d.size)*.875
	enemy.radius=d.radius
	enemy.visual_tint=Color.WHITE
	for child in enemy.get_children():
		if child is Label:
			child.text=("과팽창 가마솥 · 밀치기 저항" if id=="cauldron" else d.name)
			child.position=Vector2(-100,-enemy.visual_height-26)
			child.size=Vector2(200,26)
