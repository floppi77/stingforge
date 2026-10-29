extends Node
## Zentrale Eingabeschicht.
## - InputMap-Aktionen mit frei belegbaren Bindungen (Tastatur + Controller)
## - Trigger mit Hysterese (RT/LT)
## - Kantenerkennung mit Verbrauch ("consume"), damit ein Druck nur einmal wirkt
## - Eingabesperre nach Kontextwechsel: Taste muss erst losgelassen werden
## - Gerätewechsel ohne Flackern

const ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"fire", "autofire", "upgrade_prev", "upgrade_next", "upgrade_buy",
	"menu", "precision", "debug_menu",
	"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
]

## Standardbelegung: Liste von Bindungsbeschreibungen.
## {"t":"key","c":KEY_*} | {"t":"jb","c":JOY_BUTTON_*} | {"t":"ja","a":axis,"d":dir,"th":Schwelle}
const DEFAULTS := {
	"move_left":    [{"t": "key", "c": KEY_A}, {"t": "key", "c": KEY_LEFT}, {"t": "jb", "c": JOY_BUTTON_DPAD_LEFT}, {"t": "ja", "a": JOY_AXIS_LEFT_X, "d": -1}],
	"move_right":   [{"t": "key", "c": KEY_D}, {"t": "key", "c": KEY_RIGHT}, {"t": "jb", "c": JOY_BUTTON_DPAD_RIGHT}, {"t": "ja", "a": JOY_AXIS_LEFT_X, "d": 1}],
	"move_up":      [{"t": "key", "c": KEY_W}, {"t": "key", "c": KEY_UP}, {"t": "jb", "c": JOY_BUTTON_DPAD_UP}, {"t": "ja", "a": JOY_AXIS_LEFT_Y, "d": -1}],
	"move_down":    [{"t": "key", "c": KEY_S}, {"t": "key", "c": KEY_DOWN}, {"t": "jb", "c": JOY_BUTTON_DPAD_DOWN}, {"t": "ja", "a": JOY_AXIS_LEFT_Y, "d": 1}],
	"fire":         [{"t": "key", "c": KEY_SPACE}, {"t": "jb", "c": JOY_BUTTON_A}],
	"autofire":     [{"t": "key", "c": KEY_R}, {"t": "jb", "c": JOY_BUTTON_X}],
	"upgrade_prev": [{"t": "key", "c": KEY_Q}, {"t": "jb", "c": JOY_BUTTON_LEFT_SHOULDER}],
	"upgrade_next": [{"t": "key", "c": KEY_E}, {"t": "jb", "c": JOY_BUTTON_RIGHT_SHOULDER}],
	"upgrade_buy":  [{"t": "key", "c": KEY_F}, {"t": "ja", "a": JOY_AXIS_TRIGGER_RIGHT, "d": 1, "th": 0.6}],
	"menu":         [{"t": "key", "c": KEY_ESCAPE}, {"t": "jb", "c": JOY_BUTTON_START}],
	"precision":    [{"t": "key", "c": KEY_SHIFT}, {"t": "ja", "a": JOY_AXIS_TRIGGER_LEFT, "d": 1, "th": 0.5}],
	"debug_menu":   [{"t": "key", "c": KEY_F4}, {"t": "jb", "c": JOY_BUTTON_BACK}],
	"ui_accept":    [{"t": "key", "c": KEY_SPACE}, {"t": "key", "c": KEY_ENTER}, {"t": "jb", "c": JOY_BUTTON_A}],
	"ui_cancel":    [{"t": "key", "c": KEY_ESCAPE}, {"t": "jb", "c": JOY_BUTTON_B}],
	"ui_up":        [{"t": "key", "c": KEY_W}, {"t": "key", "c": KEY_UP}, {"t": "jb", "c": JOY_BUTTON_DPAD_UP}, {"t": "ja", "a": JOY_AXIS_LEFT_Y, "d": -1}],
	"ui_down":      [{"t": "key", "c": KEY_S}, {"t": "key", "c": KEY_DOWN}, {"t": "jb", "c": JOY_BUTTON_DPAD_DOWN}, {"t": "ja", "a": JOY_AXIS_LEFT_Y, "d": 1}],
	"ui_left":      [{"t": "key", "c": KEY_A}, {"t": "key", "c": KEY_LEFT}, {"t": "jb", "c": JOY_BUTTON_DPAD_LEFT}, {"t": "ja", "a": JOY_AXIS_LEFT_X, "d": -1}],
	"ui_right":     [{"t": "key", "c": KEY_D}, {"t": "key", "c": KEY_RIGHT}, {"t": "jb", "c": JOY_BUTTON_DPAD_RIGHT}, {"t": "ja", "a": JOY_AXIS_LEFT_X, "d": 1}],
}

