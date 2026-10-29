extends Node2D
## Deterministische Tests an der realen Player -> BulletField-Schnittstelle.
var field: BulletField
var player: Player
var failures: Array[String] = []
var checks := 0
var pulse_events := 0
var shield_pulse_events := 0
var pollen_events := 0
var pollen_strength := 0.0

func player_pulse(_pos: Vector2) -> void:
	pulse_events += 1

func shield_break_pulse(_pos: Vector2) -> void:
	shield_pulse_events += 1

func spawn_pollen(_pos: Vector2, strength: float) -> void:
	pollen_events += 1
	pollen_strength = strength

func spawn_player_bullet(pos: Vector2, velocity: Vector2, damage: float, art: String, opts: Dictionary = {}) -> Dictionary:
	return field.spawn_player(pos, velocity, damage, art, opts)

func _ready() -> void:
	App.clear_screens()
	field = BulletField.new()
	add_child(field)
	_check_orbit_separation()
	_check_composed_motion()
	_check_weapon_patterns()
	_check_shield_contract()
	_check_rate_progression()
	_check_resonance_progression()
	_check_persisted_health_and_companions()
	_check_economy()
	_check_fractional_evolutions()
	_check_capacity_accounting()
	_check_directional_orbits()
	_check_tactical_purchases()
	_check_player_evolution_events()
	_check_rush_health()
	await finish("STINGFORGE_WEAPONS")

func finish(label: String) -> void:
	if is_instance_valid(player):
		player.free()
	field.free()
	# Dummy-Audiotreiber hält Playbacks bis zum nächsten Audiotakt.
	for voice in Audio.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	Audio._sfx_cache.clear()
	Audio._music_cache.clear()
	for i in range(8):
		await get_tree().process_frame
	print("%s checks=%d failures=%d" % [label, checks, failures.size()])
	for failure in failures:
		print("FAIL " + failure)
	print(label + ("_OK" if failures.is_empty() else "_FAILED"))
	get_tree().quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func build(weapon: String, shop: Dictionary = {}, evolutions: Array = [], saved_max_hp: int = 3, start_hp: int = -1) -> void:
	if player != null:
		player.free()
	field.clear()
	player = Player.new()
	add_child(player)
	player.set_physics_process(false)
	var cfg := {"weapon": weapon, "upgrades": {"base": 1, "plasma": 3, "fan": 3, "lightning": 3}, "shop": shop, "evolutions": evolutions, "max_hp": saved_max_hp}
	if start_hp >= 0:
		cfg["hp"] = start_hp
	player.setup(cfg)
	player.autofire = true
	player._handle_firing(0.0)

func _check_orbit_separation() -> void:
	build("plasma", {"orbit": 3})
	for i in range(12):
		field.update(1.0 / 60.0, player.position)
	var a: Vector2 = field.player_bullets[0].p
	var b: Vector2 = field.player_bullets[1].p
	var c: Vector2 = field.player_bullets[2].p
	check(a.distance_to(b) > 12.0 and b.distance_to(c) > 12.0, "Plasma+Kreisflug: drei unterscheidbare Kugeln statt Überlappungsstapel")

func _check_composed_motion() -> void:
	field.clear()
	var plain := field.spawn_player(Vector2(220, 270), Vector2(430, 90), 18.4, "bullet_plasma", {"orbit_r": 86.0})
	var combo := field.spawn_player(Vector2(220, 270), Vector2(430, 90), 18.4, "bullet_plasma", {"orbit_r": 86.0, "wave_amp": 30.0, "homing": 4.0})
	for i in range(15):
		field.update(1.0 / 60.0, Vector2(200, 270), [Vector2(380, 180)])
	check((plain.p as Vector2).distance_to(combo.p) > 8.0, "Kreisflug+Welle+Zielsuche: messbar andere Bahn als nackter Kreisflug")
	check(combo.has("prev_p"), "Echte Kollisionssegmente: prev_p wird bereitgestellt")

