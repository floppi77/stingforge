extends "res://scripts/core/ui_screen.gd"

const LevelProgress := preload("res://scripts/core/level_progress.gd")

var level := 1
var on_done: Callable = Callable()
var timer := 6.5
var done := false

func setup(args: Dictionary) -> void:
	level = int(args.get("level", 1))
	on_done = args.get("on_done", Callable())
	title_key = "level." + str(level)
	# Ab Level 2 steht der Leveltext im Körper; als Untertitel erschien er doppelt.
	subtitle_key = "story.level." + str(level) if level == 1 else ""
	show_background = true

func build_items() -> void:
	items = [{"kind": "action", "text": "game.skip", "id": "skip"}]
	hint_override = ""

func _ready() -> void:
	super._ready()
	Audio.play_music("menu", 0.4)
	# Ein paar Zeilen Erzähltext als Karten
	var intro_lines: Array = []
	if level == 1:
		intro_lines = [Loc.t("story.intro.1"), Loc.t("story.intro.2"), Loc.t("story.intro.3")]
	else:
		intro_lines = [Loc.t("story.level." + str(level))]
	var list: Array = []
	list.append({"kind": "label", "text": "LEVEL %d / %d" % [level, Data.levels.size()], "size": 16,
		"color": UiTheme.ACCENT2})
	for line in intro_lines:
		list.append({"kind": "label", "text": line, "size": 20, "color": UiTheme.TEXT})
	var flight := _flight_seconds()
	if flight > 0.0:
		list.append({"kind": "label", "text": Loc.tx("Flugzeit bis zum Boss: etwa %s") % LevelProgress.clock(flight),
			"size": 14, "color": UiTheme.DIM})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "game.continue", "id": "skip"})
	items = list
	refresh()

## Geplante Abschnittsdauer plus Einflug; dieselbe Grundlage wie die HUD-Leiste.
func _flight_seconds() -> float:
	var total := 0.0
	for sec in Data.level(level).get("sections", []):
		total += float(sec.get("dur", 0.0))
	return total + 2.2 if total > 0.0 else 0.0

func _process(delta: float) -> void:
	if done:
		return
	timer -= delta
	if timer <= 0.0:
		_finish()
		return
	super._process(delta)

func on_activate(_index: int) -> void:
	_finish()

func do_back() -> void:
	_finish()

func _finish() -> void:
	if done:
		return
	done = true
	if on_done.is_valid():
		on_done.call()
