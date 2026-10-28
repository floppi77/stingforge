extends Node
## Prüft jedes einzelne Werkstatt-Upgrade auf Wirkung – je Eintrag ein Nachweis.
##
## Aufbau: Für jeden Eintrag wird ein Level mit genau diesem Eintrag auf Stufe 3
## gestartet und die zugesagte Wirkung gemessen. Damit fällt auf, wenn ein Wert
## zwar in den Daten steht, aber nirgends ankommt.

var fails: Array = []
var passed: Array = []
var app: Node
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	app = get_node("/root/App")
	_rng.seed = 4711
	await get_tree().create_timer(0.3, false).timeout

	await _check_orbit()
	await _check_wave()
	await _check_wave_freq()
	await _check_wave_amp()
	await _check_back()
	await _check_side()
	await _check_lanes()
	await _check_spiral()
	await _check_homing()
	await _check_homing_power()
	await _check_pierce()
	await _check_splash()
	await _check_chain()
	await _check_big()
	await _check_crit()
	await _check_boss_dmg()
	await _check_fire_rate()
	await _check_bullet_speed()
	await _check_burst()
	await _check_splinter()
	await _check_shield_regen()
	await _check_shield_add()
	await _check_max_hp()
	await _check_iframe()
	await _check_bomb_radius()
	await _check_bomb_rate()
	await _check_magnet()
	await _check_nectar_plus()
	await _check_graze()
	await _check_combo()
	await _check_convert()
	await _check_start_heal()
	await _check_groups()

	print("UPGRADE: geprüft=%d fehler=%d" % [passed.size(), fails.size()])
	for f in fails:
		print("UPGRADE_FEHLER: " + String(f))
	print("UPGRADE_OK" if fails.is_empty() else "UPGRADE_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

# ---------------------------------------------------------------- Hilfsmittel
func _ok(id: String, cond: bool, note: String) -> void:
	if cond:
		passed.append(id)
		print("UPGRADE_OK  %-14s %s" % [id, note])
	else:
		fails.append("%s: %s" % [id, note])

func _start(shop: Dictionary, weapon := "base") -> Node:
	Save.new_campaign("normal", 900001 + _rng.randi_range(0, 999))
	Save.campaign.shop = shop
	Save.campaign.weapon = weapon
	Save.campaign.upgrades = {"base": 1}
	app.clear_screens()
	app._begin_level(1, 0)
	for i in range(12):
		await get_tree().process_frame
	return app.game

func _stop() -> void:
	app.clear_screens()
	await get_tree().process_frame

func _fire(g: Node, times := 1) -> void:
	for i in range(times):
		g.player._fire_volley()
		await get_tree().physics_frame

func _bullets(g: Node) -> Array:
	return g.bullets.player_bullets

func _bounds(bs: Array, key: String, def := 0.0) -> float:
	var best := def
	for b in bs:
		best = maxf(best, float(b.get(key, def)))
	return best

func _max_from_line(bs: Array) -> float:
	var best := 0.0
	for b in bs:
		var dy: float = absf(float((b.p as Vector2).y) - float(b.get("wave_y0", (b.p as Vector2).y)))
		best = maxf(best, dy)
	return best

# --------------------------------------------------------------- Schussform
func _check_orbit() -> void:
	for level in range(1, 4):
		var g := await _start({"orbit": level})
		if g == null:
			_ok("orbit", false, "Level startet nicht")
			return
		await _fire(g, 2)
		var bs := _bullets(g)
		var r := _bounds(bs, "orbit_r")
		var expected: float = [110.0, 142.0, 166.0][level - 1]
		_ok("orbit", is_equal_approx(r, expected) and bs.size() > 0,
			"Kreisflug%d: tatsächlicher Radius %.0f exakt %.0f px" % [level, r, expected])
		await _stop()

func _check_wave() -> void:
	var g := await _start({"wave": 3})
	if g == null:
		_ok("wave", false, "Level startet nicht")
		return
	await _fire(g, 1)
	var start_x := 0.0
	if _bullets(g).size() > 0:
		start_x = (_bullets(g)[0].p as Vector2).x
	# 0,35 s fliegen lassen und Auslenkung messen
	await get_tree().create_timer(0.35, false).timeout
	var bs := _bullets(g)
	var dev := _max_from_line(bs)
	var moved := 0.0
	if bs.size() > 0:
		moved = (_bullets(g)[0].p as Vector2).x - start_x
	_ok("wave", dev > 8.0 and moved > 100.0,
		"Auslenkung %.0f px bei %.0f px Flug" % [dev, moved])
	await _stop()

func _check_wave_freq() -> void:
	var slow := await _wave_crossings({"wave": 3})
	var fast := await _wave_crossings({"wave": 3, "wave_freq": 3})
	_ok("wave_freq", fast > slow, "Nulldurchgänge %d (schnell) gegen %d (langsam)" % [fast, slow])

func _check_wave_amp() -> void:
	# Über eine halbe Sekunde mitmessen: nur so wird die volle Wellenauslenkung
	# erfasst und nicht zufällig eine Phase nahe dem Nulldurchgang.
	var amp1 := await _wave_peak({"wave": 3})
	var amp2 := await _wave_peak({"wave": 3, "wave_amp": 3})
	_ok("wave_amp", amp2 > amp1 + 4.0, "Auslenkung %.0f px gegen %.0f px" % [amp2, amp1])

func _wave_peak(levels: Dictionary) -> float:
	var g := await _start(levels)
	await _fire(g, 1)
	var peak := 0.0
	for i in range(30):
		await get_tree().physics_frame
		peak = maxf(peak, _max_from_line(_bullets(g)))
	await _stop()
	return peak

## Zählt, wie oft die Wellenbahn ihre Mittellinie überquert.
func _wave_crossings(shop: Dictionary) -> int:
	var g := await _start(shop)
	if g == null:
		return 0
	await _fire(g, 1)
	var prev := 0.0
	var count := 0
	for i in range(36):
		await get_tree().physics_frame
		var bs := _bullets(g)
		if bs.is_empty():
			break
		var b: Dictionary = bs[0]
		var dy: float = float((b.p as Vector2).y) - float(b.get("wave_y0", 0.0))
		if prev != 0.0 and signf(dy) != signf(prev):
			count += 1
		prev = dy
	await _stop()
	return count

func _check_back() -> void:
	var g := await _start({"back": 3})
	if g == null:
		_ok("back", false, "Level startet nicht")
		return
	await _fire(g, 1)
	var n := 0
	for b in _bullets(g):
		if (b.v as Vector2).x < -100.0:
			n += 1
	# Höchstens zwei Heckschüsse (Kugelflut), die dritte Stufe bringt Wucht.
	_ok("back", n >= 2, "%d Heckschüsse" % n)
	await _stop()

func _check_side() -> void:
	var g := await _start({"side": 3})
	if g == null:
		_ok("side", false, "Level startet nicht")
		return
	await _fire(g, 1)
	# Dieselben Geschosse über zwei Bilder verfolgen (nicht über Listenpositionen –
	# die verschieben sich, sobald irgendwo ein Geschoss verfällt).
	var before: Array = []
	for b in _bullets(g):
		if absf((b.v as Vector2).y) > 300.0:
			before.append([b, (b.p as Vector2).y])
	await get_tree().create_timer(0.2, false).timeout
	var moved := 0
	for entry in before:
		var b2: Dictionary = entry[0]
		if not _bullets(g).has(b2):
			continue
		if absf(float((b2.p as Vector2).y) - float(entry[1])) > 40.0:
			moved += 1
	_ok("side", moved >= 2, "%d Seitenstacheln fliegen (von %d)" % [moved, before.size()])
	await _stop()

func _check_lanes() -> int:
	var g0 := await _start({})
	await _fire(g0, 1)
	var base := _bullets(g0).size()
	await _stop()
	var g := await _start({"multishot": 3})
	await _fire(g, 1)
	var more := _bullets(g).size()
	await _stop()
	_ok("multishot", more > base, "%d Geschosse gegen %d ohne Doppelläufe" % [more, base])
	return more

func _check_spiral() -> void:
	var g := await _start({"spiral": 3})
	if g == null:
		_ok("spiral", false, "Level startet nicht")
		return
	g.player.autofire = true
	g.player.fire_cd = 0.0
	# Über mehrere Salven sammeln, in welche Richtungen die Zusatzschüsse gehen.
	var seen: Dictionary = {}
	for i in range(60):
		await get_tree().physics_frame
		for b in _bullets(g):
			var a := (b.v as Vector2).angle()
			seen[snappedf(a, 0.1)] = true
		if seen.size() >= 4:
			break
	var dirs: Array = seen.keys()
	dirs.sort()
	_ok("spiral", dirs.size() >= 3, "Schüsse verteilen sich auf %d Richtungen (%s)"
		% [dirs.size(), str(dirs.slice(0, 4))])
	await _stop()

func _check_homing() -> void:
	var g := await _start({"homing": 3})
	if g == null:
		_ok("homing", false, "Level startet nicht")
		return
	# Ziel weit über der Flugbahn, damit eine Gerade es nie trifft
	var e: Node = g.spawn_enemy("aphid", Vector2(520, 80))
	await get_tree().process_frame
	g.player.position = Vector2(160, 330)
	await _fire(g, 1)
	for i in range(20):
		await get_tree().physics_frame
	var turned := false
	for b in _bullets(g):
		if float(b.get("homing", 0.0)) > 0.0 and (b.v as Vector2).y < -12.0:
			turned = true
	_ok("homing", turned, "Geschosse drehen nach oben zum Ziel")
	await _stop()

func _check_homing_power() -> void:
	var g := await _start({"homing": 1})
	if g == null:
		_ok("homing_power", false, "Level startet nicht")
		return
	g.spawn_enemy("aphid", Vector2(520, 80))
	g.player.position = Vector2(160, 330)
	await _fire(g, 1)
	for i in range(20):
		await get_tree().physics_frame
	var weak := 0.0
	for b in _bullets(g):
		weak = minf(weak, (b.v as Vector2).y)
	await _stop()
	var g2 := await _start({"homing": 1, "homing_power": 3})
	if g2 == null:
		_ok("homing_power", false, "Level startet nicht")
		return
	g2.spawn_enemy("aphid", Vector2(520, 80))
	g2.player.position = Vector2(160, 330)
	await _fire(g2, 1)
	for i in range(20):
		await get_tree().physics_frame
	var strong := 0.0
	for b in _bullets(g2):
		strong = minf(strong, (b.v as Vector2).y)
	_ok("homing_power", strong < weak - 5.0,
		"stärkere Wendung %.1f gegen %.1f" % [strong, weak])
	await _stop()

# ------------------------------------------------------------------ Wirkung
func _check_pierce() -> void:
	var g := await _start({"pierce": 3})
	if g == null:
		_ok("pierce", false, "Level startet nicht")
		return
	await _fire(g, 1)
	var p := 0
	for b in _bullets(g):
		p = maxi(p, int(b.get("pierce", 0)))
	_ok("pierce", p >= 3, "%d Durchschläge" % p)
	await _stop()

func _check_splash() -> void:
	var g := await _start({"splash": 3})
	if g == null:
		_ok("splash", false, "Level startet nicht")
		return
	var a: Node = g.spawn_enemy("aphid", Vector2(420, 270))
	var b: Node = g.spawn_enemy("aphid", Vector2(420, 292))
	await get_tree().process_frame
	var hp_b: float = b.hp
	g.player.position = Vector2(360, 270)
	g.player._fire_volley()
	for i in range(20):
		await get_tree().physics_frame
	_ok("splash", b.hp < hp_b or b.dead, "Nachbar verliert Leben (%.0f -> %.0f)" % [hp_b, b.hp])
	await _stop()

func _check_chain() -> void:
	var g := await _start({"chain": 3})
	if g == null:
		_ok("chain", false, "Level startet nicht")
		return
	var a: Node = g.spawn_enemy("aphid", Vector2(420, 270))
	var b: Node = g.spawn_enemy("aphid", Vector2(420, 300))
	await get_tree().process_frame
	var hp_b: float = b.hp
	g.player.position = Vector2(360, 270)
	g.player._fire_volley()
	for i in range(24):
		await get_tree().physics_frame
	_ok("chain", b.hp < hp_b or b.dead, "Kettenblitz trifft den zweiten Gegner")
	await _stop()

func _check_big() -> void:
	var g := await _start({"big_bullet": 3})
	if g == null:
		_ok("big_bullet", false, "Level startet nicht")
		return
	await _fire(g, 1)
	var sc := _bounds(_bullets(g), "scale", 1.0)
	_ok("big_bullet", sc > 1.1, "Geschossskalierung %.2f" % sc)
	await _stop()

func _check_crit() -> void:
	var shop := {"crit": 3}
	var g := await _start(shop)
	if g == null:
		_ok("crit", false, "Level startet nicht")
		return
	var rate: float = float(g.player.shop_mod("crit"))
	var doubles := 0
	var n := 400
	for i in range(n):
		if absf(g._shot_damage(100.0) - 200.0) < 0.01:
			doubles += 1
	var measured := float(doubles) / float(n)
	_ok("crit", absf(measured - rate) < 0.08,
		"Volltrefferquote %.2f (erwartet %.2f)" % [measured, rate])
	await _stop()

func _check_boss_dmg() -> void:
	var g := await _start({"big_bullet": 1, "boss_bane": 3})
	if g == null:
		_ok("boss_bane", false, "Level startet nicht")
		return
	var normal: float = g._shot_damage(100.0, false)
	var vs_boss: float = g._shot_damage(100.0, true)
	_ok("boss_bane", vs_boss > normal + 5.0,
		"gegen Boss %.0f statt %.0f" % [vs_boss, normal])
	await _stop()

# -------------------------------------------------------------------- Tempo
func _check_fire_rate() -> void:
	var g0 := await _start({})
	var i0: float = g0.player.fire_interval()
	await _stop()
	var g := await _start({"fire_rate": 3})
	var i1: float = g.player.fire_interval()
	await _stop()
	_ok("fire_rate", i1 < i0 - 0.01, "Feuerpause %.3f s statt %.3f s" % [i1, i0])

func _check_bullet_speed() -> void:
	var g0 := await _start({})
	await _fire(g0, 1)
	var v0 := _max_vx(_bullets(g0))
	await _stop()
	var g := await _start({"bullet_speed": 3})
	await _fire(g, 1)
	var v1 := _max_vx(_bullets(g))
	_ok("bullet_speed", v1 > v0 + 40.0, "Geschwindigkeit %.0f statt %.0f" % [v1, v0])
	await _stop()

func _max_vx(bs: Array) -> float:
	var best := 0.0
	for b in bs:
		best = maxf(best, (b.v as Vector2).x)
	return best

func _check_burst() -> void:
	var g := await _start({"burst": 3})
	if g == null:
		_ok("burst", false, "Level startet nicht")
		return
	g.player.autofire = true
	g.player.fire_cd = 0.0
	var counts: Array = []
	var last := _bullets(g).size()
	for i in range(90):
		await get_tree().physics_frame
		var now := _bullets(g).size()
		if now > last:
			counts.append(now - last)
		last = maxi(0, now - 0)
		if counts.size() >= 6:
			break
	var big := 0
	for c in counts:
		big = maxi(big, int(c))
	var small := 999
	for c in counts:
		small = mini(small, int(c))
	_ok("burst", big > small, "Salven mit %d und %d Geschossen" % [big, small])
	await _stop()

# ------------------------------------------------------------------ Wirkung 2
func _check_splinter() -> void:
	var g := await _start({"splinter": 3})
	if g == null:
		_ok("splinter", false, "Level startet nicht")
		return
	g.player.position = Vector2(300, 270)
	g.player.autofire = false
	# Jeder Anlauf bekommt ein frisches, sehr zähes Ziel: der Splitter entsteht nur
	# bei etwa jedem zweiten Treffer, und ein toter Gegner wird nicht mehr getroffen.
	var extra := 0
	for versuch in range(10):
		g.spawn_enemy("aphid", Vector2(430, 270), {"hp_mult": 60.0})
		for i in range(3):
			await get_tree().physics_frame
		g.player._fire_volley()
		for i in range(10):
			await get_tree().physics_frame
			extra = 0
			for b in _bullets(g):
				if String(b.art) == "bullet_fan":
					extra += 1
			if extra > 0:
				break
		if extra > 0:
			break
	_ok("splinter", extra > 0, "%d Splitter unterwegs" % extra)
	await _stop()

# ------------------------------------------------------------------- Schutz
func _check_shield_regen() -> void:
	for shop in [{}, {"extra_shield": 1, "shield_regen": 3}]:
		var g := await _start(shop)
		if g == null:
			_ok("shield_regen", false, "Level startet nicht")
			return
		var p: Player = g.player
		p._update_timers(24.0)
		_ok("shield_regen", not p.shield_active() and p.shield_max == 0 and p.shield_hits == 0,
			"Werkstatt allein regeneriert kein ungekauftes Schild")
		p.nectar = 1000
		var bought: bool = bool(p.try_buy("shield").ok)
		p.iframes = 0.0
		p.take_damage(1)
		var duration := p.shield_regen_duration()
		var expected := 4.0 if shop.has("shield_regen") else 12.0
		p._update_timers(expected - 0.01)
		_ok("shield_regen", bought and is_equal_approx(duration, expected) and p.shield_hits == 0,
			"Gekauftes Schild lädt nicht vor %.2fs" % expected)
		p._update_timers(0.02)
		_ok("shield_regen", p.shield_hits == 1 and p.shield_max == 1,
			"Gekauftes Schild regeneriert nach %.2fs exakt eine Ladung" % expected)
		await _stop()

func _check_shield_add() -> void:
	# R2: extra_shield heißt Schildstabilität, nicht zusätzliche Kapazität.
	for level in range(4):
		var g := await _start({"extra_shield": level} if level > 0 else {})
		var p: Player = g.player
		_ok("extra_shield", not p.shield_active() and p.shield_max == 0 and p.shield_hits == 0,
			"Stabilität%d schaltet ohne Taktikkauf kein Schild frei" % level)
		p.nectar = 1000
		var bought: bool = bool(p.try_buy("shield").ok)
		p.iframes = 0.0
		var hp := p.hp
		p.take_damage(1)
		var expected: float = [0.55, 0.8, 1.05, 1.4][level]
		var exact_grace := is_equal_approx(p.iframes, expected)
		p._update_timers(expected - 0.01)
		var protected := not p.take_damage(1) and p.hp == hp
		p._update_timers(0.02)
		var expired := p.take_damage(1) and p.hp == hp - 1
		_ok("extra_shield", bought and p.shield_max == 1 and p.shield_hits == 0
			and exact_grace and protected and expired,
			"Stabilität%d: echter Treffer bleibt %.2fs geschützt, danach HP-Schaden; Kapazität bleibt 1" % [level, expected])
		await _stop()

func _check_max_hp() -> void:
	var g0 := await _start({})
	var h0: int = g0.player.max_hp
	await _stop()
	var g := await _start({"extra_life": 3})
	var h1: int = g.player.max_hp
	await _stop()
	_ok("extra_life", h1 >= h0 + 3, "%d Leben statt %d" % [h1, h0])

func _check_iframe() -> void:
	var g0 := await _start({})
	var i0: float = g0.player.iframe_time()
	await _stop()
	var g := await _start({"iframe_plus": 3})
	var i1: float = g.player.iframe_time()
	await _stop()
	_ok("iframe_plus", i1 > i0 + 0.1, "Unverwundbarkeit %.2f s statt %.2f s" % [i1, i0])

func _check_bomb_radius() -> void:
	var g := await _start({"bomb": 1})
	var r0: float = g.player_pulse_radius()
	await _stop()
	var g2 := await _start({"bomb": 1, "bomb_radius": 3})
	var r1: float = g2.player_pulse_radius()
	_ok("bomb_radius", r1 > r0 + 20.0, "Druckwelle %.0f statt %.0f" % [r1, r0])
	await _stop()

func _check_bomb_rate() -> void:
	var g0 := await _start({"bomb": 1})
	var b0: float = g0.player.bomb_cycle()
	await _stop()
	var g := await _start({"bomb": 1, "bomb_charge": 3})
	var b1: float = g.player.bomb_cycle()
	_ok("bomb_charge", b1 < b0 - 1.0, "Ladezeit %.1f s statt %.1f s" % [b1, b0])
	await _stop()

# ------------------------------------------------------------------ Ausbeute
func _check_magnet() -> void:
	var g0 := await _start({})
	var r0: float = g0.magnet_radius()
	await _stop()
	var g := await _start({"magnet": 3})
	var r1: float = g.magnet_radius()
	_ok("magnet", r1 > r0 + 40.0, "Anziehung %.0f statt %.0f" % [r1, r0])
	await _stop()

func _check_nectar_plus() -> void:
	var g0 := await _start({})
	var n0: int = g0.drop_amount(1, 0.0)
	await _stop()
	var g := await _start({"nectar_plus": 3})
	var hit: int = g.drop_amount(1, 0.29)
	var miss: int = g.drop_amount(1, 0.31)
	var got := 0
	for i in range(4000):
		got += g.drop_amount(1) - 1
	var rate := float(got) / 4000.0
	_ok("nectar_plus", absf(g.nectar_bonus_chance() - 0.3) < 0.001 and hit == n0 + 1 and miss == n0
		and absf(rate - 0.3) < 0.04, "Stufe 3: 30 %% Chance (gemessen %.1f %%), Treffer +1" % (rate * 100.0))
	await _stop()

func _check_graze() -> void:
	var g := await _start({"graze": 3})
	if g == null:
		_ok("graze", false, "Level startet nicht")
		return
	var p: Player = g.player
	var before := int(p.points)
	g.bullets.spawn_enemy(p.position + Vector2(0, 20), Vector2.ZERO, 1, "ebullet_orb",
		{"life": 1.5})
	for i in range(20):
		await get_tree().physics_frame
	_ok("graze", int(p.points) > before, "Streiftreffer geben %d Punkte" % (int(p.points) - before))
	await _stop()

func _check_combo() -> void:
	var g0 := await _start({})
	var before0 := int(g0.player.points)
	var e0: Node = g0.spawn_enemy("aphid", Vector2(420, 270))
	await get_tree().process_frame
	e0.take_damage(999.0)
	await get_tree().process_frame
	var gain0 := int(g0.player.points) - before0
	await _stop()
	var g := await _start({"combo": 3})
	var before := int(g.player.points)
	var e: Node = g.spawn_enemy("aphid", Vector2(420, 270))
	await get_tree().process_frame
	e.take_damage(999.0)
	await get_tree().process_frame
	var gain := int(g.player.points) - before
	_ok("combo", gain > gain0, "%d Punkte je Abschuss statt %d" % [gain, gain0])
	await _stop()

func _check_convert() -> void:
	var g := await _start({"convert_bonus": 3})
	if g == null:
		_ok("convert", false, "Level startet nicht")
		return
	app.clear_screens()
	app.push_screen("res://scripts/screens/nectar_convert_screen.gd",
		{"from": "level", "level": 1, "nectar": 100})
	await get_tree().create_timer(0.3, false).timeout
	var scr = app.screens[app.screens.size() - 1]
	var with_bonus := int(scr.total) if scr != null else 0
	await _stop()
	Save.campaign.shop = {}
	app.push_screen("res://scripts/screens/nectar_convert_screen.gd",
		{"from": "level", "level": 1, "nectar": 100})
	await get_tree().create_timer(0.3, false).timeout
	var scr2 = app.screens[app.screens.size() - 1]
	var plain := int(scr2.total) if scr2 != null else 0
	_ok("convert", with_bonus > plain, "%d Punkte statt %d" % [with_bonus, plain])
	await _stop()

func _check_start_heal() -> void:
	var g := await _start({"start_heal": 3})
	if g == null:
		_ok("start_heal", false, "Level startet nicht")
		return
	var p: Player = g.player
	_ok("start_heal", p.hp >= p.max_hp, "Start mit %d von %d Leben" % [p.hp, p.max_hp])
	await _stop()

# ------------------------------------------------------------------- Gruppen
func _check_groups() -> void:
	# Stingforge: technisch kombinierbare Flugformen dürfen einander nicht sperren.
	var levels := {"orbit": 1}
	var free_wave := ShopData.blocker_of("wave", levels) == ""
	var free_homing := ShopData.blocker_of("homing", levels) == ""
	var ok := free_wave and free_homing and ShopData.would_lock("orbit", {}).is_empty()
	ok = ok and ShopData.blocker_of("orbit", {"wave": 2}) == ""
	# Die Kombination muss auch über den echten Kaufweg möglich sein.
	Save.new_campaign("normal", 606060)
	Save.campaign.points = 100000
	Save.campaign.shop = {"orbit": 1}
	app.clear_screens()
	app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 2})
	await get_tree().create_timer(0.4, false).timeout
	var shop = app.screens[app.screens.size() - 1]
	var wave_row := -1
	for i in range(shop.items.size()):
		if String(shop.items[i].get("id", "")) == "wave":
			wave_row = i
	if wave_row < 0:
		ok = false
	else:
		shop.focus = wave_row
		shop._activate()
		await get_tree().process_frame
		if int(Save.campaign.get("shop", {}).get("wave", 0)) != 1:
			ok = false
		if int(Save.campaign.get("shop", {}).get("orbit", 0)) != 1:
			ok = false
	_ok("groups", ok, "Kreisflug, Welle und Zielsuche kombinierbar; echter Kauf erhält Kreisflug")
	await _stop()
