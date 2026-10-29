extends Node
## Echte UI-/Runpfade: Reset, feste Schwierigkeit und Highscore-Integration.
var checks := 0
var failures: Array[String] = []
var app: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().begins_with(ProjectSettings.globalize_path("res://build/stingforge-r2-testdata-flow") + "/"):
		push_error("Unsicherer Testdatenpfad")
		get_tree().quit(2)
		return
	app = get_node("/root/App")
	await get_tree().create_timer(0.2, true).timeout
	await _run()
	for failure in failures: print("FAIL " + failure)
	print("STINGFORGE_R2_FLOW checks=%d failures=%d" % [checks, failures.size()])
	print("STINGFORGE_R2_FLOW_OK" if failures.is_empty() else "STINGFORGE_R2_FLOW_FAILED")
	app.menu_main()
	Audio.stop_music(0.0)
	for i in range(3): await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func same_upgrade_values(a: Dictionary, b: Dictionary) -> bool:
	# JSON liest Zahlen als float: semantische Werte statt Variant-Typgleichheit.
	if a.size() != b.size(): return false
	for key in a:
		if not b.has(key) or float(a[key]) != float(b[key]): return false
	return true

func fresh(difficulty: String = "normal") -> void:
	app.clear_screens()
	app.mode = "campaign"
	Save.new_campaign(difficulty, 271009)
	Save.campaign.shop = {"fire_rate": 2, "extra_shield": 2}
	Save.campaign.evolutions = [{"id": "chitin_plate", "level": 1}]

func _run() -> void:
	check(is_equal_approx(App.PLAY_TOP, 40.0) and is_equal_approx(App.PLAY_BOTTOM, 496.0), "Kompakte reservierte HUD-Grenzen")
	fresh("expert")
	var settings = load("res://scripts/screens/settings_screen.gd").new()
	settings.app = app
	settings.setup({"from": "main"})
	settings.tab = 4
	add_child(settings)
	await get_tree().process_frame
	check(not settings.items.any(func(row): return String(row.get("id", "")) == "difficulty"), "Optionen enthalten keinen Schwierigkeitsregler")
	var prior: String = String(Save.g("game.difficulty", "normal"))
	settings._adjust_choice("difficulty", 1)
	check(String(Save.g("game.difficulty", "normal")) == prior, "Veraltete Difficulty-Adjust-ID ist wirkungslos")
	Save.reset_settings_section("game")
	check(Save.campaign.difficulty == "expert", "Optionen-Zurücksetzen verändert laufende Schwierigkeit nicht")
	settings.queue_free()
	await get_tree().process_frame
	for difficulty in ["relaxed", "normal", "expert"]:
		fresh(difficulty)
		Save.campaign.nectar = 87
		Save.campaign.points = 12345
		Save.campaign.weapon = "plasma"
		Save.campaign.speed_level = 3
		for u in Data.UPGRADES:
			Save.campaign.upgrades[u.id] = int(u.max)
		app.reset_upgrades_for_new_level()
		for u in Data.UPGRADES:
			check(int(Save.campaign.upgrades.get(u.id, -1)) == (1 if u.id == "base" else 0), difficulty + ": Reset " + String(u.id))
		check(Save.campaign.weapon == "base" and int(Save.campaign.speed_level) == 0, difficulty + ": Ausrüstung und Flugtempo zurückgesetzt")
		check(int(Save.campaign.nectar) == 87 and int(Save.campaign.points) == 12345, difficulty + ": Umrechnungs-Nektar und Werkstattpunkte bleiben erhalten")
		check(Save.campaign.shop == {"fire_rate": 2, "extra_shield": 2}, difficulty + ": Werkstatt bleibt erhalten")
		check(Save.campaign.evolutions == [{"id": "chitin_plate", "level": 1}], difficulty + ": Evolutionen bleiben erhalten")
		check(Save.campaign.difficulty == difficulty, difficulty + ": Schwierigkeit bleibt erhalten")
		var stored: Dictionary = Save._read_json(Save._path("campaign"))
		check(same_upgrade_values(stored.upgrades, Save.campaign.upgrades) and stored.weapon == "base", difficulty + ": Reset sofort gespeichert")
		app.reset_upgrades_for_new_level()
		check(same_upgrade_values(Save.campaign.upgrades, stored.upgrades), difficulty + ": Reset idempotent")
	fresh()
	Save.campaign.upgrades = {}
	app.reset_upgrades_for_new_level()
	check(Save.campaign.upgrades.size() == Data.UPGRADES.size(), "Auch unvollständige alte Upgrade-Dictionaries werden normalisiert")
	app.menu_main()
	var menu = app.screens[-1]
	check(menu.items.any(func(row): return String(row.get("id", "")) == "scores"), "Highscoreliste vom Hauptmenü erreichbar")
	var rush_index := -1
	for i in range(menu.items.size()):
		if String(menu.items[i].get("id", "")) == "rush": rush_index = i
	Save.profile.boss_rush_unlocked = true
	menu.build_items()
	if rush_index >= 0:
		menu.on_activate(rush_index)
		check(not app.screens.is_empty() and app.screens[-1].get_script().resource_path.ends_with("difficulty_screen.gd"), "Auch Boss-Rush fragt Schwierigkeit nur beim Start ab")
	app.menu_main()
	await _test_run_endings()

