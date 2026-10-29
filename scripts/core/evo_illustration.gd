extends "res://scripts/core/upgrade_illustration.gd"
## Animierte Mini-Szene für Evolutionen, Meisterevolutionen und Verschmelzungen.
## Nutzt die Bausteine der Werkstatt-Illustration; passende Werkstatt-Szenen werden
## wiederverwendet, alles andere hat eine eigene Szene (_s_ev_*, _s_m_*).
## Schlüssel: Evolutions-ID, Meister-ID (m_…), Verschmelzung "a+b" oder "locked".
## Verschmelzungen zeigen abwechselnd beide Eltern in verstärkter Form.

const SWARM := Color("#8fd0ff")
const POLLEN := Color("#c8e85a")
const CHITIN := Color("#ff9e5e")
const RESO := Color("#d690ff")
const FUSION_SWAP := 2.4

## Evolution → [Szene, Stufe]. Szenen ohne Eintrag heißen _s_ev_<id>.
const EVO_SCENES := {
	"pierce1": ["pierce", 1], "stinger_rapid": ["fire_rate", 2], "heavy_sting": ["big_bullet", 3],
	"pierce_master": ["pierce", 3], "pollen_economy": ["magnet", 2], "chitin_plate": ["extra_life", 1],
	"nectar_gluttony": ["nectar_plus", 2],
}

var key := ""
var _fusion: Array = []
var _fusion_side := 0

func show_evo(k: String) -> void:
	key = k
	_t = 0.0
	_fusion = []
	if k.contains("+"):
		_fusion = Array(k.split("+"))
		_fusion_side = 0
		_apply(String(_fusion[0]), true)
	elif k == "locked":
		item_id = "ev_locked"
		stage = 1
	else:
		_apply(k, false)
	queue_redraw()

## Setzt Szene und Stufe; in der Verschmelzung eine Stufe stärker.
func _apply(id: String, boosted: bool) -> void:
	var pick: Array = EVO_SCENES.get(id, [])
	if pick.is_empty():
		item_id = ("" if id.begins_with("m_") else "ev_") + id
		stage = 2 if boosted else 1
	else:
		item_id = String(pick[0])
		stage = mini(3, int(pick[1]) + (1 if boosted else 0))
	if not has_method("_s_" + item_id):
		item_id = "default"

func _process(delta: float) -> void:
	super._process(delta)
	if _fusion.is_empty():
		return
	var side := int(floorf(_t / FUSION_SWAP)) % 2
	if side != _fusion_side:
		_fusion_side = side
		var keep := _t
		_apply(String(_fusion[side]), true)
		_t = keep

func _draw() -> void:
	super._draw()
	if _fusion.is_empty():
		return
	# Verschmelzung: Kennzeichen oben rechts, welche der beiden Hälften gerade läuft.
	var k := maxf(1.0, floorf(size.y / H)) if size.y >= H else size.y / H
	draw_set_transform(Vector2(0, floorf((size.y - H * k) * 0.5)), 0.0, Vector2(k, k))
	_text(Vector2(_w - 30, 10), "%d/2 +" % (_fusion_side + 1), ARC)
	draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ Gesperrt
func _s_ev_locked() -> void:
	var c := Vector2(_w * 0.5, H * 0.5)
	_text(c + Vector2(-12, 4), "???", UiTheme.DIM, 16)
	draw_rect(Rect2(c + Vector2(-34, -7), Vector2(10, 9)), Color(UiTheme.DIM, 0.6))
	draw_arc(c + Vector2(-29, -8), 4.0, PI, TAU, 8, Color(UiTheme.DIM, 0.6), 2.0)

# ------------------------------------------------------------------ Hilfen
func _foe(p: Vector2, hit := false, sprite_name := "aphid") -> void:
	_sprite(sprite_name, p, Color(1, 0.55, 0.55) if hit else Color.WHITE)

func _cloud(p: Vector2, r: float, a: float, col: Color = POLLEN) -> void:
	for i in range(9):
		var o := Vector2.from_angle(i * 2.39 + _t * 0.6) * r * (0.35 + 0.65 * fposmod(i * 0.37, 1.0))
		_dot(p + o, Color(col, a), 3.0)

func _drone(p: Vector2, mod: Color = Color.WHITE) -> void:
	_sprite("drone", p, mod, 0.8)

