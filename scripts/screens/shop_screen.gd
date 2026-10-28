extends "res://scripts/core/ui_screen.gd"
## Werkstatt: dauerhafte Verbesserungen für Punkte.
## Erscheint nach jeder Evolutionswahl und ist aus dem Hauptmenü erreichbar.
##
## Drei Spalten: links die Kategorien, mittig die Upgrades der gewählten Kategorie
## (erscheinen schon beim Überfahren), rechts Beschreibung und Erklärgrafik.
## Bestätigen (oder rechts) springt aus den Kategorien in die Liste, Zurück (oder
## links) wieder heraus. Die Mittelliste ist die gewohnte UiScreen-Liste (items).

const Illustration := preload("res://scripts/core/upgrade_illustration.gd")
const CAT_BLURB := {
	"shot": "Form und Richtung deiner Stachel: Wellen, Kreisflug, Heck- und Seitenschüsse.",
	"impact": "Was beim Treffer passiert: Durchschlag, Splitter, Kettenblitz und Volltreffer.",
	"tempo": "Wie schnell und wie dicht die Biene feuert.",
	"defense": "Schild, Leben und Bomben – alles, was dich länger in der Luft hält.",
	"econ": "Mehr Blütenstaub und mehr Punkte aus jedem Flug.",
}
## Beispielszene je Kategorie, solange noch kein Upgrade gewählt ist.
const CAT_SCENE := {"shot": "wave", "impact": "chain", "tempo": "fire_rate",
	"defense": "shield_regen", "econ": "magnet"}

var level := 1
var from_menu := false
var levels: Dictionary = {}
var points := 0
## "cats": Fokus in der Kategoriespalte; "items": Fokus in der Upgradeliste.
var mode := "cats"
## Index in _cats; _cats.size() steht für "Weiter".
var cat_index := 0
var cat_col: VBoxContainer
var _cats: Array = []
var _cat_rows: Array[Control] = []
var _mouse_active := false

func setup(args: Dictionary) -> void:
	backdrop_mood = "cool"
	level = int(args.get("level", 1))
	from_menu = String(args.get("from", "")) == "menu"
	title_key = "Werkstatt"
	subtitle_key = ""
	columns = 1
	back_enabled = true
	list_width = 0
	footer_text = "Gekauftes bleibt für den Lauf · ← → wechselt zwischen Kategorien und Liste"
	for cat in ShopData.CATEGORIES:
		if not ShopData.items_of(String(cat.id)).is_empty():
			_cats.append(cat)
	_load_state()

func _load_state() -> void:
	levels = (Save.campaign.get("shop", {}) as Dictionary).duplicate(true)
	points = int(Save.campaign.get("points", 0))

func _ready() -> void:
	super._ready()
	_build_cat_column()
	# Mitte etwas breiter als die Beschreibung; beide teilen sich den Rest.
	left_col.size_flags_stretch_ratio = 1.1
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.custom_minimum_size.x = UiTheme.size(200)
	_update_focus_visuals()

func build_items() -> void:
	var list: Array = []
	# Punktestand in der Untertitelzeile: spart eine Kopfzeile für die Liste.
	subtitle_override = "Verfügbar: %s Punkte · drei Stufen je Eintrag" % _fmt(points)
	var cat: Dictionary = _cats[clampi(cat_index, 0, _cats.size() - 1)]
	list.append({"kind": "label", "text": String(cat.name).to_upper(), "size": 14,
		"color": UiTheme.ACCENT2})
	for it in ShopData.items_of(String(cat.id)):
		list.append(_row_for(it))
	items = list

func _current_cat() -> String:
	return String(_cats[clampi(cat_index, 0, _cats.size() - 1)].id)

func _on_next_row() -> bool:
	return cat_index >= _cats.size()

