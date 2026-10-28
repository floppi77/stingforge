extends Node
## R2 owned contract: real games, real Player API, exact field pixel comparisons.
const HUD := preload("res://scripts/screens/hud.gd")
const Observer := preload("res://tests/stingforge_r2_hud_recording.gd")
const U := preload("res://scripts/core/ui_theme.gd")
const Prompts := preload("res://scripts/core/ui_prompts.gd")
const OUT := "res://build/stingforge-r2-hud/"
var app: Node
var failures: Array[String] = []
var checks := 0
var rendered := false
var layouts: Array[Dictionary] = []
var actual_levels: Array[Dictionary] = []
var shield_reports: Array[Dictionary] = []
var pixel_comparisons: Array[Dictionary] = []
var text_reports: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	rendered = DisplayServer.get_name() != "headless"
	if rendered:
		# Test-window only: compositor focus hand-off must not open a pause overlay.
		for connection in get_window().focus_exited.get_connections():
			get_window().focus_exited.disconnect(connection.callable)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().process_frame
	_check(is_equal_approx(App.PLAY_TOP, 40.0), "App.PLAY_TOP exakt40 (R4: flachere Bänder)")
	_check(is_equal_approx(App.PLAY_BOTTOM, 496.0), "App.PLAY_BOTTOM exakt496 (R4: flachere Bänder)")
	Save.new_campaign("normal", 761432)
	Save.settings.game.hitbox = false
	Save.settings.game.tutorial = false
	Save.settings.graphics.shake = 0.0
	Save.settings.graphics.post = false
	Save.campaign.shop = {"extra_shield": 2}
	app.fade.color.a = 0.0
	app.post_rect.visible = false
	_check_prompts()
	for level in [1, 8, 10]:
		_start_game(level, "campaign")
		var game = app.game
		var p: Player = game.player
		_check_level(level, "campaign_L%d" % level)
		_check_range(game, "campaign_L%d" % level)
		_check_shields(p, "campaign_L%d" % level)
		# Three real worlds, not nine copies of a single level fixture.
		var stage := 0 if level == 1 else (2 if level == 8 else 3)
		p.upgrades.shield = stage
		p._refresh_shield_capacity()
		p.shield_hits = maxi(0, p.shield_max - 1)
		p.shield_regen_t = p.shield_regen_duration() * 0.5 if stage > 0 else 0.0
		if level != 1:
			game._spawn_boss()
			_freeze_art(game)
			game.boss.position = Vector2(735, 255)
			game.boss.hp = game.boss.max_hp * 0.64
			game.boss.vulnerable = true
			_check_level(level, "campaign_L%d_boss" % level)
		for mode in [{"name": "low", "scale": 0.8}, {"name": "default", "scale": 1.0}, {"name": "high", "scale": 1.6}]:
			U.set_scale_override(mode.scale)
			app.hud.banners.clear()
			app.hud.boss_t = 0.0
			app.hud.white_flash = 0.0
			var name := "L%d_%s" % [level, mode.name]
			if level == 1 and mode.name == "high":
				# Pre-spawn intro must also leave the level label and field intact.
				app.hud.boss_t = 1.0
				app.hud.white_flash = 0.8
				name += "_intro"
			elif level == 10:
				app.hud.show_banner("Schild Stufe3 gekauft · Regeneration automatisch · 999.999 Nektar", 1.0)
				app.hud.boss_t = 1.0
				app.hud.white_flash = 0.8
				name += "_boss_notice"
			_check_layout(name, mode.scale)
			await _capture(name, mode.scale, stage)
		if level == 10:
			await _check_final_form()
	_check(pixel_comparisons.size() == 9 if rendered else pixel_comparisons.is_empty(),
		"Neun echte Pixelpaare nur im Renderlauf; headless erfindet keine Bildmessung")
	await _check_training_and_rush()
	_finish()

