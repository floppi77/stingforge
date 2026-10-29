extends Node
## R11: Jede der 36 Evolutionen wirkt im echten Spiel nachweisbar (Vergleich mit und ohne),
## Splitter fliegen sichtbar nach oben und unten, Nektar-Boni werden korrekt verrechnet.

var app: Node
var g: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	Save.new_campaign("normal", 1111)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.4)
	g = app.game
	g.director.intro_t = 1.0e6
	g.player.set_physics_process(false)
	_sting()
	_swarm()
	_pollen()
	_chitin()
	_resonance()
	_nectar()
	_nectar_stacking()
	app.menu_main()
	await _wait(0.2)
	for f in fails:
		print("R11_FEHLER: " + f)
	print("R11_OK" if fails.is_empty() else "R11_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

## Gleicher Ausgangszustand für jede Prüfung: nur die angegebenen Evolutionen und Käufe.
func _reset(evos: Array, upgrades: Dictionary = {}) -> Node:
	var p = g.player
	var list: Array = []
	for e in evos:
		list.append(e if e is Dictionary else {"id": String(e), "level": 1})
	p.evolutions = list
	var u := {"base": 1, "fan": 0, "lightning": 0, "plasma": 0, "companion": 0, "bombs": 0, "shield": 0, "speed": 0}
	u.merge(upgrades, true)
	p.upgrades = u
	p.weapon = "base"
	p.shop_mods = {}
	p.apply_shop_changes()
	p.hp = p.max_hp
	p.iframes = 0.0
	p.precision = false
	p.autofire = false
	p.vel = Vector2.ZERO
	p.position = Vector2(200, 270)
	p.calm_bonus = 0.0
	p.tuning_t = 0.0
	p.shot_counter = 0
	p.fire_cd = 0.0
	p.hold_time = 0.0
	p.pulse_cd = 0.0
	p.drone_cd = 0.0
	p.companion_cd = 0.0
	p.pollen_cd = 0.0
	p.nectar = 0
	p.points = 0
	g.bullets.player_bullets.clear()
	g.bullets.enemy_bullets.clear()
	g.fx.hazards.clear()
	for e in g.enemies:
		if is_instance_valid(e):
			e.free()
	g.enemies.clear()
	g.last_kill_times.clear()
	g.swarm_call_cd = 0.0
	g.mark_table.clear()
	return p

func _enemy(pos: Vector2, hp: float = 5000.0) -> Node:
	var e = g.spawn_enemy("beetle_grunt", pos, {})
	e.hp = hp
	e.max_hp = hp
	e.shots = ""
	e.speed = 0.0
	e.behavior = "anchor"
	e.target_x = pos.x
	return e

func _new_bullets(before: int) -> Array:
	return g.bullets.player_bullets.slice(before)

# ------------------------------------------------------------------ Stachel
func _sting() -> void:
	var p := _reset([])
	p._fire_volley()
	var base_pierce := int(g.bullets.player_bullets[0].pierce)
	p = _reset(["pierce1"])
	p._fire_volley()
	_ok(int(g.bullets.player_bullets[0].pierce) == base_pierce + 1, "Durchschlagstachel: ein Ziel mehr")
	# Nadelkette setzt Durchschlagstachel voraus: ohne ihn wird sie nie angeboten.
	p = _reset([])
	Save.campaign.evolutions = []
	var offered := false
	for i in range(300):
		Save.campaign.seed = 5000 + i
		offered = offered or (app._roll_offers(3) as Array).has("pierce_master")
	Save.campaign.evolutions = [{"id": "pierce1", "level": 1}]
	var offered_with := false
	for i in range(300):
		Save.campaign.seed = 5000 + i
		offered_with = offered_with or (app._roll_offers(3) as Array).has("pierce_master")
	Save.campaign.evolutions = []
	_ok(not offered and offered_with, "Nadelkette wird nur mit Durchschlagstachel angeboten")
	p = _reset(["pierce1", "pierce_master"])
	_ok(p.evo_effect("pierce") >= 3.0, "Nadelkette mit Durchschlagstachel: mindestens drei Ziele mehr")
	# Splitter: sichtbar nach oben und unten, eigene Farbe, Stufe 2 in vier Richtungen.
	for lvl in [1, 2]:
		p = _reset([{"id": "splinter", "level": lvl}])
		var e: Node = _enemy(Vector2(480, 270))
		var b: Dictionary = g.bullets.spawn_player(Vector2(470, 270), Vector2(700, 0), 10.0, "bullet_base", {})
		var before: int = g.bullets.player_bullets.size()
		g._projectile_impact(b, e, Vector2(474, 270))
		var shards: Array = _new_bullets(before).filter(func(s): return int(s.get("proc_depth", 0)) == 1)
		var dirs := {}
		var up := false
		var down := false
		for s in shards:
			var v: Vector2 = s.v
			dirs[str(v.normalized().snapped(Vector2(0.01, 0.01)))] = true
			up = up or v.y < -100.0
			down = down or v.y > 100.0
		_ok(shards.size() == 2 * lvl and dirs.size() == 2 * lvl and up and down
			and (shards[0].tint as Color).is_equal_approx(g.SPLINTER_TINT),
			"Splittstachel Stufe %d: %d Splitter in verschiedene Richtungen, nach oben und unten, bernsteinfarben" % [lvl, 2 * lvl])
	# Gezielter Stich: etwa 14 % kritische Treffer.
	p = _reset(["crit"])
	var crits := 0
	for i in range(4000):
		g._shot_damage(10.0)
		if g._last_crit:
			crits += 1
	_ok(crits > 440 and crits < 680, "Gezielter Stich: etwa 14 %% kritisch (%d/4000)" % crits)
	p = _reset([])
	var base_rate: float = p.dmg_mult() / p.fire_interval()
	var base_dmg: float = p.dmg_mult()
	var base_int: float = p.fire_interval()
	p = _reset(["stinger_rapid"])
	_ok(p.dmg_mult() / p.fire_interval() > base_rate * 1.05, "Stakkato-Stachel: mehr Schaden pro Sekunde trotz −8 % Grundschaden")
	p = _reset(["heavy_sting"])
	_ok(absf(p.dmg_mult() / base_dmg - 1.35) < 0.01 and p.fire_interval() > base_int,
		"Schwerer Stachel: +35 % Schaden, langsamere Schussfolge")

# ------------------------------------------------------------------ Schwarm
func _swarm() -> void:
	var p := _reset([], {"companion": 1})
	var c0: int = p.companion_count()
	p = _reset(["companion_add"], {"companion": 1})
	_ok(p.companion_count() == c0 + 1, "Brutbegleiter: ein Begleiter mehr")
	p = _reset(["companion_form"], {"companion": 2})
	p.vel = Vector2.ZERO
	var orbit: Vector2 = p.companion_position(0, 2)
	p.vel = Vector2(120, 0)
	var line: Vector2 = p.companion_position(0, 2)
	_ok(orbit.distance_to(line) > 4.0, "Formationsbegleiter: im Vorwärtsflug andere Aufstellung als im Kreis")
	# Schwarmecho: Begleiter feuern schneller.
	var shots := {}
	for evos in [[], ["swarm_echo"]]:
		p = _reset(evos, {"companion": 2})
		var n := 0
		for i in range(240):
			var before: int = g.bullets.player_bullets.size()
			p.autofire = true
			p._update_timers(1.0 / 60.0)
			p._update_companions(1.0 / 60.0)
			n += g.bullets.player_bullets.size() - before
		shots[evos.size()] = n
	_ok(shots[1] > shots[0], "Schwarmecho: Begleiter feuern mehr (%d → %d in 4 s)" % [shots[0], shots[1]])
	# Opferdrohne fängt ein Geschoss in der Nähe ab.
	p = _reset(["drone_sacrifice"], {"companion": 1})
	g.bullets.spawn_enemy(p.position + Vector2(20, 0), Vector2.LEFT * 10.0, 1, "ebullet_orb")
	var eb: Array = g.bullets.enemy_bullets
	p._update_companions(1.0 / 60.0)
	_ok(not eb.is_empty() and float(eb[0].life) <= 0.0 and p.drone_cd > 0.0, "Opferdrohne: fängt ein Geschoss ab, dann Abklingzeit")
	# Zielmarkierung: sechs Treffer auf ein Ziel rufen den Schwarm (sechs Blitzbienen).
	p = _reset(["swarm_mark"])
	var t: Node = _enemy(Vector2(480, 270))
	var before: int = g.bullets.player_bullets.size()
	for i in range(6):
		g._mark_hit(t)
	var swarm: Array = _new_bullets(before).filter(func(s): return String(s.art) == "bullet_lightning")
	_ok(swarm.size() == 6, "Zielmarkierung: sechs Treffer rufen den Schwarmangriff")
	# Schwarmruf: fünf Abschüsse in drei Sekunden.
	p = _reset(["swarm_call"])
	var spare: Node = _enemy(Vector2(700, 200))
	before = g.bullets.player_bullets.size()
	for i in range(5):
		var k: Node = _enemy(Vector2(500 + i * 20, 300), 1.0)
		k.take_damage(5.0)
	var wave: Array = _new_bullets(before).filter(func(s): return String(s.art) == "bullet_lightning")
	_ok(wave.size() == 6 and is_instance_valid(spare), "Schwarmruf: fünf schnelle Abschüsse entfesseln die Schwarmwelle")

# ------------------------------------------------------------------ Pollen
func _pollen() -> void:
	var p := _reset(["pollen_trail"])
	p.vel = Vector2(120, 0)
	p._update_timers(0.05)
	_ok(g.fx.hazards.any(func(h): return String(h.kind) == "pollen_cloud" and bool(h.get("friendly", false))),
		"Pollenschleier: Flug hinterlässt Pollenwolken")
	p = _reset(["pollen_burst"])
	var e: Node = _enemy(Vector2(480, 270), 1.0)
	e.take_damage(5.0)
	_ok(g.fx.hazards.any(func(h): return String(h.kind) == "pollen_cloud" and bool(h.get("burst", false))),
		"Staubexplosion: Abschuss setzt eine Pollenwolke frei")
	p = _reset(["pollen_shield"])
	g.bullets.spawn_enemy(p.position + Vector2(60, 0), Vector2.LEFT * 100.0, 1, "ebullet_orb")
	g.bullets.spawn_enemy(p.position + Vector2(400, 0), Vector2.LEFT * 100.0, 1, "ebullet_orb")
	for b in g.bullets.enemy_bullets:
		g._apply_pollen_defenses(b)
	_ok(float(g.bullets.enemy_bullets[0].get("slow", 1.0)) <= 0.55 and float(g.bullets.enemy_bullets[1].get("slow", 1.0)) > 0.99,
		"Allergieaura: Geschosse nahe der Biene verlangsamt, ferne nicht")
	p = _reset([])
	var base_magnet: float = g.magnet_radius()
	p = _reset(["pollen_economy"])
	_ok(absf(g.magnet_radius() / base_magnet - 1.6) < 0.01, "Sammelinstinkt: Sammeleinzug +60 %")
	p.add_nectar(3, true, true)
	var after_blossom: int = p.nectar
	p.add_nectar(3, true, false)
	_ok(after_blossom == 4 and p.nectar == 7, "Sammelinstinkt: +1 nur je Blüte, nicht je Beutetropfen")
	# Sichttrübung: 15 % je Geschoss in eigener Pollenwolke.
	p = _reset(["pollen_blind"])
	g.spawn_pollen(p.position + Vector2(100, 0), 1.0)
	var gone := 0
	for i in range(1000):
		g.bullets.enemy_bullets.clear()
		g.bullets.spawn_enemy(p.position + Vector2(100, 0), Vector2.LEFT * 50.0, 1, "ebullet_orb", {"aimed": true})
		var b: Dictionary = g.bullets.enemy_bullets[0]
		g._apply_pollen_defenses(b)
		if float(b.life) <= 0.0:
			gone += 1
	_ok(gone > 100 and gone < 200, "Sichttrübung: etwa 15 %% der Geschosse erlöschen (%d/1000)" % gone)
	p = _reset([])
	var base_speed: float = p._speed()
	p = _reset(["wind_rider"])
	_ok(absf(p._speed() / base_speed - 1.12) < 0.01, "Windreiter: +12 % Tempo")
	p.vel = Vector2(150, 0)
	g.spawn_pollen(p.position, 1.0)
	_ok(float((g.fx.hazards[-1].vel as Vector2).x) > 0.0, "Windreiter: Pollenwolken driften mit der Biene")

# ------------------------------------------------------------------ Chitin
func _chitin() -> void:
	var p := _reset([])
	var base_hp: int = p.max_hp
	p = _reset(["chitin_plate"])
	_ok(p.max_hp == base_hp + 1, "Chitinpanzer: ein Trefferpunkt mehr")
	p = _reset(["chitin_regen"])
	p.hp = 1
	g._take_checkpoint_snapshot()
	_ok(p.hp == 2, "Häutung: Checkpoint heilt einen Punkt")
	p.iframes = 0.0
	p.take_damage(1, Vector2.ZERO)
	_ok(absf(p.iframes - (float(p.difficulty.iframes) + 0.3)) < 0.01, "Häutung: Schutzphase +0,3 s")
	p = _reset(["chitin_thorns"])
	var e: Node = _enemy(p.position + Vector2(4, 0), 500.0)
	g._update_collisions()
	_ok(e.hp < 500.0, "Stachelhaut: berührter Gegner nimmt Schaden")
	# Leichtbau: kleinere Trefferzone – ein knapp vorbeifliegendes Geschoss trifft nicht mehr.
	var hits := {}
	for evos in [[], ["chitin_light"]]:
		p = _reset(evos)
		g.bullets.spawn_enemy(p.position + Vector2(0, 5.4), Vector2.ZERO, 1, "ebullet_orb", {"r": 2.0})
		var b: Dictionary = g.bullets.enemy_bullets[0]
		b.prev_p = b.p
		b.r = 2.0
		var hp_before: int = p.hp
		g._update_collisions()
		hits[evos.size()] = p.hp < hp_before
	_ok(hits[0] and not hits[1], "Leichtbau: Trefferzone kleiner")
	p = _reset([])
	var plain_speed: float = p._speed()
	p = _reset(["chitin_light"])
	_ok(absf(p._speed() / plain_speed - 1.08) < 0.01, "Leichtbau: +8 % Tempo")
	# Panzerhaltung: im Präzisionsmodus 25 % weniger Schaden (über vier Treffer einer weniger).
	p = _reset(["chitin_guard"])
	p.max_hp = 9
	p.hp = 9
	p.precision = true
	for i in range(4):
		p.iframes = 0.0
		p.take_damage(1, Vector2.ZERO)
	_ok(p.hp == 6, "Panzerhaltung: vier Treffer im Präzisionsmodus kosten drei Leben (hp %d)" % p.hp)
	p = _reset([], {"shield": 1})
	var base_regen: float = p.shield_regen_duration()
	p = _reset(["chitin_bastion"], {"shield": 1})
	_ok(absf(p.shield_regen_duration() / base_regen - 0.65) < 0.01, "Bastion: Schild lädt 35 % schneller")
	p.shield_hits = 1
	g.bullets.spawn_enemy(p.position + Vector2(60, 0), Vector2.ZERO, 1, "ebullet_orb")
	p.take_damage(1, p.position + Vector2(10, 0))
	_ok(g.bullets.enemy_bullets.all(func(b): return float(b.life) <= 0.0 or (b.p as Vector2).distance_to(p.position) > 110.0),
		"Bastion: Schildtreffer löst einen Gegenimpuls aus")

# ------------------------------------------------------------------ Resonanz
func _rhythm_shot(p: Node) -> Dictionary:
	var before: int = g.bullets.player_bullets.size()
	p._fire_rhythm()
	var plasma: Array = _new_bullets(before).filter(func(s): return String(s.art) == "bullet_plasma")
	return plasma[0] if not plasma.is_empty() else {}

func _resonance() -> void:
	var p := _reset(["resonance_beat"])
	_ok(p.rhythm_interval() == 12, "Taktgeber: jede zwölfte Salve")
	p.autofire = true
	var before: int = g.bullets.player_bullets.size()
	for i in range(12):
		p.fire_cd = 0.0
		p._handle_firing(0.01)
	_ok(_new_bullets(before).any(func(s): return String(s.art) == "bullet_plasma"), "Taktgeber: die zwölfte Salve ist ein Resonanzschuss")
	p = _reset([{"id": "resonance_beat", "level": 2}])
	_ok(p.rhythm_interval() == 6, "Taktgeber Stufe 2: jede sechste Salve")
	p = _reset(["resonance_beat", "resonance_chain"])
	_ok(int(_rhythm_shot(p).get("chain", 0)) >= 2, "Kettenresonanz: Resonanzschuss springt auf zwei weitere Gegner")
	p = _reset(["resonance_beat"])
	var plain: Dictionary = _rhythm_shot(p)
	var plain_ratio: float = float(plain.dmg) / p.dmg_mult()
	p = _reset(["resonance_beat", "resonance_final"])
	var strong: Dictionary = _rhythm_shot(p)
	_ok(absf(float(strong.dmg) / p.dmg_mult() / plain_ratio - 2.0) < 0.05, "Endton: Resonanzschüsse doppelt so stark")
	p = _reset(["resonance_calm"])
	var calm_base: float = p.dmg_mult()
	p.autofire = true
	for i in range(20):
		p.fire_cd = 0.0
		p._handle_firing(0.01)
	_ok(absf(p.calm_bonus - 0.2) < 0.001 and p.dmg_mult() > calm_base * 1.15, "Ruhepol: Dauerfeuer bis +20 % Schaden")
	p = _reset(["resonance_pulse"])
	p.autofire = true
	for i in range(64):
		p._update_timers(0.05)
	_ok(p.pulse_cd > 0.0, "Druckwelle: drei Sekunden Dauerfeuer lösen die Ringwelle aus")
	p = _reset(["resonance_tuning"], {"fan": 1})
	var tune_base: float = p.dmg_mult()
	p._equip("fan")
	_ok(absf(p.tuning_t - 2.0) < 0.001 and absf(p.dmg_mult() / tune_base - 1.25) < 0.01, "Stimmung: Waffenwechsel gibt 2 s +25 % Schaden")

# ------------------------------------------------------------------ Nektar
func _nectar() -> void:
	var p := _reset(["nectar_overflow"])
	p.upgrades["base"] = p._weapon_max("base")
	p.add_nectar(5, true)
	_ok(p.points > 0, "Nektarstau: bei voller Waffenstufe geben Blüten Punkte")
	p = _reset(["nectar_convert"])
	p.hp = p.max_hp - 1
	p.nectar = 10
	p.convert_t = 0.0
	p._update_timers(0.01)
	_ok(p.hp == p.max_hp and p.nectar == 0, "Umwandlung: zehn Blütenstaub werden zu einem Leben")
	p = _reset(["nectar_gluttony"])
	p.add_nectar(10, true)
	_ok(p.nectar == 12, "Völlerei: 20 % mehr Blütenstaub")
	p = _reset([], {})
	var cost: int = p.upgrade_cost_for("fan")
	p = _reset(["nectar_bargain"])
	_ok(p.upgrade_cost_for("fan") < cost and absf(float(p.upgrade_cost_for("fan")) / float(cost) - 0.85) < 0.05,
		"Handel: Verbesserungen 15 %% günstiger (%d → %d)" % [cost, p.upgrade_cost_for("fan")])
	p = _reset(["nectar_font"])
	p.on_boss_phase()
	_ok(p.nectar == 15, "Nektarquelle: Bossphasenwechsel spendet 15 Blütenstaub")
	p = _reset(["nectar_scent"])
	var extra := 0
	for i in range(4000):
		extra += g.drop_amount(1, 0.99) - 1
	_ok(extra > 300 and extra < 500, "Duftspur: etwa 10 %% Zusatztropfen (%d/4000)" % extra)

## Alle Nektar-Boni zusammen: Duftspur und Werkstatt-Chance würfeln unabhängig (Erwartung
## addiert sich), Völlerei multipliziert das Eingesammelte, Sammelinstinkt nur bei Blüten.
func _nectar_stacking() -> void:
	var p := _reset(["nectar_scent", "nectar_gluttony", "pollen_economy"])
	p.shop_mods["nectar_plus"] = 0.3
	var kills := 4000
	var total := 0
	for i in range(kills):
		var drop: int = g.drop_amount(1)
		var count := clampi(drop, 1, 5)
		for j in range(count):
			var value := ceili(float(drop - j) / float(count))
			var before: int = p.nectar
			p.add_nectar(value, true, false)
			total += p.nectar - before
	var mean := float(total) / float(kills)
	var scent: float = p.evo_effect("nectar_drop_chance")
	var expected := (1.0 + scent + 0.3) * 1.2
	_ok(absf(mean - expected) < 0.06, "Nektar-Boni verrechnet: %.3f je Abschuss (erwartet %.3f = (1 + Duftspur %.2f + Werkstatt 0,30) × 1,2)" % [mean, expected, scent])
	_ok(absf(scent - 0.15) < 0.001, "Duftspur und Sammelinstinkt verschmolzen: 15 % statt 10 %")
