extends RefCounted
## Gemeinsame Zeichnung der Level-Laufzeitleiste (HUD-Rail und Pause-Panel).
## Erwartet die Schätzung aus Director.eta(); reine Darstellung, keine Logik.

const TRACK := Color("#22264a")
const FILL := Color("#52d6c4")
const GOLD := Color("#ffd666")
const DIM := Color("#4c568a")
const ALERT := Color("#ff5c84")
const INK := Color("#08071a")

## Restzeit als "1:24"; unter zehn Sekunden mit Sekundenangabe "0:07".
static func clock(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]

## Kurzer Begleittext zur Leiste, passend zur Phase.
static func caption(info: Dictionary) -> String:
	match String(info.get("phase", "run")):
		"boss":
			return "Bosskampf"
		"wait":
			return "Boss naht"
		"rush":
			return "Boss %d / %d" % [int(info.get("index", 1)), int(info.get("count", 1))]
	return "Boss in " + clock(float(info.get("remaining", 0.0)))

## Zeichnet die Leiste in `rect` auf `ci`. `t` treibt das sanfte Pulsieren.
static func draw_track(ci: CanvasItem, rect: Rect2, info: Dictionary, s: float, t: float = 0.0) -> void:
	if rect.size.x <= 4.0 or rect.size.y <= 0.0 or info.is_empty():
		return
	var h := maxf(2.0, minf(rect.size.y, 4.0 * s))
	var bar := Rect2(rect.position.x, rect.position.y + (rect.size.y - h) * 0.5,
		rect.size.x - 7.0 * s, h)
	var phase := String(info.get("phase", "run"))
	var frac := clampf(float(info.get("progress", 0.0)), 0.0, 1.0)
	_pill(ci, bar, TRACK)
	if frac > 0.0:
		var fill := Rect2(bar.position, Vector2(maxf(h, bar.size.x * frac), h))
		_pill(ci, fill, FILL.lerp(GOLD, 0.65) if phase != "run" else FILL)
		# Heller Kopf am aktuellen Ende statt eines harten Abbruchs.
		if phase == "run" and fill.size.x > h * 2.0:
			_pill(ci, Rect2(fill.end.x - h * 2.0, fill.position.y, h * 2.0, h), FILL.lightened(0.35))
	var mid := bar.position.y + h * 0.5
	for m in info.get("marks", []):
		var x := bar.position.x + bar.size.x * float(m)
		var passed := float(m) <= frac + 0.0005
		_diamond(ci, Vector2(x, mid), 2.6 * s, FILL if passed else DIM, INK, s)
	var mini := float(info.get("miniboss", -1.0))
	if mini >= 0.0:
		var mx := bar.position.x + bar.size.x * mini
		_triangle(ci, Vector2(mx, mid), 2.8 * s, ALERT if mini > frac else ALERT.darkened(0.35))
	# Bossmarke am Ende; pulsiert, sobald der Boss unmittelbar bevorsteht.
	var pulse := 0.5 + 0.5 * sin(t * 6.0) if phase in ["wait", "boss"] else 0.0
	var end := Vector2(bar.end.x + 3.5 * s, mid)
	if pulse > 0.0:
		ci.draw_circle(end, (4.4 + 1.6 * pulse) * s, Color(GOLD, 0.18 * pulse))
	_diamond(ci, end, 4.0 * s, GOLD, INK, s)
	if phase == "run" and frac > 0.0 and frac < 1.0:
		var head := Vector2(bar.position.x + bar.size.x * frac, mid)
		ci.draw_circle(head, 2.3 * s, Color.WHITE.lerp(FILL, 0.3))

static func _pill(ci: CanvasItem, r: Rect2, color: Color) -> void:
	# Pixelbalken: harte Kanten, oben eine helle Zeile als Glanz.
	var rr := Rect2(r.position.round(), r.size.round())
	ci.draw_rect(rr, color)
	if rr.size.y >= 4.0:
		ci.draw_rect(Rect2(rr.position, Vector2(rr.size.x, floor(rr.size.y / 4.0))), color.lightened(0.25))

static func _diamond(ci: CanvasItem, c: Vector2, r: float, fill: Color, edge: Color, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, edge, maxf(1.0, 0.8 * s), true)

static func _triangle(ci: CanvasItem, c: Vector2, r: float, fill: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.9), c + Vector2(r, -r * 0.9),
		c + Vector2(0, r * 0.9)]), fill)
