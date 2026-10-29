extends Control
## HUD in Ausgabeauflösung: Gesundheit, Schild, Nektar, Punkte, Autofeuer,
## Bosszustand und die taktische Waffenleiste (LB/RB + RT bzw. Q/E + F).

const UiT := preload("res://scripts/core/ui_theme.gd")
const Prompts := preload("res://scripts/core/ui_prompts.gd")
const LevelProgress := preload("res://scripts/core/level_progress.gd")

# Palette des Pixel-UI (siehe ui_theme.gd): Indigo, Honiggold, Nektar-Türkis.
const BG := Color("#0b0a18")
const SURFACE := Color("#181b38")
const SECOND := Color("#242a4e")
const BORDER := Color("#465284")
const GOLD := Color("#ffd666")
const MINT := Color("#52d6c4")
const TEXT := Color("#fff4dc")
const DIM := Color("#a9acc9")
const ALERT := Color("#ff5c84")
const INK := Color("#08071a")
const GOLD_DEEP := Color("#e29c24")
## Gemeinsamer Vertrag mit App/Player/World: keine HUD-Fläche im begehbaren Feld.
## R4: flachere Bänder (oben 40, unten 44 statt 56/64), Werte stehen neben ihren
## Etiketten statt darunter – gleiche Schriftgrößen, mehr Spielfeld.
const HEADER_HEIGHT := 40.0
const STATUS_BOTTOM := 25.0
const RAIL_TOP := 27.0
const RAIL_BOTTOM := 37.0
const HINT_HEIGHT := 16.0
## Badge-Höhe der Hinweise; die untere Detailzeile nutzt kleinere Kappen.
var _hint_h := HINT_HEIGHT

var app: Node
var view: Rect2 = Rect2(0, 0, 1920, 1080)
var selected: int = 1
var bar_entries: Array = []
var banners: Array = []
var pulse_flash: float = 0.0
var boss_t: float = 0.0
var boss_len: float = 1.0
var white_flash: float = 0.0
var deny_flash: float = 0.0
## Phasenbanner (Boss): Restzeit, Nummer und Zeile.
var phase_t: float = 0.0
var phase_len: float = 1.0
var phase_num: int = 0
var phase_text: String = ""
var _t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	app = get_parent().get_parent() if false else get_node_or_null("/root/App")
	_add_initial_entries()

func set_view_rect(r: Rect2) -> void:
	view = r
	queue_redraw()

func _scale() -> float:
	return view.size.x / 960.0

func _game() -> Node:
	var a := get_node_or_null("/root/App")
	if a == null:
		return null
	return a.game

func _player() -> Player:
	var g := _game()
	if g == null or not is_instance_valid(g):
		return null
	return g.player

func _add_initial_entries() -> void:
	bar_entries.clear()
	for u in Data.UPGRADES:
		bar_entries.append(u.id)
	selected = 1

func _process(delta: float) -> void:
	_t += delta
	pulse_flash = maxf(0.0, pulse_flash - delta)
	white_flash = maxf(0.0, white_flash - delta * 2.2)
	if boss_t > 0.0:
		boss_t = maxf(0.0, boss_t - delta)
	deny_flash = maxf(0.0, deny_flash - delta)
	phase_t = maxf(0.0, phase_t - delta)
	var keep: Array = []
	for b in banners:
		b.t -= delta
		if b.t > 0.0:
			keep.append(b)
	banners = keep
	var g := _game()
	if g != null and is_instance_valid(g) and not g.level_over:
		var a := get_node_or_null("/root/App")
		var blocked: bool = a != null and (not a.screens.is_empty() or a.paused)
		if not blocked:
			_handle_input()
	queue_redraw()

func _handle_input() -> void:
	var p := _player()
	if p == null or not p.alive:
		return
	if Bindings.consume("upgrade_prev"):
		selected = (selected - 1 + bar_entries.size()) % bar_entries.size()
		Audio.sfx("ui_move", -12.0, 1.1, true)
		_announce_selected()
	if Bindings.consume("upgrade_next"):
		selected = (selected + 1) % bar_entries.size()
		Audio.sfx("ui_move", -12.0, 1.2, true)
		_announce_selected()
	if Bindings.consume("autofire"):
		p.autofire = not p.autofire
		Save.set_g("game.autofire_default", p.autofire)
		Audio.sfx("ui_ok", -10.0, 1.0, true)
		show_banner(Loc.t("hud.autofire_on") if p.autofire else "Autofeuer aus", 0.9)
	if Bindings.consume("upgrade_buy"):
		buy_selected(p)

## Gewähltes Upgrade kaufen/ausrüsten, mit Banner, Klang und Sprachansage.
func buy_selected(p: Player) -> void:
	var id := String(bar_entries[selected])
	var res: Dictionary = p.try_buy(id)
	if bool(res.get("ok", false)):
		pulse_flash = 0.35
		Audio.sfx("purchase", -5.0, 1.05)
		var u := Data.upgrade(id)
		show_banner("%s  %s" % [Loc.t(String(u.get("name", ""))), _state_text(p, id)], 1.2)
	elif bool(res.get("equipped", false)):
		# Waffe gewechselt, aber die Stufe war nicht bezahlbar.
		pulse_flash = 0.25
		var u2 := Data.upgrade(id)
		show_banner("%s  %s" % [Loc.t(String(u2.get("name", ""))), _state_text(p, id)], 1.1)
		show_banner(Loc.t("bar.no_nectar"), 0.9)
		Audio.voice("nectar_low", "Zu wenig Blütenstaub")
	else:
		deny_flash = 0.3
		Audio.sfx("deny", -6.0, 1.0, true)
		if String(res.get("msg", "")) == "bar.no_nectar":
			Audio.voice("nectar_low", "Zu wenig Blütenstaub")
		elif String(res.get("msg", "")) == "bar.maxed":
			Audio.voice("upgrade_max", "Voll ausgebaut")
		var msg := String(res.get("msg", ""))
		if msg != "":
			show_banner(Loc.t(msg), 1.0)

