extends Node
## Belegbilder der fünften Runde: Geschosse gegen Blütenstaub, Sperrliste in der
## Werkstatt und der Boss im Übergang.

var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Save.new_campaign("normal", 424242)
	Save.campaign.upgrades = {"base": 3}
	# ---------------------------------------------------- 1) Geschosse und Nektar
	app.clear_screens()
	app._begin_level(4, 0)
	for i in range(70):
		await get_tree().process_frame
	var g = app.game
	g.player.autofire = true
	for i in range(30):
		await get_tree().physics_frame
	# Nektarblüten von Hand setzen, damit sie neben den Schüssen im Bild sind.
	for k in range(4):
		var pk = Pickup.new()
		g.add_child(pk)
		pk.setup("nectar", Vector2(560 + k * 90, 150 + k * 80))
	for i in range(14):
		await get_tree().physics_frame
	await _shot("docs/r5_01_geschosse_nektar.png")
	# ------------------------------------------------------- 2) Werkstatt-Sperre
	await _stop_level()
	Save.campaign.points = 90000
	Save.campaign.shop = {"orbit": 1}
	Save.save_campaign()
	app.clear_screens()
	app.push_screen("res://scripts/screens/shop_screen.gd", {"level": 1}, 0.0)
	for i in range(25):
		await get_tree().process_frame
	var shop = app.screens[app.screens.size() - 1]
	# Fokus auf "Wellenschuss" schieben, damit dessen Sperrliste zu sehen ist
	for i in range(80):
		await get_tree().process_frame
		var items: Array = shop.items
		var row: Dictionary = items[int(shop.focus)] if int(shop.focus) < items.size() else {}
		if String(row.get("id", "")) == "wave":
			break
		shop._move_focus(1)
	for i in range(25):
		await get_tree().process_frame
	await _shot("docs/r5_02_werkstatt_sperre.png")
	# ------------------------------------------------------------ 3) Boss-Phase
	Save.new_campaign("normal", 555222)
	Save.campaign.upgrades = {"base": 3}
	app.clear_screens()
	app._begin_level(3, 0)
	for i in range(14):
		await get_tree().process_frame
	var g2 = app.game
	g2.director.start_boss_now()
	for i in range(260):
		await get_tree().physics_frame
	if g2.boss != null:
		g2.boss.hp = g2.boss.max_hp * 0.62
		g2.boss.take_damage(g2.boss.max_hp * 0.1)
	for i in range(50):
		await get_tree().physics_frame
	await _shot("docs/r5_03_boss_uebergang.png")
	print("R5BILDER_OK")
	get_tree().quit(0)

func _stop_level() -> void:
	if app.game != null and is_instance_valid(app.game):
		app.clear_screens()
	for i in range(5):
		await get_tree().process_frame

func _shot(path: String) -> void:
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://" + path))
	print("Bild: " + path)