# ------------------------------------------------------------ Kategoriespalte
func _build_cat_column() -> void:
	cat_col = VBoxContainer.new()
	cat_col.name = "Categories"
	cat_col.custom_minimum_size.x = UiTheme.size(168)
	cat_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_col.add_theme_constant_override("separation", UiTheme.pad(5))
	main_row.add_child(cat_col)
	main_row.move_child(cat_col, 0)
	var head := Label.new()
	head.text = "KATEGORIEN"
	head.add_theme_font_override("font", UiTheme.font_regular())
	head.add_theme_font_size_override("font_size", UiTheme.size(14))
	head.add_theme_color_override("font_color", UiTheme.ACCENT2)
	cat_col.add_child(head)
	for i in range(_cats.size() + 1):
		var is_next := i == _cats.size()
		if is_next:
			var gap := Control.new()
			gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cat_col.add_child(gap)
		var row := _make_row({"kind": "action", "text": "Weiter" if is_next else String(_cats[i].name),
			"value_text": "", "accent": is_next}, -1)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for c in row.get_children():
			_ignore_mouse(c)
		row.mouse_entered.connect(_on_cat_hover.bind(i))
		row.gui_input.connect(_on_cat_input.bind(i))
		cat_col.add_child(row)
		_cat_rows.append(row)
	_update_cat_rows()

## Fortschritt je Kategorie (gekaufte Stufen) und Hinweis, ob etwas bezahlbar ist.
func _update_cat_rows() -> void:
	for i in range(_cat_rows.size()):
		var value := _cat_rows[i].get_meta("value") as Label
		if value == null:
			continue
		if i == _cats.size():
			value.text = "Level %d" % level if not from_menu else "Menü"
			value.add_theme_color_override("font_color", UiTheme.ACCENT)
			continue
		var bought := 0
		var total := 0
		var buyable := false
		for it in ShopData.items_of(String(_cats[i].id)):
			var lvl := int(levels.get(String(it.id), 0))
			bought += lvl
			total += int(it.get("max", 3))
			if lvl < int(it.get("max", 3)) and _unlocked(it) and points >= ShopData.cost(String(it.id), lvl):
				buyable = true
		value.text = "%d/%d" % [bought, total]
		value.add_theme_color_override("font_color", UiTheme.ACCENT if buyable else UiTheme.DIM)

func _update_cat_visuals() -> void:
	for i in range(_cat_rows.size()):
		var row := _cat_rows[i]
		var current := i == cat_index
		var focused := current and mode == "cats"
		# Offene Kategorie bleibt beim Arbeiten in der Liste hervorgehoben.
		row.add_theme_stylebox_override("panel", UiTheme.row_style(focused,
			(current and mode == "items") or i == _cats.size(), false))
		var marker := row.find_child("Marker", true, false) as CanvasItem
		if marker != null:
			marker.modulate.a = 1.0 if focused else 0.0

func _select_cat(i: int) -> void:
	i = clampi(i, 0, _cats.size())
	if i == cat_index and mode == "cats":
		return
	var changed := i != cat_index
	cat_index = i
	mode = "cats"
	if changed and i < _cats.size():
		scroll_container.scroll_vertical = 0
		items.clear()
		build_items()
		refresh()
		focus = 0
		_clamp_focus()
	Audio.sfx("ui_move", -12.0, 1.0, true)
	_update_focus_visuals()

func _enter_items() -> void:
	if _on_next_row():
		_on_next()
		return
	mode = "items"
	focus = 0
	_clamp_focus()
	Audio.sfx("ui_ok", -10.0, 1.1, true)
	_update_focus_visuals()

func _leave_items() -> void:
	mode = "cats"
	Audio.sfx("ui_back", -10.0, 1.0, true)
	_update_focus_visuals()

func _on_cat_hover(i: int) -> void:
	if _mouse_active:
		_select_cat(i)

func _on_cat_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_select_cat(i)
	_enter_items()
	accept_event()

