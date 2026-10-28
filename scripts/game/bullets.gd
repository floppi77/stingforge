class_name BulletField
extends Node2D
## Zentrale, performante Projektilverwaltung für Spieler- und Gegnerfeuer.
## Zeichnet alle Geschosse in einem Node (Draw-Call-arm) und liefert
## Segment-Kollisionen, damit auch sehr schnelle Schüsse zuverlässig treffen.

## Reichweite der Zielsuche (Weltpunkte): weiter entfernte Ziele werden ignoriert.
const HOMING_RANGE := 240.0
const MAX_PLAYER := 320
const MAX_ENEMY := 420

var player_bullets: Array = []
var enemy_bullets: Array = []
var contrast_mode := true
var _t := 0.0

func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func clear() -> void:
	player_bullets.clear()
	enemy_bullets.clear()

func spawn_player(pos: Vector2, vel: Vector2, dmg: float, art: String, opts: Dictionary = {}) -> Dictionary:
	if player_bullets.size() >= MAX_PLAYER:
		return {}
	var b := {
		"p": pos, "prev_p": pos, "v": vel, "dmg": dmg, "art": art,
		"r": float(opts.get("r", 5.0)),
		"life": float(opts.get("life", 1.6)),
		"pierce": int(opts.get("pierce", 0)),
		"homing": float(opts.get("homing", 0.0)),
		"rot": bool(opts.get("rot", false)),
		"splash": float(opts.get("splash", 0.0)),
		"chain": int(opts.get("chain", 0)),
		"lchain": int(opts.get("lchain", 0)),
		"proc_depth": int(opts.get("proc_depth", 0)),
		"scale": float(opts.get("scale", 1.0)),
		"tint": opts.get("tint", Color.WHITE),
		# Werkstatt-Formen: Kreisflug und Wellenbahn
		"orbit_r": float(opts.get("orbit_r", 0.0)),
		"orbit_w": float(opts.get("orbit_w", 2.4)),
		"orbit_a": float(opts.get("orbit_a", vel.angle())),
		"orbit_center": opts.get("orbit_center", null),
		"orbit_offset": Vector2.ZERO,
		"age": 0.0,
		# Trägerbahn und echte Tangente getrennt: Welle darf sich nicht selbst verstärken.
		"path_p": pos, "travel_v": vel, "travelled": 0.0,
		"wave_amp": float(opts.get("wave_amp", 0.0)),
		"wave_len": float(opts.get("wave_len", 80.0)),
		"wave_sp": float(opts.get("wave_sp", 1.0)),
		"wave_t": 0.0,
		"wave_x0": pos.x,
		"wave_y0": pos.y,
		"hit": {},
		"kind": "player",
	}
	player_bullets.append(b)
	return b

func spawn_enemy(pos: Vector2, vel: Vector2, dmg: int, art: String, opts: Dictionary = {}) -> Dictionary:
	if enemy_bullets.size() >= MAX_ENEMY:
		# ältestes Geschoss verwerfen statt unbegrenzt wachsen
		enemy_bullets.pop_front()
	var b := {
		"p": pos, "prev_p": pos, "v": vel, "dmg": dmg, "art": art,
		"r": float(opts.get("r", 5.0)),
		"life": float(opts.get("life", 5.0)),
		"rot": bool(opts.get("rot", false)),
		"slow": 1.0,
		"aimed": bool(opts.get("aimed", true)),
		"scale": float(opts.get("scale", 1.0)),
		"tint": opts.get("tint", Color.WHITE),
		"t": 0.0,
		"kind": "enemy",
	}
	enemy_bullets.append(b)
	return b

