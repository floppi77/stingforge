class_name Fx
extends Node2D
## Effekt- und Partikelrendering in einem Node: Explosionen, Funken, Ringe,
## Pollenwolken, Gefahrenzonen und aufsteigende Texte.

const UiT := preload("res://scripts/core/ui_theme.gd")

var effects: Array = []
var hazards: Array = []
var arcs: Array = []
var texts: Array = []
var _t := 0.0
var density := 1.0
var impacts: Array = []
## Glasscherben: drehende Dreiecke mit Schwerkraft (zersplitternde Scheiben).
var shards: Array = []
## Wassertropfen (Spritzer von Fischen, Fontänen): Pixelquadrate mit Schwerkraft.
var drops: Array = []
var _impact_serial := 0
## Wasserpalette für Fontänen und Spritzer (Pixellook, wenige feste Töne).
const W_DEEP := Color("#245f9e")
const W_MID := Color("#3f8fd8")
const W_LIGHT := Color("#8fd2fb")
const W_FOAM := Color("#dcf4ff")
const MAX_EFFECTS := 192
const MAX_IMPACTS := 96

func _ready() -> void:
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	apply_settings()

## Effektdichte aus den Einstellungen (auch nach Änderung im Pausemenü).
func apply_settings() -> void:
	density = float(Save.g("graphics.effects", 1.0))
	if bool(Save.g("access.reduce_effects", false)):
		density *= 0.5

func reset() -> void:
	effects.clear()
	hazards.clear()
	texts.clear()
	arcs.clear()
	impacts.clear()
	shards.clear()

func add(art: String, pos: Vector2, opts: Dictionary = {}) -> void:
	if density < 0.3 and not bool(opts.get("important", false)):
		return
	if effects.size() >= MAX_EFFECTS:
		if not bool(opts.get("important", false)):
			return
		effects.pop_front()
	effects.append({
		"art": art, "p": pos, "t": 0.0,
		"life": float(opts.get("life", 0.5)),
		"scale": float(opts.get("scale", 1.0)),
		"tint": opts.get("tint", Color.WHITE),
		"rot": float(opts.get("rot", 0.0)),
		"grow": float(opts.get("grow", 0.0)),
	})

## Wasserspritzer an der Oberfläche: Tropfen fliegen fächerförmig hoch und fallen zurück.
func water_splash(pos: Vector2, scale: float = 1.0) -> void:
	var n := int(round(14.0 * scale * clampf(density, 0.3, 1.0)))
	for i in range(n):
		if drops.size() >= 160:
			drops.pop_front()
		var ang := -PI * 0.5 + randf_range(-0.75, 0.75)
		drops.append({"p": pos + Vector2(randf_range(-6.0, 6.0), 0), "v": Vector2.from_angle(ang) * randf_range(90.0, 210.0) * scale,
			"t": 0.0, "life": randf_range(0.45, 0.8), "size": 1 + int(i % 3 == 0)})
	add("ring", pos, {"life": 0.35, "scale": 0.7 * scale, "grow": 1.2, "tint": Color(0.75, 0.93, 1.0, 0.8)})

func explode(pos: Vector2, scale: float = 1.0, tint: Color = Color.WHITE) -> void:
	add("explode", pos, {"life": 0.5, "scale": scale * 1.2, "tint": tint, "important": true})
	add("spark", pos, {"life": 0.28, "scale": scale, "tint": tint})
	if density > 0.6:
		for i in range(3):
			add("spark", pos + Vector2(randf_range(-14, 14), randf_range(-14, 14)),
				{"life": 0.3, "scale": scale * 0.7, "tint": tint.lerp(Color(1, 0.8, 0.3), 0.4)})

func hit_spark(pos: Vector2, tint: Color = Color(1, 0.9, 0.5)) -> void:
	add("spark", pos, {"life": 0.10, "scale": 0.42, "tint": tint})
	impact(pos, tint)

## Kleine Materialsplitter und Staub, keine dunkle Trefferlochscheibe und keine
## rekursiven Explosionen. Eigene deterministische Streuung berührt kein Kampf-RNG.
func impact(pos: Vector2, tint: Color = Color(1, 0.9, 0.5)) -> void:
	var intensity := clampf(float(Save.g("graphics.particles", 1.0)), 0.0, 1.0) * clampf(density, 0.0, 1.0)
	if intensity <= 0.0 or impacts.size() >= MAX_IMPACTS:
		return
	var count := mini(ceili(6.0 * intensity), MAX_IMPACTS - impacts.size())
	_impact_serial = (_impact_serial + 1) % 360
	for i in range(count):
		var angle := deg_to_rad(float((_impact_serial * 97 + i * 137) % 360))
		var velocity := Vector2.RIGHT.rotated(angle) * (24.0 + float(i % 4) * 9.0)
		impacts.append({"p": pos, "v": velocity, "t": 0.0, "life": 0.12 + float(i) * 0.018,
			"size": 1.2 + float(i % 3) * 0.65, "dust": i % 3 == 0, "tint": tint})

## Glasscheibe zerspringt: Scherben fliegen vom Treffpunkt weg und fallen.
func shatter(rect: Rect2, from: Vector2) -> void:
	var count := int(46 * clampf(density, 0.3, 1.0))
	for i in range(count):
		var p := rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
		var away := (p - from).normalized() if p.distance_to(from) > 1.0 else Vector2.RIGHT
		shards.append({"p": p, "v": away * randf_range(60.0, 240.0) + Vector2(randf_range(-40, 40), -randf_range(20, 120)),
			"t": 0.0, "life": randf_range(0.7, 1.3), "size": randf_range(2.5, 7.0),
			"rot": randf() * TAU, "spin": randf_range(-12.0, 12.0)})
	add("spark", rect.get_center(), {"life": 0.3, "scale": 3.0, "tint": Color(0.7, 0.95, 1.0), "important": true})

func add_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 14) -> void:
	texts.append({"p": pos, "text": text, "color": color, "t": 0.0, "life": 0.9, "size": size})

