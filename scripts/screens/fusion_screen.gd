extends "res://scripts/core/ui_screen.gd"
## Sammelbuch: oben die zwölf Meisterevolutionen (Rezept aus zwei Eltern, eigene neue
## Mechanik; unentdeckt als „???“ mit den Eltern als Hinweis), darunter die übrigen
## Verschmelzungen, bei denen beide Evolutionen gemeinsam stärker werden.
## Gold (★) = Meister, Türkis (◆) = Verschmelzung. Rechts läuft die Hilfsgrafik, sobald
## das Rezept im Profil entdeckt ist (runübergreifend).

const Recipes := preload("res://scripts/core/evo_recipes.gd")

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
	list.append({"kind": "label", "text": Loc.tx("★ MEISTEREVOLUTIONEN  %d/%d") % [masters_found, Data.MASTERS.size()],
		"size": 13, "color": Recipes.MASTER})
	for m in Data.MASTERS:
		var seen_m := Save.is_master_seen(String(m.id))
		list.append({"kind": "choice", "id": "master:" + String(m.id), "compact": true,
			"text": "%s + %s" % [Loc.tx(String(Data.evo(String(m.parents[0])).name)), Loc.tx(String(Data.evo(String(m.parents[1])).name))],
			"value_text": "★ " + Loc.tx(String(m.name)) if seen_m else "???",
			"value_color": Recipes.MASTER if seen_m else UiTheme.DIM, "dim": not seen_m})
	list.append({"kind": "label", "text": Loc.tx("◆ VERSCHMELZUNGEN  %d/%d") % [found, pairs.size()],
		"size": 13, "color": Recipes.FUSION})
	var last_family := ""
	for pair in pairs:
		var a := Data.evo(String(pair[0]))
		var b := Data.evo(String(pair[1]))
		var family := String(a.get("family", ""))
		if family != last_family:
			list.append({"kind": "label", "text": Loc.t("evo.family." + family).to_upper(),
				"size": 11, "color": UiTheme.family_color(family)})
			last_family = family
		var seen := Save.is_fusion_seen(Data.fusion_key(String(pair[0]), String(pair[1])))
		list.append({"kind": "choice", "id": Data.fusion_key(String(pair[0]), String(pair[1])), "compact": true,
			"text": "%s + %s" % [Loc.tx(String(a.get("name", ""))), Loc.tx(String(b.get("name", "")))],
			"value_text": "◆ " + Loc.tx("entdeckt") if seen else "???",
			"value_color": Recipes.FUSION if seen else UiTheme.DIM,
			"dim": not seen})
	items = list

## Rechts: Hilfsgrafik (erst nach Entdeckung), Rezeptzeile, beide Evolutionen mit Wirkung.
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
	_side_label(Loc.tx("◆ Verschmelzung") if seen else Loc.tx("Noch nicht entdeckt"), 20,
		Recipes.FUSION if seen else UiTheme.DIM, true)
	_illustration(key if seen else "locked")
	_recipe(Recipes.fusion_line(String(ids[0]), String(ids[1]), Array(ids) if seen else []))
	for id in ids:
		var e := Data.evo(String(id))
		_side_label(Loc.tx(String(e.get("name", id))), 16,
			UiTheme.family_color(String(e.get("family", "sting"))) if seen else UiTheme.DIM, true)
		_side_label(Loc.tx(String(e.get("desc", ""))), 13, UiTheme.TEXT if seen else UiTheme.DIM)
	_side_label(Loc.tx("Besitzt du beide in einem Lauf, verschmelzen sie: beide Wirkungen werden stärker.") if seen \
		else Loc.tx("Wähle beide Evolutionen im selben Lauf, um diese Verschmelzung zu entdecken."),
		13, UiTheme.ACCENT2 if seen else UiTheme.DIM)

func _illustration(k: String) -> void:
	var ill := EvoIllustration.new()
	ill.custom_minimum_size = Vector2(0, UiTheme.pad(78))
	ill.name = "Illustration"
	ill.show_evo(k)
	side_box.add_child(ill)

func _recipe(bbcode: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", UiTheme.font_regular())
	r.add_theme_font_size_override("normal_font_size", UiTheme.size(14))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = bbcode
	r.name = "Recipe"
	side_box.add_child(r)

func _side_label(text: String, size: int, color: Color, bold := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		l.add_theme_font_override("font", UiTheme.font_bold())
	l.add_theme_font_size_override("font_size", UiTheme.size(size))
	l.add_theme_color_override("font_color", color)
	side_box.add_child(l)

## Rechts für Meisterevolutionen: Hilfsgrafik und Wirkung erst nach Entdeckung, Rezept immer.
func _fill_master(id: String) -> void:
	var m := Data.master(id)
	var seen := Save.is_master_seen(id)
	_side_label(Loc.tx("★ Meisterevolution"), 13, Recipes.MASTER)
	_side_label(Loc.tx(String(m.name)) if seen else "???", 21, Recipes.MASTER if seen else UiTheme.DIM, true)
	_illustration(id if seen else "locked")
	_recipe(Recipes.master_line(id, Array(m.parents) if seen else []))
	_side_label(Loc.tx(String(m.desc)) if seen else Loc.tx("Wirkung noch unbekannt."), 14, UiTheme.TEXT if seen else UiTheme.DIM)
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
