extends Node
## R4/R5: dreispaltige Werkstatt; Listen bleiben nach Auswahl stehen (Werkstatt, Debugmenü), 20 Starttalente
## mit Zufallsauswahl von drei, schmale Menüzeilen.
var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.3)
	await _shop()
	await _debug_menu()
	await _talents()
	await _widths()
	await _name_entry()
	for f in fails:
		print("R4_UI_FEHLER: " + f)
	print("R4_UI_OK" if fails.is_empty() else "R4_UI_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## Fokus weit unten setzen, ins Bild scrollen und die Ausgangslage messen.
func _focus_low(screen: Node, accept: Callable) -> int:
	var target := -1
	for i in range(screen.items.size() - 1, -1, -1):
		if accept.call(screen.items[i]):
			target = i
			break
	screen.focus = target
	screen._update_focus_visuals()
	await _frames(3)
	return target

func _is_buyable_row(it: Dictionary) -> bool:
	# Werkstatteinträge sind Auswahlzeilen; gesperrte oder ausgebaute zeigen das im Wert.
	var value := String(it.get("value_text", "")).to_lower()
	return String(it.get("kind", "")) == "choice" and not bool(it.get("disabled", false)) \
		and not value.contains("gesperrt") and not value.contains("max")

func _is_choice_row(it: Dictionary) -> bool:
	return String(it.get("kind", "")) == "choice"

func _is_card(it: Dictionary) -> bool:
	return String(it.get("kind", "")) == "card"

func _visible(screen: Node) -> bool:
	var row: Control = screen._rows[screen.focus]
	var box: Rect2 = screen.scroll_container.get_global_rect().grow(1.0)
	return box.encloses(row.get_global_rect())

func _shop() -> void:
	Save.new_campaign("normal", 777)
	Save.campaign.points = 9999999
	app.clear_screens()
	var shop = app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 4}, 0.0)
	await _wait(0.4)
	# Dreispaltig: Kategorien links (plus "Weiter"), Fokus startet dort.
	_ok(shop.mode == "cats" and shop._cat_rows.size() == shop._cats.size() + 1
		and shop.main_row.get_child(0) == shop.cat_col, "Werkstatt: Kategorien links, Fokus startet dort")
	# Überfahren/Wählen einer Kategorie zeigt sofort deren Upgrades in der Mitte.
	shop._select_cat(3)
	await _frames(3)
	var only_cat := true
	var rows := 0
	for it in shop.items:
		if String(it.get("kind", "")) == "choice":
			rows += 1
			only_cat = only_cat and String(ShopData.item(String(it.id)).get("cat", "")) == "defense"
	_ok(only_cat and rows == ShopData.items_of("defense").size() and shop.mode == "cats",
		"Werkstatt: Mitte zeigt die Upgrades der gewählten Kategorie (%d)" % rows)
	_ok(shop.side_box.find_child("Illustration", true, false) != null, "Werkstatt: Kategorie mit Beispielgrafik")
	shop._enter_items()
	await _frames(2)
	_ok(shop.mode == "items" and String(shop.items[shop.focus].get("kind", "")) == "choice",
		"Werkstatt: Bestätigen springt in die Upgradeliste")
	var ill = shop.side_box.find_child("Illustration", true, false)
	_ok(ill != null and String(ill.item_id) == String(shop.items[shop.focus].id),
		"Werkstatt: Beschreibung mit Erklärgrafik des gewählten Effekts")
	shop._leave_items()
	await _frames(2)
	_ok(shop.mode == "cats" and shop.cat_index == 3, "Werkstatt: Zurück führt in die Kategorien")
	# Kauf in der längsten Kategorie: Liste und Fokus bleiben stehen.
	shop._select_cat(0)
	shop._enter_items()
	await _frames(3)
	var idx: int = await _focus_low(shop, _is_buyable_row)
	_ok(idx > 6, "Werkstatt: Ziel weit unten in der Liste (%d)" % idx)
	var before: int = shop.scroll_container.scroll_vertical
	var points_before: int = shop.points
	shop.on_activate(idx)
	await _frames(4)
	_ok(shop.points < points_before, "Werkstatt: Kauf ausgeführt")
	_ok(absi(shop.scroll_container.scroll_vertical - before) <= 2,
		"Werkstatt: Liste bleibt nach dem Kauf stehen (%d → %d)" % [before, shop.scroll_container.scroll_vertical])
	_ok(shop.focus == idx and shop.mode == "items" and _visible(shop), "Werkstatt: gewählter Eintrag bleibt sichtbar")
	# Mehrfach kaufen: keine wachsende Liste durch liegengebliebene Abstandshalter.
	var height: float = shop.list_box.get_combined_minimum_size().y
	for i in range(3):
		shop.on_activate(idx)
		await _frames(3)
	_ok(absf(shop.list_box.get_combined_minimum_size().y - height) <= 2.0,
		"Werkstatt: Listenhöhe wächst bei Neuaufbau nicht")
	app.clear_screens()

