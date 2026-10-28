class_name Background
extends Node2D
## Acht echte Tiefenebenen, mit gemeinsamem sichtbaren Boden an App.PLAY_BOTTOM.
## Die drei Original-Landschaften bleiben ruhig; Dunstbänder, motivabhängige
## Bodenpflanzen/Träger und Wurzelsäume ergänzen eigene Geometrie. Keine Ebene
## dupliziert bloß ein anderes Bild mit anderem Tempo. Alles bleibt bei z < 0.
const SOURCE_GROUND_Y := 476.0

## Grundgeschwindigkeiten in Pixeln je Sekunde.
const SPEED_FAR := 26.0
const SPEED_CLOUDS := 62.0
const SPEED_MID := 120.0
const SPEED_NEAR := 235.0
const SPEED_FRONT := 380.0

## Aufbau von hinten nach vorn. "asset" ist ein fester Bildname, sonst wird der
## Name aus dem Levelschlüssel gebildet (z. B. l03_far).
const LAYER_SPECS := [
	{"suffix": "far", "asset": "", "speed": SPEED_FAR, "z": -70, "alpha": 1.0},
	{"suffix": "haze", "asset": "", "speed": 44.0, "z": -66, "alpha": 0.55},
	{"asset": "bg_clouds", "suffix": "", "speed": SPEED_CLOUDS, "z": -62, "alpha": 0.30},
	{"suffix": "mid", "asset": "", "speed": SPEED_MID, "z": -55, "alpha": 1.0},
	{"suffix": "reeds", "asset": "", "speed": 174.0, "z": -50, "alpha": 0.65, "ground": true},
	{"suffix": "near", "asset": "", "speed": SPEED_NEAR, "z": -45, "alpha": 0.95, "ground": true},
	{"suffix": "roots", "asset": "", "speed": 302.0, "z": -41, "alpha": 0.72, "ground": true},
	{"asset": "bg_front", "suffix": "", "speed": SPEED_FRONT, "z": -38, "alpha": 0.48, "bottom": true},
]

var level_data: Dictionary = {}
var layers: Array = []
var scroll: float = 0.0
var speed_bonus: float = 0.0
var _t: float = 0.0
var _atmo: CPUParticles2D
## Zusätzliche Breite links und rechts (Ultrawide-Ränder); 0 = genau das Spielfeld.
var cover_extra := 0.0

func setup(data: Dictionary) -> void:
	# Wiederholtes setup darf weder alte Ebenen noch Partikel übriglassen.
	for child in get_children():
		child.free()
	layers.clear()
	_atmo = null
	scroll = 0.0
	_t = 0.0
	level_data = data
	var key := String(data.get("bg", "l01"))
	var pal: Dictionary = data.get("palette", {})
	for spec in LAYER_SPECS:
		var name := String(spec.asset)
		if name == "":
			name = "%s_%s" % [key, spec.suffix]
		var path := "res://assets/bg/%s.png" % name
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		elif Art.has(name):
			tex = Art.sheet(name)
		if tex == null:
			# Nur die Ferne darf vollflächig sein; andere Fallbacks bleiben offen.
			tex = _color_texture(data, spec)
		var tint: Color = _layer_tint(spec, pal)
		var span := maxf(1.0, float(tex.get_width()))
		# bg_front ist nur 512 px breit: zwei Kopien reißen bei x>64 ein Loch.
		var copies := int(ceil((float(App.WORLD_SIZE.x) + cover_extra * 2.0) / span)) + 1
		var anchor_y := 0.0
		if bool(spec.get("ground", false)):
			anchor_y = App.PLAY_BOTTOM - SOURCE_GROUND_Y
		elif bool(spec.get("bottom", false)):
			anchor_y = App.PLAY_BOTTOM - float(tex.get_height())
		for copy in range(copies):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.scale = Vector2.ONE
			s.z_index = int(spec.z)
			s.modulate = Color(tint.r, tint.g, tint.b, float(spec.alpha) * tint.a)
			add_child(s)
			layers.append({"node": s, "spec": spec, "copy": copy, "span": span, "anchor_y": anchor_y})
	_build_atmosphere()
	update(0.0, 78.0)

