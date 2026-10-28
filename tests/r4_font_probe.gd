extends Control
## Schriftvergleich: Größen × Glättung, als Bild nach build/r4-fonts.png.
const SAMPLE := "Bildrate Zurück Grafik Übersicht 0123456789 ÄÖÜß"
func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	var app := get_node("/root/App")
	app.ui_layer.visible = false
	app.root_ctrl.visible = false
	app.overlay_layer.visible = false
	RenderingServer.set_default_clear_color(Color("#0b0a18"))
	var y := 10
	for spec in [["res://assets/ui/fonts/pixel/PixelifySans.ttf", [20, 22, 24, 26, 28, 32, 36], [400, 500]],
			["res://assets/ui/fonts/pixel/Silkscreen-Regular.ttf", [16, 24, 32], [-1]],
			["res://assets/ui/fonts/pixel/Jersey10-Regular.ttf", [28, 37, 42, 56, 75], [-1]]]:
		for aa in [TextServer.FONT_ANTIALIASING_NONE, TextServer.FONT_ANTIALIASING_GRAY]:
			for w in spec[2]:
				for px in spec[1]:
					var ff: FontFile = load(spec[0]).duplicate()
					ff.antialiasing = aa
					ff.hinting = TextServer.HINTING_NONE
					ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
					var fv := FontVariation.new()
					fv.base_font = ff
					fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
					if w > 0:
						fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(w)}
					var l := Label.new()
					l.text = "%s %d %s w%d  %s" % [spec[0].get_file().left(6), px, "AA" if aa else "--", w, SAMPLE]
					l.add_theme_font_override("font", fv)
					l.add_theme_font_size_override("font_size", px)
					l.position = Vector2(10 if y < 1060 else 970, y % 1060)
					add_child(l)
					y += px + 4
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/r4-fonts.png"))
	get_tree().quit()
