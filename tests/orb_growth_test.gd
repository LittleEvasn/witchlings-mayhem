extends SceneTree
const G=preload("res://scripts/orb_growth.gd")
const S=preload("res://scripts/spells.gd")
const Store=preload("res://scripts/run_checkpoint.gd")
const Profile=preload("res://scripts/player_profile.gd")
var checks:=0
var failures:=0
var states:=0
var g: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func pool_tree(value: Dictionary, seen: Dictionary) -> void:
	var key:=str([value.picks.get("socket",0),value.picks.get("cycle",0),value.picks.get("power",0),value.picks.get("size",0),value.picks.get("buffer",0)])
	if seen.has(key): return
	seen[key]=true
	states+=1
	check(G.valid(value),"Every legal core state is valid "+key)
	var pool:=G.eligible(value,[],1)
	check(pool.size()>=3 if value.rank<5 else pool.is_empty(),"Three distinct options remain until fifth choice "+key)
	if value.rank==5: return
	for id in pool:
		var next:=value.duplicate(true)
		next.picks[id]=G.amount(next,id)+1
		next.rank+=1
		pool_tree(next,seen)
func choose(id: String) -> bool:
	if not g.open_orb_growth(g.active_orb,g.economy.revision): return false
	# Test selection mechanics deterministically, not the RNG's choice of cards.
	var pool:=G.eligible(g.orb_growth[g.active_orb],S.compile(g.draft).stages,g.orb_recipes.size())
	if id not in pool: return false
	pool.erase(id)
	g.orb_growth[g.active_orb].offers=[id,pool[0],pool[1]]
	return g.choose_orb_growth(id,g.active_orb,g.orb_growth[g.active_orb].rank,g.economy.revision)
