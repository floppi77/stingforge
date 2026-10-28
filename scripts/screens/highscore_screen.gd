extends "res://scripts/core/ui_screen.gd"
## Lokale echte Run-Ranglisten. Filter sind choices, niemals Werkstattkäufe.
## Der Screen liest nur; Erfassung/Run-Ende gehört dem koordinierten App-Fluss.

const MODES := ["campaign", "rush"]
const DIFFICULTIES := ["all", "relaxed", "normal", "expert"]
const DIFFICULTY_LABELS := {"all": "Alle", "relaxed": "Entspannt", "normal": "Normal", "expert": "Experte"}

var selected_mode := "campaign"
var difficulty_filter := "all"
var row_limit := 10
var scores: Array = []

func setup(args: Dictionary) -> void:
	list_width = 600
	if args.get("mode", "campaign") in MODES:
		selected_mode = args.get("mode", "campaign")
	if args.get("difficulty", "all") in DIFFICULTIES:
		difficulty_filter = args.get("difficulty", "all")
	row_limit = 20 if args.get("limit", 10) == 20 else 10

func _ready() -> void:
	title_key = "Highscores"
	subtitle_override = "Lokale Run-Ranglisten · Kampagne und Boss Rush getrennt · Namen nach jedem Lauf eintragen"
	prompt_context = "menu"
	super._ready()

func build_items() -> void:
	scores = Save.get_highscores(selected_mode, difficulty_filter, row_limit)
	var mode_label := "Kampagne" if selected_mode == "campaign" else "Boss Rush"
	header_note = "%s  /  %s  /  Top %d" % [mode_label, DIFFICULTY_LABELS[difficulty_filter], row_limit]
	hint_override = "Links/rechts oder Bestätigen ändert den gewählten Filter. Hoch/runter scrollt durch die Liste."
	footer_text = "Gesamtpunkte = verdiente Punkte, unabhängig von Werkstatt-Ausgaben. * = aus altem Spielstand geschätzt."
	items = [
		{"kind": "choice", "id": "mode", "text": "Modus", "value_text": "‹  " + mode_label + "  ›", "compact": true},
		{"kind": "choice", "id": "difficulty", "text": "Schwierigkeit", "value_text": "‹  " + DIFFICULTY_LABELS[difficulty_filter] + "  ›", "compact": true},
		{"kind": "choice", "id": "limit", "text": "Einträge", "value_text": "‹  Top %d  ›" % row_limit, "compact": true},
		{"kind": "sep"},
	]
	if scores.is_empty():
		items.append({"kind": "label", "id": "empty", "text": "Noch keine abgeschlossenen oder beendeten Runs für diesen Filter.", "size": 15})
		if not Save.profile.get("best", {}).is_empty():
			items.append({"kind": "label", "text": "Frühere Levelbestwerte bleiben erhalten; sie sind keine Run-Gesamtpunkte.", "size": 13})
	else:
		for i in range(scores.size()):
			var score: Dictionary = scores[i]
			var status := "Sieg" if bool(score.completed) else "Beendet"
			var estimate := " *" if bool(score.get("legacy_score_estimate", false)) else ""
			items.append({"kind": "action", "id": "score", "score_index": i, "compact": true,
				"text": "%02d  %s · %s · %s L%02d%s" % [i + 1, score.pilot,
					DIFFICULTY_LABELS[score.difficulty], status, int(score.level), estimate],
				"value_text": _points_text(int(score.score)), "accent": i == 0})
	items.append({"kind": "sep"})
	items.append({"kind": "action", "id": "back", "text": "menu.back", "compact": true})

func _points_text(points: int) -> String:
	var text := str(points)
	var at := text.length() - 3
	while at > 0:
		text = text.insert(at, ".")
		at -= 3
	return text

func _refresh_prompts() -> void:
	super._refresh_prompts()
	prompt_bar.add_child(UiPrompts.make_hint("ui_right", "Filter ändern", true))

func on_adjust(index: int, dir: int) -> void:
	if index < 0 or index >= items.size() or dir == 0:
		return
	var step := 1 if dir > 0 else -1
	match String(items[index].get("id", "")):
		"mode":
			selected_mode = MODES[posmod(MODES.find(selected_mode) + step, MODES.size())]
		"difficulty":
			difficulty_filter = DIFFICULTIES[posmod(DIFFICULTIES.find(difficulty_filter) + step, DIFFICULTIES.size())]
		"limit":
			row_limit = 20 if row_limit == 10 else 10
		_:
			return
	Audio.sfx("ui_move", -10.0, 1.0, true)
	build_items()
	refresh()

func on_activate(index: int) -> void:
	if index >= 0 and index < items.size() and items[index].get("id", "") == "back":
		do_back()

func on_return() -> void:
	build_items()
	refresh()

func do_back() -> void:
	if app != null:
		app.pop_screen()
	else:
		closed.emit(null)
