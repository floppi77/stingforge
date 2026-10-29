extends Node
## Realer zentraler Spawn: feste Folge ohne neue Zufallsentscheidungen.
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	await get_tree().process_frame
	for level in [1, 5, 10]:
		for difficulty in ["relaxed", "normal", "expert"]:
			var sequences: Array = []
			for repeat in range(2):
				Save.new_campaign(difficulty, 18031)
				var g := Game.new()
				g.level_index = level
				g.eb_speed = 1.0 + 0.035 * float(level - 1)
				g.difficulty = Data.DIFFICULTY[difficulty]
				g.bullets = BulletField.new()
				g.add_child(g.bullets)
				var sequence: Array = []
				seed(9051)
				var expected_rng := randf()
				seed(9051)
				for i in range(1000):
					g.bullets.enemy_bullets.clear()
					g.spawn_enemy_bullet(Vector2(i, 270), Vector2(-200, 0), 1, "ebullet_orb")
					if not g.bullets.enemy_bullets.is_empty():
						sequence.append(i)
						check_velocity(g, level, difficulty)
				check(is_equal_approx(randf(), expected_rng), "%s L%d verbraucht kein RNG" % [difficulty, level])
				var expect: int = {"relaxed": 600, "normal": 800, "expert": 1000}[difficulty]
				check(sequence.size() == expect,
					"%s L%d: %d/1000 Projektile" % [difficulty, level, sequence.size()])
				sequences.append(sequence)
				g.free()
			check(sequences[0] == sequences[1], "%s L%d reproduzierbare Folge" % [difficulty, level])
	# Echte Gegner- und Bossproduzenten müssen denselben zentralen Filter nutzen.
	for difficulty in ["normal", "expert"]:
		Save.new_campaign(difficulty, 18031)
		var g := Game.new()
		g.difficulty = Data.DIFFICULTY[difficulty]
		g.bullets = BulletField.new()
		g.add_child(g.bullets)
		var e := Enemy.new()
		e.setup("moth", Vector2(800, 270))
		g.add_child(e)
		for i in range(10):
			e._shoot()
		check(g.bullets.enemy_count() == (10 if difficulty == "expert" else 8), difficulty + " Gegnerproduzent")
		var boss := Boss.new()
		boss.setup("rose_beetle")
		g.add_child(boss)
		boss._p_radial(10, 1.0)
		boss._tick_timeline(0.5)
		check(g.bullets.enemy_count() == (20 if difficulty == "expert" else 16), difficulty + " Bossproduzent")
		g.free()
	# Training/Rush darf nicht versehentlich das globale Menü-Preset benutzen.
	var active_before := Save.active_campaign
	var menu_before: String = String(Save.settings.game.difficulty)
	for case in [{"run": "expert", "menu": "relaxed", "expected": 1000}, {"run": "normal", "menu": "expert", "expected": 800}]:
		Save.active_campaign = false
		Save.settings.game.difficulty = case.menu
		var g := Game.new()
		g.difficulty = Data.DIFFICULTY[case.run]
		g.bullets = BulletField.new()
		g.add_child(g.bullets)
		var count := 0
		for i in range(1000):
			g.bullets.enemy_bullets.clear()
			g.spawn_enemy_bullet(Vector2(800, 270), Vector2.LEFT * 200.0, 1, "ebullet_orb")
			count += g.bullets.enemy_count()
		check(count == int(case.expected), "inaktivesCampaign: Spiel%s vor Menü%s liefert%d/1000" % [case.run, case.menu, count])
		g.free()
	Save.active_campaign = active_before
	Save.settings.game.difficulty = menu_before
	var incoming := BulletField.new()
	incoming.spawn_enemy(Vector2(480, -20), Vector2.DOWN * 200.0, 1, "ebullet_spore")
	incoming.update(0.5, Vector2(160, 270))
	check(incoming.enemy_count() == 1 and is_equal_approx((incoming.enemy_bullets[0].p as Vector2).y, 80.0),
		"Gegnerfeuer darf von oberhalb des Headers in den Spielraum einlaufen")
	incoming.free()
	print("STINGFORGE_WORLD_DENSITY checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	if failures.is_empty():
		print("STINGFORGE_WORLD_DENSITY_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func check_velocity(g: Game, level: int, difficulty: String) -> void:
	var b: Dictionary = g.bullets.enemy_bullets[0]
	var diff_speed := float(Data.DIFFICULTY[difficulty].bullet_speed)
	if not is_equal_approx((b.v as Vector2).x, -200.0 * (1.0 + 0.035 * float(level - 1)) * diff_speed):
		check(false, "Levelgeschwindigkeit unverändert")
