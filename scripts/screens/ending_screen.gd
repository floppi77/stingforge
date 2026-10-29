extends Control
## Abspann-Level nach dem letzten Boss: Die Biene fliegt von selbst durch die wieder
## befriedete Welt. 20 Sekunden Glückwunsch mit Ko-fi und dem Hinweis auf das Original,
## danach rollt alles langsam nach oben und der Abspann läuft. Keine Auswahl mehr.

const UiTheme := preload("res://scripts/core/ui_theme.gd")
const KofiCup := preload("res://scripts/core/kofi_cup.gd")
const RetroDisk := preload("res://scripts/core/retro_disk.gd")
const KOFI_URL := "https://ko-fi.com/floppi77"
const STORE_URL := "https://store.steampowered.com/app/3956980/Apidya_Special/"
const HOLD_TIME := 20.0
## Rollgeschwindigkeit im 1080er-Raster (Pixel je Sekunde).
const SCROLL_SPEED := 62.0
## Friedliche Welten, durch die der Flug führt (jeweils WORLD_TIME Sekunden).
const WORLDS := [1, 3, 4, 6, 2]
const WORLD_TIME := 13.0
const GOLD := Color("#ffd666")
const INK := Color("#fff4dc")
const SHADOW := Color("#1a0d06")

var app: Node
var t := 0.0
var scroll := 0.0
var rolling := false
var finished := false
var focus := 0
var world_index := 0
var _vp: SubViewport
var _view: TextureRect
var _cam: Camera2D
var _bg: Background
var _bee: AnimatedSprite2D
var _critters: Node2D
var _flash: ColorRect
var _shade: TextureRect
var _content: VBoxContainer
var _cards: Array[PanelContainer] = []
var _hint: Label
var _end_t := -1.0
## Debug-Vorschau: zeigt den Abspann, ohne den laufenden Run abzuschließen.
var preview := false

func setup(args: Dictionary) -> void:
	preview = bool(args.get("preview", false))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make_theme()
	if not preview:
		Save.profile.boss_rush_unlocked = true
		Save.campaign.completed = true
		Save.save_profile()
		Save.save_campaign()
	_build_world()
	_build_overlay()
	_fit()
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)
	Audio.play_music("ending", 1.2)

# ------------------------------------------------------------------ Welt
func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 540)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_disable_input = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_cam = Camera2D.new()
	_cam.position = Vector2(480, 270)
	_cam.enabled = true
	_vp.add_child(_cam)
	_bg = Background.new()
	_bg.z_index = -60
	_vp.add_child(_bg)
	_bg.setup(Data.level(int(WORLDS[0])))
	_critters = Node2D.new()
	_critters.set_script(preload("res://scripts/screens/ending_critters.gd"))
	_vp.add_child(_critters)
	_bee = AnimatedSprite2D.new()
	_bee.sprite_frames = Art.sprite_frames("bee")
	_bee.play("default")
	_bee.position = Vector2(300, 300)
	_vp.add_child(_bee)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

## Autopilot: ruhige Achterschleifen, leichte Neigung in Flugrichtung.
func _fly(delta: float) -> void:
	var p := Vector2(330.0 + sin(t * 0.31) * 150.0 + sin(t * 0.83) * 30.0,
		300.0 + sin(t * 0.62) * 80.0 + sin(t * 1.37) * 22.0)
	var v := (p - _bee.position) / maxf(delta, 0.001)
	_bee.position = p
	_bee.rotation = lerpf(_bee.rotation, clampf(v.y / 900.0, -0.3, 0.3), clampf(delta * 6.0, 0.0, 1.0))
	_bg.update(delta, 90.0)
	var next := int(t / WORLD_TIME) % WORLDS.size()
	if next != world_index:
		world_index = next
		_bg.setup(Data.level(int(WORLDS[next])))
		_flash.color.a = 0.85
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)

# --------------------------------------------------------------- Oberfläche
func _build_overlay() -> void:
	_shade = TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.03, 0.025, 0.08, 0.0), Color(0.03, 0.025, 0.08, 0.62),
		Color(0.03, 0.025, 0.08, 0.62), Color(0.03, 0.025, 0.08, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.width = 2
	ramp.height = 256
	ramp.fill_from = Vector2.ZERO
	ramp.fill_to = Vector2.DOWN
	_shade.texture = ramp
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	_content.add_theme_constant_override("separation", UiTheme.pad(14))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var head := _label(Loc.tx("Herzlichen Glückwunsch, du hast diese Welt befriedet."), 34, GOLD, UiTheme.font_display())
	head.name = "Congrats"
	_content.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTheme.pad(28))
	_content.add_child(row)
	var cup := KofiCup.new()
	cup.custom_minimum_size = Vector2(UiTheme.pad(56), UiTheme.pad(56))
	row.add_child(_card(cup, Loc.tx("Wenn du Spaß hattest, spendiere mir doch einen Kaffee."),
		"ko-fi.com/floppi77", KOFI_URL))
	var disk := RetroDisk.new()
	disk.custom_minimum_size = Vector2(UiTheme.pad(56), UiTheme.pad(56))
	row.add_child(_card(disk, Loc.tx("Ziehe den Kauf des Originals in Betracht."),
		Loc.tx("Apidya Special auf Steam"), STORE_URL))
	_hint = _label(Loc.tx("Links/rechts wählen · Bestätigen öffnet den Link im Browser · Zurück überspringt"), 12, UiTheme.DIM)
	_content.add_child(_hint)
	# Der Abspann steht unter dem Glückwunsch und rollt mit ihm nach oben.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiTheme.pad(260))
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(gap)
	_content.add_child(_label(Loc.t("credits.title"), 30, GOLD, UiTheme.font_display()))
	var roll := VBoxContainer.new()
	roll.add_theme_constant_override("separation", UiTheme.pad(2))
	roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(roll)
	for line in Loc.t("credits.body").split("\n"):
		roll.add_child(_label(line, 17, INK if line != "" else UiTheme.DIM))
	roll.add_child(_label("Made with Vibe, DeepSeek, Sol, Opus, Coffee, Qwen and Love.", 17, UiTheme.ACCENT2))
	var total := 0
	for k in Save.campaign.get("level_scores", {}):
		total += int(Save.campaign.level_scores[k].get("score", 0))
	_content.add_child(_label("", 17, INK))
	_content.add_child(_label(Loc.tx("Gesamtpunkte: %d") % total, 18, GOLD))
	_content.add_child(_label(Loc.tx("Freigeschaltete Evolutionen: %d / %d") % [
		(Save.profile.unlocked_evolutions as Array).size(), Data.EVOLUTIONS.size()], 17, INK))
	_content.add_child(_label(Loc.tx("Boss-Rush: alle zehn Bosse dieses Runs stehen im Hauptmenü bereit."), 16, UiTheme.OK))
	_content.add_child(_label("", 17, INK))
	var bye := _label(Loc.tx("Danke fürs Spielen!"), 30, GOLD, UiTheme.font_display())
	bye.name = "Thanks"
	_content.add_child(bye)
	_update_cards()