## Sichtbarer Blitzbogen zwischen zwei Punkten (Kettenblitz).
func add_arc(from: Vector2, to: Vector2, tint: Color = Color(0.72, 0.95, 1.0), life: float = 0.17) -> void:
	arcs.append({"a": from, "b": to, "tint": tint, "t": 0.0, "life": life,
		"seed": randi() % 100000})

func _draw_arc(ar: Dictionary) -> void:
	var a: Vector2 = ar.a
	var b: Vector2 = ar.b
	var frac := clampf(float(ar.t) / maxf(0.001, float(ar.life)), 0.0, 1.0)
	var tint: Color = ar.tint
	tint.a *= 1.0 - frac
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ar.get("seed", 1))
	var dir := b - a
	var nrm := dir.normalized().orthogonal()
	var pts := PackedVector2Array()
	var steps := 6
	for i in range(steps + 1):
		var f := float(i) / float(steps)
		var off := 0.0
		if i > 0 and i < steps:
			off = rng.randf_range(-8.0, 8.0)
		pts.append(a + dir * f + nrm * off)
	draw_polyline(pts, tint, 2.6, true)
	var inner := Color(1, 1, 1, tint.a * 0.85)
	draw_polyline(pts, inner, 1.1, true)

func add_hazard(h: Dictionary) -> void:
	hazards.append(h)

## Gemeinsame Uhr für Warnzeichnung und Spielkollision: vier On/Off-Paare in1s.
## Kein Blinkzustand darf selbst entscheiden, ob bereits Kollision besteht.
static func is_warning(h: Dictionary) -> bool:
	var warning := float(h.get("warn", 1.0 if String(h.get("kind", "")) == "reflect_panel" else 0.0))
	return warning > 0.0 and float(h.get("t", 0.0)) < warning

static func warning_pulse_on(h: Dictionary) -> bool:
	if not is_warning(h):
		return false
	var warning := maxf(0.001, float(h.get("warn", 1.0)))
	return int(floor(float(h.get("t", 0.0)) * 8.0 / warning)) % 2 == 0

static func panel_rect(h: Dictionary) -> Rect2:
	var size := Vector2(float(h.get("w", 70.0)), float(h.get("h", 160.0)))
	return Rect2((h.p as Vector2) - size * 0.5, size)

func update(delta: float) -> void:
	_t += delta
	var keep: Array = []
	for e in effects:
		e.t += delta
		if e.t < e.life:
			keep.append(e)
	effects = keep
	var keep_impact: Array = []
	for particle in impacts:
		particle.t = float(particle.t) + delta
		if float(particle.t) >= float(particle.life):
			continue
		particle.p += (particle.v as Vector2) * delta
		particle.v = (particle.v as Vector2) * maxf(0.0, 1.0 - 4.0 * delta) + Vector2(0, 28.0 * delta)
		keep_impact.append(particle)
	impacts = keep_impact
	var keep_s: Array = []
	for sh in shards:
		sh.t = float(sh.t) + delta
		if float(sh.t) >= float(sh.life):
			continue
		sh.v = (sh.v as Vector2) + Vector2(0, 420.0 * delta)
		sh.p += (sh.v as Vector2) * delta
		sh.rot = float(sh.rot) + float(sh.spin) * delta
		keep_s.append(sh)
	shards = keep_s
	var keep_d: Array = []
	for dr in drops:
		dr.t = float(dr.t) + delta
		if float(dr.t) >= float(dr.life):
			continue
		dr.v = (dr.v as Vector2) + Vector2(0, 520.0 * delta)
		dr.p += (dr.v as Vector2) * delta
		keep_d.append(dr)
	drops = keep_d
	var keep_h: Array = []
	for h in hazards:
		h.t = float(h.get("t", 0.0)) + delta
		h.life = float(h.get("life", 3.0)) - delta
		if h.life > 0.0:
			keep_h.append(h)
	hazards = keep_h
	var keep_arc: Array = []
	for ar in arcs:
		ar.t = float(ar.t) + delta
		if float(ar.t) < float(ar.life):
			keep_arc.append(ar)
	arcs = keep_arc
	var keep_t: Array = []
	for tx in texts:
		tx.t += delta
		tx.p.y -= 26.0 * delta
		if tx.t < tx.life:
			keep_t.append(tx)
	texts = keep_t
	queue_redraw()