func update(delta: float, player_pos: Vector2, targets: Array = []) -> void:
	_t += delta
	var pb_keep: Array = []
	for b in player_bullets:
		var life: float = float(b["life"]) - delta
		b["life"] = life
		if life <= 0.0:
			continue
		var bp: Vector2 = b["p"]
		b["prev_p"] = bp
		var bv: Vector2 = b["travel_v"]
		var age: float = float(b["age"])
		var o_r: float = float(b.get("orbit_r", 0.0))
		if age <= 0.0 and o_r > 0.0:
			var center: Vector2 = player_pos if b["orbit_center"] == null else b["orbit_center"]
			b["orbit_offset"] = bp - center
			# Direkte BulletField-Nutzer behalten ebenfalls den Abschussoffset.
			if b["orbit_center"] == null:
				var transverse := (bp - center).rotated(-bv.angle()).y
				b["orbit_a"] = float(b["orbit_a"]) + clampf(transverse * 0.028, -0.5, 0.5)
		b["age"] = age + delta
		var homing: float = float(b["homing"])
		var best := Vector2.ZERO
		var bestd := INF
		if homing > 0.0:
			for t in targets:
				var tp: Vector2 = t
				if o_r <= 0.0 and (tp - bp).dot(bv.normalized()) < -30.0:
					continue
				var d: float = tp.distance_squared_to(bp)
				# Zielsuche greift nur im Nahbereich; ferne Ziele lenken nicht.
				if d > HOMING_RANGE * HOMING_RANGE:
					continue
				if d < bestd:
					bestd = d
					best = tp
		var next_pos: Vector2
		var distance_step := bv.length() * delta
		if o_r > 0.0:
			# Richtung, Salvenphase und Mündung bleiben unterscheidbar. Der kurze
			# Übergang verhindert Teleport-Segmente durch die gesamte Kreisfläche.
			var w: float = float(b["orbit_w"])
			var a: float = float(b["orbit_a"]) + w * delta
			if bestd < INF and bestd > 4.0:
				a = lerp_angle(a, (best - player_pos).angle(), clampf(homing * delta * 0.22, 0.0, 0.25))
			b["orbit_a"] = a
			distance_step = absf(w) * o_r * delta
			b["travelled"] = float(b["travelled"]) + distance_step
			var phase := _wave_phase(b)
			var radius := maxf(12.0, o_r + absf(float(b["wave_amp"])) * sin(phase))
			var enter := smoothstep(0.0, 0.16, float(b["age"]))
			next_pos = player_pos + (b["orbit_offset"] as Vector2).lerp(Vector2.from_angle(a) * radius, enter)
		else:
			if bestd < INF and bestd > 4.0:
				var want: Vector2 = (best - bp).normalized()
				bv = bv.normalized().lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized() * bv.length()
			b["travel_v"] = bv
			b["path_p"] = (b["path_p"] as Vector2) + bv * delta
			b["travelled"] = float(b["travelled"]) + distance_step
			var phase := _wave_phase(b)
			var normal := Vector2(-bv.y, bv.x).normalized()
			next_pos = (b["path_p"] as Vector2) + normal * float(b["wave_amp"]) * sin(phase)
		b["v"] = (next_pos - bp) / maxf(0.0001, delta)
		b["p"] = next_pos
		# Leuchtspur für Wellenkugeln: macht die Bahn als Welle sichtbar.
		if float(b["wave_amp"]) != 0.0:
			var trail: Array = b.get("trail", [])
			trail.push_front(next_pos)
			if trail.size() > 9:
				trail.resize(9)
			b["trail"] = trail
		if _offscreen(next_pos, 80.0):
			continue
		pb_keep.append(b)
	player_bullets = pb_keep

	var eb_keep: Array = []
	for b in enemy_bullets:
		var life: float = float(b["life"]) - delta
		b["life"] = life
		b["t"] = float(b["t"]) + delta
		if life <= 0.0:
			continue
		b["prev_p"] = b["p"]
		var bp: Vector2 = b["p"] + (b["v"] as Vector2) * float(b["slow"]) * delta
		b["p"] = bp
		if _offscreen(bp, 120.0):
			continue
		eb_keep.append(b)
	enemy_bullets = eb_keep
	queue_redraw()