func _ring(c: Vector2, r: float, col: Color, w := 1.0) -> void:
	draw_arc(c, r, 0.0, TAU, 36, INK, w + 2.0)
	draw_arc(c, r, 0.0, TAU, 36, col, w)

# ------------------------------------------------------------------ Stachel
## Eigene Szenen statt Werkstatt-Szenen, wo die Zahlen der Evolution abweichen.
## In der Verschmelzung (stage 2) zeigen sie die verstärkte Wirkung.
func _s_ev_crit() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x1() - 24, b.y)
	_foe(e)
	var u := _loop(0.9)
	_shot(Vector2(_x0() + u * (e.x - _x0()), b.y))
	var crit := posmod(int(floorf(_t * 0.9)), 6 if stage == 1 else 4) == 0
	if u > 0.85:
		_spark(e, GOLD if crit else HOT, 6.0 if crit else 3.0)
		if crit:
			_text(e + Vector2(-8, -12), "x2", GOLD)
	_text(Vector2(_x0() - 4, H - 6), "14%" if stage == 1 else "21%", UiTheme.DIM)

func _s_ev_splinter() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x0() + 44, b.y)
	_foe(e)
	var u := _loop(0.7)
	if u < 0.4:
		_shot(Vector2(lerpf(_x0(), e.x, u / 0.4), b.y))
		return
	var k := (u - 0.4) / 0.6
	_spark(e, GOLD, 3.0)
	var dirs: Array = [-1.0, 1.0] if stage == 1 else [-1.0, 0.0, 1.0]
	for d in dirs:
		_shot(e + Vector2(k * 50.0, float(d) * k * 26.0), Color(1.0, 0.75, 0.5), 0.7)

func _s_ev_chitin_regen() -> void:
	_bee_x = floorf(_w * 0.25)
	_bee()
	var flag := Vector2(_x0() + 26, H * 0.5)
	draw_line(flag + Vector2(0, -12), flag + Vector2(0, 10), HOT, 1.0)
	draw_rect(Rect2(flag + Vector2(1, -12), Vector2(9, 6)), CHITIN)
	var u := _loop(0.4)
	var healed := u > 0.45
	for i in range(3):
		var full := i < 1 or (i == 1 and healed) or (stage >= 2 and i == 2 and u > 0.7)
		_heart(Vector2(flag.x + 24 + i * 16, H * 0.5), full, 0.2 if full and i >= 1 and u < 0.8 else 0.0)
	_text(Vector2(flag.x - 8, H - 6), "CHECKPOINT", UiTheme.DIM)

func _s_ev_chitin_bastion() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_bee()
	var fill: float = _loop(0.55 if stage == 1 else 0.7) * 6.0
	_hex(b, 20.0, _t * 0.3, Color(ARC, 0.9), fill)
	if fill > 5.6:
		_ring(b, 24.0 + fposmod(_t * 30.0, 10.0), Color(CHITIN, 0.7))
	_text(Vector2(_x0() + 30, H * 0.5 + 3), "-35%" if stage == 1 else "-52%", ARC)

# ------------------------------------------------------------------ Schwarm
func _s_ev_companion_form() -> void:
	var b := _bee_pos()
	_bee()
	var forward := fposmod(_t, 4.0) < 2.0
	for i in range(3):
		var p: Vector2
		if forward:
			p = b + Vector2(16 + i * 12, -14 + i * 14)
		else:
			p = b + Vector2.from_angle(_t * 2.5 + TAU * i / 3.0) * 16.0
		_drone(p)
		if forward:
			_shot(p + Vector2(10 + _loop(1.2, i * 0.3) * 60.0, 0), Color(SWARM, 0.9), 0.8)
	_text(Vector2(_x1() - 50, H - 6), "REIHE" if forward else "KREIS", SWARM)

func _s_ev_companion_add() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_bee()
	for i in range(3):
		var extra := i == 2
		var p := b + Vector2.from_angle(_t * 2.2 + TAU * i / 3.0) * 20.0
		_drone(p, Color(1, 1, 0.7) if extra else Color.WHITE)
		if extra:
			_text(p + Vector2(6, -6), "+1", GOLD)

