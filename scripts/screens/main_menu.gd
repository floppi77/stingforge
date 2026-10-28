extends "res://scripts/core/ui_screen.gd"
## Das Hauptmenü ist eine eigene Komposition nach der gelieferten Layoutvorlage.
## Die geerbten Eingaberouten und alle Aktionshandler bleiben unverändert.
const HERO := preload("res://assets/ui/title/hero_px.png")
const GOLD_TITLE := preload("res://assets/ui/title/logo_px.png")
const LOCK := preload("res://scripts/core/main_menu_lock.gd")
const Backdrop := preload("res://scripts/core/ui_backdrop.gd")
const GOLD := Color("#ffd666")
const INK := Color("#fff4dc")
const MUTED := Color("#8f92b4")
const SHADOW := Color("#1a0d06")
var _confirm_quit: Control = null
var _first_focus := true
var _background: TextureRect
var _readability: TextureRect
var _footer_rule: TextureRect
var _motes: Control
var _t := 0.0

func _ready() -> void:
	title_key = "game.title"
	subtitle_key = "game.subtitle"
	prompt_context = "main"
	super._ready()
	if not resized.is_connected(_layout_reference): resized.connect(_layout_reference)
	_layout_reference.call_deferred()

func _process(delta: float) -> void:
	_t += delta
	if logo_rect != null and is_visible_in_tree():
		# Logo schwebt sanft, im Pixelraster des Logos (2 Bildpunkte je Schritt).
		var unit := maxf(1.0, round(_logo_scale()))
		logo_rect.position.y = _logo_y + round(sin(_t * 1.6) * 2.0) * unit
	# Der gewählte Eintrag bleibt immer sichtbar, auch wenn ein verspäteter
	# Neuaufbau (Schriftgröße, Rückkehr aus Untermenüs) die Liste zurücksetzt.
	if is_visible_in_tree():
		_scroll_focus_into_view()
	super._process(delta)

var _logo_y := 0.0

func _logo_scale() -> float:
	return maxf(1.0, floor(size.y / 540.0))

func _build_base() -> void:
	theme = UiTheme.make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background = TextureRect.new()
	_background.texture = HERO
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Gespiegelt: Die Biene fliegt rechts ins Bild, links bleibt Raum für Logo und Menü.
	_background.flip_h = true
	add_child(_background)
	# Lesbarkeit links: dunkles Indigo, nach rechts in die Szene auslaufend.
	_readability = TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.03, 0.025, 0.08, 0.82), Color(0.03, 0.025, 0.08, 0.55),
		Color(0.03, 0.025, 0.08, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.52])
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.width = 512
	ramp.height = 2
	ramp.fill_from = Vector2.ZERO
	ramp.fill_to = Vector2.RIGHT
	_readability.texture = ramp
	_readability.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_readability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_readability)
	_motes = Backdrop.new()
	_motes.motes_only = true
	add_child(_motes)
	logo_rect = TextureRect.new()
	logo_rect.texture = GOLD_TITLE
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo_rect)
	title_label = Label.new()
	title_label.visible = false
	add_child(title_label)
	subtitle_label = Label.new()
	# Breite vor dem Text setzen, damit Autowrap nicht zunächst bei 0 px misst.
	subtitle_label.size = Vector2(760, 44)
	subtitle_label.add_theme_font_override("font", UiTheme.font_caps())
	subtitle_label.add_theme_font_size_override("font_size", 16 if UiTheme.ui_scale() < 1.4 else 24)
	subtitle_label.add_theme_color_override("font_color", GOLD)
	subtitle_label.add_theme_color_override("font_shadow_color", SHADOW)
	subtitle_label.add_theme_constant_override("shadow_offset_x", 2)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle_label)
	# Kompatible Felder für die gemeinsamen Layout-/Eingabeprüfungen.
	header_box = VBoxContainer.new()
	header_box.visible = false
	add_child(header_box)
	eyebrow_label = Label.new()
	header_box.add_child(eyebrow_label)
	note_label = Label.new()
	header_box.add_child(note_label)
	hint_label = Label.new()
	hint_label.visible = false
	add_child(hint_label)
	footer_label = Label.new()
	footer_label.visible = false
	add_child(footer_label)
	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(scroll_container)
	list_margin = MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_right", 8)
	list_margin.add_theme_constant_override("margin_left", 8)
	list_margin.add_theme_constant_override("margin_top", 6)
	list_margin.add_theme_constant_override("margin_bottom", 6)
	scroll_container.add_child(list_margin)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 0)
	list_margin.add_child(list_box)
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(side_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 30)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 22)
	side_panel.add_child(margin)
	side_box = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 8)
	margin.add_child(side_box)
	_footer_rule = TextureRect.new()
	_footer_rule.texture = UiTheme.kit("divider")
	_footer_rule.stretch_mode = TextureRect.STRETCH_TILE
	_footer_rule.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer_rule)
	prompt_bar = HFlowContainer.new()
	prompt_bar.size = Vector2(1760, 74)
	prompt_bar.add_theme_constant_override("h_separation", 36)
	prompt_bar.add_theme_constant_override("v_separation", 10)
	add_child(prompt_bar)