## Bossankündigung: kurzer Weißblitz und großer Schriftzug.
## Gewähltes Upgrade ansagen ("Blitz"), damit der Blick auf dem Spielfeld bleiben kann.
func _announce_selected() -> void:
	var id := String(bar_entries[selected])
	Audio.voice("upgrade_" + id, String(Data.upgrade(id).get("short", id)))

## Großes Phasenbanner über dem Spielfeld: "PHASE II" plus Bosszeile.
func phase_announce(num: int, line: String, seconds: float = 2.0) -> void:
	phase_num = num
	phase_text = line
	phase_t = seconds
	phase_len = seconds

func _draw_phase(s: float) -> void:
	if phase_t <= 0.0:
		return
	var k := 1.0 - phase_t / phase_len
	var open_k := smoothstep(0.0, 0.12, k)
	var fade := 1.0 - smoothstep(0.72, 1.0, k)
	var cy := view.position.y + 170.0 * s
	var h := 96.0 * s * open_k
	var band := Rect2(view.position.x, cy - h * 0.5, view.size.x, h)
	draw_rect(band, Color(0.05, 0.02, 0.04, 0.78 * fade))
	# Warnstreifen oben und unten, laufend.
	var stripe := 14.0 * s
	var off := fposmod(_t * 60.0 * s, stripe * 2.0)
	for edge in [band.position.y, band.end.y - 5.0 * s]:
		var x := view.position.x - stripe * 2.0 + off
		while x < view.end.x:
			draw_colored_polygon(PackedVector2Array([Vector2(x, edge), Vector2(x + stripe, edge),
				Vector2(x + stripe * 0.6, edge + 5.0 * s), Vector2(x - stripe * 0.4, edge + 5.0 * s)]),
				_alpha(Color(1.0, 0.35, 0.25), 0.9 * fade))
			x += stripe * 2.0
	if open_k < 0.6:
		return
	var roman: String = ["I", "II", "III", "IV", "V"][clampi(phase_num - 1, 0, 4)]
	var font := UiT.font_display()
	var fs := int(round(46.0 * s))
	var title: String = "PHASE " + roman
	var slide := (1.0 - smoothstep(0.0, 0.2, k)) * 80.0 * s
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := view.position.x + (view.size.x - tw) * 0.5 - slide
	var ty := cy + fs * 0.12
	draw_string(font, Vector2(tx + 3.0 * s, ty + 3.0 * s), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _alpha(Color(0.35, 0.05, 0.05), fade))
	draw_string(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _alpha(Color(1.0, 0.86, 0.4), fade))
	var sub_rect := Rect2(band.position.x, cy + 14.0 * s, band.size.x, 22.0 * s)
	_text(phase_text, sub_rect, 13, _alpha(Color(1.0, 0.72, 0.6), fade), s, true, HORIZONTAL_ALIGNMENT_CENTER)

func boss_announce(seconds: float = 1.3, with_sound: bool = true) -> void:
	boss_t = seconds
	boss_len = seconds
	white_flash = 0.85
	if with_sound:
		Audio.sfx("boss_warn", -4.0, 0.8, true)

func show_banner(text: String, seconds: float = 1.6) -> void:
	banners.append({"text": text, "t": seconds, "max": seconds})

func _state_text(p: Player, id: String) -> String:
	var u := Data.upgrade(id)
	var lvl := int(p.upgrades.get(id, 0))
	if id == "repair":
		return Loc.t("bar.cost", [Data.upgrade_cost("repair", 0, p.evo_effect("cost_mult"))])
	if lvl >= int(u.get("max", 1)):
		if String(u.get("kind", "")) == "weapon":
			return Loc.t("bar.active") if p.weapon == id else Loc.t("bar.owned")
		if id == "speed":
			return Loc.t("bar.slower")
		return Loc.t("bar.max")
	return Loc.t("bar.cost", [p.upgrade_cost_for(id)])

func _draw() -> void:
	var s := _scale()
	var p := _player()
	if p == null or not is_instance_valid(p):
		return
	_draw_status(p, s)
	_draw_level(s)
	var g := _game()
	if g != null and g.boss != null and is_instance_valid(g.boss) and not g.boss.dead and not g.boss.fake_dead:
		_draw_boss_bar(g.boss, s)
	_draw_bar(p, s)
	_draw_boss_intro(s)
	_draw_banners(s)
	_draw_phase(s)
	# Die optionale Trefferzonenanzeige bleibt geometrisch unverändert.
	if bool(Save.g("game.hitbox", false)) and p.alive:
		var pp: Vector2 = view.position + p.position * s
		draw_arc(pp, 4.6 * s, 0.0, TAU, 20, Color(1, 0.3, 0.4, 0.9), 1.5)
		draw_circle(pp, 1.2 * s, Color(1, 1, 1, 0.9))