func _s_ev_swarm_mark() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x1() - 26, b.y)
	var u := _loop(0.3)
	var hits := mini(6, int(u * 9.0))
	_foe(e, hits >= 6)
	for i in range(6):
		_dot(e + Vector2(-10 + i * 4, -12), GOLD if i < hits else Color(UiTheme.DIM, 0.6), 2.0)
	if hits < 6:
		_stream(b.y, 3, 80.0)
	else:
		var k := (u * 9.0 - 6.0) / 3.0
		for i in range(4):
			var p := Vector2(lerpf(-6.0, e.x - 6.0, k), e.y - 16 + i * 10)
			_sprite("bee", p, Color(SWARM, 0.85), 0.55)
		_spark(e, GOLD, 4.0)

func _s_ev_swarm_echo() -> void:
	var b := _bee_pos()
	_bee()
	for dy in [-16.0, 16.0]:
		var d := b + Vector2(6, dy)
		_drone(d)
		_stream(d.y, 4, 90.0, 0.1, Color(SWARM, 0.95), 0.8)
	_stream(b.y, 3, 70.0)
	_text(Vector2(_x1() - 34, H - 6), "+25%", SWARM)

func _s_ev_drone_sacrifice() -> void:
	var b := _bee_pos()
	_bee()
	var u := _loop(0.45)
	var d := b + Vector2(18, 0)
	var bx := lerpf(_x1(), d.x, minf(1.0, u * 1.6))
	if u < 0.62:
		_drone(d)
		_sprite("ebullet_orb", Vector2(bx, b.y))
	else:
		_spark(d, SWARM, 5.0)
		_text(d + Vector2(-4, -10), "!", SWARM)
	_text(Vector2(_x1() - 30, H - 6), "8s", UiTheme.DIM)

func _s_ev_swarm_call() -> void:
	var b := _bee_pos()
	_bee()
	var u := _loop(0.28)
	var kills := mini(5, int(u * 8.0))
	for i in range(5):
		var p := Vector2(_x0() + 18 + i * 16, b.y + (8 if i % 2 == 0 else -8))
		if i >= kills:
			_foe(p)
		else:
			_spark(p, GOLD, 2.0)
	_text(Vector2(_x0() + 18, 10), "%d/5" % kills, GOLD)
	if kills >= 5:
		var k := (u * 8.0 - 5.0) / 3.0
		for i in range(5):
			_sprite("bee", Vector2(lerpf(b.x, _x1() + 10, k), 14 + i * 12), Color(SWARM, 0.9), 0.5)

# ------------------------------------------------------------------ Pollen
func _s_ev_pollen_trail() -> void:
	_bee_x = floorf(_w * 0.55)
	var b := _bee_pos()
	for i in range(4):
		var age := _loop(0.5, i * 0.25)
		_cloud(b - Vector2(18 + age * 70.0, 0), 5.0 + age * 4.0, 0.7 * (1.0 - age))
	var e := Vector2(b.x - 50, b.y + sin(_t * 2.0) * 6.0)
	_foe(e, fposmod(_t, 1.0) < 0.3)
	_bee()

func _s_ev_pollen_burst() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x0() + 50, b.y)
	var n := Vector2(_x0() + 70, b.y - 16)
	var u := _loop(0.55)
	if u < 0.35:
		_foe(e)
		_shot(Vector2(lerpf(_x0(), e.x, u / 0.35), b.y))
		_foe(n)
	else:
		var k := (u - 0.35) / 0.65
		_cloud(e, 6.0 + k * 14.0, 0.8 * (1.0 - k * 0.6))
		_foe(n, k > 0.3)

func _s_ev_pollen_shield() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_ring(b, 26.0, Color(POLLEN, 0.55))
	_bee()
	for i in range(3):
		var u := _loop(0.4, i / 3.0)
		var x := lerpf(_x1(), b.x + 10.0, u)
		var inside := x - b.x < 26.0
		var p := Vector2(x, b.y - 12 + i * 12)
		_sprite("ebullet_orb", p, Color(0.7, 0.9, 0.6) if inside else Color.WHITE)
		if inside:
			_dot(p + Vector2(6, 0), Color(POLLEN, 0.6), 1.0)
	_text(Vector2(_x1() - 36, H - 6), "LANGSAM", POLLEN)

func _s_ev_pollen_blind() -> void:
	var b := _bee_pos()
	_bee()
	var c := Vector2(_w * 0.55, b.y)
	_cloud(c, 12.0, 0.7)
	var u := _loop(0.5)
	var x := lerpf(_x1(), b.x, u)
	if x > c.x - 4 or posmod(int(floorf(_t * 0.5)), 3) != 0:
		_sprite("ebullet_needle", Vector2(x, b.y), Color.WHITE, 1.0, true)
	else:
		_spark(c, Color(POLLEN, 0.8), 3.0)
	_text(Vector2(_x1() - 26, H - 6), "15%", POLLEN)

