extends Node
## Trailer-Aufnahme: spielt eine Szene ab, während Godots Movie Maker jedes Bild
## schreibt (--write-movie, feste 60 fps). Ohne HUD, Biene mit Autopilot.
## Aufruf: godot --path . --write-movie build/trailer/raw/<clip>.avi --fixed-fps 60 \
##         tests/trailer_capture.tscn -- clip=<name>

var app: Node
var clip := "test"
var duration := 3.0
var _t := 0.0
var _pilot := true
var _pilot_phase := 0.0
var _pilot_center := Vector2(200, 270)
var _pilot_amp := Vector2(70.0, 120.0)
var _max_bullets := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("clip="):
			clip = a.trim_prefix("clip=")
	app.fade.color.a = 0.0
	Audio.set_unfocused(false)
	await _setup()

func _level(level: int, shop: Dictionary = {}, weapon: String = "fan", upgrades: Dictionary = {},
		difficulty: String = "normal") -> void:
	Save.new_campaign(difficulty, 9100 + level)
	Save.campaign.shop = shop
	var u := {"base": 1, "fan": 3, "lightning": 0, "plasma": 0, "companion": 2, "bombs": 0, "shield": 3, "speed": 1}
	u.merge(upgrades, true)
	Save.campaign.upgrades = u
	Save.campaign.weapon = weapon
	Save.campaign.nectar = 120
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	if app.hud != null:
		app.hud.visible = false
	var g = app.game
	g.player.max_hp = 99
	g.player.hp = 99
	g.player.iframes = 1.0e6
	g.player.autofire = true
	g.director.intro_t = 0.0

func _game() -> Node:
	return app.game

