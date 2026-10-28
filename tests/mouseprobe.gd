extends Node
## Prüft die Mausbedienung der Menüs im laufenden Fenster.

var fails: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.4, false).timeout
	Save.new_campaign("normal", 909090)
	app.clear_screens()
	var st = app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main", "tab": 0})
	await get_tree().create_timer(0.5, false).timeout
	if st == null or not is_instance_valid(st):
		_fail("Einstellungen öffnen")
		_finish()
		return
	await _test_settings(app, st)
	await _test_main_menu(app)
	_finish()

func _test_settings(app, st) -> void:
	var idx := -1
	for i in range(st.items.size()):
		if String(st.items[i].get("kind", "")) == "toggle":
			idx = i
			break
	if idx < 0:
		_fail("Schalter in den Einstellungen finden")
		return
	var row: Control = st._rows[idx]
	var rect := row.get_global_rect()
	var center := rect.position + rect.size * 0.5
	print("MAUS Zielzeile %d, Rect %s" % [idx, str(rect)])

	# 1) Zeiger bewegen hebt die Zeile hervor
	st.focus = 0
	_move(center)
	await get_tree().create_timer(0.25, false).timeout
	print("MAUS Fokus nach Hover: %d (erwartet %d)" % [st.focus, idx])
	if st.focus != idx:
		_fail("Hover setzt den Fokus nicht")

	# 2) Linksklick schaltet den Schalter
	var before: String = String(st.items[idx].get("value_text", ""))
	_click(center)
	await get_tree().create_timer(0.35, false).timeout
	var after: String = String(st.items[idx].get("value_text", ""))
	print("MAUS Schalter '%s': %s -> %s" % [String(st.items[idx].get("id", "")), before, after])
	if before == after:
		_fail("Klick auf den Schalter ändert nichts")

	# 3) Mausrad bewegt den Fokus
	st.focus = 0
	_wheel(center, MOUSE_BUTTON_WHEEL_DOWN)
	await get_tree().create_timer(0.25, false).timeout
	print("MAUS Fokus nach Rad: %d" % st.focus)
	if st.focus == 0:
		_fail("Mausrad bewegt den Fokus nicht")

	# 4) Klick auf die Zurück-Zeile verlässt den Bildschirm
	var back_idx := -1
	for i in range(st.items.size()):
		if String(st.items[i].get("id", "")) == "back":
			back_idx = i
			break
	if back_idx < 0:
		_fail("Zurück-Zeile finden")
		return
	st.scroll_container.scroll_vertical = 9999
	await get_tree().create_timer(0.3, false).timeout
	var br: Control = st._rows[back_idx]
	var brect := br.get_global_rect()
	var bc := brect.position + brect.size * 0.5
	st.focus = back_idx
	_click(bc)
	await get_tree().create_timer(1.2, false).timeout
	var still: bool = is_instance_valid(st) and st.is_visible_in_tree()
	print("MAUS Zurück-Klick bei %s: Einstellungen offen = %s" % [str(bc), str(still)])
	if still:
		_fail("Klick auf Zurück schließt nicht")

func _test_main_menu(app) -> void:
	app.clear_screens()
	var mm = app.push_screen("res://scripts/screens/main_menu.gd", {})
	await get_tree().create_timer(0.5, false).timeout
	if mm == null or not is_instance_valid(mm):
		_fail("Hauptmenü öffnen")
		return
	var target := 0
	for i in range(mm.items.size()):
		if String(mm.items[i].get("id", "")) == "settings":
			target = i
			break
	var mr: Control = mm._rows[target]
	var mrect := mr.get_global_rect()
	var mc := mrect.position + mrect.size * 0.5
	mm.focus = 0
	var before_screens: int = app.screens.size()
	_click(mc)
	await get_tree().create_timer(0.9, false).timeout
	var now_top = app.screens[app.screens.size() - 1] if app.screens.size() > 0 else null
	var changed: bool = app.screens.size() != before_screens or (now_top != null and now_top != mm)
	print("MAUS Hauptmenü-Klick auf Zeile %d (%s): gewechselt = %s (%d -> %d)" % [
		target, str(mc), str(changed), before_screens, app.screens.size()])
	if not changed:
		_fail("Klick im Hauptmenü bewirkt nichts")

func _fail(what: String) -> void:
	print("  FAIL " + what)
	fails.append(what)

func _finish() -> void:
	print("MAUS: fails=%d" % fails.size())
	print("MAUS_OK" if fails.is_empty() else "MAUS_FAIL")
	get_tree().quit(0 if fails.is_empty() else 1)

## Rechnet Kanvas-Koordinaten (960x540) in Fensterpixel um.
func _to_window(pos: Vector2) -> Vector2:
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if vis.x < 1.0 or vis.y < 1.0:
		return pos
	return pos * (win / vis)

func _motion(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)

## pos in Kanvas-Koordinaten
func _move(pos: Vector2) -> void:
	_motion(_to_window(pos))

func _button(p: Vector2, button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.global_position = p
	ev.button_index = button
	ev.pressed = pressed
	if pressed and button == MOUSE_BUTTON_LEFT:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)

func _click(pos: Vector2) -> void:
	var p := _to_window(pos)
	_motion(p)
	_button(p, MOUSE_BUTTON_LEFT, true)
	_button(p, MOUSE_BUTTON_LEFT, false)

func _wheel(pos: Vector2, button: int) -> void:
	var p := _to_window(pos)
	_motion(p)
	_button(p, button, true)
	_button(p, button, false)
