extends Node
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func game() -> Game:
	var g := Game.new()
	g.setup({"level": 1})
	g.started = false
	return g

func _ready() -> void:
	await get_tree().process_frame
	Save.new_campaign("normal", 18031)
	_test_spawn_admission()
	for level in [1, 5, 10]:
		var g := game()
		g.level_index = level
		g.player._fire_volley()
		var dps := g.player.attack_dps()
		var normal_hp := g.enemy_hp_mult()
		var boss_hp := g._boss_hp_scale()
		g.player.shop_mods["dmg"] = 1.0
		g.player._fire_volley()
		var power_gain := g.player.attack_dps() / dps
		check(g.enemy_hp_mult() / normal_hp < power_gain,
			"L%d Schadensverdopplung senkt reale Gegner-TTK (HPx%.3f/DPSx%.3f)" % [level, g.enemy_hp_mult() / normal_hp, power_gain])
		check(g._boss_hp_scale() / boss_hp < power_gain,
			"L%d Schadensverdopplung senkt Boss-TTK" % level)
		check(g.enemy_hp_mult() >= normal_hp, "L%d Grundhärte bleibt erhalten" % level)
		g.player.shop_mods.clear()
		g.player.evolutions = [{"id": "crit", "level": 1}]
		g.player._fire_volley()
		check(g._boss_hp_scale() / boss_hp < g.player.attack_dps() / dps,
			"L%d auch ein einzelner Crit-Evolutionskauf verbessert Boss-TTK" % level)
		g.free()
	_test_splash_and_chain()
	_test_crit()
	_test_checkpoint_drops_pollen()
	_test_splinters()
	_test_aura_homing_miniboss()
	_test_secondary_policy()
	_test_boss_mark()
	_test_pollen_area()
	_test_boss_reward()
	print("STINGFORGE_WORLD_SYNERGY checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	if failures.is_empty():
		print("STINGFORGE_WORLD_SYNERGY_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_boss_reward() -> void:
	var g := game()
	g.player.shop_mods["combo"] = 0.26
	var before := g.player.points
	g._on_boss_defeated()
	check(g.player.points - before == 4410, "Abschuss-Punktebonus gilt konsistent auch für Bossbelohnung")
	g.free()

func _test_pollen_area() -> void:
	var totals: Array[float] = []
	for steps in [1, 12]:
		var g := game()
		g.player.evolutions = [{"id": "pollen_trail", "level": 1}]
		var a: Enemy = g.spawn_enemy("beetle_grunt", Vector2(470, 270))
		var b: Enemy = g.spawn_enemy("beetle_grunt", Vector2(520, 270))
		var outside: Enemy = g.spawn_enemy("beetle_grunt", Vector2(800, 270))
		for e in [a, b, outside]:
			e.hp = 1000.0
		g.boss = Boss.new()
		g.boss.setup("rose_beetle")
		g.boss.position = Vector2(620, 270)
		g.add_child(g.boss)
		var hp := g.boss.hp
		g.spawn_pollen(Vector2(500, 270), 3.0)
		g._update_pollens(0.0)
		check(is_equal_approx(a.hp, 997.0) and is_equal_approx(b.hp, 997.0), "Pollen trifft alle Nachbarn desselben Flächenticks")
		check(is_equal_approx(hp - g.boss.hp, 3.0), "Pollenfläche trifft überlappende sichtbare Bossoberfläche")
		check(is_equal_approx(outside.hp, 1000.0), "Pollenfläche schadet außerhalb nicht")
		var hp_after := a.hp
		g._update_pollens(0.0)
		check(is_equal_approx(a.hp, hp_after), "derselbe Pollen-Zeitpunkt tickt nicht mehrfach")
		for i in range(steps):
			g._update_pollens(1.2 / float(steps))
		totals.append(1000.0 - a.hp)
		g.free()
	check(is_equal_approx(totals[0], totals[1]) and is_equal_approx(totals[0], 12.0),
		"Pollen-Dauerwirkung ist delta-invariant (%.1f/%.1f)" % [totals[0], totals[1]])

func _test_secondary_policy() -> void:
	var damage_by_level: Array[float] = []
	for jumps in [2, 3]:
		var g := game()
		var source: Enemy = g.spawn_enemy("beetle_grunt", Vector2(500, 200))
		source.hp = 1000
		var last: Enemy
		for x in [550, 600, 650]:
			last = g.spawn_enemy("beetle_grunt", Vector2(x, 200))
			last.hp = 1000
		g.bullets.spawn_player(source.position, Vector2.ZERO, 10, "bullet_lightning", {"lchain": jumps, "splash": 200, "r": 1.0})
		g._update_collisions()
		damage_by_level.append(1000.0 - last.hp)
		g.free()
	check(damage_by_level[1] >= damage_by_level[0] and damage_by_level[1] > 5.0,
		"zusätzlicher Blitzsprung reduziert nie vorhandenen Splash (%.2f→%.2f)" % [damage_by_level[0], damage_by_level[1]])
	var g := game()
	g.boss = Boss.new()
	g.boss.setup("rose_beetle")
	g.boss.position = Vector2(620, 270)
	g.add_child(g.boss)
	g.player.shop_mods = {"crit": 1.0, "boss_dmg": 0.5}
	var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(500, 270))
	e.hp = 1000.0
	var before := g.boss.hp
	g.bullets.spawn_player(e.position, Vector2.ZERO, 10, "bullet_plasma", {"splash": 70, "r": 1.0})
	g._update_collisions()
	check(is_equal_approx(1000.0 - e.hp, 20.0), "kritischer Primärtreffer verdoppelt Basis einmal")
	check(is_equal_approx(before - g.boss.hp, 15.0), "Plasma-Splash erbt Critbasis und wendet Bossbonus genau einmal an")
	g.free()

func _test_boss_mark() -> void:
	var g := game()
	g.player.evolutions = [{"id": "swarm_mark", "level": 1}]
	g.boss = Boss.new()
	g.boss.setup("rose_beetle")
	g.boss.position = Vector2(620, 270)
	g.add_child(g.boss)
	for i in range(6):
		g.bullets.player_bullets.clear()
		g.bullets.spawn_player(g.boss.position, Vector2.ZERO, 1, "bullet_base", {"r": 1.0})
		g._update_collisions()
	var swarm := 0
	for bullet in g.bullets.player_bullets:
		if int(bullet.get("proc_depth", 0)) == 1:
			swarm += 1
			bullet.p = g.boss.position
			bullet["prev_p"] = bullet.p
	check(swarm == 6, "sechs Primärtreffer markieren auch Bosse und rufen sechs sekundäre Schwarmkugeln")
	var count := g.bullets.player_bullets.size()
	g._update_collisions()
	check(g.bullets.player_bullets.size() == count, "Schwarmkugeln lösen weder weiteren Schwarm noch Splitterrekursion aus")
	var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(700, 300))
	var id := e.get_instance_id()
	g.mark_table[id] = 3
	e.take_damage(1.0e6)
	check(not g.mark_table.has(id), "Markierung wird bei Gegnertod entfernt")
	g.free()