func _setup() -> void:
	match clip:
		"menu":
			app.menu_main()
			duration = 5.0
			_pilot = false
		"l1":
			await _level(1, {"orbit": 2, "wave": 1})
			_spawn_chain(["moth_arc", "aphid_cloud", "moth_line"], 0.9)
			duration = 5.5
		"l3":
			await _level(3, {"wave": 2, "wave_amp": 1}, "lightning", {"lightning": 3})
			_spawn_chain(["reed_leap", "moth_line"], 0.8)
			_game().spawn_geyser(560.0)
			_later(1.6, func(): _game().spawn_geyser(760.0))
			duration = 4.5
		"l4":
			await _level(4, {"homing": 3}, "plasma", {"plasma": 3})
			_game()._on_hazard("spore_cloud", {"y": 0.4, "dir": 1.0})
			_spawn_chain(["moth_arc", "pod_field"], 0.9)
			duration = 4.0
		"l5":
			await _level(5, {"wave": 2, "wave_amp": 1}, "fan")
			_game()._on_hazard("wind_zone", {"dir": -1.0})
			_spawn_chain(["moth_line", "moth_arc"], 0.7)
			duration = 4.0
		"l6":
			await _level(6, {"spiral": 2}, "lightning", {"lightning": 3})
			_game()._on_hazard("reflect_panel", {})
			_spawn_chain(["moth_arc"], 0.6)
			duration = 5.0
		"l8":
			await _level(8, {"homing": 2}, "plasma", {"plasma": 3})
			_spawn_chain(["moth_line", "moth_arc"], 0.8)
			duration = 4.0
		"l9":
			await _level(9, {"wave": 3, "wave_amp": 2}, "fan")
			_spawn_chain(["moth_arc", "moth_line", "moth_arc"], 0.7)
			duration = 4.0
		"boss_larva":
			await _level(2, {"spiral": 1}, "lightning", {"lightning": 3}, "expert")
			_game()._spawn_boss()
			_later(2.4, func(): _game().boss.take_damage(_game().boss.max_hp * 0.75))
			duration = 7.5
		"boss_pike":
			await _level(3, {"wave": 2}, "fan", {}, "expert")
			_game()._spawn_boss()
			_later(2.0, func(): _game().boss.take_damage(_game().boss.max_hp * 0.5))
			duration = 6.5
		"boss_mantis":
			await _level(5, {"homing": 2}, "plasma", {"plasma": 3}, "expert")
			_game()._spawn_boss()
			duration = 5.0
		"boss_queen":
			await _level(9, {"wave": 3}, "lightning", {"lightning": 3}, "expert")
			_game()._spawn_boss()
			_later(3.0, func(): _game().boss.take_damage(_game().boss.max_hp * 0.45))
			duration = 6.0
		"boss_core":
			await _level(10, {"wave": 2}, "fan", {}, "expert")
			_game()._spawn_boss()
			_later(3.2, func(): _game().boss.take_damage(_game().boss.max_hp * 0.4))
			duration = 6.5
		# Bullet-Hell: Experte, viele echte Schützen gleichzeitig, zähere Gegner,
		# damit das Sperrfeuer stehen bleibt. Biene weicht in engeren Bögen aus.
		"bh_fungus":
			await _level(4, {}, "base", {"fan": 1, "companion": 1}, "expert")
			_spawn_chain(["mushroom_guard", "ladybug_pair", "spore_field", "mushroom_guard", "dragonfly_dash",
				"ladybug_pair", "mushroom_guard", "generator_order"], 0.35, 6.0)
			_bullet_pilot()
			duration = 6.0
		"bh_glass":
			await _level(6, {}, "lightning", {"fan": 0, "lightning": 1, "companion": 1}, "expert")
			_spawn_chain(["generator_order", "glass_drone_row", "mirror_orbit", "ladybug_pair", "generator_order",
				"mirror_orbit", "glass_drone_row"], 0.35, 6.0)
			_bullet_pilot()
			duration = 5.5
		"bh_hive":
			await _level(9, {}, "base", {"fan": 1, "companion": 1}, "expert")
			_spawn_chain(["hive_guard_row", "acolyte_orbit", "ladybug_pair", "hive_guard_row", "acolyte_orbit",
				"mushroom_guard"], 0.4, 5.0)
			_bullet_pilot()
			duration = 6.0
		"bh_core":
			await _level(10, {}, "plasma", {"fan": 0, "plasma": 1, "companion": 1}, "expert")
			_spawn_chain(["core_pulse", "generator_order", "shard_orbit", "mirror_orbit", "core_pulse",
				"generator_order"], 0.4, 5.0)
			_bullet_pilot()
			duration = 6.0
		# Prüfbild für den CRT-Filter (Spiel mit HUD), nicht Teil des Trailers.
		"crt_check":
			Save.set_g("graphics.crt", true)
			app._apply_post_shader()
			await _level(3, {"wave": 2}, "fan")
			app.hud.visible = true
			_spawn_chain(["reed_leap", "moth_line"], 0.6)
			duration = 2.5
		# Prüfbild Teich: Springbarsche und Brunnenfontänen.
		"water_check":
			await _level(3, {"wave": 1}, "base", {"fan": 0, "companion": 0})
			_game().spawn_geyser(520.0)
			_later(0.9, func(): _game().spawn_geyser(700.0))
			for i in range(3):
				_game().spawn_enemy("leap_fish", Vector2(640.0 + i * 46.0, App.PLAY_BOTTOM + 30.0), {"delay": 0.2 + i * 0.45})
			_pilot_center = Vector2(150, 200)
			duration = 4.0
		# Prüfbild Meisterevolutionen: Pollensturm, Echoschild, Schildwall, Todesmal, Goldrausch.
		"masters_check":
			await _level(4, {}, "fan", {"fan": 2, "companion": 3})
			var evos := ["pollen_trail", "wind_rider", "m_pollen_storm", "resonance_calm", "resonance_pulse",
				"m_echo_shield", "companion_form", "drone_sacrifice", "m_shield_wall", "crit", "swarm_mark",
				"m_death_mark", "nectar_bargain", "nectar_gluttony", "m_gold_rush"]
			_game().player.evolutions = []
			for id in evos:
				_game().player.evolutions.append({"id": id, "level": 2 if id == "crit" else 1})
			_game().masters.echo_t = 6.0
			_spawn_chain(["ladybug_pair", "moth_arc", "mushroom_guard"], 0.5, 3.0)
			duration = 4.5
		"shop":
			Save.new_campaign("normal", 991)
			Save.campaign.points = 42000
			Save.campaign.shop = {"wave": 1, "orbit": 2}
			app.mode = "campaign"
			app.clear_screens()
			var shop = app.push_screen("res://scripts/screens/shop_screen.gd", {"level": 3}, 0.0)
			_later(0.8, func(): shop._enter_items())
			_later(1.6, func(): shop._move_focus(1))
			_later(2.8, func(): shop._move_focus(1))
			duration = 4.2
			_pilot = false
		_:
			await _level(1)
			duration = 3.0

func _spawn_chain(forms: Array, gap: float, hp_scale: float = 1.0) -> void:
	for i in range(forms.size()):
		var f := String(forms[i])
		_later(0.2 + i * gap, func(): _game().director.spawn_formation(f, hp_scale))

## Ausweichflug fürs Sperrfeuer: weiter links, schnellere, kleinere Haken.
func _bullet_pilot() -> void:
	_pilot_center = Vector2(170, 270)
	_pilot_amp = Vector2(45.0, 150.0)

func _later(t: float, fn: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(fn)

func _physics_process(delta: float) -> void:
	_t += delta
	if _pilot and app.game != null and is_instance_valid(app.game) and app.game.player != null:
		# Autopilot: ruhige Achterbahn im linken Drittel, zielt mal höher, mal tiefer.
		_pilot_phase += delta
		var p = app.game.player
		var goal := _pilot_center + Vector2(sin(_pilot_phase * 0.7) * _pilot_amp.x, sin(_pilot_phase * 1.3) * _pilot_amp.y)
		p.position = p.position.lerp(goal, clampf(delta * 3.0, 0.0, 1.0))
	if app.game != null and is_instance_valid(app.game):
		_max_bullets = maxi(_max_bullets, app.game.bullets.enemy_bullets.size())
	if _t >= duration:
		print("TRAILER_CLIP %s max_enemy_bullets=%d" % [clip, _max_bullets])
		set_physics_process(false)
		get_tree().quit(0)
