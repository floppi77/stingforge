extends Node
## Ausschließlich Hauptmenü: Layout, echte Speicherdaten und Eingaberouten.
## Vor dem Godot-Start XDG_DATA_HOME, XDG_CONFIG_HOME und XDG_CACHE_HOME auf
## res://build/reference-menu-testdata/{data,config,cache} setzen. Keine Nutzersaves.
## Headless prüft dieselben Zustände ohne PNG; Fensterlauf erzeugt docs/ui-reference.
## Keine exakten Fokusfarben, Glyphen oder feste Positionen von Menü-IDs prüfen.

const U := preload("res://scripts/core/ui_theme.gd")
const MENU := "res://scripts/screens/main_menu.gd"
const SHOT_DIR := "res://docs/ui-reference"
const TEST_DATA := "res://build/reference-menu-testdata"
const IDS := ["continue", "new", "tutorial", "training", "rush", "scores", "fusions", "settings", "credits", "quit"]
const RUN_NOTE := "Run beendet – die Evolutionen im Profil bleiben erhalten."
const EPS := 2.0

var app: Node
var checks := 0
var fails: Array[String] = []
var screenshots := false
var saved_state: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	screenshots = DisplayServer.get_name() != "headless"
	# Die Autoloads werden vor dieser Szene initialisiert: die XDG-Variablen
	# müssen schon der aufrufende Prozess setzen, nicht erst der Test selbst.
	if not _isolated_user_dir():
		_chk(false, "Sicherheitsabbruch: user:// liegt nicht unter build/reference-menu-testdata; XDG_DATA_HOME vor Godot setzen")
		await _finish()
		return
	await get_tree().create_timer(0.4, true).timeout
	saved_state = {
		"settings": Save.settings.duplicate(true),
		"profile": Save.profile.duplicate(true),
		"campaign": Save.campaign.duplicate(true),
		"active": Save.active_campaign,
		"load_note": Save.last_load_note,
		"menu_note": app.menu_note,
		"scale": U._scale_override,
	}
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	_chk(err == OK, "Screenshotordner verfügbar")
	print("MENU_REFERENCE_USERDIR " + OS.get_user_data_dir())
	print("MENU_REFERENCE_MODE " + ("screenshots" if screenshots else "headless"))

	_fixture_active()
	var menu = await _open_menu(1.0)
	if menu != null:
		_check_menu(menu, "Aktiv", true)
		_check_enabled(menu, "continue", true, "Aktiv")
		_check_enabled(menu, "tutorial", true, "Aktiv")
		_check_enabled(menu, "training", true, "Aktiv")
		_check_enabled(menu, "rush", true, "Aktiv")
		_check_status(menu, 4, 42137, 4, "Aktiv")
		await _shot("01_active")
		await _test_navigation(menu, "Aktiv")
		await _test_quit_confirmation(menu)
		await _test_settings_mouse(menu)
		await _test_scores_route(menu)

	_fixture_fresh()
	menu = await _open_menu(1.0)
	if menu != null:
		_check_menu(menu, "Frisch", true)
		for id in ["continue", "training", "rush"]:
			_check_enabled(menu, id, false, "Frisch")
		for id in ["new", "tutorial", "scores", "fusions", "settings", "credits", "quit"]:
			_check_enabled(menu, id, true, "Frisch")
		_chk(not _visible_text(menu.side_panel).replace(".", "").contains("42137"), "Frisch: kein alter Kampagnenpunktestand")
		await _shot("02_fresh")
		for id in ["continue", "training", "rush"]:
			await _test_disabled(menu, id)
		await _test_navigation(menu, "Frisch")

	_fixture_active()
	menu = await _open_menu(1.2)
	if menu != null:
		_check_menu(menu, "Schrift 120 Prozent", false)
		_check_status(menu, 4, 42137, 4, "Schrift 120 Prozent")
		await _shot("03_large")
		await _test_navigation(menu, "Schrift 120 Prozent")
		await _shot("03_large_quit")

	_fixture_active()
	menu = await _open_menu(1.6)
	if menu != null:
		_check_menu(menu, "Schrift 160 Prozent", false)
		_check_status(menu, 4, 42137, 4, "Schrift 160 Prozent")
		await _shot("04_large160")
		await _test_navigation(menu, "Schrift 160 Prozent")
		await _shot("04_large160_quit")

	# Ein beendeter Lauf löscht nur die Kampagne; das Profil bleibt erhalten.
	_fixture_active()
	Save.active_campaign = false
	Save.campaign = {}
	app.menu_note = RUN_NOTE
	menu = await _open_menu(1.0, true)
	if menu != null:
		_check_menu(menu, "Game Over", true)
		_chk(_visible_text(menu).contains(RUN_NOTE), "Game Over: vollständige Run-Ende-Notiz sichtbar")
		_chk(String(app.menu_note).is_empty(), "Game Over: Notiz einmalig übernommen")
		_check_enabled(menu, "continue", false, "Game Over")
		_check_enabled(menu, "tutorial", true, "Game Over")
		_check_enabled(menu, "training", true, "Game Over")
		_check_enabled(menu, "rush", true, "Game Over")
		await _shot("05_gameover")
		await _test_navigation(menu, "Game Over")

	# Freigaben stammen aus dem Profil, nicht aus einer offenen Kampagne.
	_fixture_fresh()
	Save.profile.unlocked_evolutions = _evolution_ids(4)
	menu = await _open_menu(1.0)
	if menu != null:
		_check_enabled(menu, "training", true, "Evolutionen ohne Kampagne")
		_check_enabled(menu, "rush", false, "Evolutionen ohne Rush-Freigabe")
		_check_enabled(menu, "continue", false, "Evolutionen ohne Kampagne")
		Save.profile.boss_rush_unlocked = true
		menu.rebuild()
		menu.refresh()
		await _settle()
		_check_enabled(menu, "rush", true, "Profilfreigabe nach Neuaufbau")
		_check_menu(menu, "Profilfreigabe", true)
		await _shot("06_profile_unlocked")

	# Zweiter echter Datenstand entlarvt fest eingebrannte Referenzzahlen.
	_fixture_active()
	Save.campaign.level = 7
	Save.campaign.points = 13579
	Save.profile.unlocked_evolutions = _evolution_ids(2)
	menu = await _open_menu(1.0)
	if menu != null:
		_check_status(menu, 7, 13579, 2, "Geänderter Speicherstand")
		await _shot("07_changed_save")

	await _finish()

