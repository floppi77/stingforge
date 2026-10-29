extends Control
## Animierte Mini-Szene zur Werkstatt-Beschreibung: zeigt mit Spielgrafik, was ein
## Upgrade bewirkt (Schussbahn, Schild, Beute …). Reine Anzeige ohne Spiellogik.
## Gezeichnet wird in einem kleinen Pixelraster der Höhe H, ganzzahlig hochskaliert;
## "stage" ist die gezeigte Stufe (1–3) und steuert die Stärke der Szene.

const UiTheme := preload("res://scripts/core/ui_theme.gd")
const H := 76.0
const ARC := Color("#52d6c4")
const HOT := Color("#fff4dc")
const GOLD := Color("#ffd666")
const RED := Color("#ff5c84")
const GHOST := Color(0.66, 0.68, 0.79, 0.30)
const INK := Color(0.03, 0.03, 0.09, 0.9)

var item_id := ""
var stage := 1
var _t := 0.0
var _w := 200.0
## Kreisförmige Szenen (Kreisflug, Schild, Magnet) stellen die Biene in die Mitte.
var _bee_x := 30.0
var _font: Font

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, UiTheme.pad(78))
	_font = UiTheme.font_caps()

func show_item(id: String, level: int) -> void:
	item_id = id
	stage = clampi(level, 1, 3)
	_t = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()

func _draw() -> void:
	draw_style_box(UiTheme.framed("slot", 4, 0), Rect2(Vector2.ZERO, size))
	var k := maxf(1.0, floorf(size.y / H)) if size.y >= H else size.y / H
	_w = size.x / k
	var oy := floorf((size.y - H * k) * 0.5)
	draw_set_transform(Vector2(0, oy), 0.0, Vector2(k, k))
	var scene := "_s_" + item_id
	_bee_x = 30.0
	if has_method(scene):
		call(scene)
	else:
		_s_default()
	draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ Bausteine
func _bee_pos() -> Vector2:
	return Vector2(_bee_x, H * 0.5 + roundf(sin(_t * 2.4) * 1.5))

func _x0() -> float:
	return _bee_pos().x + 16.0

func _x1() -> float:
	return _w - 6.0

func _loop(speed: float, phase: float = 0.0) -> float:
	return fposmod(_t * speed + phase, 1.0)

func _sprite(name: String, center: Vector2, mod: Color = Color.WHITE, scale: float = 1.0,
		flip: bool = false, frame: int = -1) -> void:
	var n := Art.frame_count(name)
	var f := frame if frame >= 0 else int(_t * float(Art.info(name).get("fps", 8))) % n
	var tex := Art.frame_tex(name, f)
	var s := tex.get_size() * scale
	var r := Rect2((center - s * 0.5).floor(), s)
	if flip:
		r = Rect2(r.position + Vector2(s.x, 0), Vector2(-s.x, s.y))
	draw_texture_rect(tex, r, false, mod)

func _bee(mod: Color = Color.WHITE) -> void:
	_sprite("bee", _bee_pos(), mod)

func _shot(p: Vector2, mod: Color = Color.WHITE, scale: float = 1.0, flip: bool = false) -> void:
	_sprite("bullet_base", p, mod, scale, flip)

func _dot(p: Vector2, col: Color, s: float = 2.0) -> void:
	draw_rect(Rect2((p - Vector2(s, s) * 0.5).floor(), Vector2(s, s)), col)

func _spark(p: Vector2, col: Color, r: float = 3.0) -> void:
	var c := p.floor()
	draw_rect(Rect2(c + Vector2(-r, 0), Vector2(r * 2 + 1, 1)), col)
	draw_rect(Rect2(c + Vector2(0, -r), Vector2(1, r * 2 + 1)), col)
	draw_rect(Rect2(c, Vector2(1, 1)), HOT)