func _check_weapon_patterns() -> void:
	build("plasma", {"spiral": 3, "orbit": 3, "wave": 2})
	var spiral: Dictionary = field.player_bullets.back()
	check(String(spiral.art) == "bullet_plasma" and float(spiral.splash) >= 28.0, "Spirale erbt Plasma-Material und Flächenwirkung")
	check(float(spiral.get("orbit_r", 0.0)) > 0.0, "Spirale+Kreisflug wirkt auch auf Zusatzgeschoss")
	check(float(field.player_bullets[0].get("wave_amp", 0.0)) > 0.0, "Player reicht Kreisflug und Welle gleichzeitig weiter")
	check(ShopData.blocker_of("wave", {"orbit": 1}) == "", "Kombinierbare Formen sind im Laden nicht gesperrt")

func _check_shield_contract() -> void:
	build("base")
	player.nectar = 1000
	for level in range(1, 4):
		check(bool(player.try_buy("shield").ok) and player.shield_active()
			and player.shield_max == level and player.shield_hits == level,
			"Taktischer Schildkauf%d aktiviert exakt%d Ladungen/Kapazität" % [level, level])
	player.shield_hits = 1
	player.iframes = 0.0
	player.take_damage(1)
	player._update_timers(12.0)
	check(player.shield_hits == 1 and int(player.upgrades.shield) == 3, "Gekauftes Schild lädt nach 12s; Kaufstufe bleibt erhalten")
	build("base", {"extra_shield": 2})
	player._update_aura()
	check(not player.aura.visible and not player.shield_active() and player.shield_max == 0
		and player.shield_hits == 0, "Werkstatt allein schaltet weder Schild noch Aura frei")
	player.reset_for_checkpoint({})
	check(player.shield_hits == 0 and player.shield_max == 0 and is_zero_approx(player.shield_regen_t),
		"Checkpointreset erfindet ohne taktischen Schildkauf keine Ladungen")
	check(player.has_method("shield_active") and player.has_method("shield_regen_duration") and player.has_method("shield_regen_progress"), "HUD erhält einheitliche active/duration/progress-Schnittstelle")
	build("base", {"extra_shield": 1}, [{"id": "chitin_bastion", "level": 1}])
	check(is_zero_approx(player.evo_effect("shield_regen")) and not player.shield_active(),
		"Bastion bleibt ohne taktischen Kauf trotz Werkstatt inaktiv")
	player.nectar = 1000
	player.try_buy("shield")
	check(player.shield_max == 1 and is_equal_approx(player.shield_regen_duration(), 12.0 * 0.65),
		"Bastion verkürzt gekaufte Regeneration auf65Prozent ohne Extra-Kapazität")
	var pulse_before := shield_pulse_events
	player.iframes = 0.0
	player.take_damage(1)
	check(shield_pulse_events == pulse_before + 1 and player.shield_max == 1,
		"Bastion löst beim echten Schildverlust genau einen Gegenimpuls aus")
	build("base", {"extra_shield": 3, "shield_regen": 3}, [{"id": "nectar_overflow", "level": 1}, {"id": "chitin_bastion", "level": 1}])
	player.add_nectar(1)
	player._update_timers(24.01)
	check(not player.shield_active() and player.shield_max == 0 and player.shield_hits == 0,
		"Nektarstau+Werkstatt+Bastion erzeugen ohne taktischen Kauf niemals Schild")
	player.nectar = 1000
	player.try_buy("shield")
	player.shield_hits = 0
	player.add_nectar(1)
	check(player.shield_hits == 1 and player.shield_max == 1,
		"Nektarstau füllt nur bereits taktisch gekaufte Kapazität auf")

func _check_rate_progression() -> void:
	build("base", {"fire_rate": 2})
	var damage2 := player.last_volley_damage
	build("base", {"fire_rate": 3})
	check(player.last_volley_damage > damage2 and player.fire_interval() >= Player.MIN_INTERVAL, "Schnellfeuer-Stufe3 wird am Feuerratenlimit in Schaden umgewandelt")
	var counts: Array[int] = []
	for level in [2, 3]:
		build("base", {"burst": level})
		var emitted := field.player_bullets.size()
		for i in range(19):
			field.clear()
			player.fire_cd = 0.0
			player._handle_firing(0.0)
			emitted += field.player_bullets.size()
		counts.append(emitted)
	check(counts[1] > counts[0], "Salve-Stufe3 erzeugt alle4 statt alle5 Schüsse einen begrenzten Zusatzimpuls")

