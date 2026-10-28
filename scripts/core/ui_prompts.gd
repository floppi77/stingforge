extends RefCounted
## Ausschließlich Darstellung: liest Bindings.bindings_for(), verändert weder
## Belegungen noch InputMap oder Save. Nutzung über preload, wie ui_theme.gd.
## "both" zeigt immer beide Geräteklassen, unabhängig vom zuletzt aktiven Gerät.

const U := preload("res://scripts/core/ui_theme.gd")
const FACE_COLORS := {
	"A": Color("#79d778"),
	"B": Color("#f47c79"),
	"X": Color("#79b8f4"),
	"Y": Color("#f2d369"),
}

static func tokens(action: String, device: String = "both") -> Array[Dictionary]:
	var keys: Array[Dictionary] = []
	var pads: Array[Dictionary] = []
	for binding in Bindings.bindings_for(action):
		if not binding is Dictionary:
			continue
		var token := _binding_token(binding)
		if token.is_empty():
			continue
		var target: Array[Dictionary] = keys if token["kind"] == "key" else pads
		if not target.has(token):
			target.append(token)
	var out: Array[Dictionary] = []
	if device != "gamepad":
		if keys.is_empty():
			keys.append({"text": "—", "kind": "key"})
		out.append_array(keys)
	if device != "keyboard":
		if pads.is_empty():
			pads.append({"text": "—", "kind": "pad"})
		out.append_array(pads)
	return out

static func action_text(action: String, device: String = "both") -> String:
	var parts: Array[String] = []
	for token in tokens(action, device):
		parts.append(String(token["text"]))
	return " / ".join(parts)

