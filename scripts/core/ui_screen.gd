extends Control
## Basis für alle Menübildschirme: fokusbasierte Liste, vollständig ohne Maus
## bedienbar, mit sichtbarem Fokus und zentraler Eingabesperre.

const UiTheme := preload("res://scripts/core/ui_theme.gd")
const UiPrompts := preload("res://scripts/core/ui_prompts.gd")
const UiBackdrop := preload("res://scripts/core/ui_backdrop.gd")
const UiVeil := preload("res://scripts/core/ui_veil.gd")
const Flags := preload("res://scripts/core/flags.gd")

signal closed(result: Variant)

var app: Node
var items: Array = []
var focus: int = 0
var title_key: String = ""
var subtitle_key: String = ""
## Ersetzt den Untertitel, ohne zusätzliche Höhe zu brauchen (z. B. Hinweise im Hauptmenü).
var subtitle_override: String = ""
var hint_override: String = ""
var footer_text: String = ""
var header_note: String = ""
var logo_name: String = ""
var show_background: bool = true
## Über einer laufenden Partie: durchscheinender Schleier statt Vollbildkulisse,
## damit die angehaltene Szene sichtbar bleibt (Pause, Game Over, Rückfragen).
var overlay_in_game: bool = false
var veil_tint: Color = Color(0.012, 0.035, 0.045)
## Stimmung der Menükulisse: "warm" oder "cool".
var backdrop_mood := "warm"
## Breite der Menüliste im 960er-Raster; 0 = volle Spaltenbreite. Menütexte sind
## kurz, breite Zeilen über den ganzen Bildschirm wirken leer.
var list_width := 340
var back_enabled: bool = true
var columns: int = 1
var scroll_container: ScrollContainer
var list_margin: MarginContainer
var list_box: VBoxContainer
var title_label: Label
var subtitle_label: Label
var hint_label: Label
var footer_label: Label
var note_label: Label
var grid_count: int = 0        # wie viele Einträge oben im Gitter stehen
var grid_cols: int = 1
var main_row: HBoxContainer
var side_panel: PanelContainer
var side_box: VBoxContainer
var side_builder: Callable = Callable()
var header_in_column: bool = false
var left_col: VBoxContainer
var grid_wrap: VBoxContainer
var grid_box: GridContainer
var grid_extra: VBoxContainer
var logo_rect: TextureRect
var header_box: VBoxContainer
var body_box: VBoxContainer
var _rows: Array[Control] = []
var _focus_released := false
var prompt_bar: HFlowContainer
var tab_bar: HBoxContainer
var eyebrow_label: Label
## Ausschließlich Anzeige-Kontext; verändert keine Eingaberouten.
var prompt_context: String = "menu"
var _focus_tween: Tween

func _ready() -> void:
	# In einer CanvasLayer greifen Anker nicht: Größe explizit setzen.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fit_to_canvas()
	if not get_viewport().size_changed.is_connected(_fit_to_canvas):
		get_viewport().size_changed.connect(_fit_to_canvas)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_base()
	build_items()
	refresh()
	Bindings.block_all()
	set_process(true)

## Liste auf list_width begrenzen, aber nie breiter als die verfügbare Spalte.
func _fit_list_width() -> void:
	if scroll_container == null or left_col == null:
		return
	if list_width <= 0:
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size.x = 0
		return
	var want := minf(float(UiTheme.pad(list_width)), left_col.size.x)
	scroll_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if absf(scroll_container.custom_minimum_size.x - want) > 0.5:
		scroll_container.custom_minimum_size.x = want

func _fit_to_canvas() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if vs.x > 1.0 and vs.y > 1.0:
		position = Vector2.ZERO
		size = vs