func _text(p: Vector2, txt: String, col: Color = GOLD, fs: int = 8) -> void:
	txt = Loc.tx(txt)
	draw_string_outline(_font, p.floor(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, INK)
	draw_string(_font, p.floor(), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Gerader Schussstrom von der Biene nach rechts.
func _stream(y: float, n: int, speed: float, phase: float = 0.0, mod: Color = Color.WHITE,
		scale: float = 1.0) -> void:
	var span := _x1() - _x0()
	for i in range(n):
		var u := _loop(speed / span, float(i) / float(n) + phase)
		_shot(Vector2(lerpf(_x0(), _x1(), u), y), mod, scale)

func _ghost_path(pts: PackedVector2Array, col: Color = GHOST) -> void:
	for i in range(0, pts.size(), 3):
		_dot(pts[i], col, 1.0)

func _hex(center: Vector2, radius: float, angle: float, col: Color, edges: float = 6.0) -> void:
	var whole := int(floorf(edges))
	for e in range(mini(6, whole + 1)):
		var a := center + Vector2.from_angle(angle + TAU * e / 6.0) * radius
		var b := center + Vector2.from_angle(angle + TAU * (e + 1) / 6.0) * radius
		var part := clampf(edges - float(e), 0.0, 1.0)
		if part <= 0.0:
			break
		var p0 := a.lerp(b, 0.14)
		var p1 := p0.lerp(a.lerp(b, 0.86), part)
		draw_line(p0, p1, INK, 3.0)
		draw_line(p0, p1, col, 1.0)

func _heart(p: Vector2, full: bool, pulse: float = 0.0) -> void:
	var mod := Color.WHITE if full else Color(0.35, 0.35, 0.45, 0.7)
	_sprite("heart", p, mod, 1.0 + pulse, false, 0)

# ------------------------------------------------------------------ Schussform
func _s_default() -> void:
	_bee()
	_stream(_bee_pos().y, 4, 70.0)

func _s_orbit() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	var r := 15.0 + 4.0 * stage
	var ring := PackedVector2Array()
	for i in range(48):
		ring.append(b + Vector2.from_angle(TAU * i / 48.0) * r)
	_ghost_path(ring, Color(ARC, 0.35))
	_bee()
	var n := 3 + stage
	var spin := 2.6 + 0.5 * stage
	for i in range(n):
		_shot(b + Vector2.from_angle(_t * spin + TAU * i / n) * r)
	_stream(b.y, 2, 60.0, 0.0, Color(1, 1, 1, 0.55))

func _wave_scene(amp: float, freq: float, ghost_amp: float = -1.0, ghost_freq: float = -1.0) -> void:
	var b := _bee_pos()
	if ghost_amp > 0.0:
		var g := PackedVector2Array()
		for x in range(int(_x0()), int(_x1())):
			g.append(Vector2(x, b.y + ghost_amp * sin((x - _x0()) * ghost_freq)))
		_ghost_path(g)
	# Schüsse wechseln die Phase (gespiegelte Welle) wie im Spiel.
	for sgn in [1.0, -1.0]:
		var path := PackedVector2Array()
		for x in range(int(_x0()), int(_x1())):
			path.append(Vector2(x, b.y + sgn * amp * sin((x - _x0()) * freq)))
		_ghost_path(path, Color(ARC, 0.4))
	_bee()
	var span := _x1() - _x0()
	for i in range(8):
		var u := _loop(55.0 / span, float(i) / 8.0)
		var x := lerpf(_x0(), _x1(), u)
		var sgn := 1.0 if i % 2 == 0 else -1.0
		_shot(Vector2(x, b.y + sgn * amp * sin((x - _x0()) * freq)))

func _s_wave() -> void:
	_wave_scene(9.0 + 3.0 * stage, 0.085)

func _s_wave_freq() -> void:
	_wave_scene(12.0, 0.085 * (1.0 + 0.3 * stage + (0.1 if stage == 3 else 0.0)), 12.0, 0.085)

func _s_wave_amp() -> void:
	_wave_scene(8.0 + 5.0 * stage, 0.085, 8.0, 0.085)

func _s_back() -> void:
	var b := _bee_pos()
	_bee()
	_stream(b.y, 3, 70.0)
	var fan: Array = [0.0] if stage == 1 else [-0.22, 0.22]
	var scale := 1.35 if stage >= 3 else 1.0
	for a in fan:
		for i in range(2):
			var u := _loop(0.9, i * 0.5)
			var p := b + Vector2(-12, 0) + Vector2.from_angle(PI + float(a)) * u * (b.x + 2.0)
			_shot(p, Color(1.0, 0.85, 0.6), scale, true)
	_sprite("mosquito", Vector2(6, b.y - 14), Color(1, 1, 1, 0.9))

func _s_side() -> void:
	var b := _bee_pos()
	_bee()
	_stream(b.y, 3, 70.0)
	var scale := 0.9 + 0.2 * stage
	for dir in [-1.0, 1.0]:
		for i in range(2):
			var u := _loop(1.1, i * 0.5)
			_shot(b + Vector2(4.0 + u * 14.0, dir * (8.0 + u * 28.0)), Color(0.75, 1.0, 0.95), scale)
	_sprite("aphid", Vector2(b.x + 26, 8), Color(1, 1, 1, 0.9))

func _s_multishot() -> void:
	var b := _bee_pos()
	_bee()
	_stream(b.y - 4, 4, 70.0)
	var mod := Color(1, 1, 1, 0.45 + 0.18 * stage)
	_stream(b.y + 5, 4, 70.0, 0.125, mod, 0.8 + 0.1 * stage)

func _s_spiral() -> void:
	var b := _bee_pos()
	_bee()
	_stream(b.y, 3, 70.0)
	var n := 5 + stage * 2
	var step := 0.55 + 0.35 * stage
	for i in range(n):
		var age := _loop(0.45, float(i) / n)
		var ang := float(i) * step - 0.6
		var p := b + Vector2(10, 0) + Vector2.from_angle(ang) * age * 54.0
		_shot(p, Color(1.0, 0.8, 1.0, 1.0 - age * 0.6))

func _homing_scene(power: float) -> void:
	var b := _bee_pos()
	var e := Vector2(_x1() - 18.0, H * 0.5 + sin(_t * 1.6) * 22.0)
	_bee()
	_sprite("aphid", e)
	for i in range(3):
		var u := _loop(0.7, i / 3.0)
		var start := b + Vector2(14, 0)
		# Kontrollpunkt geradeaus: je stärker die Lenkung, desto früher dreht der Schuss ein.
		var ctrl := Vector2(lerpf(start.x, e.x, 1.0 - 0.28 * power), start.y)
		var p := start.lerp(ctrl, u).lerp(ctrl.lerp(e, u), u)
		_shot(p, Color(0.8, 1.0, 0.9))
		if u > 0.92:
			_spark(e, GOLD)

func _s_homing() -> void:
	_homing_scene(float(stage))

func _s_homing_power() -> void:
	_homing_scene(1.0 + stage * 0.7)

# ------------------------------------------------------------------ Wirkung
func _s_pierce() -> void:
	var b := _bee_pos()
	_bee()
	# Der Schuss durchschlägt "stage" Gegner zusätzlich und bleibt im letzten stecken.
	var n := stage + 2
	var xs: Array[float] = []
	for i in range(n):
		xs.append(lerpf(_x0() + 22.0, _x1() - 10.0, float(i) / float(n - 1)))
	var u := minf(1.0, _loop(0.55) * 1.25)
	var x := lerpf(_x0(), xs[n - 1], u)
	for i in range(n):
		var hit := x >= xs[i]
		_sprite("aphid", Vector2(xs[i], b.y), Color(1, 0.6, 0.6, 0.6) if hit and i < n - 1 else Color.WHITE)
		if hit and x - xs[i] < 6.0:
			_spark(Vector2(xs[i], b.y), GOLD)
	if u < 1.0:
		_shot(Vector2(x, b.y))
	else:
		_spark(Vector2(xs[n - 1], b.y), HOT, 4.0)

func _s_splash() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x1() - 30.0, b.y)
	var u := _loop(0.6)
	_sprite("aphid", e, Color.WHITE if u < 0.55 else Color(1, 0.6, 0.6))
	if u < 0.55:
		_shot(Vector2(lerpf(_x0(), e.x, u / 0.55), b.y))
	else:
		var k := (u - 0.55) / 0.45
		var r := (8.0 + 5.0 * stage) * minf(1.0, k * 1.6)
		for i in range(14):
			var a := TAU * i / 14.0 + i * 0.4
			_dot(e + Vector2.from_angle(a) * r * (0.6 + 0.4 * fposmod(i * 0.37, 1.0)),
				Color(GOLD, 1.0 - k), 2.0)
		_spark(e, HOT, 4.0)

func _s_chain() -> void:
	var b := _bee_pos()
	_bee()
	var foes: Array[Vector2] = [Vector2(_x0() + 40, b.y), Vector2(_x0() + 70, 16), Vector2(_x0() + 92, H - 18),
		Vector2(_x1() - 12, 22)]
	for f in foes:
		_sprite("aphid", f)
	var u := _loop(0.6)
	if u < 0.4:
		_shot(Vector2(lerpf(_x0(), foes[0].x, u / 0.4), b.y))
		return
	var k := (u - 0.4) / 0.6
	var jumps := mini(stage, int(k * 4.0))
	for j in range(jumps):
		_bolt(foes[j], foes[j + 1])
	_spark(foes[0], ARC)

func _bolt(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array([a])
	for i in range(1, 5):
		var p := a.lerp(b, i / 5.0)
		pts.append(p + Vector2(0, (fposmod(sin(i * 12.9 + floorf(_t * 14.0)) * 43.7, 1.0) - 0.5) * 8.0))
	pts.append(b)
	draw_polyline(pts, INK, 3.0)
	draw_polyline(pts, ARC, 1.0)
	_dot(b, HOT, 2.0)

func _s_big_bullet() -> void:
	var b := _bee_pos()
	_bee()
	_stream(b.y, 3, 60.0, 0.0, Color.WHITE, 1.0 + 0.25 * stage)
	_sprite("beetle", Vector2(_x1() - 14, b.y))

func _s_crit() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x1() - 24, b.y)
	_sprite("aphid", e)
	var u := _loop(0.9)
	var span := e.x - _x0()
	var x := _x0() + u * span
	_shot(Vector2(x, b.y))
	# Seltener bis häufiger Volltreffer: jeder 4./3./2. Schuss in der Vorschau.
	var crit := posmod(int(floorf(_t * 0.9)), [4, 3, 2][stage - 1]) == 0
	if u > 0.85:
		if crit:
			_spark(e, GOLD, 6.0)
			_text(e + Vector2(-8, -12), "x2", GOLD)
		else:
			_spark(e, HOT, 3.0)
	_text(Vector2(_x0() - 4, H - 6), "%d%%" % [12, 20, 30][stage - 1], UiTheme.DIM)

func _s_boss_bane() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x1() - 22, b.y)
	_sprite("beetle", e, Color.WHITE, 1.4)
	_stream(b.y, 3, 70.0)
	# Risse im Panzer wachsen mit der Stufe.
	for i in range(stage + 1):
		var s := e + Vector2(-10 + i * 5, -8 + (i % 2) * 5)
		draw_line(s, s + Vector2(4, 5), INK, 1.0)
		draw_line(s + Vector2(4, 5), s + Vector2(2, 10), INK, 1.0)
	_text(Vector2(e.x - 20, 12), "+%d%%" % [15, 30, 50][stage - 1], GOLD)