## Mausbewegung schaltet auf Zeigerbedienung; Tasten/Gamepad wieder zurück. So
## löst eine neu aufgebaute Liste unter einem ruhenden Zeiger keinen Moduswechsel aus.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_active = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_mouse_active = false

func _on_row_hover(idx: int) -> void:
	if not _mouse_active or _is_skippable(idx):
		return
	if mode != "items":
		mode = "items"
		focus = idx
		_update_focus_visuals()
		return
	super._on_row_hover(idx)

func _update_focus_visuals() -> void:
	super._update_focus_visuals()
	if mode == "cats":
		# Vorschau: Liste ohne Fokusmarke, solange die Kategorien gewählt werden.
		for i in range(_rows.size()):
			var it: Dictionary = items[i]
			if String(it.get("kind", "")) in ["label", "sep"]:
				continue
			_rows[i].add_theme_stylebox_override("panel", UiTheme.row_style(false,
				it.get("accent", false), it.get("disabled", false)))
			var marker := _rows[i].find_child("Marker", true, false) as CanvasItem
			if marker != null:
				marker.modulate.a = 0.0
	_update_cat_visuals()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var up := Bindings.consume("ui_up")
	var down := Bindings.consume("ui_down")
	var left := Bindings.consume("ui_left")
	var right := Bindings.consume("ui_right")
	var act := Bindings.consume("ui_accept")
	var buy := Bindings.consume("upgrade_buy")
	var cancel := Bindings.consume("ui_cancel")
	var menu := Bindings.consume("menu")
	if mode == "cats":
		if up:
			_select_cat(posmod(cat_index - 1, _cats.size() + 1))
		elif down:
			_select_cat(posmod(cat_index + 1, _cats.size() + 1))
		if right or act or buy:
			_enter_items()
		elif cancel or menu:
			_back()
		return
	if up:
		_move_focus(-1)
	elif down:
		_move_focus(1)
	if left or cancel or menu:
		_leave_items()
	elif act or buy:
		_activate()

func _row_for(it: Dictionary) -> Dictionary:
	var id := String(it.id)
	var lvl := int(levels.get(id, 0))
	var maxed := lvl >= int(it.get("max", 3))
	var unlocked := _unlocked(it)
	var price := ShopData.cost(id, lvl)
	var affordable := not maxed and unlocked and points >= price
	var value := ""
	var color := UiTheme.DIM
	if maxed:
		value = "Stufe %d/%d · fertig" % [lvl, int(it.get("max", 3))]
		color = UiTheme.OK
	elif not unlocked:
		value = "gesperrt"
		color = UiTheme.DIM
	else:
		value = _fmt(price)
		color = UiTheme.ACCENT if affordable else UiTheme.DIM
	return {
		"kind": "choice", "id": id, "compact": true,
		"text": "%s  %s" % [String(it.name), _pips(lvl, int(it.get("max", 3)))],
		"value_text": value, "value_color": color,
		"accent": affordable,
		"dim": maxed or not unlocked or not affordable,
		"disabled": not affordable,
	}

func _pips(lvl: int, max_lvl: int) -> String:
	var s := ""
	for i in range(max_lvl):
		s += "●" if i < lvl else "○"
	return s

func _unlocked(it: Dictionary) -> bool:
	for req in it.get("req", []):
		var rid := String((req as Array)[0])
		var rlvl := int((req as Array)[1])
		if int(levels.get(rid, 0)) < rlvl:
			return false
	if ShopData.blocker_of(String(it.id), levels) != "":
		return false
	return true

func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out

# --------------------------------------------------------------- Detailspalte
func on_focus_changed(_index: int) -> void:
	_fill_side()