func _rhythm_damage(evolutions: Array) -> Array:
	build("base", {}, evolutions)
	var hits: Array = []
	for i in range(12):
		if i > 0:
			field.clear()
			player.fire_cd = 0.0
			player._handle_firing(0.0)
		for b in field.player_bullets:
			if String(b.art) == "bullet_plasma":
				hits.append(float(b.dmg))
	return hits

func _check_resonance_progression() -> void:
	var first := _rhythm_damage([{"id": "resonance_beat", "level": 1}])
	var second := _rhythm_damage([{"id": "resonance_beat", "level": 2}])
	check(first.size() == 1 and second.size() == 2, "Taktgeber-Stufe2 verstärkt häufiger statt seltener")
	var final := _rhythm_damage([{"id": "resonance_beat", "level": 1}, {"id": "resonance_final", "level": 1}])
	check(not final.is_empty() and not first.is_empty() and is_equal_approx(float(final[0]), float(first[0]) * 2.0), "Endton verdoppelt Resonanzschaden tatsächlich")

func _check_persisted_health_and_companions() -> void:
	build("base", {"extra_life": 3}, [{"id": "chitin_plate", "level": 2}], 8)
	check(player.max_hp == 8, "Checkpoint-MaxHP enthält Boni bereits; Laden darf sie nicht nochmals addieren")
	build("plasma", {"orbit": 1}, [{"id": "companion_add", "level": 2}, {"id": "swarm_echo", "level": 2}])
	player.upgrades["companion"] = 3
	field.clear()
	player._update_companions(0.01)
	var visible_count := 0
	for companion in player.companions:
		if companion.visible:
			visible_count += 1
	check(visible_count == 5 and field.player_bullets.size() == 5, "Alle fünf möglichen Begleiter sind sichtbar und feuern")
	var mirrored := true
	for b in field.player_bullets:
		mirrored = mirrored and String(b.art) == "bullet_plasma" and float(b.splash) >= 28.0
	check(mirrored, "Schwarmecho spiegelt Plasma-Material und Wirkung statt nur Feuerrate")

func _check_economy() -> void:
	build("base", {}, [{"id": "pollen_economy", "level": 2}])
	player.add_nectar(1, true, true)
	check(player.nectar == 3, "Sammelinstinkt2 gibt pro Blüte zwei zusätzliche Nektar")
	player.add_nectar(1, true, false)
	check(player.nectar == 4, "Sammelinstinkt wirkt nicht auf Beutetropfen von Gegnern")
	build("base", {}, [{"id": "pollen_economy", "level": 2}, {"id": "nectar_font", "level": 1}])
	player.on_boss_phase()
	check(player.nectar == 15, "Bossphasengeschenk ist keine Blüte und bekommt keinen Pickup-Bonus")
	build("base", {}, [{"id": "crit", "level": 2}])
	check(is_equal_approx(player.shot_power(), 7.4 * 1.28), "Angriffsmesswert berücksichtigt kritische Evolution im Erwartungswert")

func _check_fractional_evolutions() -> void:
	for amount in [1, 2]:
		build("base", {}, [{"id": "chitin_guard", "level": 1}])
		player.hp = 50
		player.max_hp = 50
		player.precision = true
		for i in range(4):
			player.iframes = 0.0
			player.take_damage(amount)
		check(player.hp == 50 - 3 * amount, "Panzerhaltung: vier Damage%d-Treffer kosten exakt%d HP" % [amount, 3 * amount])
	build("base", {}, [{"id": "chitin_guard", "level": 1}])
	player.hp = 50
	player.max_hp = 50
	player.precision = true
	player.take_damage(1)
	check(player.hp == 50, "Panzerhaltung nützt schon vor dem vierten Treffer bei3 Basis-HP")
	player.precision = false
	player.iframes = 0.0
	player.take_damage(1)
	player.precision = true
	player.iframes = 0.0
	player.take_damage(1)
	check(player.hp == 48, "Präzisionswechsel setzt Bruchschadensbank nicht zurück")
	build("base", {}, [{"id": "nectar_gluttony", "level": 1}])
	for i in range(5):
		player.add_nectar(1)
	check(player.nectar == 6, "Völlerei: fünf gewöhnliche Einzeldrops ergeben sechs Nektar")
	build("base", {}, [{"id": "nectar_gluttony", "level": 1}, {"id": "pollen_economy", "level": 2}])
	for i in range(5):
		player.add_nectar(1, true, true)
	check(player.nectar == 18, "Völlerei+Sammelinstinkt: fünf Blüten ergeben18 statt15 Nektar")
	build("base", {}, [{"id": "nectar_gluttony", "level": 1}, {"id": "nectar_font", "level": 1}, {"id": "pollen_economy", "level": 2}])
	player.on_boss_phase()
	check(player.nectar == 15, "Bossphasengeschenk bleibt15 ohne Blüten-/Völlerei-Pickupboni")