func _isolated_user_dir() -> bool:
	var root := ProjectSettings.globalize_path(TEST_DATA).simplify_path().trim_suffix("/")
	var user_dir := OS.get_user_data_dir().simplify_path()
	var xdg := OS.get_environment("XDG_DATA_HOME").simplify_path()
	return user_dir.begins_with(root + "/") and (xdg == root or xdg.begins_with(root + "/"))

func _fixture_active() -> void:
	Save.settings = Save._default_settings()
	Save.profile = Save._default_profile()
	Save.profile.unlocked_evolutions = _evolution_ids(4)
	Save.profile.boss_rush_unlocked = true
	# Absichtlich nicht gleich dem Kampagnenpunktestand.
	Save.profile.best = {"campaign|normal|4|20261027": {"score": 98531}}
	Save.new_campaign("normal", 20261027)
	Save.campaign.level = 4
	Save.campaign.points = 42137
	Save.campaign.level_scores = {"1": 12000, "2": 14500, "3": 15637}
	Save.campaign.shop = {"back": 2}
	Save.last_load_note = ""

func _fixture_fresh() -> void:
	Save.settings = Save._default_settings()
	Save.profile = Save._default_profile()
	Save.active_campaign = false
	Save.campaign = {}
	Save.last_load_note = ""

func _evolution_ids(count: int) -> Array:
	var ids: Array = []
	for i in range(mini(count, Data.EVOLUTIONS.size())):
		ids.append(String(Data.EVOLUTIONS[i].id))
	return ids

