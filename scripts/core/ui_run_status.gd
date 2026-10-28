extends RefCounted
## Statusspalte für Bildschirme über der laufenden Partie (Pause, Game Over):
## Level, Laufzeitleiste und die wichtigsten Werte des aktuellen Laufs.
const U := preload("res://scripts/core/ui_theme.gd")
const LevelProgress := preload("res://scripts/core/level_progress.gd")

## Zeichenfläche für die Laufzeitleiste innerhalb einer Container-Spalte.
class ProgressStrip extends Control:
	var info: Dictionary = {}
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		custom_minimum_size = Vector2(0, U.pad(18))

	func _process(delta: float) -> void:
		_t += delta
		if String(info.get("phase", "")) in ["wait", "boss"]:
			queue_redraw()

	func _draw() -> void:
		var s := size.y / 18.0
		LevelProgress.draw_track(self, Rect2(Vector2(0, 0), size), info, s * 1.4, _t)

static func build(box: VBoxContainer, app: Node, headline: String, headline_color: Color = U.ACCENT2) -> void:
	var g = app.game if app != null and app.is_in_game() else null
	_label(box, headline, U.font_bold(), 11, headline_color)
	if g == null:
		return
	var hud = app.hud
	var info: Dictionary = hud.progress_info() if hud != null and hud.has_method("progress_info") else {}
	var level_text: String = hud._level_text(true) if hud != null else "LEVEL %02d" % int(g.level_index)
	var data := Data.level(int(g.level_index))
	_label(box, level_text, U.font_display(), 22, U.TEXT)
	_label(box, String(data.get("name", "")), U.font_semi(), 15, U.ACCENT)
	if not info.is_empty():
		var strip := ProgressStrip.new()
		strip.info = info
		box.add_child(strip)
		var detail := LevelProgress.caption(info)
		var marks: Array = info.get("marks", [])
		if String(info.get("phase", "")) == "run" and not marks.is_empty():
			detail += "  ·  Abschnitt %d / %d" % [int(info.get("checkpoint", 0)) + 1, marks.size() + 1]
		_label(box, detail, U.font_semi(), 12, U.DIM)
	_rule(box)
	var p = g.player
	if p != null:
		var shield := "—"
		if p.shield_active():
			shield = "%d / %d" % [p.shield_hits, p.shield_max]
		var rows := [
			["Vital", "%d / %d" % [p.hp, p.max_hp], U.TEXT],
			["Schild", shield, U.ACCENT2 if p.shield_active() else U.DIM],
			["Nektar", _grouped(int(p.nectar)), U.ACCENT],
			["Punkte", _grouped(int(p.points)), U.TEXT],
			["Spielzeit", LevelProgress.clock(float(g.stats.get("time", 0.0))), U.TEXT],
			["Schwierigkeit", Loc.t(String(g.difficulty.get("name", "Normal"))), U.DIM],
		]
		for row in rows:
			_pair(box, String(row[0]), String(row[1]), row[2])

static func _label(box: Control, text: String, font: Font, px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", U.size(px))
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

static func _pair(box: Control, key: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.add_theme_font_override("font", U.font_regular())
	k.add_theme_font_size_override("font_size", U.size(13))
	k.add_theme_color_override("font_color", U.DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", U.font_bold())
	v.add_theme_font_size_override("font_size", U.size(14))
	v.add_theme_color_override("font_color", color)
	row.add_child(v)
	box.add_child(row)

static func _rule(box: Control) -> void:
	var line := ColorRect.new()
	line.color = Color(U.BORDER, 0.8)
	line.custom_minimum_size = Vector2(0, maxf(1.0, float(U.pad(1))))
	box.add_child(line)

static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return ("−" if value < 0 else "") + out