var bindings: Dictionary = {}
var last_device: String = "keyboard"
var _frame: int = -1
var _cur: Dictionary = {}
var _prev: Dictionary = {}
var _edge: Dictionary = {}
var _consumed: Dictionary = {}
var _blocked: Dictionary = {}
var _trigger_state: Dictionary = {}
var _axis_state: Dictionary = {}
var _activity_signature: float = 0.0
var _rebind_action: String = ""
var _slop := 0.30

## Angeschlossene Controller. Prüfläufe ohne Fenster (headless) ignorieren echte
## Geräte am Rechner, damit ein Tastendruck am Schreibtisch keinen Test verfälscht.
func pads() -> Array[int]:
	if DisplayServer.get_name() == "headless":
		return []
	return Input.get_connected_joypads()

## Controller-Vibration (Einstellungen › Steuerung): Stärke 0–1 je Motor, Dauer in s.
## Gibt zurück, ob vibriert wurde (aus, kein Controller oder Stärke 0: nein).
func rumble(weak: float, strong: float, duration: float) -> bool:
	if not bool(Save.g("controls.vibration", true)):
		return false
	var k := clampf(float(Save.g("controls.vibration_strength", 0.6)), 0.0, 1.0)
	if k <= 0.0:
		return false
	var list := pads()
	for pad in list:
		Input.start_joy_vibration(pad, clampf(weak * k, 0.0, 1.0), clampf(strong * k, 0.0, 1.0), duration)
	return not list.is_empty()

func _ready() -> void:
	_ensure_actions()
	load_bindings()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ensure_actions() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.0)
		InputMap.action_erase_events(a)
		for b in bindings_for(a):
			var ev := _to_event(b)
			if ev != null:
				InputMap.action_add_event(a, ev)

func bindings_for(action: String) -> Array:
	if bindings.has(action) and not (bindings[action] as Array).is_empty():
		return bindings[action]
	return DEFAULTS.get(action, [])

func load_bindings() -> void:
	var raw: Variant = Save.g("controls.bindings", {})
	bindings = {}
	if raw is Dictionary:
		for a in ACTIONS:
			if raw.has(a) and raw[a] is Array and not (raw[a] as Array).is_empty():
				bindings[a] = raw[a]
	_ensure_actions()

func save_bindings() -> void:
	Save.set_g("controls.bindings", bindings)