func _start_game(level: int, mode: String) -> void:
	app.mode = mode
	app.training_boss = false
	app._begin_level(level, 0)
	app.clear_screens()
	app.paused = false
	get_tree().paused = false
	var game = app.game
	_check(game != null and game.started and game.level_index == level, "Echte Game-Instanz L%d bereit" % level)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_freeze_art(game)
	var original = app.hud
	var rect: Rect2 = original.view
	app.hud_host.remove_child(original)
	original.free()
	var observed = Observer.new()
	app.hud_host.add_child(observed)
	app.hud = observed
	observed.set_view_rect(rect)
	observed.set_process(false)
	observed.banners.clear()
	observed.boss_t = 0.0
	observed.white_flash = 0.0
	game.player.position = Vector2(160, 250)
	game.player.rotation = 0.0
	game.player.sprite.rotation = 0.0
	game.player.sprite.frame = level % 6
	game.player.sprite.modulate = Color.WHITE
	game.player.iframes = 0.0
	game.player.nectar = 999999
	game.player.points = 987654321
	game.player.autofire = true
	game.player.max_hp = 4
	game.player.hp = 3

func _check_prompts() -> void:
	for action in ["menu", "autofire", "upgrade_prev", "upgrade_next", "upgrade_buy"]:
		var key := false
		var pad := false
		for token in Prompts.tokens(action, "both"):
			key = key or token.kind == "key"
			pad = pad or token.kind == "pad"
		_check(key and pad, action + ": Tastatur UND Xbox gleichzeitig, kein Gerätewechsel nötig")
		_check(not Bindings.bindings_for(action).is_empty(), action + ": echte Eingabebindungen vorhanden")
	var info := Art.info("bee")
	_check(int(info.w) == 40 and int(info.h) == 32 and int(info.frames) == 6,
		"Biene weiterhin40x32 mit6Frames, keine Assetänderung")

func _check_level(expected: int, label: String) -> void:
	var info: Dictionary = app.hud._level_info()
	var data := Data.level(expected)
	_check(int(info.get("index", 0)) == expected, label + ": tatsächlicher Datenlevel, nicht Save-/Stagingindex")
	_check(String(info.get("name", "")) == String(data.name), label + ": Name aus Data.level")
	_check(app.hud._level_text(true) == "LEVEL %02d / 10" % expected, label + ": kompakter fester Levelbadge")
	_check(app.hud._level_text(false) == "LEVEL %02d / 10 · %s" % [expected, data.name], label + ": vollständige Levelanzeige")
	actual_levels.append({"case": label, "game_level": app.game.level_index,
		"display_index": info.get("index"), "label": app.hud._level_text(false)})

func _check_range(game: Node, label: String) -> void:
	var bounds: Rect2 = game.player.play_bounds
	_check(bounds.position.y >= App.PLAY_TOP + 10.0 and bounds.end.y <= App.PLAY_BOTTOM - 10.0,
		label + ": Spielerbereich mit mindestens10px Abstand zum Feldrand")
	for y in [bounds.position.y, bounds.get_center().y, bounds.end.y]:
		game.player.position.y = y
		_check(y > App.PLAY_TOP and y < App.PLAY_BOTTOM, label + ": echte obere/mittlere/untere Bereichsposition im Feld")
	game.player.position.y = 250.0

