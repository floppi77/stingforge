extends Node
## Live-Regressionspfade für Weltmechaniken der zweiten Runde.
var failures: Array[String] = []
var checks := 0
var completed: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func game(level: int = 1) -> Game:
	var g := Game.new()
	g.setup({"level": level})
	g.started = false
	return g

func _ready() -> void:
	await get_tree().process_frame
	Save.new_campaign("normal", 18031)
	_test_gravity()
	_test_player_gravity()
	_test_generators()
	_test_level_pressure()
	_test_glass()
	_test_impacts()
	_test_run_difficulty()
	_test_death_reset()
	check(completed == ["gravity", "player_gravity", "generators", "pressure", "glass", "impacts", "run_difficulty", "death_reset"], "alle Live-Suiten erreichen ihren Abschluss trotz Godot-Fehlerfortsetzung")
	check(checks >= 106, "alle vorgesehenen Live-Testpfade wurden wirklich ausgeführt")
	print("STINGFORGE_R2_WORLD checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	if failures.is_empty():
		print("STINGFORGE_R2_WORLD_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_death_reset() -> void:
	var g := game(8)
	g.player.nectar = 10000
	for i in range(3):
		check(bool(g.player.try_buy("shield").ok), "taktischer Schildkauf%d durch echten Playerpfad" % (i + 1))
		g.player.try_buy("plasma")
	g.player.try_buy("speed")
	g.player.shop_levels = {"extra_shield": 3, "shield_regen": 2}
	g.player._build_shop_mods()
	g.player.evolutions = [{"id": "chitin_guard", "level": 1}]
	g._take_checkpoint_snapshot()
	g.frozen_by_death = true
	g.player.alive = false
	g.continue_after_death()
	var correct := true
	for item in Data.UPGRADES:
		correct = correct and int(g.player.upgrades[item.id]) == (1 if String(item.id) == "base" else 0)
	check(correct, "Continue behält kostenloseBasis1 und setzt sämtliche taktischen Käufe0")
	check(g.player.weapon == "base" and g.player.speed_level == 0 and g.player.nectar == 0,
		"DeathContinue setzt Spezialwaffe/Tempo/Nektar zurück")
	check(not g.player.shield_active() and g.player.shield_max == 0 and g.player.shield_hits == 0 and is_zero_approx(g.player.shield_regen_t),
		"Continue entfernt Schildkapazität/Ladungen/Regeneration auch mit gekauftemShopschild")
	check(g.player.shop_levels == {"extra_shield": 3, "shield_regen": 2} and g.player.evo_has("chitin_guard"),
		"DeathReset erhält Shop und Evolutionen, ohne Schildfreischaltung")
	g.player._fire_volley()
	check(g.bullets.player_bullets.size() == 2, "kostenlose Basiswaffe feuert nach Continue ohne weiteren Kauf")
	g.free()
	completed.append("death_reset")

func _test_run_difficulty() -> void:
	var active_before := Save.active_campaign
	var menu_before: String = String(Save.settings.game.difficulty)
	for run in ["normal", "expert"]:
		Save.new_campaign(run, 18031)
		Save.active_campaign = false
		Save.settings.game.difficulty = "expert" if run == "normal" else "relaxed"
		var g := game(3)
		g.mode = "rush"
		var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(800, 270))
		check(is_equal_approx(e.fire_mult, float(Data.DIFFICULTY[run].fire_mult) * 1.08),
			"Enemy verwendet Lauf-%s statt geänderter Optionen bei inaktiverCampaign" % run)
		var standalone := Enemy.new()
		standalone.setup("beetle_grunt", Vector2(800, 270))
		check(is_equal_approx(standalone.fire_mult, float(Data.DIFFICULTY[run].fire_mult)),
			"EnemyFallback behält Training/Rush-Lauf-%s" % run)
		g.director.spawn_rng.seed = 7701
		g.director.spawn_t = 0.0
		g.director._update_spawner(0.0, Data.level(1).sections[0])
		var before := g.director.spawn_t
		Save.settings.game.difficulty = "relaxed" if run == "normal" else "normal"
		g.director.spawn_rng.seed = 7701
		g.director.spawn_t = 0.0
		g.director._update_spawner(0.0, Data.level(1).sections[0])
		check(is_equal_approx(g.director.spawn_t, before), "Director ignoriert Optionsänderung während Lauf-%s" % run)
		g.free()
		standalone.free()
	Save.active_campaign = active_before
	Save.settings.game.difficulty = menu_before
	Save.new_campaign("normal", 18031)
	completed.append("run_difficulty")

func _test_player_gravity() -> void:
	var g := game(10)
	g._on_hazard("gravity_field", {})
	Bindings.test_move_active = true
	for precision in [false, true]:
		# Die bestehende Bindings-Testbewegung plus genau derselbe Präzisionswert,
		# den die Eingabeschicht für diesen Physikframe an den echten Player liefert.
		Bindings._frame = Engine.get_physics_frames()
		Bindings._cur["precision"] = precision
		for speed_level in [0, 3]:
			g.player.speed_level = speed_level
			for input in [Vector2.UP, Vector2(1, -1).normalized(), Vector2(0, -0.1), Vector2(0.8, -0.2)]:
				for wind in [0.0, Player.BASE_SPEED * 0.62]:
					Bindings.test_move = input
					g.push = Vector2(0, wind)
					g.player.position = Vector2(400, 270)
					g.player._physics_process(1.0 / 60.0)
					check(g.player.vel.y < 0.0 and g.player.position.y < 270.0,
						"echter Player steigt beiGravity: Präzision%s Tempo%d Input%s Wind%.0f" % [precision, speed_level, input, wind])
					var requested: float = -input.y * 252.0 * (1.0 + 0.1 * float(speed_level)) * (0.45 if precision else 1.0)
					check(is_equal_approx(-g.player.vel.y, requested * 0.10), "Gravity lässt genau10Prozent der angeforderten Aufwärtsbewegung")
	Bindings.test_move_active = false
	Bindings.test_move = Vector2.ZERO
	Bindings._cur["precision"] = false
	Bindings._frame = -1
	g.free()
	completed.append("player_gravity")

func _test_impacts() -> void:
	var particles_before: float = float(Save.g("graphics.particles", 1.0))
	var reduce_before: bool = bool(Save.g("access.reduce_effects", false))
	var effects_before: float = float(Save.g("graphics.effects", 1.0))
	var amounts: Array[int] = []
	Save.settings.graphics.effects = 1.0
	for config in [[1.0, false], [0.25, false], [1.0, true], [0.0, false]]:
		Save.settings.graphics.particles = config[0]
		Save.settings.access.reduce_effects = config[1]
		var effect := Fx.new()
		effect._ready()
		seed(4012)
		var expected_rng := randf()
		seed(4012)
		effect.hit_spark(Vector2(400, 270), Color(0.6, 0.85, 1.0))
		check(is_equal_approx(randf(), expected_rng), "Trefferpartikel verändern keinen Gameplay-Zufallswurf")
		var fragments: Variant = effect.get("impacts")
		check(fragments is Array, "HitSpark erzeugt eigenen kurzlebigen Splitter/Staub-Pfad")
		if fragments is Array:
			amounts.append(fragments.size())
			for particle in fragments:
				check(float(particle.life) <= 0.24 and float(particle.size) <= 3.0,
					"Treffersplitter bleibt klein und lebt höchstens240ms")
				check((particle.tint as Color).b > (particle.tint as Color).r,
					"Glaseinschlag behält seine kühle Materialfarbe statt schwarzem Loch")
			effect.update(0.30)
			check(effect.impacts.is_empty(), "Trefferpartikel verschwinden ohne Folgekaskade vollständig")
		effect.free()
	if amounts.size() == 4:
		check(amounts[0] >= 3 and amounts[0] <= 6, "normaler Einschlag ist sichtbarer kontrollierter Kurzburst")
		check(amounts[1] > 0 and amounts[1] < amounts[0], "Partikelslider skaliert die Splittermenge")
		check(amounts[2] > 0 and amounts[2] < amounts[0], "reduce_effects reduziert Trefferpartikel")
		check(amounts[3] == 0, "Partikelslider0 deaktiviert die neuen Partikel vollständig")
	Save.settings.graphics.particles = 1.0
	Save.settings.access.reduce_effects = false
	var effect := Fx.new()
	effect._ready()
	for hit in range(2000):
		effect.hit_spark(Vector2(400, 270))
	check(effect.effects.size() <= 192, "auch extremer Einschlagsburst hat einen harten Effektcap")
	if effect.get("impacts") is Array:
		check(effect.impacts.size() <= 96, "höchstens96 gleichzeitige Trefferpartikel im ganzen Feld")
	effect.reset()
	var start := Time.get_ticks_usec()
	for frame in range(600):
		for hit in range(10):
			effect.hit_spark(Vector2(400, 270))
		effect.update(1.0 / 60.0)
	var total_us := Time.get_ticks_usec() - start
	print("WORLD_IMPACT_PERF frames=600 hits=6000 total_us=%d us_per_frame=%.2f effects=%d" % [total_us, float(total_us) / 600.0, effect.effects.size()])
	effect.update(1.0)
	check(effect.effects.is_empty(), "nach Laststopp bleiben keine Einschlageffekte hängen")
	effect.free()
	var g := game(6)
	var glass: Enemy = g.spawn_enemy("glass_drone", Vector2(600, 270))
	g.bullets.spawn_player(glass.position, Vector2.ZERO, 1, "bullet_base")
	g._update_collisions()
	check(not g.fx.impacts.is_empty() and (g.fx.impacts[0].tint as Color).b > (g.fx.impacts[0].tint as Color).r,
		"echter Game-Projektiltreffer wählt gläserne Materialfarbe")
	check(g.bullets.player_bullets.size() == 1, "rein optischer Einschlag erzeugt keine weiteren Kampfgeschosse")
	g.free()
	Save.settings.graphics.particles = particles_before
	Save.settings.access.reduce_effects = reduce_before
	Save.settings.graphics.effects = effects_before
	completed.append("impacts")

func _test_glass() -> void:
	var g := game(6)
	g._on_hazard("reflect_panel", {})
	var panel: Dictionary = g.fx.hazards[0]
	panel.p = Vector2(600, 270)
	check(g.fx.has_method("is_warning") and g.fx.has_method("warning_pulse_on"),
		"gemeinsamer Warninghelper steuert Rendering und Kollision")
	var warn := float(panel.warn)
	for step in range(8):
		panel.t = (float(step) + 0.32) * warn / 8.0
		g.bullets.clear()
		g.bullets.spawn_player(Vector2(700, 270), Vector2.ZERO, 1, "bullet_base")
		g.bullets.player_bullets[0].prev_p = Vector2(500, 270)
		g.bullets.spawn_player(Vector2(600, 270), Vector2.ZERO, 1, "bullet_base")
		g._update_hazards(0.0)
		check(g.bullets.player_bullets.size() == 2, "Glaswarnung %.3fs sperrt Schüsse noch nicht" % float(panel.t))
		if g.fx.has_method("is_warning"):
			check(g.fx.is_warning(panel), "alle vier On/Off-Paare liegen innerhalb derselben Warnzeit")
			check(g.fx.warning_pulse_on(panel) == (step % 2 == 0), "vier kurze Leuchtrahmenpulse statt Vollbildblitz")
	panel.t = warn
	g.bullets.clear()
	g.bullets.spawn_player(Vector2(700, 270), Vector2.ZERO, 1, "bullet_base")
	g.bullets.player_bullets[0].prev_p = Vector2(500, 270)
	g._update_hazards(0.0)
	check(g.bullets.player_bullets.is_empty(), "ab Ende der Warnzeit fängt Glas auch durchquerende echte Bulletsegmente ab")
	if g.fx.has_method("is_warning"):
		check(not g.fx.is_warning(panel) and not g.fx.warning_pulse_on(panel), "nach Aktivierung endet der leuchtende Warnrahmen vollständig")
	g.bullets.clear()
	g.bullets.spawn_player(Vector2(700, 90), Vector2.ZERO, 1, "bullet_base")
	g.bullets.player_bullets[0].prev_p = Vector2(500, 90)
	g._update_hazards(0.0)
	check(g.bullets.player_bullets.size() == 1, "Glas sperrt keinen Schuss außerhalb der sichtbaren Fläche")
	var rect := Rect2(panel.p - Vector2(float(panel.w), float(panel.h)) * 0.5, Vector2(float(panel.w), float(panel.h)))
	check(rect.position.y >= App.PLAY_TOP and rect.end.y <= App.PLAY_BOTTOM, "gesamtes Glas samt Warnrahmen bleibt im Spielfeld")
	g.free()
	completed.append("glass")

func _test_level_pressure() -> void:
	var rows: Array = []
	for level in range(1, 11):
		var g := game(level)
		g.player._fire_volley()
		var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(800, 270))
		g._spawn_boss()
		var d := Director.new()
		d.setup(Data.level(1), level, "campaign", 18031, 0)
		d.spawn_rng.seed = 4401
		var sum_interval := 0.0
		var repeated := false
		var seen := {}
		var previous_formation := ""
		for cycle in range(100):
			d.spawn_t = 0.0
			d._update_spawner(0.0, d.level_data.sections[0])
			sum_interval += d.spawn_t
			repeated = repeated or d.last_formation == previous_formation
			seen[d.last_formation] = true
			previous_formation = d.last_formation
		check(not repeated and seen.size() >= 2, "L%d reale Wellen nutzen authoredPool-Variety statt direkt gleicherFormation" % level)
		var row := {"level": level, "hp": e.max_hp, "boss_factor": g.boss.max_hp / float(Data.boss(g.boss.id).hp),
			"fire_seconds": e.fire_interval / e.fire_mult, "spawn_seconds": sum_interval / 100.0}
		rows.append(row)
		print("WORLD_LEVEL_FIXED " + JSON.stringify(row))
		if rows.size() > 1:
			var before: Dictionary = rows[rows.size() - 2]
			check(float(row.hp) > float(before.hp), "L%d Gegner-HP steigt explizit mit Level" % level)
			check(float(row.boss_factor) > float(before.boss_factor), "L%d Boss-HP-Faktor steigt unabhängig von Bossdaten" % level)
			check(float(row.fire_seconds) < float(before.fire_seconds), "L%d echte Gegnerkadenz wird dichter" % level)
			check(float(row.spawn_seconds) < float(before.spawn_seconds), "L%d echte Wellenkadenz wird dichter" % level)
		g.free()
		d.free()
	check(float(rows[9].boss_factor) / float(rows[0].boss_factor) >= 2.35, "L10 mindestens2.35-facher expliziter Boss-HP-Leveldruck")
	check(float(rows[9].hp) / float(rows[0].hp) >= 1.85 and float(rows[9].hp) / float(rows[0].hp) <= 2.1,
		"L10 Gegner-HP-Leveldruck merklich, aber begrenzt für taktische0-Builds")
	check(float(rows[9].fire_seconds) / float(rows[0].fire_seconds) < 0.8 and float(rows[9].fire_seconds) >= 1.0,
		"L10 effektive Feuerkadenz25Prozentplus, kein unkontrollierter Timer")
	check(float(rows[9].spawn_seconds) / float(rows[0].spawn_seconds) < 0.8 and float(rows[9].spawn_seconds) >= 2.4,
		"L10 mehr Wellen bei festem fairen Mindestabstand")
	completed.append("pressure")

