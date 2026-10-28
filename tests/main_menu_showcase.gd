extends Node
## Bildbeleg mit derselben Datensituation wie im Layoutentwurf, getrennte Testdaten.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.4, true).timeout
	var app := get_node("/root/App")
	Save.new_campaign("relaxed", 20261027)
	Save.campaign.level = 1
	Save.campaign.points = 8146
	Save.profile.unlocked_evolutions = []
	for i in range(4): Save.profile.unlocked_evolutions.append(String(Data.EVOLUTIONS[i].id))
	Save.profile.boss_rush_unlocked = false
	Save.profile.best = {}
	app.menu_main()
	await get_tree().create_timer(0.7, true).timeout
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var err := get_viewport().get_texture().get_image().save_png("res://docs/ui-reference/showcase.png")
	print("MENU_SHOWCASE_OK" if err == OK else "MENU_SHOWCASE_FAILED")
	app.clear_screens()
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	for i in range(8): await get_tree().process_frame
	get_tree().quit(0 if err == OK else 1)
