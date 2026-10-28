extends Node
## Bilder der sechsten Runde: neue Werkstatt-Beschreibungen und die Leiste nach
## einem Game Over.

var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, true).timeout
	Save.new_campaign("normal", 567812)
	Save.campaign.points = 40000
	Save.campaign.shop = {"back": 2}
	Save.save_campaign()
	app.clear_screens()
	app.push_screen("res://scripts/screens/shop_screen.gd", {"level": 3}, 0.0)
	await get_tree().create_timer(0.5, true).timeout
	var shop = app.screens[0]
	# zur Zeile Heckstachel springen
	for i in range(shop.items.size()):
		if String((shop.items[i] as Dictionary).get("id", "")) == "back":
			shop.focus = i
			shop.refresh()
			break
	await get_tree().create_timer(0.4, true).timeout
	await _shot("docs/r6_01_werkstatt_wucht.png")
	app.clear_screens()
	# Leiste nach dem Weiter: taktische Upgrades zurückgesetzt
	app._begin_level(2, 0)
	for i in range(16):
		await get_tree().process_frame
	var g = app.game
	g.player.upgrades = {"base": 3, "fan": 2, "lightning": 0, "plasma": 0, "companion": 1,
		"bombs": 1, "shield": 1, "speed": 1}
	g.player.weapon = "fan"
	g.player.nectar = 30
	await get_tree().create_timer(0.4, true).timeout
	await _shot("docs/r6_02_leiste_vorher.png")
	app.continue_after_death()
	await get_tree().create_timer(1.2, true).timeout
	await _shot("docs/r6_03_leiste_nachher.png")
	print("R6BILDER_OK")
	get_tree().quit(0)

func _shot(path: String) -> void:
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://" + path))
	print("Bild: " + path)
