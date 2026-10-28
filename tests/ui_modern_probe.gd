extends Node
## UI-Regressionsprüfung und Bildnachweise. Keine Änderung der Spiellogik.
const U := preload("res://scripts/core/ui_theme.gd")
var app: Node
var fails: Array[String] = []
var checks := 0
var screenshots := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	screenshots = DisplayServer.get_name() != "headless"
	await get_tree().create_timer(0.4, true).timeout
	Save.new_campaign("normal", 20261027)
	Save.campaign.points = 42000
	Save.campaign.level = 4
	Save.campaign.shop = {"back": 2}
	Save.profile.boss_rush_unlocked = true
	Save.campaign.pending = {"level": 4, "offers": app._roll_offers(3), "reroll_used": false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/ui-modern"))
	# R4: Pixelschrift ohne Kantenglättung statt variabler Vektorschrift.
	_chk((U.font_bold() as FontVariation).base_font.resource_path.ends_with("Jersey10-Regular.ttf")
		and (U.font_bold() as FontVariation).base_font.antialiasing == TextServer.FONT_ANTIALIASING_NONE,
		"Pixelschrift ohne Kantenglättung aktiv")
	await _screen("main_menu", {}, "01_hauptmenue")
	await _screen("settings_screen", {"from": "main"}, "02_einstellungen")
	var settings = app.screens[-1]
	settings.tab = 3
	settings._rebuild_keep_focus()
	await _settle()
	_check_rect(settings.prompt_bar, "Belegung: duale Fußleiste")
	for it in settings.items:
		if it.has("binding_action"):
			_chk(String(it.value_text) == Bindings.describe_action(String(it.binding_action)), "Aktuelle Belegung unverändert")
	await _shot("03_tastatur_xbox")
	settings.focus = 12
	settings._update_focus_visuals()
	await _settle()
	await _shot("04_tastatur_xbox_scroll")
	await _screen("shop_screen", {"from": "menu", "level": 4}, "05_werkstatt")
	await _screen("evolution_screen", {}, "06_evolution")
	await _screen("pause_screen", {}, "07_pause")
	await _screen("gameover_screen", {"deaths": 1, "max_deaths": 3}, "08_gameover")
	await _screen("gameover_screen", {"deaths": 3, "max_deaths": 3}, "09_run_ende")
	await _screen("confirm_screen", {"title": "menu.quit", "message": "menu.quit_warn"}, "10_rueckfrage")
	await _screen("credits_screen", {}, "11_credits")
	# Größere Schrift: Scrollen ist erlaubt; keine horizontale Ausdehnung.
	U.set_scale_override(1.2)
	await _screen("settings_screen", {"from": "main"}, "12_groessere_schrift")
	U.set_scale_override(1.6)
	await _screen("settings_screen", {"from": "main"}, "15_schrift_160")
	settings = app.screens[-1]
	settings.tab = 3
	settings._rebuild_keep_focus()
	await _settle()
	_check_rect(settings.prompt_bar, "160 Prozent: Fußleiste")
	for row in settings._rows:
		_chk(row.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x + 1, "160 Prozent: Belegungszeile passt horizontal")
	await _shot("16_belegung_160")
	U.set_scale_override(1.0)
	app.clear_screens()
	var conversion = app.push_screen("res://scripts/screens/nectar_convert_screen.gd", {"nectar": 37}, 0.0)
	await _settle()
	_check_rect(conversion.panel, "Umrechnung: zentrierte Karte")
	_check_badges(conversion, "Umrechnung")
	await _shot("17_nektarumrechnung")
	app.clear_screens()
	app._begin_level(4, 0)
	await get_tree().create_timer(0.8, true).timeout
	if app.game != null:
		app.clear_screens()
		get_tree().paused = false
		app.paused = false
		var p = app.game.player
		p.iframes = 9999.0
		p.nectar = 100
		p.points = 124500
		p.upgrades.shield = 2
		p.shield_hits = 2
		p.autofire = true
		await get_tree().create_timer(1.2, true).timeout
		await _shot("13_hud")
		app.game._spawn_boss()
		await get_tree().create_timer(0.4, true).timeout
		await _shot("14_hud_boss")
	else:
		_chk(false, "HUD: Spielinstanz vorhanden")
	U.set_scale_override(-1.0)
	print("UI_MODERN checks=%d fails=%d" % [checks, fails.size()])
	for f in fails: print("UI_MODERN_FAIL " + f)
	print("UI_MODERN_OK" if fails.is_empty() else "UI_MODERN_FAILED")
	app._cleanup_game()
	app.clear_screens()
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	for i in range(8): await get_tree().process_frame
	get_tree().quit(0 if fails.is_empty() else 1)

func _screen(script: String, args: Dictionary, shot: String) -> void:
	app.clear_screens()
	get_tree().paused = false
	app.paused = false
	var s = app.push_screen("res://scripts/screens/" + script + ".gd", args, 0.0)
	await _settle()
	_chk(s != null, script + " geöffnet")
	if s == null: return
	_check_rect(s.prompt_bar, script + ": Fußleiste")
	_chk(s.prompt_bar.get_child_count() >= 2, script + ": beide Aktionsgruppen")
	_check_badges(s.prompt_bar, script)
	if script == "main_menu":
		_chk(s.list_box.get_combined_minimum_size().y <= s.scroll_container.size.y, "Hauptmenü: alle Einträge ohne Scrollen")
	if script == "settings_screen" and U.ui_scale() == 1.0:
		_chk(s.list_box.get_combined_minimum_size().y <= s.scroll_container.size.y, "Anzeige: alle Einträge ohne Scrollen")
	if s.side_panel.visible: _check_rect(s.side_panel, script + ": Detailkarte")
	await _shot(shot)

func _check_badges(node: Node, label: String) -> void:
	var kinds := {"key": 0, "pad": 0}
	_count_badges(node, kinds)
	_chk(kinds.key > 0 and kinds.pad > 0, label + ": Tastatur UND Xbox gleichzeitig")

func _count_badges(node: Node, kinds: Dictionary) -> void:
	if node.has_meta("prompt_kind"):
		kinds[String(node.get_meta("prompt_kind"))] += 1
	for c in node.get_children(): _count_badges(c, kinds)

func _check_rect(c: Control, label: String) -> void:
	var r := c.get_global_rect()
	var v := get_viewport().get_visible_rect()
	_chk(r.position.x >= -1 and r.end.x <= v.end.x + 1 and r.position.y >= -1 and r.end.y <= v.end.y + 1, label + " innerhalb Zeichenfläche: " + str(r))

func _settle() -> void:
	await get_tree().create_timer(0.18, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame

func _shot(id: String) -> void:
	if not screenshots: return
	await _settle()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png("res://docs/ui-modern/" + id + ".png")
	_chk(err == OK, "Bild gespeichert: " + id)
	print("UI_MODERN_SHOT " + id)

func _chk(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails.append(label)
