extends Node
## R3: Die Pause friert die komplette Spielwelt ein (Welt, Gegner, Geschosse,
## Hintergrund, Regie-Timer), auch bei Fokusverlust. Neustart am Checkpoint
## während einer Boss-Ankündigung oder der Miniboss-Wartezeit darf den Boss
## nicht nachträglich auslösen. Zusätzlich: Laufzeitschätzung der Regie.

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	# Der Prüfer selbst muss während der Pause weiterlaufen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	await _wait(0.4)
	await _run()
	for f in fails:
		print("R3_PAUSE_FEHLER: " + f)
	print("R3_PAUSE_OK" if fails.is_empty() else "R3_PAUSE_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _start_level(level: int) -> Node:
	Save.new_campaign("normal", 4242)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await _wait(2.8)
	_protect(app.game)
	return app.game

## Der Prüfling darf nicht sterben, sonst überlagert Game Over die Messung.
func _protect(g: Node) -> void:
	if g != null and is_instance_valid(g) and g.player != null:
		g.player.max_hp = 99
		g.player.hp = 99
		g.player.iframes = 1.0e6

func _snapshot(g: Node) -> Dictionary:
	var positions: Array = []
	for e in g.enemies:
		if is_instance_valid(e):
			positions.append(e.position)
	return {"time": float(g.stats.time), "director": float(g.director.time),
		"scroll": float(g.background.scroll), "player": g.player.position,
		"enemies": positions, "bullets": g.bullets.get_child_count() if g.bullets != null else 0,
		"spawn_t": float(g.director.spawn_t)}

func _run() -> void:
	var g := await _start_level(1)
	_ok(g != null and is_instance_valid(g), "Level 1 läuft")
	# Gegner herbeirufen, damit sich wirklich etwas bewegen könnte.
	g.director.spawn_formation("moth_line")
	await _wait(0.3)
	var before := _snapshot(g)
	_ok(before.time > 0.0, "Spielzeit läuft vor der Pause (%.2f s)" % before.time)

	# --- Pause über das Menü: eine volle Sekunde mit gedrückter Bewegung
	app.pause_game()
	Input.action_press("move_right")
	Input.action_press("fire")
	await _wait(1.0)
	var during := _snapshot(g)
	_ok(app.paused and get_tree().paused, "Pausezustand gesetzt")
	_ok(not app.screens.is_empty(), "Pausebildschirm offen")
	_ok(is_equal_approx(during.time, before.time), "Spielzeit steht still (%.3f → %.3f)" % [before.time, during.time])
	_ok(is_equal_approx(during.director, before.director), "Levelregie steht still (%.3f → %.3f)" % [before.director, during.director])
	_ok(is_equal_approx(during.scroll, before.scroll), "Hintergrund scrollt nicht weiter")
	_ok(during.player == before.player, "Biene bewegt sich trotz gehaltener Taste nicht")
	_ok(during.enemies == before.enemies, "Gegner bewegen sich nicht (%d)" % before.enemies.size())
	_ok(is_equal_approx(during.spawn_t, before.spawn_t), "Spawn-Timer steht still")
	Input.action_release("move_right")
	Input.action_release("fire")

	# --- Fortsetzen: kurze Schonfrist, danach läuft alles weiter
	app.resume_game()
	await _wait(1.6)
	for _i in range(30):
		if float(g.stats.time) > during.time + 0.3:
			break
		await _wait(0.1)
	var after := _snapshot(g)
	_ok(not app.paused and not get_tree().paused, "Pause aufgehoben")
	_ok(after.time > during.time + 0.3, "Spielzeit läuft nach dem Fortsetzen weiter")

	# --- Fokusverlust pausiert ebenso sicher
	app._on_focus(false)
	var t0: float = g.stats.time
	await _wait(0.6)
	_ok(app.paused, "Fokusverlust pausiert")
	_ok(is_equal_approx(float(g.stats.time), t0), "Fokusverlust: Welt steht")
	app._on_focus(true)
	app.resume_game()
	await _wait(1.2)

	# --- Laufzeitschätzung der Regie (neu in R3)
	_ok(g.director.has_method("eta"), "Regie liefert Laufzeitschätzung")
	if g.director.has_method("eta"):
		var info: Dictionary = g.director.eta()
		var remaining := float(info.get("remaining", -1.0))
		_ok(remaining > 0.0 and remaining <= float(g.director.level_duration) + 10.0,
			"Restzeit plausibel (%.1f s von %.1f s)" % [remaining, g.director.level_duration])
		_ok(float(info.get("progress", -1.0)) >= 0.0 and float(info.get("progress", 2.0)) < 0.2,
			"Fortschritt am Levelanfang klein")
		_ok((info.get("marks", []) as Array).size() == g.director.checkpoint_times.size() - 1,
			"Checkpoint-Markierungen vorhanden")
		# Unter Last laufen Physikbilder langsamer als die Uhr: auf echten Spielfortschritt warten.
		var t_before: float = g.director.time
		for _i in range(40):
			if float(g.director.time) - t_before >= 0.6:
				break
			await _wait(0.1)
		var later: Dictionary = g.director.eta()
		var advanced: float = float(g.director.time) - t_before
		_ok(advanced > 0.0 and absf((remaining - float(later.remaining)) - advanced) < 0.05,
			"Restzeit sinkt beim Spielen um die gespielte Zeit (%.2f s)" % advanced)
		app.pause_game()
		var frozen: Dictionary = g.director.eta()
		await _wait(0.8)
		_ok(is_equal_approx(float(g.director.eta().remaining), float(frozen.remaining)),
			"Restzeit steht während der Pause")
		app.resume_game()
		await _wait(1.2)

	# --- Neustart am Checkpoint während der Boss-Ankündigung
	g.director.start_boss_now()
	await _wait(0.2)
	app.pause_game()
	g._restore_checkpoint()
	_protect(g)
	app.resume_game()
	await _wait(2.6)
	_ok(g.boss == null or not is_instance_valid(g.boss), "Kein Boss nach Checkpoint-Neustart während der Ankündigung")
	_ok(not bool(g.director.boss_started), "Regie wartet nach Neustart wieder auf den Levelablauf")

	# --- Neustart während der Miniboss-Wartezeit am Abschnittsende
	var secs: Array = g.director.level_data.sections
	g.director.section = secs.size() - 1
	g.director.section_t = float(secs[-1].dur) - 0.05
	g.director.miniboss_done = false
	g.director.intro_t = 0.0
	g.resume_delay = 0.0
	await _wait(0.5)
	_ok(bool(g.director.miniboss_done) and g.director.section >= secs.size(),
		"Abschnittsende erreicht, Miniboss-Wartezeit läuft")
	g._restore_checkpoint()
	_protect(g)
	await _wait(9.0)
	print("  info: boss_started=%s section=%d time=%.1f" % [g.director.boss_started, g.director.section, g.director.time])
	_ok(not bool(g.director.boss_started) and (g.boss == null or not is_instance_valid(g.boss)),
		"Wartezeit löst nach Checkpoint-Neustart keinen Boss aus")

	# --- Nach Levelende keine Pause über die Ergebnisfolge legen
	g.level_over = true
	app._on_focus(false)
	_ok(not app.paused, "Kein Pausebildschirm nach Levelende")
	app.menu_main()
	await _wait(0.3)
