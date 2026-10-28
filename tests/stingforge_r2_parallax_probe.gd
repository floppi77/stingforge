extends Node
## R2 public seam: Background.setup/update -> on-screen sprites and imported alpha.
const OUT := "res://build/stingforge-r2-parallax/"
var failures: Array[String] = []
var checks := 0
var rows: Array = []
var render_enabled := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	render_enabled = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().process_frame
	App.clear_screens()
	# Autoload-Menümusik ist für diese isolierte Grafikprobe nicht erforderlich.
	_stop_probe_audio()
	await get_tree().create_timer(0.05, true).timeout
	Save.settings.graphics.particles = 0.0
	var levels: Array = range(1, 11)
	if "--parallax-properties-only" in OS.get_cmdline_user_args():
		levels = []
	for n in levels:
		var bg := Background.new()
		App.viewport.add_child(bg)
		bg.setup(Data.level(n))
		bg.update(0.0, 78.0)
		_check(bg.LAYER_SPECS.size() == 8, "L%02d: acht echte Tiefenebenen" % n)
		var seen := {}
		for l in bg.layers:
			var s: Sprite2D = l.node
			_check(s.z_index < 0, "L%02d: Hintergrund bleibt hinter Geschossen" % n)
			if int(l.copy) == 0:
				seen[float(l.spec.speed)] = true
		_check(seen.size() == 8, "L%02d: acht unterschiedliche Geschwindigkeiten" % n)
		_check_imports(bg, n)
		var times: Array = [0.0, 0.001, 1.0, 2.526315789, 7.9, 13.1, 35.0, 10000.125]
		for l in bg.layers:
			if int(l.copy) == 0:
				var seam := float(l.span) / float(l.spec.speed)
				times.append_array([seam - 0.00001, seam, seam + 0.00001])
		for t in times:
			bg.scroll = t
			bg.update(0.0, 78.0)
			_check_ground(bg, n, t)
			_check_coverage(bg, n, t)
		_check_delta(bg, n)
		if render_enabled:
			for t in [0.0, 2.526315789, 13.1]:
				bg.scroll = t
				bg.update(0.0, 78.0)
				await _capture("l%02d_t%07.3f" % [n, t])
		bg.free()
	_check_fallbacks()
	_check_properties()
	if render_enabled:
		await _capture_integrated()
	_stop_probe_audio()
	await get_tree().create_timer(0.05, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	_write_report()
	for failure in failures:
		print("PARALLAX_RUNTIME_FAIL: ", failure)
	print("STINGFORGE_R2_PARALLAX_OK" if failures.is_empty() else "STINGFORGE_R2_PARALLAX_FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

func _stop_probe_audio() -> void:
	# Testhost-Cleanup: Dummy-Audio braucht keinen Ogg-Decoder am Prozessende.
	# Keine Änderung am Audio-Autoload oder seinen Produktionsdateien.
	Audio.stop_music(0.0)
	for node in Audio.get_children():
		if node is AudioStreamPlayer:
			node.stop()
			node.stream = null

func _check_ground(bg: Background, level: int, t: float) -> void:
	for l in bg.layers:
		var suffix := String(l.spec.get("suffix", ""))
		var asset := String(l.spec.get("asset", ""))
		if suffix not in ["near", "reeds", "roots"] and asset != "bg_front":
			continue
		var s: Sprite2D = l.node
		if int(l.copy) != 0:
			continue
		var image := s.texture.get_image()
		var world_y := App.PLAY_BOTTOM - 1.0
		var local_y := int(floor((world_y - s.position.y) / s.scale.y))
		var missing := 0
		for x in range(960):
			var local_x := posmod(int(floor((float(x) - s.position.x) / s.scale.x)), image.get_width())
			if local_y < 0 or local_y >= image.get_height() or image.get_pixel(local_x, local_y).a < 0.1:
				missing += 1
		_check(missing == 0, "L%02d %s%s t=%.5f: Bodenzeile ohne Loch (%d)" % [level, suffix, asset, t, missing])
		rows.append({"level": level, "layer": suffix + asset, "t": t, "missing": missing, "node_y": s.position.y})

func _check_imports(bg: Background, level: int) -> void:
	for l in bg.layers:
		if int(l.copy) != 0:
			continue
		var suffix := String(l.spec.get("suffix", ""))
		if suffix not in ["haze", "reeds", "roots", "near"]:
			continue
		var path := "res://assets/bg/l%02d_%s.png" % [level, suffix]
		_check(l.node.texture.resource_path == path, "L%02d %s: echter importierter PNG statt Fallback" % [level, suffix])
		var source := Image.new()
		source.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		var imported: Image = l.node.texture.get_image()
		var different := 0
		if source.get_size() == imported.get_size():
			# Alpha + sichtbare Farbe; Godot darf RGB transparenter Ränder verändern.
			for y in range(source.get_height()):
				for x in range(source.get_width()):
					var a := source.get_pixel(x, y)
					var b := imported.get_pixel(x, y)
					if absf(a.a - b.a) > 0.01 or (a.a > 0.1 and maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))) > 0.015):
						different += 1
		else:
			different = -1
		_check(different == 0, "L%02d %s: Import entspricht PNG (%d Pixelabweichungen)" % [level, suffix, different])

