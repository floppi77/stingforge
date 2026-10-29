extends "res://scripts/core/ui_screen.gd"
## Namenseingabe für einen neuen Highscore im Arcade-Stil. Tastatur: tippen,
## Rücktaste, Eingabe. Gamepad: hoch/runter wählt das Zeichen an der Schreibmarke,
## links/rechts bewegt sie, B löscht, A bestätigt.

const MAX_LEN := 10
const CHARSET := " ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ0123456789-.!"

var run_id := ""
var run_mode := "campaign"
var rank := 0
var score := 0
var completed := false
var letters: Array[String] = []
var cursor := 0
var _field: Control
var _t := 0.0

func setup(args: Dictionary) -> void:
	run_id = String(args.get("run_id", ""))
	run_mode = String(args.get("mode", "campaign"))
	rank = int(args.get("rank", 0))
	score = int(args.get("score", 0))
	completed = bool(args.get("completed", false))
	title_key = "NEUER HIGHSCORE!"
	subtitle_key = ""
	back_enabled = false
	var start := String(Save.profile.get("last_pilot", "Yuri")).to_upper().left(MAX_LEN)
	for ch in start:
		letters.append(ch)
	cursor = mini(letters.size(), MAX_LEN - 1)

func build_items() -> void:
	var mode_label := "Boss-Rush" if run_mode == "rush" else "Run"
	items = [
		{"kind": "label", "text": Loc.tx("Platz %d · %s · %s Punkte%s") % [rank, mode_label, _grouped(score),
			"  · durchgespielt" if completed else ""], "size": 18, "color": UiTheme.ACCENT},
		{"kind": "label", "text": Loc.tx("Trage deinen Namen ein (bis zu %d Zeichen).") % MAX_LEN, "size": 14},
		{"kind": "sep"},
		{"kind": "action", "text": "Name übernehmen", "id": "ok", "accent": true},
	]

func _ready() -> void:
	super._ready()
	_field = Control.new()
	_field.custom_minimum_size = Vector2(0, UiTheme.pad(54))
	_field.draw.connect(_draw_field)
	list_box.add_child(_field)
	list_box.move_child(_field, 2)
	hint_label.text = "Tastatur: tippen · Rücktaste löscht · Eingabe bestätigt    Gamepad: ↑↓ Zeichen · ←→ Stelle · B löscht · A bestätigt"
	hint_label.visible = true

func _name() -> String:
	return "".join(letters).strip_edges()

func _draw_field() -> void:
	var cell := float(UiTheme.pad(26))
	var h := float(UiTheme.pad(40))
	var font := UiTheme.font_display()
	var fs := UiTheme.size(26)
	for i in range(MAX_LEN):
		var r := Rect2(Vector2(i * (cell + UiTheme.pad(4)), 0), Vector2(cell, h))
		var focus_here := i == cursor
		_field.draw_style_box(UiTheme.framed("slot_sel" if focus_here else "slot", 4, 0), r)
		if i < letters.size():
			var ch := letters[i]
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_field.draw_string(font, Vector2(r.position.x + (cell - w) * 0.5, r.position.y + h * 0.5 + fs * 0.27),
				ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.ACCENT if focus_here else UiTheme.TEXT)
		if focus_here and int(_t * 3.0) % 2 == 0:
			_field.draw_rect(Rect2(r.position.x + 6, r.end.y - 8, cell - 12, 3), UiTheme.ACCENT)

func _process(delta: float) -> void:
	_t += delta
	if _field != null:
		_field.queue_redraw()
	if Bindings.consume("ui_up"):
		_cycle(1)
	elif Bindings.consume("ui_down"):
		_cycle(-1)
	if Bindings.consume("ui_left"):
		cursor = maxi(0, cursor - 1)
		Audio.sfx("ui_move", -12.0, 1.0, true)
	elif Bindings.consume("ui_right"):
		cursor = mini(mini(letters.size(), MAX_LEN - 1), cursor + 1)
		Audio.sfx("ui_move", -12.0, 1.0, true)
	if Bindings.consume("ui_cancel"):
		_backspace()
	if Bindings.consume("ui_accept") or Bindings.consume("upgrade_buy"):
		_confirm()

func _cycle(dir: int) -> void:
	while letters.size() <= cursor:
		letters.append(" ")
	var idx := CHARSET.find(letters[cursor])
	idx = (maxi(0, idx) + dir + CHARSET.length()) % CHARSET.length()
	letters[cursor] = CHARSET[idx]
	Audio.sfx("ui_move", -12.0, 1.1, true)

func _backspace() -> void:
	if letters.is_empty():
		return
	var at := mini(cursor, letters.size() - 1)
	if cursor >= letters.size() or letters[at] == " ":
		at = letters.size() - 1
	letters.remove_at(at)
	cursor = clampi(at, 0, maxi(0, letters.size()))
	Audio.sfx("ui_back", -10.0, 1.0, true)

## Echte Tastatureingabe: Buchstaben, Ziffern, Leer- und Satzzeichen.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_BACKSPACE:
		_backspace()
		get_viewport().set_input_as_handled()
		return
	var ch := String.chr(key.unicode).to_upper() if key.unicode > 0 else ""
	if ch != "" and CHARSET.contains(ch):
		if cursor < letters.size():
			letters[cursor] = ch
		elif letters.size() < MAX_LEN:
			letters.append(ch)
		cursor = mini(cursor + 1, MAX_LEN - 1)
		Audio.sfx("ui_move", -12.0, 1.2, true)
		get_viewport().set_input_as_handled()
		# Getippte Buchstaben (W/A/S/D, Leertaste …) dürfen nicht zugleich als
		# Menüsteuerung oder Bestätigung wirken.
		Bindings.block_until_release(["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept",
			"ui_cancel", "upgrade_buy", "menu", "fire", "autofire", "upgrade_prev", "upgrade_next"])

func on_activate(_index: int) -> void:
	_confirm()

func _confirm() -> void:
	var name := _name()
	if name.is_empty():
		Audio.sfx("deny", -8.0, 1.0, true)
		return
	Save.rename_highscore(run_id, name)
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	app.pop_screen()
	app.push_screen("res://scripts/screens/highscore_screen.gd", {"mode": run_mode})

func do_back() -> void:
	_backspace()

static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += Loc.group_sep()
		out += digits[i]
	return out
