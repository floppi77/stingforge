extends Node
## Prüfwerkzeug: Screenshot des Hauptmenüs in den docs-Ordner.
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var app := get_tree().root.get_node_or_null("App")
	if app == null:
		print("NO_APP")
		get_tree().quit(1)
		return
	app.menu_main()
	await get_tree().create_timer(0.9).timeout
	RenderingServer.force_draw(true)
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://docs/menu_neu.png")
	print("MENU_SHOT %s" % str(img.get_size()))
	get_tree().quit(0)
