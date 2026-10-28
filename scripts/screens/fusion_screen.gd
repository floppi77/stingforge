extends "res://scripts/core/ui_screen.gd"
## Übersicht aller Verschmelzungen: zwei Evolutionen eines Synergiepaars werden
## zusammen stärker. Noch nicht entdeckte Paare stehen ausgegraut in der Liste;
## einmal im Lauf gebildet, sind sie im Profil dauerhaft freigeschaltet.

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
	subtitle_override = "Zwei passende Evolutionen verschmelzen und werden gemeinsam stärker · %d von %d entdeckt" % [found, pairs.size()]
	footer_text = "Verschmolzen: Prozentwerte +50 %, Zählwerte +1, Auslöseschwellen −25 %, Sonderwirkungen stärker. Nachteile bleiben."
	var list: Array = []
	var last_family := ""
	for pair in pairs:
		var a := Data.evo(String(pair[0]))
		var b := Data.evo(String(pair[1]))
		var family := String(a.get("family", ""))
		if family != last_family:
			list.append({"kind": "label", "text": Loc.t("evo.family." + family).to_upper(), "size": 13,
				"color": UiTheme.family_color(family)})
			last_family = family
		var seen := Save.is_fusion_seen(Data.fusion_key(String(pair[0]), String(pair[1])))
		list.append({"kind": "choice", "id": Data.fusion_key(String(pair[0]), String(pair[1])), "compact": true,
			"text": "%s × %s" % [String(a.get("name", "")), String(b.get("name", ""))],
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

func on_focus_changed(_index: int) -> void:
	_fill_side()

func on_activate(_index: int) -> void:
	pass

func on_adjust(_index: int, _dir: int) -> void:
	pass

func do_back() -> void:
	app.pop_screen()