func _draw() -> void:
	for sh in shards:
		var fade := 1.0 - smoothstep(0.6, 1.0, float(sh.t) / float(sh.life))
		var size: float = float(sh.size)
		var pts := PackedVector2Array()
		for k in range(3):
			pts.append((sh.p as Vector2) + Vector2.from_angle(float(sh.rot) + TAU * k / 3.0 + (0.6 if k == 1 else 0.0)) * size)
		draw_colored_polygon(pts, Color(0.62, 0.9, 1.0, 0.55 * fade))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.9, 1.0, 1.0, 0.9 * fade), 1.0)
	for dr in drops:
		var dc: Color = W_FOAM if int(dr.size) == 1 else W_LIGHT
		dc.a = 1.0 - smoothstep(0.6, 1.0, float(dr.t) / float(dr.life))
		var dp := (dr.p as Vector2).floor()
		draw_rect(Rect2(dp, Vector2(float(dr.size), float(dr.size) + 1.0)), dc)
	for particle in impacts:
		var color: Color = particle.tint
		color.a *= 1.0 - float(particle.t) / float(particle.life)
		var p: Vector2 = particle.p
		var size: float = float(particle.size)
		if bool(particle.dust):
			draw_rect(Rect2(p - Vector2.ONE * 0.5, Vector2.ONE * size), color)
		else:
			draw_line(p, p - (particle.v as Vector2).normalized() * size, color, 1.0)
	for e in effects:
		var art := String(e.art)
		var tex := Art.frame_tex(art, 0)
		var inf := Art.info(art)
		var fw: float = float(inf.get("w", 16))
		var fh: float = float(inf.get("h", 16))
		var n := Art.frame_count(art)
		var frac: float = clampf(e.t / maxf(0.001, e.life), 0.0, 1.0)
		var fr := mini(n - 1, int(frac * float(n)))
		var src := Rect2(Vector2(fr * fw, 0), Vector2(fw, fh))
		var s: float = float(e.scale) * (1.0 + float(e.grow) * frac)
		var alpha := 1.0 - smoothstep(0.65, 1.0, frac)
		var tint: Color = e.tint
		tint.a *= alpha
		draw_set_transform(e.p, float(e.rot), Vector2(s, s))
		draw_texture_rect_region(tex, Rect2(-fw * 0.5, -fh * 0.5, fw, fh), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for h in hazards:
		_draw_hazard(h)
	for ar in arcs:
		_draw_arc(ar)
	for tx in texts:
		var font := UiT.font_bold()
		var sz: int = int(tx.size)
		draw_string(font, tx.p + Vector2(-20, 0), Loc.tx(String(tx.text)), HORIZONTAL_ALIGNMENT_CENTER, 40, sz, tx.color)

## Dieselbe Feldgeometrie für Renderer und Regressionen; alle Punkte liegen im
## sichtbaren Spielfeld, nicht unter HUD oder Fußleiste. Schwerkraft immer abwärts.
func field_geometry(h: Dictionary) -> Array:
	var lines: Array = []
	var dir := 1.0 if String(h.get("kind", "")) == "gravity_field" else signf(float(h.get("dir", 1.0)))
	var top := float(App.PLAY_TOP) + 8.0
	var bottom := float(App.PLAY_BOTTOM) - 8.0
	var span := maxf(1.0, bottom - top - 40.0)
	var drift := fmod(float(h.get("t", 0.0)) * 24.0, span / 3.0)
	for column in range(10):
		var x := 64.0 + 92.0 * float(column)
		var arrows: Array = []
		for row in range(3):
			var y := top + 20.0 + fmod(float(row) * span / 3.0 + drift, span)
			var tip := Vector2(x, y)
			arrows.append({"tip": tip, "left": tip + Vector2(-6.0, -dir * 8.0),
				"right": tip + Vector2(6.0, -dir * 8.0)})
		lines.append({"a": Vector2(x, top), "b": Vector2(x, bottom), "arrows": arrows})
	return lines

# ------------------------------------------------------- Feldeffekte (R4)
## Sanftes Ein- und Ausblenden eines Feldeffekts über seine Lebenszeit.
func _fade(life: float, max_life: float) -> float:
	var age := max_life - life
	return clampf(age / 0.45, 0.0, 1.0) * clampf(life / 0.6, 0.0, 1.0)

## Pseudozufall je Index, stabil zwischen Bildern (kein Flimmern).
func _h01(i: int, salt: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)

## Dornige Wurzel bricht aus dem Boden. Vorwarnung: aufbrechende Erde mit
## springenden Brocken. Sichtbare Höhe = Trefferhöhe (80 px).
func _draw_root(h: Dictionary, elapsed: float) -> void:
	var warn := float(h.get("warn", 0.9))
	var base: Vector2 = h.get("base", Vector2(float((h.p as Vector2).x), App.PLAY_BOTTOM))
	var rise := clampf(elapsed / warn, 0.0, 1.0)
	var height := float(h.get("height", 80.0)) * rise
	# Erdhügel und Risse, die mit der Vorwarnung wachsen.
	var mound := 6.0 + 8.0 * minf(1.0, elapsed / maxf(0.01, warn * 0.6))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-26, 2), base + Vector2(-16, -mound * 0.6),
		base + Vector2(0, -mound), base + Vector2(16, -mound * 0.6), base + Vector2(26, 2)]), Color(0.26, 0.17, 0.10))
	draw_line(base + Vector2(-10, -mound * 0.5), base + Vector2(-2, -mound * 0.9), Color(0.08, 0.05, 0.03), 1.5)
	draw_line(base + Vector2(4, -mound * 0.8), base + Vector2(12, -mound * 0.4), Color(0.08, 0.05, 0.03), 1.5)
	if rise < 1.0:
		var blink := 0.5 + 0.5 * sin(_t * 18.0)
		draw_rect(Rect2(base + Vector2(-22, -2), Vector2(44, 2)), Color(1.0, 0.6, 0.25, 0.55 * blink))
		for k in range(5):
			var bx := base.x - 18.0 + k * 9.0
			var by := base.y - mound - absf(sin(_t * 9.0 + k * 1.7)) * (4.0 + 6.0 * rise)
			draw_rect(Rect2(bx, by, 2.5, 2.5), Color(0.42, 0.28, 0.16))
	if height <= 0.5:
		return
	var tex := Art.sheet("root_spike")
	if tex != null:
		var w := float(tex.get_width())
		var hh := minf(height, float(tex.get_height()))
		var dst := Rect2(base.x - w * 0.5, base.y - hh, w, hh)
		var src := Rect2(0, 0, w, hh)
		# Warmer Lichtsaum (Silhouette, versetzt), damit die Wurzel sich vom
		# erdigen Hintergrund abhebt; danach die Wurzel selbst, leicht aufgehellt.
		var rim := Color(1.0, 0.72, 0.38, 0.85)
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
			draw_texture_rect_region(tex, Rect2(dst.position + off, dst.size), src, rim)
		draw_texture_rect_region(tex, dst, src, Color(1.3, 1.18, 1.05))
	# Staub, solange die Wurzel noch wächst.
	if rise < 1.0 or elapsed < warn + 0.25:
		for k in range(6):
			var a := -PI * 0.5 + (k - 2.5) * 0.45
			var d := 8.0 + fmod(_t * 60.0 + k * 7.0, 18.0)
			draw_rect(Rect2(base + Vector2.from_angle(a) * d, Vector2(3, 3)), Color(0.55, 0.42, 0.30, 0.6))