## Komposition im 1920 × 1080-Raster; bei Ultrawide wächst nur die Bildbreite.
func _layout_reference() -> void:
	if _background == null: return
	var k := size.y / 1080.0
	# Titelbild ganzzahlig vergrößert (scharfe Pixel), mittig beschnitten.
	var img := Vector2(HERO.get_width(), HERO.get_height())
	var px := maxf(1.0, ceil(maxf(size.x / img.x, size.y / img.y)))
	_background.size = img * px
	_background.position = ((size - _background.size) * 0.5).round()
	_readability.position = Vector2.ZERO
	_readability.size = Vector2(maxf(size.x, 1920.0 * k), size.y)
	_motes.position = Vector2.ZERO
	_motes.size = size
	var ls := _logo_scale()
	var logo := Vector2(GOLD_TITLE.get_width(), GOLD_TITLE.get_height()) * ls
	logo_rect.size = logo
	_logo_y = round(34.0 * k)
	logo_rect.position = Vector2(round(58.0 * k), _logo_y)
	subtitle_label.position = Vector2(round(96.0 * k), round(_logo_y + logo.y + 4.0 * k))
	var subtitle_height := maxf(40.0 * k, subtitle_label.get_combined_minimum_size().y)
	subtitle_label.size = Vector2(760 * k, subtitle_height)
	var menu_top := subtitle_label.position.y + subtitle_height + 10.0 * k
	var menu_bottom := 944.0 * k
	scroll_container.position = Vector2(round(70.0 * k), round(menu_top))
	scroll_container.size = Vector2(round(640.0 * k), menu_bottom - menu_top)
	var card_min := side_panel.get_combined_minimum_size()
	var card_height := maxf(300.0 * k, card_min.y)
	var card_width := maxf(560.0 * k, card_min.x)
	side_panel.position = Vector2(round(size.x - 64.0 * k - card_width), round(960.0 * k - card_height))
	side_panel.size = Vector2(card_width, card_height)
	_footer_rule.position = Vector2(round(80.0 * k), round(958.0 * k))
	_footer_rule.size = Vector2(round(620.0 * k), 8)
	prompt_bar.position = Vector2(round(80.0 * k), round(984.0 * k))
	prompt_bar.size = Vector2(1760.0 * k, 74.0 * k)

func build_items() -> void:
	var has_campaign := Save.active_campaign and not Save.campaign.is_empty()
	var can_continue: bool = has_campaign and (not bool(Save.campaign.get("completed", false)) or not Save.campaign.get("pending", {}).is_empty())
	if app != null and String(app.menu_note) != "":
		subtitle_override = String(app.menu_note)
		app.menu_note = ""
	items = [
		{"kind": "action", "text": "menu.continue", "id": "continue", "disabled": not can_continue,
			"value_text": "Level %02d" % int(Save.campaign.get("level", 1)) if has_campaign else ""},
		{"kind": "action", "text": "menu.new_campaign", "id": "new"},
		{"kind": "action", "text": "menu.training", "id": "training", "disabled": not _has_training()},
		{"kind": "action", "text": "menu.boss_rush", "id": "rush", "disabled": not bool(Save.profile.get("boss_rush_unlocked", false)),
			"secondary_text": "Nach Kampagnenabschluss" if not bool(Save.profile.get("boss_rush_unlocked", false)) else ""},
		{"kind": "action", "text": "Werkstatt", "id": "shop", "disabled": not has_campaign},
		{"kind": "action", "text": "menu.highscores", "id": "scores"},
		{"kind": "action", "text": "menu.settings", "id": "settings", "divider": true},
		{"kind": "action", "text": "menu.credits", "id": "credits"},
		{"kind": "action", "text": "menu.quit", "id": "quit"},
	]
	if _first_focus:
		focus = 0 if can_continue else 1
		_first_focus = false

