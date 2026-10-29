extends Control
## Eigene Pixelillustration für den Hinweis auf das Original: eine 3,5-Zoll-Diskette
## mit Bienenetikett. Bewusst kein fremdes Store- oder Coverbild.

var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(120, 120)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var grid := 30.0
	var px := maxf(1.0, floor(minf(size.x, size.y) / grid))
	var o := ((size - Vector2(grid, grid) * px) * 0.5).floor()
	var cell := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(w, h) * px), c)
	# Gehäuse mit abgeschrägter Ecke oben rechts.
	cell.call(1, 1, 27, 28, Color("#1d2140"))
	cell.call(2, 2, 25, 26, Color("#3a4170"))
	cell.call(26, 1, 2, 2, Color(0, 0, 0, 0))
	cell.call(27, 1, 2, 2, Color("#0b0a18"))
	# Metallschieber mit Fenster.
	cell.call(8, 2, 14, 9, Color("#c9cbd8"))
	cell.call(8, 2, 14, 1, Color("#eef0f8"))
	cell.call(16, 3, 4, 7, Color("#1d2140"))
	# Etikett in Bienenfarben.
	cell.call(4, 14, 22, 13, Color("#fff4dc"))
	for k in range(5):
		cell.call(4 + k * 5, 14, 3, 2, Color("#ffd666"))
		cell.call(6 + k * 5, 14, 2, 2, Color("#241a10"))
	# Kleine Biene mit schlagenden Flügeln auf dem Etikett.
	var flap := int(floor(_t * 6.0)) % 2
	cell.call(12, 20 - flap, 3, 2, Color(0.8, 0.95, 1.0, 0.9))
	cell.call(16, 20 - flap, 3, 2, Color(0.8, 0.95, 1.0, 0.9))
	cell.call(11, 22, 9, 3, Color("#ffd666"))
	cell.call(13, 22, 1, 3, Color("#241a10"))
	cell.call(16, 22, 1, 3, Color("#241a10"))
	cell.call(20, 23, 2, 1, Color("#241a10"))
	cell.call(10, 22, 1, 2, Color("#241a10"))
	# Schreibschutz und Glanzkante.
	cell.call(3, 3, 2, 2, Color("#0b0a18"))
	cell.call(2, 2, 25, 1, Color("#5a64a0"))
