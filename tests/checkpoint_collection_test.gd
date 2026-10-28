extends SceneTree
const Store=preload("res://scripts/run_checkpoint.gd")
const Profile=preload("res://scripts/player_profile.gd")
const Economy=preload("res://scripts/economy.gd")
const PREFIX="user://checkpoint-collection-test"
class BrokenStore:
	extends "res://scripts/run_checkpoint.gd"
	func write(_data: Dictionary, _closed := false) -> bool:
		warning="검사용 쓰기 실패"
		return false
	func close() -> bool:
		warning="검사용 쓰기 실패"
		return false
var checks:=0
var failures:=0
var g: Node2D
var h: Node2D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func clean_files() -> void:
	for name in ["-profile.json","-save.json","-incomplete.json","-legacy.json"]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(PREFIX+name+suffix): DirAccess.remove_absolute(PREFIX+name+suffix)
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("checkpoint-collection-test") and ".unreadable-" in file: DirAccess.remove_absolute("user://"+file)
func create_game() -> Node2D:
	var instance: Node2D=load("res://scenes/main.tscn").instantiate()
	instance.profile=Profile.new(PREFIX+"-profile.json")
	instance.checkpoint_store=Store.new(PREFIX+"-save.json")
	instance.record_runs=true
	root.add_child(instance)
	instance.set_physics_process(false)
	instance.sound_enabled=false
	return instance
func settle() -> void:
	for i in 4: await process_frame
func find(node: Node, key: String) -> Node:
	if str(node.name)==key: return node
	for child in node.get_children():
		var found:=find(child,key)
		if found!=null: return found
	return null
func press(key: String) -> void:
	find(h.ui.modal,key).pressed.emit()
