extends Node
## R8: Schwierigkeitsgrade unterscheiden sich spürbar, Boss-Rush nur mit Bossen des
## laufenden Runs, kein Training mehr, Sprachwahl Deutsch/Englisch mit vollständiger
## englischer Fassung (sichtbare Texte, Spieldaten, Sprachclips).

const DE_HINT := "[äöüÄÖÜß]|\\b(der|die|das|und|mit|nicht|eine?|für|auf|Stufe|Leben|Blütenstaub|Werkstatt|Zurück|Weiter|Einstellungen|Spiel|Gegner|Treffer|Biene|Punkte|Schild|Bombe|Drohne|Waffe|wählen|Bestätigen|Taste|Steuerung|Lautstärke|Kampagne|Verschmelzung\\w*|Schwierigkeit)\\b"

var app: Node
var fails: Array[String] = []
var _de := RegEx.new()
var _seen: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	_de.compile(DE_HINT)
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	await _difficulty()
	await _rush_and_training()
	await _german_stays_german()
	await _english()
	Loc.set_language("de")
	for f in fails:
		print("R8_FEHLER: " + f)
	print("R8_OK" if fails.is_empty() else "R8_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

# ------------------------------------------------------------------ Schwierigkeit
func _difficulty() -> void:
	var rates := {}
	var counts := {}
	var speeds := {}
	var regen := {}
	for d in ["relaxed", "normal", "expert"]:
		Save.new_campaign(d, 8080)
		var g := Game.new()
		g.level_index = 1
		g.difficulty = Data.DIFFICULTY[d]
		g.bullets = BulletField.new()
		g.add_child(g.bullets)
		var n := 0
		for i in range(100):
			g.bullets.enemy_bullets.clear()
			g.spawn_enemy_bullet(Vector2(800, 270), Vector2(-200, 0), 1, "ebullet_orb")
			n += g.bullets.enemy_count()
			if g.bullets.enemy_count() > 0:
				speeds[d] = absf((g.bullets.enemy_bullets[0].v as Vector2).x)
		counts[d] = n
		var boss := Boss.new()
		boss.level_index = 1
		g.add_child(boss)
		rates[d] = boss._rate()
		var p := Player.new()
		p.difficulty = Data.DIFFICULTY[d]
		regen[d] = 1.0 / float(Data.DIFFICULTY[d].shield_regen)
		p.free()
		g.free()
	_ok(counts.relaxed < counts.normal and counts.normal < counts.expert,
		"Feindgeschosse je Stufe: %d / %d / %d von 100" % [counts.relaxed, counts.normal, counts.expert])
	_ok(speeds.relaxed < speeds.normal and speeds.normal < speeds.expert,
		"Geschosstempo je Stufe (auch Bosse): %.0f / %.0f / %.0f" % [speeds.relaxed, speeds.normal, speeds.expert])
	_ok(rates.relaxed > rates.normal and rates.normal > rates.expert,
		"Boss-Angriffstakt je Stufe: %.2f / %.2f / %.2f" % [rates.relaxed, rates.normal, rates.expert])
	_ok(regen.relaxed < regen.normal and regen.normal < regen.expert, "Schildladezeit je Stufe unterschiedlich")
	# Trefferschaden: Entspannt verzeiht, Experte kostet manchmal doppelt.
	var lost := {}
	for d in ["relaxed", "normal", "expert"]:
		var pl := Player.new()
		pl.difficulty = Data.DIFFICULTY[d]
		pl.alive = true
		pl.max_hp = 99
		pl.hp = 99
		for i in range(20):
			pl.iframes = 0.0
			pl.take_damage(1)
		lost[d] = 99 - pl.hp
		pl.free()
	_ok(lost.relaxed < lost.normal and lost.normal < lost.expert,
		"Verlorene Leben nach 20 Treffern: %d / %d / %d" % [lost.relaxed, lost.normal, lost.expert])

# ------------------------------------------------------------------ Boss-Rush / Training
func _rush_and_training() -> void:
	_ok(not ResourceLoader.exists("res://scripts/screens/training_screen.gd") and not app.has_method("start_training"),
		"Training ist entfernt")
	app.menu_main()
	await _wait(0.3)
	var ids: Array = []
	for it in app.screens[-1].items:
		ids.append(String(it.get("id", "")))
	_ok(not ids.has("training") and ids.has("rush") and ids.has("language"), "Hauptmenü: kein Training, Boss-Rush und Sprachwahl")
	Save.new_campaign("normal", 8181)
	Save.campaign.level_stats = {"1": {}, "2": {}, "3": {}}
	app.start_boss_rush("normal")
	await _wait(0.4)
	_ok(app.game != null and app.game.boss_sequence == ["rose_beetle", "giant_larva", "pike_beast"],
		"Boss-Rush nur mit den drei besiegten Bossen des Runs")
	app.menu_main()
	await _wait(0.3)
	_ok(Save.active_campaign and Save.campaign.level_stats.size() == 3, "Run bleibt nach Boss-Rush erhalten")
	Save.active_campaign = false
	Save.campaign = {}
	app.start_boss_rush("normal")
	await _wait(0.2)
	_ok(app.mode != "rush", "Ohne laufenden Run startet kein Boss-Rush")
	app.menu_main()
	await _wait(0.3)

## Deutsch ist Quellsprache: Labels dürfen nie auf die englische Übersetzung zurückfallen.
func _german_stays_german() -> void:
	Loc.set_language("de")
	app.menu_main()
	await _wait(0.2)
	var l := Label.new()
	l.text = "Fortsetzen"
	app.screens[-1].add_child(l)
	await get_tree().process_frame
	_ok(l.tr(l.text) == "Fortsetzen", "Deutsch zeigt deutsche Texte (kein Rückfall auf Englisch)")
	l.queue_free()

# ------------------------------------------------------------------ Englisch
func _english() -> void:
	var menu = app.screens[-1]
	menu.choose_language("en")
	await _wait(0.2)
	_ok(Loc.lang == "en" and TranslationServer.get_locale() == "en" and String(Save.g("game.language", "")) == "en",
		"Flagge wählt Englisch und speichert die Wahl")
	# Spieldaten
	var missing: Array = []
	var texts: Array = []
	for u in Data.UPGRADES:
		texts += [String(u.name), String(u.get("short", "")), String(u.get("desc", ""))]
	for e in Data.EVOLUTIONS:
		texts += [String(e.name), String(e.desc)]
	for id in Data.ENEMIES:
		texts.append(String(Data.ENEMIES[id].name))
	for id in Data.bosses:
		texts += [String(Data.bosses[id].name), String(Data.bosses[id].get("weak", ""))]
	for lv in range(1, 11):
		var l: Dictionary = Data.level(lv)
		texts += [String(l.name), String(l.get("mechanic_text", "")), String(l.get("boss_intro", "")),
			String(l.get("miniboss", {}).get("title", ""))]
	for k in Loc.STRINGS["de"]:
		texts.append(Loc.t(k))
	var tips: Dictionary = load("res://scripts/game/tutorial.gd").TIPS
	for k in tips:
		texts += [Loc.tx(String(tips[k].title)), Loc.tx(String(tips[k].text))]
	for t in texts:
		var shown := Loc.tx(String(t)) if not String(t).is_empty() else ""
		if shown != "" and _de.search(shown.replace("Hülsbeck", "")) != null:
			missing.append(shown)
	_ok(missing.is_empty(), "Spieldaten vollständig übersetzt (%d offen: %s)" % [missing.size(), str(missing.slice(0, 6))])
	# Sichtbare Texte aller Bildschirme
	Save.new_campaign("normal", 11111)
	Save.campaign.start_talent = "pierce1"
	Save.campaign.level = 3
	Save.campaign.rewarded_levels = [1, 2]
	Save.campaign.level_stats = {"1": {}, "2": {}}
	for path_args in [
		["res://scripts/screens/main_menu.gd", {}],
		["res://scripts/screens/credits_screen.gd", {}],
		["res://scripts/screens/highscore_screen.gd", {"mode": "campaign", "difficulty": "all"}],
		["res://scripts/screens/difficulty_screen.gd", {}],
		["res://scripts/screens/start_talent_screen.gd", {}],
		["res://scripts/screens/build_overview_screen.gd", {}],
		["res://scripts/screens/fusion_screen.gd", {}],
		["res://scripts/screens/story_screen.gd", {"level": 3}],
		["res://scripts/screens/shop_screen.gd", {"level": 3}],
		["res://scripts/screens/pause_screen.gd", {}],
		["res://scripts/screens/ending_screen.gd", {}],
		["res://scripts/screens/name_entry_screen.gd", {"entry": {"score": 1234, "mode": "campaign", "difficulty": "normal"}, "rank": 1}],
	]:
		await _scan_screen(String(path_args[0]), path_args[1])
	var st := {"level": 3, "score": 12000, "kills": 40, "hits": 12, "time": 210.0, "accuracy": 0.72,
		"rank": "B", "rank_text": "Solide", "difficulty": "normal", "seed": 11111, "hp_left": 2}
	await _scan_screen("res://scripts/screens/level_result_screen.gd", {"stats": st, "level": 3, "training": false})
	Save.campaign.pending = {"level": 3, "offers": app._roll_offers(3), "reroll_used": false}
	await _scan_screen("res://scripts/screens/evolution_screen.gd", {})
	for tab in range(6):
		Save.set_g("ui.last_tab", tab)
		await _scan_screen("res://scripts/screens/settings_screen.gd", {"from": "main", "tab": tab})
	var tip: Dictionary = tips["bar"]
	await _scan_screen("res://scripts/screens/tutorial_tip_screen.gd",
		{"title": tip.title, "text": tip.text, "visual": tip.get("visual", [])})
	# Werkstatt: jede Kategorie mit Beschreibung
	app.clear_screens()
	var shop = app.push_screen("res://scripts/screens/shop_screen.gd", {"level": 3}, 0.0)
	await _wait(0.1)
	for c in range(shop._cats.size()):
		shop._select_cat(c)
		shop._enter_items()
		await get_tree().process_frame
		_scan_node(shop, "Werkstatt Kategorie %d" % c)
		shop._leave_items()
	var bad: Array = _seen.keys()
	_ok(bad.is_empty(), "Englisch: keine deutschen Texte auf den Bildschirmen (%d: %s)" % [bad.size(), str(bad.slice(0, 8))])
	for t in bad:
		print("    DE: %s  @ %s" % [t, _seen[t]])
	# Sprachclips
	var clips := 0
	for id in ["upgrade_base", "upgrade_fan", "upgrade_lightning", "upgrade_plasma", "upgrade_companion",
			"upgrade_bombs", "upgrade_shield", "upgrade_speed", "upgrade_repair", "nectar_low", "upgrade_max"]:
		if ResourceLoader.exists("res://assets/audio/voice/en/%s.ogg" % id):
			clips += 1
	_ok(clips == 11, "Englische Sprachclips vollständig (%d/11)" % clips)
	var s: AudioStream = Audio._load_voice("upgrade_fan")
	_ok(s != null and s.resource_path.contains("/en/"), "Ansage nutzt im Englischen den englischen Clip")
	app.menu_main()
	await _wait(0.2)

func _scan_screen(path: String, args: Dictionary) -> void:
	app.clear_screens()
	var s = app.push_screen(path, args, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if s == null or not is_instance_valid(s):
		fails.append("Bildschirm lädt nicht: " + path)
		return
	_scan_node(s, path.get_file())

func _scan_node(n: Node, where: String) -> void:
	if n is Label or n is Button or n is RichTextLabel:
		var c := n as Control
		if c.is_visible_in_tree():
			var raw := String(n.get("text"))
			var shown := raw if c.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else String(c.tr(raw))
			# Eigennamen mit Umlaut (Chris Hülsbeck) sind kein deutscher Text.
			if raw != "" and raw not in ["Deutsch"] and _de.search(shown.replace("Hülsbeck", "")) != null:
				_seen[shown] = where
	for ch in n.get_children():
		_scan_node(ch, where)
