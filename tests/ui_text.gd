extends Node
## Prüft die Darstellungstexte aller Bildschirme: keine rohen Schlüssel,
## keine ungefüllten Platzhalter.

var fails: Array = []
var checks := 0
var _re_key := RegEx.new()
var _re_ph := RegEx.new()

func _ready() -> void:
	_re_key.compile("^[a-z][a-z_0-9]*\\.[a-z_0-9.]+$")
	_re_ph.compile("%[dsf%]")
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	# Ausgangslage: laufende Kampagne mit Evolutionsangebot
	Save.new_campaign("normal", 11111)
	Save.campaign.start_talent = "pierce1"
	Save.campaign.level = 3
	Save.campaign.rewarded_levels = [1, 2]
	Save.campaign.pending = {}
	Save.profile.boss_rush_unlocked = true

	await _screen(app, "res://scripts/screens/main_menu.gd", {})
	await _screen(app, "res://scripts/screens/credits_screen.gd", {})
	await _screen(app, "res://scripts/screens/highscore_screen.gd", {"mode": "campaign", "difficulty": "all"})
	await _screen(app, "res://scripts/screens/difficulty_screen.gd", {})
	await _screen(app, "res://scripts/screens/start_talent_screen.gd", {})
	await _screen(app, "res://scripts/screens/build_overview_screen.gd", {})
	await _screen(app, "res://scripts/screens/confirm_screen.gd", {
		"title": "menu.quit", "message": "menu.quit_warn"})
	await _screen(app, "res://scripts/screens/story_screen.gd", {"level": 3})
	var st := {
		"level": 3, "score": 12000, "kills": 40, "hits": 12, "time": 210.0,
		"accuracy": 0.72, "rank": "B", "rank_text": "Solide", "difficulty": "normal",
		"seed": 11111, "hp_left": 2,
	}
	Save.campaign.level_stats["3"] = st
	await _screen(app, "res://scripts/screens/level_result_screen.gd",
		{"stats": st, "level": 3, "training": false})
	await _screen(app, "res://scripts/screens/ending_screen.gd", {})
	# Evolution: Angebot erzeugen
	Save.campaign.pending = {"level": 3, "offers": app._roll_offers(3), "reroll_used": false}
	await _screen(app, "res://scripts/screens/evolution_screen.gd", {})
	# Einstellungen: alle sechs Kategorien
	for tab in range(6):
		Save.set_g("ui.last_tab", tab)
		await _screen(app, "res://scripts/screens/settings_screen.gd", {"from": "main", "tab": tab})
	print("UI: checks=%d fails=%d" % [checks, fails.size()])
	for f in fails:
		print("  FAIL " + f)
	if fails.is_empty():
		print("UI_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _screen(app, path: String, args: Dictionary) -> void:
	app.clear_screens()
	var s = app.push_screen(path, args)
	await get_tree().process_frame
	await get_tree().process_frame
	if s == null or not is_instance_valid(s):
		fails.append("Bildschirm lädt nicht: " + path)
		return
	_scan(s, path)
	await get_tree().process_frame

func _scan(s, path: String) -> void:
	var items: Array = s.items if "items" in s else []
	for it in items:
		# "text" ist ein Schlüssel und wird beim Aufbau übersetzt.
		if it.has("text"):
			_check_placeholders(String(Loc.t(String(it["text"]))), path)
		if it.has("hint"):
			_check_placeholders(String(Loc.t(String(it["hint"]))), path)
		for field in ["value_text", "message", "title"]:
			if it.has(field):
				_check_text(String(it[field]), path)
		for line in it.get("lines", []):
			_check_placeholders(String(Loc.t(String(line.get("text", "")))), path)
	if "title_key" in s:
		_check_placeholders(String(Loc.t(String(s.title_key))), path)
	if "subtitle_key" in s and String(s.subtitle_key) != "":
		_check_placeholders(String(Loc.t(String(s.subtitle_key))), path)

func _check_placeholders(t: String, path: String) -> void:
	checks += 1
	if t == "":
		return
	if _re_ph.search(t) != null:
		fails.append("%s: ungefüllter Platzhalter: %s" % [path.get_file(), t])

func _check_text(t: String, path: String) -> void:
	checks += 1
	if t == "":
		return
	if _re_key.search(t) != null:
		fails.append("%s: roher Textschlüssel angezeigt: %s" % [path.get_file(), t])
	if _re_ph.search(t) != null:
		fails.append("%s: ungefüllter Platzhalter: %s" % [path.get_file(), t])
