extends Node
## Isolierter visueller Vertrag: echter HUD-Pixelvergleich und sechs Bildbelege.
const U := preload("res://scripts/core/ui_theme.gd")
const Prompts := preload("res://scripts/core/ui_prompts.gd")
const OUT := "res://build/stingforge-visual/"
var app: Node
var fails: Array[String] = []
var checks := 0
var rendered := false
var reports: Array[Dictionary] = []
var pixel_comparisons: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(0.4, true).timeout
	Save.new_campaign("normal", 761432)
	Save.settings.game.hitbox = false
	Save.settings.game.tutorial = false
	Save.settings.graphics.shake = 0.0
	Save.campaign.shop = {"extra_shield": 2}
	app.clear_screens()
	app._begin_level(1, 0)
	await get_tree().create_timer(0.9, true).timeout
	app.clear_screens()
	app.paused = false
	get_tree().paused = false
	var g = app.game
	if g == null:
		_check(false, "Spielinstanz für Screenshot vorhanden")
		_finish()
		return
	g.process_mode = Node.PROCESS_MODE_DISABLED
	_freeze_art(g)
	var p: Player = g.player
	_check(int(p.upgrades.get("shield", 0)) == 0 and is_equal_approx(p.shop_mod("shield_grace"), 0.5)
		and not p.shield_active() and p.shield_max == 0 and p.shield_hits == 0,
		"Echte Werkstattstufe extra_shield2 gibt0.5s Stabilität, aber kein ungekauftes Schild")
	p.position = Vector2(160, 250)
	p.rotation = 0.0
	p.sprite.rotation = 0.0
	p.upgrades["base"] = 1
	p.upgrades["fan"] = 1
	p.weapon = "fan"
	p.nectar = 1000
	for level in range(1, 4):
		_check(bool(p.try_buy("shield").ok) and p.shield_max == level,
			"Visuelle Fixture kauft echte taktische Schildstufe%d" % level)
	p.shield_hits = 1
	p.shield_regen_t = p.shield_regen_duration() * 0.5
	p.nectar = 100
	p.points = 124500
	p.autofire = true
	p.iframes = 0.0
	p.max_hp = 4
	p.hp = 3
	app.hud.banners.clear()
	app.hud.boss_t = 0.0
	app.hud.white_flash = 0.0
	app.hud.set_process(false)
	_check(is_equal_approx(App.PLAY_TOP, 40.0) and is_equal_approx(App.PLAY_BOTTOM, 496.0),
		"Gemeinsame Spielgrenzen exakt40/496")
	_check(is_equal_approx(app.hud.HEADER_HEIGHT, App.PLAY_TOP), "Header endet an der Spielgrenze")
	p.shield_hits = 0
	_check(app.hud._shield_active(p), "Leeres taktisch gekauftes Schild bleibt aktiv")
	p.upgrades["shield"] = 0
	p._refresh_shield_capacity()
	_check(not app.hud._shield_active(p) and p.shield_max == 0 and p.shield_hits == 0,
		"Ohne taktischen Kauf trotz Werkstatt korrekt inaktiv")
	p.upgrades["shield"] = 3
	p._refresh_shield_capacity()
	p.shield_hits = 1
	p.shield_regen_t = p.shield_regen_duration() * 0.5
	_check(app.hud._shield_active(p) and p.shield_max == 3, "Gekaufte Schildstufe3 hat exakt3 Kapazität")
	_check(is_equal_approx(app.hud._shield_progress(p), 0.5), "HUD liest reale Regeneration über Player-API")
	_check(is_equal_approx(app.hud._shield_duration(p), p.shield_regen_duration()), "Keine abweichende HUD-Regenerationsformel")
	var inf := Art.info("bee")
	_check(int(inf.w) == 40 and int(inf.h) == 32 and int(inf.frames) == 6 and int(inf.fps) == 14,
		"Biene 40x32 / 6 Frames / 14 fps unverändert")
	_check(is_equal_approx(Player.HIT_RADIUS, 4.6), "Trefferkreis unverändert")
	var imported := Art.sheet("bee").get_image()
	var original := Image.new()
	original.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/sprites/bee.png"))
	_check(imported != null and imported.get_size() == original.get_size(), "Bienenimport im richtigen Format")
	# Alpha und sichtbare Farben, nicht Godots irrelevanter RGB-Rand transparenter Pixel.
	if imported != null and rendered:
		imported.convert(Image.FORMAT_RGBA8)
		original.convert(Image.FORMAT_RGBA8)
		var stale := 0
		for y in range(original.get_height()):
			for x in range(original.get_width()):
				var a := original.get_pixel(x, y)
				var b := imported.get_pixel(x, y)
				if absf(a.a - b.a) > 0.01 or (a.a > 0.25 and a != b):
					stale += 1
		_check(stale == 0, "Importierte Biene entspricht neuer PNG: %d Abweichungen" % stale)
	for action in ["menu", "autofire", "upgrade_prev", "upgrade_next", "upgrade_buy"]:
		var key := false
		var pad := false
		for token in Prompts.tokens(action, "both"):
			key = key or token.kind == "key"
			pad = pad or token.kind == "pad"
		_check(key and pad, action + ": Tastatur UND Xbox gleichzeitig")
	for mode in [{"name": "low", "scale": 0.8}, {"name": "default", "scale": 1.0}, {"name": "high", "scale": 1.6}]:
		U.set_scale_override(mode.scale)
		p.sprite.frame = reports.size() % 6
		_check_layout(mode.name, mode.scale)
		await _capture(mode.name + "_hud", mode.scale)
	# Boss wird kontrolliert in derselben unveränderten Spielwelt dargestellt.
	g._spawn_boss()
	if g.boss == null:
		_check(false, "Boss für Bildnachweis vorhanden")
	else:
		g.boss.position = Vector2(735, 255)
		g.boss.hp = g.boss.max_hp * 0.64
		g.boss.vulnerable = true
		_freeze_art(g.boss)
		app.hud.boss_t = 0.0
		app.hud.white_flash = 0.0
		app.hud.banners.clear()
		for mode in [{"name": "low", "scale": 0.8}, {"name": "default", "scale": 1.0}, {"name": "high", "scale": 1.6}]:
			U.set_scale_override(mode.scale)
			p.sprite.frame = reports.size() % 6
			_check_layout(mode.name + "_boss", mode.scale)
			await _capture(mode.name + "_boss", mode.scale)
		# Auch Kaufmeldungen und der Bossalarm dürfen kein Spielfeldpixel verdecken.
		app.hud.show_banner("Schild Stufe 2 gekauft · Regeneration automatisch", 1.0)
		app.hud.boss_t = 1.0
		app.hud.white_flash = 0.8
		await _capture("high_boss_notice", 1.6)
	await _projectile_evidence()
	_finish()

