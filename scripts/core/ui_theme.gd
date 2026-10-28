extends RefCounted
## Pixel-UI im feinen 1×-Raster (Canvas 1920 × 1080): tiefes Indigo, Honiggold und
## Nektar-Türkis, pixelgenaue Rahmen aus assets/ui/kit und Pixelschriften ohne
## Kantenglättung. Layoutwerte sind weiter im 960er-Raster notiert (CANVAS_SCALE).

const BG := Color("#0b0a18")
const SURFACE := Color("#1b1f3c")
const SURFACE_RAISED := Color("#242a4e")
const BORDER := Color("#465284")
const ACCENT := Color("#ffd666")
const ACCENT2 := Color("#52d6c4")
const TEXT := Color("#fff4dc")
const DIM := Color("#a9acc9")
const DANGER := Color("#ff5c84")
const OK := Color("#8ee6a0")
const GOLD_DEEP := Color("#e29c24")

## Jersey 10 trägt Fließtext und Titel: in allen Größen sauber lesbar, mit Umlauten.
const FONT_BODY_PATH := "res://assets/ui/fonts/pixel/Jersey10-Regular.ttf"
const FONT_TITLE_PATH := "res://assets/ui/fonts/pixel/Jersey10-Regular.ttf"
const FONT_CAPS_PATH := "res://assets/ui/fonts/pixel/Silkscreen-Regular.ttf"
const FONT_CAPS_BOLD_PATH := "res://assets/ui/fonts/pixel/Silkscreen-Bold.ttf"
## Ersatz für Zeichen, die die Pixelschriften nicht kennen (Pfeile).
const FONT_FALLBACK_PATH := "res://assets/ui/fonts/Nunito.ttf"
# Ältere Aufrufer (Prüfungen) erwarten diese Namen noch.
const FONT_REG_PATH := FONT_BODY_PATH
const FONT_DISPLAY_PATH := FONT_TITLE_PATH
const KIT := "res://assets/ui/kit/"

static var _regular: FontVariation
static var _bold: FontVariation
static var _semi: FontVariation
static var _display: FontVariation
static var _display_soft: FontVariation
static var _caps: FontVariation
static var _caps_bold: FontVariation
static var _scale_override := -1.0
static var _textures: Dictionary = {}

static func font_regular() -> Font:
	if _regular == null: _regular = _variation(FONT_BODY_PATH, -1)
	return _regular

static func font_semi() -> Font:
	if _semi == null: _semi = _variation(FONT_BODY_PATH, -1)
	return _semi

static func font_bold() -> Font:
	if _bold == null: _bold = _variation(FONT_BODY_PATH, -1)
	return _bold

## Große Titel und Zahlen (Jersey 10).
static func font_display() -> Font:
	if _display == null: _display = _variation(FONT_TITLE_PATH, -1)
	return _display

static func font_display_soft() -> Font:
	if _display_soft == null: _display_soft = _variation(FONT_BODY_PATH, -1)
	return _display_soft

## Kleine Versalien für Überschriften und Etiketten (Silkscreen, exaktes 8er-Raster).
static func font_caps() -> Font:
	if _caps == null: _caps = _variation(FONT_CAPS_PATH, -1)
	return _caps

static func font_caps_bold() -> Font:
	if _caps_bold == null: _caps_bold = _variation(FONT_CAPS_BOLD_PATH, -1)
	return _caps_bold

static func _variation(path: String, weight: int) -> FontVariation:
	var base: FontFile = load(path)
	# Pixelschriften: keine Kantenglättung, kein Hinting, ganze Pixelpositionen.
	base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	base.hinting = TextServer.HINTING_NONE
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if base.fallbacks.is_empty() and path != FONT_FALLBACK_PATH:
		base.fallbacks = [load(FONT_FALLBACK_PATH)]
	var fv := FontVariation.new()
	fv.base_font = base
	# Ligaturen aus: "fi" würde sonst in manchen Pixelschriften zerfallen.
	fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
	if weight > 0:
		# Numerischer OpenType-Tag, sonst ignoriert Godot die Gewichtsachse.
		var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		fv.variation_opentype = {weight_tag: float(weight)}
	return fv

