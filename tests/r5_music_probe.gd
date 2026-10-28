extends Node
## R5: Durchkomponierte Levelmusik ohne Loop folgt der Levelzeit: Start bei 0,
## Pause hält sie an, Checkpoint-Neustart springt an die Abschnittsgrenze, die
## Tracklänge entspricht exakt Intro + Abschnitte + Bossankündigung.

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	await _wait(0.4)
	await _run()
	for f in fails:
		print("R5_MUSIC_FEHLER: " + f)
	print("R5_MUSIC_OK" if fails.is_empty() else "R5_MUSIC_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _protect(g: Node) -> void:
	if g != null and is_instance_valid(g) and g.player != null:
		g.player.max_hp = 99
		g.player.hp = 99
		g.player.iframes = 1.0e6

func _player() -> AudioStreamPlayer:
	return Audio._active_music

func _pos() -> float:
	return _player().get_playback_position() + AudioServer.get_time_since_last_mix()

func _run() -> void:
	var stream: AudioStream = load("res://assets/audio/music/level1.ogg")
	var data: Dictionary = Data.level(1)
	var expected := Director.INTRO_TIME + 1.25
	for sec in data.sections:
		expected += float(sec.dur)
	_ok(absf(stream.get_length() - expected) < 0.05,
		"Level 1: Tracklänge %.2f s = Levelweg bis Bossmusik %.2f s" % [stream.get_length(), expected])
	_ok(Audio.is_timed_music("level1"), "Level 1 ist ein durchkomponierter Track")
	for lv in range(2, 11):
		var ld: Dictionary = Data.level(lv)
		var want := Director.INTRO_TIME + 1.25
		for sec in ld.sections:
			want += float(sec.dur)
		var st: AudioStream = load("res://assets/audio/music/%s.ogg" % String(ld.music))
		_ok(st != null and absf(st.get_length() - want) < 0.05 and Audio.is_timed_music(String(ld.music)),
			"Level %d: eigener Track %.2f s = Levelweg %.2f s" % [lv, st.get_length() if st != null else 0.0, want])
	_ok(not Audio.is_timed_music("menu") and not Audio.is_timed_music("boss1"), "Menü und Boss bleiben geloopt")

	Save.new_campaign("normal", 5151)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(1, 0)
	await _wait(0.3)
	_protect(app.game)
	var oggs := _player().stream as AudioStreamOggVorbis
	_ok(oggs != null and not oggs.loop, "Leveltrack läuft ohne Loop")
	await _wait(3.5)
	_protect(app.game)
	var drift := absf(_pos() - app.game.director.music_pos())
	_ok(drift < 0.35, "Musik folgt der Levelzeit (Abweichung %.2f s)" % drift)

	# Pause: Musik steht, danach läuft sie an derselben Stelle weiter.
	app.pause_game()
	await _wait(0.3)
	var held := _pos()
	await _wait(1.2)
	_ok(absf(_pos() - held) < 0.08 and _player().stream_paused, "Pause hält die Musik an (%.2f → %.2f)" % [held, _pos()])
	app.resume_game()
	await _wait(2.0)
	drift = absf(_pos() - app.game.director.music_pos())
	_ok(not _player().stream_paused and drift < 0.35, "Nach der Pause wieder synchron (Abweichung %.2f s)" % drift)

	# Checkpoint-Neustart: Musik setzt an der Abschnittsgrenze minus Kurzintro an.
	app._begin_level(1, 2)
	await _wait(0.3)
	_protect(app.game)
	var cp_track: float = Director.INTRO_TIME + float(data.sections[0].dur) + float(data.sections[1].dur)
	await _wait(2.0)
	var want: float = app.game.director.music_pos()
	_ok(want > cp_track - 1.5 and absf(_pos() - want) < 0.35,
		"Checkpoint 3: Musik bei %.1f s (Abschnitt beginnt bei %.1f s)" % [_pos(), cp_track])
	app.menu_main()
	await _wait(0.3)
