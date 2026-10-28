extends "res://scripts/core/ui_screen.gd"
## Debugmenü (F4): Spiel pausiert, Werkzeuge zum Testen.
## Alles in einer Liste: Boss, Levelwechsel, Heilung sowie alle Taktik- und
## Kauf-Upgrades mit Beschreibung in der rechten Spalte.

func _ready() -> void:
	list_width = 440
	overlay_in_game = true
	header_note = "Spiel pausiert · F4 oder Esc schließt · links/rechts stellt Stufen ein · Sperren der Werkstatt gelten hier nicht"
	super._ready()

func build_items() -> void:
	var list: Array = []
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "Zum Levelboss", "id": "boss", "compact": true, "accent": true})
	list.append({"kind": "action", "text": "Zum nächsten Level", "id": "next", "compact": true})
	list.append({"kind": "action", "text": "Vollheilen", "id": "heal", "compact": true})
	list.append({"kind": "sep"})
	list.append({"kind": "label", "text": "TAKTISCHE UPGRADES", "size": 13, "color": UiTheme.ACCENT2})
	for u in Data.UPGRADES:
		var id := String(u.id)
		var lvl := _bar_level(id)
		list.append({"kind": "choice", "id": "u:" + id, "compact": true,
			"text": "%s  (%s)" % [Loc.t(String(u.name)), _short_kind(String(u.kind))],
			"value_text": "Stufe %d/%d" % [lvl, int(u.get("max", 1))],
			"value_color": UiTheme.ACCENT if lvl > 0 else UiTheme.DIM})
	list.append({"kind": "sep"})
	list.append({"kind": "label", "text": "KAUF-UPGRADES (WERKSTATT)", "size": 13, "color": UiTheme.ACCENT2})
	for it in ShopData.ITEMS:
		var sid := String(it.id)
		var slvl := _shop_level(sid)
		list.append({"kind": "choice", "id": "s:" + sid, "compact": true,
			"text": String(it.name),
			"value_text": "Stufe %d/%d" % [slvl, int(it.get("max", 3))],
			"value_color": UiTheme.ACCENT if slvl > 0 else UiTheme.DIM})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "Weiter", "id": "close", "accent": true})
	items = list

func _short_kind(kind: String) -> String:
	match kind:
		"weapon": return "Waffe"
		"support": return "Hilfe"
		"passive": return "passiv"
		"instant": return "sofort"
	return kind

func _player() -> Player:
	if app == null or app.game == null or not is_instance_valid(app.game):
		return null
	return app.game.player

func _bar_level(id: String) -> int:
	var p := _player()
	if p == null:
		return int(Save.campaign.get("upgrades", {}).get(id, 0))
	return int(p.upgrades.get(id, 0))

func _shop_level(id: String) -> int:
	var p := _player()
	if p == null:
		return int(Save.campaign.get("shop", {}).get(id, 0))
	return int(p.shop_levels.get(id, 0))

# --------------------------------------------------------------- Bedienung
func on_adjust(index: int, dir: int) -> void:
	if index >= items.size():
		return
	var id := String(items[index].get("id", ""))
	if id.begins_with("u:"):
		_set_bar_level(id.substr(2), dir)
	elif id.begins_with("s:"):
		_set_shop_level(id.substr(2), dir)

func on_activate(index: int) -> void:
	if index >= items.size():
		return
	var it: Dictionary = items[index]
	var id := String(it.get("id", ""))
	match id:
		"boss":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.debug_to_boss()
		"next":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.debug_next_level()
		"heal":
			Audio.sfx("purchase", -5.0, 1.0, true)
			app.debug_full_heal()
			_after_change()
		"close":
			Audio.sfx("ui_back", -6.0, 1.0, true)
			app.debug_close()
		_:
			if id.begins_with("u:"):
				_set_bar_level(id.substr(2), 1)
			elif id.begins_with("s:"):
				_set_shop_level(id.substr(2), 1)

func do_back() -> void:
	Audio.sfx("ui_back", -6.0, 1.0, true)
	app.debug_close()

func _process(delta: float) -> void:
	super._process(delta)
	if Bindings.consume("debug_menu"):
		app.debug_close()

