extends Control
## Menühintergrund im Amiga-Stil: Copperverlauf mit Dithering, Wabenmuster und
## langsam treibende Pollenpixel. Keine Abhängigkeit von der Spielwelt.
const U := preload("res://scripts/core/ui_theme.gd")

## "warm" (Standard) oder "cool" (Werkstatt, Einstellungen).
var mood := "warm"
## Nur die treibenden Pollen zeichnen (über einem eigenen Titelbild).
var motes_only := false
var _t := 0.0
var _pollen: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	for i in range(46):
		_pollen.append({"p": Vector2(rng.randf(), rng.randf()), "v": rng.randf_range(0.004, 0.016),
			"s": 1 + rng.randi() % 2, "ph": rng.randf() * TAU, "a": rng.randf_range(0.25, 0.8)})

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	if motes_only:
		_draw_pollen()
		return
	var tex := U.kit("backdrop_cool" if mood == "cool" else "backdrop")
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), U.BG)
	# Waben rechts, nach links ausblendend; im 2×-Pixelraster gekachelt.
	var hexa := U.kit("honeycomb")
	if hexa != null:
		var cell := Vector2(hexa.get_width(), hexa.get_height()) * 2.0
		var cols := int(ceil(size.x * 0.42 / cell.x)) + 1
		var rows := int(ceil(size.y / cell.y)) + 1
		for c in range(cols):
			var fade := 1.0 - float(c) / float(cols)
			for r in range(rows):
				var pos := Vector2(size.x - (c + 1) * cell.x, r * cell.y + fmod(_t * 6.0, cell.y) - cell.y)
				draw_texture_rect(hexa, Rect2(pos, cell), false, Color(1, 1, 1, fade))
	_draw_pollen()
	# Goldene Bodenlinie als Bühnenkante.
	draw_rect(Rect2(0, size.y - 4, size.x, 2), Color(U.GOLD_DEEP, 0.35))

## Pollen: kleine Quadrate im 2×-Raster, die sanft nach oben links treiben.
func _draw_pollen() -> void:
	for p in _pollen:
		var pos: Vector2 = p.p
		var y := fposmod(pos.y - _t * float(p.v), 1.0)
		var x := fposmod(pos.x - _t * float(p.v) * 0.6 + sin(_t * 0.7 + float(p.ph)) * 0.004, 1.0)
		var px := Vector2(floor(x * size.x / 2.0) * 2.0, floor(y * size.y / 2.0) * 2.0)
		var glow := 0.6 + 0.4 * sin(_t * 2.0 + float(p.ph))
		draw_rect(Rect2(px, Vector2.ONE * 2.0 * float(p.s)), Color(U.ACCENT, float(p.a) * glow))