func _build_base() -> void:
	theme = UiTheme.make_theme()
	if show_background:
		var in_game: bool = overlay_in_game and app != null and app.has_method("is_in_game") and app.is_in_game()
		var bg: Control = UiVeil.new() if in_game else UiBackdrop.new()
		if in_game:
			bg.tint = veil_tint
		else:
			bg.mood = backdrop_mood
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UiTheme.pad(40))
	margin.add_theme_constant_override("margin_right", UiTheme.pad(40))
	margin.add_theme_constant_override("margin_top", UiTheme.pad(24))
	margin.add_theme_constant_override("margin_bottom", UiTheme.pad(18))
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.pad(14))
	margin.add_child(outer)

	header_box = VBoxContainer.new()
	header_box.add_theme_constant_override("separation", UiTheme.pad(4))
	if not header_in_column:
		outer.add_child(header_box)
	eyebrow_label = Label.new()
	eyebrow_label.text = "STINGFORGE · EVOLVE. ADAPT. STRIKE."
	eyebrow_label.add_theme_font_override("font", UiTheme.font_caps())
	eyebrow_label.add_theme_font_size_override("font_size", UiTheme.size(8))
	eyebrow_label.add_theme_color_override("font_color", UiTheme.ACCENT2)
	header_box.add_child(eyebrow_label)
	logo_rect = TextureRect.new()
	logo_rect.visible = false
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo_rect.custom_minimum_size = Vector2(0, UiTheme.size(62))
	header_box.add_child(logo_rect)
	title_label = Label.new()
	title_label.add_theme_font_override("font", UiTheme.font_display())
	title_label.add_theme_font_size_override("font_size", UiTheme.size(36))
	title_label.add_theme_color_override("font_color", UiTheme.TEXT)
	# Pixel-Schlagschatten: harter Versatz statt weicher Unschärfe.
	title_label.add_theme_color_override("font_shadow_color", Color("#3a1e0a"))
	title_label.add_theme_constant_override("shadow_offset_x", UiTheme.pad(2))
	title_label.add_theme_constant_override("shadow_offset_y", UiTheme.pad(2))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_override("font", UiTheme.font_regular())
	subtitle_label.add_theme_font_size_override("font_size", UiTheme.size(14))
	subtitle_label.add_theme_color_override("font_color", UiTheme.DIM)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(subtitle_label)
	note_label = Label.new()
	note_label.add_theme_font_override("font", UiTheme.font_semi())
	note_label.add_theme_font_size_override("font_size", UiTheme.size(13))
	note_label.add_theme_color_override("font_color", UiTheme.ACCENT2)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.visible = false
	header_box.add_child(note_label)
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", UiTheme.pad(5))
	tab_bar.visible = false
	header_box.add_child(tab_bar)

	body_box = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", UiTheme.pad(8))
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body_box)
	main_row = HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", UiTheme.pad(22))
	body_box.add_child(main_row)
	left_col = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", UiTheme.pad(14))
	main_row.add_child(left_col)
	if header_in_column:
		left_col.add_child(header_box)

	grid_wrap = VBoxContainer.new()
	grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_wrap.visible = false
	left_col.add_child(grid_wrap)
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_wrap.add_child(top_spacer)
	grid_box = GridContainer.new()
	grid_box.columns = 1
	grid_box.add_theme_constant_override("h_separation", UiTheme.pad(12))
	grid_box.add_theme_constant_override("v_separation", UiTheme.pad(10))
	grid_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_wrap.add_child(grid_box)
	var bot_spacer := Control.new()
	bot_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_wrap.add_child(bot_spacer)
	grid_extra = VBoxContainer.new()
	grid_extra.add_theme_constant_override("separation", UiTheme.pad(6))
	grid_wrap.add_child(grid_extra)
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.resized.connect(_fit_list_width)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(scroll_container)
	list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_right", UiTheme.pad(10))
	list_margin.add_theme_constant_override("margin_left", UiTheme.pad(2))
	list_margin.add_theme_constant_override("margin_top", UiTheme.pad(2))
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(list_margin)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", UiTheme.pad(5))
	list_margin.add_child(list_box)

	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	side_panel.custom_minimum_size = Vector2(UiTheme.size(280), 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.visible = false
	main_row.add_child(side_panel)
	side_box = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", UiTheme.pad(9))
	var side_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		side_margin.add_theme_constant_override("margin_" + side, UiTheme.pad(18))
	var side_scroll := preload("res://scripts/core/ui_detail_scroll.gd").new()
	side_scroll.screen = self
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_box)
	side_margin.add_child(side_scroll)
	side_panel.add_child(side_margin)

	var divider := TextureRect.new()
	divider.texture = UiTheme.kit("divider")
	divider.stretch_mode = TextureRect.STRETCH_TILE
	divider.custom_minimum_size = Vector2(0, 8)
	divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	divider.modulate = Color(1, 1, 1, 0.8)
	body_box.add_child(divider)
	prompt_bar = HFlowContainer.new()
	prompt_bar.name = "DualDevicePrompts"
	prompt_bar.add_theme_constant_override("h_separation", UiTheme.pad(18))
	prompt_bar.add_theme_constant_override("v_separation", UiTheme.pad(5))
	body_box.add_child(prompt_bar)
	# Nur für Kontextmeldungen und die unveränderte Neubelegungsfunktion.
	hint_label = Label.new()
	hint_label.add_theme_font_override("font", UiTheme.font_semi())
	hint_label.add_theme_font_size_override("font_size", UiTheme.size(12))
	hint_label.add_theme_color_override("font_color", UiTheme.ACCENT2)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.visible = false
	body_box.add_child(hint_label)
	footer_label = Label.new()
	footer_label.add_theme_font_override("font", UiTheme.font_regular())
	footer_label.add_theme_font_size_override("font_size", UiTheme.size(11))
	footer_label.add_theme_color_override("font_color", UiTheme.DIM)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_box.add_child(footer_label)

