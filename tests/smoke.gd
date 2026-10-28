extends Node
## Automatisierter Funktionstest ohne Fenster:
## Kampagnenstart, Kampf, Bosskampf, Phasenwechsel, Evolutionsbelohnung,
## Angebotsvielfalt über mehrere Seeds, Pause, Einstellungen, Anzeige-Rückfall.

var checks: Array = []
var failed := 0
var t0 := 0

func _ready() -> void:
	t0 = Time.get_ticks_msec()
	Engine.time_scale = 6.0
	_watchdog()
	await get_tree().process_frame
	print("SMOKE: Start")
	await _run()
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("SMOKE: checks=%d failed=%d dauer=%.1fs" % [checks.size(), failed, dt])
	for c in checks:
		print(("  OK   " if c.ok else "  FAIL ") + c.name + ("" if c.ok else "  -> " + c.detail))
	if failed == 0:
		print("SMOKE_OK")
		get_tree().quit(0)
	else:
		print("SMOKE_FAIL")
		get_tree().quit(1)

func _watchdog() -> void:
	await get_tree().create_timer(150.0, false).timeout
	print("SMOKE_TIMEOUT")
	get_tree().quit(2)

func chk(name: String, ok: bool, detail: String = "") -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	if not ok:
		failed += 1

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

func wait_for(cond: Callable, timeout: float = 20.0) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false

