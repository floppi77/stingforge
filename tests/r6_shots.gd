extends "res://tests/r3_shots.gd"
## Bildnachweise R6: Tutorialfenster, HUD-Kopf, Verschmelzungen, Evolution,
## Brunnensäulen, Felsregen, Käferglut.

func _run() -> void:
	Save.profile["tutorial_done"] = false
	app.start_tutorial()
	await _wait(1.6)
	await _shot("t1_willkommen")
	app.screens[-1]._age = 1.0
	app.screens[-1].close()
	await _wait(0.4)
	app.game.get_node("Tutorial")._moved = 700.0
	await _wait(0.6)
	app.screens[-1]._age = 1.0
	app.screens[-1].close()
	await _wait(0.5)
	for e in app.game.enemies:
		if is_instance_valid(e):
			e.take_damage(9999.0)
	await _wait(0.6)
	app.screens[-1]._age = 1.0
	app.screens[-1].close()
	app.game.player.nectar = 5
	await _wait(0.6)
	await _shot("t2_waffenleiste")
	app.menu_main()
	await _wait(0.5)
	app.push_screen("res://scripts/screens/fusion_screen.gd", {}, 0.0)
	await _wait(0.5)
	await _shot("t3_verschmelzungen")
	app.clear_screens()
	Save.new_campaign("normal", 991)
	Save.campaign.evolutions = [{"id": "heavy_sting", "level": 1}]
	Save.campaign.pending = {"level": 2, "offers": ["splinter", "crit", "pollen_trail"], "reroll_used": false}
	app.mode = "campaign"
	app.push_screen("res://scripts/screens/evolution_screen.gd", {}, 0.0)
	await _wait(0.5)
	await _shot("t4_evolution")
	await _level(3)
	await _wait(1.2)
	_protect()
	app.game.spawn_geyser(520.0)
	await _wait(1.3)
	await _shot("t5_brunnensaeule")
	await _level(2)
	await _wait(1.0)
	_protect()
	app.game._spawn_boss()
	await _wait(2.5)
	app.game.boss.take_damage(app.game.boss.max_hp * 0.75)
	await _wait(3.5)
	await _shot("t6_felsregen")
	await _level(1)
	await _wait(1.0)
	_protect()
	app.game._spawn_boss()
	await _wait(2.5)
	app.game.boss.take_damage(app.game.boss.max_hp * 0.5)
	await _wait(2.6)
	await _shot("t7_kaeferglut")