func _projectile_evidence() -> void:
	# Echte BulletField-Geschosse in echten Leveln, keine nachträgliche Montage.
	# Je vier Art-Typen vor hellem Himmel, bunter Welt und dunklem Vordergrund.
	U.set_scale_override(1.0)
	for level in [1, 4]:
		if level == 4:
			app._begin_level(4, 0)
			await get_tree().create_timer(0.8, true).timeout
			app.clear_screens()
			app.paused = false
			get_tree().paused = false
		var game = app.game
		game.process_mode = Node.PROCESS_MODE_DISABLED
		_freeze_art(game)
		game.player.position = Vector2(160, 250)
		game.player.sprite.frame = 0
		game.player.sprite.rotation = 0.0
		game.player.iframes = 0.0
		game.player.sprite.modulate = Color.WHITE
		game.player.nectar = 100
		game.player.points = 124500
		game.player.autofire = true
		game.player.upgrades["shield"] = 3
		game.player._refresh_shield_capacity()
		game.player.shield_hits = 1
		game.player.shield_regen_t = game.player.shield_regen_duration() * 0.5
		app.hud.set_process(false)
		app.hud.banners.clear()
		app.hud.boss_t = 0.0
		app.hud.white_flash = 0.0
		game.bullets.clear()
		var types := ["ebullet_orb", "ebullet_needle", "ebullet_spore", "ebullet_laser"]
		var friendly := ["bullet_base", "bullet_fan", "bullet_lightning", "bullet_plasma"]
		for row_y in [140.0, 250.0, 390.0]:
			for i in range(types.size()):
				game.bullets.spawn_enemy(Vector2(340 + i * 92, row_y), Vector2(-80, 0), 1,
					types[i], {"r": 5.0, "rot": true})
				game.bullets.spawn_player(Vector2(230 + i * 92, row_y + 36), Vector2(120, 0), 1.0,
					friendly[i], {"rot": true})
		game.bullets.queue_redraw()
		_check(game.bullets.enemy_bullets.size() == 12, "Level%d: alle vier feindlichen Arten in drei Helligkeitszonen" % level)
		_check(game.bullets.player_bullets.size() == 12, "Level%d: freundliches Feuer gleichzeitig zum Vergleich" % level)
		await _capture("projectiles_bright" if level == 1 else "projectiles_dark", 1.0)

func _freeze_art(node: Node) -> void:
	if node is AnimatedSprite2D:
		node.stop()
	if node is CPUParticles2D:
		node.visible = false
	for child in node.get_children():
		_freeze_art(child)