func _run() -> void:
	var app = get_node_or_null("/root/App")
	chk("Autoload App vorhanden", app != null)
	if app == null:
		return
	chk("Hauptmenü geöffnet", not app.screens.is_empty())
	chk("Starttalente: genau drei Grundtalente", _count_base_talents() == 3, "gefunden=%d" % _count_base_talents())

	# --- Kampagne starten
	app.clear_screens()
	app.start_new_campaign("normal", "pierce1")
	var ok_level := await wait_for(func(): return app.game != null and is_instance_valid(app.game), 15.0)
	chk("Level 1 startet", ok_level)
	if not ok_level:
		return
	var g = app.game
	chk("Spieler vorhanden", g.player != null)
	chk("Starttalent angewendet", g.player.evo_level("pierce1") == 1,
		"level=%d" % g.player.evo_level("pierce1"))
	chk("Schwierigkeit normal = 3 HP", g.player.max_hp == 3 or g.player.max_hp >= 3,
		"max_hp=%d" % g.player.max_hp)

	# --- Autofeuer und Bewegung simulieren
	g.player.autofire = true
	Input.action_press("move_right")
	await wait(0.4)
	Input.action_release("move_right")
	var shots_before: int = g.stats.shots
	await wait(4.0)
	chk("Spieler feuert Munition", g.stats.shots > shots_before, "shots=%d" % g.stats.shots)
	var spawned := await wait_for(func(): return g.director.enemies_spawned > 0, 20.0)
	chk("Gegner werden erzeugt", spawned, "spawn=%d" % g.director.enemies_spawned)
	chk("Geschosse werden gezeichnet", g.bullets.player_bullets.size() > 0,
		"n=%d" % g.bullets.player_bullets.size())

	# --- Gegner stirbt durch Beschuss. Ein eigener Gegner genau in der Schusslinie:
	# die erste Welle des Levels kann auch ober- oder unterhalb vorbeifliegen.
	var dummy = g.spawn_enemy("aphid_swarm", Vector2(540, 270))
	# Die echte Tötung darf den Lambda-Capture nicht selbst ungültig machen.
	var dummy_ref: WeakRef = weakref(dummy)
	var killed := await wait_for(func():
		var target = dummy_ref.get_ref()
		return target == null or float(target.get("hp")) <= 0.0, 12.0)
	chk("Gegner kann zerstört werden", killed, "hp=%.0f" % float(dummy.get("hp")) if is_instance_valid(dummy) else "weg")
	chk("Punkte steigen", g.player.points > 0, "punkte=%d" % g.player.points)

	# --- Checkpoint
	g.director.checkpoint_reached.emit(1)
	await get_tree().process_frame
	chk("Checkpoint gespeichert", int(Save.campaign.get("checkpoint", -1)) == 1,
		"cp=%d" % int(Save.campaign.get("checkpoint", -1)))

	# --- Boss erzwingen
	g.director.start_boss_now()
	var boss_ok := await wait_for(func(): return g.boss != null and is_instance_valid(g.boss), 10.0)
	chk("Boss erscheint", boss_ok)
	if not boss_ok:
		return
	var b = g.boss
	chk("Boss hat Phasen", b.phase_defs.size() >= 2, "phasen=%d" % b.phase_defs.size())
	await wait(3.0)
	var boss_shoots := await wait_for(func(): return g.bullets.enemy_bullets.size() > 0, 25.0)
	chk("Boss greift an", boss_shoots, "gegnerkugeln=%d" % g.bullets.enemy_bullets.size())
	# Phasenwechsel durch Schaden erzwingen
	var phase0: int = b.phase
	b.take_damage(b.max_hp * 0.45)
	await get_tree().process_frame
	chk("Phasenwechsel bei Schaden", b.phase > phase0, "phase=%d" % b.phase)
	# Ein Endboss ist erst nach natürlicher Häutung UND zweitem Sieg erledigt.
	await _defeat_boss(g, b)

	# --- Evolutionsbildschirm und Belohnung
	var evo_shown := await wait_for(func(): return _has_screen(app, "evolution_screen.gd"), 25.0)
	chk("Evolutionsauswahl erscheint", evo_shown)
	if evo_shown:
		var pending: Dictionary = Save.campaign.get("pending", {})
		var offers: Array = pending.get("offers", [])
		chk("Drei Evolutionsangebote", offers.size() == 3, "n=%d" % offers.size())
		chk("Angebote sind verschieden", _unique(offers) == offers.size())
		chk("Angebote aus mehreren Familien", _families(offers).size() >= 2, str(_families(offers)))
		var pick := String(offers[0])
		var evo_before: int = Save.campaign.evolutions.size()
		app._confirm_evolution(pick)
		await wait(0.2)
		chk("Evolution gespeichert", Save.campaign.evolutions.size() == evo_before + 1,
			"vorher=%d nachher=%d" % [evo_before, Save.campaign.evolutions.size()])
		chk("Evolution freigeschaltet", Save.is_evolution_unlocked(pick))
		chk("Keine offene Entscheidung mehr", Save.campaign.get("pending", {}).is_empty())
		chk("Belohnung nicht doppelt vergeben", Save.campaign.rewarded_levels.has(1))
		chk("Ergebnisbildschirm folgt", _has_screen(app, "level_result_screen.gd"))

	# --- Angebotsvielfalt über fünf Seeds
	var variations: Array = []
	for s in [11, 202, 3033, 40404, 515151]:
		Save.campaign.seed = s
		Save.campaign.evolutions = []
		var offers2: Array = app._roll_offers(3)
		variations.append(offers2)
		chk("Seed %d liefert drei Angebote" % s, offers2.size() == 3, str(offers2))
	chk("Angebote variieren über Seeds", _unique_strings(variations) >= 3, str(variations))

	# --- Pause und Fortsetzen
	app.menu_main()
	await wait(0.2)
	Save.campaign.seed = 7
	app.start_new_campaign("normal", "crit")
	var ok2 := await wait_for(func(): return app.game != null and is_instance_valid(app.game), 15.0)
	chk("Zweiter Levelstart", ok2)
	if ok2:
		var g2 = app.game
		await wait(0.3)
		app.pause_game()
		chk("Pause friert Spiel ein", get_tree().paused)
		chk("Pausenmenü offen", _has_screen(app, "pause_screen.gd"))
		app.resume_game()
		await wait(0.2)
		chk("Fortsetzen hebt Pause auf", not get_tree().paused)
		# Einstellungen: Anzeige-Test rollt zurück
		app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
		await wait(0.2)
		chk("Einstellungen öffnen", _has_screen(app, "settings_screen.gd"))
		var before_res: int = int(Save.g("display.resolution", 2))
		Save.set_g("display.resolution", 4)
		app.apply_display()
		app.begin_display_test({"display.resolution": before_res})
		await wait(0.2)
		chk("Anzeigetest zeigt Bestätigung", _has_screen(app, "display_confirm.gd"))
		app.revert_display_now()
		await wait(0.2)
		chk("Anzeige zurückgesetzt", int(Save.g("display.resolution", 2)) == before_res,
			"jetzt=%d" % int(Save.g("display.resolution", 2)))
		# Waffenleiste: Kauf mit Nektar
		var p = g2.player
		p.nectar = 400
		var res: Dictionary = p.try_buy("fan")
		chk("Waffe kaufbar", bool(res.get("ok", false)) and int(p.upgrades.get("fan", 0)) == 1, str(res))
		p.hp = p.max_hp
		var res2: Dictionary = p.try_buy("repair")
		chk("Reparatur bei vollem Leben verbraucht nichts",
			not bool(res2.get("ok", true)) and p.nectar == 400 - 30, str(res2))
		# Evolution deaktiviert ohne Waffe
		p.evolutions.append({"id": "companion_add", "level": 1})
		p.upgrades["companion"] = 1
		var before_comp: int = int(p.evo_effect("companion_add"))
		p.upgrades["companion"] = 0
		var after_comp: int = int(p.evo_effect("companion_add"))
		chk("Waffenabhängige Evolution inaktiv ohne Waffe", before_comp == 1 and after_comp == 0,
			"%d -> %d" % [before_comp, after_comp])

	# --- Training startet mit kopiertem Build und verändert Kampagne nicht
	var cp_before: Dictionary = Save.campaign.duplicate(true)
	app.start_training(1, "boss")
	var ok3 := await wait_for(func(): return app.game != null and is_instance_valid(app.game), 15.0)
	chk("Training startet", ok3)
	if ok3:
		var g3 = app.game
		await wait(1.5)
		chk("Training zeigt Boss direkt", g3.boss != null and is_instance_valid(g3.boss))
	app.menu_main()
	await wait(0.2)
	chk("Kampagne nach Training unverändert",
		int(Save.campaign.get("level", 0)) == int(cp_before.get("level", 0))
		and Save.campaign.get("evolutions", []).size() == cp_before.get("evolutions", []).size())
	await _final_encounter(app)