func run() -> void:
	root.size=Vector2i(1600,900)
	pool_tree(G.fresh(),{})
	for rank in 4:
		var old:=G.migrate(rank)
		check(G.valid(old) and old.rank==rank,"Legacy investment counted without free extra ranks")
		check(is_equal_approx(G.cycle(old),1.0/(1.0+.1*rank)),"Legacy speed preserved")
	g=load("res://scenes/main.tscn").instantiate()
	g.record_runs=false
	g.profile=Profile.new("user://orb-growth-test-profile.json")
	g.checkpoint_store=Store.new("user://orb-growth-test.json")
	root.add_child(g)
	await process_frame
	g.set_physics_process(false)
	g.sound_enabled=false
	g.start_run("sigil")
	check(g.orb_recipes.size()==1 and g.recipe.size()==6,"New run owns exactly one six-slot orb")
	g.complete_wave()
	g.economy.gold=5000
	var before: int=g.economy.gold
	check(g.extra_orb_unlocked() and g.extra_orb_cost()==100,"First rest unlocks second orb")
	check(g.workshop_buy("orb",g.economy.revision),"Buy second orb")
	check(g.economy.gold==before-100 and not g.extra_orb_unlocked(),"Cannot buy next rest's orb early")
	g.wave=2
	check(g.workshop_buy("orb",g.economy.revision),"Second rest buys third orb")
	g.wave=3
	check(g.workshop_buy("orb",g.economy.revision),"Third rest buys fourth orb")
	check(g.orb_recipes.size()==4 and not g.workshop_buy("orb",g.economy.revision),"Four-orb hard maximum")
	g.select_orb(0)
	check(choose("socket") and choose("socket"),"Two extra sockets selectable")
	check(g.orb_capacity(0)==8 and g.draft.size()==8 and g.orb_recipes[0].size()==8,"Capacity and real applied/draft arrays become eight")
	check(g.orb_drafts[1].size()==6 and g.orb_growth[1].rank==0,"Only selected orb grows")
	var token: String=g.draft[0]
	check(g.board_drop(g.board_data(token,0,0),0,7),"Slot eight accepts real drag plan")
	check(g.draft[0]=="" and g.draft[7]==token,"Exact free position retained at slot eight")
	g.undo_draft()
	check(g.draft.size()==8 and g.draft[0]==token,"Undo never shrinks capacity")
	check(not g.board_drop(g.board_data(token,0,0),1,7),"Ungrown six-slot orb rejects slot eight")
	check(g.board_drop(g.board_data(token,0,0),0,7),"Edit before a later socket-aware save")
	g.undo_draft()
	check(choose("power") and choose("cycle") and choose("size"),"Five independent upgrade decisions")
	check(g.orb_growth[0].rank==5 and not g.open_orb_growth(0,g.economy.revision),"No sixth choice")
	var base: Dictionary=S.compile(["bolt","impact","bloom"]).stages[0]
	var decorated:=G.decorate(base,g.orb_growth[0])
	check(is_equal_approx(decorated._orb_power,1.12) and is_equal_approx(decorated.next._orb_power,1.12),"Root and child receive single profile")
	check(is_equal_approx(S.scale(decorated),S.scale(base)*1.1),"Size affects production scale")
	check(is_equal_approx(g.orb_delay(1,0),g.cast_delay(1)*.92) and is_equal_approx(g.orb_delay(1,1),g.cast_delay(1)),"Only owning orb cycle reduced")
	var features:=G.fresh()
	features.picks={"life":2,"speed":1,"sequence":1,"link":1}
	features.rank=5
	var profiled:=G.decorate(base,features)
	check(is_equal_approx(profiled.connector_power,.6) and is_equal_approx(profiled.next._orb_life,1.3),"Child potency and life use exact orb profile")
	check(G.eligible(G.fresh(),S.compile(["thunder"]).stages,1).find("speed")==-1 and G.eligible(G.fresh(),[],1).find("sequence")==-1,"Conditional choices require matching behavior")
	g.orb_growth[2]=features
	g.orb_upgrades[2]=5
	check(is_equal_approx(g.orb_delay(.12,2,true),g.cast_delay(.12)*.8),"Sequence upgrade affects only inter-root delay")
	g.state="trial"
	g.clear_magic()
	profiled["_orb"]=2
	g.emit_stage(profiled,g.player.position,Vector2.RIGHT,{},1.0)
	check(is_equal_approx(g.projectiles[0].speed,440*1.15) and is_equal_approx(g.projectiles[0].life,2.6*1.3),"Speed/life reach production projectile")
	var parent: Dictionary=g.projectiles[0]
	g.magic.trigger(parent,g.player.position)
	check(g.projectiles.size()==2 and is_equal_approx(g.projectiles[1].power,parent.power),"Connected child reuses snapshot without doubling orb power")
	g.clear_magic()
	g.orb_growth[2]=G.fresh()
	g.orb_upgrades[2]=0
	g.state="shop"
	g.select_orb(1)
	check(g.open_orb_growth(1,g.economy.revision),"Choice opens for selected orb")
	var saved_offers: Array=g.orb_growth[1].offers.duplicate()
	var gold: int=g.economy.gold
	g.orb_growth_open=-1
	check(g.open_orb_growth(1,g.economy.revision) and g.orb_growth[1].offers==saved_offers and g.economy.gold==gold,"Reopening retains cards without charge/reroll")
	check(not g.choose_orb_growth(saved_offers[0],0,0,g.economy.revision),"Stale other-orb action rejected")
	check(not g.choose_orb_growth(saved_offers[0],1,0,g.economy.revision-1),"Stale economic revision rejected")
	g.economy.gold=0
	check(not g.choose_orb_growth(saved_offers[0],1,0,g.economy.revision) and g.orb_growth[1].rank==0,"Insufficient funds do not consume cards/rank")
	g.economy.gold=gold
	check(choose("buffer"),"Buffer obtained")
	g.state="combat"
	g.invincible=0
	g.orb_clocks.fill(1.0)
	g.hurt_player(1)
	check(g.orb_clocks[1]==0 and g.orb_clocks[0]==1,"Only buffer orb resets on real hit")
	g.orb_clocks[1]=1.0
	g.invincible=0
	g.hurt_player(1)
	check(g.orb_clocks[1]==1.0,"Buffer eight-second cooldown")
	g.state="shop"
	g.wave=1
	g.wave_records=g.wave_records.slice(0,1)
	g.recipe=g.orb_recipes[g.active_orb].duplicate()
	g.draft=g.orb_drafts[g.active_orb].duplicate()
	check(g.open_orb_growth(1,g.economy.revision) and g.orb_growth[1].offers.size()==3,"Unselected next growth cards exist before save")
	var checkpoint:=Store.capture(g)
	check(Store.valid(checkpoint),"One-to-four orbs, eight slots and growth pass checkpoint validation")
	check(g.checkpoint_store.write(checkpoint),"Checkpoint mirror written")
	var loaded: Dictionary=g.checkpoint_store.load_data()
	check(not loaded.is_empty(),"JSON checkpoint roundtrip")
	Store.apply(g,loaded)
	check(g.orb_recipes.size()==4 and g.orb_growth[0].rank==5 and g.orb_drafts[0].size()==8,"Load restores four orbs and growth")
	check(g.orb_growth[1].offers==checkpoint.orb_growth[1].offers,"Pending choices persist across reload")
	var legacy:=checkpoint.duplicate(true)
	legacy.erase("orb_growth")
	legacy.orbs=[checkpoint.orbs[0].slice(0,6),checkpoint.orbs[1].slice(0,6)]
	legacy.drafts=legacy.orbs.duplicate(true)
	legacy.orb_upgrades=[3,1]
	legacy.active_orb=0
	legacy.history=[]
	legacy.waves[0].recipes=legacy.orbs.duplicate(true)
	check(Store.valid(legacy),"Existing two-orb speed-growth save remains accepted")
	Store.apply(g,legacy)
	check(g.orb_recipes.size()==2 and g.orb_growth[0].rank==3 and g.orb_capacity(0)==6,"Legacy orbs and paid ranks retained")
	check(is_equal_approx(g.orb_delay(.12,0,true),g.cast_delay(.12)/1.3),"Legacy sequential delay preserved, not only full cycle")
	check(g.economy.gold==legacy.economy.gold and g.economy.inventory==legacy.economy.inventory,"Legacy inventory and gold preserved")
	legacy.erase("run_rules")
	check(Store.valid(legacy),"Pre-survival six-slot save still accepted")
	legacy.orbs[0].append("")
	legacy.drafts[0].append("")
	check(not Store.valid(legacy),"Pre-survival format cannot bypass capacity")
	legacy.orbs[0].pop_back()
	legacy.drafts[0].pop_back()
	legacy.orb_growth="malformed"
	check(not Store.valid(legacy),"Legacy format rejects unchecked injected growth metadata")
	Store.apply(g,loaded)
	var corrupt:=checkpoint.duplicate(true)
	corrupt.orbs[1].append("")
	check(not Store.valid(corrupt),"Save cannot forge extra capacity")
	corrupt=checkpoint.duplicate(true)
	corrupt.orb_growth[0].rank=0
	check(not Store.valid(corrupt),"Save cannot forge growth rank")
	g.ui.craft_tab="workshop"
	g.ui.show_shop()
	check(g.ui.modal.find_child("BuyExtraOrb",true,false)!=null,"Workshop upgrade UI builds")
	g.select_orb(0)
	g.start_trial()
	check(g.state=="trial" and g.orb_trial.size()==4,"Trial runs all four orbs")
	g.clear_magic()
	g.cast_spell()
	check(not g.projectiles.is_empty(),"Upgraded real production cast emits")
	if not g.projectiles.is_empty(): check(g.projectiles[0].power>1.0,"Orb power reaches damage snapshot")
	var targets: Array=g.enemies.duplicate()
	check(g.AutoTargeting.target_for(targets,3)==targets[3],"Fourth orb selects fourth target")
	check(g.AutoTargeting.target_for(targets.slice(0,1),3)==targets[0],"Insufficient targets shared safely")
	g.end_trial()
	check(g.state=="shop","Trial returns to preparation")
	g.state="ended"
	g.result_win=true
	g.ui.show_results()
	check(g.ui.modal.find_child("ResultSlot0_7",true,false)!=null and g.ui.modal.find_child("ResultOrb3",true,false)!=null,"Results show fourth orb and eighth slot")
	for suffix in ["",".bak",".closed",".closed.bak"]:
		var path: String="user://orb-growth-test.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	g.queue_free()
	await process_frame
	print("RESULT: %d checks / %d failures; %d core states"%[checks,failures,states])
	quit(0 if failures==0 else 1)
