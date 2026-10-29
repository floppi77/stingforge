extends Control
## Ko-fi-Tasse als Pixelbild (Tasse mit Herz, Henkel rechts), ohne fremde Bilddatei.
## Das Raster wird ganzzahlig in die Controlgröße eingepasst.

const ROWS := [
	"..s..s....",
	"...s..s...",
	"..........",
	"WWWWWWWWW.",
	"WWRRWRRWWHH",
	"WRRRRRRRWH.H",
	"WRRRRRRRWH.H",
	"WWRRRRRWWHH",
	"WWWRRRWWWH",
	"WWWWRWWWW.",
	".WWWWWWW..",
	"..WWWWW...",
]
const COLORS := {
	"W": Color("#ffffff"), "R": Color("#ff5e5b"), "H": Color("#ffffff"), "s": Color(1, 1, 1, 0.55),
}
const OUTLINE := Color("#13c3ff")
var steam := true
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(48, 48)

func _process(delta: float) -> void:
	_t += delta
	if steam:
		queue_redraw()

func _draw() -> void:
	var cols := 12
	var px := maxf(1.0, floor(minf(size.x / float(cols + 2), size.y / float(ROWS.size() + 2))))
	var origin := ((size - Vector2(cols + 2, ROWS.size() + 2) * px) * 0.5).floor()
	# Runder Ko-fi-Hintergrund als Pixelscheibe.
	var r := (float(maxi(cols, ROWS.size())) + 2.0) * 0.5
	var center := Vector2(cols + 2, ROWS.size() + 2) * 0.5
	for y in range(ROWS.size() + 2):
		for x in range(cols + 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= r:
				draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), OUTLINE)
	var lift := int(floor(_t * 4.0)) % 2 if steam else 0
	for y in range(ROWS.size()):
		var row: String = ROWS[y]
		for x in range(row.length()):
			var ch := row[x]
			if not COLORS.has(ch):
				continue
			var yy := float(y + 1)
			if ch == "s":
				yy -= float(lift)
			draw_rect(Rect2(origin + Vector2(x + 1, yy) * px, Vector2(px, px)), COLORS[ch])