func _open_menu(scale_value: float, keep_note := false):
	app.clear_screens()
	await get_tree().process_frame
	get_tree().paused = false
	app.paused = false
	if not keep_note:
		app.menu_note = ""
	# Tatsächliche Schrift-Einstellung, kein Ersatz der Produktions-Schriften.
	U.set_scale_override(-1.0)
	Save.settings.display.ui_size = 100
	Save.settings.access.font_scale = scale_value
	_chk(is_equal_approx(U.ui_scale(), scale_value), "Schrift-Einstellung %.1f angewendet" % scale_value)
	var menu = app.push_screen(MENU, {}, 0.0)
	await _settle()
	_chk(menu != null and is_instance_valid(menu), "Hauptmenü geöffnet")
	if menu != null:
		_focus_id(menu, "continue" if Save.active_campaign else "new")
		await _settle()
	return menu

func _check_menu(menu, label: String, no_scroll: bool) -> void:
	_chk(menu.items.size() == IDS.size(), label + ": genau neun Menüaktionen")
	_chk(menu._rows.size() == menu.items.size(), label + ": für jede Aktion eine Zeile")
	for id in IDS:
		var count := 0
		for item in menu.items:
			if String(item.get("id", "")) == id:
				count += 1
		_chk(count == 1, label + ": ID genau einmal vorhanden: " + id)
		if id in ["new", "scores", "settings", "credits", "quit"]:
			_check_enabled(menu, id, true, label)
	_check_rect(menu.scroll_container, label + ": linker Menübereich")
	_check_rect(menu.prompt_bar, label + ": Eingabehinweise")
	_chk(menu.side_panel.is_visible_in_tree(), label + ": Statuskarte sichtbar")
	if menu.side_panel.is_visible_in_tree():
		_check_rect(menu.side_panel, label + ": Statuskarte")
		var card: Rect2 = menu.side_panel.get_global_rect()
		var viewport_rect := get_viewport().get_visible_rect()
		_chk(card.get_center().x > viewport_rect.get_center().x and card.get_center().y > viewport_rect.get_center().y, label + ": Statuskarte unten rechts")
		_chk(not menu.scroll_container.get_global_rect().intersects(card), label + ": linker Menübereich und Statuskarte getrennt")
		_chk(not menu.prompt_bar.get_global_rect().intersects(card), label + ": Statuskarte und Eingabehinweise getrennt")
		_check_horizontal_labels(menu.side_panel, card, label + ": Statuskarte")
	var kinds := {"key": 0, "pad": 0}
	_count_badges(menu.prompt_bar, kinds)
	_chk(kinds.key > 0 and kinds.pad > 0, label + ": Tastatur und Xbox gleichzeitig sichtbar")
	if menu.title_label.is_visible_in_tree():
		_check_rect(menu.title_label, label + ": Titel")
	if menu.subtitle_label.is_visible_in_tree():
		_check_rect(menu.subtitle_label, label + ": Untertitel/Notiz")
	if no_scroll:
		_chk(menu.scroll_container.scroll_vertical == 0, label + ": kein Anfangs-Scrollversatz")
		_chk(menu.list_box.get_combined_minimum_size().y <= menu.scroll_container.size.y + EPS, label + ": neun Zeilen passen ohne Scrollen")
		for id in IDS:
			_check_row_visible(menu, id, label)
	for row in menu._rows:
		var r: Rect2 = row.get_global_rect()
		_chk(r.position.x >= -EPS and r.end.x <= get_viewport().get_visible_rect().end.x + EPS, label + ": Zeile passt horizontal")
		if menu.side_panel.is_visible_in_tree():
			_chk(not r.intersects(menu.side_panel.get_global_rect()), label + ": Zeile überlappt Statuskarte nicht")

