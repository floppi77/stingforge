extends Node
## R10: Bossüberarbeitung (Pilz-Hofstaat, Mantidenpaar, Wasserläufer-Rohrbruch,
## Erntemaschinen-Flanke, Kern-Schutzzone, ruhigerer Wind), Sichttrübung und Pollen,
## Abspann-Level ohne Evolutionswahl, Ko-fi im Hauptmenü, Debug-Bosswahl und -Abspann.

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	app.links_dry_run = true
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	_data()
	await _fungus()
	await _mantis()
	await _skater()
	await _harvester()
	await _core()
	await _final_flow()
	await _menu_and_debug()
	for f in fails:
		print("R10_FEHLER: " + f)
	print("R10_OK" if fails.is_empty() else "R10_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

## Run auf Level 1 starten und per Debug direkt in den Bosskampf eines Levels springen.
func _boss_fight(lv: int) -> Node:
	Save.new_campaign("normal", 1010 + lv)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	_ok(app.debug_fight_boss(lv), "Debug-Bosswahl startet Level %d" % lv)
	var g = app.game
	for i in range(80):
		if g.boss != null and is_instance_valid(g.boss):
			break
		await _wait(0.05)
	g.player.iframes = 1.0e6
	g.player.autofire = false
	g.player.position = Vector2(140, 270)
	return g

# ------------------------------------------------------------------ Daten
func _data() -> void:
	var fungus := Data.boss("fungus_mind")
	var all_sprouts := true
	for ph in fungus.phases:
		all_sprouts = all_sprouts and (ph.patterns as Array).has("sprouts")
	_ok(int(fungus.hp) == 3000 and all_sprouts, "Pilzboss: weniger Leben, Pilzlinge in jeder Phase")
	for id in ["fungus_sprout", "fungus_healer", "fungus_guard"]:
		_ok(not Data.enemy(id).is_empty() and Loc.has_translation(String(Data.enemy(id).name)), "Gegner %s definiert und übersetzt" % id)
	var mantis := Data.boss("mantis_pair")
	_ok((mantis.phases[0] as Dictionary).has("twin_patterns"), "Mantidenpaar: eigene Angriffe der zweiten Mantis")
	var skater := Data.boss("mutant_skater")
	_ok((skater.phases[0].patterns as Array).has("skim_strike") and (skater.phases[0].patterns as Array).has("ripple_ring"),
		"Wasserläufer: neue Angriffe schon in Phase 1")
	var harv := Data.boss("harvester")
	_ok((harv.phases[0].patterns as Array).has("harvester_flank") and (harv.phases[2].patterns as Array).has("harvest_storm"),
		"Erntemaschine: Flanke in Phase 1, Dreschsturm in Phase 3")
	var core := Data.boss("core_organism")
	_ok((core.phases[2].patterns as Array).has("safe_zone"), "Kernorganismus: Schutzzone in Phase 3")
	var game_src := FileAccess.get_file_as_string("res://scripts/game/game.gd")
	_ok(game_src.contains("const BLIND_CHANCE := 0.15") and game_src.contains("blind_checked"),
		"Sichttrübung: 15 % und nur ein Versuch je Geschoss")
	_ok(game_src.contains("const GRAVITY_STRENGTH := 0.65"), "Wind im Kernlevel schwächer (0,90 → 0,65)")
	var dir_src := FileAccess.get_file_as_string("res://scripts/game/director.gd")
	_ok(dir_src.contains("\"core\": {\"interval\": 10.0"), "Wind im Kernlevel seltener (7 s → 10 s)")
	var pl_src := FileAccess.get_file_as_string("res://scripts/game/player.gd")
	_ok(pl_src.contains("pollen_cd = 0.4"), "Pollenwolken: seltener gelegt")

# ------------------------------------------------------------------ Pilz
func _fungus() -> void:
	var g = await _boss_fight(4)
	var b = g.boss
	_ok(b != null and String(b.id) == "fungus_mind" and int(g.level_index) == 4, "Pilzboss direkt per Debug erreicht")
	await _wait(3.2)
	var healer = null
	var guards: Array = []
	for e in g.enemies:
		if not is_instance_valid(e):
			continue
		if String(e.behavior) == "healer":
			healer = e
		elif String(e.behavior) == "orbit_host":
			guards.append(e)
	_ok(healer != null and guards.size() == 3, "Heilpilz mit drei umkreisenden Schirmlingen erscheint")
	if healer == null:
		app.menu_main()
		await _wait(0.2)
		return
	_ok(healer.shielded(), "Heilpilz ist geschützt, solange Schirmlinge leben")
	var hp0: float = healer.hp
	healer.take_damage(100.0)
	_ok(healer.hp > hp0 - 20.0, "Geschützter Heilpilz nimmt kaum Schaden")
	b.hp = b.max_hp * 0.9
	var before: float = b.hp
	await _wait(2.2)
	_ok(b.hp > before, "Heilpilz heilt den Boss langsam")
	for gd in guards:
		if is_instance_valid(gd):
			gd.take_damage(9999.0)
	await _wait(0.1)
	_ok(not healer.shielded(), "Ohne Schirmlinge ist der Heilpilz verwundbar")
	b._p_sprouts()
	await _wait(0.2)
	var sprouts := 0
	for e in g.enemies:
		if is_instance_valid(e) and String(e.behavior) == "sprout":
			sprouts += 1
	_ok(sprouts > 0, "Kleine Pilzlinge helfen dem Boss")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Mantis
func _mantis() -> void:
	var g = await _boss_fight(5)
	var b = g.boss
	_ok(b != null and not b.twin_dead and b.twin_hp > 0.0 and b.primary_hp > 0.0, "Mantidenpaar: zwei Körper mit eigenen Lebenspunkten")
	if b == null:
		return
	var twin_before: float = b.twin_hp
	var prim_before: float = b.primary_hp
	b.take_damage(50.0, Vector2.ZERO, b.TWIN_PART)
	_ok(b.twin_hp < twin_before and is_equal_approx(b.primary_hp, prim_before), "Treffer auf die zweite Mantis zählt nur bei ihr")
	b.take_damage(b.twin_hp + 5.0, Vector2.ZERO, b.TWIN_PART)
	_ok(b.twin_dead and int(b.phase) == 1, "Fällt eine Mantis, beginnt Phase II")
	var pats: Array = b.phase_defs[1].patterns
	_ok(pats.has("orchid_needles") and pats.has("orchid_scythe") and pats.has("mantis_pounce"),
		"Die Überlebende erbt die Angriffe der Gefallenen")
	_ok(not b.dead and b.hp > 0.0, "Kampf läuft mit der Überlebenden weiter")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Wasserläufer
func _skater() -> void:
	var g = await _boss_fight(7)
	var b = g.boss
	b._apply_phase(2)
	await _wait(3.0)
	g.clear_enemy_bullets()
	await _wait(1.0)
	var drops := 0
	for bl in g.bullets.enemy_bullets:
		if (bl.get("tint", Color.WHITE) as Color).is_equal_approx(Color(0.6, 0.85, 1.0)) or float((bl.v as Vector2).y) > 0.0:
			drops += 1
	_ok(drops >= 10, "Rohrbruch: viele Wasserspritzer prasseln herab (%d)" % drops)
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Erntemaschine
func _harvester() -> void:
	var g = await _boss_fight(8)
	var b = g.boss
	_ok(b._harvest_density() == 0, "Erntemaschine Phase 1: Grunddichte")
	await _wait(2.6)
	b.motion = {}
	b.timeline.clear()
	b._p_harvester_flank()
	var min_x := 9999.0
	var left_seen := false
	for i in range(240):
		await _wait(0.05)
		min_x = minf(min_x, b.position.x)
		if b.position.x > 60.0 and b.position.x < 200.0:
			left_seen = true
		if left_seen and b.position.x > 700.0 and b.motion.is_empty():
			break
	_ok(min_x < 0.0 and left_seen, "Flanke: rechts hinaus, links hinter der Biene herein")
	_ok(b.position.x > 700.0, "Flanke: danach rechts wieder herein (x=%d)" % int(b.position.x))
	b._apply_phase(2)
	_ok(b._harvest_density() >= 1, "Erntemaschine Phase 3: dichtere Salven")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Kern
func _core() -> void:
	var g = await _boss_fight(10)
	var b = g.boss
	_ok(b != null and String(b.id) == "core_organism", "Kernorganismus direkt per Debug erreicht")
	g.fx.add_hazard({"kind": "gravity_field", "p": Vector2.ZERO, "t": 0.0, "life": 3.0, "max_life": 3.0})
	g.fx.update(0.7)
	var pull_before: Vector2 = g.gravity_pull()
	_ok(pull_before.y > 0.0 and pull_before.y <= Player.BASE_SPEED * 0.66, "Wind zieht, aber schwächer als zuvor")
	var window: float = g.begin_safe_zone()
	var zone: Dictionary = g.safe_zone
	var b_rect: Rect2 = g.player.play_bounds
	var far := 0.0
	for corner in [b_rect.position, Vector2(b_rect.end.x, b_rect.position.y), Vector2(b_rect.position.x, b_rect.end.y), b_rect.end]:
		far = maxf(far, (corner as Vector2).distance_to(zone.p))
	var need := (far - float(zone.r)) / Player.BASE_SPEED
	_ok(window >= need and window <= need + 0.8, "Zeitfenster reicht gerade ohne Tempo-Upgrade (%.2f s, nötig %.2f s)" % [window, need])
	_ok(g.gravity_pull() == Vector2.ZERO, "Während der Schutzzone ist der Wind aus")
	# Biene in der Zone: kein Schaden.
	g.player.iframes = 0.0
	g.player.shield_hits = 0
	g.player.max_hp = 9
	g.player.hp = 9
	g.player.position = zone.p
	g.player.set_physics_process(false)
	g.fx.update(window + 0.05)
	g._tick_safe_zone(0.0)
	_ok(g.player.hp == 9 and g.safe_zone.is_empty(), "In der Schutzzone: kein Schaden")
	# Biene außerhalb: dreifacher Schaden.
	g.begin_safe_zone()
	var z2: Dictionary = g.safe_zone
	g.player.position = (z2.p as Vector2) + Vector2(200, 0) if float(z2.p.x) < 600.0 else (z2.p as Vector2) - Vector2(200, 0)
	g.player.iframes = 0.0
	g.fx.update(float(z2.life) + 0.05)
	g._tick_safe_zone(0.0)
	_ok(9 - g.player.hp == 3, "Außerhalb der Schutzzone: dreifacher Schaden (%d)" % (9 - g.player.hp))
	g.player.set_physics_process(true)
	g.player.iframes = 1.0e6
	b._safe_zone_last = -100.0
	b.motion = {}
	b._p_safe_zone()
	_ok(not g.safe_zone.is_empty() and not b.motion.is_empty(), "Kern hält inne, solange die Schutzzone läuft")
	_ok(b.phase_defs.size() >= 3, "Kern: Phasen vorhanden")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Abspann
func _final_flow() -> void:
	Save.new_campaign("normal", 4242)
	app.mode = "campaign"
	app.clear_screens()
	Save.campaign.nectar = 0
	Save.campaign.level_stats = {}
	var stats := {"level": 10, "score": 5000, "kills": 10, "hits": 1, "time": 300.0, "rank": "A",
		"rank_text": "Stark", "difficulty": "normal", "seed": 4242, "hp_left": 3}
	app.on_level_complete(stats)
	await _wait(2.0)
	_ok(Save.campaign.get("pending", {}).is_empty(), "Nach dem letzten Boss keine Evolutionswahl")
	var top = app.screens[-1] if not app.screens.is_empty() else null
	_ok(top != null and String(top.get_script().resource_path).ends_with("level_result_screen.gd"), "Nach dem letzten Boss direkt die Levelwertung")
	if top != null and top.has_method("on_activate"):
		top.on_activate(0)
	await _wait(0.4)
	var end = app.screens[-1] if not app.screens.is_empty() else null
	_ok(end != null and String(end.get_script().resource_path).ends_with("ending_screen.gd"), "Danach startet das Abspann-Level")
	if end == null:
		return
	_ok(bool(Save.campaign.completed) and bool(Save.profile.boss_rush_unlocked), "Abspann schließt den Run ab")
	var congrats := end.find_child("Congrats", true, false) as Label
	_ok(congrats != null and congrats.text == Loc.tx("Herzlichen Glückwunsch, du hast diese Welt befriedet."), "Glückwunsch wird angezeigt")
	_ok(end._cards.size() == 2, "Ko-fi links, Original rechts")
	end._open(0)
	_ok(app.last_opened_url == "https://ko-fi.com/floppi77", "Ko-fi-Link öffnet")
	end._open(1)
	_ok(app.last_opened_url == "https://store.steampowered.com/app/3956980/Apidya_Special/", "Steam-Link zu Apidya Special öffnet")
	var bee_start: Vector2 = end._bee.position
	await _wait(0.5)
	_ok(end._bee.position.distance_to(bee_start) > 1.0, "Biene fliegt von selbst")
	_ok(not end.rolling, "Erst steht der Glückwunsch")
	end.t = end.HOLD_TIME - 0.1
	await _wait(0.6)
	var scroll_a: float = end.scroll
	await _wait(0.5)
	_ok(end.rolling and end.scroll > scroll_a, "Nach 20 Sekunden rollt alles nach oben, der Abspann läuft")
	end.skip()
	await _wait(0.3)
	var menu = app.screens[0] if not app.screens.is_empty() else null
	_ok(menu != null and String(menu.get_script().resource_path).ends_with("main_menu.gd"), "Abspann endet im Hauptmenü")

# ------------------------------------------------------------------ Menü und Debug
func _menu_and_debug() -> void:
	app.menu_main()
	await _wait(0.3)
	var menu = app.screens[0]
	var badge = menu.find_child("KofiBadge", true, false)
	_ok(badge != null and badge.visible, "Hauptmenü zeigt den kleinen Ko-fi-Knopf")
	app.last_opened_url = ""
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	if badge != null:
		badge.gui_input.emit(ev)
	_ok(app.last_opened_url == "https://ko-fi.com/floppi77", "Ko-fi-Knopf öffnet die Seite")
	app.clear_screens()
	var credits = app.push_screen("res://scripts/screens/credits_screen.gd", {}, 0.0)
	await _wait(0.1)
	var ids: Array = credits.items.map(func(it): return String(it.get("id", "")))
	_ok(ids.has("kofi"), "Credits: Ko-fi auch per Tastatur und Controller")
	# Debug-Abspann: Vorschau ohne Runabschluss.
	Save.new_campaign("normal", 5151)
	Save.campaign.completed = false
	app.mode = "campaign"
	app._begin_level(2, 0)
	await _wait(0.3)
	app.debug_game()
	await _wait(0.1)
	var dbg = app.screens[-1]
	var dids: Array = dbg.items.map(func(it): return String(it.get("id", "")))
	_ok(dids.has("bossjump") and dids.has("credits"), "Debugmenü: Boss wählen und Abspann starten")
	app.debug_credits()
	await _wait(0.3)
	var end = app.screens[-1]
	_ok(String(end.get_script().resource_path).ends_with("ending_screen.gd") and end.preview, "Debug startet das Abspann-Level")
	_ok(not bool(Save.campaign.completed) and not app.is_in_game(), "Debug-Abspann schließt den Run nicht ab")
	app.menu_main()
	await _wait(0.2)
