extends Node
## Prüfwerkzeug: Bild der Anzeige-Einstellungen (auch im großen Fenster).
func _ready() -> void:
	await get_tree().process_frame
	var app := get_tree().root.get_node_or_null("App")
	await get_tree().create_timer(0.8).timeout
	app.clear_screens()
	app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
	await get_tree().create_timer(0.8).timeout
	var s: Control = app.screens[-1]
	# eine Auflösung vormerken, damit Markierung und Übernehmen-Zeile zu sehen sind
	s._adjust_choice("resolution", 1)
	s._rebuild_keep_focus()
	print("vorgemerkt=%s anzeige=%s" % [str(s.staged), str(s.items[1].get("value_text", ""))])
	await get_tree().create_timer(0.4).timeout
	RenderingServer.force_draw(true)
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://docs/display_01_einstellungen.png")
	print("SET_SHOT fenster=%s bild=%s" % [str(get_window().size), str(img.get_size())])
	# großes Fenster: gleiche Anordnung, nur größer dargestellt
	get_window().size = Vector2i(2730, 1536)
	await get_tree().create_timer(0.7).timeout
	RenderingServer.force_draw(true)
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("res://docs/display_02_grosses_fenster.png")
	print("SET_SHOT_GROSS fenster=%s bild=%s" % [str(get_window().size), str(img2.get_size())])
	# zurück auf 1600 × 900, dann die Rückfrage beim Übernehmen zeigen
	get_window().size = Vector2i(1600, 900)
	await get_tree().create_timer(0.5).timeout
	s.apply_staged_display()
	await get_tree().create_timer(0.7).timeout
	RenderingServer.force_draw(true)
	var img3 := get_viewport().get_texture().get_image()
	img3.save_png("res://docs/display_03_rueckfrage.png")
	print("SET_SHOT_FRAGE bild=%s titel=%s" % [str(img3.get_size()),
		str((app._display_confirm.title_label as Label).text)])
	app.revert_display_now()
	get_tree().quit(0)
