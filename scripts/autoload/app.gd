extends Node
## Anwendungsfluss: Fenster/Anzeige, Screen-Stack, Kampagnen-Zustandsmaschine,
## Pause, Fokusverlust, Controller-Trennung.

## Spiellogik und Pixelkunst leben im 960 × 540-Raster; gerendert wird die Welt
## doppelt so fein (1920 × 1080), damit Bewegung und Effekte weich bleiben.
const WORLD_SIZE := Vector2i(960, 540)
const RENDER_SCALE := 2
const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
	# Ultrawide: Spielfeld bleibt 16:9, die Ränder zeigen den Hintergrund weiter.
	Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(5120, 1440),
]
const RES_LABELS := ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440", "3840 × 2160",
	"2560 × 1080", "3440 × 1440", "5120 × 1440"]

## Auflösungen, die auf den aktuellen Monitor passen (mindestens 1280 × 720).
## So kann man keine Größe wählen, die das Fenster gar nicht darstellen kann.
func resolution_options(mon_override: int = -1) -> Array:
	var mon: int = mon_override
	if mon < 0:
		mon = int(Save.g("display.monitor", 0)) if Save != null else 0
	mon = clampi(mon, 0, maxi(0, DisplayServer.get_screen_count() - 1))
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(mon).size
	if usable.x <= 0 or usable.y <= 0:
		usable = Vector2i(1920, 1080)
	var out: Array = []
	for r in RESOLUTIONS:
		var v: Vector2i = r
		if v.x <= usable.x and v.y <= usable.y:
			out.append(v)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out

func resolution_labels() -> Array:
	var out: Array = []
	for r in resolution_options():
		var v: Vector2i = r
		out.append("%d × %d" % [v.x, v.y])
	return out

func resolution_index() -> int:
	var opts := resolution_options()
	var want: Vector2i = RESOLUTIONS[clampi(int(Save.g("display.resolution", 2)), 0, RESOLUTIONS.size() - 1)]
	var i := opts.find(want)
	return i if i >= 0 else opts.size() - 1

var root_ctrl: Control
var viewport: SubViewport
var view_rect: TextureRect
var letterbox: ColorRect
var ui_layer: CanvasLayer
var overlay_layer: CanvasLayer
var screen_host: Control
var hud_host: Control
var fade: ColorRect
var post_rect: ColorRect
## Ultrawide/16:10: eigener Hintergrund für die Flächen neben dem 16:9-Spielfeld.
var backdrop_vp: SubViewport
var backdrop_rect: TextureRect
var backdrop_bg: Node2D
var backdrop_cam: Camera2D
var side_shade: Control

var game: Node2D = null
var hud: Control = null
var mode: String = ""            # "", "campaign", "training", "rush"
var run_level: int = 1
var run_checkpoint: int = 0
var campaign_snapshot: Dictionary = {}
var screens: Array = []
## Unterkante des Spielbereichs in Weltkoordinaten: darunter liegt die Leiste.
const PLAY_BOTTOM := 496.0
## Kompakte Instrumentenbänder schaffen Platz, ohne Weltkörper zu verdecken.
const PLAY_TOP := 40.0
const PLAY_LEFT := 14.0
const PLAY_RIGHT := 946.0

var paused: bool = false
## Einmalige Notiz für das Hauptmenü (z. B. nach einem beendeten Lauf).
var menu_note: String = ""
var quitting: bool = false
var display_pending_revert: Dictionary = {}
var _display_timer: float = 0.0
var _display_confirm: Node = null
var _prev_window_size: Vector2i = Vector2i.ZERO
var _gameover_pending := false
var training_boss := false
## Offene Namenseingabe für einen gerade beendeten Highscore-Lauf.
var pending_name: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tree()
	apply_display()
	get_tree().root.size_changed.connect(_on_root_resize)
	_on_root_resize()
	Input.joy_connection_changed.connect(_on_joy_changed)
	get_window().focus_exited.connect(func(): _on_focus(false))
	get_window().focus_entered.connect(func(): _on_focus(true))
	menu_main()