func _to_event(b: Dictionary) -> InputEvent:
	match String(b.get("t", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(b.get("c", 0))
			k.keycode = int(b.get("c", 0))
			return k
		"jb":
			var j := InputEventJoypadButton.new()
			j.button_index = int(b.get("c", 0))
			return j
		"ja":
			var m := InputEventJoypadMotion.new()
			m.axis = int(b.get("a", 0))
			m.axis_value = float(b.get("d", 1)) * 1.0
			return m
	return null

# ------------------------------------------------------------- Abfragen/Status
func _update() -> void:
	var f := Engine.get_physics_frames()
	if f == _frame:
		return
	_frame = f
	_prev = _cur
	_cur = {}
	for a in ACTIONS:
		var raw := _raw_pressed(a)
		if _blocked.has(a):
			if not raw:
				_blocked.erase(a)
			raw = false
		_cur[a] = raw
		var was: bool = _prev.get(a, false)
		# Der Tastendruck bleibt als Auslöser stehen, bis er verbraucht wird.
		# Sonst gehen Eingaben verloren, wenn zwischen zwei Physikbildern kein
		# Zeichenbild liegt (Menüs fragen im Zeichenbild, Spiel in der Physik).
		if raw and not was:
			_edge[a] = true
			_consumed[a] = false
		elif not raw:
			_edge[a] = false
	_detect_device()

func is_down(action: String) -> bool:
	_update()
	return _cur.get(action, false)

func is_pressed_phys(action: String) -> bool:
	return _raw_pressed(action)

## Liefert true genau einmal pro Tastendruck.
func consume(action: String) -> bool:
	_update()
	if _edge.get(action, false) and not _consumed.get(action, false):
		_consumed[action] = true
		return true
	return false

func peek(action: String) -> bool:
	_update()
	return _edge.get(action, false) and not _consumed.get(action, false)

## Blockiert Aktionen bis zur vollständigen Freigabe (Kontextwechsel).
func block_until_release(actions: Array = []) -> void:
	_update()
	var list: Array = actions if not actions.is_empty() else ACTIONS
	for a in list:
		_blocked[a] = true
		_edge[a] = false

func block_all() -> void:
	block_until_release(ACTIONS)

func clear_blocks() -> void:
	_blocked.clear()

func any_confirm_down() -> bool:
	return _raw_pressed("ui_accept") or _raw_pressed("upgrade_buy")

# ------------------------------------------------------------------ Rohzustand
func _raw_pressed(action: String) -> bool:
	for b in bindings_for(action):
		if _binding_active(b):
			return true
	return false

func _binding_active(b: Dictionary) -> bool:
	match String(b.get("t", "")):
		"key":
			return Input.is_physical_key_pressed(int(b.get("c", 0))) or Input.is_key_pressed(int(b.get("c", 0)))
		"jb":
			for d in pads():
				if Input.is_joy_button_pressed(d, int(b.get("c", 0))):
					return true
			return false
		"ja":
			var axis := int(b.get("a", 0))
			var dir := float(b.get("d", 1))
			var th := float(b.get("th", 0.5))
			var key := "%s_%d_%d" % [action_of_binding(b), axis, int(dir)]
			var val := _axis_value(axis) * dir
			# Hysterese: auslösen oberhalb th, erneut scharf unter th*0.55
			var on: bool = _axis_state.get(key, false)
			if not on and val > th:
				on = true
			elif on and val < th * 0.55:
				on = false
			_axis_state[key] = on
			return on
	return false

func action_of_binding(b: Dictionary) -> String:
	for a in ACTIONS:
		if bindings_for(a).has(b):
			return a
	return "x"

func _axis_value(axis: int) -> float:
	var best := 0.0
	for d in pads():
		var v := Input.get_joy_axis(d, axis)
		if absf(v) > absf(best):
			best = v
	return best

## Analoge Bewegungsachse (Stick) mit radialer Totzone, auf Einheitskreis normiert.
## Nur für Prüfwerkzeuge: erzwungene Bewegungsrichtung (im Spiel nie gesetzt).
var test_move_active: bool = false
var test_move: Vector2 = Vector2.ZERO

func move_vector() -> Vector2:
	if test_move_active:
		return test_move.limit_length(1.0)
	_update()
	var deadzone: float = float(Save.g("controls.deadzone", 0.22))
	var sens: float = float(Save.g("controls.sensitivity", 1.0))
	var v := Vector2.ZERO
	var analog := Vector2.ZERO
	for d in pads():
		var ax := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
		if Vector2(ax, ay).length() > analog.length():
			analog = Vector2(ax, ay)
	analog *= sens
	var mag := analog.length()
	if mag > deadzone:
		var scaled := (mag - deadzone) / maxf(0.001, 1.0 - deadzone)
		analog = analog.normalized() * clampf(scaled, 0.0, 1.0)
	else:
		analog = Vector2.ZERO
	# Digitale Achsen (Tastatur/D-Pad) haben Vorrang als volle Richtung
	var dx := (1.0 if _cur.get("move_right", false) else 0.0) - (1.0 if _cur.get("move_left", false) else 0.0)
	var dy := (1.0 if _cur.get("move_down", false) else 0.0) - (1.0 if _cur.get("move_up", false) else 0.0)
	v = Vector2(dx, dy)
	if v.length() > 1.0:
		v = v.normalized()
	if analog.length() > 0.02:
		if v.length() < 0.02:
			v = analog
		else:
			v = (v + analog).limit_length(1.0)
	return v.limit_length(1.0)

func is_precision() -> bool:
	return is_down("precision")

func is_firing() -> bool:
	return is_down("fire")

# --------------------------------------------------------------- Gerätewechsel
func _detect_device() -> void:
	var sig := 0.0
	var pad_active := false
	for d in pads():
		var ax := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if ax.length() > _slop:
			pad_active = true
		for i in range(JOY_BUTTON_MAX):
			if Input.is_joy_button_pressed(d, i):
				pad_active = true
	if pad_active:
		last_device = "joypad"
		return
	var keys := ["move_left", "move_right", "move_up", "move_down", "fire", "ui_accept", "ui_cancel", "menu"]
	for a in keys:
		if _raw_pressed_kb(a):
			last_device = "keyboard"
			return

func _raw_pressed_kb(action: String) -> bool:
	for b in bindings_for(action):
		if String(b.get("t", "")) == "key":
			if Input.is_physical_key_pressed(int(b.get("c", 0))):
				return true
	return false

func device() -> String:
	return last_device

# ------------------------------------------------------------------- Neubelegung
func describe_binding(b: Dictionary) -> String:
	match String(b.get("t", "")):
		"key":
			var code := int(b.get("c", 0))
			var s := OS.get_keycode_string(code)
			return s if s != "" else ("Taste %d" % code)
		"jb":
			match int(b.get("c", -1)):
				JOY_BUTTON_A: return "A"
				JOY_BUTTON_B: return "B"
				JOY_BUTTON_X: return "X"
				JOY_BUTTON_Y: return "Y"
				JOY_BUTTON_LEFT_SHOULDER: return "LB"
				JOY_BUTTON_RIGHT_SHOULDER: return "RB"
				JOY_BUTTON_START: return "Start"
				JOY_BUTTON_BACK: return "Select"
				JOY_BUTTON_DPAD_UP: return "D-Pad ↑"
				JOY_BUTTON_DPAD_DOWN: return "D-Pad ↓"
				JOY_BUTTON_DPAD_LEFT: return "D-Pad ←"
				JOY_BUTTON_DPAD_RIGHT: return "D-Pad →"
				_: return "Taste %d" % int(b.get("c", 0))
		"ja":
			match int(b.get("a", -1)):
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
				JOY_AXIS_LEFT_X: return "Stick ↔"
				JOY_AXIS_LEFT_Y: return "Stick ↕"
				_: return "Achse %d" % int(b.get("a", 0))
	return "?"

func describe_action(action: String) -> String:
	var parts: Array[String] = []
	for b in bindings_for(action):
		parts.append(describe_binding(b))
	return " / ".join(parts)

func event_to_binding(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"t": "key", "c": int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)}
	if ev is InputEventJoypadButton:
		return {"t": "jb", "c": int((ev as InputEventJoypadButton).button_index)}
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		if absf(m.axis_value) < 0.5:
			return {}
		var d := 1 if m.axis_value > 0 else -1
		var th := 0.6 if m.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else 0.5
		return {"t": "ja", "a": int(m.axis), "d": d, "th": th}
	return {}

func find_conflict(action: String, b: Dictionary) -> String:
	for a in ACTIONS:
		if a == action:
			continue
		for other in bindings_for(a):
			if _same_binding(b, other):
				return a
	return ""

func _same_binding(a: Dictionary, b: Dictionary) -> bool:
	if String(a.get("t", "")) != String(b.get("t", "")):
		return false
	match String(a.get("t", "")):
		"key", "jb":
			return int(a.get("c", -1)) == int(b.get("c", -2))
		"ja":
			return int(a.get("a", -1)) == int(b.get("a", -2)) and int(a.get("d", 0)) == int(b.get("d", 9))
	return false

func apply_binding(action: String, b: Dictionary, force: bool = false) -> String:
	var conflict := find_conflict(action, b)
	if conflict != "" and not force:
		return conflict
	if conflict != "":
		# Konflikt auflösen: andere Aktion bekommt Standard zurück
		bindings.erase(conflict)
	bindings[action] = [b]
	save_bindings()
	_axis_state.clear()
	return ""

func reset_action(action: String) -> void:
	bindings.erase(action)
	save_bindings()
	_ensure_actions()

func reset_all() -> void:
	bindings = {}
	save_bindings()
	_ensure_actions()
