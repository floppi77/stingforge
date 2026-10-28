extends Node
## Prüft die am Spiel gemeldeten Korrekturen als Spielmechanik:
## Blitzkette, Upgrade-Rücksetzung, Bossmusik, Bossdarstellung, Spielbereich.

var fails: Array = []
var checks := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  OK   " + what)
	else:
		print("  FAIL " + what)
		fails.append(what)

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.2, false).timeout
	Save.new_campaign("normal", 424242)
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game(app)
	await get_tree().process_frame

	# --- Blitzkette: 66 % auf den Nachbarn, 33 % auf den Übernächsten
	var a = await _spawn_enemy(g, Vector2(600, 200), 400)
	var b = await _spawn_enemy(g, Vector2(600, 300), 400)
	var c = await _spawn_enemy(g, Vector2(600, 400), 400)
	if a == null or b == null or c == null:
		_ok(false, "Testgegner anlegen")
	else:
		var hp_a := float(a.hp)
		var hp_b := float(b.hp)
		var hp_c := float(c.hp)
		var dmg := 100.0
		g._lightning_chain(a.position, dmg, 2, [a.get_instance_id()], 160.0)
		await get_tree().process_frame
		var d_b := hp_b - float(b.hp)
		var d_c := hp_c - float(c.hp)
		print("  Blitzkette: Sprung1=%.1f (%.0f%%), Sprung2=%.1f (%.0f%%)" % [
			d_b, 100.0 * d_b / dmg, d_c, 100.0 * d_c / dmg])
		_ok(absf(d_b - dmg * 0.66) < 0.6, "Kettenblitz Sprung 1 macht 66 %")
		_ok(absf(d_c - dmg * 0.33) < 0.9, "Kettenblitz Sprung 2 macht 33 %")
		_ok(float(a.hp) == hp_a, "Ausgangsziel erhält keinen Zusatzschaden")
		_ok(g.fx.arcs.size() >= 2, "zwei Blitzbögen sichtbar (%d)" % g.fx.arcs.size())
	# Blitzwaffe trägt die Kette überhaupt in die Kugel
	var lvl_before := int(g.player.upgrades.get("lightning", 0))
	g.player.upgrades["lightning"] = 2
	g.player.weapon = "lightning"
	g.player._fire_volley()
	await get_tree().process_frame
	var lchain := 0
	for pb in g.bullets.player_bullets:
		lchain = maxi(lchain, int(pb.get("lchain", 0)))
	_ok(lchain >= 2, "Blitzkugel trägt Kettenstufen (lchain=%d)" % lchain)
	g.player.upgrades["lightning"] = lvl_before

	# --- Upgrade-Rücksetzung beim neuen Level
	app.mode = "campaign"
	Save.campaign.upgrades = {"base": 3, "fan": 2, "lightning": 1, "plasma": 0,
		"companion": 1, "bombs": 3, "shield": 2, "speed": 3, "repair": 1}
	Save.campaign.weapon = "fan"
	Save.campaign.speed_level = 3
	Save.campaign.shop = {"extra_shield": 2}
	Save.campaign.evolutions = [{"id": "chitin_bastion", "level": 1}]
	app.reset_upgrades_for_new_level()
	var up: Dictionary = Save.campaign.get("upgrades", {})
	print("  Upgrades nach Reset: ", str(up))
	_ok(int(up.get("base", 0)) == 1, "kostenlose BASIS1 bleibt verfügbar")
	for id in ["fan", "lightning", "plasma", "companion", "bombs", "shield", "speed", "repair"]:
		_ok(int(up.get(id, -1)) == 0, "taktischer Kauf nach Levelabschluss exakt 0: " + id)
	_ok(Save.campaign.weapon == "base" and int(Save.campaign.speed_level) == 0,
		"Ausrüstung auf Basis und Tempo auf 0 zurückgesetzt")
	_ok(Save.campaign.shop == {"extra_shield": 2} and Save.campaign.evolutions == [{"id": "chitin_bastion", "level": 1}],
		"Werkstatt und Evolutionen überleben taktischen Reset")

	# --- Bossmusik: eigener Titel je Boss, keiner doppelt
	var names: Array = []
	for lv in Data.levels:
		var music := String(g._boss_music(String(lv.get("boss", ""))))
		names.append(music)
	print("  Bossmusik: ", str(names))
	_ok(names.size() == 10, "zehn Bosse")
	var uniq := {}
	for n in names:
		uniq[n] = true
	_ok(uniq.size() == 10, "jeder Boss hat einen eigenen Titel")
	var missing: Array = []
	for n in uniq.keys():
		if not ResourceLoader.exists("res://assets/audio/music/%s.ogg" % String(n)):
			missing.append(n)
	_ok(missing.is_empty(), "alle Boss-Titel liegen als Datei vor (%s)" % str(missing))

	# --- Bossdarstellung: genau ein Körper, keine Doppelung
	app.clear_screens()
	app._begin_level(4, 0)
	g = await _wait_game(app)
	g.director.start_boss_now()
	for i in range(240):
		if g.boss != null and is_instance_valid(g.boss):
			break
		await get_tree().process_frame
	if g.boss == null:
		_ok(false, "Boss erscheint")
	else:
		var part_nodes := 0
		for pp in g.boss.parts:
			if pp.get("node", null) != null:
				part_nodes += 1
		var bodies := 0
		for ch in g.boss.get_children():
			if (ch is Sprite2D or ch is AnimatedSprite2D) and not ch in g.boss.parts.map(func(x): return x.get("node", null)):
				bodies += 1
		_ok(bodies <= 2, "Boss hat einen Körper plus Glow, Module separat (%d)" % bodies)
		var tex_w := 0
		if g.boss.body is AnimatedSprite2D:
			var f = (g.boss.body as AnimatedSprite2D).sprite_frames.get_frame_texture("default", 0)
			tex_w = int((f as AtlasTexture).region.size.x) if f is AtlasTexture else int(f.get_width())
		elif g.boss.body is Sprite2D:
			tex_w = int((g.boss.body as Sprite2D).texture.get_width())
		var info := Art.info(String(Data.boss(String(g.boss.id)).get("sprite", "")))
		_ok(tex_w == int(info.get("w", 0)), "Boss zeigt genau ein Einzelbild (%d px)" % tex_w)

	# --- Eskalation über Mechanik: gleiche Lebenspunkte, mehr Verhalten
	var b1 := Boss.new()
	b1.setup("rose_beetle", 1.0, 1)
	var b10 := Boss.new()
	b10.setup("rose_beetle", 1.0, 10)
	_ok(is_equal_approx(b1.max_hp, b10.max_hp),
		"Lebenspunkte steigen nicht mit dem Level (%.0f = %.0f)" % [b1.max_hp, b10.max_hp])
	_ok(b1.threat_tier() == 1 and b10.threat_tier() == 5,
		"Bedrohungsstufe steigt von 1 auf 5 (%d/%d)" % [b1.threat_tier(), b10.threat_tier()])
	_ok(b10.phase_defs.size() > b1.phase_defs.size(),
		"Endkampf hat mehr Phasen (%d > %d)" % [b10.phase_defs.size(), b1.phase_defs.size()])
	var pats1: Array = (b1.phase_defs[0] as Dictionary).get("patterns", [])
	var pats10: Array = (b10.phase_defs[0] as Dictionary).get("patterns", [])
	_ok(pats10.size() > pats1.size(),
		"Endkampf hat mehr Muster je Phase (%d > %d)" % [pats10.size(), pats1.size()])
	_ok(b10.interval_now < b1.interval_now,
		"Level 10 Boss greift schneller an (%.2fs < %.2fs)" % [b10.interval_now, b1.interval_now])
	b1.free()
	b10.free()

	# --- Gegnerprojektile: keine Animation (kein Blinken) und hell genug
	var bullets_src := FileAccess.get_file_as_string("res://scripts/game/bullets.gd")
	_ok(not bullets_src.contains("frame_count"), "Geschosse wechseln kein Einzelbild (kein Blinken)")
	for bname in ["ebullet_orb", "ebullet_laser", "ebullet_needle", "ebullet_spore"]:
		var tex := Art.frame_tex(bname, 0)
		var img: Image = tex.get_image()
		var sum := 0.0
		var cnt := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var px: Color = img.get_pixel(x, y)
				if px.a > 0.4:
					sum += (px.r + px.g + px.b) / 3.0
					cnt += 1
		var lum := sum / float(maxi(1, cnt))
		var bright := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var px2: Color = img.get_pixel(x, y)
				if px2.a > 0.4 and (px2.r + px2.g + px2.b) / 3.0 > 0.8:
					bright += 1
		var frac := float(bright) / float(maxi(1, cnt))
		_ok(lum > 0.40 and frac >= 0.10,
			"%s ist hell und kontrastreich (Mittel %.2f, hell %.0f %%)" % [bname, lum, frac * 100.0])

	# --- Evolutionswahl: links/rechts zwischen Karten, runter zum Neuwürfeln
	var evo: Control = load("res://scripts/screens/evolution_screen.gd").new()
	evo.app = app
	add_child(evo)
	await get_tree().process_frame
	if evo.has_method("build_items"):
		evo.build_items()
		evo.refresh()
	await get_tree().process_frame
	_ok(int(evo.grid_count) == 3, "drei Karten im Gitter (%d)" % int(evo.grid_count))
	evo.focus = 0
	evo._grid_move(1, 1)
	var f_right: int = int(evo.focus)
	evo._grid_move(1, 1)
	var f_right2: int = int(evo.focus)
	evo._grid_move(1, -1)
	var f_back: int = int(evo.focus)
	evo._grid_move(0, 1)
	var f_down: int = int(evo.focus)
	_ok(f_right == 1 and f_right2 == 2 and f_back == 1,
		"links/rechts wandert durch die Karten (%d,%d,%d)" % [f_right, f_right2, f_back])
	_ok(f_down >= 3, "runter führt zur Zeile Neuwürfeln (%d)" % f_down)
	evo.queue_free()

	# --- Blütenstaub wird am Levelende zu Punkten
	var before_points := int(Save.campaign.get("points", 0))
	Save.campaign.nectar = 7
	var conv: Control = load("res://scripts/screens/nectar_convert_screen.gd").new()
	conv.app = app
	conv.setup({"nectar": 7})
	app.screen_host.add_child(conv)
	await get_tree().process_frame
	var gained := int(Save.campaign.get("points", 0)) - before_points
	_ok(gained == 70, "7 Nektar ergeben 70 Punkte (%d)" % gained)
	_ok(int(Save.campaign.get("nectar", -1)) == 0, "Blütenstaub steht danach auf 0")
	if conv.has_method("_finish"):
		conv._finish()
	conv.queue_free()

	# --- Gegner bleiben über der Leiste, auch springende
	var limit_y: float = App.PLAY_BOTTOM - 2.0
	var worst := 0.0
	for beh in ["leap", "sweep", "dash", "track", "charge", "sine", "mirror", "rush"]:
		app.clear_screens()
		app._begin_level(3, 0)
		g = await _wait_game(app)
		var e = await _spawn_enemy(g, Vector2(300, App.PLAY_BOTTOM - 60.0), 9999)
		if e != null:
			e.behavior = beh
			e.base_y = App.PLAY_BOTTOM - 30.0
			e.home_y = App.PLAY_BOTTOM - 30.0
			e.amplitude = 90.0
			for i in range(150):
				await get_tree().physics_frame
				if not is_instance_valid(e):
					break
				worst = maxf(worst, e.position.y)
	_ok(worst <= limit_y, "kein Gegner rutscht unter die Leiste (max y=%.0f <= %.0f)" % [worst, limit_y])

	# --- Schwerkraft: Gegensteuern bleibt möglich
	app.clear_screens()
	app._begin_level(5, 0)
	g = await _wait_game(app)
	g.push = Vector2(0, 250.0)
	var y0: float = g.player.position.y
	Bindings.test_move_active = true
	Bindings.test_move = Vector2(0, -1)
	for i in range(45):
		await get_tree().physics_frame
		if is_instance_valid(g):
			g.push = Vector2(0, 250.0)
	var y1: float = g.player.position.y
	Bindings.test_move_active = false
	Bindings.test_move = Vector2.ZERO
	_ok(y1 < y0 - 5.0, "Gegensteuern fliegt bergauf (%.0f -> %.0f)" % [y0, y1])

	# --- Messung: feuert ein Endkampf-Boss tatsächlich dichter?
	var peaks: Array[int] = []
	for lv in [1, 10]:
		app.clear_screens()
		app._begin_level(lv, 0)
		g = await _wait_game(app)
		g.director.start_boss_now()
		for i in range(240):
			if g.boss != null and is_instance_valid(g.boss):
				break
			await get_tree().physics_frame
		var peak := 0
		for i in range(270):
			await get_tree().physics_frame
			if not is_instance_valid(g) or g.boss == null:
				break
			peak = maxi(peak, g.bullets.enemy_bullets.size())
		peaks.append(peak)
	_ok(peaks.size() == 2 and peaks[1] > peaks[0],
		"Endkampf feuert dichter (Level 10: %d Kugeln, Level 1: %d)" % [
			peaks[1] if peaks.size() > 1 else -1, peaks[0] if peaks.size() > 0 else -1])

	# --- Spielbereich endet über der Leiste
	app.clear_screens()
	app._begin_level(2, 0)
	g = await _wait_game(app)
	_ok(g.player.play_bounds.end.y <= App.PLAY_BOTTOM, "Spieler bleibt über der Leiste")
	# R4: flachere Bänder (40 oben, 44 unten) geben dem Spielfeld 36 Zeilen mehr.
	_ok(is_equal_approx(App.PLAY_TOP, 40.0) and is_equal_approx(App.PLAY_BOTTOM, 496.0),
		"Kompakte HUD-Bänder reservieren exakt 40/496 statt 56/476")

	print("MECHANIK: checks=%d fails=%d" % [checks, fails.size()])
	print("MECHANIK_OK" if fails.is_empty() else "MECHANIK_FAIL")
	get_tree().quit(0 if fails.is_empty() else 1)

func _spawn_enemy(g, pos: Vector2, hp: int):
	g._on_spawn_enemy("spore_drifter", pos, {})
	await get_tree().process_frame
	var e = g.enemies[g.enemies.size() - 1] if g.enemies.size() > 0 else null
	if e == null:
		return null
	e.hp = hp
	e.max_hp = hp
	e.speed = 60.0
	e.behavior = "straight"
	return e

func _wait_game(app) -> Node:
	for i in range(600):
		if app.game != null and is_instance_valid(app.game):
			var g = app.game
			if g.player != null:
				return g
		await get_tree().process_frame
	return null
