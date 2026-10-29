extends Node
## R7: Bossangriffe zielen richtig (Larve „spit_arc“, Wasserläufer „drain_gate“),
## jede Einstellung hat eine messbare Wirkung, „Voll ausgebaut“-Ansage, Springbarsche am Teich.

const UiTheme := preload("res://scripts/core/ui_theme.gd")

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	await _spit_arc()
	await _drain_gate()
	await _settings()
	await _maxed_voice()
	await _pond()
	for f in fails:
		print("R7_FEHLER: " + f)
	print("R7_OK" if fails.is_empty() else "R7_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _boss_level(level: int) -> Node:
	Save.new_campaign("expert", 7700 + level)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await _wait(0.3)
	var g = app.game
	g.player.iframes = 1.0e6
	g.player.max_hp = 99
	g.player.hp = 99
	g._spawn_boss()
	await _wait(0.2)
	# Nur der geprüfte Angriff soll feuern: Bosstakt anhalten, Levelgegner entfernen.
	g.boss.act_timer = 1.0e6
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(1.0e5)
	return g

## Mittlere Flugrichtung neuer Feindgeschosse seit `before`.
func _mean_dir(g: Node, before: Array) -> Vector2:
	var sum := Vector2.ZERO
	for b in g.bullets.enemy_bullets:
		if not before.has(b):
			sum += (b.v as Vector2).normalized()
	return sum.normalized()

func _spit_arc() -> void:
	var g = await _boss_level(2)
	g.player.position = Vector2(180, 150)
	g.clear_enemy_bullets()
	var before: Array = []
	g.boss._p_spit_arc()
	await _wait(0.6)
	var to_player: Vector2 = (g.player.position - g.boss.position).normalized()
	var d := _mean_dir(g, before)
	_ok(d != Vector2.ZERO and d.dot(to_player) > 0.9, "Larve spit_arc zielt auf die Biene (%.2f)" % d.dot(to_player))
	g.player.position = Vector2(180, 420)
	g.clear_enemy_bullets()
	await _wait(0.35)
	d = _mean_dir(g, [])
	to_player = (g.player.position - g.boss.position).normalized()
	_ok(d != Vector2.ZERO and d.dot(to_player) > 0.9, "Folgesalve zielt neu (%.2f)" % d.dot(to_player))

func _drain_gate() -> void:
	var g = await _boss_level(7)
	g.clear_enemy_bullets()
	g.boss._p_drain_gate()
	await _wait(0.5)
	var d := _mean_dir(g, [])
	_ok(d.y > 0.9, "Wasserläufer drain_gate fällt von oben herab (%.2f)" % d.y)
	app.menu_main()
	await _wait(0.3)

# ------------------------------------------------------------------ Einstellungen
func _settings() -> void:
	var keep := Save.settings.duplicate(true)
	# Nachbearbeitung und CRT
	Save.set_g("graphics.post", false)
	app._apply_post_shader()
	_ok(app.post_rect.material == null, "Nachbearbeitung aus: kein Vignetten-Shader mehr")
	Save.set_g("graphics.post", true)
	app._apply_post_shader()
	_ok(app.post_rect.material != null, "Nachbearbeitung an: Vignette aktiv")
	Save.set_g("graphics.crt", true)
	Save.set_g("graphics.post", false)
	app._apply_post_shader()
	var cm := app.crt_rect.material as ShaderMaterial
	_ok(app.crt_rect.visible and cm != null and String(cm.shader.code).contains("hint_screen_texture"),
		"CRT an: Röhren-Shader über dem ganzen Bild, auch ohne Nachbearbeitung")
	_ok(app.crt_layer.layer > app.ui_layer.layer and app.crt_layer.layer < app.overlay_layer.layer,
		"CRT liegt über HUD und Menüs")
	_ok(cm != null and float(cm.get_shader_parameter("row_px")) > 0.0, "CRT-Scanlines am Spielpixel-Raster")
	Save.set_g("graphics.crt", false)
	app._apply_post_shader()
	_ok(not app.crt_rect.visible, "CRT aus")
	# Level mit Spielwerten
	Save.set_g("game.tutorial", true)
	Save.set_g("game.autofire_default", true)
	Save.new_campaign("normal", 4711)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	var g = app.game
	var texts: Array = []
	for b in app.hud.banners:
		texts.append(String(b.text))
	_ok(" ".join(texts).contains("Schießen:") and " ".join(texts).contains("Kaufen:"),
		"Tutorialhinweise an: Steuerung wird im ersten Level eingeblendet")
	_ok(g.player.autofire, "Dauerfeuer-Standard wird übernommen")
	Save.set_g("graphics.shake", 0.0)
	g.shake_amount = 0.0
	g.shake(6.0)
	_ok(g.shake_amount == 0.0, "Bildschirmwackeln 0 %: kein Wackeln")
	Save.set_g("graphics.shake", 1.0)
	g.shake(6.0)
	_ok(g.shake_amount > 0.0, "Bildschirmwackeln 100 %: wackelt")
	Save.set_g("graphics.effects", 0.2)
	Save.set_g("access.contrast_hazards", false)
	g.apply_settings()
	_ok(is_equal_approx(g.fx.density, 0.2), "Effektdichte greift sofort (%.2f)" % g.fx.density)
	_ok(not g.bullets.contrast_mode, "Kontrast-Geschosse lassen sich sofort abschalten")
	Save.set_g("game.tutorial", false)
	Save.new_campaign("normal", 4712)
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	texts.clear()
	for b in app.hud.banners:
		texts.append(String(b.text))
	_ok(not " ".join(texts).contains("Schießen:"), "Tutorialhinweise aus: keine Steuerungsbanner")
	# Ton, Oberfläche, Bildrate, Vibration
	Save.set_g("audio.music", 0.0)
	Audio.apply_volumes()
	_ok(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) < -60.0, "Musiklautstärke 0 %: stumm")
	Save.set_g("display.ui_size", 100)
	var s100: int = UiTheme.size(100)
	Save.set_g("display.ui_size", 130)
	_ok(UiTheme.size(100) > s100, "Oberflächengröße skaliert die UI")
	Save.set_g("display.fps_cap", 60)
	app.apply_display()
	_ok(Engine.max_fps == 60, "Bildratenbegrenzung greift")
	Save.set_g("controls.vibration", false)
	_ok(not Bindings.rumble(1.0, 1.0, 0.1), "Vibration aus: kein Rütteln")
	Save.settings = keep
	Audio.apply_volumes()
	app.apply_display()
	app._apply_post_shader()
	app.menu_main()
	await _wait(0.3)