func _s_splinter() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x0() + 44, b.y)
	_sprite("aphid", e)
	var u := _loop(0.7)
	if u < 0.4:
		_shot(Vector2(lerpf(_x0(), e.x, u / 0.4), b.y))
	else:
		var k := (u - 0.4) / 0.6
		_spark(e, GOLD, 3.0)
		_shot(e + Vector2(k * 60.0, 0), Color(1.0, 0.75, 0.5), 0.7)
	_text(Vector2(_x1() - 26, H - 6), "1/%d" % [5, 3, 2][stage - 1], UiTheme.DIM)

# ------------------------------------------------------------------ Tempo
func _s_fire_rate() -> void:
	var b := _bee_pos()
	_stream(b.y + 9, 4, 60.0, 0.0, Color(1, 1, 1, 0.25))
	_bee()
	_stream(b.y, 4 + stage * 2, 60.0 * (1.0 + 0.15 * stage))

func _s_bullet_speed() -> void:
	var b := _bee_pos()
	_bee()
	var speed: float = 70.0 * (1.0 + float([0.2, 0.35, 0.5][stage - 1]))
	var span := _x1() - _x0()
	for i in range(3):
		var x := lerpf(_x0(), _x1(), _loop(speed / span, i / 3.0))
		for s in range(1, 4):
			_dot(Vector2(x - 4.0 - s * 4.0, b.y), Color(GOLD, 0.6 - s * 0.15), 2.0)
		_shot(Vector2(x, b.y))
	_stream(b.y + 10, 3, 70.0, 0.0, Color(1, 1, 1, 0.25))