static func ui_scale() -> float:
	if _scale_override > 0.0: return _scale_override
	var user := 1.0
	if Save != null:
		user = float(Save.g("display.ui_size", 100)) / 100.0 * float(Save.g("access.font_scale", 1.0))
	return clampf(user, 0.5, 3.2)

static func set_scale_override(v: float) -> void:
	_scale_override = v

## Menüs sind im 960er-Raster entworfen, das Canvas ist 1920 × 1080 (feines 1×-Raster).
const CANVAS_SCALE := 2.0

static func size(px: int) -> int:
	return int(maxf(8.0, round(px * ui_scale() * CANVAS_SCALE)))

static func pad(px: int) -> int:
	return int(maxf(1.0, round(px * ui_scale() * CANVAS_SCALE)))

# ---------------------------------------------------------------- Pixelrahmen
static func kit(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := KIT + name + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

## 9-Slice aus dem Kit. Der Rahmen bleibt pixelgenau (Nearest), der Inhalt erhält
## eigene Innenabstände im Layoutraster.
static func framed(name: String, margin: int, content: int = -1, scale: int = 2) -> StyleBox:
	var tex := kit(name)
	if tex == null:
		return _surface(SURFACE, BORDER, 8)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(margin)
	# Rahmen im doppelten Pixelraster: jede Kitzeile wird zu 2 × 2 Bildpunkten.
	sb.set_expand_margin_all(0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	var c := content if content >= 0 else margin
	sb.content_margin_left = pad(c)
	sb.content_margin_right = pad(c)
	sb.content_margin_top = pad(c)
	sb.content_margin_bottom = pad(c)
	if scale != 1:
		sb.set_meta("pixel_scale", scale)
	return sb

static func _surface(color: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(0)
	return sb

static func row_style(focused: bool, accent: bool = false, disabled: bool = false) -> StyleBox:
	var name := "row"
	if accent: name = "row_accent"
	if disabled: name = "row_disabled"
	if focused: name = "row_focus"
	var sb := framed(name, 8, 0)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

static func card_style(focused: bool) -> StyleBox:
	return framed("card_focus" if focused else "card", 12, 0)

static func panel_style(_color: Color = Color("#101f28")) -> StyleBox:
	return framed("panel", 12, 0)

static func chip_style(on: bool) -> StyleBox:
	return framed("chip_on" if on else "chip", 7, 0)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular()
	t.default_font_size = size(15)
	t.set_color("font_color", "Label", TEXT)
	var track := _surface(Color("#141631"), Color.TRANSPARENT, 0)
	track.set_border_width_all(0)
	track.content_margin_left = pad(3)
	track.content_margin_right = pad(3)
	t.set_stylebox("scroll", "VScrollBar", track)
	var grab := _surface(Color("#3a4478"), Color.TRANSPARENT, 0)
	grab.set_border_width_all(0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_hi := _surface(ACCENT2, Color.TRANSPARENT, 0)
	grab_hi.set_border_width_all(0)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	var grab_on := _surface(ACCENT, Color.TRANSPARENT, 0)
	grab_on.set_border_width_all(0)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_on)
	var empty := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon in ["increment", "decrement", "increment_highlight", "decrement_highlight", "increment_pressed", "decrement_pressed"]:
		t.set_icon(icon, "VScrollBar", empty)
	return t

static func family_color(family: String) -> Color:
	match family:
		"sting": return ACCENT
		"swarm": return Color("#8fd0ff")
		"pollen": return Color("#c8e85a")
		"chitin": return Color("#ff9e5e")
		"resonance": return Color("#d690ff")
		"nectar": return ACCENT2
	return TEXT