func _test_spawn_admission() -> void:
	var g := game()
	var first: Variant = g.call("spawn_player_bullet", Vector2(200, 200), Vector2.RIGHT, 10.0, "bullet_base")
	check(first is Dictionary and not first.is_empty(), "Game-Spawn liefert das tatsächlich angenommene Projektil")
	while g.bullets.player_bullets.size() < BulletField.MAX_PLAYER:
		g.bullets.spawn_player(Vector2(200, 200), Vector2.RIGHT, 10, "bullet_base")
	var before := int(g.stats.shots)
	var rejected: Variant = g.call("spawn_player_bullet", Vector2(200, 200), Vector2.RIGHT, 10.0, "bullet_base")
	check(rejected is Dictionary and rejected.is_empty(), "voller BulletField liefert eindeutig leeres Dictionary")
	check(int(g.stats.shots) == before, "abgewiesenes Projektil erhöht keine Schussstatistik")
	g.free()

func _test_aura_homing_miniboss() -> void:
	var g := game()
	g.player.evolutions = [{"id": "pollen_shield", "level": 1}]
	g.player.position = Vector2(500, 270)
	g.spawn_enemy_bullet(Vector2(100, 270), Vector2.RIGHT * 200, 1, "ebullet_orb")
	# Der erste normale Spawn kann der deterministisch ausgelassene fünfte Anteil sein.
	if g.bullets.enemy_bullets.is_empty():
		g.spawn_enemy_bullet(Vector2(100, 270), Vector2.RIGHT * 200, 1, "ebullet_orb")
	var bullet: Dictionary = g.bullets.enemy_bullets.back()
	bullet["prev_p"] = bullet.p
	bullet.p = Vector2(500, 330)
	g._update_hazards(0.0)
	check(is_equal_approx(float(bullet.slow), 0.55), "Allergieaura bremst später einfliegende Kugeln")
	bullet.p = Vector2(850, 330)
	bullet["prev_p"] = bullet.p
	g._update_hazards(0.0)
	check(is_equal_approx(float(bullet.slow), 1.0), "Allergieaura ist räumlich, keine dauerhafte Fremdbremse")
	g.bullets.enemy_bullets.clear()
	g.player.evolutions = [{"id": "pollen_blind", "level": 1}]
	g.spawn_pollen(Vector2(600, 200), 1.0)
	g.rng.seed = 190844
	var dissolved := 0
	var changed_after_retry := false
	for i in range(1000):
		g.bullets.enemy_bullets.clear()
		bullet = g.bullets.spawn_enemy(Vector2(100, 200), Vector2.ZERO, 1, "ebullet_orb")
		bullet["prev_p"] = Vector2(560, 200)
		bullet.p = Vector2(600, 200)
		g._update_hazards(0.0)
		if float(bullet.life) <= 0.0:
			dissolved += 1
		else:
			for retry in range(30):
				g._update_hazards(0.0)
				if float(bullet.life) <= 0.0:
					changed_after_retry = true
	check(dissolved > 350 and dissolved < 450, "Sichttrübung wirkt beim Eintritt mit40Prozent (%d/1000)" % dissolved)
	check(not changed_after_retry, "Sichttrübung würfelt jeKugel/Wolke nur einmal statt auf100Prozent aufzuschaukeln")
	g.bullets.enemy_bullets.clear()
	bullet = g.bullets.spawn_enemy(Vector2(600, 200), Vector2.ZERO, 1, "ebullet_orb", {"aimed": false})
	bullet["prev_p"] = bullet.p
	g._update_hazards(0.0)
	check(float(bullet.life) > 0.0, "Sichttrübung betrifft ausschließlich gezielte Kugeln")
	g.bullets.enemy_bullets.clear()
	bullet = g.bullets.spawn_enemy(g.player.position, Vector2.ZERO, 1, "ebullet_orb")
	bullet.life = 0.0
	g.player.iframes = 0.0
	g.player.shield_hits = 0
	var hp := g.player.hp
	g._update_collisions()
	check(g.player.hp == hp, "aufgelöstes Projektil verursacht im selben Tick keinen Geistertreffer")
	g.player.evolutions.clear()
	g.bullets.clear()
	var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(600, 270))
	e.hp = 1000.0
	check(g._homing_targets().has(e.position), "Schwarm-Zielsuche funktioniert ohne gekauftes Shop-Homing")
	g.miniboss = e
	g.player.shop_mods["boss_dmg"] = 0.5
	g.bullets.spawn_player(e.position, Vector2.ZERO, 10, "bullet_base", {"r": 1.0})
	g._update_collisions()
	check(is_equal_approx(1000.0 - e.hp, 15.0), "Bossbonus gilt auch für Minibosse")
	g.free()