func _build_tree() -> void:
	root_ctrl = Control.new()
	root_ctrl.name = "Root"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	letterbox = ColorRect.new()
	letterbox.color = Color(0, 0, 0, 1)
	letterbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(letterbox)

	backdrop_vp = SubViewport.new()
	backdrop_vp.size = WORLD_SIZE * RENDER_SCALE
	backdrop_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	backdrop_vp.gui_disable_input = true
	backdrop_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	backdrop_vp.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(backdrop_vp)
	backdrop_cam = Camera2D.new()
	backdrop_cam.position = Vector2(WORLD_SIZE) * 0.5
	backdrop_cam.enabled = true
	backdrop_vp.add_child(backdrop_cam)
	backdrop_rect = TextureRect.new()
	backdrop_rect.texture = backdrop_vp.get_texture()
	backdrop_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop_rect.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_rect.modulate = Color(0.58, 0.62, 0.68)
	backdrop_rect.visible = false
	root_ctrl.add_child(backdrop_rect)

	viewport = SubViewport.new()
	viewport.size = WORLD_SIZE * RENDER_SCALE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# App läuft immer (Menüs, Eingaben); die Spielwelt darunter muss aber pausierbar
	# sein, sonst erbt sie "immer" und läuft hinter dem Pausebildschirm weiter.
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(viewport)

	view_rect = TextureRect.new()
	view_rect.texture = viewport.get_texture()
	view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	view_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(view_rect)
	side_shade = preload("res://scripts/core/side_shade.gd").new()
	side_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	side_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(side_shade)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	hud_host = Control.new()
	hud_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(hud_host)

	screen_host = Control.new()
	screen_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(screen_host)

	post_rect = ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(post_rect)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)
	overlay_layer.add_child(fade)
	_apply_post_shader()