## Färbung je Ebene: die neuen Ebenen übernehmen die Farben des Levels, die
## bestehenden Landschaftsebenen bleiben neutral und werden nur leicht abgesenkt.
func _layer_tint(spec: Dictionary, pal: Dictionary) -> Color:
	var name := String(spec.asset)
	if name == "bg_clouds":
		var accent: Color = pal.get("accent", Color(1.0, 0.95, 0.8))
		return accent.lerp(Color(1, 1, 1), 0.55)
	if name == "bg_front":
		var dark: Color = pal.get("dark", Color(0.05, 0.07, 0.09))
		return dark.lerp(Color(0.02, 0.03, 0.04), 0.5)
	if String(spec.suffix) == "near":
		return Color(0.82, 0.85, 0.9)
	return Color(1, 1, 1)

func _color_texture(data: Dictionary, spec: Dictionary) -> Texture2D:
	var pal: Dictionary = data.get("palette", {})
	var img := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	if String(spec.get("suffix", "")) == "far":
		for y in range(540):
			var t := float(y) / 540.0
			var c: Color = (pal.get("sky", Color("#334")) as Color).lerp(pal.get("dark", Color("#111")), t)
			img.fill_rect(Rect2i(0, y, 960, 1), c)
	elif bool(spec.get("ground", false)) or bool(spec.get("bottom", false)):
		var soil := 464 if bool(spec.get("ground", false)) else 524
		img.fill_rect(Rect2i(0, soil, 960, 540 - soil), pal.get("dark", Color("#111")))
	# Fehlender Dunst bleibt transparent, kein deckender Himmel vor Landschaften.
	return ImageTexture.create_from_image(img)

func _build_atmosphere() -> void:
	var amount := int(26 * float(Save.g("graphics.particles", 1.0)))
	if amount <= 0:
		return
	_atmo = CPUParticles2D.new()
	_atmo.amount = amount
	_atmo.lifetime = 5.5
	_atmo.preprocess = 2.0
	_atmo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_atmo.emission_rect_extents = Vector2(520.0 + cover_extra, 300)
	_atmo.position = Vector2(480, 270)
	_atmo.direction = Vector2(-1, 0)
	_atmo.spread = 25.0
	_atmo.gravity = Vector2(0, 6)
	_atmo.initial_velocity_min = 18.0
	_atmo.initial_velocity_max = 46.0
	_atmo.scale_amount_min = 1.0
	_atmo.scale_amount_max = 3.0
	_atmo.color = (level_data.get("palette", {}).get("accent", Color(1, 1, 0.7)) as Color)
	_atmo.color.a = 0.32
	_atmo.z_index = -35
	add_child(_atmo)

func update(delta: float, speed: float) -> void:
	_t += delta
	# "speed" ist die Fluggeschwindigkeit der Welt; die Ebenen bewegen sich im
	# Verhältnis dazu, damit ein schnelleres Level auch schneller wirkt.
	var base := clampf(speed / 78.0, 0.4, 2.5)
	scroll += base * (1.0 + speed_bonus) * delta
	for l in layers:
		var spec: Dictionary = l.spec
		var span: float = float(l.get("span", 960.0))
		var total := scroll * float(spec.speed)
		var off := fposmod(total, span)
		var node: Sprite2D = l.node
		var lead := ceilf(cover_extra / span) * span
		node.position = Vector2(-off + float(l.copy) * span - lead, float(l.get("anchor_y", 0.0)))

## Kurzer Lichtblitz (Treffer, Explosion) auf allen Ebenen.
func flash(color: Color, strength: float = 0.3, duration: float = 0.35) -> void:
	if not bool(Save.g("graphics.flashes", true)):
		return
	for l in layers:
		var node: Sprite2D = l.node
		var tint := node.modulate
		var tw := create_tween()
		tw.tween_property(node, "modulate", tint.lerp(color, strength), duration * 0.2)
		tw.tween_property(node, "modulate", tint, duration * 0.8)
