extends Node
## Erzeugt echte Spielscreenshots (1920×1080) für die Abgabe.
## Aufruf: godot --path . res://tests/shots.tscn -- --mode=all

var out_dir := "res://docs/shots"
var log_file: FileAccess
var count := 0
var only := ""

func _log(msg: String) -> void:
	if log_file == null:
		log_file = FileAccess.open("res://docs/_shots_progress.txt", FileAccess.WRITE)
	if log_file != null:
		log_file.store_line(msg)
		log_file.flush()
	print(msg)

func _ready() -> void:
	_log("SHOTS: start")
	await get_tree().process_frame
	_log("SHOTS: frame ok")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var app = get_node_or_null("/root/App")
	if app == null:
		print("SHOTS: kein App-Autoload")
		get_tree().quit(1)
		return
	Engine.max_fps = 60
	await get_tree().create_timer(0.8, false).timeout
	await _shot("01_hauptmenue")

	# Einstellungen
	app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
	await _pause(0.5)
	await _shot("02_einstellungen")
	app.clear_screens()

	# Kampagne + Level 1
	app.start_new_campaign("normal", "pierce1")
	await _wait_game()
	app.game.player.autofire = true
	await _pause(2.2)
	await _shot("03_level1_bluetenmeer")

	# Level 3 Wasser
	app.clear_screens()
	app._begin_level(3, 0)
	await _wait_game()
	app.game.player.autofire = true
	await _pause(2.4)
	await _shot("04_level3_schilf_und_teich")

	# Level 5 Boss
	app.clear_screens()
	app._begin_level(5, 0)
	await _wait_game()
	app.game.player.autofire = true
	await _pause(1.2)
	app.game.director.start_boss_now()
	await _pause(2.6)
	await _shot("05_level5_mantidenpaar_boss")

	# Level 8 Maschinenherz
	app.clear_screens()
	app._begin_level(8, 0)
	await _wait_game()
	app.game.player.autofire = true
	await _pause(2.0)
	await _shot("06_level8_maschinenherz")

	# Level 10 Kernorganismus, Phase 2
	app.clear_screens()
	app._begin_level(10, 0)
	await _wait_game()
	app.game.player.autofire = true
	app.game.director.start_boss_now()
	await _pause(2.0)
	if app.game.boss != null and is_instance_valid(app.game.boss):
		app.game.boss.take_damage(app.game.boss.max_hp * 0.42)
	await _pause(1.4)
	await _shot("07_level10_kernorganismus_boss")

	# Evolutionsauswahl
	app.clear_screens()
	Save.campaign.seed = 424242
	Save.campaign.evolutions = []
	Save.campaign.rewarded_levels = []
	Save.campaign.level_stats = {"1": {"level": 1, "score": 18450, "kills": 72, "hits": 1,
		"time": 412.0, "rank": "A", "rank_text": "Meisterhaft", "difficulty": "normal", "seed": 424242}}
	Save.campaign.level = 1
	Save.campaign.pending = {"level": 1, "offers": app._roll_offers(3), "reroll_used": false}
	app.show_evolution_screen(false)
	await _pause(0.6)
	await _shot("08_evolutionsauswahl")

	# Levelabschluss
	app.clear_screens()
	app.push_screen("res://scripts/screens/level_result_screen.gd", {
		"stats": Save.campaign.level_stats["1"], "level": 1, "chosen": String(Save.campaign.pending.offers[0]),
		"new_unlock": true})
	await _pause(0.6)
	await _shot("09_levelabschluss")

	_log("SHOTS_DONE %d" % count)
	get_tree().quit(0)

func _wait_game() -> void:
	for i in range(600):
		var app = get_node("/root/App")
		if app.game != null and is_instance_valid(app.game):
			await _pause(0.4)
			return
		await get_tree().process_frame

func _pause(t: float) -> void:
	await get_tree().create_timer(t, false).timeout

func _shot(name: String) -> void:
	await get_tree().create_timer(0.25, false).timeout
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var vp := get_viewport()
	var img: Image = vp.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err == OK:
		count += 1
		_log("SHOT %s  %dx%d" % [name, img.get_width(), img.get_height()])
	else:
		_log("SHOT_FAIL %s err=%d" % [name, err])