func _wave_phase(b: Dictionary) -> float:
	var length := maxf(24.0, float(b["wave_len"]))
	var frequency := maxf(0.2, float(b["wave_sp"]))
	var phase := TAU * float(b["travelled"]) / length * frequency
	b["wave_t"] = phase
	return phase

func _offscreen(p: Vector2, margin: float) -> bool:
	return p.x < -margin - 40 or p.x > 960 + margin or p.y < -margin or p.y > App.PLAY_BOTTOM + 24.0

func _draw() -> void:
	for b in player_bullets:
		_draw_one(b, true)
	for b in enemy_bullets:
		_draw_one(b, false)

func _draw_one(b: Dictionary, friendly: bool) -> void:
	var trail: Array = b.get("trail", [])
	if friendly and trail.size() > 1:
		var tint: Color = b.get("tint", Color.WHITE)
		var base := Color(0.75, 1.0, 0.92).lerp(tint, 0.3)
		for i in range(trail.size() - 1):
			var f := 1.0 - float(i) / float(trail.size())
			draw_line(trail[i], trail[i + 1], Color(base, 0.55 * f), 3.0 * f + 0.5, false)
	var tex := Art.frame_tex(String(b.art), 0)
	var inf := Art.info(String(b.art))
	var fw: float = float(inf.get("w", 12))
	var fh: float = float(inf.get("h", 12))
	# Geschosse werden nicht animiert: ein rotierender Streifen wirkte wie Blinken.
	var src := Rect2(Vector2.ZERO, Vector2(fw, fh))
	var s: float = float(b.get("scale", 1.0))
	var tilt := 0.0
	if b.get("rot", false):
		tilt = (b.v as Vector2).angle()
	draw_set_transform(b.p, tilt, Vector2(s, s))
	var rect := Rect2(-fw * 0.5, -fh * 0.5, fw, fh)
	if not friendly:
		# Opaker, zeitlich stabiler Silhouettenrand statt Hintergrund-abhängigem
		# Leuchthof. Treffergröße r bleibt vollkommen unverändert.
		var edge := 1.5 if contrast_mode else 1.0
		var dark := Color("#11101f")
		for offset in [Vector2(-edge, 0), Vector2(edge, 0), Vector2(0, -edge), Vector2(0, edge),
				Vector2(-edge, -edge), Vector2(edge, -edge), Vector2(-edge, edge), Vector2(edge, edge)]:
			draw_texture_rect_region(tex, Rect2(rect.position + offset, rect.size), src, dark)
	draw_texture_rect_region(tex, rect, src, b.get("tint", Color.WHITE) as Color)
	if not friendly:
		# Heller Kern bleibt auch bei reduzierten Effekten bestehen; weder Zeit
		# noch Zufall verändern die Helligkeit (kein Blinken).
		draw_circle(Vector2.ZERO, 1.7 if contrast_mode else 1.0, Color("#fff8e7"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- Abfragen
func clear_enemy_area(center: Vector2, radius: float) -> int:
	var keep: Array = []
	var removed := 0
	for b in enemy_bullets:
		if (b.p as Vector2).distance_to(center) <= radius:
			removed += 1
		else:
			keep.append(b)
	enemy_bullets = keep
	return removed

func slow_area(center: Vector2, radius: float, factor: float) -> void:
	for b in enemy_bullets:
		if (b.p as Vector2).distance_to(center) <= radius:
			b.slow = minf(float(b.slow), factor)

func dissolve_aimed(center: Vector2, radius: float, chance: float, rng: RandomNumberGenerator) -> void:
	var keep: Array = []
	for b in enemy_bullets:
		if b.aimed and (b.p as Vector2).distance_to(center) <= radius and rng.randf() < chance:
			continue
		keep.append(b)
	enemy_bullets = keep

func enemy_count() -> int:
	return enemy_bullets.size()