## Tatsächliche Bindungen beider Geräteklassen; die Logik bleibt in Bindings.
func _refresh_prompts() -> void:
	for c in prompt_bar.get_children():
		prompt_bar.remove_child(c)
		c.queue_free()
	prompt_bar.add_child(UiPrompts.make_navigation_hint(columns > 1))
	prompt_bar.add_child(UiPrompts.make_hint("ui_accept", "Bestätigen", true))
	if back_enabled and prompt_context not in ["main", "gameover"]:
		prompt_bar.add_child(UiPrompts.make_hint("ui_cancel", "Zurück", true))
	if prompt_context == "settings":
		var tabs_hint := HBoxContainer.new()
		tabs_hint.add_theme_constant_override("separation", UiTheme.pad(4))
		tabs_hint.add_child(UiPrompts.make_badges("upgrade_prev", "both", true))
		tabs_hint.add_child(UiPrompts.make_hint("upgrade_next", "Reiter", true))
		prompt_bar.add_child(tabs_hint)


func build_items() -> void:
	pass

func refresh() -> void:
	# Beim Neuaufbau (z. B. nach einem Kauf) bleibt die Liste stehen: Höhe und
	# Scrollposition werden gehalten, bis die neuen Zeilen angeordnet sind.
	var keep_scroll := scroll_container.scroll_vertical if scroll_container != null else 0
	if list_box != null and scroll_container != null and scroll_container.visible:
		list_box.custom_minimum_size.y = list_box.size.y
	for r in _rows:
		if r.get_parent() != null: r.get_parent().remove_child(r)
		r.queue_free()
	_rows.clear()
	# Auch Abstandshalter zwischen Gruppen gehören zur alten Liste.
	if list_box != null:
		for c in list_box.get_children():
			list_box.remove_child(c)
			c.queue_free()
	if logo_name != "" and Art.has(logo_name):
		var tex: Texture2D = Art.sheet(logo_name)
		logo_rect.texture = tex
		logo_rect.visible = true
		title_label.visible = false
	else:
		logo_rect.visible = false
		title_label.visible = true
	title_label.text = Loc.t(title_key) if title_key != "" else ""
	if subtitle_override != "":
		subtitle_label.text = subtitle_override
		subtitle_label.visible = true
	else:
		subtitle_label.text = Loc.t(subtitle_key) if subtitle_key != "" else ""
		subtitle_label.visible = subtitle_key != ""
	note_label.text = header_note
	note_label.visible = header_note != ""
	var use_grid := columns > 1
	grid_wrap.visible = use_grid
	_fill_side()
	scroll_container.visible = not use_grid
	if use_grid:
		grid_box.columns = columns
		grid_cols = maxi(1, columns)
		grid_count = 0
	_refresh_prompts()
	hint_label.text = hint_override
	hint_label.visible = hint_override != ""
	footer_label.text = footer_text
	footer_label.visible = footer_text != ""
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var row := _make_row(it, i)
		if not use_grid and bool(it.get("spaced", false)):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, UiTheme.pad(8))
			list_box.add_child(gap)
		if use_grid:
			if String(it.get("kind", "action")) == "card":
				grid_count += 1
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid_box.add_child(row)
			else:
				grid_extra.add_child(row)
		else:
			list_box.add_child(row)
		_rows.append(row)
		_wire_mouse(row, i)
	_clamp_focus()
	_layout_pending = true
	if scroll_container != null:
		scroll_container.scroll_vertical = keep_scroll
	_update_focus_visuals()
	_settle_after_rebuild.call_deferred(keep_scroll)

