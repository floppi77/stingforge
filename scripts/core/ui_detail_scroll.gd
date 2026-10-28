extends ScrollContainer
## Nur Menüdarstellung: lange Detailkarten per Mausrad oder rechtem Stick lesen.
## Keine Eingabeaktion, kein Schreiben in Belegungen und kein Zugriff auf die Welt.
var screen: Control
var _last_focus := -1
var _remainder := 0.0

func _process(delta: float) -> void:
	if screen == null or not is_instance_valid(screen) or not screen.is_visible_in_tree(): return
	var app := get_node_or_null("/root/App")
	if app == null or app.screens.is_empty() or app.screens[-1] != screen: return
	if screen.focus != _last_focus:
		_last_focus = screen.focus
		scroll_vertical = 0
		_remainder = 0.0
	var axis := 0.0
	for device in Bindings.pads():
		var value := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(value) > absf(axis): axis = value
	if absf(axis) < 0.25:
		_remainder = 0.0
		return
	_remainder += axis * 220.0 * delta
	var pixels := int(_remainder)
	_remainder -= pixels
	scroll_vertical += pixels