func _s_ev_wind_rider() -> void:
	var b := _bee_pos()
	for i in range(5):
		var y := 10.0 + i * 14.0
		var x := fposmod(_w - _t * 140.0 - i * 37.0, _w + 20.0) - 10.0
		draw_line(Vector2(x, y), Vector2(x + 14, y), Color(1, 1, 1, 0.35), 1.0)
	_cloud(b - Vector2(16, 0), 5.0, 0.6)
	_bee()
	_text(Vector2(_x1() - 30, H - 6), "+12%", POLLEN)

# ------------------------------------------------------------------ Chitin
func _s_ev_chitin_thorns() -> void:
	_bee_x = floorf(_w * 0.4)
	var b := _bee_pos()
	# Gegner läuft auf die Biene zu, prallt an der Stachelhaut ab und fliegt zurück.
	var u := _loop(0.6)
	var touch := b.x + 16.0
	var ex := lerpf(_x1(), touch, u * 2.0) if u < 0.5 else lerpf(touch, _x1(), (u - 0.5) * 2.0)
	_bee()
	for i in range(6):
		var a := TAU * i / 6.0
		var p := b + Vector2.from_angle(a) * 11.0
		draw_line(p, p + Vector2.from_angle(a) * 4.0, CHITIN, 1.0)
	_foe(Vector2(ex, b.y), u > 0.45 and u < 0.7)
	if absf(u - 0.5) < 0.08:
		_spark(Vector2(touch, b.y), CHITIN, 4.0)

func _s_ev_chitin_light() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_bee()
	var big := 9.0
	var small := 9.0 * 0.85
	_ring(b, big, Color(UiTheme.DIM, 0.4))
	_ring(b, small, CHITIN)
	_sprite("ebullet_orb", Vector2(b.x + 4, b.y - 12 + sin(_t * 3.0) * 2.0))
	_text(Vector2(_x0() + 20, H * 0.5 - 4), "-15%", CHITIN)
	_text(Vector2(_x0() + 20, H * 0.5 + 10), "+8%", CHITIN)

func _s_ev_chitin_guard() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_bee(Color(1, 0.9, 0.75))
	_hex(b, 15.0, 0.0, Color(CHITIN, 0.8))
	var u := _loop(0.5)
	if u < 0.5:
		_sprite("ebullet_orb", Vector2(lerpf(_x1(), b.x + 16.0, u * 2.0), b.y))
	else:
		_spark(b + Vector2(14, 0), CHITIN, 3.0)
		_text(Vector2(b.x + 20, b.y - 8), "-25%", CHITIN)
	_text(Vector2(_x1() - 52, H - 6), "PRÄZISION", UiTheme.DIM)

# ------------------------------------------------------------------ Resonanz
func _salvo_counter(every: int, col: Color) -> int:
	var n := int(floorf(_t * 3.0)) % every
	for i in range(every):
		_dot(Vector2(_x0() + 4 + i * 5, H - 8), col if i <= n else Color(UiTheme.DIM, 0.5), 2.0)
	return n

func _s_ev_resonance_beat() -> void:
	var b := _bee_pos()
	_bee()
	var n := _salvo_counter(12, RESO)
	_stream(b.y, 3, 70.0)
	if n == 11:
		_sprite("bullet_plasma", Vector2(_x0() + fposmod(_t * 3.0, 1.0) * 80.0, b.y), RESO, 1.2)

func _s_ev_resonance_chain() -> void:
	var b := _bee_pos()
	_bee()
	var foes: Array[Vector2] = [Vector2(_x0() + 40, b.y), Vector2(_x0() + 70, 16), Vector2(_x1() - 14, H - 18)]
	for f in foes:
		_foe(f)
	var u := _loop(0.6)
	if u < 0.4:
		_sprite("bullet_plasma", Vector2(lerpf(_x0(), foes[0].x, u / 0.4), b.y), RESO)
		return
	var jumps := mini(2, int((u - 0.4) / 0.6 * 3.0))
	for j in range(jumps):
		_bolt(foes[j], foes[j + 1])
	_spark(foes[0], RESO, 4.0)

