extends "res://tests/stingforge_weapons_probe.gd"
## 4 Waffen × 32 Werkstattartikel × 3 Stufen; beobachtete Wirkung statt Mod-Snapshot.
var measurements: Array = []
var matrix_cases := 0
var pair_cases := 0
var proc_trials := 0

func _ready() -> void:
	App.clear_screens()
	seed(6042026)
	field = BulletField.new()
	add_child(field)
	_check_weapon_levels()
	_check_workshop_matrix()
	_check_form_pairs()
	_check_motion_examples()
	_check_orbit_homing_separation()
	_check_evolution_consumers()
	_check_max_builds()
	var out := FileAccess.open("res://build/stingforge_weapons_metrics.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify({"weapon_shop_cases": matrix_cases, "form_pattern_cases": pair_cases,
			"checks": checks, "failures": failures, "measurements": measurements}, "\t"))
		out.close()
	print("MATRIX weapon_shop=%d form_patterns=%d proc_trials=%d evolutions=%d" % [matrix_cases, pair_cases, proc_trials, Data.EVOLUTIONS.size()])
	await finish("STINGFORGE_WEAPONS_MATRIX")

func _fire_once(clear_first: bool = true) -> void:
	if clear_first:
		field.clear()
	player.fire_cd = 0.0
	player._handle_firing(0.0)

func _check_weapon_levels() -> void:
	var specifications := {
		"base": [[1, 2, 14.8]],
		"fan": [[1, 4, 22.4], [2, 5, 28.0], [3, 6, 33.6]],
		# R4: Blitz Stufe 2 war schusszahlgleich mit Stufe 1; jetzt 2/3/4 Kugeln.
		"lightning": [[1, 2, 11.6], [2, 3, 17.4], [3, 4, 23.2]],
		"plasma": [[1, 1, 18.4], [2, 2, 36.8], [3, 3, 55.2]],
	}
	for weapon_id in specifications:
		for spec in specifications[weapon_id]:
			build(weapon_id)
			player.upgrades[weapon_id] = spec[0]
			_fire_once()
			check(field.player_bullets.size() == int(spec[1]), "%s%d: bekannte Schusszahl" % [weapon_id, spec[0]])
			check(is_equal_approx(player.last_volley_damage, float(spec[2])), "%s%d: bekannter Salvenschaden" % [weapon_id, spec[0]])
			for b in field.player_bullets:
				check(String(b.art) == "bullet_" + weapon_id, "%s: korrektes Waffenmaterial" % weapon_id)
				if weapon_id == "lightning":
					check(int(b.lchain) == 1 + int(spec[0]) and int(b.pierce) == 1, "Blitz: jede Stufe trägt zusätzliche Kettenwirkung")
				if weapon_id == "plasma":
					check(is_equal_approx(float(b.splash), 28.0), "Plasma: Flächenradius auf jeder Stufe")
			measurements.append({"weapon": weapon_id, "level": spec[0], "shots": field.player_bullets.size(), "volley_damage": player.last_volley_damage})

func _shop_context(id: String, level: int) -> Dictionary:
	var shop := {}
	for prerequisite in ShopData.item(id).get("req", []):
		shop[String(prerequisite[0])] = int(prerequisite[1])
	if id == "start_heal":
		shop["extra_life"] = 3
	if id == "shield_regen":
		shop["extra_shield"] = 1
	if level > 0:
		shop[id] = level
	return shop

func _check_workshop_matrix() -> void:
	check(ShopData.ITEMS.size() == 32, "Werkstatt enthält genau32 prüfbare Artikel")
	for weapon_id in Data.WEAPON_ORDER:
		for item in ShopData.ITEMS:
			var id := String(item.id)
			var previous := _shop_outcome(weapon_id, id, 0)
			for level in range(1, 4):
				var result := _shop_outcome(weapon_id, id, level)
				matrix_cases += 1
				check(_different(previous, result), "%s × %s%d: spürbare Steigerung gegenüber voriger Stufe" % [weapon_id, id, level])
				check(player.fire_interval() >= Player.MIN_INTERVAL, "%s%d: Feuertakt bleibt begrenzt" % [id, level])
				measurements.append({"weapon": weapon_id, "shop": id, "level": level, "observed": result})
				previous = result