func run() -> void:
	clean_files()
	root.size=Vector2i(1600,900)
	g=create_game()
	current_scene=g
	check(g.checkpoint_info().is_empty(),"Fresh install offers no empty resume")
	g.rng.seed=20261028
	g.start_run("sigil")
	check("bolt" in g.profile.data.discovered_spells and "fan" in g.profile.data.discovered_spells and "impact" in g.profile.data.discovered_spells,"Actual starting inventory is discovered")
	check("frost" not in g.profile.data.discovered_spells,"Other starting kits and previews do not unlock spells")
	check(not g.save_checkpoint() and g.checkpoint_info().is_empty(),"Combat cannot create preparation save")
	check(not g.resume_checkpoint() and g.state=="combat","Resume cannot interrupt a running battle")
	g.wave_time=60
	g.wave_kills=12
	g.kills=12
	g.complete_wave()
	check(g.state=="reward" and g.checkpoint_info().is_empty(),"Unchosen relic reward is outside save boundary")
	g.choose_reward(g.reward_options[0])
	g.economy.grant(500)
	g.economy.inventory.bolt=3
	g.economy.inventory.seek=1
	check(g.craft_spell("upgrade","bolt","",g.economy.revision),"Equipped spell can be manually upgraded before save")
	g.select_orb(1)
	g.board_quick_equip("seek")
	g.board_quick_equip("bolt")
	g.select_orb(0)
	g.select_research("bloom",g.economy.revision)
	check(g.buy_orb(0,g.economy.revision) and g.economy.research_sold,"Purchased research offer is saved as consumed")
	g.economy.inventory["bolt@3"]=1
	g.economy.inventory["bloom@3"]=1
	check(g.craft_spell("fuse","bolt@3","bloom@3",g.economy.revision)==false,"Unrelated +3 parents do not create a nonexistent recipe")
	g.economy.inventory["thunder@3"]=1
	check(g.craft_spell("fuse","bolt@3","thunder@3",g.economy.revision),"Completed fusion consumes actual +3 copies")
	check("storm_spear" in g.profile.data.discovered_fusions,"Actually crafting fusion discovers its own entry")
	g.acquire_relic("seal")
	g.acquire_relic("gloves")
	check(g.reroll_shop(g.economy.revision),"Reroll before save uses existing economy")
	check(g.economy.offers.filter(func(o):return o.get("free",false)).size()==1,"Saved offers include exactly one existing free offer")
	g.relics.cast_count=3
	g.relics.gem_remainder=7
	g.rng.seed=0x1234567891234567
	g.rng.randi()
	g.relics.rng.seed=0x6543210987654321
	g.combat_rewards.rng.seed=0x2345678912345678
	g.ui.craft_tab="bag"
	g.ui.selected_item="bolt@1"
	g.ui.show_shop()
	await settle()
	check(g.state=="shop" and not g.checkpoint_info().is_empty(),"Entering and editing preparation automatically saves")
	check(FileAccess.file_exists(g.checkpoint_store.path) and FileAccess.file_exists(g.checkpoint_store.path+".bak"),"Save has primary and mirrored recovery files")
	var expected: Dictionary=Store.capture(g)
	check(Store.valid(expected),"Complete preparation snapshot passes schema and stock validation")
	var future:=Economy.new()
	future.inventory=g.economy.inventory.duplicate()
	future.gold=g.economy.gold
	future.research_sold=g.economy.research_sold
	future.relics=g.relics
	var random:=RandomNumberGenerator.new()
	Store.restore_rng(random,expected.rng)
	var expected_next: int=random.randi()
	Store.restore_rng(random,expected.rng)
	future.reroll(random,g.recipe)
	var serial: int=g.combat_rewards.run_serial
	var pending: Array=g.combat_rewards.pending.duplicate(true)
	check(not pending.is_empty(),"Deferred spell reward exists at save boundary")
	g.record_runs=false
	h=create_game()
	current_scene=h
	await settle()
	check(find(h.ui.modal,"Continue")!=null,"New process title offers actual saved preparation")
	check(h.resume_checkpoint() and h.state=="shop","Resume restores preparation rather than advancing wave")
	check(h.run_id==expected.run_id and h.wave==1 and h.wave_time==60,"Run identity and completed wave retained")
	check(h.economy.inventory==expected.economy.inventory and h.economy.gold==expected.economy.gold and h.economy.total_earned==expected.economy.earned,"Ranked stock and currency restore without duplication or extra clear reward")
	check(h.orb_recipes==expected.orbs and h.orb_drafts==expected.drafts and h.active_orb==int(expected.active_orb),"Both six-slot orb programs and active selection restore")
	check(h.economy.offers==expected.economy.offers and h.economy.research_sold,"Offer identities, prices, free/sold flags restore without reroll")
	check(not h.buy_orb(0,h.economy.revision),"Consumed research cannot be repurchased after resume")
	check(h.relics.owned==expected.relics.owned and h.relics.cast_count==3 and h.relics.gem_remainder==7,"Relic ownership and partial proc counters restore")
	check(h.combat_rewards.pending==pending and h.combat_rewards.run_serial==serial and h.combat_rewards.issued.has(1),"Pending choices and issued-wave keys restore with integer lookup")
	check(not h.ui.spell_reward_button.disabled,"Resumed preparation actually enables pending-reward GUI button")
	check(h.rng.randi()==expected_next,"64-bit RNG resumes exact next number after JSON round trip")
	Store.restore_rng(h.rng,expected.rng)
	check(Store.rng_data(h.relics.rng)==expected.relic_rng and Store.rng_data(h.combat_rewards.rng)==expected.reward_rng,"Relic and reward RNG streams preserve independent state")
	check(h.reroll_shop(h.economy.revision) and h.economy.offers==future.offers and h.economy.gold==future.gold,"Next reroll matches uninterrupted run, including research and free offer rules")
	var reward: Dictionary=h.combat_rewards.pending[0]
	var chosen: String=reward.options[0]
	var stock: int=h.economy.inventory.get(chosen,0)
	check(h.claim_spell_reward(reward.id,chosen,h.combat_rewards.revision) and h.economy.inventory[chosen]==stock+1,"Deferred choice grants exactly one real copy after resume")
	check(not h.claim_spell_reward(reward.id,chosen,h.combat_rewards.revision) and h.economy.inventory[chosen]==stock+1,"Deferred choice cannot be claimed twice")
	var saved_offer: Array=h.economy.offers.duplicate(true)
	var saved_gold: int=h.economy.gold
	var saved_state: String=str(h.rng.state)
	h.dash_direction=Vector2.RIGHT
	h.dash_left=.12
	h.dash_cooldown=0
	h.invincible=.07
	check(h.start_trial(),"Trial can start from resumed preparation")
	h._physics_process(.2)
	h.try_dash(Vector2.LEFT)
	check(not h.save_checkpoint(),"Simulation cannot overwrite preparation with trial position, RNG or targets")
	h.end_trial()
	check(h.economy.gold==saved_gold and h.economy.offers==saved_offer and str(h.rng.state)==saved_state,"Trial return restores preparation economy and RNG")
	check(h.dash_direction==Vector2.RIGHT and h.dash_left==.12 and is_equal_approx(h.invincible,.07),"Trial dash direction and invulnerability cannot leak into saved preparation")
	h.save_and_title()
	check(h.state=="title" and find(h.ui.modal,"Continue")!=null,"Save and title retains resumable preparation")
	press("NewExperiment")
	press("StartExperiment")
	check(h.ui.front_screen=="replace","New run requires explicit saved-run replacement confirmation")
	press("CancelReplace")
	check(not h.checkpoint_info().is_empty() and h.ui.front_screen=="prepare","Cancel replacement preserves checkpoint")
	h.return_title()
	check(h.resume_checkpoint(),"Saved preparation can be re-entered without reroll")
	var normal: Dictionary=Store.capture(h)
	# The editor is allowed to save an incomplete, silent one-token program.
	var incomplete:=normal.duplicate(true)
	incomplete.orbs[0]=["impact"]
	incomplete.drafts[0]=["impact"]
	incomplete.history=[]
	check(Store.valid(incomplete),"Incomplete program with valid owned copies is saveable")
	var independent:=Store.new(PREFIX+"-incomplete.json")
	check(independent.write(incomplete),"Incomplete state can round-trip to disk")
	h.checkpoint_loading=true
	Store.apply(h,independent.load_data())
	h.checkpoint_loading=false
	check(h.orb_compiled[0].is_empty() and not h.valid_draft(),"Incomplete resumed program stays silent and Ready remains blocked")
	Store.apply(h,normal)
	for field in ["gold","inventory","orbs","rng"]:
		var bad:=normal.duplicate(true)
		match field:
			"gold": bad.economy.gold=-1
			"inventory": bad.economy.inventory["unknown_spell"]=1
			"orbs": bad.orbs=[["storm_spear","storm_spear"],[]]
			"rng": bad.rng.state=1234
		check(not Store.valid(bad),"Reject unsafe snapshot: "+field)
	check(h.save_checkpoint(),"Preparation can save after malformed-file validation probes")
	var store: RefCounted=h.checkpoint_store
	var bad_file:=FileAccess.open(store.path,FileAccess.WRITE)
	bad_file.store_string("broken");bad_file.close()
	check(not store.load_data().is_empty() and not store.warning.is_empty(),"Corrupt primary recovers identical mirrored preparation")
	check(h.save_checkpoint(),"Saving repairs missing primary mirror")
	check(not store.read_envelope(store.path).is_empty(),"After corruption both mirrors are actually repaired")
	var preserved:=false
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("checkpoint-collection-test-save.json.unreadable-"): preserved=true
	check(preserved,"Corrupt original is preserved separately before repair overwrites it")
	var broken:=BrokenStore.new(PREFIX+"-save.json")
	h.checkpoint_store=broken
	h.launch_next_wave()
	check(h.state=="shop","Failed save retirement cannot begin combat")
	h.save_and_title()
	check(h.state=="shop","Failed save cannot leave preparation via save-and-title")
	h.request_quit()
	check(h.state=="shop","Failed save blocks window-close quit rather than silently losing edits")
	h.checkpoint_store=store
	check(h.save_checkpoint(),"Preparation recovers after temporary write failure")
	h.launch_next_wave()
	check(h.state=="combat" and h.wave==2 and h.checkpoint_info().is_empty(),"Ready consumes save before new combat and cannot replay prior clear reward")
	bad_file=FileAccess.open(store.path,FileAccess.WRITE)
	bad_file.store_string("broken");bad_file.close()
	check(store.load_data().is_empty(),"Corrupt consumed primary cannot resurrect old active backup")
	h.end_reason="검사 실패"
	h.end_run(false)
	check(h.checkpoint_info().is_empty(),"Ending a run leaves no playable save")
	h.return_title()
	check(find(h.ui.modal,"Continue")==null,"Closed save is not advertised on title")
	var discoveries: Dictionary=h.profile.data.duplicate(true)
	h.ui.show_collection("title")
	await settle()
	check(h.ui.front_screen=="collection" and find(h.ui.modal,"Entry_bolt").get_meta("discovered"),"Collection shows acquired starting spell")
	var unseen: String=h.Spells.PARTS.keys().filter(func(id):return id not in h.profile.data.discovered_spells)[0]
	check(not find(h.ui.modal,"Entry_"+unseen).get_meta("discovered"),"Unseen spells remain undiscovered without browsing unlock")
	press("CollectionTab_fusion")
	check(find(h.ui.modal,"Entry_storm_spear").get_meta("discovered"),"Crafted completed fusion is visible in its own category")
	press("Entry_moon_ring")
	check(h.profile.data.discovered_fusions==discoveries.discovered_fusions,"Recipe hint browsing does not mark a fusion obtained")
	press("CollectionTab_relic")
	check(find(h.ui.modal,"Entry_seal").get_meta("discovered"),"Obtained relic has persistent discovery entry")
	var before_stock: Dictionary=h.economy.inventory.duplicate()
	press("CollectionBack")
	check(h.state=="title" and h.economy.inventory==before_stock,"Collection cannot grant or equip inventory")
	var p:=Profile.new(PREFIX+"-legacy.json")
	p.record_run({"won":true,"kit":"sigil","combat":100.0,"run_id":"legacy-id","recipes":[["bolt@3","moon_ring"],[]],"relics":["seal"]})
	p.save_profile()
	var migrated:=Profile.new(p.path)
	migrated.load_profile()
	check("bolt" in migrated.data.discovered_spells and "moon_ring" in migrated.data.discovered_fusions and "seal" in migrated.data.discovered_relics,"Existing concluded records seed discoveries on profile load")
	check(not migrated.record_run({"won":true,"kit":"sigil","combat":100.0,"run_id":"legacy-id"}) and migrated.data.wins==1,"Same run identity cannot increment result statistics twice")
	check(h.profile.data.discovered_spells.has("bolt") and h.profile.data.discovered_fusions.has("storm_spear"),"Discoveries survive run ending")
	var replacement:=normal.duplicate(true)
	replacement.run_id=Crypto.new().generate_random_bytes(16).hex_encode()
	h.checkpoint_store.write(replacement)
	h.ui.show_title()
	press("NewExperiment")
	press("StartExperiment")
	press("ConfirmReplace")
	check(h.state in ["intro","combat"] and h.run_id!=replacement.run_id and h.checkpoint_info().is_empty(),"Confirmed new run retires old save instead of reusing its stock")
	check(h.profile.data.discovered_fusions.has("storm_spear"),"Replacing a run preserves permanent discoveries")
	g.record_runs=false;h.record_runs=false
	g.queue_free();h.queue_free()
	await process_frame
	clean_files()
	print("RESULT: %d checks / %d failures"%[checks,failures])
	quit(1 if failures else 0)
