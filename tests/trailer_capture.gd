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

func _level(level: int, shop: Dictionary = {}, weapon: String = "fan", upgrades: Dictionary = {}) -> void:
	Save.new_campaign("normal", 9100 + level)
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
			await _level(5, {"orbit": 3, "wave": 2}, "fan")
			_game()._on_hazard("wind_zone", {"dir": -1.0})
			_spawn_chain(["moth_line", "moth_arc"], 0.7)
			duration = 4.0
		"l6":
			await _level(6, {"spiral": 2}, "lightning", {"lightning": 3})
			_game()._on_hazard("reflect_panel", {})
			_spawn_chain(["moth_arc"], 0.6)
			duration = 5.0
		"l8":
			await _level(8, {"orbit": 3}, "plasma", {"plasma": 3})
			_spawn_chain(["moth_line", "moth_arc"], 0.8)
			duration = 4.0
		"l9":
			await _level(9, {"wave": 3, "wave_amp": 2}, "fan")
			_spawn_chain(["moth_arc", "moth_line", "moth_arc"], 0.7)
			duration = 4.0
		"boss_larva":
			await _level(2, {"orbit": 2}, "lightning", {"lightning": 3})
			_game()._spawn_boss()
			_later(2.4, func(): _game().boss.take_damage(_game().boss.max_hp * 0.75))
			duration = 7.5
		"boss_pike":
			await _level(3, {"wave": 2}, "fan")
			_game()._spawn_boss()
			_later(2.0, func(): _game().boss.take_damage(_game().boss.max_hp * 0.5))
			duration = 6.5
		"boss_mantis":
			await _level(5, {"orbit": 3}, "plasma", {"plasma": 3})
			_game()._spawn_boss()
			duration = 5.0
		"boss_queen":
			await _level(9, {"wave": 3}, "lightning", {"lightning": 3})
			_game()._spawn_boss()
			_later(3.0, func(): _game().boss.take_damage(_game().boss.max_hp * 0.45))
			duration = 6.0
		"boss_core":
			await _level(10, {"orbit": 3, "wave": 2}, "fan")
			_game()._spawn_boss()
			_later(3.2, func(): _game().boss.take_damage(_game().boss.max_hp * 0.4))
			duration = 6.5
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

func _spawn_chain(forms: Array, gap: float) -> void:
	for i in range(forms.size()):
		var f := String(forms[i])
		_later(0.2 + i * gap, func(): _game().director.spawn_formation(f))

func _later(t: float, fn: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(fn)

func _physics_process(delta: float) -> void:
	_t += delta
	if _pilot and app.game != null and is_instance_valid(app.game) and app.game.player != null:
		# Autopilot: ruhige Achterbahn im linken Drittel, zielt mal höher, mal tiefer.
		_pilot_phase += delta
		var p = app.game.player
		var goal := _pilot_center + Vector2(sin(_pilot_phase * 0.7) * 70.0, sin(_pilot_phase * 1.3) * 120.0)
		p.position = p.position.lerp(goal, clampf(delta * 3.0, 0.0, 1.0))
	if _t >= duration:
		set_physics_process(false)
		get_tree().quit(0)
