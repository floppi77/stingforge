extends Node
## R3-Bildnachweise (nur im Fenster): HUD mit Laufzeitleiste, Pause-Overlay,
## Game Over und die wichtigsten Menüs. Isolierte Testdaten, keine Nutzersaves.

var out_dir := "res://build/r3-shots/"
var app: Node
var only: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	var want_size := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("size="):
			var wh := a.trim_prefix("size=").split("x")
			want_size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("out="):
			out_dir = "res://build/" + a.trim_prefix("out=") + "/"
		else:
			only.append(a)
	if DisplayServer.get_name() == "headless":
		print("R3_SHOTS_SKIPPED headless")
		get_tree().quit(0)
		return
	# Fokuswechsel des Testfensters soll keine Pause auslösen.
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	app.fade.color.a = 0.0
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = want_size
	await _wait(0.8)
	await _run()
	print("R3_SHOTS_OK")
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out_dir + name + ".png"))
	print("R3_SHOT " + name)

func _protect() -> void:
	var g = app.game
	if g != null and g.player != null:
		g.player.max_hp = 4
		g.player.hp = 3
		g.player.iframes = 1.0e6

func _level(level: int, seed_value: int = 777) -> void:
	Save.new_campaign("normal", seed_value)
	Save.campaign.nectar = 85
	Save.campaign.points = 48250
	Save.campaign.upgrades = {"base": 2, "fan": 1, "lightning": 0, "plasma": 0, "companion": 1,
		"bombs": 0, "shield": 3, "speed": 1, "repair": 0}
	Save.campaign.weapon = "fan"
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await _wait(0.3)
	_protect()

func _run() -> void:
	if _want("hud"):
		await _level(1)
		await _wait(3.4)
		app.game.director.spawn_formation("moth_arc")
		await _wait(1.6)
		await _shot("01_hud_level1")
	if _want("late"):
		await _level(5)
		await _wait(2.6)
		var d = app.game.director
		var secs: Array = d.level_data.sections
		# Spät im Level: vorletzter Abschnitt, Checkpoints teils passiert.
		var cp := maxi(1, secs.size() - 2)
		d.section = cp
		d.time = float(d.checkpoint_times[cp]) + float(secs[cp].dur) * 0.6
		d.section_t = float(secs[cp].dur) * 0.6
		d.checkpoint_index = cp
		await _wait(1.2)
		await _shot("02_hud_spaet")
	if _want("pause"):
		await _level(3)
		await _wait(3.2)
		app.game.director.spawn_formation("reed_leap")
		await _wait(1.2)
		app.pause_game()
		await _wait(0.5)
		await _shot("03_pause")
		app.screens[-1].on_activate(app.screens[-1].items.size() - 1)
		await _wait(0.4)
		await _shot("04_pause_rueckfrage")
		app.resume_game()
		await _wait(0.2)
	if _want("wave"):
		Save.new_campaign("normal", 4040)
		Save.campaign.shop = {"wave": 3, "wave_amp": 2}
		app.mode = "campaign"
		app.clear_screens()
		app._begin_level(1, 0)
		await _wait(0.3)
		_protect()
		app.game.player.autofire = true
		app.game.player.position = Vector2(140, 270)
		await _wait(3.0)
		await _shot("18_wellenschuss")
	if _want("newfoes"):
		await _level(2)
		await _wait(2.4)
		var gf = app.game
		gf._on_spawn_enemy("hornet_flank", Vector2(-60, 200), {"target_x": 520.0})
		gf._on_spawn_enemy("web_spider", Vector2(700, -30), {"hang_y": 220.0})
		gf._on_spawn_enemy("ant_gunner", Vector2(900, App.PLAY_BOTTOM - 20), {})
		gf._on_spawn_enemy("mole_cricket", Vector2(640, App.PLAY_BOTTOM + 30), {})
		await _wait(1.9)
		await _shot("19_neue_gegner")
	if _want("hazards"):
		for spec in [[2, "root_spike", "13_wurzeln"], [3, "water_splash", "14_fontaene"],
				[4, "spore_cloud", "15_sporen"], [5, "wind_zone", "16_wind"], [10, "gravity_field", "17_schwerkraft"]]:
			await _level(int(spec[0]))
			await _wait(2.4)
			var gg = app.game
			for i in range(3):
				gg._on_hazard(String(spec[1]), {"y": 0.3 + 0.2 * i, "dir": 1.0})
				await _wait(0.25)
			if String(spec[1]) == "spore_cloud":
				for hz in gg.fx.hazards:
					if String(hz.kind) == "spore_cloud":
						hz.p.x = 520.0 + 140.0 * float(gg.fx.hazards.find(hz))
			await _wait(0.45)
			print("HAZ ", spec[2], " ", gg.fx.hazards.map(func(x): return "%s life=%.2f base=%s" % [x.kind, x.life, str(x.get("base", "-"))]))
			await _shot(String(spec[2]))
	if _want("boss"):
		await _level(2)
		await _wait(2.4)
		app.game.director.start_boss_now()
		await _wait(4.5)
		await _shot("05_hud_boss")
	if _want("gameover"):
		await _level(4)
		await _wait(2.5)
		app.show_game_over()
		await _wait(0.5)
		await _shot("06_gameover")
	if _want("menus"):
		app.menu_main()
		await _wait(0.6)
		await _shot("07_hauptmenue")
		app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"}, 0.0)
		await _wait(0.4)
		await _shot("08_einstellungen")
		app.clear_screens()
		Save.new_campaign("normal", 991)
		Save.campaign.points = 42000
		Save.campaign.level = 4
		app.mode = "campaign"
		app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 4}, 0.0)
		await _wait(0.4)
		await _shot("09_werkstatt")
		app.clear_screens()
		Save.campaign.pending = {"level": 4, "offers": app._roll_offers(3), "reroll_used": false}
		app.push_screen("res://scripts/screens/evolution_screen.gd", {}, 0.0)
		await _wait(0.4)
		await _shot("10_evolution")
		app.clear_screens()
		app.push_screen("res://scripts/screens/level_result_screen.gd", {"stats": {"level": 4,
			"score": 61240, "kills": 212, "hits": 2, "time": 301.0, "accuracy": 0.91, "rank": "A",
			"rank_text": "Starker Flug"}, "level": 4, "training": false}, 0.0)
		await _wait(0.4)
		await _shot("11_ergebnis")
		app.clear_screens()
		app.push_screen("res://scripts/screens/story_screen.gd", {"level": 6, "on_done": func(): pass}, 0.0)
		await _wait(0.6)
		await _shot("12_story")
		app.menu_main()
		await _wait(0.3)