func _s_ev_resonance_calm() -> void:
	var b := _bee_pos()
	_bee()
	_stream(b.y, 6, 75.0)
	var v := _loop(0.25)
	_bar(Vector2(_x0() + 10, H - 10), 60.0, v, RESO)
	_text(Vector2(_x0() + 74, H - 6), "+%d%%" % int(v * 20.0), RESO)

func _s_ev_resonance_pulse() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	_bee()
	var u := _loop(0.25)
	if u < 0.6:
		_stream(b.y, 4, 75.0)
		_bar(Vector2(_x0() + 10, H - 10), 50.0, u / 0.6, RESO)
	else:
		var k := (u - 0.6) / 0.4
		_ring(b, 10.0 + k * 40.0, Color(RESO, 1.0 - k), 2.0)

func _s_ev_resonance_tuning() -> void:
	var b := _bee_pos()
	_bee()
	var phase := fposmod(_t, 3.0)
	var icon := "icon_fan" if phase < 1.5 else "icon_lightning"
	_sprite(icon, Vector2(_x0() + 10, 12))
	var boosted := fposmod(_t, 1.5) < 0.9
	_stream(b.y, 4, 75.0, 0.0, Color(1.0, 0.8, 1.0) if boosted else Color.WHITE, 1.15 if boosted else 1.0)
	if boosted:
		_text(Vector2(_x0() + 24, 15), "+25%", RESO)

func _s_ev_resonance_final() -> void:
	var b := _bee_pos()
	_bee()
	var x := _x0() + _loop(0.6) * (_x1() - _x0())
	_sprite("bullet_plasma", Vector2(x, b.y), RESO, 1.7)
	_text(Vector2(_x1() - 24, 12), "x2", RESO)
	_foe(Vector2(_x1() - 14, b.y), x > _x1() - 22)

# ------------------------------------------------------------------ Nektar
func _s_ev_nectar_overflow() -> void:
	var b := _bee_pos()
	_bee()
	_bar(Vector2(_x0() + 4, 8), 40.0, 1.0, GOLD)
	_text(Vector2(_x0() + 48, 12), "MAX", GOLD)
	var u := _loop(0.5)
	var p := Vector2(lerpf(_x1(), b.x + 6, u), b.y + 10)
	_sprite("nectar", p)
	if u > 0.85:
		_text(b + Vector2(12, -8), "+50", GOLD)
		_hex(b, 15.0, 0.0, Color(ARC, 0.9))

func _s_ev_nectar_convert() -> void:
	var c := H * 0.5
	var u := _loop(0.4)
	var count := mini(10, int(u * 13.0))
	for i in range(10):
		_dot(Vector2(16 + i * 6, c), GOLD if i < count else Color(UiTheme.DIM, 0.5), 3.0)
	_text(Vector2(80, c + 3), "→", UiTheme.DIM)
	_heart(Vector2(102, c), count >= 10, 0.2 if count >= 10 else 0.0)
	_text(Vector2(16, H - 6), "20s", UiTheme.DIM)

func _s_ev_nectar_scent() -> void:
	var e := Vector2(_w * 0.5, 22)
	var u := _loop(0.5)
	if u < 0.25:
		_foe(e)
		return
	_spark(e, GOLD, 3.0)
	var k := (u - 0.25) / 0.75
	_sprite("nectar", e + Vector2(-7.0 * k, k * k * 38.0))
	_sprite("nectar", e + Vector2(7.0 * k, k * k * 38.0), Color(1, 1, 0.7))
	_text(e + Vector2(12, -2), "+1", GOLD)

func _s_ev_nectar_bargain() -> void:
	var c := Vector2(_w * 0.35, H * 0.5)
	_sprite("icon_shield", c)
	_text(c + Vector2(14, -2), "30", UiTheme.DIM)
	draw_line(c + Vector2(13, -6), c + Vector2(26, -6), RED, 1.0)
	var pop := 0.2 * absf(sin(_t * 3.0))
	_text(c + Vector2(14, 12), "25", GOLD, int(8 + 4 * pop))
	_text(Vector2(_x1() - 28, H - 6), "-15%", ARC)

func _s_ev_nectar_font() -> void:
	var c := Vector2(_w * 0.65, 18)
	_sprite("beetle", c, Color(1.0, 0.7, 0.7))
	_text(Vector2(8, 12), "PHASE II", RED)
	for i in range(6):
		var u := _loop(0.5, i / 6.0)
		_sprite("nectar", Vector2(c.x - 30 + i * 12, 14 + u * 50.0), Color(1, 1, 1, 1.0 - u * 0.5))
	_text(Vector2(8, H - 6), "+15", GOLD)