func _s_burst() -> void:
	var b := _bee_pos()
	_bee()
	var every: int = [6, 5, 4][stage - 1]
	var span := _x1() - _x0()
	for i in range(every):
		var u := _loop(55.0 / span, float(i) / every)
		var x := lerpf(_x0(), _x1(), u)
		if i == 0:
			for dy in [-5.0, 0.0, 5.0]:
				_shot(Vector2(x, b.y + dy), Color(1.0, 0.85, 0.55))
		else:
			_shot(Vector2(x, b.y))

# ------------------------------------------------------------------ Schutz
func _s_shield_regen() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_bee()
	var fill: float = _loop(0.35 * float([1.5, 2.0, 3.0][stage - 1])) * 6.0
	_hex(b, 20.0, _t * 0.3, Color(ARC, 0.9), fill)
	_text(Vector2(_x0() + 30, H * 0.5 + 3), "x%s" % ["1.5", "2", "3"][stage - 1], ARC)

func _s_extra_shield() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	var u := _loop(0.45)
	var safe: float = [0.25, 0.5, 0.85][stage - 1]
	if u < 0.35:
		_hex(b, 20.0, _t * 0.3, Color(ARC, 0.9))
		_sprite("ebullet_orb", Vector2(lerpf(_x1(), b.x + 20.0, u / 0.35), b.y))
	else:
		var k := (u - 0.35) / 0.65
		var glow: bool = k < 0.35 + safe * 0.5
		_bee(Color(0.6, 1.0, 0.95, 0.6) if glow and int(_t * 12.0) % 2 == 0 else Color.WHITE)
		_bar(Vector2(_x0() + 20, H - 12), 60.0, 1.0 - clampf(k / (0.35 + safe * 0.5), 0.0, 1.0), ARC)
		_text(Vector2(_x0() + 20, H - 16), "+%ss" % Loc.dec(str(safe)), ARC)
		return
	_bee()