func _check_capacity_accounting() -> void:
	build("base")
	for capacity in [320, 319]:
		field.clear()
		for i in range(capacity):
			field.spawn_player(Vector2(200, 200), Vector2.ZERO, 1.0, "bullet_base")
		player.fire_cd = 0.0
		player._handle_firing(0.0)
		var accepted := 320 - int(capacity)
		check(player.last_volley_shots == accepted and is_equal_approx(player.last_volley_damage, 7.4 * float(accepted)), "Kapazität%d: Messwerte zählen nur%d wirklich erzeugte Kugeln" % [capacity, accepted])
		if accepted == 0:
			check(is_zero_approx(player.attack_dps()) and is_zero_approx(player.shot_power()), "Leere Salve nachCap darf nicht als Vor-erster-Schuss-Grundschaden gelten")

func _check_directional_orbits() -> void:
	build("base", {"orbit": 3, "back": 1, "side": 1})
	check(cos(float(field.player_bullets[2].orbit_a)) < -0.5, "Heck+Kreisflug startet hinter statt vor der Biene")
	check(sin(float(field.player_bullets[3].orbit_a)) < -0.5 and sin(float(field.player_bullets[4].orbit_a)) > 0.5, "Seiten+Kreisflug behalten obere/untere Abschussrichtung")

func _check_tactical_purchases() -> void:
	for id in ["fan", "lightning", "plasma", "companion", "bombs", "shield", "speed"]:
		build("base")
		player.upgrades[id] = 0
		player.nectar = 10000
		var previous_speed := player._speed()
		for level in range(1, 4):
			var before := player.nectar
			var paid := int(Data.upgrade(id).costs[level - 1])
			var result := player.try_buy(id)
			check(bool(result.ok) and int(player.upgrades[id]) == level and before - player.nectar == paid, "%s%d: Kauf erhöht Stufe und zieht korrekte Kosten ab" % [id, level])
			match id:
				"companion":
					field.clear()
					player.companion_cd = 0.0
					player._update_companions(0.0)
					check(field.player_bullets.size() == level, "Drohnenstufe%d erzeugt%d aktive Schützen" % [level, level])
				"bombs":
					var old_events := pulse_events
					player.bomb_cd = 0.0
					player._update_timers(0.001)
					check(pulse_events == old_events + 1 and is_equal_approx(player.bomb_cd, 17.0 - 2.0 * level), "Bombenstufe%d löst selbständig mit kürzerem Zyklus aus" % level)
				"speed":
					check(player._speed() > previous_speed and player.speed_level == level, "Tempostufe%d steigert reales Bewegungstempo" % level)
					previous_speed = player._speed()
		var old_level := int(player.upgrades[id])
		var old_nectar := player.nectar
		player.try_buy(id)
		check(int(player.upgrades[id]) == old_level and player.nectar == old_nectar, "%s: Maximalstufe kostet nichts und wird nicht verändert" % id)
	build("base")
	player.nectar = 100
	player.hp = player.max_hp - 1
	check(bool(player.try_buy("repair").ok) and player.hp == player.max_hp and player.nectar == 65, "Reparatur heilt genau1 und kostet35")
	check(not bool(player.try_buy("repair").ok) and player.nectar == 65, "Reparatur bei vollen HP verbraucht nichts")

