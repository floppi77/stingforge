extends Node2D
## Runde 2: reale Player-API; keine Produktionsobjekte ersetzen oder stubben.
var mode := "campaign"
var player: Player
var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	App.clear_screens()
	_test_unpurchased_gate()
	_test_capacity_and_purchases()
	_test_unpurchased_lifecycle()
	_test_regeneration_and_overflow()
	_test_shield_stability()
	_test_shield_rings()
	_test_orbit_reach_and_composition()
	_test_bastion_on_purchased_shield()
	_test_run_score_income()
	await _finish()

func _build(cfg: Dictionary = {}) -> void:
	if is_instance_valid(player):
		player.free()
	player = Player.new()
	add_child(player)
	player.set_physics_process(false)
	player.setup(cfg)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _test_unpurchased_gate() -> void:
	_build({"upgrades": {"base": 1, "shield": 0},
		"shop": {"extra_shield": 3, "shield_regen": 3},
		"evolutions": [{"id": "chitin_bastion", "level": 1}, {"id": "nectar_overflow", "level": 1}]})
	_check(not player.shield_active(), "Taktik0: gespeicherte Werkstatt/Evo aktivieren kein Schild")
	_check(player.shield_max == 0 and player.shield_hits == 0, "Taktik0: exakt null Kapazität und Ladungen")
	player.add_nectar(1)
	_check(player.shield_hits == 0, "Taktik0: Nektarstau erzeugt keine Ladung")
	var hp_before := player.hp
	_check(player.take_damage(1) and player.hp == hp_before - 1, "Taktik0: Treffer geht an HP statt an ein Phantom-Schild")

## Feste Simulationszeit am echten Physics-Callback: kein Warten auf Wandzeit,
## keine Ersatz-Timer und keine Aufrufe einzelner interner Timerfunktionen.
func _tick(seconds: float) -> void:
	player._physics_process(seconds)

func _test_capacity_and_purchases() -> void:
	for difficulty_id in ["relaxed", "normal", "expert"]:
		_build({"difficulty": difficulty_id, "nectar": 10000,
			"shop": {"extra_shield": 3, "shield_regen": 3},
			"evolutions": [{"id": "chitin_bastion", "level": 1}]})
		for level in range(1, 4):
			var before := player.nectar
			var result := player.try_buy("shield")
			_check(bool(result.ok), "%s: taktischer Kauf%d erfolgreich" % [difficulty_id, level])
			_check(before - player.nectar == [25, 70, 130][level - 1], "Schild%d: echte Kaufkosten" % level)
			_check(player.shield_max == level and player.shield_hits == level,
				"%s: Taktik%d hat exakt%d Kapazität/Ladungen trotz Shop/Evo" % [difficulty_id, level, level])
			_check(player.shield_active(), "Gekauftes, geladenes Schild ist aktiv")
		player.shield_hits = 0
		_check(player.shield_active(), "Gekauftes, leeres Schild bleibt für HUD aktiv")
		var before_max := player.nectar
		_check(not bool(player.try_buy("shield").ok) and player.nectar == before_max,
			"Schild3: kein weiterer Kauf oder Verbrauch")
		player.reset_for_checkpoint({"upgrades": {"base": 1, "shield": 2}})
		_check(player.shield_max == 2 and player.shield_hits == 2, "Checkpoint stellt exakt gekaufte Kapazität her")
	_build({"upgrades": {"shield": 1}, "nectar": 1000})
	player.shield_hits = 0
	player.try_buy("shield")
	_check(player.shield_max == 2 and player.shield_hits == 1, "Leeres Schild1→2 erhält nur eine neue Ladung")
	player.try_buy("shield")
	_check(player.shield_max == 3 and player.shield_hits == 2, "Teilgeladenes Schild2→3 erhält nur eine neue Ladung")

func _test_unpurchased_lifecycle() -> void:
	_build({"shop": {"extra_shield": 3, "shield_regen": 3},
		"evolutions": [{"id": "chitin_bastion", "level": 1}, {"id": "nectar_overflow", "level": 1}]})
	_tick(120.0)
	_check(player.shield_hits == 0 and is_zero_approx(player.shield_regen_t), "Taktik0: auch nach120s keine Regeneration")
	_check(is_zero_approx(player.shield_regen_progress()), "Taktik0: HUD-Ladefortschritt bleibt null")
	_check(not player.aura.visible, "Taktik0: keine sichtbare Aura")
	_check(is_zero_approx(player.evo_effect("shield_regen")), "Taktik0: Bastion bleibt konditional inaktiv")
	player.apply_shop_changes()
	_check(player.shield_max == 0 and player.shield_hits == 0, "Werkstatt anwenden aktiviert Taktik0 nicht")
	player.reset_for_checkpoint({"upgrades": {"base": 1, "shield": 0}})
	_check(player.shield_max == 0 and player.shield_hits == 0 and not player.shield_active(), "Checkpoint mit Taktik0 bleibt ohne Schild")
	_check(int(player.shop_levels.extra_shield) == 3, "Checkpoint erhält gespeicherte Werkstattstufe")
	player.nectar = 1000
	player.try_buy("shield")
	player.take_damage(1)
	_tick(0.1)
	player.upgrades.shield = 0
	player.apply_shop_changes()
	_check(player.shield_max == 0 and player.shield_hits == 0 and is_zero_approx(player.shield_regen_t), "Entzogene Taktik: apply_shop_changes leert Ladungen und Timer")
	_tick(120.0)
	_check(not player.aura.visible and player.shield_hits == 0, "Entzogene Taktik: weder Aura noch automatische Rückkehr")