func _check_status(menu, level: int, points: int, evolutions: int, label: String) -> void:
	var text := _visible_text(menu.side_panel)
	var number_text := text.replace(".", "").replace(",", "").replace(" ", "").replace("\u00a0", "").replace("\u202f", "")
	_chk(number_text.contains(str(points)), label + ": aktuelle Kampagnenpunkte %d statt Profilbestwert" % points)
	_chk(_matches(text, "(?i)level\\s*:?\\s*0?%d\\b" % level), label + ": aktuelles Level %d" % level)
	_chk(text.to_lower().contains(Loc.t("diff.normal").to_lower()), label + ": echte Schwierigkeit Normal")
	_chk(_matches(text, "(?i)evolutionen\\s*:?\\s*0?%d\\b" % evolutions), label + ": Profil zeigt %d Evolutionen" % evolutions)
	print("MENU_REFERENCE_STATUS " + label + " " + text.replace("\n", " | "))

func _matches(text: String, pattern: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(text) != null

func _check_enabled(menu, id: String, expected: bool, label: String) -> void:
	var index := _index(menu, id)
	_chk(index >= 0, label + ": Aktion gefunden: " + id)
	if index >= 0:
		_chk(not bool(menu.items[index].get("disabled", false)) == expected, label + ": Freigabe " + id + " = " + str(expected))

func _index(menu, id: String) -> int:
	for i in range(menu.items.size()):
		if String(menu.items[i].get("id", "")) == id:
			return i
	return -1

func _focus_id(menu, id: String) -> bool:
	var index := _index(menu, id)
	if index < 0:
		_chk(false, "Fokusziel fehlt: " + id)
		return false
	menu.focus = index
	menu._update_focus_visuals()
	return true

func _test_navigation(menu, label: String) -> void:
	if not _focus_id(menu, "new"):
		return
	var visited: Array[String] = []
	for i in range(menu.items.size() + 1):
		if menu.focus >= 0 and menu.focus < menu.items.size():
			var id := String(menu.items[menu.focus].get("id", ""))
			if not visited.has(id):
				visited.append(id)
		menu._move_focus(1)
	for id in ["new", "scores", "settings", "credits", "quit"]:
		_chk(visited.has(id), label + ": per Listennavigation erreichbar: " + id)
	_focus_id(menu, "quit")
	await _settle()
	_check_row_visible(menu, "quit", label + ": nach Navigation")
	_chk(menu.items[_index(menu, "quit")].get("disabled", false) == false, label + ": Beenden aktivierbar")

func _test_disabled(menu, id: String) -> void:
	if not _focus_id(menu, id):
		return
	var count: int = app.screens.size()
	menu._activate()
	await _settle()
	_chk(app.screens.size() == count and app.screens[-1] == menu and app.game == null, "Gesperrt: " + id + " löst keinen Szenenwechsel/Spielstart aus")
	_chk(not Save.active_campaign and Save.campaign.is_empty(), "Gesperrt: " + id + " erzeugt keine Kampagne")

func _test_quit_confirmation(menu) -> void:
	if not _focus_id(menu, "quit"):
		return
	var count: int = app.screens.size()
	menu._activate()
	await _settle()
	var opened: bool = app.screens.size() == count + 1 and app.screens[-1] != menu
	_chk(opened, "Beenden öffnet Rückfrage statt sofortigem Programmende")
	if opened:
		_chk(app.screens[-1].get_script().resource_path == "res://scripts/screens/confirm_screen.gd", "Beenden benutzt unveränderte Rückfrage")
		app.pop_screen(0.0)
		await _settle()
		_chk(app.screens[-1] == menu and menu.is_visible_in_tree(), "Abgebrochene Rückfrage kehrt ins Hauptmenü zurück")

func _test_settings_mouse(menu) -> void:
	var index := _index(menu, "settings")
	if index < 0 or index >= menu._rows.size():
		return
	# gui_input prüft dieselbe Zeilen-Verkabelung auch headless; ein echtes
	# Fenster-Hit-Testing bleibt zusätzlich bei der Screenshot-Sichtprüfung.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = menu._rows[index].size * 0.5
	menu._rows[index].gui_input.emit(click)
	await _settle()
	var opened: bool = not app.screens.is_empty() and app.screens[-1] != menu
	_chk(opened, "Maus: Einstellungen über Zeilen-ID statt festen Index geöffnet")
	if opened:
		_chk(app.screens[-1].get_script().resource_path == "res://scripts/screens/settings_screen.gd", "Maus: richtige Menüroute")
		app.pop_screen(0.0)
		await _settle()

func _test_scores_route(menu) -> void:
	if not _focus_id(menu, "scores"):
		return
	var count: int = app.screens.size()
	menu._activate()
	await _settle()
	var opened: bool = app.screens.size() == count + 1 and app.screens[-1] != menu
	_chk(opened, "Bestenliste öffnet eigene neue Route")
	if opened:
		_chk(app.screens[-1].get_script().resource_path == "res://scripts/screens/highscore_screen.gd", "Bestenliste benutzt ScoresScreen")
		app.pop_screen(0.0)
		await _settle()
		_chk(app.screens[-1] == menu, "Bestenliste zurück erhält Hauptmenü")

func _check_row_visible(menu, id: String, label: String) -> void:
	var index := _index(menu, id)
	if index < 0 or index >= menu._rows.size():
		_chk(false, label + ": sichtbare Zeile fehlt: " + id)
		return
	var row: Control = menu._rows[index]
	_check_rect(row, label + ": " + id)
	var bounds: Rect2 = menu.scroll_container.get_global_rect().grow(EPS)
	var r := row.get_global_rect()
	_chk(row.is_visible_in_tree() and bounds.encloses(r), label + ": Zeile vollständig im Menübereich: " + id)

func _check_rect(control: Control, label: String) -> void:
	var r := control.get_global_rect()
	_chk(r.size.x > 0 and r.size.y > 0 and get_viewport().get_visible_rect().grow(EPS).encloses(r), label + " innerhalb Zeichenfläche: " + str(r))

func _check_horizontal_labels(node: Node, bounds: Rect2, label: String) -> void:
	if node is Label and node.is_visible_in_tree():
		var r: Rect2 = node.get_global_rect()
		_chk(r.position.x >= bounds.position.x - EPS and r.end.x <= bounds.end.x + EPS, label + ": Text bleibt horizontal innerhalb der Karte")
	for child in node.get_children():
		_check_horizontal_labels(child, bounds, label)

func _count_badges(node: Node, kinds: Dictionary) -> void:
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if node.has_meta("prompt_kind"):
		var kind := String(node.get_meta("prompt_kind"))
		if kinds.has(kind):
			kinds[kind] += 1
	for child in node.get_children():
		_count_badges(child, kinds)

func _visible_text(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree():
		return ""
	var text := String(node.text) + "\n" if node is Label or node is RichTextLabel else ""
	for child in node.get_children():
		text += _visible_text(child)
	return text

func _settle() -> void:
	await get_tree().create_timer(0.18, true).timeout
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame

func _shot(id: String) -> void:
	if not screenshots:
		return
	await _settle()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var image := get_viewport().get_texture().get_image()
	_chk(image != null and not image.is_empty(), "Gerendertes Bild vorhanden: " + id)
	if image == null or image.is_empty():
		return
	var path := SHOT_DIR + "/" + id + ".png"
	_chk(image.save_png(path) == OK, "Bild gespeichert: " + path)
	print("MENU_REFERENCE_SHOT " + path)

func _finish() -> void:
	U.set_scale_override(float(saved_state.get("scale", -1.0)))
	app._cleanup_game()
	app.clear_screens()
	get_tree().paused = false
	app.paused = false
	if not saved_state.is_empty():
		Save.settings = saved_state.settings
		Save.profile = saved_state.profile
		Save.campaign = saved_state.campaign
		Save.active_campaign = saved_state.active
		Save.last_load_note = saved_state.load_note
		app.menu_note = saved_state.menu_note
	# Audio-Streams vor dem Beenden lösen, analog ui_modern_probe.
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	for i in range(8):
		await get_tree().process_frame
	print("MENU_REFERENCE checks=%d fails=%d" % [checks, fails.size()])
	for failure in fails:
		print("MENU_REFERENCE_FAIL " + failure)
	print("MENU_REFERENCE_OK" if fails.is_empty() else "MENU_REFERENCE_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _chk(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails.append(label)