## Feste Geometrie, skalierende Schrift: auch bei 160 % bleibt alles vor y=56.
## Levelbadge und Boss/Meldungen haben getrennte, niemals überlappende Räume.
func _status_layout(s: float) -> Dictionary:
	var band := Rect2(view.position, Vector2(view.size.x, HEADER_HEIGHT * s))
	return {
		"header": band,
		"vital": _area(band, 12, 3, 156, 22, s),
		"shield": _area(band, 174, 3, 172, 22, s),
		"nectar": _area(band, 352, 3, 162, 22, s),
		"score": _area(band, 520, 3, 172, 22, s),
		"controls": _area(band, 698, 3, 250, 22, s),
		"rail": _area(band, 12, RAIL_TOP, 936, RAIL_BOTTOM - RAIL_TOP, s),
		"level": _area(band, 12, RAIL_TOP, 112, 10, s),
		"level_name": _area(band, 132, RAIL_TOP, 212, 10, s),
		"progress": _area(band, 352, RAIL_TOP, 264, 10, s),
		"eta": _area(band, 624, RAIL_TOP, 76, 10, s),
		"notice": _area(band, 708, RAIL_TOP, 240, 10, s),
		"boss_name": _area(band, 132, RAIL_TOP, 228, 10, s),
		"boss_hp": _area(band, 372, RAIL_TOP + 3, 292, 4, s),
		"boss_status": _area(band, 676, RAIL_TOP, 272, 10, s),
	}

func _level_info() -> Dictionary:
	var g := _game()
	if g == null or not is_instance_valid(g):
		return {}
	var index: int = g.level_index
	# Rush lädt die Bühne von Level 10; die Anzeige folgt dagegen dem echten Boss.
	# Boss.level_index ist dort ein Bedrohungswert, kein verlässlicher Datenindex.
	if String(g.mode) == "rush":
		var boss_id := ""
		if g.boss != null and is_instance_valid(g.boss) and not g.boss.dead and not g.boss.fake_dead:
			boss_id = String(g.boss.id)
		elif g.rush_index >= 0 and g.rush_index < g.boss_sequence.size():
			boss_id = String(g.boss_sequence[g.rush_index])
		for level in Data.levels:
			if String(level.get("boss", "")) == boss_id:
				index = int(level.get("id", index))
				break
	var data := Data.level(index)
	return {"index": index, "total": Data.levels.size(),
		"name": String(data.get("name", "")), "mode": String(g.mode)}

func _level_text(compact: bool = false) -> String:
	var info := _level_info()
	if info.is_empty():
		return ""
	var label := "LEVEL %02d / %02d" % [info.index, info.total]
	return label if compact else label + " · " + Loc.tx(String(info.name))

func _draw_level(s: float) -> void:
	var layout := _status_layout(s)
	var badge: Rect2 = layout.level
	# Levelplakette: goldene Schräge, dunkle Schrift wie ein Messingschild.
	_round_box(badge, GOLD_DEEP.darkened(0.15), GOLD, 4.0 * s)
	_round_box(badge.grow(-s), Color.TRANSPARENT, Color(1, 0.95, 0.7, 0.35), 2.0 * s)
	_caps(_level_text(true), badge.grow_individual(-5.0 * s, 0, -5.0 * s, 0), INK, s,
		HORIZONTAL_ALIGNMENT_CENTER)
	if not _boss_is_visible():
		var info := _level_info()
		var prefix := "Rush · " if String(info.get("mode", "")) == "rush" else ""
		_text(prefix + Loc.tx(String(info.get("name", ""))), layout.level_name, 10, TEXT, s, true)
		_draw_progress(layout, s)

func _draw_progress(layout: Dictionary, s: float) -> void:
	var info := progress_info()
	if info.is_empty():
		return
	LevelProgress.draw_track(self, layout.progress, info, s, _t)
	var phase := String(info.get("phase", "run"))
	_text(LevelProgress.caption(info), layout.eta, 8, GOLD if phase in ["wait", "boss"] else DIM,
		s, true, HORIZONTAL_ALIGNMENT_RIGHT)

## Schätzung der Regie; im Boss-Rush zählt stattdessen die Bossfolge.
func progress_info() -> Dictionary:
	var g := _game()
	if g == null or not is_instance_valid(g) or g.director == null:
		return {}
	if String(g.mode) == "rush":
		var count := maxi(1, g.boss_sequence.size())
		var marks: Array = []
		for i in range(1, count):
			marks.append(float(i) / float(count))
		return {"phase": "rush", "progress": clampf(float(g.rush_index) / float(count), 0.0, 1.0),
			"index": mini(int(g.rush_index) + 1, count), "count": count, "marks": marks}
	return g.director.eta()

func _shield_active(p: Player) -> bool:
	# Player ist die einzige Quelle; dauerhafte Werkstattkäufe schalten nichts frei.
	return p.shield_active()

func _shield_status(p: Player) -> Dictionary:
	var active := _shield_active(p)
	var capacity := p.shield_max if active else 0
	var hits := clampi(p.shield_hits, 0, capacity)
	var charging := active and hits < capacity
	return {"active": active, "capacity": capacity, "hits": hits,
		"charging": charging, "progress": _shield_progress(p) if charging else 0.0,
		"track_visible": active and capacity > 0}

func _shield_duration(p: Player) -> float:
	return maxf(0.001, p.shield_regen_duration())

func _shield_progress(p: Player) -> float:
	return clampf(p.shield_regen_progress(), 0.0, 1.0)

