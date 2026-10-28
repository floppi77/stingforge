extends Node
## Prüfwerkzeug: Bild der Nektar-Umrechnung am Levelende.
func _ready() -> void:
	await get_tree().process_frame
	var app := get_tree().root.get_node_or_null("App")
	await get_tree().create_timer(0.8).timeout
	Save.campaign.nectar = 128
	app.push_screen("res://scripts/screens/nectar_convert_screen.gd", {"nectar": 128})
	await get_tree().create_timer(0.8).timeout
	RenderingServer.force_draw(true)
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://docs/conv_01_umrechnung.png")
	print("CONV_SHOT_1 %s" % str(img.get_size()))
	await get_tree().create_timer(1.1).timeout
	RenderingServer.force_draw(true)
	get_viewport().get_texture().get_image().save_png("res://docs/conv_02_gutschrift.png")
	print("CONV_SHOT_2")
	get_tree().quit(0)
