extends Node
## Bild des Game-Over-Bildschirms (Weiter und kein Weiter mehr).

var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Save.new_campaign("normal", 313131)
	Save.campaign.shop = {"orbit": 2, "fire_rate": 2}
	Save.campaign.points = 12000
	Save.save_campaign()
	app.clear_screens()
	app._begin_level(2, 0)
	for i in range(16):
		await get_tree().process_frame
	var g = app.game
	g.player.hp = 1
	g.player.iframes = 0.0
	g.player.take_damage(9, Vector2.ZERO)
	print("INFO nach Schaden: hp=%d alive=%s frozen=%s" % [g.player.hp, str(g.player.alive), str(g.frozen_by_death)])
	if not g.frozen_by_death:
		g._on_player_died()
	# Todesanzeige dauert zwei Sekunden – zeitbasiert warten, nicht nach Bildern.
	for i in range(60):
		await get_tree().create_timer(0.1, true).timeout
		if app.screens.size() > 0:
			break
	await get_tree().create_timer(0.4, true).timeout
	print("INFO screens=%d paused=%s" % [app.screens.size(), str(get_tree().paused)])
	var has_cont := false
	for it in app.screens[0].items:
		if String((it as Dictionary).get("id", "")) == "continue":
			has_cont = true
	print("INFO Weiter angeboten=%s" % str(has_cont))
	await _shot("docs/go_01_gameover.png")
	# dritter Game Over: kein Weiter mehr
	app.continue_after_death()
	await get_tree().create_timer(0.3, true).timeout
	Save.campaign.deaths = 3
	app.show_game_over()
	await get_tree().create_timer(0.4, true).timeout
	await _shot("docs/go_02_kein_weiter.png")
	# Run beenden -> Hauptmenü mit Notiz und ohne „Fortsetzen“
	app.show_game_over()
	await get_tree().create_timer(0.4, true).timeout
	app.abandon_run()
	await get_tree().create_timer(0.6, true).timeout
	if app.screens.size() > 0:
		var menu = app.screens[0]
		for it in menu.items:
			if String((it as Dictionary).get("id", "")) == "continue":
				print("INFO Fortsetzen gesperrt=%s" % str(bool((it as Dictionary).get("disabled", false))))
		print("INFO Notiz=%s" % menu.header_note)
		await _shot("docs/go_03_hauptmenue_nach_run.png")
	print("GOBILDER_OK")
	get_tree().quit(0)

func _shot(path: String) -> void:
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://" + path))
	print("Bild: " + path)