func _debug_menu() -> void:
	Save.new_campaign("normal", 778)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.6)
	app.debug_game()
	await _wait(0.3)
	var dbg = app.screens[-1]
	var idx: int = await _focus_low(dbg, _is_choice_row)
	var before: int = dbg.scroll_container.scroll_vertical
	_ok(before > 0, "Debugmenü: Liste ist heruntergescrollt (%d)" % before)
	dbg.on_adjust(idx, 1)
	await _frames(4)
	_ok(absi(dbg.scroll_container.scroll_vertical - before) <= 2,
		"Debugmenü: Liste bleibt nach Änderung stehen (%d → %d)" % [before, dbg.scroll_container.scroll_vertical])
	_ok(dbg.focus == idx and _visible(dbg), "Debugmenü: gewählter Eintrag bleibt sichtbar")
	app.menu_main()
	await _wait(0.3)

func _talents() -> void:
	var Talent = load("res://scripts/screens/start_talent_screen.gd")
	var pool: Array = Talent.start_pool()
	_ok(pool.size() == 20, "20 Starttalente im Pool (%d)" % pool.size())
	var seen := {}
	for e in pool:
		_ok(String(e.get("weapon", "")) == "" and (e.get("req", []) as Array).is_empty(),
			"Starttalent ohne Voraussetzung: " + String(e.id))
	for s in range(40):
		var offer: Array = Talent.roll_offers(3, s)
		var ids := {}
		var fams := {}
		for e in offer:
			ids[String(e.id)] = true
			fams[String(e.family)] = true
			seen[String(e.id)] = true
		if offer.size() != 3 or ids.size() != 3 or fams.size() != 3:
			fails.append("Ziehung %d: drei verschiedene Talente aus drei Familien" % s)
	_ok(seen.size() >= 15, "Zufallsauswahl streut über den Pool (%d von 20 gesehen)" % seen.size())
	Save.new_campaign("normal", 779)
	app.clear_screens()
	var scr = app.push_screen("res://scripts/screens/start_talent_screen.gd", {"difficulty": "normal"}, 0.0)
	await _wait(0.3)
	var cards: Array = scr.items.filter(_is_card)
	_ok(cards.size() == 3, "Starttalent-Bildschirm zeigt drei Karten (%d)" % cards.size())
	var pick := String(cards[0].id)
	scr.on_activate(0)
	await _wait(0.4)
	var evos: Array = Save.campaign.get("evolutions", [])
	_ok(String(Save.campaign.get("start_talent", "")) == pick and evos.size() == 1 and String(evos[0].id) == pick,
		"Gewähltes Starttalent wird angewendet (%s)" % pick)
	app.menu_main()
	await _wait(0.3)

func _widths() -> void:
	Save.new_campaign("normal", 780)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.5)
	app.pause_game()
	await _wait(0.4)
	var pause = app.screens[-1]
	var limit: float = float(UiTheme_pad(pause.list_width)) + 1.0
	for row in pause._rows:
		_ok(row.size.x <= limit, "Pause: Menüzeile schmal (%.0f ≤ %.0f px)" % [row.size.x, limit])
	app.resume_game()
	app.menu_main()
	await _wait(0.3)

## Highscore-Namenseingabe: Lauf beenden, Eingabe erscheint im Hauptmenü,
## getippter Name wird im Eintrag gespeichert und als Vorschlag gemerkt.
func _name_entry() -> void:
	Save.new_campaign("normal", 4711)
	Save.ensure_run_score()
	Save.campaign.run_score = 987654
	app.mode = "campaign"
	app._record_run_highscore(false)
	var id := String(Save.campaign.run_id)
	_ok(not app.pending_name.is_empty(), "Top-20-Lauf merkt eine offene Namenseingabe")
	app.menu_main()
	await _wait(0.3)
	var top = app.screens[-1]
	_ok(top.get_script().resource_path.ends_with("name_entry_screen.gd"), "Namenseingabe erscheint über dem Hauptmenü")
	top.letters.clear()
	top.cursor = 0
	for ch in ["B", "I", "E", "N", "E"]:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.keycode = OS.find_keycode_from_string(ch)
		ev.unicode = ch.unicode_at(0)
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().process_frame
	_ok(top._name() == "BIENE", "Getippter Name kommt an (%s)" % top._name())
	top._confirm()
	await _wait(0.2)
	var found := ""
	for row in Save.get_highscores("campaign", "all", 20):
		if String(row.run_id) == id:
			found = String(row.pilot)
	_ok(found == "BIENE", "Highscore trägt den eingegebenen Namen (%s)" % found)
	_ok(String(Save.profile.get("last_pilot", "")) == "BIENE", "Name wird als Vorschlag gemerkt")
	app.menu_main()
	await _wait(0.2)

func UiTheme_pad(px: int) -> int:
	return preload("res://scripts/core/ui_theme.gd").pad(px)
