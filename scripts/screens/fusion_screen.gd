extends "res://scripts/core/ui_screen.gd"
## Sammelbuch: oben die zwölf Meisterevolutionen (Rezept aus zwei Eltern, eigene neue
## Mechanik; unentdeckt als „???“ mit den Eltern als Hinweis), darunter die übrigen
## Verschmelzungen, bei denen beide Evolutionen gemeinsam stärker werden.

func setup(_args: Dictionary) -> void:
	title_key = "Verschmelzungen"
	list_width = 420
	back_enabled = true
	prompt_context = "menu"

func build_items() -> void:
	var pairs := Data.all_fusions()
	var found := 0
	for pair in pairs:
		if Save.is_fusion_seen(Data.fusion_key(String(pair[0]), String(pair[1]))):
			found += 1
	var masters_found := 0
	for m in Data.MASTERS:
		if Save.is_master_seen(String(m.id)):
			masters_found += 1
	subtitle_override = Loc.tx("Meisterevolutionen %d von %d · Verschmelzungen %d von %d entdeckt") % [
		masters_found, Data.MASTERS.size(), found, pairs.size()]
	footer_text = "Verschmolzen: Prozentwerte +50 %, Zählwerte +1, Auslöseschwellen −25 %, Sonderwirkungen stärker. Nachteile bleiben."
	var list: Array = []
	list.append({"kind": "label", "text": Loc.tx("MEISTEREVOLUTIONEN"), "size": 13, "color": UiTheme.ACCENT})
	for m in Data.MASTERS:
		var seen_m := Save.is_master_seen(String(m.id))
		var pa := Data.evo(String(m.parents[0]))
		var pb := Data.evo(String(m.parents[1]))
		list.append({"kind": "choice", "id": "master:" + String(m.id), "compact": true,
			"text": "%s  ←  %s + %s" % [Loc.tx(String(m.name)) if seen_m else "???", Loc.tx(String(pa.name)), Loc.tx(String(pb.name))],
			"value_text": "entdeckt" if seen_m else "noch nicht entdeckt",
			"value_color": UiTheme.ACCENT if seen_m else UiTheme.DIM, "dim": not seen_m})
	var last_family := ""
	for pair in pairs:
		var a := Data.evo(String(pair[0]))
		var b := Data.evo(String(pair[1]))
		var family := String(a.get("family", ""))
		if family != last_family:
			list.append({"kind": "label", "text": Loc.tx("VERSCHMELZUNGEN") + "  ·  " + Loc.t("evo.family." + family).to_upper(),
				"size": 13, "color": UiTheme.family_color(family)})
			last_family = family
		var seen := Save.is_fusion_seen(Data.fusion_key(String(pair[0]), String(pair[1])))
		list.append({"kind": "choice", "id": Data.fusion_key(String(pair[0]), String(pair[1])), "compact": true,
			"text": "%s × %s" % [Loc.tx(String(a.get("name", ""))), Loc.tx(String(b.get("name", "")))],
			"value_text": "entdeckt" if seen else "noch nicht entdeckt",
			"value_color": UiTheme.OK if seen else UiTheme.DIM,
			"dim": not seen})
	items = list

## Rechts: beide Evolutionen mit Wirkung, ausgegraut, solange nicht entdeckt.
func _fill_side() -> void:
	if side_box == null:
		return
	for c in side_box.get_children():
		side_box.remove_child(c)
		c.queue_free()
	side_panel.visible = true
	if items.is_empty() or focus >= items.size() or not items[focus].has("id"):
		return
	var key := String(items[focus].id)
	if key.begins_with("master:"):
		_fill_master(key.trim_prefix("master:"))
		return
	var ids := key.split("+")
	var seen := Save.is_fusion_seen(key)
	var title := Label.new()
	title.text = "Verschmelzung" if seen else "Noch nicht entdeckt"
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.add_theme_font_size_override("font_size", UiTheme.size(20))
	title.add_theme_color_override("font_color", UiTheme.ACCENT if seen else UiTheme.DIM)
	side_box.add_child(title)
	for id in ids:
		var e := Data.evo(String(id))
		var name := Label.new()
		name.text = String(e.get("name", id))
		name.add_theme_font_override("font", UiTheme.font_bold())
		name.add_theme_font_size_override("font_size", UiTheme.size(16))
		name.add_theme_color_override("font_color", UiTheme.family_color(String(e.get("family", "sting"))) if seen else UiTheme.DIM)
		side_box.add_child(name)
		var desc := Label.new()
		desc.text = String(e.get("desc", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", UiTheme.size(14))
		desc.add_theme_color_override("font_color", UiTheme.TEXT if seen else UiTheme.DIM)
		side_box.add_child(desc)
	var how := Label.new()
	how.text = "Besitzt du beide in einem Lauf, verschmelzen sie: beide Wirkungen werden stärker." if seen \
		else "Wähle beide Evolutionen im selben Lauf, um diese Verschmelzung zu entdecken."
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_font_size_override("font_size", UiTheme.size(13))
	how.add_theme_color_override("font_color", UiTheme.ACCENT2 if seen else UiTheme.DIM)
	side_box.add_child(how)

func _side_label(text: String, size: int, color: Color, bold := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		l.add_theme_font_override("font", UiTheme.font_bold())
	l.add_theme_font_size_override("font_size", UiTheme.size(size))
	l.add_theme_color_override("font_color", color)
	side_box.add_child(l)

## Rechts für Meisterevolutionen: Name und neue Wirkung (unentdeckt: ???), Eltern als Rezept.
func _fill_master(id: String) -> void:
	var m := Data.master(id)
	var seen := Save.is_master_seen(id)
	_side_label(Loc.tx("Meisterevolution"), 13, UiTheme.ACCENT2)
	_side_label(Loc.tx(String(m.name)) if seen else "???", 21, UiTheme.ACCENT if seen else UiTheme.DIM, true)
	_side_label(Loc.tx(String(m.desc)) if seen else Loc.tx("Wirkung noch unbekannt."), 14, UiTheme.TEXT if seen else UiTheme.DIM)
	_side_label(Loc.tx("Rezept"), 13, UiTheme.ACCENT2)
	for pid in m.parents:
		var e := Data.evo(String(pid))
		_side_label("◆ " + Loc.tx(String(e.name)), 15, UiTheme.family_color(String(e.family)), true)
	_side_label(Loc.tx("Besitze beide im selben Run, eine davon auf Höchststufe: Am nächsten Levelende erscheint die goldene Meisterkarte. Die Eltern bleiben erhalten."),
		13, UiTheme.DIM)

func on_focus_changed(_index: int) -> void:
	_fill_side()

func on_activate(_index: int) -> void:
	pass

func on_adjust(_index: int, _dir: int) -> void:
	pass

func do_back() -> void:
	app.pop_screen()