func _test_regeneration_and_overflow() -> void:
	for level in range(1, 4):
		_build({"upgrades": {"base": 1, "shield": level}})
		_check(player.take_damage(1) and player.shield_hits == level - 1, "Schild%d verliert exakt eine Ladung" % level)
		_tick(6.0)
		_check(is_equal_approx(player.shield_regen_progress(), 0.5), "Schild%d meldet nach6s halbe Regeneration" % level)
		_tick(5.99)
		_check(player.shield_hits == level - 1, "Schild%d regeneriert nicht vor12s" % level)
		_tick(0.02)
		_check(player.shield_hits == level and is_zero_approx(player.shield_regen_t), "Schild%d regeneriert nach12s bis Kapazität" % level)
		player.apply_shop_changes()
		_check(player.shield_hits == level, "Werkstatt erhöht gekaufte Kapazität nicht")
	for shop_level in range(1, 4):
		_build({"upgrades": {"shield": 1}, "shop": {"shield_regen": shop_level}})
		player.take_damage(1)
		var duration: float = [8.0, 6.0, 4.0][shop_level - 1]
		_tick(duration - 0.01)
		_check(player.shield_hits == 0, "Schildaufladung%d: keine verfrühte Ladung" % shop_level)
		_tick(0.02)
		_check(player.shield_hits == 1, "Schildaufladung%d: reale Aufladung nach%.1fs" % [shop_level, duration])
	_build({"upgrades": {"base": 1, "shield": 2}, "evolutions": [{"id": "nectar_overflow", "level": 1}]})
	player.take_damage(1)
	player.add_nectar(1)
	_check(player.shield_hits == 2 and player.points == 8, "Nektarstau füllt gekauftes Schild und gibt Punkte")
	player.add_nectar(1)
	_check(player.shield_hits == 2, "Nektarstau überschreitet Kapazität nicht")

func _test_shield_stability() -> void:
	_check(String(ShopData.item("extra_shield").name) == "Schildstabilität", "Save-ID extra_shield heißt jetzt Schildstabilität")
	for level in range(1, 4):
		_build({"upgrades": {"shield": 1}, "shop": {"extra_shield": level}})
		var hp_before := player.hp
		var total_protection: float = [0.8, 1.05, 1.4][level - 1]
		var grace: float = [0.25, 0.5, 0.85][level - 1]
		_check(is_equal_approx(player.shop_mod("shield_grace"), grace), "Stabilität%d: Save-Stufe liefert exakten Zeitbonus" % level)
		_check(player.shield_max == 1 and player.shield_hits == 1, "Stabilität%d schenkt keine Kapazität" % level)
		_check(player.take_damage(1) and player.shield_hits == 0 and player.hp == hp_before, "Stabilität%d: letzter Schildpunkt fängt Treffer ab" % level)
		_check(is_equal_approx(player.iframes, total_protection), "Stabilität%d: gemessene Schutzzeit%.2fs nach Ladungsverlust" % [level, total_protection])
		_tick(total_protection - 0.01)
		_check(not player.take_damage(1) and player.hp == hp_before, "Stabilität%d schützt bis kurz vor Ende" % level)
		_tick(0.02)
		_check(player.take_damage(1) and player.hp == hp_before - 1, "Stabilität%d: Schutz endet nach vereinbarter Zeit" % level)
		_check(is_equal_approx(player.iframes, 1.3), "Stabilität%d verlängert HP-Treffer nicht" % level)
		_build({"shop": {"extra_shield": level}})
		_check(player.take_damage(1) and is_equal_approx(player.iframes, 1.3), "Stabilität%d ohne taktischen Kauf gewährt keinen freien Schutz" % level)
		_build({"upgrades": {"shield": 3}, "shop": {"extra_shield": level, "iframe_plus": 3}})
		for hit in range(3):
			player.iframes = 0.0
			player.take_damage(1)
			_check(player.shield_hits == 2 - hit and is_equal_approx(player.iframes, total_protection), "Stabilität%d gilt nach jeder verlorenen Ladung; Nachbrenner addiert nicht" % level)