func _test_run_endings() -> void:
	Save.profile = Save._default_profile()
	Save.save_profile()
	# Echte Player-Credits, echte App-Death-/Abbruchhooks; Ausgaben sind keine Minuspunkte.
	fresh("expert")
	app._begin_level(3, 0)
	for i in range(5): await get_tree().process_frame
	var game = app.game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.add_points(500)
	game.player.points -= 350
	Save.campaign.points = game.player.points
	var failed_id: String = Save.campaign.run_id
	check(int(Save.campaign.run_score) == 500 and int(Save.campaign.points) == 150, "Verdiente Punkte unabhängig vom ausgegebenen Guthaben")
	app.on_player_death()
	app.on_player_death()
	check(Save.get_highscores("campaign", "expert", 20).is_empty(), "Kein vorzeitiger Highscore beim möglichen Continue")
	app.on_player_death()
	var rows: Array = Save.get_highscores("campaign", "expert", 20)
	check(rows.size() == 1, "Drittes Game Over trägt echten Run ein")
	if not rows.is_empty():
		check(int(rows[0].score) == 500 and int(rows[0].level) == 3 and not bool(rows[0].completed), "Game-Over-Eintrag hat verdiente Punkte und erreichten Level")
	app.abandon_run()
	check(not Save.active_campaign, "Aufgegebener Kampagnenrun beendet")
	check(Save.get_highscores("campaign", "expert", 20).size() == 1, "Game Over plus Beenden erzeugt keine Dublette")
	check(String(Save.get_highscores("campaign", "expert", 20)[0].run_id) == failed_id, "Runidentität bleibt im Profil erhalten")

	# Wirklicher Abschluss-/Umrechnungs-/Evolutionspfad, nicht direktes Record-Mocking.
	fresh("normal")
	Save.campaign.run_score = 1000
	Save.campaign.points = 200
	Save.campaign.nectar = 5
	Save.campaign.upgrades = {"base": 1, "plasma": 3, "shield": 3}
	Save.campaign.weapon = "plasma"
	Save.campaign.speed_level = 3
	app.run_level = 10
	app.on_level_complete({"level": 10, "score": 1000, "rank": "A", "seed": 271009, "difficulty": "normal"})
	check(int(Save.campaign.upgrades.shield) == 0 and Save.campaign.weapon == "base", "Schon Siegcallback setzt Taktik zurück, nicht erst Resultat-Weiter")
	check(int(Save.campaign.nectar) == 5, "Reset vernichtet keine noch umzurechnende Beute")
	check(Save.get_highscores("campaign", "normal", 20).is_empty(), "Siegscore wartet auf den vollständigen Umrechnungsbonus")
	await get_tree().create_timer(1.7, true).timeout
	var conversion = app.screens[-1]
	check(conversion.get_script().resource_path.ends_with("nectar_convert_screen.gd"), "Echter Abschluss öffnet Nektarumrechnung")
	check(int(Save.campaign.run_score) == 1050 and int(Save.campaign.nectar) == 0, "Umrechnung erhöht Runscore einmalig")
	conversion._finish()
	for i in range(3): await get_tree().process_frame
	# Nach dem letzten Boss gibt es keine Evolutionswahl mehr: direkt Wertung und Sieg.
	check(Save.campaign.pending.is_empty(), "Nach Level 10 keine Evolutionswahl")
	check(String(app.screens[-1].get_script().resource_path).ends_with("level_result_screen.gd"), "Nach Level 10 direkt die Wertung")
	rows = Save.get_highscores("campaign", "normal", 20)
	check(rows.size() == 1, "Vollständiger Abschluss veröffentlicht einen Sieg")
	if not rows.is_empty():
		check(int(rows[0].score) == 1050 and bool(rows[0].completed) and int(rows[0].level) == 10, "Sieg enthält Nektarbonus und Level10")
	app._record_run_highscore(false)
	check(bool(Save.get_highscores("campaign", "normal", 20)[0].completed), "Später Abbruch kann Siegstatus nicht zurücknehmen")
	app.menu_main()
	app.continue_campaign()
	check(app.game == null, "Abgeschlossener Run wird nicht unter alter Scoreidentität neu gestartet")

	# Restore zwischen Sieg und Evolution: Bonus nachholen, danach nicht doppelt zählen.
	fresh()
	Save.campaign.level = 2
	Save.campaign.run_score = 200
	Save.campaign.points = 20
	Save.campaign.nectar = 3
	Save.campaign.pending = {"level": 2, "offers": ["pierce1", "crit", "heavy_sting"], "reroll_used": false}
	app.continue_campaign()
	for i in range(3): await get_tree().process_frame
	check(int(Save.campaign.run_score) == 230 and int(Save.campaign.nectar) == 0, "Restore holt ausstehenden Nektarbonus nach")
	app.continue_campaign()
	check(int(Save.campaign.run_score) == 230, "Erneutes Restore schreibt keinen zweiten Bonus")
	app.menu_main()

	# Rush ist ein eigener Run; Quit muss die Originalkampagne erhalten.
	fresh("expert")
	# Boss-Rush braucht mindestens einen im Run besiegten Boss.
	Save.campaign.level_stats = {"1": {}}
	Save.save_campaign()
	var campaign_id: String = Save.campaign.run_id
	var original_hash := FileAccess.get_sha256(Save._path("campaign"))
	app.start_boss_rush("relaxed")
	for i in range(5): await get_tree().process_frame
	game = app.game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	check(Save.campaign.run_id != campaign_id and int(Save.campaign.run_score) == 0, "Boss-Rush hat eigene frische Scoreidentität")
	check(Save.campaign.difficulty == "relaxed" and game.difficulty.name == "diff.relaxed", "Beim Rush-Start gewählte Schwierigkeit gilt im Spiel")
	game.player.add_points(123)
	app.abandon_run()
	check(Save.active_campaign and Save.campaign.run_id == campaign_id and Save.campaign.difficulty == "expert", "Rush-Abbruch stellt Originalkampagne unverändert wieder her")
	check(FileAccess.get_sha256(Save._path("campaign")) == original_hash, "Rush-Abbruch löscht oder überschreibt echten Kampagnensave nicht")
	rows = Save.get_highscores("rush", "relaxed", 20)
	check(rows.size() == 1 and int(rows[0].score) == 123, "Rushpunkte getrennt von Kampagnenrangliste gespeichert")
	app.menu_main()
