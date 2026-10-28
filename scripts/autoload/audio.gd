extends Node
## Audio: eigene Audiobusse (Master/Musik/SFX/UI), Musik-Crossfade,
## SFX-Pool mit begrenzter Stimmenzahl und kontrollierter Variation.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
## Gesprochene Ansagen (z. B. Upgrade-Wahl im HUD), je Kennung eine Datei.
const VOICE_DIR := "res://assets/audio/voice/"

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}
var _current_music := ""
var _fade_tween: Tween
var _last_sfx_time: Dictionary = {}
var _unfocused_mute := false
var _master_scale := 1.0
## Durchkomponierte Leveltracks: ab dieser Länge kein Loop, Wiedergabe folgt der Levelzeit.
const TIMED_MIN_LENGTH := 120.0
## Erlaubte Abweichung zwischen Wiedergabe und Levelzeit, bevor nachgestellt wird.
const SYNC_TOLERANCE := 0.3
var _music_hold := false
## Zeitpunkt (ms) des letzten Nachstellens: höchstens einmal pro Sekunde springen.
var _last_seek_ms := -100000
var _voice_player: AudioStreamPlayer
var _voice_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_active_music = _music_a
	for i in range(14):
		_sfx_players.append(_make_player("SFX"))
	for i in range(4):
		_ui_players.append(_make_player("UI"))
	_voice_player = _make_player("UI")
	apply_volumes()

func _setup_buses() -> void:
	for name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_mute(0, false)

func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func apply_volumes() -> void:
	var m: float = float(Save.g("audio.master", 0.9))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, m)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(Save.g("audio.music", 0.75)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(Save.g("audio.sfx", 0.85)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(maxf(0.0001, float(Save.g("audio.ui", 0.7)))))
	var mute := _unfocused_mute and bool(Save.g("audio.mute_unfocused", true))
	AudioServer.set_bus_mute(0, mute)

func set_unfocused(v: bool) -> void:
	_unfocused_mute = v
	apply_volumes()

func _load_music(name: String) -> AudioStream:
	if _music_cache.has(name):
		return _music_cache[name]
	for ext in [".ogg", ".wav"]:
		var path: String = MUSIC_DIR + name + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			var loop := not _is_timed_stream(name, s)
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = loop
			elif s is AudioStreamWAV:
				(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
			_music_cache[name] = s
			return s
	_music_cache[name] = null
	return null

## Leveltracks (level1 … level10), die lang genug sind, laufen ohne Loop durch.
static func _is_timed_stream(name: String, s: AudioStream) -> bool:
	return name.begins_with("level") and name.trim_prefix("level").is_valid_int() \
		and s != null and s.get_length() >= TIMED_MIN_LENGTH

func is_timed_music(name: String) -> bool:
	return _is_timed_stream(name, _load_music(name))

## from_pos: Startposition in Sekunden (Checkpoint-Neustart mitten im Track).
func play_music(name: String, fade: float = 0.8, from_pos: float = 0.0) -> void:
	if name == _current_music and _active_music.playing:
		return
	_current_music = name
	var stream := _load_music(name)
	if stream == null:
		return
	var next: AudioStreamPlayer = _music_b if _active_music == _music_a else _music_a
	next.stream = stream
	next.volume_db = -40.0
	next.stream_paused = false
	_music_hold = false
	next.play(clampf(from_pos, 0.0, maxf(0.0, stream.get_length() - 0.05)))
	var old := _active_music
	_active_music = next
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(next, "volume_db", 0.0, fade)
	if old.playing:
		_fade_tween.tween_property(old, "volume_db", -40.0, fade)
		_fade_tween.chain().tween_callback(old.stop)

## Musik anhalten/fortsetzen (Pause, Wiederanlauf), ohne die Position zu verlieren.
func set_music_hold(hold: bool) -> void:
	if hold == _music_hold:
		return
	_music_hold = hold
	_active_music.stream_paused = hold

## Hält einen durchkomponierten Leveltrack an der Levelzeit. Wirkt nur, solange
## genau dieser Track läuft (die Bossmusik löst ihn ab).
func sync_music(name: String, pos: float) -> void:
	if name != _current_music or _music_hold or not is_timed_music(name):
		return
	# Zeitlupe/Zeitraffer (Tests, Effekte): Musik läuft in Echtzeit, Nachstellen wäre sinnlos.
	if not is_equal_approx(Engine.time_scale, 1.0):
		return
	var length := _active_music.stream.get_length() if _active_music.stream != null else 0.0
	if pos >= length - 0.05:
		return
	if not _active_music.playing:
		_active_music.play(maxf(0.0, pos))
		return
	var at := _active_music.get_playback_position() + AudioServer.get_time_since_last_mix()
	var now := Time.get_ticks_msec()
	if absf(at - pos) > SYNC_TOLERANCE and now - _last_seek_ms > 1000:
		_last_seek_ms = now
		_active_music.seek(maxf(0.0, pos))

func stop_music(fade: float = 0.8) -> void:
	_current_music = ""
	if _active_music.playing:
		var p := _active_music
		_fade_tween = create_tween()
		_fade_tween.tween_property(p, "volume_db", -40.0, fade)
		_fade_tween.tween_callback(p.stop)

func _load_sfx(name: String) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	for ext in [".wav", ".ogg"]:
		var path: String = SFX_DIR + name + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			_sfx_cache[name] = s
			return s
	_sfx_cache[name] = null
	return null

func sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0, ui: bool = false) -> void:
	# Drosselung: identische kurze Effekte nicht im selben Frame stapeln
	var now := Time.get_ticks_msec()
	if _last_sfx_time.has(name) and now - int(_last_sfx_time[name]) < 28:
		return
	_last_sfx_time[name] = now
	var pool := _ui_players if ui else _sfx_players
	var p: AudioStreamPlayer = null
	for cand in pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = pool[0]
	var stream := _load_sfx(name)
	if stream == null:
		return
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.play()

## Kurze Sprachansage. Bevorzugt vorgerenderte Clips (gleich auf allen Systemen),
## sonst die Sprachausgabe des Betriebssystems, falls eine deutsche Stimme da ist.
## Eine neue Ansage unterbricht die vorige: schnelles Blättern bleibt verständlich.
func voice(id: String, text: String) -> void:
	if not bool(Save.g("audio.voice_upgrades", true)):
		return
	var stream := _load_voice(id)
	if stream != null:
		_voice_player.stop()
		_voice_player.stream = stream
		_voice_player.volume_db = 2.0
		_voice_player.play()
		return
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voices := DisplayServer.tts_get_voices_for_language("de")
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	var vol := int(clampf(float(Save.g("audio.ui", 0.7)) * float(Save.g("audio.master", 0.9)) * 100.0, 10.0, 100.0))
	DisplayServer.tts_speak(text, voices[0], vol, 1.0, 1.25)

func _load_voice(id: String) -> AudioStream:
	if _voice_cache.has(id):
		return _voice_cache[id]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(VOICE_DIR + id + ext):
			stream = load(VOICE_DIR + id + ext)
			break
	_voice_cache[id] = stream
	return stream

func sfx_var(name: String, volume_db: float = 0.0) -> void:
	sfx(name, volume_db, randf_range(0.94, 1.06))