## Glasscheibe (Level 6). Vorwarnung: die Scheibe kristallisiert sichtbar aus
## (wachsende Füllung, Eckwinkel, Warnzeichen) und der Rahmen blinkt viermal.
## Aktiv: kräftiges Glas mit hellem Rand und wanderndem Glanz; Risse zeigen den
## Schaden, bis die Scheibe zerspringt.
func _draw_glass(h: Dictionary) -> void:
	var rect := panel_rect(h)
	var warn := float(h.get("warn", 1.0))
	var t := float(h.get("t", 0.0))
	var edge := Color(0.55, 0.95, 1.0)
	if is_warning(h):
		var k := clampf(t / warn, 0.0, 1.0)
		draw_rect(rect, Color(0.5, 0.85, 1.0, 0.06 + 0.16 * k))
		# Eiskristall wächst von der Mitte aus.
		var c := rect.get_center()
		for i in range(6):
			var a := TAU * i / 6.0 + 0.3
			draw_line(c, c + Vector2.from_angle(a) * Vector2(rect.size.x, rect.size.y) * 0.5 * k,
				Color(0.85, 1.0, 1.0, 0.5 * k), 1.0)
		var on := warning_pulse_on(h)
		var frame := Color(0.35, 0.9, 1.0, 0.95)
		if on:
			draw_rect(rect.grow(2.0), frame, false, 3.0)
		var arm := 14.0
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx := 1.0 if corner.x <= rect.get_center().x else -1.0
			var sy := 1.0 if corner.y <= rect.get_center().y else -1.0
			var o: Vector2 = corner + Vector2(-sx, -sy) * 6.0
			var bracket := Color(1.0, 0.85, 0.3, 0.95 if on else 0.4)
			draw_line(o, o + Vector2(sx * arm, 0), bracket, 3.0)
			draw_line(o, o + Vector2(0, sy * arm), bracket, 3.0)
		if on:
			# Warnzeichen über der Scheibe.
			var tip := Vector2(c.x, rect.position.y - 22.0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -10), tip + Vector2(10, 8), tip + Vector2(-10, 8)]),
				Color(1.0, 0.85, 0.3, 0.95))
			draw_rect(Rect2(tip + Vector2(-1, -4), Vector2(2, 7)), Color(0.15, 0.08, 0.02))
			draw_rect(Rect2(tip + Vector2(-1, 5), Vector2(2, 2)), Color(0.15, 0.08, 0.02))
		return
	var hp_frac := clampf(float(h.get("hp", 1.0)) / maxf(1.0, float(h.get("max_hp", 1.0))), 0.0, 1.0)
	var flash := clampf(float(h.get("hit_flash", 0.0)) * 4.0, 0.0, 1.0)
	# Satte Tönung und dunkle Außenkontur: auch vor dem hellen Gewächshaus klar erkennbar.
	draw_rect(rect, Color(0.12, 0.45, 0.68, 0.42 + 0.2 * flash))
	draw_rect(rect.grow(2.0), Color(0.03, 0.14, 0.22, 0.9), false, 2.0)
	draw_rect(rect, edge.lerp(Color.WHITE, flash), false, 2.0)
	draw_rect(rect.grow(-3.0), Color(0.85, 1.0, 1.0, 0.45), false, 1.0)
	# Wandernder Glanzstreifen
	var sweep := fposmod(_t * 0.6, 1.6) - 0.3
	var sx2 := rect.position.x + rect.size.x * sweep
	for k in range(3):
		var x0 := sx2 + k * 5.0
		if x0 > rect.position.x and x0 + 18.0 < rect.end.x:
			draw_line(Vector2(x0, rect.end.y - 4), Vector2(x0 + 18.0, rect.position.y + 4), Color(1, 1, 1, 0.28 - k * 0.07), 2.0)
	# Risse wachsen mit dem Schaden (ab einem Viertel Verlust).
	var cracks: Array = h.get("cracks", [])
	var depth := 1.0 - hp_frac
	for i in range(cracks.size()):
		var at: Vector2 = cracks[i]
		var rays := 3 + int(depth * 4.0)
		for r in range(rays):
			var a := TAU * _h01(i * 7 + r, 91)
			var ln := 8.0 + 34.0 * depth * (0.5 + _h01(i * 5 + r, 92))
			var mid := at + Vector2.from_angle(a) * ln * 0.5 + Vector2.from_angle(a + 1.2) * 3.0
			var end := (at + Vector2.from_angle(a) * ln).clamp(rect.position, rect.end)
			draw_polyline(PackedVector2Array([at, mid.clamp(rect.position, rect.end), end]), Color(0.95, 1.0, 1.0, 0.85), 1.0)
	# Schadensbalken unter der Scheibe
	if hp_frac < 1.0:
		var bar := Rect2(rect.position.x, rect.end.y + 5.0, rect.size.x, 3.0)
		draw_rect(bar, Color(0.05, 0.1, 0.15, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_frac, bar.size.y)), edge)

## Wasserfontäne als Brunnensäule. Geometrie (Höhe, Strahlbreite, Krone) kommt aus
## geyser_shape(): dieselbe Form zeichnet der Renderer und prüft die Kollision.
const GEYSER_HALF := 12.0
const GEYSER_CROWN := 22.0

static func geyser_shape(h: Dictionary) -> Dictionary:
	var warn := float(h.get("warn", 0.7))
	var t := float(h.get("t", 0.0))
	var life := float(h.get("life", 1.0))
	var full := float(h.get("height", 80.0))
	# Der Strahl schießt im letzten Drittel der Vorwarnung hoch und fällt am Ende in sich zusammen.
	var rise := smoothstep(warn * 0.6, warn, t)
	var fall := clampf(life / 0.45, 0.0, 1.0)
	var height := full * rise * fall
	var base: Vector2 = h.get("base", Vector2(float((h.p as Vector2).x), App.PLAY_BOTTOM))
	return {"base": base, "height": height, "top": base - Vector2(0, height), "half": GEYSER_HALF,
		"crown": GEYSER_CROWN * clampf(height / 60.0, 0.0, 1.0), "active": t >= warn * 0.72 and height > 16.0}