func _draw_status(p: Player, s: float) -> void:
	var layout := _status_layout(s)
	var band: Rect2 = layout.header
	_draw_band(band, s, true)
	for key in ["vital", "shield", "nectar", "score", "controls"]:
		_gauge(layout[key], s)
	# Eine Zeile je Instrument: Etikett links, Wert rechts daneben.
	var vital: Rect2 = layout.vital
	var hurt := clampf(1.0 - float(p.hp) / maxf(1.0, float(p.max_hp)), 0.0, 1.0)
	_caps("VITAL", _area(vital, 7, 0, 40, 22, s), DIM, s)
	var pip := minf(17.0, 68.0 / maxf(1.0, float(p.max_hp)))
	for i in range(p.max_hp):
		var full := i < p.hp
		var beat := 1.0
		if full and p.hp <= 1:
			beat = 0.75 + 0.25 * absf(sin(_t * 5.0))
		_icon(Art.sheet("icon_hp"), Rect2(vital.position + Vector2((46.0 + i * pip) * s, 3.0 * s),
			Vector2(16, 16) * s), Color(beat, beat, beat) if full else Color(0.22, 0.22, 0.36))
	_value("%d/%d" % [p.hp, p.max_hp], _area(vital, 116, 0, 34, 22, s), 16,
		TEXT.lerp(ALERT, hurt * 0.8), s, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_shields(p, layout.shield, s)
	var nectar: Rect2 = layout.nectar
	_icon(Art.sheet("icon_nectar"), _area(nectar, 4, 2, 18, 18, s))
	_caps("BLÜTENSTAUB", _area(nectar, 25, 0, 74, 22, s), DIM, s)
	_value(_points(p.nectar), _area(nectar, 100, 0, 56, 22, s), 18, GOLD, s, HORIZONTAL_ALIGNMENT_RIGHT)
	var score: Rect2 = layout.score
	_caps("PUNKTE", _area(score, 7, 0, 48, 22, s), DIM, s)
	_value(_points(p.points), _area(score, 56, 0, 110, 22, s), 20, TEXT, s,
		HORIZONTAL_ALIGNMENT_RIGHT)
	# Tastatur UND Xbox stets gleichzeitig, nebeneinander in einer Zeile.
	var controls: Rect2 = layout.controls
	var auto_label := "Auto " + Loc.tx("AN" if p.autofire else "AUS")
	_hint_h = 14.0
	var half := controls.size.x * 0.5
	var a_s := _hint_scale("autofire", auto_label, half - 10.0 * s, s)
	_draw_hint("autofire", auto_label, controls.position + Vector2(6.0 * s, 4.0 * s), a_s,
		MINT if p.autofire else DIM)
	var m_s := _hint_scale("menu", "Menü", half - 10.0 * s, s)
	var m_w := _hint_width("menu", "Menü", m_s)
	_draw_hint("menu", "Menü", Vector2(controls.end.x - 6.0 * s - m_w, controls.position.y + 4.0 * s), m_s, DIM)
	_hint_h = HINT_HEIGHT

func _draw_band(field_band: Rect2, s: float, top: bool) -> void:
	var canvas_w := get_viewport_rect().size.x
	var band := Rect2(Vector2(0, field_band.position.y), Vector2(canvas_w, field_band.size.y))
	draw_rect(band, BG)
	draw_rect(Rect2(band.position, Vector2(band.size.x, band.size.y * 0.55)), Color("#121230"))
	var hexa := UiT.kit("honeycomb")
	if hexa != null:
		var cell := Vector2(hexa.get_width(), hexa.get_height()) * s
		var x := fposmod(-view.position.x, cell.x) - cell.x
		while x < canvas_w:
			var y := band.position.y - fposmod(band.position.y, cell.y)
			while y < band.end.y:
				var r := Rect2(Vector2(x, y), cell).intersection(band)
				if r.size.x > 0.0 and r.size.y > 0.0:
					var src := Rect2((r.position - Vector2(x, y)) / s, r.size / s)
					draw_texture_rect_region(hexa, r, src, Color(1, 1, 1, 0.45))
				y += cell.y
			x += cell.x
	# Gefüllte Streifen im Bildpixelraster: kein halber Pixel im Spielfeld.
	var edge_y := band.end.y - 3.0 * s if top else band.position.y
	draw_rect(Rect2(0, edge_y, canvas_w, s), GOLD_DEEP.darkened(0.35) if top else BORDER)
	draw_rect(Rect2(0, edge_y + s, canvas_w, s), GOLD if top else GOLD_DEEP.darkened(0.35))
	draw_rect(Rect2(0, edge_y + 2.0 * s, canvas_w, s), INK if top else BG)

## Instrumentenfeld: dunkle Vertiefung mit Lichtkante.
func _gauge(rect: Rect2, s: float) -> void:
	_round_box(rect, Color("#141633"), BORDER, 4.0 * s)
	draw_rect(Rect2(rect.position + Vector2(2.0 * s, rect.size.y - 3.0 * s),
		Vector2(rect.size.x - 4.0 * s, s)), Color(0, 0, 0, 0.35))

func _draw_shields(p: Player, rect: Rect2, s: float) -> void:
	var status := _shield_status(p)
	var active: bool = status.active
	var charging: bool = status.charging
	var progress: float = status.progress
	_caps("SCHILD", _area(rect, 7, 0, 48, 22, s), MINT if active else DIM, s)
	if not active:
		# Kein Quellenersatz durch Shopdaten, kein Fake-Pip und kein Ladetrack.
		_text("Taktisch kaufen", _area(rect, 58, 0, 108, 22, s), 11, DIM, s)
		return
	var slots: int = status.capacity
	var step := minf(16.0, 64.0 / maxf(1.0, float(slots)))
	for i in range(slots):
		var pip := _area(rect, 56 + float(i) * step, 4, minf(14.0, step - 1.0), 14, s)
		_draw_shield_pip(pip, i < status.hits, charging and i == status.hits, s)
	var state := "BEREIT"
	if charging:
		state = "%d%%" % roundi(progress * 100.0)
	_caps(state, _area(rect, 120, 0, 46, 22, s), MINT, s, HORIZONTAL_ALIGNMENT_RIGHT)
	# Ladeleiste als feine Pixelzeile an der Unterkante des Instruments.
	var track := _area(rect, 4, 19, 164, 1, s)
	draw_rect(track, Color("#0c0d22"))
	if charging and progress > 0.0:
		draw_rect(Rect2(track.position, Vector2(floor(track.size.x * progress / s) * s, track.size.y)), MINT)

func _draw_shield_pip(rect: Rect2, filled: bool, charging: bool, s: float) -> void:
	# Sechseckige Wabe als Schildladung, im Bildpixelraster gezeichnet.
	var c := rect.get_center().round()
	var r: float = floor(minf(rect.size.x, rect.size.y) * 0.5 / s) * s
	var pts := PackedVector2Array()
	for j in range(6):
		pts.append((c + Vector2.from_angle(PI / 6.0 + float(j) * TAU / 6.0) * r).round())
	draw_colored_polygon(pts, MINT.darkened(0.1) if filled else Color("#0c0d22"))
	var inner := PackedVector2Array()
	for j in range(6):
		inner.append((c + Vector2.from_angle(PI / 6.0 + float(j) * TAU / 6.0) * (r - 2.0 * s)).round())
	if filled:
		draw_colored_polygon(inner, MINT.lightened(0.15))
		draw_rect(Rect2(c - Vector2(s, r - 3.0 * s), Vector2(s * 2.0, s)), Color(1, 1, 1, 0.7))
	pts.append(pts[0])
	draw_polyline(pts, MINT if filled or charging else BORDER, s, false)
	if charging:
		var blink := 0.5 + 0.5 * sin(_t * 8.0)
		draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), Color(MINT, blink))

