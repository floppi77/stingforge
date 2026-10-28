extends Node
## Misst die tatsächliche Bildrate im laufenden Spiel (Lastsituation: Level 5 im
## Bosskampf mit Dauerfeuer) und gibt die Kennzahlen aus.

var frames: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	# Nur im Messfenster: Fokusübergaben dürfen keine Pause als hohe FPS ausgeben.
	for connection in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(connection.callable)
	await get_tree().create_timer(0.4, false).timeout
	# Reproduzierbarer isolierter Build statt zufälliger Vorher-Testdaten.
	Save.new_campaign("normal", 761432)
	# Messfenster: 1920 × 1080, wie im Bericht angegeben
	get_window().size = Vector2i(1920, 1080)
	await get_tree().create_timer(0.6, false).timeout
	print("PERF modus vsync=%s cap=%s" % [str(Save.g("display.vsync", true)),
		str(Save.g("display.fps_cap", 0))])
	# --maxed: alle Werkstatt-Upgrades auf Stufe 3 (härteste Last)
	if "--maxed" in OS.get_cmdline_user_args():
		var full: Dictionary = {}
		for it in ShopData.ITEMS:
			full[String(it.id)] = 3
		Save.campaign.shop = full
		Save.campaign.upgrades = {"fan": 3, "plasma": 3, "companion": 3, "shield": 3, "bombs": 3}
		Save.campaign.weapon = "fan"
	app.clear_screens()
	app.mode = "campaign"
	app._begin_level(5, 0)
	for i in range(600):
		if app.game != null and is_instance_valid(app.game):
			break
		await get_tree().process_frame
	var g = app.game
	# Auch die Lastmessung darf nicht nach frühem Game Over bloß ein Menü messen.
	g.player.iframes = 9999.0
	g.player.autofire = true
	await get_tree().create_timer(1.0, false).timeout
	g.director.start_boss_now()
	await get_tree().create_timer(1.5, false).timeout
	# Zusatzlast: viele Gegner und Geschosse gleichzeitig
	if "--stress" in OS.get_cmdline_user_args():
		for i in range(16):
			g._on_spawn_enemy("moth", Vector2(700 + (i % 4) * 60, 90 + (i / 4) * 100), {})
		for i in range(160):
			var a := TAU * float(i) / 160.0
			g.spawn_enemy_bullet(Vector2(700, 270), Vector2(cos(a), sin(a)) * 120.0, 1, "ebullet_orb")
	frames.clear()
	var peak_bullets := 0
	var peak_enemies := 0
	var inactive_frames := 0
	var t_end := Time.get_ticks_msec() + 10000
	var t_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		if not is_instance_valid(g):
			inactive_frames += 1
			break
		if get_tree().paused or g.is_play_frozen():
			inactive_frames += 1
		frames.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		peak_bullets = maxi(peak_bullets, g.bullets.player_bullets.size() + g.bullets.enemy_bullets.size())
		peak_enemies = maxi(peak_enemies, g.enemies.size())
	var dur := float(Time.get_ticks_msec() - t_start) / 1000.0
	frames.sort()
	var n := frames.size()
	var sum := 0.0
	for f in frames:
		sum += float(f)
	var avg := sum / maxf(1.0, float(n))
	var p50: float = float(frames[int(n * 0.5)]) if n > 1 else 0.0
	var p95: float = float(frames[int(n * 0.95)]) if n > 1 else 0.0
	var worst: float = float(frames[n - 1]) if n > 0 else 0.0
	print("PERF renderer=", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_api_version())
	print("PERF fenster=", get_window().size, " bilder=%d dauer=%.2fs -> %.1f fps" % [n, dur, float(n) / maxf(0.001, dur)])
	print("PERF prozessframe ms: avg=%.2f p50=%.2f p95=%.2f max=%.2f" % [avg, p50, p95, worst])
	print("PERF spitze: geschosse=%d gegner=%d objekte=%d" % [peak_bullets, peak_enemies, Performance.get_monitor(Performance.OBJECT_COUNT)])
	print("PERF draw calls=%d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("PERF inaktive_frames=%d" % inactive_frames)
	var valid: bool = inactive_frames == 0 and n > 0 and peak_enemies > 0 and peak_bullets > 0
	print("PERF_MESSUNG_OK" if valid else "PERF_MESSUNG_FAILED")
	get_tree().quit(0 if valid else 1)