## Trefferprüfung passend zur Zeichnung: Strahl (Rechteck) plus Krone (Kreis) oben.
static func geyser_hits(h: Dictionary, p: Vector2, radius: float) -> bool:
	var g := geyser_shape(h)
	if not bool(g.active):
		return false
	var base: Vector2 = g.base
	var top: Vector2 = g.top
	if absf(p.x - base.x) <= float(g.half) + radius and p.y >= top.y and p.y <= base.y + radius:
		return true
	return p.distance_to(top) <= float(g.crown) + radius

## Fontäne im Pixellook: alles auf ganzen Spielpixeln, feste Wasserpalette,
## Animation im 12-fps-Takt. Form und Treffer kommen aus geyser_shape().
func _draw_geyser(h: Dictionary, _elapsed: float) -> void:
	var g := geyser_shape(h)
	var base: Vector2 = (g.base as Vector2).floor()
	var full := float(h.get("height", 80.0))
	var height := float(g.height)
	var half := int(g.half)
	var warn := float(h.get("warn", 0.7))
	var t := float(h.get("t", 0.0))
	var fr := int(_t * 12.0)
	var salt := int(base.x)
	# Vorwarnung: Blasen steigen im Becken auf, gestrichelte Vorschau der Säulenränder.
	if t < warn:
		for k in range(7):
			var ph := fposmod(_t * 2.6 + _h01(k, salt), 1.0)
			_wpx(base.x - 15.0 + k * 5.0, base.y - 2.0 - floorf(ph * 9.0), 2, 2, W_FOAM, 1.0 - ph * 0.7)
		var a := 0.22 + 0.14 * sin(_t * 16.0)
		var yy := base.y - full
		while yy < base.y - 4.0:
			_wpx(base.x - half, yy, 1, 3, W_LIGHT, a)
			_wpx(base.x + half - 1, yy, 1, 3, W_LIGHT, a)
			yy += 6.0
	# Schaumteppich am Fuß, breiter solange die Säule steht.
	var spread := half + (10 if height > 2.0 else 4)
	for i in range(-spread, spread, 2):
		var hn := 1 + int(_h01(i + fr * 7, salt) * 3.0)
		_wpx(base.x + i, base.y - hn, 2, hn, W_FOAM if absi(i) < spread - 4 else W_LIGHT, 0.95)
	if height <= 2.0:
		return
	var top := base.y - floorf(height)
	# Säule zeilenweise (2 px): mit Luft durchsetztes, fast weißes Wasser. Schübe laufen
	# als Wülste nach oben, Ränder flattern, bläuliche Schlieren ziehen mit.
	var row := 0
	var y := base.y - 2.0
	while y > top:
		var up := base.y - y
		var frac := up / maxf(1.0, height)
		var surge := sin(up * 0.09 - _t * 14.0)
		var w := float(half) - frac * 4.0 + surge * 2.0
		var jl := floorf(_h01(row * 3 + fr, salt) * 3.0) - 1.0
		var jr := floorf(_h01(row * 5 + fr + 17, salt) * 3.0) - 1.0
		var x0 := base.x - w + jl
		var x1 := base.x + w + jr
		_wpx(x0 - 2.0, y - 2.0, int(x1 - x0) + 4, 2, W_LIGHT, 0.45)
		_wpx(x0, y - 2.0, int(x1 - x0), 2, W_FOAM, 0.92)
		_wpx(x0, y - 2.0, 2, 2, W_LIGHT, 0.95)
		_wpx(x1 - 2.0, y - 2.0, 2, 2, W_MID, 0.95)
		for k in range(5):
			var sx := -7.0 + k * 3.5
			if _h01(row + fr * 3 + k * 31, salt) < 0.3:
				_wpx(base.x + sx, y - 2.0, 1, 2, W_MID if k % 2 == 0 else W_LIGHT, 0.9)
		if _h01(row * 7 + fr * 5, salt) < 0.18:
			_wpx(base.x - 2.0 + jl * 2.0, y - 2.0, 2, 2, Color.WHITE, 1.0)
		y -= 2.0
		row += 1
	# Seitliche Gischt: einzelne Tropfen steigen neben dem Strahl mit.
	for k in range(10):
		var ph := fposmod(_t * 1.8 + _h01(k, salt + 3), 1.0)
		var side := -1.0 if k % 2 == 0 else 1.0
		_wpx(base.x + side * (float(half) + 3.0 + _h01(k * 9, salt) * 5.0), base.y - ph * height, 1, 2, W_FOAM,
			0.8 * (1.0 - ph))
	var crown := float(g.crown)
	if crown < 4.0:
		return
	var cw := int(crown * 1.2)
	# Zurückfallendes Wasser: unterbrochene Vorhänge links und rechts, nach unten breiter.
	for side2 in [-1.0, 1.0]:
		var i := 0
		var yy2 := top + 8.0
		while yy2 < base.y - 3.0:
			if (i + fr) % 3 != 0:
				_wpx(base.x + float(side2) * (float(cw) - 3.0 + i * 0.18), yy2, 1, 2, W_LIGHT, 0.65)
			yy2 += 3.0
			i += 1
	# Krone: Gischtballen (verpixelte Scheiben), die sich langsamer umformen als der Strahl.
	var slow := int(_t * 6.0)
	for b in range(7):
		var bx := (_h01(b * 11 + slow, salt) - 0.5) * float(cw) * 1.5
		var by := -_h01(b * 17 + slow, salt) * crown * 0.9
		var r := 4.0 + _h01(b * 23 + slow, salt) * crown * 0.35
		var cy := -r
		while cy <= r:
			var span := floorf(sqrt(maxf(0.0, r * r - cy * cy)) * 0.5) * 2.0
			_wpx(base.x + bx - span, top + by + cy, int(span * 2.0) + 2, 2,
				W_LIGHT if cy > r * 0.5 else W_FOAM, 0.95)
			cy += 2.0
		_wpx(base.x + bx - 1.0, top + by - r, 2, 1, Color.WHITE, 1.0)
	# Tropfen auf Parabelbahnen vom Kronenrand nach außen.
	for k in range(22):
		var side3 := -1.0 if k % 2 == 0 else 1.0
		var ph2 := fposmod(_t * 1.25 + float(k) * 0.113, 1.0)
		var dx := side3 * (float(cw) * 0.5 + ph2 * (24.0 + float(k % 4) * 12.0))
		var dy := -16.0 * ph2 + 120.0 * ph2 * ph2
		var sz := 2 if k % 3 == 0 else 1
		_wpx(base.x + dx, top + dy, sz, sz + 1, W_LIGHT if sz == 2 else W_FOAM, 1.0 - ph2 * 0.6)
	# Sprühnebel: helle Einzelpixel über der Krone.
	for k in range(10):
		var mx := (_h01(k * 13 + fr, salt) - 0.5) * float(cw) * 3.0
		var my := -_h01(k * 29 + fr, salt) * crown * 1.4
		_wpx(base.x + mx, top + my, 1, 1, Color.WHITE, 0.55)

