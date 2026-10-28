extends "res://scripts/core/ui_screen.gd"

var message := ""
var on_yes: Callable = Callable()
var on_no: Callable = Callable()
var yes_label := "menu.yes"
var no_label := "menu.no"

func setup(args: Dictionary) -> void:
	title_key = String(args.get("title", "menu.confirm"))
	message = String(args.get("message", ""))
	on_yes = args.get("on_yes", Callable())
	on_no = args.get("on_no", Callable())
	yes_label = String(args.get("yes", "menu.yes"))
	no_label = String(args.get("no", "menu.no"))
	subtitle_key = message
	overlay_in_game = true

func build_items() -> void:
	items = [
		{"kind": "action", "text": yes_label, "id": "yes", "accent": true},
		{"kind": "action", "text": no_label, "id": "no"},
	]

func on_activate(index: int) -> void:
	if String(items[index].get("id", "")) == "yes":
		Audio.sfx("ui_ok", -6.0, 1.0, true)
		app.pop_screen()
		if on_yes.is_valid():
			on_yes.call()
	else:
		Audio.sfx("ui_back", -6.0, 1.0, true)
		app.pop_screen()
		if on_no.is_valid():
			on_no.call()

## Links/rechts wechselt zwischen Ja und Nein – wie es der Hinweis verspricht.
func on_adjust(_index: int, dir: int) -> void:
	if items.size() < 2:
		return
	_set_focus(1 if dir > 0 else 0)

func do_back() -> void:
	app.pop_screen()
