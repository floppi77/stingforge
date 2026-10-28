extends Node
## Prüft den Parallax-Hintergrund: Anzahl Ebenen, unterschiedliche Geschwindigkeit,
## Bewegung im laufenden Spiel und ein Belegbild.

var fails: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Save.new_campaign("normal", 909011)
	app.clear_screens()
	app._begin_level(2, 0)
	for i in range(20):
		await get_tree().process_frame
	var g = app.game
	if g == null:
		print("BG_FAILED: kein Level")
		get_tree().quit(1)
		return
	var bg = g.background
	if bg == null or bg.layers.is_empty():
		fails.append("keine Hintergrundebenen")
	else:
		var spec_count: int = bg.LAYER_SPECS.size()
		if bg.layers.size() < spec_count * 2:
			fails.append("zu wenige Ebenenkopien: %d" % bg.layers.size())
		# Geschwindigkeiten müssen sich unterscheiden
		var speeds := {}
		for s in bg.LAYER_SPECS:
			speeds[float(s.speed)] = true
		if speeds.size() < 4:
			fails.append("Ebenen laufen nicht unterschiedlich schnell (%d Stufen)" % speeds.size())
		# Bewegung messen
		var first := bg.layers[0].node as Sprite2D
		var x0 := first.position.x
		var front := bg.layers[bg.layers.size() - 1].node as Sprite2D
		var f0 := front.position.x
		for i in range(30):
			await get_tree().physics_frame
		var moved_far: float = absf(first.position.x - x0)
		var moved_front: float = absf(front.position.x - f0)
		if moved_far < 1.0 and moved_front < 1.0:
			fails.append("Hintergrund bewegt sich nicht")
		if moved_front <= moved_far:
			fails.append("Vordergrund läuft nicht schneller als die Ferne (%.1f gegen %.1f)"
				% [moved_front, moved_far])
		print("BG: %d Ebenen, Ferne %.1f px, Vordergrund %.1f px in 0,5 s"
			% [bg.layers.size(), moved_far, moved_front])
	# Belegbild
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/bg_01_parallax.png"))
	for f in fails:
		print("BG_FEHLER: " + String(f))
	print("BG_OK" if fails.is_empty() else "BG_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)