func _bar_top(s: float) -> float:
	# Oberkante der Leiste = Unterkante des Spielbereichs (App.PLAY_BOTTOM).
	var strip := (540.0 - App.PLAY_BOTTOM) * s
	return view.position.y + view.size.y - strip

func _boss_readout(b: Boss) -> Dictionary:
	var status := "Phase %d/%d · %s" % [b.phase + 1, b.phase_defs.size(),
		Loc.tx("Schwachpunkt offen" if b.vulnerable else "Panzerung aktiv")]
	if not banners.is_empty():
		status = String(banners[-1].text)
	return {"title": ("BOSS · " if boss_t > 0.0 else "") + b.name_text,
		"fraction": clampf(b.hp / maxf(1.0, b.max_hp), 0.0, 1.0), "status": status}

func _draw_boss_bar(b: Boss, s: float) -> void:
	# Nur 12px-Rail; die ersten 112px bleiben immer exklusiv für das Levelbadge.
	var layout := _status_layout(s)
	var readout := _boss_readout(b)
	_text(readout.title, layout.boss_name, 10, GOLD if boss_t > 0.0 else TEXT, s, true)
	var track: Rect2 = layout.boss_hp
	var frame := track.grow_individual(2.0 * s, 2.0 * s, 2.0 * s, 2.0 * s)
	draw_rect(frame, INK)
	draw_rect(frame.grow(-s), Color("#1a1030"))
	var frac: float = readout.fraction
	# Segmentierter Pixelbalken: Gold bei vollem Leben, Rosé kurz vor dem Fall.
	var seg := 6.0 * s
	var count := int(floor(track.size.x / seg))
	var lit := int(ceil(float(count) * frac))
	var fill := GOLD.lerp(ALERT, clampf(1.0 - frac * 1.6, 0.0, 1.0))
	for i in range(count):
		var r := Rect2(track.position + Vector2(float(i) * seg, 0), Vector2(seg - s, track.size.y))
		if i < lit:
			draw_rect(r, fill)
			draw_rect(Rect2(r.position, Vector2(r.size.x, s)), fill.lightened(0.45))
		else:
			draw_rect(r, Color("#2a1d40"))
	_text(readout.status, layout.boss_status, 9, MINT if b.vulnerable else DIM,
		s, false, HORIZONTAL_ALIGNMENT_RIGHT)

func _bar_layout(s: float) -> Dictionary:
	var band := Rect2(view.position.x, _bar_top(s), view.size.x, (540.0 - App.PLAY_BOTTOM) * s)
	var n := maxi(1, bar_entries.size())
	var gap := 6.0 * s
	var cell_w := minf(100.0 * s, (view.size.x - 28.0 * s - float(n - 1) * gap) / float(n))
	var total := n * cell_w + (n - 1) * gap
	var x0 := view.position.x + (view.size.x - total) * 0.5
	var cards: Array[Rect2] = []
	for i in range(n):
		cards.append(Rect2(x0 + i * (cell_w + gap), band.position.y + 13.0 * s, cell_w, 29.0 * s))
	return {"band": band, "cards": cards, "status_y": band.position.y + 2.0 * s}

