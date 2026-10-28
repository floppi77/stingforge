extends Node
## Messwerkzeug: wie viele Punkte bringt ein komplettes Level (bis zum Boss)?

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.4, false).timeout
	for lv in [1, 3, 6]:
		app.clear_screens()
		if Save.campaign.is_empty():
			Save.new_campaign("normal", 12345)
		Save.campaign.level = lv
		Save.campaign.points = 0
		app._begin_level(lv, 0)
		for i in range(400):
			if app.game != null and is_instance_valid(app.game):
				break
			await get_tree().process_frame
		var g = app.game
		g.player.autofire = true
		Engine.time_scale = 5.0
		var guard := 0
		while not g.level_over and guard < 4000:
			guard += 1
			g.player.iframes = 99999.0
			g.player.hp = g.player.max_hp
			await get_tree().process_frame
		Engine.time_scale = 1.0
		print("INCOME level=%d spielzeit=%.0fs punkte=%d kills=%d boss=%d" % [lv,
			float(g.stats.time), g.player.points, g.stats.kills, g.stats.bosses])
	print("INCOME_OK")
	get_tree().quit(0)