func _check_player_evolution_events() -> void:
	build("base", {}, [{"id": "resonance_tuning", "level": 1}])
	var base_damage := player.dmg_mult()
	player.try_buy("plasma") # Maxstufe: ausrüsten statt weiterer Kauf.
	check(player.weapon == "plasma" and is_equal_approx(player.dmg_mult(), base_damage * 1.25), "Stimmung: echter Ausrüstungswechsel aktiviert25% mehr Schaden")
	player._update_timers(2.01)
	check(is_equal_approx(player.dmg_mult(), base_damage), "Stimmung endet nach2 Sekunden")
	build("base", {}, [{"id": "resonance_calm", "level": 1}])
	for i in range(10):
		player.fire_cd = 0.0
		player._handle_firing(0.0)
	check(is_equal_approx(player.calm_bonus, 0.2), "Ruhepol baut reale20% Schaden auf und überschreitet das Limit nicht")
	player.autofire = false
	player._handle_firing(1.0)
	check(is_zero_approx(player.calm_bonus), "Ruhepol fällt ohne Dauerfeuer ab")
	build("base", {}, [{"id": "resonance_pulse", "level": 1}])
	var before := pulse_events
	player._update_timers(3.0)
	check(pulse_events == before + 1 and is_equal_approx(player.pulse_cd, 6.0), "Druckwelle:3s Dauerfeuer lösen genau einen Impuls mit6s Cooldown aus")
	build("base", {}, [{"id": "pollen_trail", "level": 2}])
	var pollen_before := pollen_events
	player.vel = Vector2(100, 0)
	player._update_timers(0.23)
	check(pollen_events == pollen_before + 1 and is_equal_approx(pollen_strength, 2.0), "Pollenschleier2 emittiert stärkere Wolke bei Bewegung")
	build("base", {}, [{"id": "nectar_convert", "level": 1}])
	player.nectar = 10
	player.hp = player.max_hp - 1
	player._update_timers(20.01)
	check(player.nectar == 0 and player.hp == player.max_hp, "Umwandlung tauscht nach20s exakt10 Nektar gegen1 HP")
	build("base", {}, [{"id": "nectar_bargain", "level": 1}])
	player.upgrades["fan"] = 0
	check(player.upgrade_cost_for("fan") < 30, "Handel reduziert tatsächlichen Kaufpreis")
	build("base", {}, [{"id": "companion_form", "level": 1}, {"id": "companion_add", "level": 2}])
	check(is_zero_approx(player.evo_effect("companion_add")), "Begleiter-Evolution ohne gekaufte Drohne bleibt begründet inaktiv")
	player.upgrades["companion"] = 1
	player.vel = Vector2(100, 0)
	var attack_pos := player.companion_position(0, 3)
	player.vel = Vector2.ZERO
	check(attack_pos.distance_to(player.companion_position(0, 3)) > 10.0, "Formationsbegleiter wechseln tatsächlich zwischen Angriff und Kreisformation")
	player.vel = Vector2(-100, 0)
	check(attack_pos.distance_to(player.companion_position(0, 3)) > 10.0, "Rückflug verwendet die kompakte Kreisformation statt Angriffsreihe")

func _check_rush_health() -> void:
	if is_instance_valid(player):
		player.free()
	var game := Game.new()
	game.mode = "rush"
	game.bullets = field
	add_child(game)
	var cfg := {"difficulty": "normal", "hp": 7, "max_hp": 7, "shop": {"extra_life": 2}, "evolutions": [{"id": "chitin_plate", "level": 1}]}
	for reload_index in range(2):
		player = Player.new()
		game.add_child(player)
		game.player = player
		player.set_physics_process(false)
		player.setup(cfg)
		check(player.max_hp == 7 and player.hp == 7, "Rushreload%d: vier Basis-HP plus drei Boni bleiben konstant7" % reload_index)
		player.apply_shop_changes()
		check(player.max_hp == 7, "Rush Werkstatt-Neuberechnung behält vier Basis-HP")
		cfg.max_hp = player.max_hp
		player.free()
	game.free()
