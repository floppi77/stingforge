extends Node2D
## Befriedete Welt im Abspann: Schmetterlinge gaukeln, Pollen schweben, niemand schießt.

var _t := 0.0
var _flies: Array = []
var _motes: Array = []

func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 1992
	for i in range(7):
		_flies.append({"x": rng.randf_range(-200.0, 1160.0), "y": rng.randf_range(90.0, 420.0),
			"speed": rng.randf_range(26.0, 54.0), "phase": rng.randf() * TAU,
			"color": [Color("#ff9ec4"), Color("#ffd666"), Color("#9ee7ff"), Color("#c6a8ff")][i % 4]})
	for i in range(40):
		_motes.append({"x": rng.randf_range(-200.0, 1160.0), "y": rng.randf_range(50.0, 500.0),
			"speed": rng.randf_range(10.0, 34.0), "phase": rng.randf() * TAU})

func _process(delta: float) -> void:
	_t += delta
	for f in _flies:
		f.x = float(f.x) - float(f.speed) * delta
		if float(f.x) < -260.0:
			f.x = 1220.0
	for m in _motes:
		m.x = float(m.x) - float(m.speed) * delta
		if float(m.x) < -260.0:
			m.x = 1220.0
	queue_redraw()

func _draw() -> void:
	for m in _motes:
		var p := Vector2(float(m.x), float(m.y) + sin(_t * 0.9 + float(m.phase)) * 8.0).round()
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.95, 0.7, 0.55 + 0.3 * sin(_t * 2.0 + float(m.phase))))
	for f in _flies:
		var ph := float(f.phase)
		var p := Vector2(float(f.x), float(f.y) + sin(_t * 1.3 + ph) * 18.0).round()
		var open := absf(sin(_t * 9.0 + ph))
		var c: Color = f.color
		var wing := Vector2(round(2.0 + 3.0 * open), 4.0)
		draw_rect(Rect2(p + Vector2(-wing.x, -4), wing), c)
		draw_rect(Rect2(p + Vector2(1, -4), wing), c)
		draw_rect(Rect2(p + Vector2(-wing.x + 1, 0), wing - Vector2(1, 1)), c.darkened(0.2))
		draw_rect(Rect2(p + Vector2(1, 0), wing - Vector2(1, 1)), c.darkened(0.2))
		draw_rect(Rect2(p + Vector2(0, -4), Vector2(1, 7)), Color("#241a10"))
