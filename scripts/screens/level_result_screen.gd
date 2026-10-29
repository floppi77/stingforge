extends "res://scripts/core/ui_screen.gd"

const UiRunStatus := preload("res://scripts/core/ui_run_status.gd")

var stats: Dictionary = {}
var level := 1
var training := false
var new_unlock := false
var chosen := ""
## Durch die Wahl entstandene Verschmelzungen [[a, b], …] und die davon neu entdeckten Schlüssel.
var fusions: Array = []
var fusions_new: Array = []

func setup(args: Dictionary) -> void:
	stats = args.get("stats", {})
	level = int(args.get("level", stats.get("level", 1)))
	training = bool(args.get("training", false))
	new_unlock = bool(args.get("new_unlock", false))
	chosen = String(args.get("chosen", ""))
	fusions = args.get("fusions", [])
	fusions_new = args.get("fusions_new", [])
	title_key = "game.level_complete"
	subtitle_key = ""

func build_items() -> void:
	side_builder = _build_summary
	var list: Array = []
	list.append({"kind": "label", "text": Loc.t("level." + str(level)), "size": 26, "color": UiTheme.ACCENT})
	var rank := String(stats.get("rank", "C"))
	list.append({"kind": "label", "text": Loc.tx("Wertung: %s – %s") % [rank, String(stats.get("rank_text", ""))],
		"size": 22, "color": _rank_color(rank)})
	list.append({"kind": "label", "text": Loc.tx("Schwierigkeit: %s   Saatwert: %d") % [
		Loc.t(String(Data.DIFFICULTY[String(stats.get("difficulty", "normal"))].name)),
		int(stats.get("seed", 0))], "size": 15, "color": UiTheme.DIM})
	if chosen != "":
		var e := Data.evo(chosen)
		list.append({"kind": "sep"})
		var master_txt := Loc.tx("Meisterevolution: %s") if Data.is_master(chosen) else Loc.tx("Neue Evolution: %s")
		list.append({"kind": "label", "text": master_txt % Loc.tx(String(e.get("name", chosen))),
			"size": 18, "color": UiTheme.ACCENT if Data.is_master(chosen) else UiTheme.family_color(String(e.get("family", "sting")))})
		if Data.is_master(chosen):
			list.append({"kind": "label", "text": Loc.tx(String(e.get("desc", ""))), "size": 14, "color": UiTheme.TEXT})
		if new_unlock:
			list.append({"kind": "label", "text": Loc.t("evo.new_unlock"), "size": 14, "color": UiTheme.OK})
		for pair in fusions:
			var key := Data.fusion_key(String(pair[0]), String(pair[1]))
			list.append({"kind": "label", "text": Loc.tx("Verschmelzung: %s – beide Evolutionen werden stärker.") % Data.fusion_name(String(pair[0]), String(pair[1])),
				"size": 16, "color": UiTheme.ACCENT2})
			if fusions_new.has(key):
				list.append({"kind": "label", "text": "VERSCHMELZUNG ENTDECKT – im Hauptmenü unter „Verschmelzungen“", "size": 13, "color": UiTheme.OK})
	if training:
		list.append({"kind": "sep"})
		list.append({"kind": "label", "text": "game.training_note", "size": 15, "color": UiTheme.DIM})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "game.continue", "id": "next", "accent": true})
	items = list

static func _rank_color(rank: String) -> Color:
	match rank:
		"S": return UiTheme.ACCENT
		"A": return UiTheme.ACCENT2
		"B": return UiTheme.TEXT
	return UiTheme.DIM

## Rechte Spalte: große Wertung und die Kennzahlen des Levels.
func _build_summary(box: VBoxContainer) -> void:
	var rank := String(stats.get("rank", "C"))
	var head := Label.new()
	head.text = "WERTUNG"
	head.add_theme_font_override("font", UiTheme.font_bold())
	head.add_theme_font_size_override("font_size", UiTheme.size(11))
	head.add_theme_color_override("font_color", UiTheme.ACCENT2)
	box.add_child(head)
	var big := Label.new()
	big.text = rank
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_override("font", UiTheme.font_display())
	big.add_theme_font_size_override("font_size", UiTheme.size(84))
	big.add_theme_color_override("font_color", _rank_color(rank))
	big.add_theme_color_override("font_shadow_color", Color("#1a0d06"))
	big.add_theme_constant_override("shadow_offset_x", UiTheme.pad(3))
	big.add_theme_constant_override("shadow_offset_y", UiTheme.pad(3))
	box.add_child(big)
	var t := float(stats.get("time", 0.0))
	for row in [
		[Loc.t("game.score"), UiRunStatus._grouped(int(stats.get("score", 0))), UiTheme.ACCENT],
		["Abschüsse", UiRunStatus._grouped(int(stats.get("kills", 0))), UiTheme.TEXT],
		[Loc.t("game.hits_taken"), str(int(stats.get("hits", 0))), UiTheme.TEXT],
		[Loc.t("game.time"), "%d:%02d" % [int(t) / 60, int(t) % 60], UiTheme.TEXT],
	]:
		UiRunStatus._pair(box, String(row[0]), String(row[1]), row[2])
	# Gewählte Evolution bzw. neu entstandene Verschmelzung als Hilfsgrafik.
	var show := ""
	if not fusions.is_empty():
		show = Data.fusion_key(String(fusions[0][0]), String(fusions[0][1]))
	elif chosen != "":
		show = chosen
	if show != "":
		var ill := EvoIllustration.new()
		ill.custom_minimum_size = Vector2(0, UiTheme.pad(64))
		ill.name = "Illustration"
		ill.show_evo(show)
		box.add_child(ill)

func on_activate(_index: int) -> void:
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	if training:
		app.menu_main()
	else:
		app.advance_after_level(level)

func do_back() -> void:
	on_activate(0)
