extends Node
## R4: Bosse bewegen sich ohne Zittern und Teleportsprünge, bleiben im Feld und
## greifen an. Je Boss 25 s Kampf im Zeitraffer, Biene unverwundbar.
var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, true, false, true).timeout
	var only := OS.get_cmdline_user_args()
	for level in range(1, 11):
		if only.is_empty() or only.has(str(level)):
			await _boss(level)
	Engine.time_scale = 1.0
	for f in fails:
		print("R4_BOSS_FEHLER: " + f)
	print("R4_BOSS_OK" if fails.is_empty() else "R4_BOSS_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _boss(level: int) -> void:
	Engine.time_scale = 1.0
	Save.new_campaign("normal", 6100 + level)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await get_tree().create_timer(0.5, true, false, true).timeout
	var g = app.game
	g.player.max_hp = 999
	g.player.hp = 999
	g.player.iframes = 1.0e6
	g.director.start_boss_now()
	for i in range(40):
		await get_tree().create_timer(0.1, true, false, true).timeout
		if g.boss != null and is_instance_valid(g.boss):
			break
	await get_tree().create_timer(0.4, true, false, true).timeout
	var b = g.boss
	if b == null:
		fails.append("Level %d: kein Boss" % level)
		return
	b.hp = 1.0e9
	b.max_hp = 1.0e9
	Engine.time_scale = 3.0
	var last: Vector2 = b.position
	var last_step := Vector2.ZERO
	var shiver := 0
	var jerks := 0
	var jumps := 0
	var outside := 0
	var frames := 0
	var bullets_seen := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8400:
		await get_tree().physics_frame
		if not is_instance_valid(b) or b.dead:
			break
		frames += 1
		var step: Vector2 = b.position - last
		# Außerhalb des Bildes (Erntemaschinen-Flanke) zählt kein Versatz als Sprung.
		var on_screen: bool = last.x > -40.0 and last.x < 1000.0 and b.position.x > -40.0 and b.position.x < 1000.0
		var visible: bool = not b.submerged and b.position.y < App.PLAY_BOTTOM + 40.0 and on_screen
		# Zittern: winzige Hin-und-her-Schritte in y oder x direkt hintereinander.
		for axis in [0, 1]:
			var a: float = step[axis]
			var p: float = last_step[axis]
			if absf(a) > 0.05 and absf(p) > 0.05 and signf(a) != signf(p) and absf(a) < 2.0 and absf(p) < 2.0:
				shiver += 1
			# Ruckler: harte Richtungsumkehr mit großen Schritten (Hin-und-her-Zerren).
			# In Echtzeit gemessen: der Zeitraffer vergrößert jeden Schritt.
			var lim := 2.0 * Engine.time_scale
			if visible and absf(a) >= lim and absf(p) >= lim and signf(a) != signf(p):
				jerks += 1
				if OS.get_environment("R4_BOSS_DEBUG") != "":
					print("    JERK axis=%d a=%.1f p=%.1f motion=%s style=%s phase=%d" % [axis, a, p, str(b.motion.get("curve", "-")), b.move_style, b.phase])
		if visible and step.length() > 40.0 * Engine.time_scale:
			jumps += 1
		if visible and not b.submerged:
			var bounds: Rect2 = b._stable_bounds()
			if b.position.y + bounds.position.y < App.PLAY_TOP - 4.0 or b.position.y + bounds.end.y > App.PLAY_BOTTOM + 4.0:
				outside += 1
		bullets_seen = maxi(bullets_seen, g.bullets.enemy_bullets.size() if "enemy_bullets" in g.bullets else 0)
		last_step = step
		last = b.position
	Engine.time_scale = 1.0
	var rate := float(shiver) / maxf(1.0, float(frames))
	var ok: bool = frames > 100 and rate < 0.03 and jerks == 0 and jumps == 0 and outside == 0
	print(("  OK   " if ok else "  FAIL ") + "Level %d %s: %d Bilder, Zittern %.1f %%, Ruckler %d, Sprünge %d, außerhalb %d, Geschosse max %d" % [
		level, b.id, frames, rate * 100.0, jerks, jumps, outside, bullets_seen])
	if not ok:
		fails.append("Level %d: Bossbewegung unsauber" % level)
	app.menu_main()
	await get_tree().create_timer(0.2, true, false, true).timeout
