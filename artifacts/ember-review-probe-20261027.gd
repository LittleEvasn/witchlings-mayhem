extends SceneTree
var g: Node2D
var rows: Array=[]
func _initialize() -> void: call_deferred("run")
func fresh() -> void:
	g.magic.clear()
	g.projectiles.clear()
	g.player.position=Vector2(2400,1800)
func walk() -> void:
	for i in 120:
		g.player.position.x+=2
		g.magic.behavior.update(1.0/120.0)
func cast(recipe: Array, orb := 0) -> void:
	var stage: Dictionary=g.Spells.compile(recipe).stages[0].duplicate(true)
	stage["_orb"]=orb
	g.magic.emit(stage,g.player.position,Vector2.RIGHT,{},1.0,1.0)
func positions() -> Array:
	var out: Array=[]
	for zone in g.magic.zones: out.append([zone.pos.x-g.player.position.x,zone.pos.y-g.player.position.y])
	return out
func run() -> void:
	g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene=g
	await process_frame
	g.record_runs=false
	g.sound_enabled=false
	g.start_run("sigil")
	g.set_physics_process(false)
	g.director.enabled=false
	fresh()
	cast(["ember_path"])
	rows.append({"case":"stationary","patches":g.magic.zones.size(),"positions":positions()})
	fresh()
	walk()
	cast(["ember_path"])
	rows.append({"case":"walk_one_second_240_units","patches":g.magic.zones.size(),"positions":positions(),"history":g.magic.behavior.path.size()})
	fresh()
	walk()
	cast(["fan","ember_path"])
	rows.append({"case":"fan_three_branches","patches":g.magic.zones.size(),"positions":positions()})
	fresh()
	walk()
	for i in 6: cast(["ember_path"],i%2)
	var owners: Dictionary={}
	for zone in g.magic.zones:
		var id: String=str(zone.owner_orb)
		owners[id]=owners.get(id,0)+1
	rows.append({"case":"six_four_patch_casts_both_orbs","requested":24,"remaining":g.magic.zones.size(),"owners":owners})
	var file:=FileAccess.open("res://artifacts/ember-review-probe-20261027.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	file.close()
	print(JSON.stringify(rows))
	quit()