func _draw_bar(p: Player, s: float) -> void:
	if bar_entries.is_empty():
		_add_initial_entries()
	var n := bar_entries.size()
	var layout := _bar_layout(s)
	var band: Rect2 = layout.band
	_draw_band(band, s, false)
	for i in range(n):
		var id := String(bar_entries[i])
		var u := Data.upgrade(id)
		var lvl := int(p.upgrades.get(id, 0))
		var active := (id == p.weapon) or (id == "speed" and p.speed_level > 0) or (id == "shield" and _shield_active(p))
		var owned := lvl > 0 or (id == "shield" and _shield_active(p))
		var sel := i == selected
		var rect: Rect2 = layout.cards[i]
		var cell_w := rect.size.x
		var maxlvl := int(u.get("max", 1))
		# Diese Anzeige benutzt unverändert dieselbe Bezahlbarkeitsprüfung.
		var buyable := lvl < maxlvl and p.nectar >= p.upgrade_cost_for(id)
		if id == "repair":
			buyable = p.hp < p.max_hp and p.nectar >= Data.upgrade_cost("repair", 0,
				p.evo_effect("cost_mult"))
		var kit_name := "slot_sel" if sel else ("slot_active" if active else "slot")
		if sel:
			# Pulsierender Goldschein um den gewählten Slot.
			var glow := 0.35 + 0.25 * sin(_t * 5.0) + pulse_flash
			_round_box(rect.grow(2.0 * s), Color.TRANSPARENT, Color(GOLD, clampf(glow, 0.0, 1.0)), 4.0 * s)
		draw_style_box(UiT.framed(kit_name, 4, 0), rect)
		if deny_flash > 0.0 and sel:
			draw_rect(rect.grow(-2.0 * s), Color(ALERT, 0.35 * deny_flash / 0.3))
		if buyable and not sel:
			draw_rect(Rect2(rect.position + Vector2(4.0 * s, s), Vector2(rect.size.x - 8.0 * s, s)),
				Color(GOLD, 0.45 + 0.25 * sin(_t * 3.0 + float(i))))
		var icon_alpha := 1.0 if (owned or buyable or id == "base") else 0.45
		_icon(Art.sheet("icon_" + id), _area(rect, 3, 6, 17, 17, s), Color(1, 1, 1, icon_alpha))
		var name_col := TEXT if (owned or buyable or id == "base") else DIM
		_text(String(u.get("short", Loc.t(String(u.name)))),
			_area(rect, 22, 2, cell_w / s - 25, 11, s), 11, name_col, s, true)
		_text(_state_short(p, id), _area(rect, 22, 12, cell_w / s - 25, 9, s),
			9, GOLD if buyable else (MINT if active else DIM), s)
		for l in range(maxlvl):
			var dot := _area(rect, 22 + l * 5, 22, 4, 4, s)
			draw_rect(dot, INK)
			draw_rect(dot.grow(-s), (MINT if active else GOLD) if l < lvl else Color("#2b2f58"))
		var status := "AKTIV" if active else ("KAUFBAR" if buyable else ("BESITZ" if owned else "SPAREN"))
		if id == "repair" and p.hp >= p.max_hp:
			status = "VOLL"
		var status_col := MINT if active else (GOLD if buyable else DIM)
		_caps(status, _area(rect, 38, 20, cell_w / s - 41, 8, s), status_col, s, HORIZONTAL_ALIGNMENT_RIGHT)
	# Auswahl links, dynamische Tastatur- UND Controller-Badges rechts.
	var sel_id := String(bar_entries[selected])
	var u2 := Data.upgrade(sel_id)
	var detail := Loc.t(String(u2.name)) + " · " + _state_text(p, sel_id)
	_hint_h = 11.0
	var hint_s := _bar_hint_scale(s)
	var hints_w := _bar_hint_width(hint_s)
	var hx := view.end.x - 14.0 * s - hints_w
	var hy: float = layout.status_y
	_text(detail, Rect2(view.position.x + 14.0 * s, hy, hx - view.position.x - 30.0 * s, 10.0 * s),
		10, TEXT, s, true)
	hx += _draw_hint("upgrade_prev", "Wählen", Vector2(hx, hy), hint_s) + 8.0 * hint_s
	hx += _draw_hint("upgrade_next", "", Vector2(hx, hy), hint_s) + 18.0 * hint_s
	_draw_hint("upgrade_buy", "Nutzen", Vector2(hx, hy), hint_s)
	_hint_h = HINT_HEIGHT

func maxed_out(lvl: int, maxlvl: int) -> bool:
	return lvl >= maxlvl

func _state_short(p: Player, id: String) -> String:
	var u := Data.upgrade(id)
	var lvl := int(p.upgrades.get(id, 0))
	var maxlvl := int(u.get("max", 1))
	if id == "repair":
		return Loc.t("bar.cost", [Data.upgrade_cost("repair", 0, p.evo_effect("cost_mult"))])
	if lvl >= maxlvl:
		if String(u.get("kind", "")) == "weapon":
			return Loc.t("bar.active") if p.weapon == id else Loc.t("bar.owned")
		return Loc.t("bar.max")
	return "%d  (%d/%d)" % [p.upgrade_cost_for(id), lvl, maxlvl]

func _boss_is_visible() -> bool:
	var g := _game()
	return g != null and g.boss != null and is_instance_valid(g.boss) and not g.boss.dead and not g.boss.fake_dead

