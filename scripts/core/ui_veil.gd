extends Control
## Durchscheinender Schleier über der angehaltenen Spielwelt (Pause, Game Over,
## Rückfragen im Spiel). Links dichter für die Lesbarkeit der Liste, rechts
## bleibt die eingefrorene Szene erkennbar; HUD-Bänder oben/unten treten zurück.
const U := preload("res://scripts/core/ui_theme.gd")

## Grundfarbe des Schleiers; Game Over tönt ihn leicht rötlich.
var tint := Color(0.012, 0.035, 0.045)
var _across: GradientTexture2D
var _down: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_across = _ramp([Color(tint, 0.90), Color(tint, 0.84), Color(tint, 0.58)],
		[0.0, 0.42, 1.0], Vector2.RIGHT)
	# Kopf- und Fußband (HUD) stärker abdunkeln, damit nichts mit dem Titel kollidiert.
	_down = _ramp([Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.62)],
		[0.0, 0.16, 0.82, 1.0], Vector2.DOWN)

func _ramp(colors: Array, offsets: Array, dir: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256 if dir == Vector2.RIGHT else 2
	tex.height = 2 if dir == Vector2.RIGHT else 256
	tex.fill_from = Vector2.ZERO
	tex.fill_to = dir
	return tex

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_across, r, false)
	draw_texture_rect(_down, r, false)
	var unit := size.x / 960.0
	draw_rect(Rect2(0, 0, size.x, unit), Color(U.ACCENT, 0.35))
	draw_rect(Rect2(0, size.y - unit, size.x, unit), Color(U.ACCENT2, 0.22))
