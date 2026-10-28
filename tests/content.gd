extends Node
## Inhaltsprüfung: Daten, Assets, Ton, Abhängigkeiten.

var fails: Array = []
var checks := 0

func _ready() -> void:
	_check_evolutions()
	_check_upgrades()
	_check_enemies()
	_check_bosses()
	_check_levels()
	_check_assets()
	_check_audio()
	_check_locale()
	_scan_sources_for_keys()
	print("CONTENT: checks=%d fails=%d" % [checks, fails.size()])
	for f in fails:
		print("  FAIL " + f)
	if fails.is_empty():
		print("CONTENT_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)

func _check_evolutions() -> void:
	var evs: Array = Data.EVOLUTIONS
	ok(evs.size() >= 30, "mindestens 30 Evolutionen (ist %d)" % evs.size())
	var ids := {}
	var fams := {}
	for e in evs:
		var id := String(e.id)
		ok(not ids.has(id), "Evolution-ID doppelt: " + id)
		ids[id] = true
		fams[String(e.family)] = int(fams.get(String(e.family), 0)) + 1
		ok(String(e.get("desc", "")) != "", "Evolution ohne Beschreibung: " + id)
		ok(int(e.get("max", 1)) >= 1, "Evolution mit max<1: " + id)
		ok(e.has("effect"), "Evolution ohne Effekt: " + id)
	for f in fams.keys():
		ok(int(fams[f]) >= 5, "Familie %s hat nur %d Evolutionen" % [f, int(fams[f])])
	ok(fams.size() == 6, "genau sechs Familien (ist %d)" % fams.size())
	# Verweise gültig
	for e in evs:
		var id := String(e.id)
		for r in e.get("req", []):
			ok(ids.has(String(r)), "req von %s verweist auf unbekannte Evolution %s" % [id, str(r)])
		var syn := String(e.get("synergy", ""))
		ok(syn == "" or ids.has(syn), "Synergie von %s verweist auf unbekannte Evolution %s" % [id, syn])
		var w := String(e.get("weapon", ""))
		ok(w == "" or _upgrade_ids().has(w), "Waffe von %s unbekannt: %s" % [id, w])
	var bases := 0
	for e in evs:
		if bool(e.get("start_base", false)):
			bases += 1
	ok(bases == 3, "genau drei Grundtalente (ist %d)" % bases)

func _upgrade_ids() -> Dictionary:
	var d := {}
	for u in Data.UPGRADES:
		d[String(u.id)] = true
	return d

func _check_upgrades() -> void:
	ok(Data.UPGRADES.size() == 9, "neun Leisten-Einträge (ist %d)" % Data.UPGRADES.size())
	for u in Data.UPGRADES:
		var id := String(u.id)
		ok(int(u.get("max", 0)) >= 1, "Upgrade %s ohne max" % id)
		var costs: Array = u.get("costs", [])
		ok(costs.size() == int(u.get("max", 1)), "Upgrade %s: Kostenliste passt nicht zu max" % id)
		ok(Art.has("icon_" + String(u.get("icon", id))), "Upgrade-Icon fehlt: " + id)
	for u in Data.WEAPON_ORDER:
		var found := false
		for e in Data.UPGRADES:
			if String(e.id) == String(u):
				found = true
		ok(found, "WEAPON_ORDER nennt unbekanntes Upgrade " + str(u))

func _check_enemies() -> void:
	ok(Data.ENEMIES.size() >= 20, "mindestens 20 Gegnertypen (ist %d)" % Data.ENEMIES.size())
	for k in Data.ENEMIES.keys():
		var e: Dictionary = Data.ENEMIES[k]
		ok(String(e.get("sprite", "")) != "", "Gegner %s ohne Sprite" % k)
		ok(Art.has(String(e.get("sprite", ""))), "Gegner %s: Sprite %s fehlt im Manifest" % [k, String(e.get("sprite", ""))])
		ok(float(e.get("hp", 0)) > 0.0, "Gegner %s ohne HP" % k)
	_audit_code_coverage()
	for fm in Director.FORMATIONS.keys():
		var f: Dictionary = Director.FORMATIONS[fm]
		ok(Data.ENEMIES.has(String(f.get("enemy", ""))),
			"Formation %s nutzt unbekannten Gegner %s" % [str(fm), String(f.get("enemy", ""))])

func _check_bosses() -> void:
	ok(Data.bosses.size() == 10, "zehn Bosse (ist %d)" % Data.bosses.size())
	for k in Data.bosses.keys():
		var b: Dictionary = Data.bosses[k]
		var phases: Array = b.get("phases", [])
		ok(phases.size() >= 2, "Boss %s hat nur %d Phasen" % [k, phases.size()])
		ok(Art.has(String(b.get("sprite", ""))), "Boss %s: Sprite fehlt (%s)" % [k, String(b.get("sprite", ""))])
		for p in phases:
			ok(float(p.get("hp", 0)) > 0.0, "Boss %s: Phase ohne HP-Anteil" % k)
			var pats: Array = p.get("patterns", [])
			ok(pats.size() > 0, "Boss %s: Phase ohne Muster" % k)

func _audit_code_coverage() -> void:
	# Jedes Boss-Muster, jeder Bewegungsstil, jede Mechanik muss im Code existieren.
	var boss_src := FileAccess.get_file_as_string("res://scripts/game/boss.gd")
	var game_src := FileAccess.get_file_as_string("res://scripts/game/game.gd")
	var enemy_src := FileAccess.get_file_as_string("res://scripts/game/enemy.gd")
	var mech_kinds := {}
	for k in Director.HAZARDS.keys():
		mech_kinds[String(Director.HAZARDS[k].kind)] = true
	for m in mech_kinds.keys():
		ok(game_src.contains("\"%s\"" % m), "Mechanik-Auslöser ohne Umsetzung: " + m)
	var pat_names := {}
	for k in Data.bosses.keys():
		for ph in Data.bosses[k].get("phases", []):
			for pn in ph.get("patterns", []):
				pat_names[String(pn)] = true
			var mv := String(ph.get("move", ""))
			ok(boss_src.contains("\"%s\":" % mv), "Boss %s: Bewegungsstil ohne Umsetzung (%s)" % [str(k), mv])
	for pn in pat_names.keys():
		ok(boss_src.contains("\"%s\":" % pn), "Boss-Muster ohne Umsetzung: " + pn)
	var behaviors := {}
	for k in Data.ENEMIES.keys():
		var b := String(Data.ENEMIES[k].get("behavior", "straight"))
		behaviors[b] = true
	for b in behaviors.keys():
		ok(enemy_src.contains("\"%s\"" % b), "Gegnerverhalten ohne Umsetzung: " + b)

func _check_levels() -> void:
	ok(Data.levels.size() == 10, "zehn Level (ist %d)" % Data.levels.size())
	for i in range(10):
		var l: Dictionary = Data.levels[i]
		ok(String(l.get("name", "")) != "", "Level %d ohne Namen" % (i + 1))
		ok(String(l.get("boss", "")) != "", "Level %d ohne Boss" % (i + 1))
		ok(Data.bosses.has(String(l.get("boss", ""))), "Level %d: Boss %s unbekannt" % [i + 1, String(l.get("boss", ""))])
		var secs: Array = l.get("sections", [])
		ok(secs.size() >= 4, "Level %d hat nur %d Abschnitte" % [i + 1, secs.size()])
		ok(String(l.get("music", "")) != "", "Level %d ohne Musik" % (i + 1))
		ok(String(l.get("mechanic", "")) != "", "Level %d ohne Mechanik" % (i + 1))
		for s in secs:
			var pool: Array = s.get("pools", [])
			ok(pool.size() > 0, "Level %d: Abschnitt ohne Gegner-Pools" % (i + 1))
			for p in pool:
				for fm in p:
					ok(Director.FORMATIONS.has(String(fm)),
						"Level %d: unbekannte Formation %s" % [i + 1, String(fm)])

func _check_assets() -> void:
	for u in Data.WEAPON_ORDER:
		var icon := "icon_" + (String(u) if String(u) != "speed" else "speed")
		ok(Art.has(icon), "Icon fehlt: " + icon)
	for extra in ["icon_hp", "icon_nectar", "icon_shieldbar", "icon_autofire", "logo", "icon"]:
		ok(Art.has(extra), "UI-Sprite fehlt: " + extra)
	for s in ["bullet_base", "bullet_fan", "bullet_lightning", "bullet_plasma", "ebullet_needle", "ebullet_orb", "ebullet_spore", "explode", "spark", "ring", "pollen", "heart", "nectar", "blossom", "bomb", "drone", "bee"]:
		ok(Art.has(s), "Spiel-Sprite fehlt: " + s)
	for i in range(10):
		for layer in ["far", "mid", "near"]:
			var p := "res://assets/bg/l%02d_%s.png" % [i + 1, layer]
			ok(ResourceLoader.exists(p) or FileAccess.file_exists(p), "Hintergrund fehlt: " + p)

func _check_audio() -> void:
	for i in range(10):
		var p := "res://assets/audio/music/level%d.ogg" % (i + 1)
		ok(FileAccess.file_exists(p), "Musik fehlt: " + p)
	for m in ["menu", "boss", "ending", "level_clear"]:
		ok(FileAccess.file_exists("res://assets/audio/music/%s.ogg" % m), "Musik fehlt: " + m)
	var sfx := ["shot_base", "shot_fan", "shot_lightning", "shot_plasma", "hit", "explosion_small",
		"explosion_big", "player_hit", "shield_hit", "shield_break", "bomb", "pickup_nectar",
		"pickup_heart", "purchase", "deny", "ui_move", "ui_ok", "ui_back", "boss_warn",
		"phase_change", "boss_death", "level_clear", "game_over", "checkpoint", "low_hp_warn",
		"combo_ready"]
	for s in sfx:
		ok(FileAccess.file_exists("res://assets/audio/sfx/%s.wav" % s), "Effekt fehlt: " + s)

func _scan_sources_for_keys() -> void:
	# Jeder als Anzeigetext verwendete Schlüssel muss übersetzt sein.
	# Geprüft werden Loc.t("…") sowie die Textfelder der Bildschirmelemente.
	var dirs := ["res://scripts/screens/", "res://scripts/game/", "res://scripts/core/",
		"res://scripts/autoload/"]
	var pat_loc := RegEx.new()
	pat_loc.compile("Loc\\.t\\(\\s*\"([a-z][a-z_0-9]*\\.[a-z_0-9.]*)\"")
	var pat_field := RegEx.new()
	pat_field.compile("\"(?:text|title_key|subtitle_key|message|value_text|hint)\"\\s*:\\s*\"([a-z][a-z_0-9]*\\.[a-z_0-9.]*)\"")
	var checked := {}
	for d in dirs:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		for f in dir.get_files():
			if not f.ends_with(".gd"):
				continue
			if f == "loc.gd":
				continue
			var src := FileAccess.get_file_as_string(d + f)
			for re: RegEx in [pat_loc, pat_field]:
				for m: RegExMatch in re.search_all(src):
					var key: String = String(m.get_string(1))
					if key.ends_with(".") or checked.has(key):
						continue
					checked[key] = true
					var t := String(Loc.t(key))
					ok(t != key, "Textschlüssel ohne Übersetzung: " + key + " (" + f + ")")

func _check_locale() -> void:
	var keys := ["game.title", "menu.new_campaign", "menu.continue", "menu.training",
		"menu.boss_rush", "menu.settings", "menu.credits", "menu.quit",
		"menu.resume", "menu.restart_checkpoint", "menu.build", "menu.back_main",
		"cp.reached", "game.rush_next", "story.intro.1", "story.intro.2", "story.intro.3",
		"story.end.1", "story.end.2", "game.level_complete", "game.game_over"]
	for k in keys:
		var t := String(Loc.t(k))
		ok(t != "" and t != k, "Übersetzung fehlt: " + k)
	for i in range(1, 11):
		for pat in ["level.%d", "story.level.%d"]:
			var k: String = String(pat) % i
			var t := String(Loc.t(k))
			ok(t != "" and t != k, "Übersetzung fehlt: " + k)
	for k in ["evo.title", "evo.subtitle", "evo.reroll", "evo.reroll_used", "evo.new_unlock",
			"evo.profile_only", "evo.active_campaign", "evo.weapon_dependent", "evo.synergy",
			"evo.start_talent", "evo.downside"]:
		var t := String(Loc.t(k))
		ok(t != "" and t != k, "Übersetzung fehlt: " + k)
	for e in Data.EVOLUTIONS:
		ok(String(e.get("name", "")) != "" and not String(e.get("name", "")).begins_with("evo."),
			"Evolution ohne lesbaren Namen: " + String(e.id))