func _different(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return true
	for i in range(a.size()):
		if absf(float(a[i]) - float(b[i])) > 0.0001:
			return true
	return false

func _game_seam() -> Game:
	var g := Game.new()
	g.player = player
	g.bullets = field
	g.difficulty = Data.DIFFICULTY.normal
	g.fx = Fx.new()
	g.add_child(g.fx)
	return g

func _shop_outcome(weapon_id: String, id: String, level: int) -> Array:
	build(weapon_id, _shop_context(id, level), [], 3, 1)
	var g := _game_seam()
	var result: Array = []
	match id:
		"shield_regen":
			player.nectar = 1000
			player.try_buy("shield")
			player.iframes = 0.0
			player.take_damage(1)
			var duration := player.shield_regen_duration()
			player._update_timers(duration)
			result = [duration if player.shield_hits == 1 and player.shield_max == 1 else -1.0]
		"extra_shield":
			player.nectar = 1000
			player.try_buy("shield")
			player.iframes = 0.0
			var hp := player.hp
			player.take_damage(1)
			# Tatsächlicher Schutz bis kurz vor Ablauf; danach muss ein HP-Treffer wirken.
			var grace := player.iframes
			var protected := player.hp == hp and not player.take_damage(1)
			player._update_timers(grace - 0.01)
			protected = protected and not player.take_damage(1) and player.hp == hp
			player._update_timers(0.02)
			var expired := player.take_damage(1) and player.hp == hp - 1
			result = [grace if protected and expired and player.shield_max == 1 and player.shield_hits == 0 else -1.0]
		"extra_life": result = [player.max_hp]
		"iframe_plus": result = [player.iframe_time()]
		"bomb_radius": result = [g.player_pulse_radius()]
		"bomb_charge": result = [player.bomb_cycle()]
		"magnet": result = [g.magnet_radius()]
		"nectar_plus": result = [g.nectar_bonus_chance()]
		"start_heal": result = [player.hp]
		"boss_bane": result = [g._shot_damage(100.0, true)]
		"crit":
			seed(4171)
			var total := 0.0
			for trial in range(600):
				total += g._shot_damage(100.0)
			result = [total / 600.0]
		"graze":
			field.clear()
			field.spawn_enemy(player.position + Vector2(0, 20), Vector2.ZERO, 1, "ebullet_orb")
			g._update_collisions()
			result = [player.points]
		"combo":
			var enemy := Enemy.new()
			enemy.score = 100
			g._on_enemy_killed(enemy)
			result = [player.points]
			enemy.free()
		"convert_bonus":
			Save.campaign.shop = _shop_context(id, level)
			var conversion = load("res://scripts/screens/nectar_convert_screen.gd").new()
			conversion.setup({"nectar": 100})
			result = [conversion.total]
			conversion.free()
		"splinter":
			field.clear()
			seed(601)
			var enemy := Enemy.new()
			enemy.setup("beetle_grunt", Vector2(400, 270), {"hp_mult": 1000.0})
			g.enemies = [enemy]
			var fragments := 0
			for trial in range(160):
				field.clear()
				field.spawn_player(enemy.position, Vector2.ZERO, 0.1, "bullet_base")
				g._update_collisions()
				for b in field.player_bullets:
					if String(b.art) == "bullet_fan":
						fragments += 1
				proc_trials += 1
			result = [fragments]
			enemy.free()
		_:
			var shots := 0
			var damage := 0.0
			var x := 0.0
			var y := 0.0
			var pierce := 0.0
			var splash := 0.0
			var chain := 0.0
			var size := 0.0
			var path_length := 0.0
			for volley in range(60 if id == "burst" else 12):
				if volley > 0:
					_fire_once()
				shots += field.player_bullets.size()
				damage += player.last_volley_damage / player.fire_interval()
				for b in field.player_bullets:
					pierce += float(b.pierce)
					splash += float(b.splash)
					chain += float(b.chain)
					size += float(b.scale) + float(b.r)
				# Zielsuche wirkt bewusst nur im Nahbereich (Bullets.HOMING_RANGE): Ziel dort platzieren.
				var aim := Vector2(330, 200) if id in ["homing", "homing_power"] else Vector2(550, 160)
				for frame in range(15):
					field.update(1.0 / 60.0, player.position, [aim])
					for b in field.player_bullets:
						path_length += (b.p as Vector2).distance_to(b.prev_p)
				for b in field.player_bullets:
					x += (b.p as Vector2).x
					y += (b.p as Vector2).y
			result = [shots, damage, x, y, pierce, splash, chain, size, path_length]
	g.free()
	return result

func _check_form_pairs() -> void:
	var forms := [{}, {"orbit": 3}, {"wave": 3}, {"homing": 3}, {"orbit": 3, "wave": 3},
		{"orbit": 3, "homing": 3}, {"wave": 3, "homing": 3}, {"orbit": 3, "wave": 3, "homing": 3}]
	var patterns := [{}, {"spiral": 3}, {"back": 3}, {"side": 3}, {"multishot": 3}, {"burst": 3}]
	for weapon_id in Data.WEAPON_ORDER:
		for form in forms:
			for pattern in patterns:
				var shop: Dictionary = form.duplicate()
				shop.merge(pattern)
				build(weapon_id, shop)
				# Vierte Salve enthält den Burst und eine nicht-triviale Spiralphase.
				if pattern.has("burst") or pattern.has("spiral"):
					for i in range(3):
						_fire_once()
				var born := field.player_bullets.duplicate()
				var old_positions: Array = []
				for b in born:
					old_positions.append(b.p)
				field.update(1.0 / 60.0, player.position, [Vector2(500, 140)])
				var valid := true
				for i in range(born.size()):
					var b: Dictionary = born[i]
					valid = valid and (b.p as Vector2).is_finite() and (b.v as Vector2).is_finite()
					valid = valid and (b.prev_p as Vector2).is_equal_approx(old_positions[i])
					valid = valid and float(b.dmg) > 0.0 and String(b.art) == "bullet_" + weapon_id
					if shop.has("orbit"):
						valid = valid and float(b.orbit_r) > 0.0
					if shop.has("wave"):
						valid = valid and absf(float(b.wave_amp)) > 0.0  # R4: gegenphasige Doppelhelix
					if shop.has("homing"):
						valid = valid and float(b.homing) > 0.0
					if weapon_id == "plasma":
						valid = valid and float(b.splash) >= 28.0
					if weapon_id == "lightning":
						valid = valid and int(b.lchain) >= 2
				for frame in range(29):
					field.update(1.0 / 60.0, player.position, [Vector2(500, 140)])
				var endpoints: Array = []
				var damage := 0.0
				for i in range(born.size()):
					var b: Dictionary = born[i]
					valid = valid and (b.p as Vector2).is_finite() and (b.v as Vector2).is_finite()
					valid = valid and (b.p as Vector2).distance_to(old_positions[i]) > 2.0
					endpoints.append([(b.p as Vector2).x, (b.p as Vector2).y])
					damage += float(b.dmg)
				pair_cases += 1
				measurements.append({"pair_weapon": weapon_id, "forms": form, "pattern": pattern,
					"shots": born.size(), "damage": damage, "positions_after_half_second": endpoints})
				check(valid, "%s: Formen+Muster %s/%s bleiben wirksam mit echten Segmenten" % [weapon_id, str(form), str(pattern)])

func _check_motion_examples() -> void:
	field.clear()
	var b := field.spawn_player(Vector2(200, 200), Vector2(300, 400), 7.4, "bullet_base", {"wave_amp": 20.0, "wave_len": 100.0})
	field.update(0.05, Vector2(160, 270))
	check((b.p as Vector2).is_equal_approx(Vector2(199, 232)), "Diagonalwelle: bekannte Viertelperiode relativ zur Schussrichtung")
	field.update(0.05, Vector2(160, 270))
	check((b.p as Vector2).is_equal_approx(Vector2(230, 240)), "Diagonalwelle: bekannte Halbperiode ohne kumulativen Drift")
	field.clear()
	var enemy := field.spawn_enemy(Vector2(200, 200), Vector2(-60, 120), 1, "ebullet_orb", {"r": 5.0, "scale": 1.7})
	enemy.slow = 0.5
	field.update(0.1, Vector2(160, 270))
	check((enemy.prev_p as Vector2).is_equal_approx(Vector2(200, 200)) and (enemy.p as Vector2).is_equal_approx(Vector2(197, 206)), "Gegnersegment berücksichtigt slow×delta exakt")
	check(is_equal_approx(float(enemy.r), 5.0), "Visuelles Gegnerscaling verändert Hitbox nicht")

func _check_orbit_homing_separation() -> void:
	build("plasma", {"orbit": 3, "homing": 3})
	for i in range(120):
		field.update(1.0 / 60.0, player.position, [Vector2(450, 220)])
	var closest := INF
	for i in range(field.player_bullets.size()):
		for j in range(i + 1, field.player_bullets.size()):
			closest = minf(closest, (field.player_bullets[i].p as Vector2).distance_to(field.player_bullets[j].p))
	check(closest > 14.0, "Plasma+Kreisflug+Zielsuche: Zielzug darf Phasen nach2s nicht zu einem Stapel kollabieren (%.2fpx)" % closest)

func _check_evolution_consumers() -> void:
	# Wirkungspfad je Evolution; ergänzt dynamische Bug-, Waffen- und Welttests.
	var consumer := {
		"pierce1": ["player", "evo_effect(\"pierce\")"], "splinter": ["game", "_spawn_splinter"],
		"crit": ["game", "crit_chance"], "stinger_rapid": ["player", "rate_damage_mult"],
		"heavy_sting": ["player", "evo_effect(\"dmg_mult\")"], "pierce_master": ["player", "evo_effect(\"pierce\")"],
		"companion_form": ["player", "evo_has(\"companion_form\")"], "companion_add": ["player", "evo_effect(\"companion_add\")"],
		"swarm_mark": ["game", "_mark_hit"], "swarm_echo": ["player", "evo_has(\"swarm_echo\")"],
		"drone_sacrifice": ["player", "drone_intercept"], "swarm_call": ["game", "_swarm_strike"],
		"pollen_trail": ["player", "spawn_pollen"], "pollen_burst": ["game", "evo_has(\"pollen_burst\")"],
		"pollen_shield": ["game", "evo_has(\"pollen_shield\")"], "pollen_economy": ["player", "evo_effect(\"nectar_pickup\")"],
		"pollen_blind": ["game", "evo_has(\"pollen_blind\")"], "wind_rider": ["player", "evo_effect(\"speed_mult\")"],
		"chitin_plate": ["player", "evo_effect(\"hp\")"], "chitin_regen": ["player", "evo_effect(\"iframes\")"],
		"chitin_thorns": ["game", "evo_has(\"chitin_thorns\")"], "chitin_light": ["game", "evo_effect(\"hitbox\")"],
		"chitin_guard": ["player", "evo_effect(\"precision_guard\")"], "chitin_bastion": ["player", "evo_effect(\"shield_regen\")"],
		"resonance_beat": ["player", "rhythm_interval"], "resonance_chain": ["player", "evo_effect(\"rhythm_chain\")"],
		"resonance_calm": ["player", "calm_bonus + 0.04"], "resonance_pulse": ["player", "hold_time >= 3.0"],
		"resonance_tuning": ["player", "tuning_t = 2.0"], "resonance_final": ["player", "evo_effect(\"rhythm_mult\")"],
		"nectar_overflow": ["player", "evo_has(\"nectar_overflow\")"], "nectar_convert": ["player", "evo_effect(\"nectar_convert\")"],
		"nectar_scent": ["game", "evo_effect(\"nectar_drop_chance\")"], "nectar_gluttony": ["player", "evo_effect(\"nectar_mult\")"],
		"nectar_bargain": ["player", "evo_effect(\"cost_mult\")"], "nectar_font": ["player", "evo_effect(\"nectar_phase\")"],
	}
	var sources := {"player": FileAccess.get_file_as_string("res://scripts/game/player.gd"), "game": FileAccess.get_file_as_string("res://scripts/game/game.gd")}
	check(Data.EVOLUTIONS.size() == 36 and consumer.size() == 36, "Alle36 Evolutionen haben einen expliziten Wirkungspfad")
	for evolution in Data.EVOLUTIONS:
		var id := String(evolution.id)
		check(consumer.has(id), "Evolution im Abdeckungsregister: " + id)
		if not consumer.has(id):
			continue
		var entry: Array = consumer[id]
		check(String(sources[entry[0]]).contains(String(entry[1])), "Bestehender Consumer für " + id)
		build("base", {"extra_shield": 1}, [{"id": id, "level": int(evolution.max)}])
		if id == "chitin_bastion":
			check(not player.shield_active() and player.shield_max == 0 and player.shield_hits == 0
				and is_zero_approx(player.evo_effect("shield_regen")),
				"Bastion-Negativgate: Werkstatt ohne taktischen Kauf bleibt vollständig inaktiv")
		player.upgrades["companion"] = 1
		player.upgrades["shield"] = 1
		var effect: Dictionary = evolution.get("effect", {})
		for key in effect:
			check(is_equal_approx(player.evo_effect(key), float(effect[key]) * float(evolution.max)), "Evolution skaliert auf Maxstufe: %s.%s" % [id, key])

func _check_max_builds() -> void:
	var shop := {}
	for item in ShopData.ITEMS:
		shop[String(item.id)] = int(item.max)
	var evolutions: Array = []
	for evolution in Data.EVOLUTIONS:
		evolutions.append({"id": evolution.id, "level": evolution.max})
	for weapon_id in Data.WEAPON_ORDER:
		build(weapon_id, shop, evolutions)
		player.upgrades["companion"] = 3
		player.upgrades["shield"] = 3
		player.upgrades["bombs"] = 3
		player._refresh_shield_capacity()
		var peak := field.player_bullets.size()
		var peak_volley := 0
		var finite := true
		var start := Time.get_ticks_usec()
		for frame in range(1200):
			var delta := 1.0 / 120.0
			player._update_timers(delta)
			player._handle_firing(delta)
			player._update_companions(delta)
			field.update(delta, player.position, [Vector2(470, 170), Vector2(500, 330)])
			peak = maxi(peak, field.player_bullets.size())
			peak_volley = maxi(peak_volley, player.last_volley_shots)
			for b in field.player_bullets:
				finite = finite and (b.p as Vector2).is_finite() and (b.v as Vector2).is_finite()
		var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
		# R6: Fächer Stufe 3 hat 6 Stacheln (Aufwertung) – Salvengrenze 15; die Grenze je
		# Sekunde (balanceprobe, 120 Kugeln/s) bleibt maßgeblich und unverändert.
		check(peak < BulletField.MAX_PLAYER and peak_volley <= 15, "%s Maxbuild10s: ohne Limitsättigung, peak=%d/salve=%d" % [weapon_id, peak, peak_volley])
		check(finite and player.fire_interval() >= Player.MIN_INTERVAL, "%s Maxbuild: endliche Bahnen, begrenzter Feuertakt" % weapon_id)
		measurements.append({"maxbuild_weapon": weapon_id, "simulated_seconds": 10, "peak_projectiles": peak, "peak_volley": peak_volley,
			"last_volley_damage": player.last_volley_damage, "interval": player.fire_interval(), "simulation_ms": elapsed_ms})
		print("MAXBUILD %s peak=%d volley=%d interval=%.3f simulation_ms=%.1f" % [weapon_id, peak, peak_volley, player.fire_interval(), elapsed_ms])
	field.clear()
	for i in range(BulletField.MAX_PLAYER + 20):
		field.spawn_player(Vector2(200, 200), Vector2.ZERO, 1.0, "bullet_base")
	check(field.player_bullets.size() == 320, "Harte Spielergrenze bleibt exakt320")
	for i in range(BulletField.MAX_ENEMY + 20):
		field.spawn_enemy(Vector2(200, 200), Vector2.ZERO, 1, "ebullet_orb")
	check(field.enemy_bullets.size() == 420, "Harte Gegnergrenze bleibt exakt420")