# ------------------------------------------------------------------ Meister
func _s_m_splinter_lance() -> void:
	var b := _bee_pos()
	_bee()
	var foes := [Vector2(_x0() + 30, b.y), Vector2(_x0() + 60, b.y - 14), Vector2(_x0() + 60, b.y + 14),
		Vector2(_x0() + 92, b.y - 24), Vector2(_x0() + 92, b.y + 24)]
	for f in foes:
		_foe(f)
	var u := _loop(0.45)
	var gen := int(u * 3.0)
	var k := fposmod(u * 3.0, 1.0)
	if gen == 0:
		_shot(Vector2(lerpf(_x0(), foes[0].x, k), b.y))
	else:
		var from: Array = [foes[0]] if gen == 1 else [foes[1], foes[2]]
		for f in from:
			_spark(f, GOLD, 3.0)
			for dir in [-1.0, 1.0]:
				_shot((f as Vector2) + Vector2(k * 30.0, dir * k * (14.0 if gen == 1 else 10.0)), Color(1.0, 0.75, 0.5), 0.7)

func _s_m_death_mark() -> void:
	var b := _bee_pos()
	_bee()
	var e := Vector2(_x1() - 26, b.y)
	var u := _loop(0.4)
	var marked := u > 0.3
	_foe(e, marked)
	if marked:
		_ring(e, 9.0 + sin(_t * 8.0), RED)
		draw_line(e + Vector2(-13, 0), e + Vector2(-6, 0), RED, 1.0)
		draw_line(e + Vector2(6, 0), e + Vector2(13, 0), RED, 1.0)
		_text(e + Vector2(-8, -14), "x2", RED)
	_stream(b.y, 3, 70.0)
	if u < 0.3 and u > 0.2:
		_spark(e, GOLD, 6.0)

func _s_m_royal_court() -> void:
	_bee_x = floorf(_w * 0.3)
	var b := _bee_pos()
	_bee()
	for i in range(6):
		var p := b + Vector2.from_angle(_t * 1.8 + TAU * i / 6.0) * 20.0
		_sprite("bee", p, Color(1, 0.95, 0.75), 0.55)
		_shot(p + Vector2(8 + _loop(1.1, i / 6.0) * 70.0, 0), Color(1, 1, 1, 0.8), 0.7)

func _s_m_shield_wall() -> void:
	var b := _bee_pos()
	_bee()
	var u := _loop(0.4)
	for i in range(4):
		var p := Vector2(b.x + 24, b.y - 18 + i * 12)
		var rebuilding := i == 1 and u > 0.5
		_drone(p, Color(1, 1, 1, 0.3) if rebuilding else Color.WHITE)
	for i in range(3):
		var v := _loop(0.6, i / 3.0)
		var x := lerpf(_x1(), b.x + 30, v)
		if v < 0.97:
			_sprite("ebullet_orb", Vector2(x, b.y - 12 + i * 12))
		else:
			_spark(Vector2(b.x + 30, b.y - 12 + i * 12), SWARM, 3.0)

func _s_m_chain_bloom() -> void:
	var b := _bee_pos()
	_bee()
	var spots := [Vector2(_x0() + 30, b.y), Vector2(_x0() + 55, b.y - 16), Vector2(_x0() + 80, b.y + 12), Vector2(_x0() + 105, b.y - 8)]
	var u := _loop(0.35)
	for i in range(spots.size()):
		var start := 0.15 + i * 0.18
		var k := clampf((u - start) / 0.25, 0.0, 1.0)
		if u < start:
			_cloud(spots[i], 7.0, 0.6)
		elif k < 1.0:
			_ring(spots[i], 4.0 + k * 12.0, Color(GOLD, 1.0 - k), 2.0)
			_spark(spots[i], GOLD, 4.0)

func _s_m_pollen_storm() -> void:
	_bee_x = floorf(_w * 0.35)
	var b := _bee_pos()
	for i in range(14):
		var a := _t * 3.0 + TAU * i / 14.0
		_dot(b + Vector2.from_angle(a) * (20.0 + 3.0 * sin(a * 3.0)), Color(POLLEN, 0.8), 3.0)
	_bee()
	var u := _loop(0.5)
	var x := lerpf(_x1(), b.x + 20, u)
	if x > b.x + 24:
		_sprite("ebullet_orb", Vector2(x, b.y + 6))
	else:
		_spark(Vector2(b.x + 22, b.y + 6), POLLEN, 3.0)

