extends Control
## Gestaltung der Flächen neben dem 16:9-Spielfeld (Ultrawide, 16:10):
## weicher Übergang zur gedimmten Kulisse und eine feine Feldkante.

var field := Rect2()
var _ramp: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if field.size.x <= 0.0:
		return
	var s := field.size.x / 960.0
	var full := Rect2(Vector2.ZERO, size)
	# Links/rechts: zur Außenkante hin dunkler, am Feld fast klar (echter Verlauf,
	# keine Streifen aus überlappenden Stufen).
	var left := field.position.x
	var right := full.end.x - field.end.x
	if _ramp == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0.01, 0.02, 0.03, 0.66), Color(0.01, 0.02, 0.03, 0.12)])
		_ramp = GradientTexture2D.new()
		_ramp.gradient = g
		_ramp.width = 256
		_ramp.height = 2
	if left > 1.0:
		draw_texture_rect(_ramp, Rect2(0, 0, left, size.y), false)
	if right > 1.0:
		# Gespiegelt: dunkel am rechten Rand.
		draw_texture_rect(_ramp, Rect2(full.end.x, 0, -right, size.y), false)
	var top := field.position.y
	var bottom := full.end.y - field.end.y
	if top > 1.0:
		draw_rect(Rect2(0, 0, size.x, top), Color(0.01, 0.02, 0.03, 0.55))
	if bottom > 1.0:
		draw_rect(Rect2(0, field.end.y, size.x, bottom), Color(0.01, 0.02, 0.03, 0.55))
	# Feldkante: dunkle Fuge mit warmem Lichtsaum, im Pixelraster des Bildes.
	var edge := maxf(2.0, round(s))
	for x: float in [field.position.x, field.end.x]:
		if (x == field.position.x and left > 1.0) or (x == field.end.x and right > 1.0):
			draw_rect(Rect2(x - edge, field.position.y, edge * 2.0, field.size.y), Color(0.02, 0.03, 0.04, 0.95))
			var inner: float = x + (edge if x == field.position.x else -edge * 2.0)
			draw_rect(Rect2(inner, field.position.y, edge, field.size.y), Color(0.95, 0.76, 0.36, 0.28))
	if top > 1.0:
		draw_rect(Rect2(field.position.x, field.position.y - edge, field.size.x, edge * 2.0), Color(0.02, 0.03, 0.04, 0.95))
	if bottom > 1.0:
		draw_rect(Rect2(field.position.x, field.end.y - edge, field.size.x, edge * 2.0), Color(0.02, 0.03, 0.04, 0.95))