func _set_bar_level(id: String, dir: int) -> void:
	var u := Data.upgrade(id)
	if u.is_empty():
		return
	var p := _player()
	var maxlvl := int(u.get("max", 1))
	var cur := _bar_level(id)
	var lvl := clampi(cur + dir, 0, maxlvl)
	if lvl == cur:
		Audio.sfx("deny", -14.0, 1.2, true)
		_after_change()
		return
	if p != null:
		p.upgrades[id] = lvl
		if String(u.get("kind", "")) == "weapon" and lvl > 0:
			p.weapon = id
		if id == "shield":
			p.shield_hits = mini(p.shield_max, lvl)
			p.shield_regen_t = 0.0
		if id == "speed":
			p.speed_level = lvl
		if id == "repair":
			p.upgrades[id] = 0
			p.hp = p.max_hp
			p.hp_changed.emit(p.hp, p.max_hp)
	Save.campaign.upgrades = (p.upgrades if p != null else Save.campaign.get("upgrades", {})).duplicate(true)
	if p != null and p.weapon != "":
		Save.campaign.weapon = p.weapon
	Save.save_campaign()
	Audio.sfx("ui_ok", -8.0, 1.0, true)
	_after_change()

func _set_shop_level(id: String, dir: int) -> void:
	var it := ShopData.item(id)
	if it.is_empty():
		return
	var p := _player()
	var maxlvl := int(it.get("max", 3))
	var cur := _shop_level(id)
	var lvl := clampi(cur + dir, 0, maxlvl)
	if lvl == cur:
		Audio.sfx("deny", -14.0, 1.2, true)
		_after_change()
		return
	if p != null:
		if lvl <= 0:
			p.shop_levels.erase(id)
		else:
			p.shop_levels[id] = lvl
		p.apply_shop_changes()
		Save.campaign.shop = p.shop_levels.duplicate(true)
	else:
		var shop: Dictionary = Save.campaign.get("shop", {})
		if lvl <= 0:
			shop.erase(id)
		else:
			shop[id] = lvl
		Save.campaign.shop = shop
	Save.save_campaign()
	Audio.sfx("ui_ok", -8.0, 1.0, true)
	_after_change()

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

func _after_change() -> void:
	var keep := focus
	items.clear()
	build_items()
	refresh()
	focus = clampi(keep, 0, maxi(0, items.size() - 1))
	_clamp_focus()
	_update_focus_visuals()

# --------------------------------------------------------------- Beschreibung
func on_focus_changed(_index: int) -> void:
	_fill_side()

func _fill_side() -> void:
	if side_box == null:
		return
	for c in side_box.get_children():
		c.queue_free()
	side_panel.visible = true
	if items.is_empty() or focus >= items.size():
		_side_line("Debug", 20, UiTheme.ACCENT, true)
		return
	var it: Dictionary = items[focus]
	var id := String(it.get("id", ""))
	if id.begins_with("u:"):
		var u := Data.upgrade(id.substr(2))
		_side_line(Loc.t(String(u.get("name", ""))), 21, UiTheme.ACCENT, true)
		_side_line("Taktisch · Stufe %d/%d" % [_bar_level(id.substr(2)), int(u.get("max", 1))],
			14, UiTheme.DIM)
		_side_line(Loc.t(String(u.get("desc", ""))), 15, UiTheme.TEXT)
	elif id.begins_with("s:"):
		var sid := id.substr(2)
		var entry := ShopData.item(sid)
		var lvl := _shop_level(sid)
		_side_line(String(entry.name), 21, UiTheme.ACCENT, true)
		_side_line("Werkstatt · Stufe %d/%d" % [lvl, int(entry.get("max", 3))], 14, UiTheme.DIM)
		if lvl > 0:
			_side_line("Jetzt: " + String(ShopData.step(sid, lvl - 1).get("desc", "")),
				14, UiTheme.TEXT)
		if lvl < int(entry.get("max", 3)):
			_side_line("Stufe %d: " % (lvl + 1) + String(ShopData.step(sid, lvl).get("desc", "")),
				15, UiTheme.TEXT)
			_side_line("Preis im Spiel: %s Punkte" % _fmt(ShopData.cost(sid, lvl)), 13, UiTheme.DIM)
		else:
			_side_line("Vollständig ausgebaut.", 14, UiTheme.OK)
	else:
		_side_line("Debug", 20, UiTheme.ACCENT, true)
		_side_line("Aktionen zum Testen. Änderungen an Upgrades gelten sofort und werden "
			+ "im Spielstand gesichert.", 14, UiTheme.TEXT)

func _side_line(text: String, size: int, color: Color, bold := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.font_bold() if bold else UiTheme.font_regular())
	l.add_theme_font_size_override("font_size", UiTheme.size(size))
	l.add_theme_color_override("font_color", color)
	side_box.add_child(l)
