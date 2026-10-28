extends "res://scripts/screens/hud.gd"
## Test-only observer: delegates every actual draw to production HUD unchanged.
var text_samples: Array[Dictionary] = []
var hint_samples: Array[Dictionary] = []
var shield_samples: Array[Dictionary] = []

func _draw() -> void:
	text_samples.clear()
	hint_samples.clear()
	shield_samples.clear()
	super._draw()

func _text(text: String, rect: Rect2, px: float, color: Color, s: float,
		bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := UiT.font_bold() if bold else UiT.font_regular()
	var fs := _fit_font(font, text, rect, px, s)
	text_samples.append({"text": text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"font_px": fs, "height": font.get_height(fs),
		"width": font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x})
	super._text(text, rect, px, color, s, bold, align)

func _draw_hint(action: String, label: String, pos: Vector2, s: float, color: Color = DIM) -> float:
	var width := super._draw_hint(action, label, pos, s, color)
	hint_samples.append({"action": action, "rect": [pos.x, pos.y, width, HINT_HEIGHT * s],
		"tokens": Prompts.tokens(action, "both")})
	return width

func _draw_shield_pip(rect: Rect2, filled: bool, charging: bool, s: float) -> void:
	shield_samples.append({"filled": filled, "charging": charging,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	super._draw_shield_pip(rect, filled, charging, s)