func _test_splinters() -> void:
	var g := game()
	var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(600, 270))
	e.hp = 1.0e9
	g.player.evolutions = [{"id": "splinter", "level": 2}]
	g.player.shop_mods["splinter_chance"] = 1.0
	g.bullets.spawn_player(e.position, Vector2.ZERO, 10, "bullet_base", {"r": 1.0})
	g._update_collisions()
	check(g.bullets.player_bullets.size() == 7, "Splittstachel2+Werkstatt erzeugen begrenzt6Splitter statt Rekursion/ignoriertemShop")
	check(is_equal_approx(1.0e9 - e.hp, 10.0), "Splitter treffen ihr Ursprungsziel nicht sofort erneut")
	var secondary := 0
	for bullet in g.bullets.player_bullets:
		if int(bullet.get("proc_depth", 0)) == 1:
			secondary += 1
	check(secondary == 6, "alle Splitter sind als sekundär markiert")
	g.free()

func _test_checkpoint_drops_pollen() -> void:
	var g := game()
	g.player.evolutions = [{"id": "chitin_regen", "level": 1}]
	g.player.hp = 1
	g._take_checkpoint_snapshot()
	check(g.player.hp == 2, "Chitin-Regeneration heilt am echten Checkpoint")
	check(int(g.checkpoint_snapshot.hp) == 2, "Checkpoint sichert den geheilten Zustand")
	g.player.evolutions = [{"id": "nectar_scent", "level": 2}]
	g.player.shop_mods["nectar_plus"] = 1.0 # sichere Chance: immer ein Tropfen mehr
	for amount in [1, 6, 17]:
		for p in g.pickups:
			p.free()
		g.pickups.clear()
		g._drop_nectar(Vector2(500, 270), amount)
		var total := 0
		var count := 0
		for p in g.pickups:
			if p.kind == "nectar":
				total += p.value
				count += 1
		check(total == amount + 3, "Nektar-Drop%d erhält volle Summe%d stattObjektcap5" % [amount, amount + 3])
		check(count <= 5, "Nektar bleibt bei höchstens5Objekten")
	g.player.evolutions = [{"id": "pollen_trail", "level": 1}, {"id": "wind_rider", "level": 1}]
	g.player.vel = Vector2(120, -100)
	g.player.position = Vector2(300, 270)
	g.player.iframes = 0.0
	g.player.shield_hits = 0
	g.spawn_pollen(g.player.position, 1.0)
	var cloud: Dictionary = g.fx.hazards.back()
	check((cloud.vel as Vector2).x > -40.0 and (cloud.vel as Vector2).y < 0.0,
		"Windreiter-Pollen übernimmt die Flugrichtung der Biene")
	var hp := g.player.hp
	g._update_hazards(1.0 / 60.0)
	check(g.player.hp == hp, "eigene Pollenwolke verursacht niemals Selbstschaden")
	# Gegnerische Sporen müssen weiterhin schaden.
	g.fx.hazards.clear()
	g.fx.add_hazard({"kind": "spore_cloud", "p": g.player.position, "radius": 62.0, "t": 0.0,
		"life": 7.0, "max_life": 7.0, "vel": Vector2.ZERO, "dmg": 1, "hit_cd": 0.0})
	g._update_hazards(1.0 / 60.0)
	check(g.player.hp == hp - 1, "gegnerische Sporen verursachen weiterhin Schaden")
	g.free()

