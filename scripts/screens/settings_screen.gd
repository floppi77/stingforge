extends "res://scripts/core/ui_screen.gd"

const TABS := ["display", "graphics", "audio", "controls", "game", "access"]

var from := "main"
var tab := 0
var capture_action := ""
var capture_timer := 0.0
var _pending_rows: Array = []
var _scroll_saved: int = 0
## Anzeige-Änderungen werden erst gesammelt und dann mit A übernommen.
## Vorher sprang bei jedem Tastendruck das Fenster um und ein Dialog auf.
var staged: Dictionary = {}

func setup(args: Dictionary) -> void:
	list_width = 520
	backdrop_mood = "cool"
	from = String(args.get("from", "main"))
	title_key = "set.title"
	subtitle_key = ""

func _ready() -> void:
	set_process_input(true)
	super._ready()

func build_items() -> void:
	var list: Array = []
	# Belegungsreiter braucht Platz für Tastatur- und Xbox-Spalte.
	list_width = 700 if tab == 3 else 520
	if is_inside_tree():
		_fit_list_width.call_deferred()
	header_note = ""
	prompt_context = "settings"
	_build_tabs()
	match TABS[tab]:
		"display": _build_display(list)
		"graphics": _build_graphics(list)
		"audio": _build_audio(list)
		"controls": _build_controls(list)
		"game": _build_game(list)
		"access": _build_access(list)
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "set.reset", "id": "reset_section"})
	list.append({"kind": "action", "text": "menu.back", "id": "back"})
	# Einstellungen haben viele Zeilen – kompakt, damit nichts abgeschnitten wird
	for it in list:
		var d: Dictionary = it
		if String(d.get("kind", "")) != "sep":
			d["compact"] = true
	items = list
	hint_override = "Links/rechts ändert Werte · Bestätigen übernimmt die vorgemerkte Anzeige." if tab == 0 else ""
	footer_text = "D = Steuerkreuz · LS = linker Stick · Bestätigen startet die Neubelegung." if tab == 3 else ""

func _tab_strip() -> String:
	return Loc.t("set.tab." + TABS[tab])

## Optische Reiter nutzen dieselbe bestehende Navigation; keine neue Belegung.
func _build_tabs() -> void:
	if tab_bar == null: return
	for c in tab_bar.get_children():
		tab_bar.remove_child(c)
		c.queue_free()
	tab_bar.visible = true
	for i in range(TABS.size()):
		var button := Button.new()
		button.text = Loc.t("set.tab." + TABS[i])
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", UiTheme.font_semi())
		button.add_theme_font_size_override("font_size", UiTheme.size(12))
		button.add_theme_color_override("font_color", UiTheme.ACCENT if i == tab else UiTheme.DIM)
		var style := UiTheme.row_style(i == tab)
		style.content_margin_left = UiTheme.pad(13)
		style.content_margin_right = UiTheme.pad(13)
		style.content_margin_top = UiTheme.pad(6)
		style.content_margin_bottom = UiTheme.pad(6)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", UiTheme.row_style(true))
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(func():
			tab = i
			focus = 0
			rebuild()
			refresh())
		tab_bar.add_child(button)

## Wert, der gerade gilt: gestuft (noch nicht übernommen) oder gespeichert.
func _val(path: String, default: Variant) -> Variant:
	if staged.has(path):
		return staged[path]
	return Save.g(path, default)

## Index in der Liste der möglichen Auflösungen (nicht in App.RESOLUTIONS).
## Gespeichert wird immer der Index in App.RESOLUTIONS.
func _res_index() -> int:
	var opts: Array = App.resolution_options()
	var idx := clampi(int(_val("display.resolution", 2)), 0, App.RESOLUTIONS.size() - 1)
	var i := opts.find(App.RESOLUTIONS[idx])
	# gespeicherte Größe gibt es auf diesem Monitor nicht: größte passende nehmen
	return i if i >= 0 else opts.size() - 1

## Gestufte Anzeige-Werte wirklich anwenden – mit 15-Sekunden-Rückfrage.
func apply_staged_display() -> void:
	if staged.is_empty():
		return
	var prev := {}
	for k in staged.keys():
		prev[k] = Save.g(String(k), null)
		Save.set_g(String(k), staged[k])
	staged.clear()
	Save.save_settings()
	App.apply_display()
	App.begin_display_test(prev)
	_rebuild_keep_focus()