func _label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font if font != null else UiTheme.font_semi())
	l.add_theme_font_size_override("font_size", UiTheme.size(font_size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _card(icon: Control, text: String, link_text: String, url: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UiTheme.pad(330), 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("url", url)
	var margin := MarginContainer.new()
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, UiTheme.pad(14))
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, UiTheme.pad(10))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.pad(12))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(texts)
	var main := _label(text, 15, INK)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(main)
	var link := _label(link_text, 13, UiTheme.ACCENT2, UiTheme.font_bold())
	link.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.name = "Link"
	texts.add_child(link)
	var idx := _cards.size()
	panel.mouse_entered.connect(func():
		if focus != idx:
			focus = idx
			Audio.sfx("ui_move", -10.0, 1.0, true)
			_update_cards())
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			focus = idx
			_open(idx))
	_cards.append(panel)
	return panel

func _update_cards() -> void:
	for i in range(_cards.size()):
		_cards[i].add_theme_stylebox_override("panel", UiTheme.card_style(i == focus))

func _open(idx: int) -> void:
	if idx < 0 or idx >= _cards.size():
		return
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	_update_cards()
	if app != null and app.has_method("open_link"):
		app.open_link(String(_cards[idx].get_meta("url")))

func _fit() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if vs.x < 1.0 or vs.y < 1.0:
		return
	position = Vector2.ZERO
	size = vs
	# Ultrawide: die Welt wird breiter statt beschnitten.
	var w := int(ceil(540.0 * vs.x / vs.y))
	_vp.size = Vector2i(maxi(960, w), 540)
	_bg.cover_extra = maxf(0.0, (float(_vp.size.x) - 960.0) * 0.5 + 16.0)
	_bg.setup(Data.level(int(WORLDS[world_index])))
	_view.position = Vector2.ZERO
	_view.size = vs
	_flash.position = Vector2.ZERO
	_flash.size = vs
	_shade.position = Vector2.ZERO
	_shade.size = vs
	_layout_content()

func _layout_content() -> void:
	var k := size.y / 1080.0
	var width := minf(size.x - 120.0 * k, 1400.0 * k)
	_content.size = Vector2(width, 0)
	_content.position = Vector2(round((size.x - width) * 0.5), round(250.0 * k - scroll))

# ------------------------------------------------------------------ Ablauf
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	_fly(delta)
	if not rolling and t >= HOLD_TIME:
		rolling = true
	if rolling and not finished:
		scroll += SCROLL_SPEED * (size.y / 1080.0) * delta
		var thanks := _content.get_node_or_null("Thanks") as Control
		if thanks != null and thanks.get_global_rect().get_center().y <= size.y * 0.5:
			finished = true
			_end_t = 4.0
		_layout_content()
	if finished:
		_end_t -= delta
		if _end_t <= 0.0:
			_leave()
			return
	if Bindings.consume("ui_left") or Bindings.consume("ui_up"):
		focus = (focus + _cards.size() - 1) % _cards.size()
		Audio.sfx("ui_move", -10.0, 1.0, true)
		_update_cards()
	elif Bindings.consume("ui_right") or Bindings.consume("ui_down"):
		focus = (focus + 1) % _cards.size()
		Audio.sfx("ui_move", -10.0, 1.0, true)
		_update_cards()
	if Bindings.consume("ui_accept") or Bindings.consume("upgrade_buy"):
		if _cards_visible():
			_open(focus)
	if Bindings.consume("ui_cancel") or Bindings.consume("menu"):
		skip()

func _cards_visible() -> bool:
	return not _cards.is_empty() and _cards[0].get_global_rect().end.y > 0.0

## Zurück: erst den Glückwunsch überspringen, dann den Abspann.
func skip() -> void:
	if not rolling:
		rolling = true
		t = maxf(t, HOLD_TIME)
		return
	_leave()

func _leave() -> void:
	if finished and _end_t > 0.0:
		_end_t = 0.0
	finished = true
	set_process(false)
	if app != null and app.has_method("menu_main"):
		app.menu_main()