func _bar(p: Vector2, w: float, v: float, col: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2(w, 4)), INK)
	draw_rect(Rect2(p.floor() + Vector2(1, 1), Vector2(floorf((w - 2) * v), 2)), col)

func _s_extra_life() -> void:
	_bee_x = floorf(_w * 0.32)
	_bee()
	for i in range(3 + stage):
		var extra := i >= 3
		_heart(Vector2(_x0() + 10 + i * 16, H * 0.5), true, 0.15 * sin(_t * 5.0) if extra else 0.0)
		if extra:
			_text(Vector2(_x0() + 4 + i * 16, H * 0.5 - 10), "+", GOLD)

func _s_iframe_plus() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	var u := _loop(0.5)
	var dur: float = [0.3, 0.55, 0.85][stage - 1]
	if u < 0.25:
		_bee()
		_sprite("ebullet_orb", Vector2(lerpf(_x1(), b.x + 8.0, u / 0.25), b.y))
		return
	var k := (u - 0.25) / 0.75
	var base := 0.35
	var limit: float = base + dur * 0.5
	var blink: bool = k < limit and int(_t * 14.0) % 2 == 0
	_bee(Color(1, 1, 1, 0.25) if blink else Color.WHITE)
	_bar(Vector2(_x0() + 20, H - 12), 60.0, 1.0 - clampf(k / limit, 0.0, 1.0), GOLD)
	draw_rect(Rect2(Vector2(_x0() + 20 + 60.0 * base / limit, H - 13), Vector2(1, 6)), HOT)
	_text(Vector2(_x0() + 20, H - 16), "+%ss" % Loc.dec(str(dur)), GOLD)

func _s_bomb_radius() -> void:
	var c := Vector2(_w * 0.5, H * 0.5)
	var u := _loop(0.5)
	var r := (14.0 + 6.0 * stage) * minf(1.0, u * 2.0)
	var ghost := 14.0
	var ring := PackedVector2Array()
	for i in range(40):
		ring.append(c + Vector2.from_angle(TAU * i / 40.0) * ghost)
	_ghost_path(ring)
	for f in [Vector2(-30, -14), Vector2(28, 16), Vector2(36, -10), Vector2(-24, 18)]:
		var p: Vector2 = c + f
		var gone: bool = u < 0.5 and p.distance_to(c) <= r
		if not gone:
			_sprite("aphid", p)
		else:
			_spark(p, GOLD, 2.0)
	if u < 0.5:
		draw_arc(c, r, 0.0, TAU, 40, INK, 3.0)
		draw_arc(c, r, 0.0, TAU, 40, Color(GOLD, 1.0 - u), 1.0)
	_sprite("bomb", c)