func _check_layout(label: String, scale: float) -> void:
	var hud = app.hud
	var s: float = hud._scale()
	var regions: Dictionary = hud._status_layout(s)
	var header: Rect2 = regions.header
	for name in ["vital", "shield", "nectar", "score", "controls", "rail", "level", "level_name", "notice", "boss_name", "boss_hp", "boss_status"]:
		var r: Rect2 = regions[name]
		_check(header.encloses(r), label + ": " + name + " vollständig im reservierten Header")
		_check(r.end.y <= hud.view.position.y + App.PLAY_TOP * s, label + ": " + name + " vor Spielfeld")
	_check(not (regions.level as Rect2).intersects(regions.boss_name), label + ": Levelbadge und Bossname getrennt")
	_check(not hud._level_text(true).is_empty(), label + ": tatsächliches Levelbadge vorhanden")
	_check(is_equal_approx(hud._bar_top(s), hud.view.position.y + App.PLAY_BOTTOM * s), label + ": untere Leiste erst ab PLAY_BOTTOM")
	var footer: Dictionary = hud._bar_layout(s)
	_check(footer.cards.size() == 9, label + ": alle neun taktischen Leistenfelder bleiben erhalten")
	for card: Rect2 in footer.cards:
		_check((footer.band as Rect2).encloses(card), label + ": Leistenfeld vollständig im unteren64px-Band")
	var control: Rect2 = regions.controls
	hud._hint_h = 14.0
	for row in [{"action": "autofire", "label": "Auto AN"}, {"action": "menu", "label": "Menü"}]:
		var hint_s: float = hud._hint_scale(row.action, row.label, control.size.x * 0.5 - 10.0 * s, s)
		_check(hud._hint_width(row.action, row.label, hint_s) <= control.size.x * 0.5 - 10.0 * s + 0.001,
			label + ": dualer Hinweis " + row.action + " passt")
		_check(4.0 * s + hud._hint_h * hint_s <= control.size.y + 0.001,
			label + ": kompakte Hinweiszeile " + row.action + " passt vertikal")
	hud._hint_h = hud.HINT_HEIGHT
	var regular := U.font_bold()
	var title_rect: Rect2 = hud._area(regions.vital, 116, 0, 34, 22, s)
	var fs: int = hud._fit_font(regular, "3/4", title_rect, 16, s)
	_check(fs * hud.CAP_RATIO <= title_rect.size.y * 0.78 + 0.001, label + ": tatsächliche Schriftmetrics passen")
	reports.append({"case": label, "font_scale": scale, "title_font_px": fs,
		"header_end_y": header.end.y, "play_top_y": hud.view.position.y + App.PLAY_TOP * s,
		"boss_rail_end_y": (regions.rail as Rect2).end.y, "sprite_frame": app.game.player.sprite.frame})

func _capture(name: String, scale: float) -> void:
	app.hud.queue_redraw()
	await get_tree().process_frame
	if not rendered:
		return
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(OUT + name + ".png") == OK, "Screenshot gespeichert: " + name)
	var hud = app.hud
	var s: float = hud._scale()
	# Canvas-items streckt 960x540 auf das native Screenshotbild. Nicht dessen
	# Gerätepixel mit logischen HUD-Koordinaten verwechseln.
	var native_scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var left := ceili(hud.view.position.x * native_scale.x)
	# Vom rechten Rand rechnen, damit 1600/960 nicht durch Float-Rundung eine
	# ganze native Randspalte unterschlägt.
	var right := image.get_width() - ceili((get_viewport().get_visible_rect().end.x - hud.view.end.x) * native_scale.x)
	var top := ceili((hud.view.position.y + App.PLAY_TOP * s) * native_scale.y)
	var bottom := floori((hud.view.position.y + App.PLAY_BOTTOM * s) * native_scale.y)
	var crop := Rect2i(left, top, right - left, bottom - top)
	var field := image.get_region(crop)
	hud.visible = false
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var naked_image := get_viewport().get_texture().get_image()
	var naked := naked_image.get_region(crop)
	if name == "default_hud":
		naked_image.save_png(OUT + "default_world_without_hud.png")
	var with_data := field.get_data()
	var without_data := naked.get_data()
	var identical := with_data == without_data
	var changed_pixels := 0
	if not identical:
		var channels := with_data.size() / (crop.size.x * crop.size.y)
		for pixel in range(crop.size.x * crop.size.y):
			for channel in range(channels):
				var i: int = pixel * channels + channel
				if with_data[i] != without_data[i]:
					changed_pixels += 1
					break
	pixel_comparisons.append({"case": name, "font_scale": scale,
		"compared_pixels": crop.size.x * crop.size.y, "changed_pixels": changed_pixels,
		"native_playfield": [crop.position.x, crop.position.y, crop.size.x, crop.size.y]})
	_check(identical, "%s %.1f: kein HUD-Pixel im begehbaren Feld" % [name, scale])
	hud.visible = true
	await get_tree().process_frame
	print("STINGFORGE_VISUAL_SHOT " + OUT + name + ".png")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails.append(label)
		print("STINGFORGE_VISUAL_FAIL " + label)

func _finish() -> void:
	U.set_scale_override(-1.0)
	var report := {"checks": checks, "failures": fails, "rendered": rendered,
		"layouts": reports, "playfield_pixel_comparisons": pixel_comparisons}
	var file := FileAccess.open(OUT + ("render-report.json" if rendered else "layout-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("STINGFORGE_VISUAL checks=%d fails=%d rendered=%s" % [checks, fails.size(), rendered])
	print("STINGFORGE_VISUAL_OK" if fails.is_empty() else "STINGFORGE_VISUAL_FAILED")
	app._cleanup_game()
	app.clear_screens()
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	for i in range(8):
		await get_tree().process_frame
	get_tree().quit(0 if fails.is_empty() else 1)