func refresh() -> void:
	for row in _rows:
		if row.get_parent() != null: row.get_parent().remove_child(row)
		row.queue_free()
	_rows.clear()
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	subtitle_label.text = subtitle_override if subtitle_override != "" else Loc.t(subtitle_key)
	for i in range(items.size()):
		var row := _make_reference_row(items[i])
		if items[i].get("divider", false):
			var rule := TextureRect.new()
			rule.texture = UiTheme.kit("divider")
			rule.stretch_mode = TextureRect.STRETCH_TILE
			rule.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rule.custom_minimum_size = Vector2(0, 10)
			rule.stretch_mode = TextureRect.STRETCH_TILE
			rule.modulate = Color(1, 1, 1, 0.55)
			list_box.add_child(rule)
		list_box.add_child(row)
		_rows.append(row)
		_wire_mouse(row, i)
	_build_profile()
	_refresh_prompts()
	_clamp_focus()
	_update_focus_visuals()
	_layout_reference.call_deferred()

func _make_reference_row(it: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_skin(false))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var marker := TextureRect.new()
	marker.name = "Marker"
	marker.texture = UiTheme.kit("cursor")
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.custom_minimum_size = Vector2(24, 24)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(marker)
	if it.get("disabled", false):
		var lock := LOCK.new()
		lock.name = "Lock"
		lock.custom_minimum_size = Vector2(20, 26)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock)
		marker.custom_minimum_size.x = 0
		marker.visible = false
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", -10)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var label := Label.new()
	label.text = Loc.t(String(it.text))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.add_theme_font_size_override("font_size", UiTheme.size(17))
	label.add_theme_color_override("font_color", MUTED if it.get("disabled", false) else INK)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	text_box.add_child(label)
	panel.set_meta("label", label)
	if String(it.get("secondary_text", "")) != "":
		var description := Label.new()
		description.text = String(it.secondary_text)
		description.add_theme_font_override("font", UiTheme.font_regular())
		description.add_theme_font_size_override("font_size", UiTheme.size(11))
		description.add_theme_color_override("font_color", MUTED)
		text_box.add_child(description)
	if String(it.get("value_text", "")) != "":
		var value := Label.new()
		value.text = String(it.value_text)
		value.add_theme_font_override("font", UiTheme.font_caps())
		value.add_theme_font_size_override("font_size", 16 if UiTheme.ui_scale() < 1.4 else 24)
		value.add_theme_color_override("font_color", GOLD)
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(value)
	return panel

func _row_skin(selected: bool) -> StyleBox:
	if selected:
		var sb := UiTheme.framed("row_focus", 8, 0)
		for side in ["left", "right", "top", "bottom"]: sb.set("content_margin_" + side, 0)
		return sb
	return StyleBoxEmpty.new()

func _update_focus_visuals() -> void:
	for i in range(_rows.size()):
		var row := _rows[i]
		row.add_theme_stylebox_override("panel", _row_skin(i == focus))
		var marker := row.find_child("Marker", true, false) as CanvasItem
		if marker != null: marker.modulate.a = 1.0 if i == focus else 0.0
		var label: Label = row.get_meta("label")
		if label != null and not items[i].get("disabled", false):
			label.add_theme_color_override("font_color", GOLD if i == focus else INK)
	_scroll_focus_into_view()
	# Nach einem Neuaufbau (Schriftgröße, Rückkehr) stehen Zeilenhöhen und
	# Scrollgrenze erst nach der Anordnung fest: dann noch einmal nachführen.
	_scroll_after_layout.call_deferred()

func _scroll_after_layout() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_scroll_focus_into_view()

func _scroll_focus_into_view() -> void:
	if focus >= _rows.size() or scroll_container == null or not is_instance_valid(_rows[focus]):
		return
	# In Bildschirmkoordinaten vergleichen: Ränder des Listencontainers zählen mit.
	var sel := _rows[focus]
	var r := sel.get_global_rect()
	var box := scroll_container.get_global_rect()
	if r.position.y < box.position.y:
		scroll_container.scroll_vertical -= int(ceil(box.position.y - r.position.y)) + 2
	elif r.end.y > box.end.y:
		scroll_container.scroll_vertical += int(ceil(r.end.y - box.end.y)) + 2