func _check_shields(p: Player, label: String) -> void:
	_check(int(p.shop_levels.get("extra_shield", 0)) == 2, label + ": dauerhafte Werkstatt im echten Build vorhanden")
	for stage in range(4):
		p.upgrades.shield = stage
		p._refresh_shield_capacity()
		p.shield_hits = p.shield_max
		var status: Dictionary = app.hud._shield_status(p)
		_check(p.shield_max == stage and int(status.capacity) == stage,
			label + ": Stufe%d hat exakt%d Kapazität, keine Shop-Zusatzkapazität" % [stage, stage])
		_check(bool(status.active) == p.shield_active(), label + ": Stufe%d liest API active" % stage)
		if stage == 0:
			# Stale charges are not a source either, even if a debug/save value lingers.
			p.shield_hits = 2
			p.shield_regen_t = 123.0
			status = app.hud._shield_status(p)
			_check(not status.active and status.hits == 0 and status.capacity == 0 and
				not status.track_visible and is_zero_approx(status.progress),
				label + ": ohne Quelle keinerlei filled Pip/Ladetrack trotz Shop und Altladung")
		else:
			p.shield_hits = 0
			p.shield_regen_t = p.shield_regen_duration() * 0.5
			status = app.hud._shield_status(p)
			_check(status.active and status.charging and status.track_visible,
				label + ": leeres taktisches Schild bleibt aktiv und lädt")
			_check(is_equal_approx(float(status.progress), p.shield_regen_progress()) and
				is_equal_approx(app.hud._shield_duration(p), p.shield_regen_duration()),
				label + ": ausschließlich Player-API für Regeneration, keine eigene Formel")
		shield_reports.append({"case": label, "stage": stage, "model": status})

