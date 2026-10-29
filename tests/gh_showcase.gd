extends "res://tests/r3_shots.gd"
## Galerie für die GitHub-Projektseite: Menü, Tutorial, Level, Bosse, Werkstatt,
## Verschmelzungen, Evolution, Ultrawide – je Sprache.
## Aufruf (mit Fenster): godot --path . tests/gh_showcase.tscn -- out=gh-showcase lang=de [size=2560x1080]

func _fight(level: int, formations: Array, wait_s: float = 3.0) -> void:
	await _level(level)
	await _wait(2.6)
	app.game.player.autofire = true
	app.game.player.position = Vector2(170, 270)
	for f in formations:
		app.game.director.spawn_formation(String(f))
		await _wait(0.5)
	await _wait(wait_s)

func _boss(level: int, hit: float = 0.0, settle: float = 5.0) -> void:
	await _level(level)
	await _wait(2.0)
	app.game.player.autofire = true
	app.game.player.position = Vector2(170, 270)
	app.game.director.start_boss_now()
	await _wait(settle)
	if hit > 0.0 and app.game.boss != null:
		app.game.boss.take_damage(app.game.boss.max_hp * hit)

## Hauptmenü mit laufendem Run (Level 4, drei Bosse besiegt, Evolutionen im Profil).
func _menu_fixture() -> void:
	Save.profile.unlocked_evolutions = ["pierce1", "splinter", "crit", "heavy_sting", "pollen_trail"]
	Save.profile["tutorial_done"] = true
	Save.new_campaign("normal", 20261029)
	Save.campaign.level = 4
	Save.campaign.points = 42137
	Save.campaign.level_stats = {"1": {}, "2": {}, "3": {}}
	Save.campaign.level_scores = {"1": 12000, "2": 14500, "3": 15637}

func _run() -> void:
	var lang := "de"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			lang = a.trim_prefix("lang=")
			only.erase(a)
	Loc.set_language(lang)
	var wide := get_window().size.x > 2200
	if wide:
		await _fight(3, ["reed_leap", "moth_line"], 2.0)
		await _shot("uw_level3_schilf")
		await _boss(9, 0.0, 5.5)
		await _shot("uw_level9_koenigin")
		return
	_menu_fixture()
	app.menu_main()
	await _wait(1.0)
	await _shot("01_hauptmenue")
	Save.profile["tutorial_done"] = false
	app.start_tutorial()
	await _wait(1.6)
	for i in range(2):
		app.screens[-1]._age = 1.0
		app.screens[-1].close()
		await _wait(0.4)
		if i == 0:
			app.game.get_node("Tutorial")._moved = 700.0
			await _wait(0.6)
	for e in app.game.enemies:
		if is_instance_valid(e):
			e.take_damage(9999.0)
	await _wait(0.6)
	app.screens[-1]._age = 1.0
	app.screens[-1].close()
	app.game.player.nectar = 5
	await _wait(0.6)
	await _shot("10_tutorial")
	app.menu_main()
	await _wait(0.3)
	Save.profile["fusions_seen"] = [Data.fusion_key("splinter", "heavy_sting"), Data.fusion_key("pierce1", "pierce_master")]
	app.push_screen("res://scripts/screens/fusion_screen.gd", {}, 0.0)
	await _wait(0.5)
	await _shot("11_verschmelzungen")
	await _fight(1, ["moth_arc", "aphid_cloud"], 1.4)
	await _shot("02_level1_bluetenmeer")
	await _fight(4, ["moth_line", "pod_field"], 1.6)
	app.game._on_hazard("spore_cloud", {"y": 0.45, "dir": 1.0})
	await _wait(1.2)
	await _shot("03_level4_pilzwald")
	await _fight(6, ["moth_arc"], 1.0)
	app.game._on_hazard("reflect_panel", {})
	await _wait(2.4)
	await _shot("04_level6_glas")
	await _boss(2, 0.0, 4.5)
	app.game.boss.take_damage(app.game.boss.max_hp * 0.45)
	await _wait(0.9)
	await _shot("05_boss_larve_phase2")
	await _boss(5, 0.0, 6.0)
	await _shot("06_boss_mantidenpaar")
	await _boss(10, 0.0, 6.0)
	await _shot("07_boss_kernorganismus")
	app.clear_screens()
	Save.new_campaign("normal", 991)
	Save.campaign.points = 42000
	Save.campaign.shop = {"wave": 1, "orbit": 2, "fire_rate": 1}
	app.mode = "campaign"
	var shop = app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 4}, 0.0)
	await _wait(0.4)
	shop._enter_items()
	shop._move_focus(1)
	await _wait(0.8)
	await _shot("08_werkstatt")
	app.clear_screens()
	Save.campaign.pending = {"level": 4, "offers": app._roll_offers(3), "reroll_used": false}
	app.push_screen("res://scripts/screens/evolution_screen.gd", {}, 0.0)
	await _wait(0.6)
	await _shot("09_evolution")
