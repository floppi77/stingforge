extends Node2D
## Schwachpunkt-Markierung des Bosses: pulsierender Pixelring mit vier Zacken,
## im 0,5-Weltpixel-Raster des 1080p-Renderings. Rein visuell.

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var r := 9.0 + pulse * 2.0
	var gold := Color(1.0, 0.84, 0.4, 0.95)
	var hot := Color(1.0, 0.36, 0.52, 0.85)
	draw_arc(Vector2.ZERO, r + 1.0, 0.0, TAU, 24, Color(0.05, 0.03, 0.1, 0.8), 1.5, false)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, gold, 1.0, false)
	for i in range(4):
		var dir := Vector2.from_angle(float(i) * TAU / 4.0 + _t * 0.8)
		var a := dir * (r + 2.5)
		var b := dir * (r + 6.0 + pulse * 1.5)
		draw_line(a, b, gold, 1.5, false)
	draw_circle(Vector2.ZERO, 2.5 + pulse, hot, true, -1.0, false)
	draw_circle(Vector2.ZERO, 1.0, Color(1, 1, 1, 0.9), true, -1.0, false)