func _check_layout(label: String, scale: float) -> void:
	var hud = app.hud
	var original: Rect2 = hud.view
	# Also cover fractional native output scaling and a letterboxed view origin.
	for canvas in [Rect2(0, 0, 960, 540), Rect2(0, 0, 1600, 900), Rect2(80, 45, 1920, 1080)]:
		hud.set_view_rect(canvas)
		var s: float = hud._scale()
		var layout: Dictionary = hud._status_layout(s)
		var header: Rect2 = layout.header
		_check(is_equal_approx(hud.HEADER_HEIGHT, 40.0) and is_equal_approx(header.end.y, canvas.position.y + 40.0 * s),
			label + ": Header exakt40px")
		for key in ["vital", "shield", "nectar", "score", "controls"]:
			var rect: Rect2 = layout[key]
			_check(header.encloses(rect) and rect.position.y >= canvas.position.y + 3.0 * s - 0.001 and
				rect.end.y <= canvas.position.y + 25.0 * s + 0.001 and is_equal_approx(rect.size.y, 22.0 * s),
				label + ": " + key + " Instrumentkarte22px bei y3..25")
		var rail: Rect2 = layout.rail
		_check(is_equal_approx(rail.position.y, canvas.position.y + 27.0 * s) and
			is_equal_approx(rail.end.y, canvas.position.y + 37.0 * s), label + ": Rail y27..37")
		for key in ["level", "level_name", "progress", "eta", "notice", "boss_name", "boss_hp", "boss_status"]:
			_check(rail.encloses(layout[key]), label + ": " + key + " bleibt im Rail")
		# R3: Laufzeitleiste und Restzeit zwischen Levelname und Meldung, ohne Überlappung.
		for pair in [["level_name", "progress"], ["progress", "eta"], ["eta", "notice"], ["level", "progress"]]:
			_check(not (layout[pair[0]] as Rect2).intersects(layout[pair[1]]),
				label + ": " + pair[0] + " und " + pair[1] + " getrennt")
		for key in ["level_name", "notice", "boss_name", "boss_hp", "boss_status"]:
			_check(not (layout.level as Rect2).intersects(layout[key]), label + ": Levelbadge nie von" + key + " verdrängt")
		_check(not (layout.level_name as Rect2).intersects(layout.notice), label + ": Levelname und Meldung getrennt")
		_check(not (layout.boss_name as Rect2).intersects(layout.boss_hp) and
			not (layout.boss_hp as Rect2).intersects(layout.boss_status), label + ": Bossname/HP/Status getrennt")
		var bottom: Dictionary = hud._bar_layout(s)
		var band: Rect2 = bottom.band
		_check(is_equal_approx(band.position.y, canvas.position.y + 496.0 * s) and
			is_equal_approx(band.size.y, 44.0 * s), label + ": Bodenband exakt44px ab496")
		_check(bottom.cards.size() == 9 and hud.bar_entries.size() == Data.UPGRADES.size(), label + ": alle9 Karten erhalten")
		for index in range(bottom.cards.size()):
			var card: Rect2 = bottom.cards[index]
			_check(band.encloses(card) and is_equal_approx(card.size.y, 29.0 * s), label + ": Karte%d vollständig im44px-Band" % index)
			_check(float(bottom.status_y) + 11.0 * s <= card.position.y, label + ": Status über Karte%d ohne Überdeckung" % index)
			if index > 0:
				_check(not card.intersects(bottom.cards[index - 1]), label + ": Karten ohne Überlappung")
			var id := String(hud.bar_entries[index])
			var upgrade := Data.upgrade(id)
			_check_font(label, String(upgrade.get("short", "")), hud._area(card, 22, 2, card.size.x / s - 25, 11, s), 11, s)
			_check_font(label, hud._state_short(app.game.player, id), hud._area(card, 22, 12, card.size.x / s - 25, 9, s), 9, s)
		var control: Rect2 = layout.controls
		# R4: beide Hinweise nebeneinander in einer Zeile (je halbe Breite, Kappe 14px).
		hud._hint_h = 14.0
		for row in [{"action": "autofire", "label": "Auto AUS"}, {"action": "menu", "label": "Menü"}]:
			var fitted: float = hud._hint_scale(row.action, row.label, control.size.x * 0.5 - 10.0 * s, s)
			_check(hud._hint_width(row.action, row.label, fitted) <= control.size.x * 0.5 - 10.0 * s + 0.001 and
				4.0 * s + hud._hint_h * fitted <= control.size.y + 0.001,
				label + ": dualer Hinweis " + row.action + " passt horizontal und vertikal")
		hud._hint_h = 11.0
		var hint_s: float = hud._bar_hint_scale(s)
		_check(hud._bar_hint_width(hint_s) <= 520.0 * s + 0.001 and hud._hint_h * hint_s <= 11.0 * s + 0.001,
			label + ": Wählen/Nutzen mit Tastatur UND Xbox im oberen Bodenstatus")
		hud._hint_h = hud.HINT_HEIGHT
		_check_font(label, hud._level_text(true), (layout.level as Rect2).grow_individual(-5.0 * s, 0, -5.0 * s, 0), 9, s)
		_check_font(label, "Insektenförmige Erntemaschine", layout.boss_name, 9, s)
		_check_font(label, "Schild Stufe3 gekauft · Regeneration automatisch · 999.999 Nektar", layout.boss_status, 8, s)
		layouts.append({"case": label, "font_scale": scale, "canvas": [canvas.position.x, canvas.position.y, canvas.size.x, canvas.size.y],
			"header_end_y": header.end.y, "rail_end_y": rail.end.y, "bottom_start_y": band.position.y, "cards": bottom.cards.size()})
	hud.set_view_rect(original)

func _check_font(label: String, text: String, rect: Rect2, size: float, s: float) -> void:
	var font := U.font_bold()
	var fitted: int = app.hud._fit_font(font, text, rect, size, s)
	# R4: Pixelschrift mit großem Zeilenabstand – maßgeblich ist die Versalhöhe.
	_check(fitted * app.hud.CAP_RATIO <= rect.size.y * 0.78 + 0.001 and
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x <= rect.size.x + 0.001,
		label + ": echte Schriftmetrics passen: " + text)

