extends Node
## Belege für die neuen Schriften: Hauptmenü, Werkstatt und Spielbild.

var count := 0
var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.4, false).timeout
	Save.new_campaign("normal", 515242)
	app.clear_screens()
	app.push_screen("res://scripts/screens/main_menu.gd")
	await _shot("font_01_hauptmenue")
	app.clear_screens()
	Save.campaign.points = 26000
	Save.campaign.shop = {}
	app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 3})
	await _shot("font_02_werkstatt")
	app.clear_screens()
	await get_tree().create_timer(0.2, false).timeout
	print("FONTBILDER %d" % count)
	print("FONTBILDER_OK" if count >= 2 else "FONTBILDER_FAILED")
	get_tree().quit(0 if count >= 2 else 1)

func _shot(name: String) -> void:
	await get_tree().create_timer(0.5, true).timeout
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % name))
	if err == OK:
		count += 1
		print("BILD %s  %dx%d" % [name, img.get_width(), img.get_height()])