func _apply_post_shader() -> void:
	post_rect.color = Color(0, 0, 0, 0)
	if not bool(Save.g("graphics.post", true)):
		return
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.55;
uniform float crt = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.82, 0.28, d);
	float a = (1.0 - vig) * strength * 0.55;
	if (crt > 0.5) {
		float scan = 0.06 * step(0.5, fract(FRAGCOORD.y * 0.5));
		a += scan;
	}
	COLOR = vec4(0.0, 0.02, 0.05, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", 0.5)
	mat.set_shader_parameter("crt", 1.0 if bool(Save.g("graphics.crt", false)) else 0.0)
	post_rect.material = mat

# ------------------------------------------------------------------- Anzeige
func apply_display() -> void:
	var win := get_window()
	var mon: int = int(Save.g("display.monitor", 0))
	var res_idx: int = clampi(int(Save.g("display.resolution", 2)), 0, RESOLUTIONS.size() - 1)
	var res: Vector2i = RESOLUTIONS[res_idx]
	# Nie größer als der Monitor – sonst schneidet das System das Fenster ab
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(mon).size
	if usable.x > 0 and usable.y > 0:
		res = Vector2i(mini(res.x, usable.x), mini(res.y, usable.y))
	var wm: String = String(Save.g("display.window_mode", "window"))
	var screens := DisplayServer.get_screen_count()
	if mon >= screens:
		mon = 0
		Save.set_g("display.monitor", 0)
	match wm:
		"fullscreen":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			win.current_screen = mon
		"borderless":
			win.mode = Window.MODE_FULLSCREEN
			win.current_screen = mon
		_:
			win.mode = Window.MODE_WINDOWED
			win.current_screen = mon
			win.size = res
			_recenter(mon, res)
	win.set_flag(Window.FLAG_BORDERLESS, false)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(Save.g("display.vsync", true)) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(Save.g("display.fps_cap", 0))
	Audio.apply_volumes()
	_apply_post_shader()
	_on_root_resize()

func _recenter(mon: int, res: Vector2i) -> void:
	var win := get_window()
	var screen_pos := DisplayServer.screen_get_position(mon)
	var usable := DisplayServer.screen_get_usable_rect(mon)
	var pos := screen_pos + (usable.size - res) / 2
	win.position = pos

func _on_root_resize() -> void:
	# Wichtig: Größe in Canvas-Einheiten, nicht in Gerätepixeln – der
	# Stretch-Modus skaliert das Canvas bereits auf das Fenster.
	var win_size: Vector2 = get_viewport().get_visible_rect().size
	if win_size.x <= 1.0 or win_size.y <= 1.0:
		win_size = Vector2(960, 540)
	var scale_mode := String(Save.g("display.scaling", "pixel_plus_ui"))
	var sx := float(win_size.x) / float(WORLD_SIZE.x)
	var sy := float(win_size.y) / float(WORLD_SIZE.y)
	var s := minf(sx, sy)
	if scale_mode == "integer" and s >= 1.0:
		s = floor(s)
	var w := int(round(WORLD_SIZE.x * s))
	var h := int(round(WORLD_SIZE.y * s))
	var x := int((win_size.x - w) * 0.5)
	var y := int((win_size.y - h) * 0.5)
	view_rect.position = Vector2(x, y)
	view_rect.size = Vector2(w, h)
	view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if scale_mode != "smooth" else CanvasItem.TEXTURE_FILTER_LINEAR
	if post_rect != null:
		post_rect.position = Vector2(x, y)
		post_rect.size = Vector2(w, h)
	_layout_backdrop(win_size, Rect2(x, y, w, h))
	if hud != null and hud.has_method("set_view_rect"):
		hud.set_view_rect(Rect2(x, y, w, h))

## Ränder neben dem 16:9-Feld: dieselbe Levelkulisse, gedimmt und weich abgesetzt.
## Gegner und Geschosse bleiben ausschließlich im Spielfeld (fair wie auf 16:9).
func _layout_backdrop(canvas: Vector2, field: Rect2) -> void:
	var sides := canvas.x - field.size.x > 2.0 or canvas.y - field.size.y > 2.0
	backdrop_rect.position = Vector2.ZERO
	backdrop_rect.size = canvas
	var px := Vector2i(ceili(canvas.x), ceili(canvas.y))
	if backdrop_vp.size != px:
		backdrop_vp.size = px
	var s := field.size.x / float(WORLD_SIZE.x)
	backdrop_cam.zoom = Vector2(s, s)
	# Weltmitte liegt auf der Feldmitte, auch wenn das Feld nicht exakt zentriert ist.
	backdrop_cam.position = Vector2(WORLD_SIZE) * 0.5 + (canvas * 0.5 - field.get_center()) / s
	side_shade.field = field
	side_shade.queue_redraw()
	_set_backdrop_active(sides and is_in_game())

func _set_backdrop_active(on: bool) -> void:
	backdrop_rect.visible = on
	side_shade.visible = on
	backdrop_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on:
		return
	if backdrop_bg == null or not is_instance_valid(backdrop_bg) or backdrop_bg.get_meta("level", -1) != game.level_index:
		if backdrop_bg != null and is_instance_valid(backdrop_bg):
			backdrop_bg.queue_free()
		backdrop_bg = Background.new()
		backdrop_bg.cover_extra = 1400.0
		backdrop_bg.set_meta("level", game.level_index)
		backdrop_vp.add_child(backdrop_bg)
		backdrop_bg.setup(game.level_data)

func _sync_backdrop() -> void:
	if not backdrop_rect.visible:
		return
	if not is_in_game() or backdrop_bg == null or not is_instance_valid(backdrop_bg):
		_set_backdrop_active(false)
		return
	backdrop_bg.scroll = game.background.scroll
	backdrop_bg.speed_bonus = game.background.speed_bonus
	backdrop_bg.update(0.0, Game.WORLD_SCROLL)

func view_world_rect() -> Rect2:
	return Rect2(view_rect.position, view_rect.size)

func world_to_ui(p: Vector2) -> Vector2:
	var s := view_rect.size.x / float(WORLD_SIZE.x)
	return view_rect.position + p * s

# ------------------------------------------------------------------- Screens
func _script(path: String) -> GDScript:
	return load(path)

func push_screen(path: String, args: Dictionary = {}, fade_time: float = 0.18) -> Control:
	var s: Control = _script(path).new()
	s.app = self
	if s.has_method("setup"):
		s.call("setup", args)
	screen_host.add_child(s)
	if not screens.is_empty():
		var top: Control = screens[-1]
		top.visible = false
		top.process_mode = Node.PROCESS_MODE_DISABLED
	screens.append(s)
	Bindings.block_until_release(["ui_accept", "ui_cancel", "upgrade_buy", "menu", "fire",
		"autofire", "upgrade_prev", "upgrade_next"])
	if fade_time > 0.0:
		_flash(fade_time)
	return s

func pop_screen(fade_time: float = 0.12) -> void:
	if screens.is_empty():
		return
	var s: Control = screens.pop_back()
	s.queue_free()
	if not screens.is_empty():
		var top: Control = screens[-1]
		top.visible = true
		top.process_mode = Node.PROCESS_MODE_ALWAYS
		if top.has_method("on_return"):
			top.call("on_return")
	Bindings.block_until_release(["ui_accept", "ui_cancel", "upgrade_buy", "menu", "fire",
		"autofire", "upgrade_prev", "upgrade_next"])
	if fade_time > 0.0:
		_flash(fade_time)

func replace_with(path: String, args: Dictionary = {}) -> Control:
	clear_screens()
	return push_screen(path, args)

func clear_screens() -> void:
	for s in screens:
		if is_instance_valid(s):
			s.queue_free()
	screens.clear()

func _flash(t: float) -> void:
	fade.color = Color(0, 0, 0, 0.55)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, t)

# ------------------------------------------------------------------- Pause
func is_in_game() -> bool:
	return game != null and is_instance_valid(game)

func can_pause() -> bool:
	return is_in_game() and paused == false and not _gameover_pending and not bool(game.level_over)

## Pause über Menü-/Esc-Taste, nur im laufenden Spiel ohne offenen Bildschirm.
func _tick_pause_input() -> void:
	if not can_pause():
		return
	if not screens.is_empty():
		return
	if Bindings.consume("debug_menu"):
		debug_game()
		return
	if Bindings.consume("menu") or Bindings.consume("ui_cancel"):
		pause_game()