# ------------------------------------------------------------------ Voll ausgebaut
func _maxed_voice() -> void:
	Save.new_campaign("normal", 4713)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	var g = app.game
	var hud = app.hud
	var clip: AudioStream = Audio._load_voice("upgrade_max")
	_ok(clip != null and clip.get_length() > 0.3 and clip.get_length() < 1.5, "Sprachclip „Voll ausgebaut“ vorhanden")
	g.player.upgrades["shield"] = int(Data.upgrade("shield").get("max", 3))
	g.player.nectar = 999
	hud.selected = hud.bar_entries.find("shield")
	Audio._voice_player.stop()
	hud.buy_selected(g.player)
	_ok(g.player.nectar == 999, "Ausgebautes Upgrade kostet nichts")
	_ok(Audio._voice_player.playing and Audio._voice_player.stream == clip,
		"Kaufversuch bei vollem Ausbau sagt „Voll ausgebaut“")
	var texts: Array = []
	for b in hud.banners:
		texts.append(String(b.text))
	_ok(texts.has(Loc.t("bar.maxed")), "Banner „Voll ausgebaut“")
	app.menu_main()
	await _wait(0.3)

# ------------------------------------------------------------------ Teich
func _pond() -> void:
	Save.new_campaign("normal", 4714)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(3, 0)
	await _wait(0.3)
	var g = app.game
	g.player.iframes = 1.0e6
	g.player.autofire = false
	for e in g.enemies:
		if is_instance_valid(e):
			e.queue_free()
	await _wait(0.05)
	g.director.intro_t = 0.0
	g.director.ground_t = 0.0
	await _wait(0.2)
	var ids: Array = []
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead:
			ids.append(String(e.id))
	_ok(ids.has("leap_fish") and not ids.has("ant_gunner") and not ids.has("mole_cricket"),
		"Teich: Springbarsche statt Ameisen und Grillen (%s)" % ", ".join(ids))
	var fish = null
	for e in g.enemies:
		if is_instance_valid(e) and String(e.id) == "leap_fish":
			fish = e
			break
	var top := 9999.0
	var seen_down := false
	var t := 0.0
	while t < 3.0 and is_instance_valid(fish):
		if fish.sprite.visible:
			top = minf(top, fish.position.y)
			if fish.vy > 0.0 and fish.sprite.rotation > 0.4:
				seen_down = true
		await _wait(0.05)
		t += 0.05
	_ok(top < App.PLAY_BOTTOM - 150.0, "Barsch springt im Bogen aus dem Wasser (Scheitel y=%.0f)" % top)
	_ok(seen_down, "Barsch kippt beim Fallen mit dem Kopf nach unten")
	Save.new_campaign("normal", 4715)
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	_ok(app.game.director.level_data.get("mechanic", "") != "water", "Andere Welten behalten ihre Bodengegner")
	app.menu_main()
	await _wait(0.3)
