extends Node2D
## Reale Godot-Zeichenprobe, benötigt einen Render-Displaytreiber (nicht Dummy).
## Keine Bildimporte; Ausgabe bleibt im isolierten Spieler-Testverzeichnis.
var mode := "campaign"
var examples: Array[Player] = []

func _ready() -> void:
	App.clear_screens()
	App.root_ctrl.hide()
	App.ui_layer.hide()
	get_window().size = Vector2i(960, 540)
	RenderingServer.set_default_clear_color(Color("101e25"))
	for row in range(2):
		for charges in range(4):
			var bee := Player.new()
			add_child(bee)
			bee.set_physics_process(false)
			bee.setup({"upgrades": {"shield": charges}})
			bee.position = Vector2(120 + charges * 240, 175 + row * 235)
			bee.sprite.stop()
			bee.engine_fx.emitting = false
			bee.aura.set_status(charges, row == 1)
			examples.append(bee)
	queue_redraw()
	for i in range(8):
		await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("STINGFORGE_R2_PLAYER_VISUAL_NEEDS_RENDER_DISPLAY")
		get_tree().quit(2)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://build/stingforge-r2-testdata-player/shield-rings.png"
	var status := image.save_png(path)
	print("STINGFORGE_R2_PLAYER_VISUAL_OK" if status == OK else "STINGFORGE_R2_PLAYER_VISUAL_FAILED")
	print(ProjectSettings.globalize_path(path))
	for bee in examples:
		bee.free()
	get_tree().quit(0 if status == OK else 1)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(28, 38), "Schildladungen: exakt 0 / 1 / 2 / 3", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e7f4ee"))
	draw_string(font, Vector2(28, 67), "Oben: Mint/Gold mit Glanz   |   Unten: reduzierte Effekte, gleicher Status", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9bb5b0"))
	for row in range(2):
		for charges in range(4):
			var x := 120.0 + charges * 240.0
			var y := 175.0 + row * 235.0
			draw_line(Vector2(x - 100, y + 80), Vector2(x + 100, y + 80), Color("2f4a4f"), 1.0)
			draw_string(font, Vector2(x - 42, y + 109), "%d Ladung%s" % [charges, "" if charges == 1 else "en"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dae9e3"))