func _fill_side() -> void:
	if side_box == null:
		return
	for c in side_box.get_children():
		side_box.remove_child(c)
		c.queue_free()
	side_panel.visible = true
	if mode == "cats" or _cats.is_empty():
		_fill_side_category()
		return
	var it := _focused_item()
	if it.is_empty():
		_fill_side_category()
		return
	var id := String(it.id)
	var lvl := int(levels.get(id, 0))
	var maxed := lvl >= int(it.get("max", 3))
	_side_line(String(it.name), 22, UiTheme.ACCENT, true)
	_side_line("%s · Stufe %d/%d  %s" % [_cat_name(String(it.cat)),
		lvl, int(it.get("max", 3)), _pips(lvl, int(it.get("max", 3)))], 14, UiTheme.DIM)
	_side_illustration(id, lvl if maxed else lvl + 1)
	# Preis und Kaufstatus direkt unter der Grafik: ohne Scrollen sichtbar.
	if maxed:
		_side_line("Vollständig ausgebaut.", 15, UiTheme.OK)
	else:
		var price := ShopData.cost(id, lvl)
		var blocker := ShopData.blocker_of(id, levels)
		if blocker != "":
			_side_line("Gesperrt für diesen Lauf: %s ist gewählt."
				% String(ShopData.item(blocker).get("name", blocker)), 14, UiTheme.DANGER)
			_side_line(ShopData.group_note(id), 13, UiTheme.DIM)
		elif not _unlocked(it):
			_side_line("Gesperrt – braucht: " + _req_text(it), 14, Color(1.0, 0.72, 0.55))
		elif points >= price:
			_side_line("Preis: %s Punkte – bezahlbar" % _fmt(price), 15, UiTheme.OK)
		else:
			_side_line("Preis: %s Punkte – es fehlen %s" % [_fmt(price), _fmt(price - points)],
				15, Color(1.0, 0.72, 0.55))
		_side_gap(4)
		_side_line("Stufe %d: " % (lvl + 1) + String(ShopData.step(id, lvl).get("desc", "")),
			14, UiTheme.TEXT)
	if lvl > 0:
		_side_gap(4)
		_side_line("Jetzt: " + String(ShopData.step(id, lvl - 1).get("desc", "")), 13, UiTheme.DIM)
	# Ausschlussgruppe: was dieser Kauf sperrt (rot) bzw. was schon gesperrt ist
	var lock_ids: Array = []
	if lvl <= 0:
		lock_ids = ShopData.would_lock(id, levels)
	else:
		lock_ids = ShopData.locks_of(id, levels)
	if lvl > 0 and not lock_ids.is_empty():
		_side_gap(8)
		_side_line("Gesperrt für diesen Lauf: " + ShopData.lock_names(lock_ids), 14,
			UiTheme.DANGER)
		_side_line(ShopData.group_note(id), 13, UiTheme.DIM)
	elif lvl <= 0 and not lock_ids.is_empty():
		_side_gap(8)
		_side_line("Sperrt: " + ShopData.lock_names(lock_ids), 14, UiTheme.DANGER)
		var own := String(it.name)
		_side_line("Mit dem Kauf von %s ist %s für diesen Lauf nicht mehr wählbar."
			% [own, ShopData.lock_names(lock_ids)], 13, UiTheme.DIM)
	_side_gap(8)
	side_box.add_child(UiPrompts.make_hint("ui_accept", "Kaufen", true))

func _fill_side_category() -> void:
	if _on_next_row():
		_side_line("Weiter", 22, UiTheme.ACCENT, true)
		_side_line("Weiter zu Level %d." % level if not from_menu else "Zurück zum Hauptmenü.",
			15, UiTheme.TEXT)
		_side_gap(6)
		_side_line("Nicht ausgegebene Punkte bleiben erhalten.", 14, UiTheme.DIM)
		_side_gap(8)
		side_box.add_child(UiPrompts.make_hint("ui_accept", "Weiter", true))
		return
	var cat := _current_cat()
	_side_line(_cat_name(cat), 22, UiTheme.ACCENT, true)
	_side_illustration(String(CAT_SCENE.get(cat, "")), 2)
	_side_gap(2)
	_side_line(String(CAT_BLURB.get(cat, "")), 15, UiTheme.TEXT)
	_side_gap(6)
	var entries := ShopData.items_of(cat)
	var open := 0
	for it in entries:
		if int(levels.get(String(it.id), 0)) < int(it.get("max", 3)) and _unlocked(it) \
				and points >= ShopData.cost(String(it.id), int(levels.get(String(it.id), 0))):
			open += 1
	_side_line("%d Upgrades · %d jetzt bezahlbar" % [entries.size(), open], 14,
		UiTheme.OK if open > 0 else UiTheme.DIM)
	_side_gap(8)
	side_box.add_child(UiPrompts.make_hint("ui_accept", "Liste öffnen", true))