func _draw_boss_intro(s: float) -> void:
	# Kein Vollbildblitz/Popup vor Geschossen: Alarm bleibt vollständig im Header.
	if white_flash > 0.0 and not bool(Save.g("access.reduce_effects", false)):
		var rail: Rect2 = _status_layout(s).rail
		draw_line(rail.position, Vector2(rail.end.x, rail.position.y),
			_alpha(GOLD, clampf(white_flash, 0.0, 1.0)), s)
	if boss_t > 0.0 and not _boss_is_visible():
		var notice: Rect2 = _status_layout(s).notice
		_text("GEFAHR ERKANNT · BOSS NÄHERT SICH", notice, 9, GOLD, s, true,
			HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_banners(s: float) -> void:
	if _boss_is_visible() or boss_t > 0.0:
		return # Bei Bossen nutzt die letzte Meldung dessen rechte Statusspalte.
	var notice: Rect2 = _status_layout(s).notice
	if banners.is_empty():
		return # Der Levelname ist die dauerhafte Information, kein Füllschriftzug.
	# Nur die neueste Information, im eigenen Raum rechts vom Levelnamen.
	_text(String(banners[-1].text), notice, 9, TEXT, s, true, HORIZONTAL_ALIGNMENT_RIGHT)

# ------------------- Reine Zeichenhilfen: keine Eingaben, Zustände oder Käufe.
func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, opacity)

func _area(rect: Rect2, x: float, y: float, w: float, h: float, s: float) -> Rect2:
	return Rect2(rect.position + Vector2(x, y) * s, Vector2(w, h) * s)

