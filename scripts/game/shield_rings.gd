extends Node2D
## Schildladungen als Wabenhülle um die Biene: je Ladung ein sechseckiger Ring aus
## sechs Platten mit Fugen und Wabenknoten an den Ecken, abwechselnd rotierend.
## Reine Anzeige, niemals Kollisionsfläche oder Schildquelle. Player liefert Status
## und Simulationszeit; Pausen frieren die Drehung mit ein.
## lines() ist dieselbe Geometrie, die _draw() als Plattenkanten zeichnet.

const RADII := [22.0, 27.0, 32.0]
const ANGULAR_SPEED := [0.25, -0.2, 0.15] # Godot: positives y nach unten = Uhrzeigersinn.
const COLORS := [Color(0.42, 0.95, 0.84, 0.85), Color(1.0, 0.82, 0.38, 0.80), Color(0.66, 1.0, 0.90, 0.75)]
## Lücke zwischen zwei Platten (Anteil einer Kante).
const GAP := 0.16

var _charges := 0
var _reduced_glow := false
var _angles: Array[float] = [0.0, 0.35, 0.7]
var _t := 0.0

func set_status(charges: int, reduce_effects: bool = false) -> void:
	var next := clampi(charges, 0, 3)
	visible = next > 0
	if next == _charges and reduce_effects == _reduced_glow:
		return
	_charges = next
	_reduced_glow = reduce_effects
	queue_redraw()

func advance(delta: float) -> void:
	if _charges == 0 or delta <= 0.0:
		return
	_t += delta
	for i in range(3):
		_angles[i] = wrapf(_angles[i] + float(ANGULAR_SPEED[i]) * delta, -PI, PI)
	queue_redraw()

## Geschlossene Sechsecke je Ladung (7 Punkte, erster = letzter).
func lines() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i in range(_charges):
		out.append(_hexagon(float(RADII[i]), _angles[i]))
	return out

func _hexagon(radius: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in range(7):
		pts.append(Vector2.from_angle(angle + TAU * float(v % 6) / 6.0) * radius)
	return pts

func _draw() -> void:
	if _charges <= 0:
		return
	var outer: float = RADII[_charges - 1]
	# Weiche Hülle: nur ein Hauch, damit die Biene klar lesbar bleibt.
	if not _reduced_glow:
		var shimmer := 0.05 + 0.02 * sin(_t * 3.0)
		draw_colored_polygon(_hexagon(outer + 2.0, _angles[_charges - 1]).slice(0, 6), Color(0.45, 0.95, 0.85, shimmer))
	var hexes := lines()
	for i in range(hexes.size()):
		var color: Color = COLORS[i]
		var pts := hexes[i]
		for e in range(6):
			var a := pts[e]
			var b := pts[e + 1]
			# Platte mit Fugen an beiden Enden.
			var p0 := a.lerp(b, GAP)
			var p1 := a.lerp(b, 1.0 - GAP)
			if not _reduced_glow:
				draw_line(p0, p1, Color(color, 0.16), 4.0, false)
			# Dunkle Pixelkontur, darauf die farbige Platte mit heller Oberkante.
			draw_line(p0, p1, Color(0.03, 0.03, 0.09, 0.75), 2.5, false)
			draw_line(p0, p1, color, 1.5, false)
			draw_line(p0.lerp(p1, 0.15), p0.lerp(p1, 0.55), color.lightened(0.45), 0.5, false)
			# Wabenknoten an der Ecke: kleines helles Quadrat mit Kontur.
			draw_rect(Rect2(a - Vector2(1.25, 1.25), Vector2(2.5, 2.5)), Color(0.03, 0.03, 0.09, 0.8))
			draw_rect(Rect2(a - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), color.lightened(0.4))
		# Wandernder Glanz auf dem äußersten Ring zeigt "aktiv".
		if i == hexes.size() - 1 and not _reduced_glow:
			var k := fposmod(_t * 0.6, 1.0) * 6.0
			var e2 := int(k) % 6
			var spot := pts[e2].lerp(pts[e2 + 1], k - floor(k))
			draw_circle(spot, 1.5, Color(1, 1, 1, 0.75), true, -1.0, false)