func _side_illustration(id: String, stage: int) -> void:
	var ill := Illustration.new()
	ill.name = "Illustration"
	ill.show_item(id, maxi(1, stage))
	side_box.add_child(ill)

func _req_text(it: Dictionary) -> String:
	var parts: Array = []
	for req in it.get("req", []):
		var rid := String((req as Array)[0])
		var rlvl := int((req as Array)[1])
		var other := ShopData.item(rid)
		parts.append("%s Stufe %d" % [String(other.get("name", rid)), rlvl])
	return ", ".join(parts)

func _cat_name(cat: String) -> String:
	for c in ShopData.CATEGORIES:
		if String(c.id) == cat:
			return String(c.name)
	return cat

func _side_line(text: String, size: int, color: Color, bold := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.font_bold() if bold else UiTheme.font_regular())
	l.add_theme_font_size_override("font_size", UiTheme.size(size))
	l.add_theme_color_override("font_color", color)
	side_box.add_child(l)

func _side_gap(h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, UiTheme.pad(h))
	side_box.add_child(c)

func _focused_item() -> Dictionary:
	if items.is_empty() or focus >= items.size():
		return {}
	var it: Dictionary = items[focus]
	if not it.has("id") or String(it.get("kind", "")) != "choice":
		return {}
	return ShopData.item(String(it.id))

# -------------------------------------------------------------------- Kaufen
## Bestätigen kauft. Bewusst nicht über on_adjust: Pfeil links/rechts soll
## nur blättern und keinen Kauf auslösen.
func _activate() -> void:
	if items.is_empty():
		return
	mode = "items"
	var it: Dictionary = items[focus]
	if it.get("disabled", false):
		Audio.sfx("deny", -8.0, 1.0, true)
		return
	var id := String(it.get("id", ""))
	if id == "next" or id == "":
		if id == "next":
			_on_next()
		return
	_buy(id)

## Links/rechts hat in der Werkstatt keine Funktion (kein versehentlicher Kauf).
func on_adjust(_index: int, _dir: int) -> void:
	pass

func on_activate(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	focus = index
	_activate()

func _on_next() -> void:
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	app.shop_done(level, not from_menu)

func _buy(id: String) -> void:
	var entry := ShopData.item(id)
	if entry.is_empty():
		return
	var lvl := int(levels.get(id, 0))
	if lvl >= int(entry.get("max", 3)):
		Audio.sfx("deny", -10.0, 1.0, true)
		return
	if not _unlocked(entry):
		Audio.sfx("deny", -10.0, 1.0, true)
		return
	var price := ShopData.cost(id, lvl)
	if points < price:
		Audio.sfx("deny", -10.0, 1.0, true)
		return
	points -= price
	levels[id] = lvl + 1
	Save.campaign.points = points
	Save.campaign.shop = levels
	Save.save_campaign()
	Audio.sfx("purchase", -3.0, 1.05)
	_rebuild_keep_focus()
	_update_cat_rows()

func _rebuild_keep_focus() -> void:
	var keep := focus
	items.clear()
	build_items()
	refresh()
	focus = clampi(keep, 0, maxi(0, items.size() - 1))
	_clamp_focus()
	_update_focus_visuals()

func do_back() -> void:
	app.shop_done(level, not from_menu)