func _check_actual_draw(label: String, stage: int) -> void:
	var hud = app.hud
	var s: float = hud._scale()
	_check(not hud.text_samples.is_empty(), label + ": echter Produktionszeichencode beobachtet")
	var badge_count := 0
	for sample in hud.text_samples:
		var r := Rect2(sample.rect[0], sample.rect[1], sample.rect[2], sample.rect[3])
		_check(r.end.y <= hud.view.position.y + App.PLAY_TOP * s + 0.001 or r.position.y >= hud.view.position.y + App.PLAY_BOTTOM * s - 0.001,
			label + ": tatsächlicher Text bleibt außerhalb Feld: " + String(sample.text))
		_check(float(sample.width) <= r.size.x + 0.001 and float(sample.height) <= r.size.y + 0.001,
			label + ": tatsächliche Glyphen passen: " + String(sample.text))
		if String(sample.text) == hud._level_text(true):
			badge_count += 1
	_check(badge_count == 1, label + ": Levelbadge genau einmal, auch während Bossintro/Meldung")
	_check(hud.hint_samples.size() == 5, label + ": alle5 Funktionshinweise wirklich gezeichnet")
	for hint in hud.hint_samples:
		var key := false
		var pad := false
		for token in hint.tokens:
			key = key or token.kind == "key"
			pad = pad or token.kind == "pad"
		_check(key and pad, label + ": tatsächlicher Hinweis " + String(hint.action) + " zeigt beide Geräte")
	_check(hud.shield_samples.size() == stage, label + ": tatsächlich exakt%d Schildpips" % stage)
	if stage == 0:
		_check(not hud._shield_status(app.game.player).track_visible, label + ": stage0 hat wirklich keinen Ladetrack")
	text_reports.append({"case": label, "samples": hud.text_samples.duplicate(true),
		"hints": hud.hint_samples.duplicate(true), "shield_pips": hud.shield_samples.duplicate(true)})

func _capture(name: String, scale: float, stage: int) -> void:
	_check(app.screens.is_empty() and not app.paused and not get_tree().paused,
		name + ": keine Pause-/Menüüberdeckung im HUD-Vertrag")
	app.hud.queue_redraw()
	await get_tree().process_frame
	if not rendered:
		return
	# Freeze only the world texture for the A/B pair: shader TIME/animations cannot
	# masquerade as HUD pollution. HUD itself still redraws normally in root UI.
	app.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	app.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(OUT + name + ".png") == OK, "Screenshot gespeichert: " + name)
	_check_actual_draw(name, stage)
	var hud = app.hud
	var s: float = hud._scale()
	var native_scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var left := ceili(hud.view.position.x * native_scale.x)
	var right := image.get_width() - ceili((get_viewport().get_visible_rect().end.x - hud.view.end.x) * native_scale.x)
	# These literal NEW bounds cannot silently regress with stale App constants.
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
	_check(naked_image.save_png(OUT + name + "_without_hud.png") == OK, "Ohne-HUD-Beleg gespeichert: " + name)
	var naked := naked_image.get_region(crop)
	var with_data := field.get_data()
	var without_data := naked.get_data()
	var changed_pixels := 0
	if with_data != without_data:
		var channels := with_data.size() / (crop.size.x * crop.size.y)
		for pixel in range(crop.size.x * crop.size.y):
			for channel in range(channels):
				var i: int = pixel * channels + channel
				if with_data[i] != without_data[i]:
					changed_pixels += 1
					break
	pixel_comparisons.append({"case": name, "font_scale": scale, "compared_pixels": crop.size.x * crop.size.y,
		"changed_pixels": changed_pixels, "native_playfield": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
		"world_playfield": [0, App.PLAY_TOP, 960, App.PLAY_BOTTOM - App.PLAY_TOP], "with_hud": name + ".png", "without_hud": name + "_without_hud.png"})
	_check(changed_pixels == 0, name + ": null veränderte Feldpixel, keinerlei Toleranz")
	hud.visible = true
	await get_tree().process_frame