## Pixelplakette: abgeschrägte Ecken statt Rundungen, Kanten im Bildpixelraster.
## `radius` wählt nur die Größe der Schräge (klein/groß), keine weiche Kurve.
func _round_box(rect: Rect2, bg: Color, border: Color, radius: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var r := Rect2(rect.position.round(), rect.size.round())
	var u := maxf(1.0, round(_scale() * 0.5) * 2.0 * 0.5)
	var cut := clampf(2.0 * u if radius >= 4.0 * _scale() else u, 0.0, minf(r.size.x, r.size.y) * 0.25)
	if bg.a > 0.0:
		draw_rect(Rect2(r.position + Vector2(cut, 0), Vector2(r.size.x - cut * 2.0, r.size.y)), bg)
		draw_rect(Rect2(r.position + Vector2(0, cut), Vector2(r.size.x, r.size.y - cut * 2.0)), bg)
		if cut >= 2.0 * u:
			draw_rect(Rect2(r.position + Vector2(u, u), r.size - Vector2(u, u) * 2.0), bg)
	if border.a <= 0.0:
		return
	var w := u
	draw_rect(Rect2(r.position + Vector2(cut, 0), Vector2(r.size.x - cut * 2.0, w)), border)
	draw_rect(Rect2(r.position + Vector2(cut, r.size.y - w), Vector2(r.size.x - cut * 2.0, w)), border)
	draw_rect(Rect2(r.position + Vector2(0, cut), Vector2(w, r.size.y - cut * 2.0)), border)
	draw_rect(Rect2(r.position + Vector2(r.size.x - w, cut), Vector2(w, r.size.y - cut * 2.0)), border)
	# Treppenstufen in den Ecken (ein bzw. zwei Pixel).
	var steps := int(round(cut / u))
	for i in range(steps):
		var d := float(i) * u
		var e := cut - d - u
		for corner in [Vector2(d, e), Vector2(r.size.x - u - d, e), Vector2(d, r.size.y - u - e),
				Vector2(r.size.x - u - d, r.size.y - u - e)]:
			draw_rect(Rect2(r.position + corner, Vector2(u, u)), border)
	# Lichtkante oben (Glasplakette), sehr dezent.
	draw_rect(Rect2(r.position + Vector2(cut, w), Vector2(r.size.x - cut * 2.0, w)), Color(1, 1, 1, 0.07))

## Pixelsymbol in ganzzahliger Vergrößerung, zentriert im Zielrechteck.
func _icon(tex: Texture2D, rect: Rect2, color: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var src := Vector2(tex.get_width(), tex.get_height())
	if src.x > src.y * 1.5:
		src.x = src.y  # Bildstreifen: nur das erste Feld
	var k := maxf(1.0, floor(minf(rect.size.x / src.x, rect.size.y / src.y)))
	var dst := Rect2((rect.get_center() - src * k * 0.5).round(), src * k)
	draw_texture_rect_region(tex, dst, Rect2(Vector2.ZERO, src), color)

func _font(px: float, s: float) -> int:
	# Canvas-Skala genau einmal; ui_scale enthält nur die Nutzer-/Lesbarkeitswahl.
	return maxi(1, roundi(px * s * UiT.ui_scale()))

## Pixelschriften haben viel Zeilenabstand: gemessen wird die sichtbare
## Versalhöhe (Jersey 10 ≈ 0,54 em), nicht die volle Zeilenhöhe.
const CAP_RATIO := 0.54

func _fit_font(font: Font, text: String, rect: Rect2, px: float, s: float) -> int:
	var fs := _font(px * 1.6, s)
	while fs > 1 and (fs * CAP_RATIO > rect.size.y * 0.78 or
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x):
		fs -= 1
	return fs

func _text(text: String, rect: Rect2, px: float, color: Color, s: float,
		bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	text = Loc.tx(text)
	var font := UiT.font_bold() if bold else UiT.font_regular()
	var fs := _fit_font(font, text, rect, px, s)
	# Versalien mittig: Grundlinie = Mitte + halbe Versalhöhe.
	var baseline := rect.position.y + rect.size.y * 0.5 + fs * CAP_RATIO * 0.5
	draw_string(font, Vector2(rect.position.x, round(baseline)), text, align, rect.size.x, fs, color)

## Versalienetikett in Silkscreen, exakt im 8er-Raster der Schrift.
func _caps(text: String, rect: Rect2, color: Color, s: float,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	text = Loc.tx(text)
	var font := UiT.font_caps()
	var fs := maxi(8, int(round(s * UiT.ui_scale())) * 8)
	while fs > 8 and (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x
			or fs * 0.625 > rect.size.y):
		fs -= 8
	# Silkscreen: 5 von 8 Rasterpixeln sind Versalhöhe.
	var baseline := rect.position.y + rect.size.y * 0.5 + fs * 0.625 * 0.5
	draw_string(font, Vector2(rect.position.x, round(baseline)), text, align, rect.size.x, fs, color)

## Große Zahl in Jersey 10 mit hartem Pixelschatten.
func _value(text: String, rect: Rect2, px: float, color: Color, s: float,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_text(text, Rect2(rect.position + Vector2(s, s), rect.size), px, INK, s, true, align)
	_text(text, rect, px, color, s, true, align)

func _points(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			grouped += Loc.group_sep()
		grouped += digits[i]
	return ("−" if value < 0 else "") + grouped

func _hint_font(s: float) -> int:
	return _fit_font(UiT.font_bold(), "Ag", Rect2(0, 0, 200.0 * s, (_hint_h - 4.0) * s), 10, s)

func _hint_scale(action: String, label: String, max_width: float, s: float) -> float:
	var fitted := s
	for _i in range(8):
		var needed := _hint_width(action, label, fitted)
		if needed <= max_width:
			break
		fitted *= max_width / maxf(1.0, needed) * 0.98
	return fitted

func _bar_hint_width(s: float) -> float:
	return _hint_width("upgrade_prev", "Wählen", s) + 8.0 * s + _hint_width(
		"upgrade_next", "", s) + 18.0 * s + _hint_width("upgrade_buy", "Nutzen", s)

func _bar_hint_scale(s: float) -> float:
	var fitted := s
	for _i in range(8):
		var needed := _bar_hint_width(fitted)
		if needed <= 520.0 * s:
			break
		fitted *= 520.0 * s / maxf(1.0, needed) * 0.98
	return fitted

func _token_width(token: Dictionary, s: float) -> float:
	var label := String(token.get("text", "—"))
	var font_w := UiT.font_bold().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint_font(s)).x
	return maxf(18.0 * s, font_w + 10.0 * s)

func _hint_width(action: String, label: String, s: float) -> float:
	var width := 0.0
	if not label.is_empty():
		width = UiT.font_bold().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint_font(s)).x + 7.0 * s
	var tokens: Array[Dictionary] = Prompts.tokens(action, "both")
	for i in range(tokens.size()):
		width += _token_width(tokens[i], s) + (4.0 * s if i > 0 else 0.0)
	return width

func _draw_hint(action: String, label: String, pos: Vector2, s: float, color: Color = DIM) -> float:
	var x := pos.x
	if not label.is_empty():
		var label_w := UiT.font_bold().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint_font(s)).x
		_text(label, Rect2(x, pos.y, label_w + s, _hint_h * s), 9, color, s, true)
		x += label_w + 7.0 * s
	var tokens: Array[Dictionary] = Prompts.tokens(action, "both")
	for i in range(tokens.size()):
		if i > 0:
			x += 4.0 * s
		var width := _token_width(tokens[i], s)
		_draw_badge(tokens[i], Rect2(x, pos.y, width, _hint_h * s), s)
		x += width
	return x - pos.x

func _draw_badge(token: Dictionary, rect: Rect2, s: float) -> void:
	var label := String(token.get("text", "—"))
	var pad := String(token.get("kind", "key")) == "pad"
	var accent: Color = token.get("color", MINT if pad else DIM)
	var face_button := pad and label in ["A", "B", "X", "Y"]
	var px := clampf(rect.size.y / s * 0.62, 7.0, 10.0)
	if face_button:
		# Runde Gamepad-Taste als Pixelkreis.
		var c := rect.get_center().round()
		var r: float = floor(rect.size.y * 0.5 / s) * s
		draw_circle(c, r, INK, true, -1.0, false)
		draw_circle(c, r - s, accent.darkened(0.35), true, -1.0, false)
		draw_circle(c - Vector2(0, s), r - 2.0 * s, accent.darkened(0.1), true, -1.0, false)
		_text(label, rect.grow(-s), px, INK, s, true, HORIZONTAL_ALIGNMENT_CENTER)
		return
	# Tastenkappe: Oberseite hell, Unterkante als Pixelschatten.
	_round_box(rect, INK, Color.TRANSPARENT, 2.0 * s)
	var cap := rect.grow_individual(-s, -s, -s, -2.0 * s)
	_round_box(cap, SECOND.lerp(accent, 0.12 if pad else 0.0), _alpha(accent, 0.85 if pad else 0.5), 2.0 * s)
	_text(label, cap.grow(-s), px, accent if pad else TEXT, s, true, HORIZONTAL_ALIGNMENT_CENTER)