## Debugmenü (F4): Spiel anhalten und Werkzeuge anbieten.
func debug_game() -> void:
	if paused or not is_in_game():
		return
	paused = true
	get_tree().paused = true
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	push_screen("res://scripts/screens/debug_screen.gd", {})

func debug_close() -> void:
	resume_game()

## Debug: direkt zum Boss des laufenden Levels.
func debug_to_boss() -> void:
	if not is_in_game():
		return
	var g := game
	debug_close()
	if g == null or not is_instance_valid(g):
		return
	if g.director != null and g.director.has_method("start_boss_now"):
		g.director.start_boss_now()

## Debug: laufendes Level überspringen und das nächste starten.
func debug_next_level() -> void:
	var lv := int(Save.campaign.get("level", run_level))
	if is_in_game() and game.player != null:
		Save.campaign.points = game.player.points
		Save.campaign.nectar = game.player.nectar
		Save.campaign.hp = game.player.hp
		Save.campaign.upgrades = game.player.upgrades.duplicate(true)
		Save.campaign.shop = game.player.shop_levels.duplicate(true)
		Save.campaign.weapon = game.player.weapon
		Save.save_campaign()
	debug_close()
	if lv >= 10:
		clear_screens()
		push_screen("res://scripts/screens/ending_screen.gd", {})
		return
	reset_upgrades_for_new_level()
	_begin_level_with_story(lv + 1, 0)

## Debug: volle Leben und Schild.
func debug_full_heal() -> void:
	if not is_in_game() or game.player == null:
		return
	var p: Player = game.player
	p.hp = p.max_hp
	p.shield_hits = p.shield_max
	p.hp_changed.emit(p.hp, p.max_hp)
	p.hp_changed.emit(p.hp, p.max_hp)
	Audio.sfx("pickup_heart", -4.0, 1.0)

func toggle_pause() -> void:
	if paused:
		resume_game()
	else:
		pause_game()

func pause_game(reason: String = "") -> void:
	# Nach Levelende läuft bereits die Ergebnisfolge; dort gibt es keine Partie mehr.
	if not can_pause():
		return
	paused = true
	get_tree().paused = true
	Audio.set_music_hold(true)
	Audio.sfx("ui_back", -6.0, 1.0, true)
	push_screen("res://scripts/screens/pause_screen.gd", {"reason": reason})

func resume_game() -> void:
	if not paused:
		return
	paused = false
	_clear_pause_screens()
	Bindings.block_until_release(["ui_accept", "ui_cancel", "upgrade_buy", "menu", "fire", "autofire"])
	var tw := create_tween()
	tw.tween_callback(func(): get_tree().paused = false)
	if game != null and game.has_method("start_resume_delay"):
		game.start_resume_delay(0.85)

func _clear_pause_screens() -> void:
	for s in screens:
		if is_instance_valid(s):
			s.queue_free()
	screens.clear()

func _on_focus(has_focus: bool) -> void:
	Audio.set_unfocused(not has_focus)
	if not has_focus and can_pause():
		pause_game("focus")

