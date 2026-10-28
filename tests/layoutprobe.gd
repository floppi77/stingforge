extends Node
## Prüfwerkzeug: passen die Bildschirme ohne Scrollen in die Zeichenfläche?

const SCREENS := [
	["Hauptmenü", "res://scripts/screens/main_menu.gd", {}],
	["Einstellungen", "res://scripts/screens/settings_screen.gd", {"from": "main"}],
	["Credits", "res://scripts/screens/credits_screen.gd", {}],
]

func _ready() -> void:
	await get_tree().process_frame
	var app := get_tree().root.get_node_or_null("App")
	await get_tree().create_timer(0.8).timeout
	for e in SCREENS:
		app.clear_screens()
		app.push_screen(String(e[1]), e[2])
		await get_tree().create_timer(0.5).timeout
		var s: Control = app.screens[-1]
		var need: float = (s.list_box as Control).get_combined_minimum_size().y
		var have: float = (s.scroll_container as Control).size.y
		var clips := 0
		for r in s.list_box.get_children():
			var lbl: Variant = r.get_meta("label") if r.has_meta("label") else null
			if lbl is Label and (lbl as Label).get_minimum_size().x > (lbl as Label).size.x + 0.5:
				clips += 1
		print("LAYOUT %-14s Zeilen=%d Inhalt=%.0f Platz=%.0f %s%s" % [e[0],
			s.items.size(), need, have, ("SCROLL" if need > have else "passt"),
			(" beschnitten=%d" % clips) if clips > 0 else ""])
		if String(e[0]) == "Hauptmenü":
			var parts: Array[String] = []
			for r in s.list_box.get_children():
				parts.append("%.0f" % (r as Control).get_combined_minimum_size().y)
			print("  Zeilenhoehen: %s" % ", ".join(parts))
			print("  Trennung=%d Kopf=%.0f Fuss=%.0f" % [
				(s.list_box as Control).get_theme_constant("separation"),
				((s.title_label.get_parent()) as Control).size.y,
				(s.hint_label as Control).size.y])
	# Einstellungen: alle Reiter, einmal mit vorgemerkter Auflösung
	app.clear_screens()
	app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
	await get_tree().create_timer(0.5).timeout
	var st: Control = app.screens[-1]
	for t in range(6):
		st.tab = t
		st._rebuild_keep_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		print("TAB %d Inhalt=%.0f Platz=%.0f" % [t,
			(st.list_box as Control).get_combined_minimum_size().y,
			(st.scroll_container as Control).size.y])
	st.tab = 0
	st._adjust_choice("resolution", 1)
	st._rebuild_keep_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	print("TAB 0 mit Vormerkung Inhalt=%.0f Platz=%.0f" % [
		(st.list_box as Control).get_combined_minimum_size().y,
		(st.scroll_container as Control).size.y])

	# Gitter (Evolutionswahl) prüfen
	app.clear_screens()
	app.push_screen("res://scripts/screens/evolution_screen.gd", {"offers": [
		{"id": "sting_a"}, {"id": "guard_a"}, {"id": "power_a"}], "level": 3})
	await get_tree().create_timer(0.6).timeout
	var ev: Control = app.screens[-1]
	print("LAYOUT Evolutionswahl Inhalt=%.0f Platz=%.0f" % [
		(ev.grid_wrap as Control).get_combined_minimum_size().y, (ev.grid_wrap as Control).size.y])
	print("LAYOUT_OK")
	get_tree().quit(0)