func _s_bomb_charge() -> void:
	_bee()
	var speed: float = [1.25, 1.45, 1.65][stage - 1]
	var v := _loop(0.4 * speed)
	_sprite("icon_bombs", Vector2(_x0() + 14, H * 0.5))
	_bar(Vector2(_x0() + 30, H * 0.5 + 6), 60.0, v, GOLD)
	_bar(Vector2(_x0() + 30, H * 0.5 - 6), 60.0, _loop(0.4), Color(UiTheme.DIM, 0.6))
	_text(Vector2(_x0() + 30, H * 0.5 - 12), "+%d%%" % [25, 45, 65][stage - 1], GOLD)

# ------------------------------------------------------------------ Ausbeute
func _s_magnet() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	var r: float = 18.0 * (1.0 + float([0.6, 1.2, 2.0][stage - 1]) * 0.5)
	var base := PackedVector2Array()
	var ring := PackedVector2Array()
	for i in range(48):
		base.append(b + Vector2.from_angle(TAU * i / 48.0) * 18.0)
		ring.append(b + Vector2.from_angle(TAU * i / 48.0) * r)
	_ghost_path(base)
	_ghost_path(ring, Color(GOLD, 0.45))
	_bee()
	for i in range(6):
		var a := TAU * i / 6.0 + 0.3
		var u := _loop(0.5, i / 6.0)
		var start := b + Vector2.from_angle(a) * r
		_sprite("nectar", start.lerp(b, u * u))

func _s_nectar_plus() -> void:
	# Mit etwas Glück fällt ein zusätzlicher Tropfen (jeder dritte Zyklus in der Vorschau).
	var e := Vector2(_w * 0.55, 20)
	var u := _loop(0.5)
	if u < 0.2:
		_sprite("aphid", e)
		return
	_spark(e, GOLD, 3.0)
	var k := (u - 0.2) / 0.8
	var lucky := posmod(int(floorf(_t * 0.5)), 3) == 0
	_sprite("nectar", e + Vector2(-6.0 * k, k * k * 40.0))
	if lucky:
		_sprite("nectar", e + Vector2(9.0 * k, k * k * 40.0), Color(1, 1, 0.7))
		_text(e + Vector2(14, -6), "+1", GOLD)
	_text(Vector2(e.x + 22, 18), "%d%%" % [15, 20, 30][stage - 1], UiTheme.DIM)

func _s_graze() -> void:
	var b := _bee_pos()
	_bee()
	for i in range(3):
		var u := _loop(0.5, i / 3.0)
		var y: float = b.y + float([-9.0, 10.0, -14.0][i])
		var x := lerpf(_x1(), -8.0, u)
		_sprite("ebullet_orb", Vector2(x, y))
		if absf(x - b.x) < 10.0:
			_spark(Vector2(b.x, (y + b.y) * 0.5), GOLD, 3.0)
			_text(Vector2(b.x + 10, y - 2), "+%d" % [3, 6, 10][stage - 1], GOLD)

func _s_combo() -> void:
	var b := _bee_pos()
	_bee()
	var u := _loop(0.35)
	var kills := int(u * 5.0)
	for i in range(4):
		var p := Vector2(_x0() + 22 + i * 18, b.y + (6 if i % 2 == 0 else -6))
		if i >= kills:
			_sprite("aphid", p)
		else:
			_spark(p, GOLD, 2.0)
	_text(Vector2(_x0() + 22, 12), Loc.tx("SERIE x%d") % maxi(1, kills), GOLD)
	_text(Vector2(_x0() + 22, H - 6), "+%d%%" % [8, 16, 26][stage - 1], UiTheme.DIM)

func _s_convert_bonus() -> void:
	var c := H * 0.5
	_sprite("nectar", Vector2(22, c))
	_text(Vector2(30, c + 3), "x10", UiTheme.DIM)
	var u := _loop(0.6)
	for i in range(4):
		var x := lerpf(52.0, _w - 70.0, fposmod(u + i * 0.25, 1.0))
		_dot(Vector2(x, c), Color(GOLD, 0.8), 2.0)
	_text(Vector2(_w - 64, c + 3), "+%d%%" % [25, 50, 80][stage - 1], GOLD, 16)

func _s_start_heal() -> void:
	_text(Vector2(10, 14), "LEVEL-START", UiTheme.DIM)
	var u := _loop(0.4)
	var healed := int(u * 4.0)
	for i in range(5):
		var restored := i >= 2 and i < 2 + stage
		var full := i < 2 or (restored and i - 2 < healed)
		_heart(Vector2(18 + i * 16, H * 0.5 + 6), full, 0.2 if restored and i - 2 == healed - 1 else 0.0)
