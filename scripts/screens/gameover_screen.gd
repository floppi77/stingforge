extends "res://scripts/core/ui_screen.gd"

const UiRunStatus := preload("res://scripts/core/ui_run_status.gd")
## Game Over: Weitermachen (taktische Upgrades werden zurückgesetzt) oder den
## Run beenden. Nach dem dritten Game Over gibt es kein Weiter mehr.

var attempts_left := 0
var deaths := 0
var max_deaths := 3

func setup(args: Dictionary) -> void:
	list_width = 520
	deaths = int(args.get("deaths", 1))
	max_deaths = int(args.get("max_deaths", 3))
	attempts_left = maxi(0, max_deaths - deaths)
	title_key = "game.game_over"
	subtitle_key = ""
	prompt_context = "gameover"
	hint_override = ""
	overlay_in_game = true
	veil_tint = Color(0.07, 0.015, 0.025)
	side_builder = func(box: VBoxContainer) -> void:
		UiRunStatus.build(box, app, "LAUF BIS HIERHER", UiTheme.DANGER)

func build_items() -> void:
	if title_label != null:
		title_label.add_theme_color_override("font_color", UiTheme.DANGER)
	var list: Array = []
	var total := maxi(1, max_deaths)
	list.append({"kind": "label", "text": Loc.tx("Game Over %d von %d") % [mini(deaths, total), total],
		"size": 18, "color": UiTheme.ACCENT})
	if attempts_left > 0:
		list.append({"kind": "label",
			"text": "Beim Weitermachen starten die taktischen Upgrades am unteren Rand neu.",
			"size": 15})
		list.append({"kind": "label",
			"text": "Gekaufte Werkstatt-Verbesserungen und Evolutionen bleiben.",
			"size": 15, "color": UiTheme.DIM})
		list.append({"kind": "sep"})
		list.append({"kind": "action", "text": "Weiter am Kontrollpunkt", "id": "continue",
			"accent": true, "value_text": Loc.tx("noch %d") % attempts_left})
	else:
		list.append({"kind": "label", "text": "Kein Weiter mehr – der Run ist vorbei.",
			"size": 15, "color": UiTheme.DANGER})
		list.append({"kind": "label",
			"text": "Die im Profil gesammelten Evolutionen bleiben erhalten.",
			"size": 15, "color": UiTheme.DIM})
		list.append({"kind": "sep"})
	list.append({"kind": "action",
		"text": "Run beenden" if attempts_left > 0 else "Zum Hauptmenü", "id": "quit_run"})
	items = list

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	match String(it.get("id", "")):
		"continue":
			if attempts_left <= 0:
				Audio.sfx("ui_back", -8.0)
				return
			app.continue_after_death()
		"quit_run":
			app.abandon_run()

## Kein Zurück: Esc würde sonst versehentlich einen Versuch verbrauchen.
func do_back() -> void:
	Audio.sfx("ui_back", -8.0)
