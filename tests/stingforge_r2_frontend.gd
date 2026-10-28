extends Node
## Ausschließlich isolierte Bild-Testdaten; kein echter Spielstand wird gelesen/geändert.
var checks := 0
var failures := 0
var app: Node
const OUT := "res://build/stingforge-r2-frontend/"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FRONTEND: " + message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_user_data_dir().contains("stingforge-r2-testdata-frontend"):
		push_error("Isolierte Frontend-Testdaten fehlen")
		get_tree().quit(2)
		return
	app = get_node("/root/App")
	for connection in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(connection.callable)
	Save.profile = Save._default_profile()
	Save.profile.unlocked = 10
	Save.campaign = {}
	Save.active_campaign = false
	Save.set_g("access.font_scale", 1.0)
	Save.set_g("display.ui_size", 100)
	for i in range(25):
		check(Save.record_highscore({"run_id": "r2-frontend-fixture-%d" % i,
			"mode": "campaign", "difficulty": ["relaxed", "normal", "expert"][i % 3],
			"score": (25 - i) * 75241, "level": 10 if i % 3 == 0 else 1 + i % 9,
			"completed": i % 3 == 0, "pilot": "Yuri", "seed": 271009 + i}), "Testeintrag gespeichert")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	app.fade.color.a = 0.0
	app.post_rect.visible = false
	app.menu_note = "R2-Bildprüfung · isolierte Testdaten"
	app.menu_main()
	await get_tree().create_timer(0.35, true).timeout
	var menu = app.screens[-1]
	check(menu.items.size() == 10, "Zehn Hauptmenüaktionen (mit Tutorial und Verschmelzungen, ohne Werkstatt)")
	await shot("main_menu.png")
	var index := -1
	for i in range(menu.items.size()):
		if menu.items[i].get("id", "") == "scores": index = i
	check(index >= 0, "Highscore-Aktion vorhanden")
	menu.on_activate(index)
	await get_tree().create_timer(0.35, true).timeout
	var screen = app.screens[-1]
	check(screen.get_script().resource_path.ends_with("highscore_screen.gd"), "Echte Ranglistenroute")
	screen.hint_override = "Bildprüfung · isolierte Testdaten, keine persönlichen Highscores"
	check(screen.scores.size() == 10, "Top10 dargestellt")
	await shot("highscores_top10_testdaten.png")
	screen.on_adjust(2, 1)
	screen.hint_override = "Bildprüfung · isolierte Testdaten, keine persönlichen Highscores"
	check(screen.scores.size() == 20, "Top20 dargestellt")
	await shot("highscores_top20_testdaten.png")
	Save.set_g("access.font_scale", 1.6)
	screen.refresh()
	await get_tree().create_timer(0.12, true).timeout
	await shot("highscores_160_testdaten.png")
	screen.do_back()
	check(app.screens[-1] == menu, "Zurück zum selben Hauptmenü")
	Save.set_g("access.font_scale", 1.0)
	app.clear_screens()
	await get_tree().process_frame
	print("STINGFORGE_R2_FRONTEND checks=%d failures=%d" % [checks, failures])
	print("STINGFORGE_R2_FRONTEND_OK" if failures == 0 else "STINGFORGE_R2_FRONTEND_FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(not image.is_empty(), "Nativer Framebuffer: " + name)
	check(image.save_png(OUT + name) == OK, "PNG geschrieben: " + name)