func _bool_text(v: bool) -> String:
	return Loc.t("set.value_on") if v else Loc.t("set.value_off")

func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

func _build_display(list: Array) -> void:
	var monitors: int = maxi(1, DisplayServer.get_screen_count())
	var mon_names: Array = []
	for i in range(monitors):
		mon_names.append("Monitor %d" % (i + 1))
	var mon_cur := mini(int(_val("display.monitor", 0)), monitors - 1)
	list.append({"kind": "choice", "text": "set.monitor", "id": "monitor",
		"value_text": mon_names[mon_cur] + ("  •" if staged.has("display.monitor") else ""),
		"accent": staged.has("display.monitor"),
		"value_color": UiTheme.ACCENT if staged.has("display.monitor") else UiTheme.TEXT})
	var labels: Array = App.resolution_labels()
	var res_i: int = _res_index()
	list.append({"kind": "choice", "text": "set.resolution", "id": "resolution",
		"value_text": String(labels[clampi(res_i, 0, labels.size() - 1)]) +
			("  •" if staged.has("display.resolution") else ""),
		"accent": staged.has("display.resolution"),
		"value_color": UiTheme.ACCENT if staged.has("display.resolution") else UiTheme.TEXT,
		"hint": "" if _val("display.window_mode", "window") == "window" else "set.res_window_only"})
	var wm := String(_val("display.window_mode", "window"))
	list.append({"kind": "choice", "text": "set.window_mode", "id": "window_mode",
		"value_text": String({"window": "Fenster", "borderless": "Randlos",
			"fullscreen": "Vollbild"}.get(wm, wm)) +
			("  •" if staged.has("display.window_mode") else ""),
		"accent": staged.has("display.window_mode"),
		"value_color": UiTheme.ACCENT if staged.has("display.window_mode") else UiTheme.TEXT})
	# Übernehmen steht direkt unter den Werten, die es betrifft
	if not staged.is_empty():
		list.append({"kind": "action", "text": "set.apply_display", "id": "apply_display",
			"accent": true, "value_text": Loc.t("set.apply_display_hint")})
	list.append({"kind": "toggle", "text": "set.vsync", "id": "vsync",
		"value_text": _bool_text(bool(Save.g("display.vsync", true)))})
	var caps := [0, 30, 60, 120, 144, 240]
	var cap := int(Save.g("display.fps_cap", 0))
	list.append({"kind": "choice", "text": "set.fps_cap", "id": "fps_cap",
		"value_text": ("Aus" if cap == 0 else str(cap))})
	var sc := String(Save.g("display.scaling", "pixel_plus_ui"))
	list.append({"kind": "choice", "text": "set.scaling", "id": "scaling",
		"value_text": Loc.t(String({"integer": "set.integer_scaling", "smooth": "set.smooth_scaling",
			"pixel_plus_ui": "set.pixel_plus_ui"}.get(sc, sc)))})
	list.append({"kind": "slider", "text": "set.ui_size", "id": "ui_size",
		"value_text": "%d%%" % int(Save.g("display.ui_size", 100))})
	# „Anzeige testen“ entfällt: das Übernehmen zeigt die Rückfrage bereits.

func _build_graphics(list: Array) -> void:
	list.append({"kind": "slider", "text": "set.effects", "id": "effects",
		"value_text": _pct(float(Save.g("graphics.effects", 1.0)))})
	list.append({"kind": "slider", "text": "set.particles", "id": "particles",
		"value_text": _pct(float(Save.g("graphics.particles", 1.0)))})
	list.append({"kind": "slider", "text": "set.shake", "id": "shake",
		"value_text": _pct(float(Save.g("graphics.shake", 0.6)))})
	list.append({"kind": "toggle", "text": "set.flashes", "id": "flashes",
		"value_text": _bool_text(bool(Save.g("graphics.flashes", true)))})
	list.append({"kind": "toggle", "text": "set.post", "id": "post",
		"value_text": _bool_text(bool(Save.g("graphics.post", true)))})
	list.append({"kind": "toggle", "text": "set.lighting", "id": "lighting",
		"value_text": _bool_text(bool(Save.g("graphics.lighting", true)))})
	list.append({"kind": "toggle", "text": "set.crt", "id": "crt",
		"value_text": _bool_text(bool(Save.g("graphics.crt", false)))})

