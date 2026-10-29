extends Node
## R9: Meisterevolutionen (Daten, Angebot, Wahl, jede Wirkung), Debug-Sprung zum Boss
## beendet den Levelablauf, durchsichtigere Pollenwolken.

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	_data()
	await _offer_and_choice()
	await _effects()
	await _boss_jump()
	await _collection()
	for f in fails:
		print("R9_FEHLER: " + f)
	print("R9_OK" if fails.is_empty() else "R9_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

# ------------------------------------------------------------------ Daten
func _data() -> void:
	_ok(Data.MASTERS.size() == 12, "Zwölf Meisterevolutionen")
	var pairs := {}
	var ok := true
	for m in Data.MASTERS:
		var a := String(m.parents[0])
		var b := String(m.parents[1])
		ok = ok and not Data.EVOLUTIONS.filter(func(e): return e.id == a).is_empty() \
			and not Data.EVOLUTIONS.filter(func(e): return e.id == b).is_empty()
		pairs[Data.fusion_key(a, b)] = true
		ok = ok and Data.master_of(a, b) == String(m.id) and Data.evo(String(m.id)).get("master", false)
		ok = ok and Loc.has_translation(String(m.name)) and Loc.has_translation(String(m.desc))
	_ok(ok and pairs.size() == 12, "Eltern existieren, Paare eindeutig, Namen und Texte übersetzt")
	var still := 0
	for pair in Data.all_fusions():
		if Data.master_of(String(pair[0]), String(pair[1])) != "":
			still += 1
	_ok(still == 0 and Data.all_fusions().size() == 16, "Meisterpaare haben keinen Pauschal-Bonus mehr (16 Verschmelzungen bleiben)")

# ------------------------------------------------------------------ Angebot und Wahl
func _offer_and_choice() -> void:
	Save.new_campaign("normal", 9191)
	Save.campaign.evolutions = [{"id": "chitin_plate", "level": 1}, {"id": "chitin_regen", "level": 1}]
	_ok(not app.master_offers().has("m_second_skin"), "Ohne Höchststufe keine Meisterkarte")
	Save.campaign.evolutions[0].level = 2
	_ok(app.master_offers().has("m_second_skin"), "Beide Eltern, einer auf Höchststufe: Meisterkarte bereit")
	var offers: Array = app._roll_offers(3)
	_ok(offers.size() == 3 and String(offers[0]) == "m_second_skin", "Meisterkarte belegt die erste Angebotskarte")
	Save.campaign.pending = {"level": 2, "offers": offers, "reroll_used": false}
	Save.campaign.level = 2
	app.clear_screens()
	var scr = app.push_screen("res://scripts/screens/evolution_screen.gd", {"on_choose": func(_id): pass}, 0.0)
	await _wait(0.1)
	_ok(scr.items.size() > 0 and bool(scr.items[0].get("master", false)), "Evolutionsbildschirm zeigt die goldene Meisterkarte")
	Save.profile["masters_seen"] = []
	app._confirm_evolution("m_second_skin")
	await _wait(0.1)
	var ids: Array = []
	for e in Save.campaign.evolutions:
		ids.append(String(e.id))
	_ok(ids.has("m_second_skin") and ids.has("chitin_plate") and ids.has("chitin_regen"), "Meister gewählt, beide Eltern bleiben")
	_ok(Save.is_master_seen("m_second_skin") and not Save.is_evolution_unlocked("m_second_skin"),
		"Meister landet im Sammelbuch, nicht bei den 36 Evolutionen")
	_ok(not app.master_offers().has("m_second_skin"), "Gewählter Meister wird nicht erneut angeboten")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Wirkungen
func _start(evos: Array, upgrades: Dictionary = {}) -> Node:
	Save.new_campaign("normal", 9292)
	Save.campaign.evolutions = []
	for id in evos:
		Save.campaign.evolutions.append({"id": id, "level": 1})
	var u := {"base": 1, "fan": 0, "lightning": 0, "plasma": 0, "companion": 0, "bombs": 0, "shield": 0, "speed": 0}
	u.merge(upgrades, true)
	Save.campaign.upgrades = u
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	var g = app.game
	g.director.intro_t = 1.0e6
	for e in g.enemies:
		if is_instance_valid(e):
			e.queue_free()
	g.enemies.clear()
	g.player.position = Vector2(200, 270)
	g.player.autofire = false
	await _wait(0.05)
	return g

func _enemy(g: Node, pos: Vector2, hp: float = 500.0) -> Node:
	var e = g.spawn_enemy("beetle_grunt", pos, {})
	e.hp = hp
	e.max_hp = hp
	e.shots = ""
	e.speed = 0.0
	e.behavior = "anchor"
	e.target_x = pos.x
	return e

func _effects() -> void:
	# Splitterlanze: Splitter durchschlagen zwei Ziele und zerbrechen erneut.
	var g = await _start(["pierce1", "splinter", "m_splinter_lance"])
	var target = _enemy(g, Vector2(500, 270))
	g.bullets.player_bullets.clear()
	g._spawn_splinter(Vector2(500, 270), 10.0, 2, {})
	var sp: Dictionary = g.bullets.player_bullets[0]
	_ok(int(sp.pierce) == 2 and bool(sp.get("lance", false)), "Splitterlanze: Splitter mit zwei Durchschlägen")
	g.bullets.player_bullets.clear()
	g._proc_splinters(sp, Vector2(500, 270), 10.0)
	_ok(g.bullets.player_bullets.size() == 2 and int(g.bullets.player_bullets[0].proc_depth) == 2,
		"Splitterlanze: Splitter zerbricht beim Treffer erneut")
	# Todesmal: markiertes Ziel nimmt doppelten Schaden.
	g = await _start(["crit", "swarm_mark", "m_death_mark"])
	target = _enemy(g, Vector2(500, 270))
	var before: float = g._target_damage_mult(target)
	g.masters.mark(target)
	_ok(is_equal_approx(g._target_damage_mult(target), before * 2.0), "Todesmal: markiertes Ziel nimmt doppelten Schaden")
	# Hofstaat: sechs Begleiter mit aktiver Waffe.
	g = await _start(["companion_add", "swarm_echo", "m_royal_court"], {"companion": 1, "fan": 1})
	_ok(g.player.companion_count() == 6, "Hofstaat: sechs Begleitbienen")
	g.player.weapon = "fan"
	g.bullets.player_bullets.clear()
	g.player.companion_cd = 0.0
	g.player._update_companions(0.016)
	_ok(g.bullets.player_bullets.size() >= 12, "Hofstaat: Begleiter feuern mit der aktiven Waffe (%d Geschosse)" % g.bullets.player_bullets.size())
	# Schildwall: Drohne schluckt ein Geschoss und fällt kurz aus.
	g = await _start(["companion_form", "drone_sacrifice", "m_shield_wall"], {"companion": 2})
	var wp: Vector2 = g.masters.wall_position(0, 2)
	_ok((g.player.companion_position(0, 2) - wp).length() < 0.1, "Schildwall: Drohnen stehen als Wand vor der Biene")
	g.bullets.enemy_bullets.clear()
	g.bullets.spawn_enemy(wp, Vector2.ZERO, 1, "ebullet_orb", {})
	g.masters.update(0.016)
	_ok(g.bullets.enemy_bullets.is_empty() or float(g.bullets.enemy_bullets[0].life) <= 0.0, "Schildwall: Geschoss geschluckt")
	_ok(not g.masters.wall_active(0), "Schildwall: getroffene Drohne baut sich neu auf")
	# Kettenblüte: Explosion zündet Nachbarwolken und trifft Gegner.
	g = await _start(["pollen_burst", "pollen_trail", "m_chain_bloom"])
	target = _enemy(g, Vector2(560, 270), 500.0)
	g.fx.hazards.clear()
	g.spawn_pollen(Vector2(620, 270), 1.0, false)
	g.spawn_pollen(Vector2(540, 270), 1.4, true)
	var hp0: float = target.hp
	for i in range(30):
		g.masters.update(0.02)
	_ok(target.hp < hp0, "Kettenblüte: Explosion trifft Gegner (%.0f → %.0f)" % [hp0, target.hp])
	_ok(g.fx.hazards.any(func(h): return bool(h.get("bloomed", false))), "Kettenblüte: Nachbarwolke zündet mit")
	# Pollensturm: Wirbel trifft Gegner und löscht Geschosse.
	g = await _start(["pollen_trail", "wind_rider", "m_pollen_storm"])
	g.masters.storm_angle = 0.0
	var c: Vector2 = g.masters.storm_center()
	target = _enemy(g, c, 500.0)
	g.bullets.enemy_bullets.clear()
	g.bullets.spawn_enemy(c, Vector2.ZERO, 1, "ebullet_orb", {})
	g.masters._storm_tick = 0.0
	g.masters._update_storm(0.0)
	_ok(target.hp < 500.0, "Pollensturm: Wirbel schadet Gegnern")
	_ok(float(g.bullets.enemy_bullets[0].life) <= 0.0, "Pollensturm: Wirbel löscht Feindgeschosse")
	# Zweite Haut: einmal pro Level einen tödlichen Treffer überleben.
	g = await _start(["chitin_plate", "chitin_regen", "m_second_skin"])
	g.player.hp = 1
	g.player.iframes = 0.0
	g.player.take_damage(1)
	_ok(g.player.alive and g.player.hp == 1, "Zweite Haut: tödlicher Treffer überlebt")
	g.player.iframes = 0.0
	g.player.take_damage(1)
	_ok(not g.player.alive, "Zweite Haut: nur einmal pro Level")
	# Dornenpanzer: Treffer schleudert zwölf Stacheln.
	g = await _start(["chitin_plate", "chitin_thorns", "m_thorn_armor"])
	g.player.max_hp = 9
	g.player.hp = 9
	g.player.iframes = 0.0
	g.bullets.player_bullets.clear()
	g.player.take_damage(1)
	_ok(g.bullets.player_bullets.size() >= 12, "Dornenpanzer: zwölf Stacheln beim Treffer")
	# Gewitterchor: Resonanzschuss springt als Blitz.
	g = await _start(["resonance_beat", "resonance_chain", "m_thunder_choir"])
	g.bullets.player_bullets.clear()
	g.player._fire_rhythm()
	_ok(not g.bullets.player_bullets.is_empty() and int(g.bullets.player_bullets[0].get("lchain", 0)) == 5,
		"Gewitterchor: Resonanzschuss springt auf fünf Gegner")
	# Echoschild: aufgeladen wirft der Ring Geschosse zurück.
	g = await _start(["resonance_calm", "resonance_pulse", "m_echo_shield"])
	g.masters.echo_t = 2.0
	g.bullets.enemy_bullets.clear()
	g.bullets.player_bullets.clear()
	g.bullets.spawn_enemy(g.player.position + Vector2(30, 0), Vector2(-100, 0), 1, "ebullet_orb", {})
	g.masters._update_echo(0.016)
	_ok(float(g.bullets.enemy_bullets[0].life) <= 0.0 and not g.bullets.player_bullets.is_empty()
		and (g.bullets.player_bullets[0].v as Vector2).x > 0.0, "Echoschild: Geschoss zurückgeworfen")
	g.masters.echo_t = 0.0
	g.masters.echo_cd = 0.0
	g.masters.echo_charge = 0.0
	g.player.autofire = true
	for i in range(int(3.2 / 0.05)):
		g.masters._update_echo(0.05)
	_ok(g.masters.echo_t > 0.0, "Echoschild: drei Sekunden Dauerfeuer laden den Ring")
	g.player.autofire = false
	# Goldrausch: jeder sechste Gegner verliert einen goldenen Tropfen.
	g = await _start(["nectar_bargain", "nectar_gluttony", "m_gold_rush"])
	var gold := 0
	for i in range(12):
		var n_before: int = g.pickups.size()
		g.masters.on_kill(_enemy(g, Vector2(600, 100 + i * 20)))
		for p in g.pickups.slice(n_before):
			if is_instance_valid(p) and p.value == 5 and p.magnet:
				gold += 1
	_ok(gold == 2, "Goldrausch: zwei goldene Tropfen aus zwölf Abschüssen (%d)" % gold)
	# Lebensnektar: volle Reserve heilt ein fehlendes Leben.
	g = await _start(["nectar_convert", "nectar_overflow", "m_life_nectar"])
	g.player.max_hp = 4
	g.player.hp = 2
	for i in range(30):
		g.player.add_nectar(1)
	_ok(g.player.hp == 3 and g.player.life_reserve == 0, "Lebensnektar: 30 Tropfen heilen ein Leben")
	# Ohne Meister: Eltern allein lösen keine Meisterwirkung aus.
	g = await _start(["chitin_plate", "chitin_regen"])
	g.player.hp = 1
	g.player.iframes = 0.0
	g.player.take_damage(1)
	_ok(not g.player.alive, "Ohne Meisterevolution keine Zweite Haut")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Debug-Sprung, Pollen
func _boss_jump() -> void:
	Save.new_campaign("normal", 9393)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(4, 0)
	await _wait(0.3)
	var g = app.game
	g.player.iframes = 1.0e6
	g.director.intro_t = 0.0
	await _wait(0.5)
	app.debug_to_boss()
	await _wait(0.3)
	var d = g.director
	var spawned_before: int = d.enemies_spawned
	var section_before: int = d.section
	await _wait(3.0)
	_ok(d.boss_started and d.miniboss_done and section_before >= Data.level(4).sections.size(),
		"Debug-Sprung: Abschnitte und Zwischengegner beendet")
	_ok(d.enemies_spawned == spawned_before, "Debug-Sprung: keine neuen Wellen während des Bosskampfs")
	# Pollenwolken: Explosionswolken deutlich durchsichtiger als zuvor (Deckkraft 0,22 → 0,077).
	var src := FileAccess.get_file_as_string("res://scripts/game/fx.gd")
	_ok(src.contains("fade *= 0.25 if bool(h.get(\"burst\", false)) else 0.32"), "Pollenwolken: Explosionswolken durchsichtiger")
	app.menu_main()
	await _wait(0.2)

# ------------------------------------------------------------------ Sammelbuch
func _collection() -> void:
	Save.profile["masters_seen"] = ["m_gold_rush"]
	app.clear_screens()
	var scr = app.push_screen("res://scripts/screens/fusion_screen.gd", {}, 0.0)
	await _wait(0.1)
	var masters := 0
	var unknown := 0
	for it in scr.items:
		if String(it.get("id", "")).begins_with("master:"):
			masters += 1
			if String(it.text).begins_with("???"):
				unknown += 1
	_ok(masters == 12 and unknown == 11, "Sammelbuch: zwölf Meister, unentdeckte als ??? (%d/%d)" % [masters, unknown])
	app.menu_main()
	await _wait(0.2)