var _layout_pending := false

## Nach der Anordnung der neuen Zeilen: Scrollposition wiederherstellen, die
## Platzhalterhöhe lösen und nur scrollen, falls der Fokus außerhalb liegt.
func _settle_after_rebuild(keep_scroll: int) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if scroll_container != null:
		scroll_container.scroll_vertical = keep_scroll
	if list_box != null:
		list_box.custom_minimum_size.y = 0
	_layout_pending = false
	_ensure_focus_visible()

## Holt den Fokus ins Bild, ohne zu springen, wenn er schon sichtbar ist.
func _ensure_focus_visible() -> void:
	if _layout_pending or scroll_container == null or not scroll_container.visible:
		return
	if focus >= _rows.size() or not is_instance_valid(_rows[focus]):
		return
	var sel: Control = _rows[focus]
	if sel.size.y <= 0.0:
		return
	var r := sel.get_global_rect()
	var box := scroll_container.get_global_rect()
	var pad := float(UiTheme.pad(4))
	if r.position.y < box.position.y:
		scroll_container.scroll_vertical -= int(ceil(box.position.y - r.position.y + pad))
	elif r.end.y > box.end.y:
		scroll_container.scroll_vertical += int(ceil(r.end.y - box.end.y + pad))

## Rechte Spalte: optionale Zusatzinfos (Hauptmenü). Leer = keine Spalte.
func _fill_side() -> void:
	if side_box == null:
		return
	for c in side_box.get_children():
		side_box.remove_child(c)
		c.queue_free()
	if not side_builder.is_valid():
		side_panel.visible = false
		return
	side_panel.visible = true
	side_builder.call(side_box)

