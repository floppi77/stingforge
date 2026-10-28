extends Node
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	await get_tree().process_frame
	Save.new_campaign("normal", 18031)
	var found: Array[String] = []
	for id in Data.ENEMIES:
		if String(Data.enemy(id).behavior) in ["dive", "charge"]:
			found.append(id)
	check(found == ["wasp_dart", "piston_drone"], "tatsächliche Verfolger-IDs aus Daten erfasst")
	for level in [1, 5, 10]:
		for id in found:
			for multiplier in [1.0, 1.8]:
				var g := Game.new()
				g.level_index = level
				g.player = Player.new()
				g.player.position = Vector2(300, 270)
				g.add_child(g.player)
				var e := Enemy.new()
				e.setup(id, Vector2(800, 270), {"speed_mult": multiplier})
				g.add_child(e)
				e.shots = ""
				var peak := 0.0
				var turned_back := false
				for i in range(600):
					# Nach dem Anflug weicht die Biene hinter den Angreifer aus.
					if i == 100:
						g.player.position = Vector2(950, 320)
					var before := e.position
					e._physics_process(1.0 / 60.0)
					peak = maxf(peak, e.position.distance_to(before) * 60.0)
					if e.position.x > before.x + 0.001:
						turned_back = true
				check(peak <= (160.0 if id == "wasp_dart" else 145.0) + 0.01,
					"%s L%d x%.1f: Höchsttempo %.1f deutlich unter252" % [id, level, multiplier, peak])
				check(not turned_back, "%s L%d dreht nicht zum endlosen Verfolgen um" % [id, level])
				check(e.position.x < -90.0, "%s L%d verlässt nach einem Anflug das Feld" % [id, level])
				g.free()
	# Jede Musterroutine bewegt selbst; der gemeinsame Tick darf x nicht erneut addieren.
	for id in ["moth", "beetle_grunt", "aphid_swarm", "pollen_pod", "mosquito_pair", "canal_crawler", "pike_fry", "mantis_stalker"]:
		var e := Enemy.new()
		e.setup(id, Vector2(800, 270))
		e.shots = ""
		var old_x := e.position.x
		e._physics_process(1.0 / 60.0)
		check(absf((old_x - e.position.x) * 60.0 - e.speed) < 0.02,
			id + " bewegt sich einmal mit Daten-Geschwindigkeit")
		e.free()
	# Echte Spritehalbausdehnung, nicht nur der kleinere Kollisionsradius.
	for id in Data.ENEMIES:
		for y in [0.0, 800.0]:
			var e := Enemy.new()
			e.setup(id, Vector2(800, y))
			e.shots = ""
			e.age = 2.0
			e._physics_process(1.0 / 60.0)
			var half_height := float(Art.info(String(e.def.sprite)).h) * 0.5
			check(e.position.y - maxf(e.radius, half_height) >= App.PLAY_TOP - 0.001,
				id + " bleibt mit sichtbarem Sprite unter Header")
			check(e.position.y + maxf(e.radius, half_height) <= App.PLAY_BOTTOM + 0.001,
				id + " bleibt mit sichtbarem Sprite über Unterkante")
			e.free()
	print("STINGFORGE_WORLD_MOTION checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	if failures.is_empty():
		print("STINGFORGE_WORLD_MOTION_OK")
	get_tree().quit(0 if failures.is_empty() else 1)