func _build_audio(list: Array) -> void:
	for pair in [["master", "set.master"], ["music", "set.music"], ["sfx", "set.sfx"], ["ui", "set.ui_sound"]]:
		list.append({"kind": "slider", "text": String(pair[1]), "id": String(pair[0]),
			"value_text": _pct(float(Save.g("audio." + String(pair[0]), 0.8)))})
	list.append({"kind": "toggle", "text": "set.mute_unfocused", "id": "mute_unfocused",
		"value_text": _bool_text(bool(Save.g("audio.mute_unfocused", true)))})
	list.append({"kind": "toggle", "text": "set.voice_upgrades", "id": "voice_upgrades",
		"value_text": _bool_text(bool(Save.g("audio.voice_upgrades", true)))})

func _build_controls(list: Array) -> void:
	list.append({"kind": "label", "text": "", "binding_header": true})
	for a in Bindings.ACTIONS:
		list.append({
			"kind": "action", "text": "act." + a, "id": "bind:" + a,
			"value_text": Bindings.describe_action(a), "binding_action": a,
		})
	list.append({"kind": "sep"})
	list.append({"kind": "slider", "text": "set.deadzone", "id": "deadzone",
		"value_text": _pct(float(Save.g("controls.deadzone", 0.22)))})
	list.append({"kind": "slider", "text": "set.sensitivity", "id": "sensitivity",
		"value_text": _pct(float(Save.g("controls.sensitivity", 1.0)))})
	var has_pad := not Input.get_connected_joypads().is_empty()
	list.append({"kind": "toggle", "text": "set.vibration", "id": "vibration",
		"value_text": _bool_text(bool(Save.g("controls.vibration", true))) if has_pad else Loc.t("set.unsupported")})
	list.append({"kind": "slider", "text": "set.vibration_strength", "id": "vibration_strength",
		"value_text": _pct(float(Save.g("controls.vibration_strength", 0.6)))})
	list.append({"kind": "action", "text": "set.reset", "id": "reset_bindings"})

func _build_game(list: Array) -> void:
	list.append({"kind": "toggle", "text": "set.autofire_default", "id": "autofire_default",
		"value_text": _bool_text(bool(Save.g("game.autofire_default", false)))})
	list.append({"kind": "toggle", "text": "set.tutorial", "id": "tutorial",
		"value_text": _bool_text(bool(Save.g("game.tutorial", true)))})
	list.append({"kind": "toggle", "text": "set.hitbox", "id": "hitbox",
		"value_text": _bool_text(bool(Save.g("game.hitbox", false)))})
	list.append({"kind": "label", "text": "Die Schwierigkeit wählst du beim Run-Start. Während des Runs bleibt sie fest.",
		"size": 14, "color": UiTheme.DIM})

func _build_access(list: Array) -> void:
	list.append({"kind": "slider", "text": "set.font_scale", "id": "font_scale",
		"value_text": _pct(float(Save.g("access.font_scale", 1.0)))})
	list.append({"kind": "toggle", "text": "set.reduce_effects", "id": "reduce_effects",
		"value_text": _bool_text(bool(Save.g("access.reduce_effects", false)))})
	list.append({"kind": "toggle", "text": "set.contrast_hazards", "id": "contrast_hazards",
		"value_text": _bool_text(bool(Save.g("access.contrast_hazards", true)))})

func on_adjust(index: int, dir: int) -> void:
	var it: Dictionary = items[index]
	var id := String(it.get("id", ""))
	var kind := String(it.get("kind", ""))
	if kind not in ["choice", "slider", "toggle"]:
		return
	match kind:
		"choice":
			_adjust_choice(id, dir)
		"slider":
			_adjust_slider(id, dir)
		"toggle":
			_toggle(id)
	_rebuild_keep_focus()