func _s_m_second_skin() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	var u := _loop(0.35)
	if u < 0.3:
		_bee()
		_sprite("ebullet_orb", Vector2(lerpf(_x1(), b.x + 8, u / 0.3), b.y))
		_heart(Vector2(_x0() + 30, 12), true)
	else:
		var k := (u - 0.3) / 0.7
		_sprite("bee", b + Vector2(-k * 14.0, k * 8.0), Color(CHITIN, 0.5 * (1.0 - k)))
		_bee()
		_hex(b, 15.0, _t, Color(ARC, 0.9), minf(6.0, k * 9.0))
		_heart(Vector2(_x0() + 30, 12), true, 0.2 * sin(_t * 8.0))
		_text(Vector2(_x0() + 40, 15), "1", HOT)

func _s_m_thorn_armor() -> void:
	_bee_x = floorf(_w * 0.4)
	var b := _bee_pos()
	_bee()
	var u := _loop(0.5)
	if u < 0.3:
		_sprite("ebullet_orb", Vector2(lerpf(_x1(), b.x + 8, u / 0.3), b.y))
		return
	var k := (u - 0.3) / 0.7
	for i in range(12):
		var a := TAU * i / 12.0
		var p := b + Vector2.from_angle(a) * (8.0 + k * 34.0)
		draw_line(p, p + Vector2.from_angle(a) * 4.0, INK, 3.0)
		draw_line(p, p + Vector2.from_angle(a) * 4.0, CHITIN, 1.0)

func _s_m_thunder_choir() -> void:
	var b := _bee_pos()
	_bee()
	var foes: Array[Vector2] = [Vector2(_x0() + 34, b.y), Vector2(_x0() + 56, 12), Vector2(_x0() + 76, H - 14),
		Vector2(_x0() + 98, 20), Vector2(_x1() - 10, H - 22), Vector2(_x1() - 8, 10)]
	for f in foes:
		_foe(f)
	var u := _loop(0.5)
	if u < 0.3:
		_sprite("bullet_plasma", Vector2(lerpf(_x0(), foes[0].x, u / 0.3), b.y), RESO)
		return
	var jumps := mini(5, int((u - 0.3) / 0.7 * 7.0))
	for j in range(jumps):
		_bolt(foes[j], foes[j + 1])

func _s_m_echo_shield() -> void:
	_bee_x = floorf(_w * 0.32)
	var b := _bee_pos()
	var u := _loop(0.3)
	_bee()
	if u < 0.4:
		_stream(b.y, 4, 75.0)
		_bar(Vector2(_x0() + 10, H - 10), 50.0, u / 0.4, RESO)
		return
	_ring(b, 22.0, Color(RESO, 0.85), 2.0)
	var k := (u - 0.4) / 0.6
	var x := b.x + 22.0 + absf(1.0 - k * 2.0) * (_x1() - b.x - 22.0)
	_sprite("ebullet_orb", Vector2(x, b.y - 6), Color(1, 0.8, 1) if k > 0.5 else Color.WHITE)

func _s_m_gold_rush() -> void:
	var b := _bee_pos()
	_bee()
	var u := _loop(0.35)
	var kills := mini(6, int(u * 9.0))
	for i in range(6):
		var p := Vector2(_x0() + 14 + i * 14, 14 + (i % 2) * 10)
		if i >= kills:
			_foe(p)
	if kills >= 6:
		var k := (u * 9.0 - 6.0) / 3.0
		var from := Vector2(_x0() + 84, 24)
		_sprite("nectar", from.lerp(b, k), Color(1.0, 0.85, 0.3), 1.3)
		_text(from + Vector2(-4, -6), "+5", GOLD)
	_text(Vector2(_x0() + 14, H - 6), "%d/6" % kills, GOLD)

func _s_m_life_nectar() -> void:
	var c := H * 0.5
	var v := _loop(0.25)
	_sprite("nectar", Vector2(14, c))
	_bar(Vector2(26, c - 2), 70.0, v, GOLD)
	_text(Vector2(26, c - 6), "%d/30" % int(v * 30.0), GOLD)
	_heart(Vector2(110, c), v > 0.95, 0.25 if v > 0.95 else 0.0)
