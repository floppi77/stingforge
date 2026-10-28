extends Control
## Kleines skalierbares Schloss, ohne Emoji-/Systemschriftabhängigkeit.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(14, 18)

func _draw() -> void:
	var s := minf(size.x / 14.0, size.y / 18.0)
	var origin := (size - Vector2(14, 18) * s) * 0.5
	var ink := Color("#89928c")
	draw_arc(origin + Vector2(7, 6) * s, 3.5 * s, PI, TAU, 14, ink, 2.1 * s, true)
	draw_style_box(_body(ink), Rect2(origin + Vector2(2, 6) * s, Vector2(10, 10) * s))
	draw_line(origin + Vector2(7, 10) * s, origin + Vector2(7, 13) * s, Color("#102017"), 1.5 * s, true)

func _body(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(1)
	return style