func _test_shield_rings() -> void:
	_build({"upgrades": {"shield": 3}})
	_check(not player.aura is Sprite2D and player.aura.has_method("lines"), "Schild zeichnet eigene Wabenringe statt icon_shieldbar-Sprite")
	if not player.aura.has_method("lines"):
		return
	var start: Array = player.aura.call("lines")
	_check(start.size() == 3 and player.aura.visible, "Schild3 zeigt sofort drei Ladungsringe")
	for i in range(start.size()):
		var line: PackedVector2Array = start[i]
		# R4: Wabenhülle statt Pentagramm – geschlossenes Sechseck je Ladung.
		_check(line.size() == 7 and line[0].is_equal_approx(line[6]), "Ring%d ist ein geschlossenes Sechseck" % (i + 1))
		_check(is_equal_approx(absf(angle_difference(line[0].angle(), line[1].angle())), PI / 3.0), "Ring%d hat Wabenwinkel 60°" % (i + 1))
		if i > 0:
			_check(line[0].length() - (start[i - 1] as PackedVector2Array)[0].length() >= 4.0, "Ringradien bleiben deutlich getrennt")
	_tick(1.0)
	var advanced: Array = player.aura.call("lines")
	for i in range(3):
		var turn := angle_difference((start[i] as PackedVector2Array)[0].angle(), (advanced[i] as PackedVector2Array)[0].angle())
		_check(turn < 0.0 if i == 1 else turn > 0.0, "Ring%d dreht in vereinbarter Richtung" % (i + 1))
		_check(absf(turn) < 0.3, "Ring%d rotiert ruhig statt hektisch" % (i + 1))
	player.take_damage(1)
	_check((player.aura.call("lines") as Array).size() == 2, "Verlorene Ladung entfernt sofort genau einen Ring")
	Save.settings.access.reduce_effects = true
	_tick(0.0)
	_check((player.aura.call("lines") as Array).size() == 2 and player.aura.visible, "Reduzierte Effekte erhalten alle Ladungsringe")
	player.iframes = 0.0
	player.take_damage(1)
	_check((player.aura.call("lines") as Array).size() == 1, "Eine Restladung zeigt genau einen Stern")
	player.iframes = 0.0
	player.take_damage(1)
	_check((player.aura.call("lines") as Array).is_empty() and not player.aura.visible, "Leeres Schild zeigt keinen Stern")
	_tick(12.01)
	_check((player.aura.call("lines") as Array).size() == 1, "Regenerierte Ladung zeigt automatisch wieder einen Stern")
	player.upgrades.shield = 0
	player.apply_shop_changes()
	_check((player.aura.call("lines") as Array).is_empty() and not player.aura.visible, "Shop-Apply mit Taktik0 entfernt sofort alle Sterne")
	player.reset_for_checkpoint({"upgrades": {"shield": 2}})
	_check((player.aura.call("lines") as Array).size() == 2, "Checkpoint synchronisiert Sternanzahl ohne nächsten Tick")
	Save.settings.access.reduce_effects = false
	_check(player.sprite.scale == Vector2.ONE and player.sprite.sprite_frames.get_frame_texture("default", 0).get_size() == Vector2(40, 32), "Bestehende Biene bleibt unverändert40×32")
	_check(is_equal_approx(Player.HIT_RADIUS, 4.6), "Schildsterne verändern Trefferkreis nicht")
	_check(player.play_bounds.position.y >= App.PLAY_TOP + 16.0 and player.play_bounds.end.y <= App.PLAY_BOTTOM - 16.0, "Bienenhöhe liest gemeinsame HUD-Grenzen passiv")

## Echter Game->BulletField-Weg ohne vollständiges Level oder Test-Doubles.
func _real_game(cfg: Dictionary) -> Game:
	_build(cfg)
	var game := Game.new()
	add_child(game)
	game.bullets = BulletField.new()
	game.add_child(game.bullets)
	game.fx = Fx.new()
	game.add_child(game.fx)
	game.player = player
	player.reparent(game)
	return game