func _adjust_choice(id: String, dir: int) -> void:
	match id:
		"monitor":
			var count: int = maxi(1, DisplayServer.get_screen_count())
			var cur := int(_val("display.monitor", 0))
			var new_mon := (cur + dir + count) % count
			staged["display.monitor"] = new_mon
			# Anderer Monitor: Auflösungsliste kann kürzer sein
			var opts: Array = App.resolution_options(new_mon)
			var keep := clampi(_res_index(), 0, opts.size() - 1)
			staged["display.resolution"] = App.RESOLUTIONS.find(opts[keep])
		"resolution":
			var opts2: Array = App.resolution_options()
			var cur2: int = clampi(_res_index() + dir, 0, opts2.size() - 1)
			staged["display.resolution"] = App.RESOLUTIONS.find(opts2[cur2])
		"window_mode":
			var modes := ["window", "borderless", "fullscreen"]
			var cur3 := modes.find(String(_val("display.window_mode", "window")))
			if cur3 < 0:
				cur3 = 0
			staged["display.window_mode"] = modes[(cur3 + dir + modes.size()) % modes.size()]
		"fps_cap":
			var caps := [0, 30, 60, 120, 144, 240]
			var idx := caps.find(int(Save.g("display.fps_cap", 0)))
			if idx < 0:
				idx = 0
			Save.set_g("display.fps_cap", caps[(idx + dir + caps.size()) % caps.size()])
			App.apply_display()
		"scaling":
			var scs := ["pixel_plus_ui", "integer", "smooth"]
			var idx2 := scs.find(String(Save.g("display.scaling", "pixel_plus_ui")))
			if idx2 < 0:
				idx2 = 0
			Save.set_g("display.scaling", scs[(idx2 + dir + scs.size()) % scs.size()])
			App.apply_display()
	Audio.sfx("ui_move", -12.0, 1.05, true)

func _adjust_slider(id: String, dir: int) -> void:
	var step := 0.1
	match id:
		"effects", "particles", "shake", "deadzone", "sensitivity", "vibration_strength", "font_scale":
			pass
		"ui_size":
			Save.set_g("display.ui_size", clampi(int(Save.g("display.ui_size", 100)) + dir * 10, 70, 160))
			Audio.sfx("ui_move", -12.0, 1.05, true)
			return
		_:
			step = 0.05
	var path := ""
	match id:
		"effects": path = "graphics.effects"
		"particles": path = "graphics.particles"
		"shake": path = "graphics.shake"
		"master": path = "audio.master"
		"music": path = "audio.music"
		"sfx": path = "audio.sfx"
		"ui": path = "audio.ui"
		"deadzone": path = "controls.deadzone"
		"sensitivity": path = "controls.sensitivity"
		"vibration_strength": path = "controls.vibration_strength"
		"font_scale": path = "access.font_scale"
	if path == "":
		return
	var cur := float(Save.g(path, 0.5))
	var lo := 0.0
	var hi := 1.0
	if id == "deadzone":
		lo = 0.0
		hi = 0.6
	elif id == "sensitivity":
		lo = 0.4
		hi = 1.6
	elif id == "font_scale":
		lo = 0.8
		hi = 1.6
	elif id in ["master", "music", "sfx", "ui"]:
		lo = 0.0
		hi = 1.0
	Save.set_g(path, clampf(snappedf(cur + dir * step, 0.05), lo, hi))
	if path.begins_with("audio."):
		Audio.apply_volumes()
	Audio.sfx("ui_move", -12.0, 1.15, true)

func _toggle(id: String) -> void:
	var paths := {
		"vsync": "display.vsync", "flashes": "graphics.flashes", "post": "graphics.post",
		"lighting": "graphics.lighting",
		"crt": "graphics.crt", "mute_unfocused": "audio.mute_unfocused",
		"voice_upgrades": "audio.voice_upgrades",
		"vibration": "controls.vibration", "autofire_default": "game.autofire_default",
		"tutorial": "game.tutorial", "hitbox": "game.hitbox",
		"reduce_effects": "access.reduce_effects", "contrast_hazards": "access.contrast_hazards",
	}
	if not paths.has(id):
		return
	var path := String(paths[id])
	Save.set_g(path, not bool(Save.g(path, true)))
	if id == "vsync":
		App.apply_display()
	if id == "post" or id == "crt":
		App.apply_display()
	Audio.sfx("ui_ok", -10.0, 1.0, true)


