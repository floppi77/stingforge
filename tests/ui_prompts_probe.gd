extends Node
## Isolierte Anzeigeprüfung. Nur Bindings-RAM wird vorübergehend ersetzt;
## kein apply_binding(), kein Save.set_g(), keine InputMap-Änderung.
## Aufruf: godot --headless --path . tests/ui_prompts_probe.tscn

const UiPrompts := preload("res://scripts/core/ui_prompts.gd")
const U := preload("res://scripts/core/ui_theme.gd")

var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	# App startet beim Autoload Menü-Musik. Im Anzeige-Test direkt anhalten,
	# damit der Dummy-Audiotreiber beim schnellen Beenden sauber freigibt.
	for child in Audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	var original_bindings: Dictionary = Bindings.bindings
	var original_device: String = Bindings.last_device
	var original_scale: float = U._scale_override
	var settings_before: Dictionary = Save.settings.duplicate(true)
	var profile_before: Dictionary = Save.profile.duplicate(true)
	var campaign_before: Dictionary = Save.campaign.duplicate(true)
	var disk_before := _save_disk_state()
	var input_before := _input_map_state()
	Bindings.bindings = {}
	U.set_scale_override(1.0)
	_test_defaults()
	_test_devices()
	_test_custom_and_unbound()
	_test_german_keys()
	_test_pad_names()
	Bindings.bindings = {}
	await _test_controls()
	_check(Save.settings == settings_before, "Save.settings unverändert")
	_check(Save.profile == profile_before, "Save.profile unverändert")
	_check(Save.campaign == campaign_before, "Save.campaign unverändert")
	_check(_save_disk_state() == disk_before, "Save-Dateien bytegleich/unverändert")
	_check(_input_map_state() == input_before, "InputMap unverändert")
	Bindings.bindings = original_bindings
	Bindings.last_device = original_device
	U.set_scale_override(original_scale)
	_check(Bindings.bindings == original_bindings, "Bindings-RAM wiederhergestellt")
	_check(Bindings.last_device == original_device, "Gerätestatus wiederhergestellt")
	print("UI_PROMPTS: checks=%d fails=%d" % [checks, failures.size()])
	for message in failures:
		print("  FAIL " + message)
	if failures.is_empty():
		print("UI_PROMPTS_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_defaults() -> void:
	var expected := {
		"fire": "A", "ui_cancel": "B", "autofire": "X",
		"upgrade_prev": "LB", "upgrade_next": "RB",
		"precision": "LT", "upgrade_buy": "RT",
		"menu": "Menü", "debug_menu": "Ansicht",
	}
	for action in expected:
		_check(UiPrompts.action_text(action, "gamepad") == expected[action], "Standard %s = %s" % [action, expected[action]])
	for pair in [["fire", "A"], ["ui_cancel", "B"], ["autofire", "X"]]:
		var result: Array[Dictionary] = UiPrompts.tokens(pair[0], "gamepad")
		_check(result.size() == 1 and result[0].get("color") is Color, "Xbox-Farbe %s vorhanden" % pair[1])
	var a: Color = UiPrompts.tokens("fire", "gamepad")[0]["color"]
	var b: Color = UiPrompts.tokens("ui_cancel", "gamepad")[0]["color"]
	var x: Color = UiPrompts.tokens("autofire", "gamepad")[0]["color"]
	_check(a.g > a.r and a.g > a.b, "A grün")
	_check(b.r > b.g and b.r > b.b, "B rot")
	_check(x.b > x.r and x.b > x.g, "X blau")
	_check(UiPrompts.action_text("fire", "keyboard") == "Leertaste", "Leertaste vollständig deutsch")
	_check(UiPrompts.action_text("ui_accept", "keyboard") == "Leertaste / Eingabe", "Alle Standard-Tastaturalternativen")
	_check(UiPrompts.action_text("fire") == "Leertaste / A", "both: Tastatur und Pad")

func _test_devices() -> void:
	var expected: Array[Dictionary] = UiPrompts.tokens("ui_accept", "both")
	for active_device in ["keyboard", "joypad"]:
		Bindings.last_device = active_device
		_check(UiPrompts.tokens("ui_accept", "both") == expected, "both unabhängig von Bindings.device(): " + active_device)
		_check(UiPrompts.action_text("fire", "keyboard") == "Leertaste", "keyboard unabhängig: " + active_device)
		_check(UiPrompts.action_text("fire", "gamepad") == "A", "gamepad unabhängig: " + active_device)
		for token in UiPrompts.tokens("ui_accept", "keyboard"):
			_check(token["kind"] == "key", "Tastaturspalte enthält nur Keys")
		for token in UiPrompts.tokens("ui_accept", "gamepad"):
			_check(token["kind"] == "pad", "Padspalte enthält nur Pad")

func _test_custom_and_unbound() -> void:
	Bindings.bindings["fire"] = [{"t": "key", "c": KEY_K}]
	_check(UiPrompts.action_text("fire", "keyboard") == "K", "Benutzerdefinierte Taste K")
	_check(UiPrompts.tokens("fire", "gamepad") == [{"text": "—", "kind": "pad"}], "Kein erfundenes A bei Tastatur-only")
	_check(UiPrompts.action_text("fire") == "K / —", "Fehlende Padklasse sichtbar")
	Bindings.bindings["fire"] = [{"t": "jb", "c": JOY_BUTTON_Y}]
	_check(UiPrompts.tokens("fire", "keyboard") == [{"text": "—", "kind": "key"}], "Keine erfundene Leertaste bei Pad-only")
	_check(UiPrompts.action_text("fire", "gamepad") == "Y", "Benutzerdefiniertes Y")
	var y: Color = UiPrompts.tokens("fire", "gamepad")[0]["color"]
	_check(y.r > y.b and y.g > y.b, "Y gelb")
	_check(UiPrompts.tokens("nicht_belegt") == [{"text": "—", "kind": "key"}, {"text": "—", "kind": "pad"}], "Unbekannte Aktion: beide Klassen ungebunden")
	Bindings.bindings["fire"] = [{"t": "key", "c": KEY_F7}, {"t": "jb", "c": JOY_BUTTON_RIGHT_SHOULDER}]
	_check(UiPrompts.action_text("fire") == "F7 / RB", "Keine Defaults zusätzlich zu Benutzerbelegung")
	var copy: Array[Dictionary] = UiPrompts.tokens("fire")
	copy[0]["text"] = "Manipuliert"
	_check(UiPrompts.action_text("fire") == "F7 / RB", "Ergebnistokens sind unabhängige Anzeige-Dictionaries")
	Bindings.bindings = {}

func _test_german_keys() -> void:
	var expected := {
		KEY_SPACE: "Leertaste", KEY_ENTER: "Eingabe", KEY_SHIFT: "Umschalt",
		KEY_ESCAPE: "Esc", KEY_UP: "Pfeil ↑", KEY_DOWN: "Pfeil ↓",
		KEY_LEFT: "Pfeil ←", KEY_RIGHT: "Pfeil →", KEY_CTRL: "Strg",
		KEY_BACKSPACE: "Rücktaste", KEY_DELETE: "Entf",
	}
	for code in expected:
		Bindings.bindings["fire"] = [{"t": "key", "c": code}]
		_check(UiPrompts.action_text("fire", "keyboard") == expected[code], "Deutscher Tastenname: " + expected[code])
	Bindings.bindings = {}

func _test_pad_names() -> void:
	for pair in [[JOY_BUTTON_DPAD_UP, "Steuerkreuz ↑"], [JOY_BUTTON_DPAD_DOWN, "Steuerkreuz ↓"], [JOY_BUTTON_DPAD_LEFT, "Steuerkreuz ←"], [JOY_BUTTON_DPAD_RIGHT, "Steuerkreuz →"]]:
		Bindings.bindings["fire"] = [{"t": "jb", "c": pair[0]}]
		_check(UiPrompts.action_text("fire", "gamepad") == pair[1], "Steuerkreuz eindeutig: " + pair[1])
	for item in [[JOY_AXIS_LEFT_X, -1, "Linker Stick ←"], [JOY_AXIS_LEFT_X, 1, "Linker Stick →"], [JOY_AXIS_LEFT_Y, -1, "Linker Stick ↑"], [JOY_AXIS_LEFT_Y, 1, "Linker Stick ↓"]]:
		Bindings.bindings["fire"] = [{"t": "ja", "a": item[0], "d": item[1]}]
		_check(UiPrompts.action_text("fire", "gamepad") == item[2], "Linker Stick mit Richtung: " + item[2])
	Bindings.bindings = {}

func _test_controls() -> void:
	var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for compact in [false, true]:
		for device in ["keyboard", "gamepad", "both"]:
			for action in ["fire", "ui_accept", "ui_cancel", "move_left", "nicht_belegt"]:
				var badges: Control = UiPrompts.make_badges(action, device, compact)
				_check(badges is HBoxContainer, "Badges sind HBox")
				_check_passive(badges)
				badges.free()
				_check(not is_instance_valid(badges), "Badges inklusive Kinder zerstört")
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= orphan_count, "Keine verwaisten Badge-Nodes")
	var fixture := VBoxContainer.new()
	fixture.name = "PromptFixture"
	add_child(fixture)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	fixture.add_child(footer)
	for item in [["ui_up", "Wählen"], ["ui_accept", "Bestätigen"], ["ui_cancel", "Zurück"], ["upgrade_prev", "Reiter"]]:
		var hint: Control = UiPrompts.make_hint(item[0], item[1], true)
		_check(hint is HBoxContainer and hint.get_child_count() == 2, "Hint = Badges + Label")
		_check_passive(hint)
		footer.add_child(hint)
	var full: Control = UiPrompts.make_badges("fire", "keyboard", false)
	var compact: Control = UiPrompts.make_badges("fire", "keyboard", true)
	fixture.add_child(full)
	fixture.add_child(compact)
	var face: Control = UiPrompts.make_badges("fire", "gamepad", true)
	fixture.add_child(face)
	await get_tree().process_frame
	await get_tree().process_frame
	var cap := full.get_child(0) as PanelContainer
	var small_cap := compact.get_child(0) as PanelContainer
	var face_cap := face.get_child(0) as PanelContainer
	_check((cap.get_child(0) as Label).text == "Leertaste", "Vollanzeige Leertaste")
	_check((small_cap.get_child(0) as Label).text == "Leer", "Kompakte deutsche Abkürzung")
	_check(compact.get_combined_minimum_size().x < full.get_combined_minimum_size().x, "compact spart Breite")
	_check(compact.get_combined_minimum_size().y <= 52, "Kompakte Tokens für 1080p-Footer (R4: doppeltes Canvas)")
	_check(footer.get_combined_minimum_size().x <= 1760, "Vier Menühinweise passen in 1760px")
	for hint in footer.get_children():
		var hint_text: String = hint.get_child(1).text
		var hint_width: float = hint.get_combined_minimum_size().x
		print("UI_PROMPTS_GROUP: %s=%.1fpx" % [hint_text, hint_width])
		_check(hint_width <= 360, "Kompakte Footergruppe %s höchstens 360px (%.1fpx)" % [hint_text, hint_width])
	for action in Bindings.ACTIONS:
		for device in ["keyboard", "gamepad"]:
			var column: Control = UiPrompts.make_badges(action, device, true)
			var limit := 260 if device == "keyboard" else 280
			_check(column.get_combined_minimum_size().x <= limit, "Settings-Spalte %s/%s passt" % [action, device])
			column.free()
	_check(is_equal_approx(face_cap.size.x, face_cap.size.y), "Xbox-Facebutton quadratische Kreisfläche")
	var face_style := face_cap.get_theme_stylebox("panel") as StyleBoxFlat
	_check(face_style.corner_radius_top_left >= face_cap.size.y / 2.0 - 1.0, "Xbox-Facebutton rund")
	var key_style := cap.get_theme_stylebox("panel") as StyleBoxFlat
	# R4: Pixel-Tastenkappen – eckig, aber weiterhin mit erhabener Unterkante.
	_check(key_style.corner_radius_top_left == 0 and key_style.border_width_bottom > key_style.border_width_top, "Eckige erhabene Pixel-Tastenkappen")
	print("UI_PROMPTS_LAYOUT: footer=%.1fpx compact=%.1fx%.1fpx face=%.1fx%.1fpx" % [footer.get_combined_minimum_size().x, compact.get_combined_minimum_size().x, compact.get_combined_minimum_size().y, face_cap.size.x, face_cap.size.y])
	fixture.queue_free()
	await get_tree().process_frame
	_check(not is_instance_valid(fixture), "Szenen-UI vollständig zerstört")

func _check_passive(node: Node) -> void:
	if node is Control:
		_check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Anzeige fängt keine Mausklicks ab")
		_check(node.focus_mode == Control.FOCUS_NONE, "Anzeige übernimmt keinen Eingabefokus")
	for child in node.get_children():
		_check_passive(child)

func _input_map_state() -> Dictionary:
	var state := {}
	for action in InputMap.get_actions():
		var events: Array[String] = []
		for event in InputMap.action_get_events(action):
			events.append(event.as_text())
		state[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": events}
	return state

func _save_disk_state() -> Dictionary:
	var state := {}
	for filename in DirAccess.get_files_at(Save.DIR):
		var path: String = Save.DIR.path_join(filename)
		state[filename] = FileAccess.get_sha256(path)
	return state

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