## Statischer Anzeige-Schnappschuss; bei geänderten Belegungen neu aufbauen.
## compact ist für kleine Footer und getrennte Settings-Spalten gedacht.
static func make_badges(action: String, device: String = "both", compact: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.name = "InputBadges"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", U.pad(2 if compact else 4))
	var previous_kind := ""
	for token in tokens(action, device):
		var kind := String(token["kind"])
		if previous_kind != "":
			var separator := _label("·" if kind != previous_kind else "/", compact, U.DIM)
			row.add_child(separator)
		row.add_child(_badge(token, compact))
		previous_kind = kind
	return row

static func make_hint(action: String, label: String, compact: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.name = "InputHint"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", U.pad(4 if compact else 8))
	row.add_child(make_badges(action, "both", compact))
	row.add_child(_label(label, compact, U.TEXT))
	return row

## Richtungen zusammengefasst, ohne eine geänderte Belegung zu überschreiben.
static func make_navigation_hint(grid: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", U.pad(4))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var groups: Dictionary = {"key": [], "pad": []}
	var actions := ["ui_up", "ui_down", "ui_left", "ui_right"] if grid else ["ui_up", "ui_down"]
	for action in actions:
		for token in tokens(action):
			var text := String(token.text)
			if text not in groups[token.kind]: groups[token.kind].append(text)
	for kind in ["key", "pad"]:
		var values: Array = groups[kind]
		if kind == "key":
			var letters: Array = []
			var arrows: Array = []
			for text in values:
				if String(text).begins_with("Pfeil "): arrows.append(String(text).trim_prefix("Pfeil "))
				else: letters.append(text)
			if not letters.is_empty(): row.add_child(_badge({"text": "/".join(letters), "kind": kind}, true))
			if not arrows.is_empty(): row.add_child(_badge({"text": "".join(arrows), "kind": kind}, true))
		else:
			var dpad := false
			var stick := false
			for text in values:
				if String(text).begins_with("Steuerkreuz "): dpad = true
				elif String(text).begins_with("Linker Stick "): stick = true
				else: row.add_child(_badge({"text": text, "kind": kind}, true))
			if dpad: row.add_child(_badge({"text": "D-Pad", "kind": kind}, true))
			if stick: row.add_child(_badge({"text": "LS", "kind": kind}, true))
	row.add_child(_label("Wählen", true, U.TEXT))
	return row

static func _binding_token(binding: Dictionary) -> Dictionary:
	match String(binding.get("t", "")):
		"key":
			return {"text": _key_name(int(binding.get("c", 0))), "kind": "key"}
		"jb":
			var text := _button_name(int(binding.get("c", -1)))
			var token := {"text": text, "kind": "pad"}
			if FACE_COLORS.has(text):
				token["color"] = FACE_COLORS[text]
			return token
		"ja":
			return {"text": _axis_name(int(binding.get("a", -1)), float(binding.get("d", 1))), "kind": "pad"}
	return {}

static func _key_name(code: int) -> String:
	match code:
		KEY_NONE: return "—"
		KEY_SPACE: return "Leertaste"
		KEY_ENTER: return "Eingabe"
		KEY_KP_ENTER: return "Num Eingabe"
		KEY_SHIFT: return "Umschalt"
		KEY_CTRL: return "Strg"
		KEY_ALT: return "Alt"
		KEY_META: return "Meta"
		KEY_ESCAPE: return "Esc"
		KEY_TAB: return "Tab"
		KEY_BACKSPACE: return "Rücktaste"
		KEY_DELETE: return "Entf"
		KEY_INSERT: return "Einfg"
		KEY_HOME: return "Pos1"
		KEY_END: return "Ende"
		KEY_PAGEUP: return "Bild ↑"
		KEY_PAGEDOWN: return "Bild ↓"
		KEY_UP: return "Pfeil ↑"
		KEY_DOWN: return "Pfeil ↓"
		KEY_LEFT: return "Pfeil ←"
		KEY_RIGHT: return "Pfeil →"
		KEY_CAPSLOCK: return "Feststelltaste"
		KEY_NUMLOCK: return "Num-Fest"
		KEY_SCROLLLOCK: return "Rollen"
		KEY_PRINT: return "Druck"
		KEY_PAUSE: return "Pause"
	var text := OS.get_keycode_string(code)
	return text if not text.is_empty() else "Taste %d" % code

static func _button_name(code: int) -> String:
	match code:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Menü"
		JOY_BUTTON_BACK: return "Ansicht"
		JOY_BUTTON_GUIDE: return "Xbox"
		JOY_BUTTON_LEFT_STICK: return "Linker Stick · Druck"
		JOY_BUTTON_RIGHT_STICK: return "Rechter Stick · Druck"
		JOY_BUTTON_DPAD_UP: return "Steuerkreuz ↑"
		JOY_BUTTON_DPAD_DOWN: return "Steuerkreuz ↓"
		JOY_BUTTON_DPAD_LEFT: return "Steuerkreuz ←"
		JOY_BUTTON_DPAD_RIGHT: return "Steuerkreuz →"
	return "Pad-Taste %d" % code

static func _axis_name(axis: int, direction: float) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		JOY_AXIS_LEFT_X: return "Linker Stick ←" if direction < 0 else "Linker Stick →"
		JOY_AXIS_LEFT_Y: return "Linker Stick ↑" if direction < 0 else "Linker Stick ↓"
		JOY_AXIS_RIGHT_X: return "Rechter Stick ←" if direction < 0 else "Rechter Stick →"
		JOY_AXIS_RIGHT_Y: return "Rechter Stick ↑" if direction < 0 else "Rechter Stick ↓"
	return "Pad-Achse %d %s" % [axis, "−" if direction < 0 else "+"]

static func _compact_text(text: String) -> String:
	match text:
		"Leertaste": return "Leer"
		"Eingabe": return "Eing."
		"Num Eingabe": return "Num ↵"
		"Umschalt": return "Umsch."
		"Rücktaste": return "Rück"
		"Feststelltaste": return "Fest"
	return text.replace("Pfeil ", "").replace("Steuerkreuz ", "D ").replace("Linker Stick", "LS").replace("Rechter Stick", "RS").replace(" · Druck", " · Klick")

static func _label(text: String, compact: bool, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", U.font_semi())
	label.add_theme_font_size_override("font_size", U.size(12 if compact else 14))
	label.add_theme_color_override("font_color", color)
	return label

static func _badge(token: Dictionary, compact: bool) -> Control:
	var text := String(token["text"])
	var is_key := String(token["kind"]) == "key"
	var is_face := not is_key and token.has("color") and FACE_COLORS.has(text)
	var height := U.size(22 if compact else 28)
	var badge := PanelContainer.new()
	badge.name = "Keycap" if is_key else "PadButton"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.custom_minimum_size = Vector2(height, height)
	badge.tooltip_text = text
	badge.set_meta("prompt_text", text)
	badge.set_meta("prompt_kind", token["kind"])
	# Pixel-Tastenkappen: harte Kanten, dunkle Unterkante als Tastenhub.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#242a4e") if is_key else Color("#1b2f4a")
	style.border_color = Color("#6b78b4") if is_key else Color("#52d6c4")
	if is_face:
		var face_color: Color = token["color"]
		style.bg_color = face_color
		style.border_color = face_color.darkened(0.45)
	style.set_corner_radius_all(height / 2 if is_face else 0)
	style.corner_detail = 6 if is_face else 1
	style.anti_aliasing = false
	style.set_border_width_all(U.pad(1))
	if is_key:
		style.border_width_bottom = U.pad(3)
		style.border_color = Color("#6b78b4")
	style.content_margin_left = 0 if is_face else U.pad(3 if compact else 8)
	style.content_margin_right = style.content_margin_left
	style.content_margin_top = 0
	style.content_margin_bottom = U.pad(1)
	badge.add_theme_stylebox_override("panel", style)
	var ink := Color("#0b0a18") if is_face else U.TEXT
	if text == "—":
		ink = U.DIM
	var label := _label(_compact_text(text) if compact else text, compact, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	return badge