func _rebuild_keep_focus() -> void:
	var f := focus
	var scroll := scroll_container.scroll_vertical if scroll_container != null else 0
	rebuild()
	refresh()
	focus = clampi(f, 0, maxi(0, items.size() - 1))
	_clamp_focus()
	_update_focus_visuals()
	if scroll_container != null:
		scroll_container.scroll_vertical = scroll

## A/Leertaste auf einer Anzeigezeile übernimmt die vorgemerkten Werte,
## statt den Wert weiterzuschalten (das machen links/rechts).
func _activate() -> void:
	if not items.is_empty():
		var it: Dictionary = items[focus]
		if String(it.get("kind", "")) == "choice" \
				and String(it.get("id", "")) in ["monitor", "resolution", "window_mode"]:
			apply_staged_display()
			return
	super._activate()

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	var id := String(it.get("id", ""))
	if id == "back":
		if not staged.is_empty():
			apply_staged_display()
		app.pop_screen()
		return
	if id == "apply_display":
		apply_staged_display()
		return
	if id in ["monitor", "resolution", "window_mode"]:
		# A/Leertaste übernimmt die gestuften Anzeigewerte
		apply_staged_display()
		return
	if id == "reset_section":
		app.push_screen("res://scripts/screens/confirm_screen.gd", {
			"title": "set.reset",
			"message": "set.reset",
			"on_yes": func():
				Save.reset_settings_section(TABS[tab])
				staged.clear()
				App.apply_display()
				Bindings.load_bindings()
				_rebuild_keep_focus(),
		})
		return
	if id == "reset_bindings":
		Bindings.reset_all()
		Audio.sfx("ui_ok", -8.0, 1.0, true)
		_rebuild_keep_focus()
		return
	if id == "test_display":
		App.begin_display_test({})
		return
	if id.begins_with("bind:"):
		capture_action = id.substr(5)
		capture_timer = 8.0
		hint_label.text = Loc.t("set.rebind_wait")
		hint_label.visible = true
		Audio.sfx("ui_ok", -10.0, 1.0, true)
		return

func _input(event: InputEvent) -> void:
	if capture_action == "":
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			capture_action = ""
			hint_label.text = ""
			Bindings.block_until_release(["ui_accept", "ui_cancel", "upgrade_buy", "menu"])
			return
		_try_bind({"t": "key", "c": int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)})
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_try_bind({"t": "jb", "c": int((event as InputEventJoypadButton).button_index)})
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > 0.6:
			var d := 1 if m.axis_value > 0 else -1
			var th := 0.6 if m.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else 0.5
			_try_bind({"t": "ja", "a": int(m.axis), "d": d, "th": th})
			get_viewport().set_input_as_handled()

func _try_bind(b: Dictionary) -> void:
	var action := capture_action
	var conflict := Bindings.find_conflict(action, b)
	if conflict != "":
		capture_action = ""
		app.push_screen("res://scripts/screens/confirm_screen.gd", {
			"title": "set.rebind",
			"message": "set.rebind_conflict" % Loc.t("act." + conflict),
			"on_yes": func():
				Bindings.apply_binding(action, b, true)
				Bindings.save_bindings()
				_rebuild_keep_focus(),
		})
		return
	Bindings.apply_binding(action, b, true)
	Bindings.save_bindings()
	capture_action = ""
	hint_label.text = ""
	Audio.sfx("ui_ok", -8.0, 1.1, true)
	_rebuild_keep_focus()

func _process(delta: float) -> void:
	if capture_action != "":
		capture_timer -= delta
		if capture_timer <= 0.0:
			capture_action = ""
			hint_label.text = ""
		if Bindings.consume("ui_prev"):
			pass
		return
	if Bindings.consume("upgrade_prev"):
		tab = (tab - 1 + TABS.size()) % TABS.size()
		focus = 0
		Audio.sfx("ui_move", -10.0, 1.0, true)
		rebuild()
		refresh()
		return
	if Bindings.consume("upgrade_next"):
		tab = (tab + 1) % TABS.size()
		focus = 0
		Audio.sfx("ui_move", -10.0, 1.2, true)
		rebuild()
		refresh()
		return
	super._process(delta)

func do_back() -> void:
	audio_apply()
	app.pop_screen()

func audio_apply() -> void:
	Audio.apply_volumes()

func on_return() -> void:
	rebuild()
	refresh()