func _make_row(it: Dictionary, idx: int) -> Control:
	var kind: String = it.get("kind", "action")
	if kind == "sep":
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, UiTheme.pad(6))
		return sp
	if kind == "label":
		if it.get("binding_header", false): return _make_binding_header()
		var l := Label.new()
		l.text = Loc.t(String(it.get("text", "")))
		l.add_theme_font_override("font", UiTheme.font_regular())
		l.add_theme_font_size_override("font_size", UiTheme.size(int(it.get("size", 17))))
		l.add_theme_color_override("font_color", it.get("color", UiTheme.DIM))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return l
	if kind == "card":
		return _make_card(it, idx)
	if kind == "langs":
		return _make_langs_row()

	var compact := bool(it.get("compact", false))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.row_style(false, it.get("accent", false), it.get("disabled", false)))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", UiTheme.pad(13))
	m.add_theme_constant_override("margin_right", UiTheme.pad(13))
	m.add_theme_constant_override("margin_top", UiTheme.pad(3 if compact else 9))
	m.add_theme_constant_override("margin_bottom", UiTheme.pad(3 if compact else 9))
	panel.add_child(m)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UiTheme.size(10))
	m.add_child(hb)

	var marker := TextureRect.new()
	marker.texture = UiTheme.kit("cursor")
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.custom_minimum_size = Vector2(UiTheme.size(12 if compact else 14), UiTheme.size(9 if compact else 12))
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.name = "Marker"
	hb.add_child(marker)

	var left := Label.new()
	left.text = Loc.t(String(it.get("text", "")))
	left.add_theme_font_override("font", UiTheme.font_semi())
	left.add_theme_font_size_override("font_size", UiTheme.size(15 if compact else 18))
	left.add_theme_color_override("font_color", UiTheme.DIM if bool(it.get("dim", false)) or bool(it.get("disabled", false)) else UiTheme.TEXT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(left)

	if it.has("binding_action"):
		var action := String(it.binding_action)
		var stacked := UiTheme.ui_scale() > 1.15
		var bindings_box: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
		bindings_box.add_theme_constant_override("separation", UiTheme.pad(6 if stacked else 10))
		hb.add_child(bindings_box)
		for device in ["keyboard", "gamepad"]:
			var slot := HBoxContainer.new()
			if not stacked: slot.custom_minimum_size.x = UiTheme.size(220 if device == "keyboard" else 245)
			slot.alignment = BoxContainer.ALIGNMENT_BEGIN
			if stacked:
				var device_label := Label.new()
				device_label.text = "Tastatur" if device == "keyboard" else "Xbox"
				device_label.custom_minimum_size.x = UiTheme.size(52)
				device_label.add_theme_font_size_override("font_size", UiTheme.size(10))
				device_label.add_theme_color_override("font_color", UiTheme.DIM)
				slot.add_child(device_label)
			slot.add_child(UiPrompts.make_badges(action, device, true))
			bindings_box.add_child(slot)
	elif it.has("value_text"):
		var val := Label.new()
		val.text = String(it.get("value_text", ""))
		val.add_theme_font_override("font", UiTheme.font_bold())
		val.add_theme_font_size_override("font_size", UiTheme.size(13 if compact else 16))
		val.add_theme_color_override("font_color", it.get("value_color", UiTheme.ACCENT))
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if prompt_context == "settings" and kind == "choice":
			val.text = "‹   " + Loc.tx(val.text) + "   ›"
		elif kind == "toggle" and val.text in ["An", "Aus"]:
			val.add_theme_color_override("font_color", UiTheme.ACCENT2 if val.text == "An" else UiTheme.DIM)
			val.text = "●  " + Loc.tx(val.text)
		if kind == "slider" and val.text.ends_with("%"):
			var gauge := ProgressBar.new()
			gauge.custom_minimum_size = Vector2(UiTheme.pad(64), UiTheme.pad(4))
			gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var ranges := {"ui_size": Vector2(70, 160), "font_scale": Vector2(80, 160), "sensitivity": Vector2(40, 160), "deadzone": Vector2(0, 60)}
			var bounds: Vector2 = ranges.get(String(it.get("id", "")), Vector2(0, 100))
			gauge.min_value = bounds.x
			gauge.max_value = bounds.y
			gauge.value = val.text.trim_suffix("%").to_float()
			gauge.show_percentage = false
			var track := StyleBoxFlat.new()
			track.bg_color = UiTheme.BG
			track.set_corner_radius_all(UiTheme.pad(2))
			gauge.add_theme_stylebox_override("background", track)
			var fill := StyleBoxFlat.new()
			fill.bg_color = UiTheme.ACCENT2
			fill.set_corner_radius_all(UiTheme.pad(2))
			gauge.add_theme_stylebox_override("fill", fill)
			hb.add_child(gauge)
		if it.has("hint") and String(it.get("hint", "")) != "":
			val.text += "  ·  " + Loc.t(String(it.hint))
		hb.add_child(val)
	panel.set_meta("label", left)
	panel.set_meta("value", hb.get_child(hb.get_child_count() - 1))
	return panel

## Sprachwahl: zwei Pixelflaggen, die aktive hervorgehoben; Klick wählt direkt,
## links/rechts oder Bestätigen wechselt (on_adjust/on_activate des Bildschirms).
func _make_langs_row() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.row_style(false))
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, UiTheme.pad(13))
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, UiTheme.pad(6))
	panel.add_child(m)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", UiTheme.size(22))
	m.add_child(hb)
	var marker := TextureRect.new()
	marker.texture = UiTheme.kit("cursor")
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.custom_minimum_size = Vector2(UiTheme.size(14), UiTheme.size(12))
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.name = "Marker"
	hb.add_child(marker)
	for code in Loc.LANGS:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", UiTheme.size(8))
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.name = "Lang_" + code
		var flag := TextureRect.new()
		flag.texture = Flags.texture(code)
		flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.custom_minimum_size = Vector2(UiTheme.size(39), UiTheme.size(21))
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var active: bool = Loc.lang == code
		flag.modulate = Color.WHITE if active else Color(1, 1, 1, 0.45)
		box.add_child(flag)
		var name_label := Label.new()
		# Sprachnamen bleiben in ihrer eigenen Sprache.
		name_label.text = "Deutsch" if code == "de" else "English"
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_label.add_theme_font_override("font", UiTheme.font_semi())
		name_label.add_theme_font_size_override("font_size", UiTheme.size(15))
		name_label.add_theme_color_override("font_color", UiTheme.TEXT if active else UiTheme.DIM)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		box.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				choose_language(code))
		hb.add_child(box)
	panel.set_meta("label", marker)
	panel.set_meta("value", hb)
	return panel

