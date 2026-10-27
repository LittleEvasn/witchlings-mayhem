extends RefCounted
const Clicks = preload("res://tools/orb_workbench_visual_probe.gd")
static func duplicate_upgrade(game: Node) -> Dictionary:
	game.start_run("sigil")
	game.set_physics_process(false)
	game.complete_wave()
	game.choose_reward("power")
	game.economy.inventory["bolt@2"] = 1 # UI fixture only.
	game.economy.gold = 0
	game.set_shop_tab("forge")
	game.select_forge_item("bolt@2")
	await game.get_tree().process_frame
	var clicked := await Clicks.click(game,"별빛탄 소모")
	return {"clicked":clicked,"rank3":game.economy.inventory.get("bolt@3",0),"base_remaining":game.economy.inventory.get("bolt",0),"rank2_remaining":game.economy.inventory.get("bolt@2",0),"gold":game.economy.gold}
static func begin(game: Node) -> Dictionary:
	game.start_run("sigil")
	game.set_physics_process(false)
	game.sound_enabled = false
	game.rng.seed = 2307
	game.complete_wave()
	game.choose_reward("power")
	game.economy.gold = 220 # UI fixture, never part of the gameplay reward.
	game.ui.show_shop()
	await game.get_tree().process_frame
	var tab := await Clicks.click(game,"강화 · 합성")
	var selected := await Clicks.click(game,"별빛탄 ×")
	var upgraded := await Clicks.click(game,"마석 강화")
	return {"forge_tab":tab and game.shop_tab=="forge","select_copy":selected,"upgrade_click":upgraded and game.economy.inventory.get("bolt@1",0)==1,"gold":game.economy.gold}
static func ready_fusion(game: Node) -> Dictionary:
	for i in 3: await Clicks.click(game,"마석 강화")
	await Clicks.click(game,"상점 · 조합으로")
	game.select_research("thunder",game.economy.revision)
	await game.get_tree().process_frame
	await Clicks.click(game,"16 G · 구입")
	await Clicks.click(game,"강화 · 합성")
	await Clicks.click(game,"벼락 ×")
	for i in 4: await Clicks.click(game,"마석 강화")
	var selected := await Clicks.click(game,"뇌광창   ←")
	return {"fusion_selected":selected,"bolt4":game.economy.inventory.get("bolt@4",0),"thunder4":game.economy.inventory.get("thunder@4",0),"gold":game.economy.gold}
static func fuse(game: Node) -> Dictionary:
	var clicked := await Clicks.click(game,"합성 실행")
	return {"fusion_click":clicked,"result":game.economy.inventory.get("storm_spear",0),"recipe":game.recipe,"gold":game.economy.gold}
static func trial(game: Node) -> Dictionary:
	var started := await Clicks.click(game,"시험 발사")
	game.cast_target = Vector2(710,260)
	game.orb_clocks = [0,0]
	game._tick_orbs(0.02)
	for i in 42:
		game._update_projectiles(1.0/60)
		game.magic.update_zones(1.0/60)
		game._update_effects(1.0/60)
	game.visuals.queue_redraw()
	game.ui.update_trial_stats()
	await game.get_tree().process_frame
	return {"trial_click":started and game.state=="trial","damage":game.trial_damage,"strikes":game.magic.behavior.strikes.size(),"projectiles":game.projectiles.size()}
