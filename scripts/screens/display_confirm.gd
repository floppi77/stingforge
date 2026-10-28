extends "res://scripts/core/ui_screen.gd"
## Rückfrage nach einer Anzeige-Änderung: behalten oder zurück?
## Läuft 15 Sekunden, danach wird automatisch zurückgestellt.

var seconds := 15.0
var _done := false

func setup(args: Dictionary) -> void:
	seconds = float(args.get("seconds", 15))
	title_key = "set.confirm_title"
	subtitle_key = ""
	columns = 1
	hint_override = "Links/rechts wählt · Bestätigen behält die Anzeige · Zurück stellt sie wieder her."

func build_items() -> void:
	items = [
		{"kind": "action", "text": "set.confirm_keep", "id": "keep", "accent": true},
		{"kind": "action", "text": "set.confirm_revert", "id": "revert"},
	]

func _process(delta: float) -> void:
	if _done:
		return
	seconds -= delta
	# Countdown in der Fußzeile: dort ist Platz, der Titel bleibt kurz und passt
	footer_label.text = Loc.t("set.confirm_countdown_footer") % int(maxf(0.0, ceil(seconds)))
	footer_label.visible = true
	if seconds <= 0.0:
		_revert()
		return
	super._process(delta)

## Links/rechts wechselt zwischen den beiden Antworten, statt nichts zu tun.
func on_adjust(_index: int, dir: int) -> void:
	if items.is_empty():
		return
	_set_focus(1 if dir > 0 else 0)

func on_activate(index: int) -> void:
	if String(items[index].get("id", "")) == "keep":
		_done = true
		Audio.sfx("ui_ok", -8.0, 1.0, true)
		app.confirm_display()
	else:
		_revert()

func _revert() -> void:
	if _done:
		return
	_done = true
	Audio.sfx("ui_back", -8.0, 1.0, true)
	app.revert_display_now()

func do_back() -> void:
	_revert()
