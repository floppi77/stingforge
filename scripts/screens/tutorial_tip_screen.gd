extends Control
## Tutorial: kleines Erklärfenster über dem angehaltenen Spiel.
## Oben mittig, mit Titel, bildhaftem Text und einer Bildzeile aus echten
## Spielgrafiken und Tastensymbolen. Bestätigen (Leertaste/A/Eingabe) schließt.
##
## args: title, text, visual (Liste von Bausteinen), on_close (Callable)
##   Baustein: {"sprite": "bee"} · {"action": "upgrade_prev"} · {"text": "→"}
##             {"icon": "icon_nectar"} · {"scale": 2.0} je Baustein optional

const UiTheme := preload("res://scripts/core/ui_theme.gd")
const UiPrompts := preload("res://scripts/core/ui_prompts.gd")

var app: Node
var title := ""
var text := ""
var visual: Array = []
var on_close: Callable = Callable()
var _age := 0.0
var _closing := false

func setup(args: Dictionary) -> void:
	title = String(args.get("title", ""))
	text = String(args.get("text", ""))
	visual = args.get("visual", [])
	on_close = args.get("on_close", Callable())

func _ready() -> void:
	# In einer CanvasLayer greifen Anker nicht: Größe explizit setzen.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vs
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.02, 0.04, 0.35)
	veil.size = vs
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	var w := minf(vs.x * 0.56, float(UiTheme.size(520)))
	panel.custom_minimum_size = Vector2(w, 0)
	panel.position = Vector2((vs.x - w) * 0.5, vs.y * 0.12)
	add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, UiTheme.pad(16))
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.pad(8))
	m.add_child(box)
	var eyebrow := Label.new()
	eyebrow.text = "ÜBUNGSFLUG"
	eyebrow.add_theme_font_override("font", UiTheme.font_caps())
	eyebrow.add_theme_font_size_override("font_size", UiTheme.size(8))
	eyebrow.add_theme_color_override("font_color", UiTheme.ACCENT2)
	box.add_child(eyebrow)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", UiTheme.font_display())
	t.add_theme_font_size_override("font_size", UiTheme.size(26))
	t.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(t)
	if not visual.is_empty():
		box.add_child(_visual_row())
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", UiTheme.font_regular())
	body.add_theme_font_size_override("font_size", UiTheme.size(16))
	body.add_theme_color_override("font_color", UiTheme.TEXT)
	box.add_child(body)
	var hint := HBoxContainer.new()
	hint.alignment = BoxContainer.ALIGNMENT_END
	hint.add_child(UiPrompts.make_hint("ui_accept", "Weiter", true))
	box.add_child(hint)
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.18)
	Bindings.block_until_release(["ui_accept", "upgrade_buy", "fire", "menu", "ui_cancel"])
	Audio.sfx("ui_ok", -10.0, 1.25, true)

## Bildzeile: Spielgrafiken, Tastensymbole und Pfeile nebeneinander.
func _visual_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTheme.pad(10))
	row.custom_minimum_size = Vector2(0, UiTheme.pad(44))
	for item in visual:
		var d: Dictionary = item
		var scale := float(d.get("scale", 2.0))
		if d.has("sprite") or d.has("icon"):
			var name := String(d.get("sprite", d.get("icon", "")))
			var tex := Art.frame_tex(name, 0)
			var r := TextureRect.new()
			r.texture = tex
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var s := tex.get_size() * scale * UiTheme.CANVAS_SCALE * 0.5
			r.custom_minimum_size = s
			r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if d.has("tint"):
				r.modulate = d.tint
			row.add_child(r)
		elif d.has("action"):
			var b := UiPrompts.make_badges(String(d.action), "both", true)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		elif d.has("text"):
			var l := Label.new()
			l.text = String(d.text)
			l.add_theme_font_override("font", UiTheme.font_display())
			l.add_theme_font_size_override("font_size", UiTheme.size(int(d.get("size", 22))))
			l.add_theme_color_override("font_color", d.get("color", UiTheme.ACCENT2))
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(l)
	return row

func _process(delta: float) -> void:
	_age += delta
	if _closing or _age < 0.35:
		return
	if Bindings.consume("ui_accept") or Bindings.consume("upgrade_buy") or Bindings.consume("fire"):
		close()

func _gui_input(event: InputEvent) -> void:
	if _age >= 0.35 and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()

func close() -> void:
	if _closing:
		return
	_closing = true
	Audio.sfx("ui_ok", -8.0, 1.1, true)
	if on_close.is_valid():
		on_close.call()