func _check_coverage(bg: Background, level: int, t: float) -> void:
	for first in bg.layers:
		if int(first.copy) != 0:
			continue
		var right := 0.0
		for l in bg.layers:
			if l.spec != first.spec:
				continue
			var s: Sprite2D = l.node
			_check(s.position.x <= right + 0.001, "L%02d t%.5f: keine Kachellücke bei x%.2f" % [level, t, right])
			right = maxf(right, s.position.x + float(l.span))
		_check(right >= 960.0, "L%02d t%.5f: reale Spritekopien decken 960px ab" % [level, t])

func _check_delta(bg: Background, level: int) -> void:
	bg.scroll = 0.0
	bg.speed_bonus = 0.35
	bg.update(2.0, 117.0)
	var whole: Array = []
	for l in bg.layers:
		whole.append(l.node.position)
	bg.scroll = 0.0
	for i in range(240):
		bg.update(1.0 / 120.0, 117.0)
	for i in range(bg.layers.size()):
		_check(bg.layers[i].node.position.distance_to(whole[i]) < 0.002,
			"L%02d: delta-unabhängig 2s vs 240x1/120" % level)
	bg.speed_bonus = 0.0

func _check_fallbacks() -> void:
	var bg := Background.new()
	App.viewport.add_child(bg)
	var data := {"bg": "__missing_r2", "palette": {"sky": Color("#336699"), "dark": Color("#112233")}}
	bg.setup(data)
	var count := bg.get_child_count()
	bg.setup(data)
	_check(bg.get_child_count() == count, "setup zweimal: keine Ebenen-/Partikellecks")
	_check_ground(bg, 0, 0.0)
	_check_coverage(bg, 0, 0.0)
	for l in bg.layers:
		if int(l.copy) != 0:
			continue
		var suffix := String(l.spec.get("suffix", ""))
		if suffix == "far":
			_check(l.node.texture.get_image().get_pixel(480, 200).a == 1.0, "Fehlende Ferne: lesbarer opaker Himmel")
		elif suffix in ["haze", "mid", "reeds", "near", "roots"]:
			_check(l.node.texture.get_image().get_pixel(480, 200).a == 0.0, "Fallback deckt Spielkorridor nicht zu: " + suffix)
	bg.free()

func _check_properties() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--parallax-samples="):
			path = arg.trim_prefix("--parallax-samples=")
	if path.is_empty():
		return
	var samples: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(samples is Array, "Property-Samples lesbar")
	if not samples is Array:
		return
	for sample in samples:
		var bg := Background.new()
		App.viewport.add_child(bg)
		bg.setup(Data.level(int(sample.level)))
		bg.speed_bonus = float(sample.bonus)
		bg.scroll = float(sample.start)
		bg.update(float(sample.total), float(sample.speed))
		var whole: Array = []
		for l in bg.layers:
			whole.append(l.node.position)
		bg.scroll = float(sample.start)
		for delta in sample.parts:
			bg.update(float(delta), float(sample.speed))
		for i in range(bg.layers.size()):
			var distance: float = bg.layers[i].node.position.distance_to(whole[i])
			# The same point on a wrapping tile may be represented by x or x+span.
			var span := float(bg.layers[i].span)
			_check(minf(distance, absf(distance-span)) < 0.03, "Property delta-independent: " + str(sample))
		_check_ground(bg, int(sample.level), bg.scroll)
		_check_coverage(bg, int(sample.level), bg.scroll)
		bg.free()
	print("PARALLAX_PROPERTY_RUNTIME_CASES: ", samples.size())

func _capture_integrated() -> void:
	Save.new_campaign("normal", 272104)
	App._begin_level(1, 0)
	App.clear_screens()
	App.paused = false
	get_tree().paused = false
	var game = App.game
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.background.scroll = 13.1
	game.background.update(0.0, 78.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before := App.viewport.get_texture().get_image()
	# Echte BulletField-Kugel direkt vor dem sichtbaren Boden, kein Montagepunkt.
	game.bullets.spawn_enemy(Vector2(480, 464), Vector2.ZERO, 1, "ebullet_orb", {"r": 5.0, "rot": false})
	game.bullets.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after := App.viewport.get_texture().get_image()
	var changed := 0
	for y in range(448, 476):
		for x in range(464, 497):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	_check(changed >= 12, "Echte Kugel bleibt vor bodennahem Vordergrund sichtbar (%d Pixel)" % changed)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "integrated_l01.png"))
	Audio.stop_music(0.0)

func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := App.viewport.get_texture().get_image()
	_check(image != null and image.get_width() == 960, "Echtes 960px Rendering " + label)
	if image != null:
		image.save_png(ProjectSettings.globalize_path(OUT + label + ".png"))

func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)

func _write_report() -> void:
	var name := "runtime-window.json" if render_enabled else "runtime-headless.json"
	if "--parallax-properties-only" in OS.get_cmdline_user_args():
		name = "runtime-properties.json"
	var file := FileAccess.open(OUT + name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "rendered": render_enabled, "ground": rows}, "\t"))