## Ein Wasserpixel-Block auf ganzen Spielpixeln.
func _wpx(x: float, y: float, w: int, hgt: int, col: Color, a: float) -> void:
	var c := col
	c.a = a
	draw_rect(Rect2(floorf(x), floorf(y), float(w), float(hgt)), c)

## Giftige Sporenwolke des Pilzwalds: wabernde Klumpen in Violett mit gelbgrünen
## Sporen, die nach außen treiben. Trefferkreis bleibt unverändert.
func _draw_spores(h: Dictionary, life: float, max_life: float) -> void:
	var pos: Vector2 = h.p
	var r := float(h.radius)
	var a := _fade(life, max_life)
	var seed_i := int(h.get("seed", int(pos.y)))
	for k in range(8):
		var ang := TAU * float(k) / 8.0 + _h01(k, seed_i) * 0.6
		var off := Vector2.from_angle(ang) * r * (0.38 + 0.12 * sin(_t * 1.3 + k))
		draw_circle(pos + off, r * (0.42 + 0.08 * _h01(k, seed_i + 1)), Color(0.22, 0.12, 0.28, 0.55 * a), true, -1.0, false)
	for k in range(8):
		var ang2 := TAU * float(k) / 8.0 + 0.4 + _h01(k, seed_i + 2) * 0.6
		var off2 := Vector2.from_angle(ang2) * r * (0.3 + 0.1 * sin(_t * 1.7 + k * 2.0))
		draw_circle(pos + off2, r * (0.3 + 0.06 * _h01(k, seed_i + 3)), Color(0.46, 0.26, 0.52, 0.55 * a), true, -1.0, false)
	draw_circle(pos, r * 0.32, Color(0.62, 0.40, 0.62, 0.5 * a), true, -1.0, false)
	# Sporen: kleine leuchtende Pixel, die aus dem Kern nach außen treiben.
	for k in range(16):
		var ang3 := TAU * _h01(k, seed_i + 4)
		var d := fposmod(_t * 14.0 + _h01(k, seed_i + 5) * r, r * 1.1)
		var p := pos + Vector2.from_angle(ang3 + _t * 0.3) * d
		var glow := 1.0 - d / (r * 1.1)
		draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(0.78, 0.95, 0.40, 0.85 * glow * a))
	# Warnsaum: gelbgrün gepunkteter Rand, damit die Gefahrenfläche lesbar bleibt.
	for k in range(20):
		var ang4 := TAU * float(k) / 20.0 + _t * 0.4
		draw_rect(Rect2((pos + Vector2.from_angle(ang4) * r * 0.82).round(), Vector2(2, 2)), Color(0.85, 1.0, 0.45, 0.45 * a))

## Wind: geschwungene Böen-Schlieren und mitgerissene Blätter in Windrichtung.
## Die Feldgeometrie (field_geometry) bleibt für Regressionen unverändert.
func _draw_wind(h: Dictionary, life: float, max_life: float) -> void:
	var dir := signf(float(h.get("dir", 1.0)))
	var a := _fade(life, max_life)
	var top := float(App.PLAY_TOP) + 4.0
	var bottom := float(App.PLAY_BOTTOM) - 4.0
	var span := bottom - top
	var age := max_life - life
	for k in range(14):
		var x0 := 40.0 + _h01(k, 11) * 880.0
		var len := 50.0 + _h01(k, 12) * 70.0
		var speed := 220.0 + _h01(k, 13) * 160.0
		var head := top + fposmod(_h01(k, 14) * span + age * speed, span + len)
		if dir < 0.0:
			head = bottom - (head - top)
		var pts := PackedVector2Array()
		for j in range(9):
			var f := float(j) / 8.0
			var y := head - dir * len * f
			var x := x0 + sin(y * 0.03 + k + _t * 1.5) * 10.0 - age * 30.0 * 0.2
			pts.append(Vector2(fposmod(x, 960.0), clampf(y, top, bottom)))
		for j in range(8):
			var w := 2.5 * (1.0 - float(j) / 8.0) + 0.5
			draw_line(pts[j], pts[j + 1], Color(0.92, 0.97, 1.0, 0.42 * a * (1.0 - float(j) / 9.0)), w, false)
	# Mitgerissene Blätter, taumelnd.
	for k in range(10):
		var lx := fposmod(_h01(k, 21) * 960.0 + sin(_t * 2.0 + k) * 20.0 - age * 25.0, 960.0)
		var ly := top + fposmod(_h01(k, 22) * span + age * (150.0 + 60.0 * _h01(k, 23)), span)
		if dir < 0.0:
			ly = bottom - (ly - top)
		var rot := _t * (3.0 + k % 3) + k
		var c := Vector2(lx, ly)
		var leaf := PackedVector2Array([c + Vector2(5, 0).rotated(rot), c + Vector2(0, 2).rotated(rot),
			c + Vector2(-5, 0).rotated(rot), c + Vector2(0, -2).rotated(rot)])
		draw_colored_polygon(leaf, Color(0.48, 0.70, 0.28, 0.9 * a) if k % 2 == 0 else Color(0.80, 0.52, 0.22, 0.9 * a))
		draw_line(leaf[0], leaf[2], Color(0.15, 0.22, 0.08, 0.8 * a), 1.0, false)