func _build_profile() -> void:
	for child in side_box.get_children():
		side_box.remove_child(child)
		child.queue_free()
	var active := Save.active_campaign and not Save.campaign.is_empty()
	var lv := int(Save.campaign.get("level", 1)) if active else 1
	var difficulty := String(Save.campaign.get("difficulty", "normal")) if active else String(Save.g("game.difficulty", "normal"))
	var best := 0
	for record in (Save.profile.get("best", {}) as Dictionary).values():
		if record is Dictionary: best = maxi(best, int(record.get("score", 0)))
	var points := int(Save.campaign.get("points", 0)) if active else 0
	var unlocked: int = (Save.profile.unlocked_evolutions as Array).size()
	var total := Data.EVOLUTIONS.size()
	var head := Label.new()
	head.text = "DEIN BIENENSTOCK"
	head.add_theme_font_override("font", UiTheme.font_caps())
	head.add_theme_font_size_override("font_size", 16 if UiTheme.ui_scale() < 1.4 else 24)
	head.add_theme_color_override("font_color", UiTheme.ACCENT2)
	side_box.add_child(head)
	_profile_rule()
	_profile_line("LEVEL %02d / 10" % lv if active else "NEUER FLUG", Loc.t(String(Data.DIFFICULTY.get(difficulty, Data.DIFFICULTY.normal).name)), 20, 13, INK)
	var evo_row := HBoxContainer.new()
	evo_row.add_theme_constant_override("separation", 16)
	evo_row.add_child(_text("Evolutionen", 13, INK))
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(120, 12)
	bar.max_value = maxi(1, total)
	bar.value = unlocked
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#0c0d22")
	track.border_color = Color("#465284")
	track.set_border_width_all(2)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.ACCENT2
	fill.border_color = Color("#0c0d22")
	fill.set_border_width_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	evo_row.add_child(bar)
	evo_row.add_child(_text("%d / %d" % [unlocked, total], 13, INK, true))
	side_box.add_child(evo_row)
	_profile_rule()
	_profile_line("Werkstatt", _pretty_points(points) + " Punkte", 13, 13, GOLD)
	_profile_line("Bestpunkte", _pretty_points(best), 13, 13, INK)

func _profile_rule() -> void:
	var rule := TextureRect.new()
	rule.texture = UiTheme.kit("divider")
	rule.stretch_mode = TextureRect.STRETCH_TILE
	rule.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rule.custom_minimum_size = Vector2(0, 8)
	rule.modulate = Color(1, 1, 1, 0.7)
	side_box.add_child(rule)

func _profile_line(left: String, right: String, ls: int, rs: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := _text(left, ls, INK, ls > 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(_text(right, rs, color, true))
	side_box.add_child(row)

func _text(value: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", UiTheme.font_bold() if bold else UiTheme.font_semi())
	label.add_theme_font_size_override("font_size", UiTheme.size(font_size))
	label.add_theme_color_override("font_color", color)
	return label

func _pretty_points(n: int) -> String:
	var raw := str(n)
	var out := ""
	for i in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0: out += "."
		out += raw[i]
	return out

func _has_training() -> bool:
	for lv in Save.campaign.get("level_scores", {}).keys():
		return true
	return bool(Save.profile.get("boss_rush_unlocked", false)) or (Save.profile.unlocked_evolutions as Array).size() > 0

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	match String(it.get("id", "")):
		"new":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			_open_new_campaign()
		"continue":
			if Save.active_campaign:
				Audio.sfx("ui_ok", -6.0, 1.0, true)
				app.continue_campaign()
		"training":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.push_screen("res://scripts/screens/training_screen.gd", {})
		"rush":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.push_screen("res://scripts/screens/difficulty_screen.gd", {"run_mode": "rush"})
		"scores":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.push_screen("res://scripts/screens/highscore_screen.gd", {})
		"shop":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.push_screen("res://scripts/screens/shop_screen.gd",
				{"from": "menu", "level": int(Save.campaign.get("level", 1))})
		"settings":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
		"credits":
			Audio.sfx("ui_ok", -6.0, 1.0, true)
			app.push_screen("res://scripts/screens/credits_screen.gd", {})
		"quit":
			Audio.sfx("ui_back", -6.0, 1.0, true)
			_confirm_quit = app.push_screen("res://scripts/screens/confirm_screen.gd", {
				"title": "menu.quit",
				"message": "menu.quit_warn",
				"on_yes": func(): app.quit_to_desktop(),
			})

func _open_new_campaign() -> void:
	if Save.active_campaign and not Save.campaign.is_empty():
		app.push_screen("res://scripts/screens/confirm_screen.gd", {
			"title": "menu.new_campaign",
			"message": "menu.new_campaign_warn",
			"on_yes": func(): _choose_difficulty(),
		})
	else:
		_choose_difficulty()

func _choose_difficulty() -> void:
	app.push_screen("res://scripts/screens/difficulty_screen.gd", {})

func do_back() -> void:
	# Im Hauptmenü beendet Esc nicht das Spiel.
	Audio.sfx("deny", -12.0, 1.0, true)

func on_return() -> void:
	rebuild()
	refresh()
