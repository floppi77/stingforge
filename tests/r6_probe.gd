extends Node
## R6: Tutorial von Anfang bis Ende, Verschmelzungen, Bossmusik-Loops,
## angekündigte Bossphasen (Hecht), Brunnensäulen-Trefferform, Hauptmenü.

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	_fusions()
	_music_loops()
	await _menu()
	await _tutorial()
	await _pike_and_geyser()
	for f in fails:
		print("R6_FEHLER: " + f)
	print("R6_OK" if fails.is_empty() else "R6_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _top_script() -> String:
	if app.screens.is_empty():
		return ""
	var s = app.screens[-1]
	return String(s.get_script().resource_path) if s.get_script() != null else ""

func _close_tip() -> bool:
	if not _top_script().ends_with("tutorial_tip_screen.gd"):
		return false
	app.screens[-1]._age = 1.0
	app.screens[-1].close()
	return true

func _wait_tip(seconds: float = 6.0) -> bool:
	var t := 0.0
	while t < seconds:
		if _top_script().ends_with("tutorial_tip_screen.gd"):
			return true
		await _wait(0.1)
		t += 0.1
	return false

# ------------------------------------------------------------------ Verschmelzung
func _fusions() -> void:
	var pairs := Data.all_fusions()
	_ok(pairs.size() >= 20, "Verschmelzungspaare definiert (%d)" % pairs.size())
	var p := Player.new()
	p.evolutions = [{"id": "heavy_sting", "level": 1}]
	var alone := p.evo_effect("dmg_mult")
	p.evolutions.append({"id": "splinter", "level": 1})
	_ok(p.evo_fused("heavy_sting") and p.evo_effect("dmg_mult") > alone + 0.1,
		"Schwerer Stachel × Splittstachel: verschmolzen, Schaden %.2f → %.2f" % [alone, p.evo_effect("dmg_mult")])
	p.evolutions = [{"id": "pierce1", "level": 1}, {"id": "pierce_master", "level": 1}]
	_ok(int(p.evo_effect("pierce")) >= 5, "Durchschlag verschmolzen +1 je Partner (%d)" % int(p.evo_effect("pierce")))
	p.evolutions = [{"id": "nectar_bargain", "level": 1}]
	var cheap := p.evo_effect("cost_mult")
	p.evolutions.append({"id": "nectar_gluttony", "level": 1})
	_ok(p.evo_effect("cost_mult") < cheap and p.evo_effect("fire_rate_mult") <= -0.099,
		"Handel × Völlerei: Rabatt größer, Nachteil unverändert")
	p.free()
	var key := Data.fusion_key("splinter", "heavy_sting")
	Save.profile["fusions_seen"] = []
	_ok(not Save.is_fusion_seen(key) and Save.discover_fusion(key) and Save.is_fusion_seen(key),
		"Verschmelzung wird im Profil entdeckt")

# ------------------------------------------------------------------ Musik
func _music_loops() -> void:
	var ok := true
	for i in range(1, 11):
		var s: AudioStreamOggVorbis = Audio._load_music("boss%d" % i)
		ok = ok and s != null and s.loop and s.loop_offset > 1.0 and s.loop_offset < 3.0
	_ok(ok, "Alle zehn Bosstracks loopen ab ihrem Loopstart (nach der Ankunft)")
	var lv: AudioStreamOggVorbis = Audio._load_music("level1")
	_ok(lv != null and not lv.loop, "Leveltrack weiter ohne Loop")

# ------------------------------------------------------------------ Menü
func _menu() -> void:
	app.menu_main()
	await _wait(0.4)
	var menu = app.screens[-1]
	var ids: Array = []
	for it in menu.items:
		ids.append(String(it.get("id", "")))
	_ok(not ids.has("shop") and ids.has("tutorial") and ids.has("fusions"),
		"Hauptmenü: Tutorial und Verschmelzungen, keine Werkstatt")

# ------------------------------------------------------------------ Tutorial
func _tutorial() -> void:
	Save.new_campaign("normal", 4242)
	Save.campaign.points = 12345
	Save.active_campaign = true
	var before := Save.campaign.duplicate(true)
	Save.profile["tutorial_done"] = false
	app.start_tutorial()
	await _wait(0.4)
	var g = app.game
	_ok(g != null and g.mode == "tutorial" and g.get_node_or_null("Tutorial") != null, "Übungsflug startet")
	_ok(await _wait_tip(), "Begrüßung erscheint und hält das Spiel an")
	_ok(get_tree().paused, "Spiel ist während der Erklärung pausiert")
	_close_tip()
	await _wait(0.6)
	var tut = g.get_node("Tutorial")
	tut._moved = 700.0
	_ok(await _wait_tip(), "Schießen wird erklärt")
	_close_tip()
	await _wait(0.6)
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	_ok(await _wait_tip(), "Blütenstaub wird erklärt, sobald Tropfen fallen")
	_close_tip()
	await _wait(0.4)
	g.player.nectar = 5
	_ok(await _wait_tip(), "Waffenleiste und Kosten werden erklärt")
	var nectar_before: int = g.player.nectar
	_close_tip()
	await _wait(0.6)
	_ok(nectar_before >= 80, "Tutorial legt Blütenstaub für den ersten Kauf dazu")
	g.player.try_buy("fan")
	_ok(await _wait_tip(), "Kauf wird bestätigt und erklärt")
	_close_tip()
	await _wait(0.5)
	g.stats.kills += 10
	_ok(await _wait_tip(8.0), "Gegenfeuer wird erklärt")
	_close_tip()
	await _wait(0.4)
	tut._t = 9.0
	_ok(await _wait_tip(), "Schild und Bombe werden erklärt")
	_close_tip()
	await _wait(0.4)
	tut._t = 30.0
	await _wait(0.3)
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	tut._t = 10.0
	_ok(await _wait_tip(8.0), "Levelende wird angekündigt")
	_close_tip()
	await _wait(0.4)
	if _top_script().ends_with("nectar_convert_screen.gd"):
		var conv = app.screens[-1]
		if conv.on_done.is_valid():
			conv.on_done.call()
	_ok(await _wait_tip(), "Punkte und Highscore werden erklärt")
	_close_tip()
	await _wait(0.6)
	_ok(await _wait_tip(), "Werkstatt wird erklärt")
	_close_tip()
	await _wait(0.3)
	var shop = app.screens[-1]
	_ok(_top_script().ends_with("shop_screen.gd") and shop.tutorial, "Werkstatt im Übungsflug geöffnet")
	app.shop_done(1, true)
	_ok(await _wait_tip(), "Evolutionen und Verschmelzungen werden erklärt")
	_close_tip()
	await _wait(0.4)
	_ok(bool(Save.profile.get("tutorial_done", false)), "Tutorial als erledigt gespeichert")
	_ok(Save.active_campaign and int(Save.campaign.get("points", 0)) == int(before.points)
		and String(Save.campaign.get("run_id", "")) == String(before.get("run_id", "")),
		"Echter Spielstand bleibt unberührt")
	_ok(_top_script().ends_with("main_menu.gd"), "Zurück im Hauptmenü")

# ------------------------------------------------------------------ Hecht + Brunnen
func _pike_and_geyser() -> void:
	Save.new_campaign("normal", 3131)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(3, 0)
	await _wait(0.5)
	var g = app.game
	g.player.max_hp = 99
	g.player.hp = 99
	g.player.iframes = 1.0e6
	g._spawn_boss()
	await _wait(0.2)
	g.fx.hazards.clear()
	g.boss.take_damage(g.boss.max_hp * 0.5)
	await _wait(3.2)
	var geysers := 0
	for h in g.fx.hazards:
		if String(h.get("style", "")) == "water" and float(h.get("height", 0.0)) >= 250.0:
			geysers += 1
	_ok(geysers >= 2, "Hecht Phase 2 „peitscht das Wasser“: hohe Wassersäulen im Kampf (%d)" % geysers)
	# Trefferform = sichtbare Säule
	var h := {"kind": "root_spike", "style": "water", "p": Vector2(500, 0), "base": Vector2(500, App.PLAY_BOTTOM),
		"t": 1.5, "life": 2.0, "max_life": 3.6, "warn": 0.7, "height": 240.0}
	var shape := Fx.geyser_shape(h)
	_ok(Fx.geyser_hits(h, Vector2(500, App.PLAY_BOTTOM - 120.0), 4.6), "Brunnensäule trifft in der Säule")
	_ok(not Fx.geyser_hits(h, Vector2(500 + Fx.GEYSER_HALF + 12.0, App.PLAY_BOTTOM - 120.0), 4.6),
		"Neben der Säule kein Treffer")
	_ok(Fx.geyser_hits(h, (shape.top as Vector2) + Vector2(14, 0), 4.6), "Krone oben trifft ebenfalls")
	h.t = 0.2
	_ok(not Fx.geyser_hits(h, Vector2(500, App.PLAY_BOTTOM - 20.0), 4.6), "Während der Vorwarnung kein Treffer")
	app.menu_main()
	await _wait(0.3)