## Schwerkraftfeld: fallende Lichtpartikel und abwärts wandernde Wellenbänder.
func _draw_gravity(h: Dictionary, life: float, max_life: float) -> void:
	var a := _fade(life, max_life)
	var top := float(App.PLAY_TOP) + 4.0
	var bottom := float(App.PLAY_BOTTOM) - 4.0
	var span := bottom - top
	var age := max_life - life
	for k in range(4):
		var y := top + fposmod(age * 120.0 + k * span / 4.0, span)
		draw_rect(Rect2(0, y, 960, 2), Color(0.78, 0.50, 1.0, 0.16 * a))
	for k in range(36):
		var x := _h01(k, 31) * 960.0
		var fall := fposmod(_h01(k, 32) * span + age * age * 90.0 + age * 60.0, span)
		var p := Vector2(x, top + fall)
		draw_rect(Rect2(p.round(), Vector2(2, 4)), Color(0.85, 0.62, 1.0, 0.7 * a))

## Kanalflut: trübes Wasser mit pixeliger Wellenkante, Schaumkrone und aufsteigenden Blasen.
func _draw_flood(h: Dictionary) -> void:
	var top := float(h.y)
	var bottom := float(App.PLAY_BOTTOM) + 44.0
	if top >= bottom:
		return
	draw_rect(Rect2(-200, top, 1360, bottom - top), Color(0.12, 0.30, 0.26, 0.78))
	draw_rect(Rect2(-200, top + 26.0, 1360, bottom - top), Color(0.06, 0.18, 0.16, 0.45))
	# Wellenkante in 4px-Schritten, damit sie im Pixelraster bleibt.
	var x := -200.0
	while x < 1160.0:
		var wave := roundf(sin(x * 0.035 + _t * 3.2) * 2.0 + sin(x * 0.011 - _t * 1.7) * 2.0)
		draw_rect(Rect2(x, top + wave - 3.0, 4, 3), Color(0.70, 0.92, 0.80, 0.85))
		draw_rect(Rect2(x, top + wave, 4, 2), Color(0.30, 0.55, 0.45, 0.9))
		x += 4.0
	for k in range(22):
		var bx := fposmod(_h01(k, 61) * 1160.0 + _t * (14.0 + 8.0 * _h01(k, 62)), 1160.0) - 100.0
		var depth := bottom - top - 8.0
		var by := bottom - fposmod(_t * (22.0 + 18.0 * _h01(k, 63)) + _h01(k, 64) * depth, maxf(1.0, depth))
		draw_rect(Rect2(Vector2(bx, by).round(), Vector2(2, 2)), Color(0.75, 0.95, 0.85, 0.5))

## Schutzzone: ganzer Schirm als pulsierende Warnfläche, nur ein Kreis bleibt frei.
## Zeilenweise in 2px-Streifen, damit das Loch pixelig und exakt rund bleibt.
func _draw_safe_zone(h: Dictionary, life: float, max_life: float) -> void:
	var c: Vector2 = h.p
	var r := float(h.r)
	var urgency := 1.0 - clampf(life / maxf(0.001, max_life), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * (8.0 + 14.0 * urgency))
	var col := Color(0.30, 0.0, 0.02, 0.34 + 0.22 * urgency + 0.08 * pulse)
	var top := float(App.PLAY_TOP)
	var bottom := float(App.PLAY_BOTTOM)
	draw_rect(Rect2(0, top, 960, maxf(0.0, c.y - r - top)), col)
	draw_rect(Rect2(0, c.y + r, 960, maxf(0.0, bottom - c.y - r)), col)
	var y := c.y - r
	while y < c.y + r:
		var dy := y + 1.0 - c.y
		var half := sqrt(maxf(0.0, r * r - dy * dy))
		draw_rect(Rect2(0, y, maxf(0.0, c.x - half), 2), col)
		draw_rect(Rect2(c.x + half, y, maxf(0.0, 960.0 - c.x - half), 2), col)
		y += 2.0
	# Diagonale Warnstreifen wandern über die Fläche.
	for k in range(14):
		var x := fposmod(k * 76.0 - _t * 90.0, 1064.0) - 52.0
		draw_line(Vector2(x, bottom), Vector2(x + 52.0, top), Color(1.0, 0.25, 0.15, 0.16 + 0.12 * pulse), 4.0)
	# Rand der Schutzzone: hell, mit schrumpfendem Zeitbogen.
	draw_arc(c, r, 0.0, TAU, 40, Color(0.7, 1.0, 0.75, 0.95), 3.0)
	draw_arc(c, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - urgency), 40, Color(1.0, 1.0, 1.0, 0.85), 2.0)
	draw_circle(c, r - 2.0, Color(0.6, 1.0, 0.7, 0.08 + 0.06 * pulse))

## Strömung: lange wellige Wasserschlieren mit mitgerissenen Bläschen.
func _draw_current(h: Dictionary, life: float, max_life: float) -> void:
	var dir := signf(float(h.get("dir", -1.0)))
	var a := _fade(life, max_life)
	var age := max_life - life
	for k in range(9):
		var y0 := float(App.PLAY_TOP) + 30.0 + _h01(k, 41) * (float(App.PLAY_BOTTOM) - float(App.PLAY_TOP) - 60.0)
		var len := 80.0 + _h01(k, 42) * 90.0
		var head := fposmod(_h01(k, 43) * 960.0 + dir * age * (160.0 + 80.0 * _h01(k, 44)), 960.0 + len)
		var prev := Vector2.ZERO
		for j in range(10):
			var f := float(j) / 9.0
			var p := Vector2(head - dir * len * f, y0 + sin(f * 6.0 + _t * 3.0 + k) * 4.0)
			if j > 0:
				draw_line(prev, p, Color(0.62, 0.90, 1.0, 0.45 * a * (1.0 - f)), 2.0 * (1.0 - f) + 0.5, false)
			prev = p
		draw_circle(Vector2(head, y0) + Vector2(dir * 4.0, -3.0), 1.5, Color(0.9, 1.0, 1.0, 0.7 * a), true, -1.0, false)

