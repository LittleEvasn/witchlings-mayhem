extends RefCounted
## Pure presentation. Missing licensed textures use the existing vector fallback.
const ROOT := "res://assets/vfx/cartoon_coffee/"
const SPECS := {"bullet":[3,9],"explosion":[8,64],"wind":[8,64],"moon":[4,16],"fire":[8,64],"star":[4,16],"impact":[4,16],"shockwave":[4,16]}
var textures := {}
var missing := {}
var draws := 0
func texture(key: String) -> Texture2D:
	if textures.has(key): return textures[key]
	if missing.has(key) or not SPECS.has(key): return null
	var path := ROOT+key+".png"
	if not ResourceLoader.exists(path):
		missing[key] = true
		return null
	textures[key] = load(path)
	return textures[key]

func draw(canvas: CanvasItem, key: String, pos: Vector2, diameter: float, age: float, color := Color.WHITE, duration := 0.0, angle := 0.0, foot_anchor := false) -> bool:
	var tex := texture(key)
	if tex==null: return false
	var spec: Array = SPECS[key]
	var grid: int = spec[0]
	var count: int = spec[1]
	var frame := clampi(int(age/maxf(duration,0.001)*(count-1)),0,count-1) if duration>0 else posmod(int(age*30),count)
	if key=="fire" or key=="wind": frame = 12+posmod(int(age*30),36)
	var side: float = tex.get_width()/float(grid)
	var source := Rect2((frame%grid)*side,floori(frame/float(grid))*side,side,side)
	canvas.draw_set_transform(pos,angle)
	var at := Vector2(-diameter*.5,-diameter*(.81 if foot_anchor else .5))
	canvas.draw_texture_rect_region(tex,Rect2(at,Vector2.ONE*diameter),source,color,false,true)
	canvas.draw_set_transform(Vector2.ZERO)
	draws += 1
	return true
