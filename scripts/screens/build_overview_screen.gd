extends "res://scripts/core/ui_screen.gd"

func _ready() -> void:
	list_width = 560
	title_key = "menu.build"
	subtitle_key = ""
	overlay_in_game = true
	super._ready()

func build_items() -> void:
	var list: Array = []
	var c: Dictionary = _live_build()
	var weapon := String(c.get("weapon", "base"))
	list.append({"kind": "label", "text": Loc.tx("Hauptwaffe: %s  (Stufe %d)") % [
		Loc.t("bar." + weapon), int(c.get("upgrades", {}).get(weapon, 1))], "size": 19, "color": UiTheme.ACCENT})
	list.append({"kind": "label", "text": Loc.tx("Blütenstaub: %d   Punkte: %d   Leben: %d/%d") % [
		int(c.get("nectar", 0)), int(c.get("points", 0)), int(c.get("hp", 3)), int(c.get("max_hp", 3))],
		"size": 16})
	list.append({"kind": "sep"})
	list.append({"kind": "label", "text": "Aktive Evolutionen", "size": 20, "color": UiTheme.ACCENT2})
	var evos: Array = c.get("evolutions", [])
	if evos.is_empty():
		list.append({"kind": "label", "text": "evo.none_active", "size": 16, "color": UiTheme.DIM})
	for entry in evos:
		var e := Data.evo(String(entry.get("id", "")))
		if e.is_empty():
			continue
		var active := true
		var w := String(e.get("weapon", ""))
		if w != "" and int(c.get("upgrades", {}).get(w, 0)) <= 0:
			active = false
		list.append({
			"kind": "card", "text": String(e.name),
			"family": String(e.family),
			"value_text": Loc.tx("Stufe %d/%d") % [int(entry.get("level", 1)), int(e.max)],
			"lines": [
				{"text": String(e.desc), "size": 15, "color": UiTheme.TEXT},
				{"text": (Loc.tx("Inaktiv: benötigt ") + Loc.t("bar." + w)) if not active else (
					Loc.t("evo.synergy") % Loc.tx(String(Data.evo(String(e.get("synergy", ""))).get("name", "–")))
					if e.get("synergy", "") != "" else ""),
					"size": 13, "color": Color(1, 0.65, 0.5) if not active else UiTheme.DIM},
			],
		})
	list.append({"kind": "sep"})
	list.append({"kind": "label", "text": "Ausrüstung", "size": 20, "color": UiTheme.ACCENT2})
	for u in Data.UPGRADES:
		var lvl := int(c.get("upgrades", {}).get(u.id, 0))
		var txt := Loc.tx("%s: Stufe %d/%d") % [Loc.t(String(u.name)), lvl, int(u.max)]
		if u.id == "speed":
			txt += Loc.tx("  ·  gewähltes Tempo: %d") % int(c.get("speed_level", 0))
		list.append({"kind": "label", "text": txt, "size": 15})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "menu.back", "id": "back"})
	items = list

## Aus der Pause heraus zählt der laufende Stand, nicht der letzte Checkpoint-Save.
func _live_build() -> Dictionary:
	var c: Dictionary = Save.campaign.duplicate(true)
	if app == null or not app.is_in_game() or app.game.player == null:
		return c
	var p = app.game.player
	c.weapon = p.weapon
	c.upgrades = p.upgrades.duplicate(true)
	c.nectar = p.nectar
	c.points = p.points
	c.hp = p.hp
	c.max_hp = p.max_hp
	c.speed_level = p.speed_level
	return c

func on_activate(_index: int) -> void:
	app.pop_screen()

func do_back() -> void:
	app.pop_screen()