func _draw_hazard(h: Dictionary) -> void:
	var kind := String(h.kind)
	var pos: Vector2 = h.p
	var life: float = float(h.life)
	var max_life: float = float(h.get("max_life", 3.0))
	var frac := 1.0 - clampf(life / maxf(0.001, max_life), 0.0, 1.0)
	match kind:
		"shootable_root", "root_spike":
			if String(h.get("style", "")) == "water":
				_draw_geyser(h, frac * max_life)
			else:
				_draw_root(h, frac * max_life)
		"spore_cloud":
			_draw_spores(h, life, max_life)
		"pollen_cloud":
			# Pollen der Biene: goldene Ballen mit glitzernden Körnchen.
			var r: float = float(h.radius)
			var fade := clampf(life / maxf(0.3, max_life), 0.0, 1.0) * 0.8 + 0.2
			# Durchsichtig genug, dass die Biene auch in mehreren Wolken sichtbar bleibt.
			fade *= 0.25 if bool(h.get("burst", false)) else 0.32
			# Blasses Pollengelb statt kräftigem Gold.
			for k in range(6):
				var ang := TAU * float(k) / 6.0 + _t * 0.5
				draw_circle(pos + Vector2.from_angle(ang) * r * 0.35, r * 0.42, Color(1.0, 0.92, 0.66, 0.22 * fade), true, -1.0, false)
			draw_circle(pos, r * 0.38, Color(1.0, 0.95, 0.75, 0.28 * fade), true, -1.0, false)
			if density > 0.5:
				for k in range(6):
					var a2 := TAU * _h01(k, 51) + _t * 0.9
					var d2 := r * (0.2 + 0.7 * _h01(k, 52))
					draw_rect(Rect2((pos + Vector2.from_angle(a2) * d2).round(), Vector2(2, 2)), Color(1.0, 0.95, 0.6, minf(0.8, 1.6 * fade)))
		"reflect_panel":
			_draw_glass(h)
		"light_shaft":
			# Lichtschacht durch die eingestürzte Decke: markiert die sichere Lücke.
			var w := float(h.get("w", 140.0))
			var top := pos.y
			for k in range(6):
				var a := 0.05 + 0.025 * sin(_t * 2.0 + k)
				var shrink := float(k) * w * 0.07
				draw_rect(Rect2(pos.x - w * 0.5 + shrink, top, w - shrink * 2.0, App.PLAY_BOTTOM - top), Color(1.0, 0.92, 0.65, a))
			for k in range(10):
				var yy := top + fposmod(_t * 30.0 + k * 47.0, App.PLAY_BOTTOM - top)
				var xx := pos.x + sin(_t + k * 2.1) * w * 0.35
				draw_rect(Rect2(xx, yy, 2, 2), Color(1.0, 0.95, 0.75, 0.6))
		"ceiling_crack":
			# Deckenriss: wachsende Spalte, rieselnder Staub, Warnfarbe kurz vor dem Fall.
			var grow := 0.4 + 0.6 * frac
			var hot := frac > 0.55
			var glow := Color(1.0, 0.55, 0.2, 0.55 + 0.4 * sin(_t * 22.0))
			# Hängender Brocken und Riss, der kurz vor dem Fall glüht.
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-12, 0), pos + Vector2(12, 0),
				pos + Vector2(8, 10 + 4 * frac), pos + Vector2(-6, 12 + 4 * frac)]), Color(0.42, 0.29, 0.18))
			var crack := PackedVector2Array([pos + Vector2(-22 * grow, 1), pos + Vector2(-8, 7), pos + Vector2(0, 2),
				pos + Vector2(9, 9), pos + Vector2(22 * grow, 3)])
			draw_polyline(crack, Color(0.1, 0.06, 0.03), 3.0)
			if hot:
				draw_polyline(crack, glow, 1.5)
			# Staubfahne zeigt die Fallbahn.
			for k in range(8):
				var fall := fposmod(_t * 150.0 + k * 19.0, 50.0 + 140.0 * frac)
				draw_rect(Rect2(pos + Vector2(-7 + (k % 4) * 4, 14 + fall), Vector2(3, 3)), Color(0.66, 0.5, 0.34, 0.85))
		"wind_marker":
			_draw_wind(h, life, max_life)
		"gravity_field":
			_draw_gravity(h, life, max_life)
		"safe_zone":
			_draw_safe_zone(h, life, max_life)
		"flood":
			_draw_flood(h)
		"water_line":
			var yy4: float = float(h.get("y", 470.0))
			draw_rect(Rect2(0, yy4, 960, 540 - yy4), Color(0.10, 0.35, 0.45, 0.45))
			draw_line(Vector2(0, yy4), Vector2(960, yy4), Color(0.75, 0.95, 1.0, 0.7), 2.0)
			for i in range(20):
				var x := fmod(float(i) * 53.0 + _t * 24.0, 960.0)
				draw_circle(Vector2(x, yy4 + sin(_t * 2.0 + i) * 3.0), 1.6, Color(0.85, 1.0, 1.0, 0.55))
		"current":
			_draw_current(h, life, max_life)
		"blossom":
			var tex := Art.frame_tex("blossom", 0)
			var s2 := 2.2
			draw_texture_rect(tex, Rect2(pos - Vector2(16, 16) * s2 * 0.5, Vector2(16, 16) * s2), false)