func _test_crit() -> void:
	var g := game()
	for case in [{"evo": 1, "shop": 0.0, "expected": 0.14}, {"evo": 2, "shop": 0.2, "expected": 0.48}, {"evo": 2, "shop": 0.8, "expected": 1.0}, {"evo": 1, "shop": -0.5, "expected": 0.0}]:
		g.player.evolutions = [{"id": "crit", "level": case.evo}]
		g.player.shop_mods["crit"] = case.shop
		seed(204190)
		var critical := 0
		for i in range(20000):
			if g._shot_damage(10.0) > 15.0:
				critical += 1
		var actual := float(critical) / 20000.0
		check(absf(actual - float(case.expected)) < 0.012,
			"Crit Evolution%d+Werkstatt%.2f: messbar%.3f statt ignorierter Evolution (Soll%.2f)" % [case.evo, case.shop, actual, case.expected])
	g.free()

func _test_splash_and_chain() -> void:
	var g := game()
	g.boss = Boss.new()
	g.boss.setup("rose_beetle")
	g.boss.position = Vector2(620, 270)
	g.add_child(g.boss)
	g.player.shop_mods["boss_dmg"] = 0.5
	var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(500, 270))
	e.hp = 1000.0
	var boss_hp := g.boss.hp
	var bullet := g.bullets.spawn_player(e.position, Vector2.ZERO, 10, "bullet_plasma", {"splash": 70.0, "r": 1.0})
	bullet["prev_p"] = e.position
	g._update_collisions()
	check(is_equal_approx(boss_hp - g.boss.hp, 7.5),
		"Plasma-Splash vom Nachbargegner trifft sichtbare Bossoberfläche mit Bossbonus einmal")
	# Direkt am Boss ausgelöst: Boss kein zweites Mal, Nachbar erhält Flächenschaden.
	g.bullets.player_bullets.clear()
	e.position = Vector2(540, 270)
	var enemy_hp := e.hp
	boss_hp = g.boss.hp
	bullet = g.bullets.spawn_player(g.boss.position, Vector2.ZERO, 10, "bullet_plasma", {"splash": 120.0, "r": 1.0})
	bullet["prev_p"] = bullet.p
	g._update_collisions()
	check(is_equal_approx(boss_hp - g.boss.hp, 15.0), "direkter Boss-Plasmatreffer ohne eigenen Splash-Doppeltreffer")
	check(is_equal_approx(enemy_hp - e.hp, 5.0), "Boss-Plasmatreffer löst Splash auf Nachbargegner aus")
	# Ein Projektil besitzt Kette+Blitzkette+Splash: Boss nur ein sekundärer Treffer.
	g.bullets.player_bullets.clear()
	boss_hp = g.boss.hp
	bullet = g.bullets.spawn_player(e.position, Vector2.ZERO, 10, "bullet_plasma", {"splash": 120.0, "chain": 1, "lchain": 1, "pierce": 5, "r": 1.0})
	bullet["prev_p"] = bullet.p
	g._update_collisions()
	check(is_equal_approx(boss_hp - g.boss.hp, 25.65), "Shopkette+Blitzkette+Splash ergänzen sich je einmal (Bossbonus zielweise)")
	g.free()
