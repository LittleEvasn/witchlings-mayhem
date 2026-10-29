extends Node2D
## One canvas pass; no per-hit Labels/Tweens and no gameplay RNG consumption.
const FONT=preload("res://assets/fonts/Jua-Regular.ttf")
const MAX_VISIBLE:=64
const PER_TARGET:=2
const MERGE_SECONDS:=0.12
const LIFE:=0.40
const FONT_SIZE:=20
var game: Node2D
var clock:=0.0
var serial:=0
var entries: Array=[]

static func number_text(value: float) -> String:
	return str(maxi(1,roundi(value))) # Presentation only; fractional damage remains exact.

func clear() -> void:
	entries.clear()
	clock=0
	serial=0
	queue_redraw()

func add_hit(enemy: Node2D, amount: float) -> void:
	if not game.profile.data.damage_numbers or amount<=0 or not is_finite(amount): return
	if not game.visible_world_rect().grow(80).has_point(enemy.position): return
	var key: int=enemy.get_instance_id()
	for i in range(entries.size()-1,-1,-1):
		var item: Dictionary=entries[i]
		if item.target==key and clock-item.started<MERGE_SECONDS:
			item.amount+=amount
			item.hits+=1
			refresh_text(item)
			queue_redraw()
			return
	var matching:=0
	for item in entries:
		if item.target==key: matching+=1
	if matching>=PER_TARGET:
		for i in entries.size():
			if entries[i].target==key:
				entries.remove_at(i)
				break
	if entries.size()>=MAX_VISIBLE: entries.pop_front()
	serial+=1
	var height: float=110 if enemy.boss else maxf(60,enemy.visual_height+8)
	var offset:=Vector2((serial%5-2)*7,-height-matching*12)
	var item: Dictionary={"target":key,"ref":weakref(enemy),"offset":offset,"amount":amount,"hits":1,"started":clock,"pos":enemy.position+offset}
	refresh_text(item)
	entries.append(item)
	queue_redraw()

func refresh_text(item: Dictionary) -> void:
	item["text"]=number_text(item.amount)
	item["width"]=FONT.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x

func advance(delta: float) -> void:
	clock+=delta
	for i in range(entries.size()-1,-1,-1):
		if clock-entries[i].started>=LIFE: entries.remove_at(i)
		elif clock-entries[i].started<.10:
			var enemy: Node2D=entries[i].ref.get_ref()
			if is_instance_valid(enemy): entries[i].pos=enemy.position+entries[i].offset
	queue_redraw()

func _process(delta: float) -> void:
	if entries.is_empty(): return
	if not game.profile.data.damage_numbers: clear();return
	if game.magic_active(): advance(delta)

func _draw() -> void:
	# Draw outlines together, then fills, using the existing game's font atlas.
	for outline in [true,false]:
		for item in entries:
			var age: float=clock-item.started
			var pop: float=1.0+.16*pow(maxf(0,1-age/.12),2)
			var alpha: float=clampf((LIFE-age)/.16,0,1)
			draw_set_transform(item.pos+Vector2(0,-20*(1-pow(1-age/LIFE,2))),0,Vector2.ONE*pop)
			var at:=Vector2(-item.width*.5,0)
			if outline: draw_string_outline(FONT,at,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE,4,Color(.08,.05,.15,alpha))
			else: draw_string(FONT,at,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE,Color(1,.97,.84,alpha))
	draw_set_transform(Vector2.ZERO)