## Sprache wechseln, speichern und den Bildschirm neu aufbauen (zusammengesetzte Texte).
func choose_language(code: String) -> void:
	if code == Loc.lang:
		return
	Loc.set_language(code)
	Save.set_g("game.language", Loc.lang)
	Save.save_settings()
	Audio.sfx("ui_ok", -8.0, 1.1, true)
	var f := focus
	rebuild()
	refresh()
	focus = clampi(f, 0, maxi(0, items.size() - 1))
	_update_focus_visuals()

func _make_binding_header() -> Control:
	if UiTheme.ui_scale() > 1.15:
		var label := Label.new()
		label.text = "AKTION   /   TASTATUR & XBOX-GAMEPAD"
		label.add_theme_font_size_override("font_size", UiTheme.size(10))
		label.add_theme_color_override("font_color", UiTheme.ACCENT2)
		return label
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiTheme.pad(35))
	margin.add_theme_constant_override("margin_right", UiTheme.pad(13))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.size(10))
	margin.add_child(row)
	for i in range(3):
		var l := Label.new()
		l.text = ["AKTION", "TASTATUR", "XBOX-GAMEPAD"][i]
		l.add_theme_font_override("font", UiTheme.font_bold())
		l.add_theme_font_size_override("font_size", UiTheme.size(10))
		l.add_theme_color_override("font_color", UiTheme.ACCENT2)
		if i == 0: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: l.custom_minimum_size.x = UiTheme.size(220 if i == 1 else 245)
		row.add_child(l)
	return margin

