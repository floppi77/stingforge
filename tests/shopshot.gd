extends Node
## Belege für Runde 4: Werkstatt, gesperrte Einträge, Bossankündigung,
## Debugmenü und die Waffenleiste grau/gold.

var count := 0
var out_dir := "res://docs"
var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.4, false).timeout
	await _shop_shots()
	await _bar_shots()
	await _boss_shot()
	await _debug_shot()
	print("SHOPBILDER %d" % count)
	print("SHOPBILDER_OK" if count >= 6 else "SHOPBILDER_FAILED")
	get_tree().quit(0 if count >= 6 else 1)

func _shop_shots() -> void:
	Save.new_campaign("normal", 880011)
	Save.campaign.points = 26000
	Save.campaign.shop = {}
	app.clear_screens()
	app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 3})
	await get_tree().create_timer(0.5, false).timeout
	await _shot("shop_01_werkstatt")
	var shop = app.screens[app.screens.size() - 1]
	if shop != null:
		# auf einen gesperrten Eintrag (Schnelle Wellen) springen
		for i in range(shop.items.size()):
			if String(shop.items[i].get("id", "")) == "wave_freq":
				shop.focus = i
				shop._update_focus_visuals()
				break
		await get_tree().create_timer(0.3, false).timeout
		await _shot("shop_02_gesperrt")
		# auf einen bezahlbaren Eintrag (Kreisflug) springen
		for i in range(shop.items.size()):
			if String(shop.items[i].get("id", "")) == "orbit":
				shop.focus = i
				shop._update_focus_visuals()
				break
		await get_tree().create_timer(0.3, false).timeout
		await _shot("shop_03_kaufbar")
		# kaufen mit echter Leertaste und Ergebnis festhalten
		await _press(KEY_SPACE)
		await get_tree().create_timer(0.4, false).timeout
		print("BELEG nach Kauf: Punkte %d, Stufe %s" % [int(Save.campaign.get("points", 0)),
			str(Save.campaign.get("shop", {}).get("orbit", 0))])
		await _shot("shop_08_gekauft")
	app.clear_screens()
	await get_tree().process_frame

func _bar_shots() -> void:
	Save.new_campaign("normal", 5150)
	Save.campaign.points = 1200
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		return
	g.player.autofire = true
	g.player.iframes = 9999.0
	# wenig Nektar: alles grau
	g.player.nectar = 2
	g.player.upgrades["fan"] = 1
	await get_tree().create_timer(0.8, false).timeout
	await _shot("shop_04_leiste_grau")
	# viel Nektar: bezahlbare Einträge leuchten
	g.player.nectar = 400
	await get_tree().create_timer(0.8, false).timeout
	await _shot("shop_05_leiste_gold")
	app.clear_screens()
	await get_tree().process_frame

func _boss_shot() -> void:
	Save.new_campaign("normal", 5152)
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		return
	g.player.iframes = 9999.0
	await get_tree().create_timer(0.5, false).timeout
	g.director.start_boss_now()
	await get_tree().create_timer(0.35, false).timeout
	await _shot("shop_06_bossankuendigung")
	app.clear_screens()
	await get_tree().process_frame

func _debug_shot() -> void:
	Save.new_campaign("normal", 6161)
	Save.campaign.points = 30000
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		return
	g.player.iframes = 9999.0
	await get_tree().create_timer(0.4, false).timeout
	if app.paused:
		app.resume_game()
		await get_tree().create_timer(0.6, true).timeout
	app.debug_game()
	await get_tree().create_timer(0.5, true).timeout
	var dbg = app.screens[app.screens.size() - 1] if not app.screens.is_empty() else null
	if dbg != null:
		for i in range(dbg.items.size()):
			if String(dbg.items[i].get("id", "")) == "s:orbit":
				dbg.focus = i
				dbg._update_focus_visuals()
				break
	await get_tree().create_timer(0.4, true).timeout
	await _shot("shop_07_debugmenu")
	app.debug_close()
	await get_tree().create_timer(0.3, true).timeout
	app.clear_screens()
	await get_tree().process_frame

func _press(key: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().create_timer(0.25, false).timeout
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().create_timer(0.2, false).timeout

func _wait_game() -> Node:
	for i in range(400):
		if app.game != null and is_instance_valid(app.game) and app.game.player != null:
			return app.game
		await get_tree().process_frame
	return null

func _shot(name: String) -> void:
	# process_always, damit auch im pausierten Spiel (Debugmenü) aufgenommen wird
	await get_tree().create_timer(0.2, true).timeout
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
		print("BILD %s  %dx%d" % [name, img.get_width(), img.get_height()])
	else:
		print("BILD_FEHLER %s err=%d" % [name, err])