func _test_generators() -> void:
	var g := game(8)
	for i in range(8):
		g._on_hazard("order_marker", {})
	check(g.fx.hazards.is_empty(), "Zahlenkreise ohne Funktion sind vollständig entfernt")
	check(g.enemies.size() == 2, "Generator-Verstärkung ist echt und auf zwei lebende Generatoren begrenzt")
	var entered := false
	for e in g.enemies:
		check(e.id == "generator_unit", "Generator-Verstärkung verwendet echte schießbare Gegner")
		var before: float = e.hp
		e.take_damage(1.0)
		check(e.hp < before, "Generator reagiert auf echten Schaden")
		for frame in range(180):
			e.age += 1.0 / 60.0
			e._move(1.0 / 60.0)
		entered = entered or e.position.x < 940.0
	check(entered, "verankerte Generatoren gelangen sichtbar aufs Feld statt bei1010 festzuhängen")
	check(not g.director.boss_started and not g.level_over,
		"Generatoren erfinden keine geheime Boss-Voraussetzung oder Sofortstrafe")
	g.director.boss_started = true
	var count := g.enemies.size()
	g._on_hazard("order_marker", {})
	check(g.enemies.size() == count, "keine Generator-Verstärkung nach Bossbeginn")
	g.free()
	completed.append("generators")