func _make_card(it: Dictionary, idx: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.card_style(false))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, UiTheme.pad(14))
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UiTheme.pad(8))
	m.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var marker := Label.new()
	marker.text = "◆ "
	marker.add_theme_font_override("font", UiTheme.font_bold())
	marker.add_theme_font_size_override("font_size", UiTheme.size(18))
	marker.add_theme_color_override("font_color", UiTheme.ACCENT)
	marker.name = "Marker"
	head.add_child(marker)
	var compact := bool(it.get("compact", false))
	var fam := Label.new()
	fam.text = Loc.t("evo.family." + String(it.get("family", "sting"))).to_upper()
	fam.add_theme_font_override("font", UiTheme.font_bold())
	fam.add_theme_font_size_override("font_size", UiTheme.size(10 if compact else 12))
	fam.add_theme_color_override("font_color", UiTheme.family_color(String(it.get("family", "sting"))))
	fam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fam)
	var lvl := Label.new()
	lvl.text = String(it.get("value_text", ""))
	lvl.add_theme_font_override("font", UiTheme.font_bold())
	lvl.add_theme_font_size_override("font_size", UiTheme.size(14))
	lvl.add_theme_color_override("font_color", UiTheme.ACCENT)
	head.add_child(lvl)

	var name_l := Label.new()
	name_l.text = String(it.get("text", ""))
	name_l.add_theme_font_override("font", UiTheme.font_bold())
	name_l.add_theme_font_size_override("font_size", UiTheme.size(18 if compact else 21))
	name_l.add_theme_color_override("font_color", UiTheme.TEXT)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_l)

	for line in it.get("lines", []):
		var l := Label.new()
		l.text = String(line.get("text", ""))
		l.add_theme_font_override("font", UiTheme.font_regular())
		l.add_theme_font_size_override("font_size", UiTheme.size(int(line.get("size", 16)) - (2 if compact else 0)))
		l.add_theme_color_override("font_color", line.get("color", UiTheme.DIM))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
	return panel

## Maus: Zeiger hebt hervor, Linksklick aktiviert, Rad bewegt den Fokus.
func _wire_mouse(row: Control, idx: int) -> void:
	if row == null:
		return
	var kind: String = String(items[idx].get("kind", "action"))
	if kind in ["label", "sep"]:
		_ignore_mouse(row)
		return
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for c in row.get_children():
		_ignore_mouse(c)
	if not row.mouse_entered.is_connected(_on_row_hover):
		row.mouse_entered.connect(_on_row_hover.bind(idx))
	if not row.gui_input.is_connected(_on_row_input):
		row.gui_input.connect(_on_row_input.bind(idx))

func _ignore_mouse(node: Node) -> void:
	for n in node.get_children():
		_ignore_mouse(n)
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_row_hover(idx: int) -> void:
	if idx < 0 or idx >= items.size():
		return
	if _is_skippable(idx):
		return
	if focus != idx:
		focus = idx
		Audio.sfx("ui_move", -16.0, 1.0, true)
		_update_focus_visuals()