func _test_orbit_reach_and_composition() -> void:
	for level in range(1, 4):
		var game := _real_game({"shop": {"orbit": level}})
		player.autofire = true
		_tick(0.0)
		_check(game.bullets.player_bullets.size() == 2, "Kreisflug%d fügt keine Feuerquelle hinzu" % level)
		for i in range(12):
			game.bullets.update(1.0 / 60.0, player.position)
		for bullet in game.bullets.player_bullets:
			var radius := (bullet.p as Vector2).distance_to(player.position)
			_check(is_equal_approx(radius, [110.0, 142.0, 166.0][level - 1]), "Kreisflug%d erreicht real den neuen Radius" % level)
			_check(is_equal_approx(float(bullet.orbit_w), 3.6 if level == 3 else 2.4), "Kreisflug%d wahrt Stufe3-Temposteigerung" % level)
		game.free()
	var game := _real_game({"weapon": "plasma", "upgrades": {"plasma": 3},
		"shop": {"orbit": 3, "wave": 2, "homing": 2, "spiral": 3}})
	player.autofire = true
	_tick(0.0)
	_check(game.bullets.player_bullets.size() == 4, "Plasma3+Spirale: drei Hauptkugeln und eine begrenzte Zusatzkugel")
	for bullet in game.bullets.player_bullets:
		_check(String(bullet.art) == "bullet_plasma" and float(bullet.splash) >= 28.0, "Komposition erhält Plasma-Material und Flächenwirkung")
		_check(is_equal_approx(float(bullet.orbit_r), 166.0) and absf(float(bullet.wave_amp)) > 0.0 and float(bullet.homing) > 0.0, "Jede Haupt-/Spiralkugel trägt Kreisflug+Welle+Zielsuche gleichzeitig")
	var a: Dictionary = game.bullets.player_bullets[0]
	var b: Dictionary = game.bullets.player_bullets[1]
	for i in range(12):
		game.bullets.update(1.0 / 60.0, player.position, [Vector2(430, 210)])
	_check((a.p as Vector2).distance_to(b.p) > 12.0, "Komponierte Plasma-Kugeln bleiben unterscheidbar statt zu stapeln")
	game.free()

func _test_bastion_on_purchased_shield() -> void:
	for level in range(1, 4):
		var game := _real_game({"upgrades": {"shield": level}, "evolutions": [{"id": "chitin_bastion", "level": 1}]})
		_check(player.shield_max == level and player.shield_hits == level, "Bastion bei Taktik%d erhöht Kapazität nicht" % level)
		var nearby := game.bullets.spawn_enemy(player.position + Vector2(25, 0), Vector2.ZERO, 1, "ebullet_orb")
		var outside := game.bullets.spawn_enemy(player.position + Vector2(150, 0), Vector2.ZERO, 1, "ebullet_orb")
		player.take_damage(1)
		_check(not game.bullets.enemy_bullets.has(nearby) and game.bullets.enemy_bullets.has(outside), "Bastion%d: Gegenimpuls räumt echte nahe Geschosse, nicht entfernte" % level)
		_check(is_equal_approx(player.shield_regen_duration(), 7.8), "Bastion%d:35Prozent kürzere Regeneration" % level)
		_tick(7.79)
		_check(player.shield_hits == level - 1, "Bastion%d regeneriert nicht vor7.8s" % level)
		_tick(0.02)
		_check(player.shield_hits == level, "Bastion%d regeneriert real nach7.8s" % level)
		game.free()

func _test_run_score_income() -> void:
	var saved_campaign := Save.campaign.duplicate(true)
	var saved_active := Save.active_campaign
	var saved_mode := App.mode
	for game_mode in ["campaign", "rush", "training"]:
		Save.new_campaign("normal", 4281)
		App.mode = game_mode
		var game := _real_game({"points": 500, "upgrades": {"base": 1}, "evolutions": [{"id": "nectar_overflow", "level": 1}]})
		game.mode = game_mode
		player.add_points(120)
		_check(player.points == 620, "%s: add_points ändert Einnahmen nicht" % game_mode)
		var expected := 0 if game_mode == "training" else 120
		_check(int(Save.campaign.run_score) == expected, "%s: kumulativer Runscore erhält genau erlaubte Einnahmen" % game_mode)
		player.points -= 200 # Werkstattguthaben ausgeben, kein Einkommen zurücknehmen.
		_check(int(Save.campaign.run_score) == expected, "%s: Werkstattverbrauch mindert Runscore nicht" % game_mode)
		player.add_nectar(3)
		expected = 0 if game_mode == "training" else 144
		_check(player.points == 444, "%s: Nektarstau-Punktewert bleibt8 jeNektar" % game_mode)
		_check(int(Save.campaign.run_score) == expected, "%s: Nektarstau läuft ebenfalls über die echte Runscore-Einnahme" % game_mode)
		player.add_points(0)
		player.add_points(-10)
		_check(int(Save.campaign.run_score) == expected, "%s: null/negative Beträge sind kein Runscore-Einkommen" % game_mode)
		game.free()
	Save.campaign = saved_campaign
	Save.active_campaign = saved_active
	App.mode = saved_mode

func _finish() -> void:
	if is_instance_valid(player):
		player.free()
	for voice in Audio.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	Audio._sfx_cache.clear()
	Audio._music_cache.clear()
	for i in range(8):
		await get_tree().process_frame
	print("STINGFORGE_R2_PLAYER checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		print("FAIL " + failure)
	print("STINGFORGE_R2_PLAYER_OK" if failures.is_empty() else "STINGFORGE_R2_PLAYER_FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)