func _on_joy_changed(device: int, connected: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return # Prüfläufe: echte Controller am Rechner spielen keine Rolle.
	if not connected and can_pause():
		var pads := Bindings.pads()
		if pads.is_empty():
			pause_game("controller")

# ------------------------------------------------------------------- Kampagne
func menu_main() -> void:
	if mode in ["training", "rush"] and not campaign_snapshot.is_empty():
		Save.campaign = campaign_snapshot.duplicate(true)
		Save.active_campaign = _had_campaign
		campaign_snapshot = {}
	mode = ""
	_cleanup_game()
	clear_screens()
	get_tree().paused = false
	paused = false
	Audio.play_music("menu")
	push_screen("res://scripts/screens/main_menu.gd", {}, 0.0)
	if not pending_name.is_empty():
		var args := pending_name.duplicate()
		pending_name = {}
		push_screen("res://scripts/screens/name_entry_screen.gd", args, 0.0)

func _cleanup_game() -> void:
	_set_backdrop_active(false)
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if game != null and is_instance_valid(game):
		game.queue_free()
	game = null

func start_new_campaign(difficulty: String, start_talent: String) -> void:
	Save.new_campaign(difficulty, randi())
	if start_talent != "":
		Save.campaign.start_talent = start_talent
		_apply_evolution(start_talent)
	Save.campaign.max_hp = int(Data.DIFFICULTY[difficulty].hp)
	Save.campaign.hp = Save.campaign.max_hp
	Save.profile.campaigns_started = int(Save.profile.get("campaigns_started", 0)) + 1
	Save.profile.last_start_talent = start_talent
	Save.save_campaign()
	Save.save_profile()
	mode = "campaign"
	run_level = 1
	run_checkpoint = 0
	_begin_level_with_story(1, 0)

func continue_campaign() -> void:
	if not Save.active_campaign:
		return
	mode = "campaign"
	run_level = int(Save.campaign.level)
	run_checkpoint = int(Save.campaign.checkpoint)
	if not Save.campaign.get("pending", {}).is_empty():
		# Auch nach Abbruch direkt nach dem Sieg den Bonus genau einmal gutschreiben.
		var rest := int(Save.campaign.get("nectar", 0))
		if rest > 0:
			push_screen("res://scripts/screens/nectar_convert_screen.gd", {
				"nectar": rest, "on_done": func(): show_evolution_screen(true),
			})
		else:
			show_evolution_screen(true)
		return
	if bool(Save.campaign.get("completed", false)):
		menu_note = "Run abgeschlossen – starte eine neue Kampagne oder den Boss-Rush."
		menu_main()
		return
	_begin_level(run_level, run_checkpoint)

func _begin_level_with_story(level: int, checkpoint: int) -> void:
	if int(Save.g("game.tutorial", true)) or level >= 1:
		push_screen("res://scripts/screens/story_screen.gd", {
			"level": level,
			"on_done": func(): _begin_level(level, checkpoint)
		})
	else:
		_begin_level(level, checkpoint)

func _begin_level(level: int, checkpoint: int) -> void:
	clear_screens()
	_cleanup_game()
	get_tree().paused = false
	paused = false
	run_level = level
	run_checkpoint = checkpoint
	_gameover_pending = false
	if mode == "campaign":
		Save.campaign.level = level
		Save.campaign.checkpoint = checkpoint
		Save.save_campaign()
	var g: Node2D = load("res://scripts/game/game.gd").new()
	g.name = "Game"
	viewport.add_child(g)
	game = g
	hud = load("res://scripts/screens/hud.gd").new()
	hud_host.add_child(hud)
	hud.set_view_rect(view_world_rect())
	call_deferred("_on_root_resize")
	g.setup({
		"mode": mode,
		"level": level,
		"checkpoint": checkpoint,
		"app": self,
		"boss_only": training_boss and mode == "training",
	})

func on_game_ready_to_pause() -> void:
	pass

func on_checkpoint(checkpoint_index: int) -> void:
	if mode == "campaign":
		run_checkpoint = checkpoint_index
		Save.campaign.checkpoint = checkpoint_index
		if game != null and is_instance_valid(game) and game.player != null:
			var pl = game.player
			Save.campaign.hp = pl.hp
			Save.campaign.max_hp = pl.max_hp
			Save.campaign.nectar = pl.nectar
			Save.campaign.points = pl.points
			Save.campaign.upgrades = pl.upgrades.duplicate(true)
			Save.campaign.weapon = pl.weapon
			Save.campaign.speed_level = pl.speed_level
		Save.save_campaign()
	if hud != null and hud.has_method("show_banner"):
		hud.show_banner(Loc.t("cp.reached"), 1.6)

func on_player_death() -> void:
	if hud != null and hud.has_method("show_banner"):
		hud.show_banner(Loc.t("game.game_over"), 1.8)
	# Zählen, wie oft der Lauf gescheitert ist – nach drei Versuchen ist Schluss.
	var d := int(Save.campaign.get("deaths", 0)) + 1
	Save.campaign.deaths = d
	Save.save_campaign()
	if d >= Save.MAX_CONTINUES:
		_record_run_highscore(false)

## Zahl der Game Over in diesem Lauf (1 = erster Tod).
func run_deaths() -> int:
	return int(Save.campaign.get("deaths", 0))

## Game-Over-Bildschirm: Weiter (mit zurückgesetzten taktischen Upgrades) oder
## Run beenden. Nach drei Toden gibt es kein Weiter mehr.
func show_game_over() -> void:
	if not is_in_game():
		return
	_gameover_pending = true
	paused = true
	get_tree().paused = true
	Audio.sfx("ui_back", -6.0, 1.0, true)
	push_screen("res://scripts/screens/gameover_screen.gd", {
		"deaths": run_deaths(), "max_deaths": Save.MAX_CONTINUES,
	})

## Weiter am Kontrollpunkt. Die taktischen Upgrades (unterer Rand) starten neu,
## gekaufte Werkstatt-Verbesserungen und Evolutionen bleiben.
func continue_after_death() -> void:
	_gameover_pending = false
	if game != null and game.has_method("continue_after_death"):
		game.continue_after_death()
	resume_game()

## Lokale Runrangliste: verdiente Punkte, nicht das nach Einkäufen übrige Guthaben.
func _record_run_highscore(completed: bool) -> void:
	if mode not in ["campaign", "rush"] or Save.campaign.is_empty():
		return
	Save.ensure_run_score()
	var reached := 10 if completed else clampi(int(Save.campaign.get("level", run_level)), 1, 10)
	if mode == "rush" and not completed and game != null and is_instance_valid(game):
		reached = clampi(int(game.get("rush_index")) + 1, 1, 10)
	Save.record_highscore({
		"run_id": String(Save.campaign.run_id), "mode": mode,
		"difficulty": String(Save.campaign.get("difficulty", "normal")),
		"score": int(Save.campaign.run_score), "level": reached,
		"completed": completed, "seed": int(Save.campaign.get("seed", 0)),
		"pilot": "Yuri", "legacy_score_estimate": bool(Save.campaign.get("legacy_score_estimate", false)),
	})
	# Unter den besten 20: bei der Rückkehr ins Hauptmenü nach dem Namen fragen.
	var rank := Save.highscore_rank(String(Save.campaign.run_id), mode, 20)
	if rank > 0:
		pending_name = {"run_id": String(Save.campaign.run_id), "mode": mode, "rank": rank,
			"score": int(Save.campaign.run_score), "completed": completed}

## Run aufgeben: Kampagne beenden und ins Hauptmenü zurück.
func abandon_run() -> void:
	_gameover_pending = false
	_record_run_highscore(false)
	# Training/Rush benutzen nur eine Kopie; den Originalsave niemals löschen.
	if mode not in ["training", "rush"]:
		Save.end_campaign()
	menu_note = "Run beendet – die Evolutionen im Profil bleiben erhalten."
	menu_main()

func on_level_complete(stats: Dictionary) -> void:
	if mode == "training":
		push_screen("res://scripts/screens/level_result_screen.gd", {"stats": stats, "training": true})
		return
	if mode == "rush":
		_record_run_highscore(true)
		Save.record_best("rush|%s|%d" % [String(Save.campaign.get("difficulty", "normal")),
			int(Save.campaign.get("seed", 0))], stats)
		push_screen("res://scripts/screens/level_result_screen.gd", {
			"stats": stats, "training": true, "rush": true, "level": 10,
		})
		return
	# Kampagne: Belohnung sichern, dann Levelabschluss
	var lv: int = int(stats.get("level", run_level))
	Save.campaign.level = lv
	Save.campaign.completed = lv >= 10
	Save.campaign.level_stats[str(lv)] = stats
	_record_level_score(lv, stats)
	if not Save.campaign.rewarded_levels.has(lv):
		Save.campaign.pending = {
			"level": lv,
			"offers": _roll_offers(3),
			"reroll_used": false,
		}
	# Schon am echten Abschluss sichern, nicht erst nach Resultat/Neustart.
	# Angebote werden vorher gewürfelt, damit eben benutzte Waffen zulässig bleiben.
	reset_upgrades_for_new_level()
	Save.save_campaign()
	if hud != null and hud.has_method("show_banner"):
		hud.show_banner(Loc.t("game.level_complete"), 1.4)
	get_tree().create_timer(1.5).timeout.connect(func():
		if not is_inside_tree():
			return
		_cleanup_after_level()
		# Restlicher Blütenstaub wird mittig umgerechnet, danach kommt die Evolution
		var rest := int(Save.campaign.get("nectar", 0))
		if rest > 0:
			var after_convert := func() -> void:
				if is_inside_tree():
					pop_screen()
					show_evolution_screen(false)
			push_screen("res://scripts/screens/nectar_convert_screen.gd", {
				"nectar": rest,
				"on_done": after_convert,
			})
		else:
			show_evolution_screen(false)
	)

func _record_level_score(lv: int, stats: Dictionary) -> void:
	var key := "%s|%s|%d|%d|%s" % [mode, Save.campaign.difficulty, lv, int(Save.campaign.seed),
		"zug" if bool(Save.g("access.reduce_effects", false)) else "std"]
	var entry := {
		"score": int(stats.get("score", 0)),
		"rank": stats.get("rank", "C"),
		"difficulty": Save.campaign.difficulty,
		"seed": Save.campaign.seed,
		"hits": int(stats.get("hits", 0)),
	}
	Save.record_best(key, entry)

func _cleanup_after_level() -> void:
	_cleanup_game()

func _roll_offers(count: int) -> Array:
	var pool: Array = []
	var owned: Array = Save.campaign.evolutions
	var seed_val: int = int(Save.campaign.seed) + run_level * 7919 + Save.campaign.rewarded_levels.size() * 104729
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for e in Data.EVOLUTIONS:
		var id: String = e.id
		var cur: int = _evo_level(id)
		if cur >= e.max:
			continue
		# Voraussetzungen
		var ok := true
		var reqs: Array = e.get("req", [])
		for r in reqs:
			if _evo_level(String(r)) < int(e.get("req_level", 1)):
				ok = false
		if not ok:
			continue
		# Waffenabhängige Evolutionen mit nicht vorhandener Waffe sind zulässig,
		# werden aber nur angeboten, wenn die Waffe besessen wird.
		if e.get("weapon", "") != "" and _weapon_owned(String(e.get("weapon", ""))) == false:
			continue
		pool.append(id)
	# Gewichtung: Familienvielfalt bevorzugen
	var chosen: Array = []
	var families: Array = []
	var guard := 0
	# Leerer Pool (alles ausgebaut) darf nicht in einen ungültigen Index laufen.
	while chosen.size() < count and guard < 200 and not pool.is_empty():
		guard += 1
		var cand: String = pool[rng.randi_range(0, pool.size() - 1)]
		if chosen.has(cand):
			continue
		var fam: String = Data.evo(cand).get("family", "")
		if families.has(fam) and guard < 120:
			continue
		chosen.append(cand)
		families.append(fam)
	# Auffüllen, falls zu wenige Familien
	guard = 0
	while chosen.size() < count and guard < 100 and pool.size() > 0:
		guard += 1
		var cand2: String = pool[rng.randi_range(0, pool.size() - 1)]
		if not chosen.has(cand2):
			chosen.append(cand2)
	return chosen

func _evo_level(id: String) -> int:
	var lv := 0
	for e in Save.campaign.evolutions:
		if String(e.id) == id:
			lv = int(e.get("level", 1))
	return lv

func _weapon_owned(w: String) -> bool:
	if w == "companion":
		return int(Save.campaign.upgrades.get("companion", 0)) > 0
	if w == "shield":
		return int(Save.campaign.upgrades.get("shield", 0)) > 0
	return int(Save.campaign.upgrades.get(w, 0)) > 0

func _apply_evolution(id: String) -> bool:
	if id == "":
		return false
	var e := Data.evo(id)
	if e.is_empty():
		return false
	var cur := _evo_level(id)
	if cur >= int(e.max):
		return false
	var found := false
	for entry in Save.campaign.evolutions:
		if String(entry.id) == id:
			entry.level = int(entry.level) + 1
			found = true
	if not found:
		Save.campaign.evolutions.append({"id": id, "level": 1})
	return true

func show_evolution_screen(restored: bool) -> void:
	var s := push_screen("res://scripts/screens/evolution_screen.gd", {
		"restored": restored,
		"on_choose": func(id: String):
			_confirm_evolution(id)
	})

func _confirm_evolution(id: String) -> void:
	var lv: int = int(Save.campaign.get("pending", {}).get("level", run_level))
	var first_unlock := not Save.is_evolution_unlocked(id)
	Save.unlock_evolution(id)
	_apply_evolution(id)
	if not Save.campaign.rewarded_levels.has(lv):
		Save.campaign.rewarded_levels.append(lv)
	Save.campaign.pending = {}
	Save.campaign.level = lv
	Save.campaign.checkpoint = 0
	Save.campaign.completed = lv >= 10
	Save.save_campaign()
	if lv >= 10:
		# Nektarumrechnung ist hier bereits erfolgt: vollständiger, einmaliger Runsieg.
		_record_run_highscore(true)
	var was_new := first_unlock
	clear_screens()
	push_screen("res://scripts/screens/level_result_screen.gd", {
		"stats": Save.campaign.level_stats.get(str(lv), {}),
		"level": lv,
		"new_unlock": was_new,
		"chosen": id,
		"training": false,
	}, 0.25)

## Jeder Levelabschluss löscht alle taktischen Käufe; Werkstatt/Evolutionen bleiben.
## Die kostenlose Basiswaffe ist weiterhin verfügbar. Nektar erst danach umrechnen!
func reset_upgrades_for_new_level() -> void:
	if mode != "campaign":
		return
	var fresh: Dictionary = {}
	for upgrade in Data.UPGRADES:
		fresh[String(upgrade.id)] = 1 if String(upgrade.id) == "base" else 0
	Save.campaign.upgrades = fresh
	Save.campaign.weapon = "base"
	Save.campaign.speed_level = 0
	Save.save_campaign()

func advance_after_level(lv: int) -> void:
	clear_screens()
	reset_upgrades_for_new_level()
	if lv >= 10:
		push_screen("res://scripts/screens/ending_screen.gd", {})
		return
	# Werkstatt: nach jedem Level Punkte in dauerhafte Upgrades stecken
	if mode == "campaign":
		push_screen("res://scripts/screens/shop_screen.gd", {"level": lv}, 0.25)
		return
	_begin_level_with_story(lv + 1, 0)

## Aus der Werkstatt zurück ins Spiel (go_next) oder ins Hauptmenü.
func shop_done(lv: int, go_next: bool) -> void:
	clear_screens()
	if go_next and mode == "campaign":
		_begin_level_with_story(lv + 1, 0)
	else:
		menu_main()

# ------------------------------------------------------------------- Modi
var _had_campaign := false

func start_training(level: int, kind: String) -> void:
	mode = "training"
	training_boss = kind == "boss"
	run_level = level
	run_checkpoint = 0
	_had_campaign = Save.active_campaign
	campaign_snapshot = Save.campaign.duplicate(true) if Save.active_campaign else _default_build()
	# Training arbeitet auf einer Kopie; das Original bleibt unberührt.
	Save.campaign = campaign_snapshot.duplicate(true)
	Save.campaign.hp = Save.campaign.max_hp
	Save.campaign.nectar = maxi(int(Save.campaign.get("nectar", 0)), 120)
	Save.active_campaign = false
	_begin_level(level, 0)

func _default_build() -> Dictionary:
	return {
		"difficulty": String(Save.g("game.difficulty", "normal")),
		"seed": 1, "level": 1, "checkpoint": 0, "hp": 3, "max_hp": 3,
		"nectar": 60, "points": 0, "weapon": "base", "speed_level": 1,
		"upgrades": {"base": 1, "fan": 1, "lightning": 1, "plasma": 1,
					 "companion": 1, "bombs": 1, "shield": 0, "speed": 1},
		"evolutions": [], "start_talent": "", "rewarded_levels": [],
		"pending": {}, "level_stats": {}, "completed": false,
	}

func _begin_training_level() -> void:
	# Training nutzt eine Kopie des Builds; Original wird danach wiederhergestellt.
	Save.campaign = campaign_snapshot.duplicate(true)
	Save.active_campaign = false
	_begin_level(run_level, 0)

func start_boss_rush(difficulty_id: String = "") -> void:
	if difficulty_id not in Data.DIFFICULTY:
		difficulty_id = String(Save.campaign.get("difficulty", Save.g("game.difficulty", "normal")))
	if difficulty_id not in Data.DIFFICULTY:
		difficulty_id = "normal"
	mode = "rush"
	run_level = 10
	run_checkpoint = 0
	_had_campaign = Save.active_campaign
	campaign_snapshot = Save.campaign.duplicate(true) if Save.active_campaign else _default_build()
	Save.campaign = campaign_snapshot.duplicate(true)
	Save.campaign.difficulty = difficulty_id
	# Jeder Boss-Rush ist ein neuer Ranglistenrun, keine Kopie der Kampagnenidentität.
	Save.campaign.erase("run_id")
	Save.campaign.run_score = 0
	Save.campaign.legacy_score_estimate = false
	Save.ensure_run_score()
	Save.active_campaign = false
	Save.campaign.hp = Save.campaign.max_hp
	Save.campaign.max_hp = maxi(4, int(Save.campaign.get("max_hp", 3)))
	Save.campaign.hp = Save.campaign.max_hp
	_begin_level(10, 0)

func quit_to_desktop() -> void:
	Save.save_all()
	quitting = true
	get_tree().quit()

# ------------------------------------------------------- Anzeige-Testfenster
func begin_display_test(previous: Dictionary) -> void:
	display_pending_revert = previous
	_display_timer = 15.0
	if _display_confirm != null and is_instance_valid(_display_confirm):
		_display_confirm.queue_free()
	_display_confirm = push_screen("res://scripts/screens/display_confirm.gd", {"seconds": 15})

func confirm_display() -> void:
	display_pending_revert = {}
	_display_timer = 0.0
	if _display_confirm != null and is_instance_valid(_display_confirm):
		screens.erase(_display_confirm)
		_display_confirm.queue_free()
		_display_confirm = null
	if not screens.is_empty():
		screens[-1].visible = true
		screens[-1].process_mode = Node.PROCESS_MODE_ALWAYS

func revert_display_now() -> void:
	if display_pending_revert.is_empty():
		confirm_display()
		return
	var prev := display_pending_revert
	display_pending_revert = {}
	_display_timer = 0.0
	for k in prev:
		Save.set_g(String(k), prev[k])
	Save.save_settings()
	apply_display()
	if _display_confirm != null and is_instance_valid(_display_confirm):
		screens.erase(_display_confirm)
		_display_confirm.queue_free()
		_display_confirm = null
	if not screens.is_empty():
		screens[-1].visible = true
		screens[-1].process_mode = Node.PROCESS_MODE_ALWAYS
	Bindings.block_until_release(["ui_accept", "ui_cancel"])
	Audio.sfx("ui_back", -6.0, 1.0, true)

func _process(delta: float) -> void:
	_tick_pause_input()
	_sync_backdrop()
	if _display_timer > 0.0 and not display_pending_revert.is_empty():
		_display_timer -= delta
		if _display_timer <= 0.0:
			var prev := display_pending_revert
			display_pending_revert = {}
			for k in prev:
				Save.set_g(String(k), prev[k])
			apply_display()
			confirm_display()
			Audio.sfx("ui_back", -4.0, 1.0, true)