func _test_gravity() -> void:
	var g := game(10)
	var hp_before := g.player.hp
	g.player.position = Vector2(808, 270)
	g._on_hazard("gravity_pulse", {})
	check(g.fx.hazards.size() == 1 and String(g.fx.hazards[0].kind) == "gravity_field",
		"Kernpuls erzeugt abwärts gerichtetes Gravitationsfeld statt Schadensring")
	g._update_hazards(1.0 / 60.0)
	check(g.player.hp == hp_before, "Gravitation ist Kraftfeld und kein unverständlicher Kontaktschaden")
	check(g.has_method("gravity_pull"), "Game bietet separaten ungefilterten Gravity-Vertrag")
	if g.has_method("gravity_pull"):
		check((g.gravity_pull() as Vector2).is_equal_approx(Vector2(0, 226.8)),
			"normaler Grundflug: Gravity226.8 lässt25.2px/s Aufstieg")
		g.player.precision = true
		check((g.gravity_pull() as Vector2).is_equal_approx(Vector2(0, 102.06)),
			"Präzisionsflug: Gravity102.06 lässt11.34px/s Aufstieg")
		g._on_hazard("gravity_pulse", {})
		check((g.gravity_pull() as Vector2).y <= 102.061, "überlagerte Gravitationsfelder addieren sich nicht zur Falle")
	check(g.fx.has_method("field_geometry"), "Renderer liefert gemeinsame vertikale Feldgeometrie")
	if g.fx.has_method("field_geometry"):
		for line in g.fx.field_geometry({"kind": "gravity_field", "t": 0.0}):
			check(is_equal_approx((line.a as Vector2).x, (line.b as Vector2).x), "Gravitationsfeldlinie ist vertikal")
			check((line.a as Vector2).y >= App.PLAY_TOP and (line.b as Vector2).y <= App.PLAY_BOTTOM,
				"Feldlinie bleibt vollständig zwischen HUD-Grenzen")
			for arrow in line.arrows:
				check((arrow.tip as Vector2).y > (arrow.left as Vector2).y and (arrow.tip as Vector2).y > (arrow.right as Vector2).y,
					"Gravitationspfeil zeigt eindeutig abwärts")
	g.free()
	for direction in [-1.0, 1.0]:
		g = game(5)
		g._on_hazard("wind_zone", {"dir": direction})
		for frame in range(90):
			g.fx.update(1.0 / 60.0)
			g._update_push(1.0 / 60.0)
			g._update_hazards(1.0 / 60.0)
		check(signf(g.current_push().y) == direction, "Windvorzeichen%.0f wird nicht doppelt multipliziert" % direction)
		check(g.current_push().length() <= Player.BASE_SPEED * 0.62 + 0.001,
			"bestehende62-Prozent-Wind/Current-Grenze bleibt bestehen")
		g.free()
	completed.append("gravity")