func _on_row_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if _is_skippable(idx):
				return
			focus = idx
			_update_focus_visuals()
			_activate()
		MOUSE_BUTTON_WHEEL_UP:
			_move_focus(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_move_focus(1)
		_:
			return
	accept_event()

func _clamp_focus() -> void:
	if items.is_empty():
		focus = 0
		return
	focus = clampi(focus, 0, items.size() - 1)
	var guard := 0
	while _is_skippable(focus) and guard < items.size() * 2:
		focus = (focus + 1) % items.size()
		guard += 1

func _is_skippable(i: int) -> bool:
	var k: String = items[i].get("kind", "action")
	return k in ["label", "sep"]

func _update_focus_visuals() -> void:
	for i in range(_rows.size()):
		var row := _rows[i]
		var it: Dictionary = items[i]
		var kind: String = it.get("kind", "action")
		if kind in ["label", "sep"]:
			continue
		var focused := i == focus
		var marker := row.find_child("Marker", true, false) as CanvasItem
		if marker != null:
			marker.modulate.a = 1.0 if focused else 0.0
		if kind == "card":
			row.add_theme_stylebox_override("panel", UiTheme.card_style(focused))
		else:
			row.add_theme_stylebox_override("panel", UiTheme.row_style(focused, it.get("accent", false), it.get("disabled", false)))
			var lbl := row.find_child("*", true, false)
	on_focus_changed(focus)
	_ensure_focus_visible()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var grid_mode: bool = columns > 1
	if Bindings.consume("ui_up"):
		if grid_mode:
			_grid_move(0, -1)
		else:
			_move_focus(-1)
	elif Bindings.consume("ui_down"):
		if grid_mode:
			_grid_move(0, 1)
		else:
			_move_focus(1)
	if Bindings.consume("ui_left"):
		if grid_mode:
			_grid_move(1, -1)
		else:
			_adjust(-1)
	elif Bindings.consume("ui_right"):
		if grid_mode:
			_grid_move(1, 1)
		else:
			_adjust(1)
	var act := Bindings.consume("ui_accept")
	var buy := Bindings.consume("upgrade_buy")
	var cancel := Bindings.consume("ui_cancel")
	var menu := Bindings.consume("menu")
	if act or buy:
		_activate()
	elif cancel or menu:
		_back()

func _set_focus(i: int) -> void:
	focus = clampi(i, 0, items.size() - 1)
	Audio.sfx("ui_move", -10.0, 1.0, true)
	_update_focus_visuals()

## Bewegung im dreispaltigen Gitter: hoch/runter in Spalten, links/rechts zwischen Karten.
## Unter der letzten Kartenzeile geht es in die Nebenliste (Neuwürfeln).
func _grid_move(axis: int, dir: int) -> void:
	if items.is_empty():
		return
	if axis == 0:
		if focus < grid_count:
			var rows := int(ceil(float(grid_count) / float(grid_cols)))
			var row := int(float(focus) / float(grid_cols))
			if dir > 0 and row >= rows - 1:
				if grid_count < items.size():
					_set_focus(grid_count)
				return
			if dir < 0 and row <= 0:
				return
			var t := focus + dir * grid_cols
			if t >= 0 and t < grid_count:
				_set_focus(t)
		else:
			if dir < 0:
				var rows2 := int(ceil(float(grid_count) / float(grid_cols)))
				_set_focus(mini(grid_count - 1, (rows2 - 1) * grid_cols))
			elif focus + 1 < items.size():
				_set_focus(focus + 1)
	else:
		if focus < grid_count:
			var t := focus + dir
			if t >= 0 and t < grid_count:
				_set_focus(t)
		else:
			_adjust(dir)

func _move_focus(dir: int) -> void:
	if items.is_empty():
		return
	var start := focus
	for i in range(items.size()):
		focus = (focus + dir + items.size()) % items.size()
		if not _is_skippable(focus):
			break
	if focus != start:
		Audio.sfx("ui_move", -10.0, 1.0, true)
	_update_focus_visuals()

func _adjust(dir: int) -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[focus]
	match String(it.get("kind", "action")):
		"choice", "toggle", "slider":
			on_adjust(focus, dir)
		_:
			# Auch reine Aktionszeilen dürfen links/rechts reagieren
			# (z. B. die Rückfrage "Behalten / Standard").
			if has_method("on_adjust"):
				on_adjust(focus, dir)

func _activate() -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[focus]
	if it.get("disabled", false):
		Audio.sfx("deny", -8.0, 1.0, true)
		return
	# Schalter, Auswahl und Regler reagieren auf Bestätigen/Klick wie auf "rechts".
	var kind := String(it.get("kind", "action"))
	if kind == "toggle" or kind == "choice" or kind == "slider":
		on_adjust(focus, 1)
		return
	on_activate(focus)

func _back() -> void:
	if not back_enabled:
		Audio.sfx("deny", -12.0, 1.0, true)
		return
	Audio.sfx("ui_back", -6.0, 1.0, true)
	do_back()

# --- Überschreibbare Haken ---
func on_activate(_index: int) -> void:
	pass

func on_adjust(_index: int, _dir: int) -> void:
	pass

## Wird nach jedem Fokuswechsel aufgerufen – z. B. für eine Detailspalte.
func on_focus_changed(_index: int) -> void:
	pass

func do_back() -> void:
	closed.emit(null)

func set_items(new_items: Array, keep_focus: bool = true) -> void:
	var old := focus
	items = new_items
	refresh()
	if keep_focus:
		focus = clampi(old, 0, maxi(0, items.size() - 1))
	_clamp_focus()
	_update_focus_visuals()

func rebuild() -> void:
	items.clear()
	build_items()

func focus_text() -> String:
	if focus < items.size():
		return String(items[focus].get("text", ""))
	return ""