func _check_final_form() -> void:
	var boss: Boss = app.game.boss
	var hud = app.hud
	var old_max := boss.max_hp
	hud.banners.clear()
	hud.boss_t = 0.0
	hud.white_flash = 0.0
	boss._die()
	_check(boss.reviving and not boss.dead, "L10 Form1-Ende hält den tatsächlichen Boss/Levelbadge sichtbar")
	boss._tick_reviving(boss.REVIVE_TIME)
	_check(boss.encounter_form == 2 and boss.phase_defs.size() == 3, "L10 Form2 besitzt tatsächlich3 Phasen")
	var readout: Dictionary = hud._boss_readout(boss)
	_check(boss.max_hp > old_max and is_equal_approx(readout.fraction, 1.0), "Form2 HP-Rail liest neue max_hp und startet wieder voll")
	for phase in range(3):
		boss._apply_phase(phase)
		hud.banners.clear()
		boss.hp = boss.max_hp * (1.0 - 0.28 * float(phase))
		readout = hud._boss_readout(boss)
		_check(String(readout.status).begins_with("Phase %d/3" % (phase + 1)), "Form2 HUD liest tatsächliche Phase%d/3" % (phase + 1))
		_check(is_equal_approx(readout.fraction, boss.hp / boss.max_hp), "Form2 HUD HP folgt tatsächlicher neuer Kapazität")
		_check_level(10, "L10_form2_phase%d" % (phase + 1))
	_freeze_art(app.game)
	if rendered:
		U.set_scale_override(1.6)
		hud.queue_redraw()
		app.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		app.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_check_actual_draw("L10_high_form2_phase3", 3)
		_check(get_viewport().get_texture().get_image().save_png(OUT + "L10_high_form2_phase3.png") == OK,
			"Zusatzbeleg Form2 Phase3/3 gespeichert; neun Hauptpixelpaare bleiben exakt neun")

func _check_training_and_rush() -> void:
	Save.campaign.level = 1 # deliberately stale save: must never drive the label
	app.start_training(8, "level")
	app.clear_screens()
	app.paused = false
	get_tree().paused = false
	app.game.process_mode = Node.PROCESS_MODE_DISABLED
	app.hud.set_process(false)
	_check_level(8, "training_actual_L8_not_saved_L1")
	app.start_boss_rush()
	app.clear_screens()
	app.paused = false
	get_tree().paused = false
	app.game.process_mode = Node.PROCESS_MODE_DISABLED
	app.hud.set_process(false)
	_check_level(1, "rush_first_boss_actual_L1_not_stage_L10")
	for index in [7, 9]:
		if app.game.boss != null:
			app.game.boss.free()
		app.game.boss = null
		app.game.rush_index = index
		_check_level(index + 1, "rush_between_actual_L%d" % (index + 1))
		app.game._spawn_rush_boss()
		_freeze_art(app.game)
		_check_level(index + 1, "rush_boss_actual_L%d" % (index + 1))
	await get_tree().process_frame

func _freeze_art(node: Node) -> void:
	if node is AnimatedSprite2D:
		node.stop()
	if node is CPUParticles2D:
		node.visible = false
	for child in node.get_children():
		_freeze_art(child)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL " + label)

func _finish() -> void:
	U.set_scale_override(-1.0)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "rendered": rendered,
		"layouts": layouts, "actual_levels": actual_levels, "shield_api": shield_reports,
		"text_metrics": text_reports, "playfield_pixel_comparisons": pixel_comparisons}
	var file := FileAccess.open(OUT + ("render-report.json" if rendered else "layout-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	else:
		_check(false, "Reportdatei konnte nicht geschrieben werden")
	print("STINGFORGE_R2_HUD checks=%d fails=%d rendered=%s" % [checks, failures.size(), rendered])
	print("STINGFORGE_R2_HUD_OK" if failures.is_empty() else "STINGFORGE_R2_HUD_FAIL")
	app._cleanup_game()
	app.clear_screens()
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	# Bounded teardown: known Dummy-audio shutdown references are reported by the
	# runner, never "fixed" by changing Audio or waiting indefinitely for its mixer.
	for _i in range(8):
		await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