func _defeat_boss(g, b) -> void:
	var first_max: float = b.max_hp
	b.invuln = 0.0
	b.vulnerable = true
	b.take_damage(b.max_hp * 10.0)
	if String(b.id) == "core_organism":
		chk("Endboss: erster Tod startet Häutung statt Sieg", b.reviving and not b.dead and not g.level_over)
		# R4: Scheinsieg mit Ruhephase, dann Wiedergeburt (REVIVE_TIME).
		var reborn := await wait_for(func(): return is_instance_valid(b) and not b.reviving and b.encounter_form == 2, b.REVIVE_TIME + 3.0)
		chk("Endboss: Scheinsieg und Wiedergeburt erreichen Form2", reborn)
		if not reborn:
			return
		chk("Endboss: zweite Form hat1.75xersteMaxHP", is_equal_approx(b.max_hp, first_max * 1.75))
		chk("Endboss: zweite Form hat exakt3Phasen", b.phase_defs.size() == 3)
		chk("Endboss: noch kein Levelabschluss vor zweitem Tod", not g.level_over)
		b.invuln = 0.0
		b.vulnerable = true
		b.take_damage(b.max_hp * 10.0)
	await wait(0.2)
	chk("Boss endgültig besiegt", b.dead and g.level_over)

func _final_encounter(app) -> void:
	app.clear_screens()
	Save.new_campaign("normal", 111987)
	app.mode = "campaign"
	app._begin_level(10, 0)
	var started := await wait_for(func(): return app.game != null and is_instance_valid(app.game), 15.0)
	chk("Finales Level startet für Zweiformen-Smoke", started)
	if not started:
		return
	var g = app.game
	g.player.iframes = 30.0
	g.player.autofire = false
	g.director.start_boss_now()
	var spawned := await wait_for(func(): return g.boss != null and is_instance_valid(g.boss), 10.0)
	chk("Finaler Boss erscheint als core_organism", spawned and String(g.boss.id) == "core_organism")
	if spawned:
		await _defeat_boss(g, g.boss)
	app.menu_main()

func _count_base_talents() -> int:
	var n := 0
	for e in Data.EVOLUTIONS:
		if bool(e.get("start_base", false)):
			n += 1
	return n

func _has_screen(app, needle: String) -> bool:
	for s in app.screens:
		if is_instance_valid(s) and String(s.get_script().resource_path).ends_with(needle):
			return true
	return false

func _unique(arr: Array) -> int:
	var seen := {}
	for a in arr:
		seen[str(a)] = true
	return seen.size()

func _unique_strings(arr: Array) -> int:
	var seen := {}
	for a in arr:
		seen[str(a)] = true
	return seen.size()

func _families(offers: Array) -> Array:
	var fams := {}
	for id in offers:
		fams[str(Data.evo(String(id)).get("family", "?"))] = true
	return fams.keys()
