extends Control
## Levelende: restlicher Blütenstaub (Nektar) wird in Punkte umgerechnet.
## Läuft mittig im Bild, zählt hoch, klingt dabei und übergibt danach weiter.

const UiTheme := preload("res://scripts/core/ui_theme.gd")
const UiPrompts := preload("res://scripts/core/ui_prompts.gd")
const POINTS_PER_NECTAR := 10

var app: Node
var nectar: int = 0
var total: int = 0
var shown: int = 0
var t: float = 0.0
var phase: int = 0          # 0 = Umrechnung läuft, 1 = Ergebnis steht, 2 = fertig
var _next_sfx: float = 0.0
var _done := false
var on_done: Callable = Callable()

var title_label: Label
var count_label: Label
var detail_label: Label
var done_label: Label
var panel: PanelContainer
var dim: ColorRect
var center: CenterContainer

func setup(args: Dictionary) -> void:
	nectar = maxi(0, int(args.get("nectar", 0)))
	# Bessere Umrechnung aus der Werkstatt
	var bonus := 1.0
	var shop: Dictionary = Save.campaign.get("shop", {})
	for id in shop.keys():
		var step := ShopData.step(String(id), int(shop[id]) - 1)
		bonus += float((step.get("mod", {}) as Dictionary).get("convert_bonus", 0.0))
	total = int(round(float(nectar * POINTS_PER_NECTAR) * bonus))
	on_done = args.get("on_done", Callable())

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Punkte sofort gutschreiben, damit sie auch bei Abbruch zählen
	if nectar > 0:
		# Vor der Guthabenänderung zählen, damit auch alte Saves den Bonus nicht doppeln.
		Save.add_run_score(total)
		Save.campaign.points = int(Save.campaign.get("points", 0)) + total
	Save.campaign.nectar = 0
	Save.save_campaign()
	if total > 0:
		Audio.sfx("pickup_nectar", -8.0, 0.85, true)

func _fit() -> void:
	var r: Rect2 = get_viewport().get_visible_rect()
	size = r.size
	if dim != null:
		dim.size = r.size
	if center != null:
		center.size = r.size

func _build() -> void:
	# Die CanvasLayer erhält ihre Größe explizit, nicht zugleich über Gegenanker.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var r: Rect2 = get_viewport().get_visible_rect()
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.88)
	dim.size = r.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	center = CenterContainer.new()
	center.size = r.size
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# etwas über der Mitte, damit die Leiste darunter nicht verdeckt wirkt
	center.position = Vector2(0, -UiTheme.size(24))
	add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.custom_minimum_size = Vector2(minf(UiTheme.size(580), r.size.x - 80), UiTheme.size(150))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTheme.pad(22))
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.pad(8))
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = Loc.t("conv.title")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UiTheme.font_bold())
	title_label.add_theme_font_size_override("font_size", UiTheme.size(24))
	title_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title_label)

	detail_label = Label.new()
	detail_label.text = Loc.t("conv.detail") % [nectar, POINTS_PER_NECTAR]
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_override("font", UiTheme.font_regular())
	detail_label.add_theme_font_size_override("font_size", UiTheme.size(18))
	detail_label.add_theme_color_override("font_color", UiTheme.DIM)
	box.add_child(detail_label)

	count_label = Label.new()
	count_label.text = "+0"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_override("font", UiTheme.font_bold())
	count_label.add_theme_font_size_override("font_size", UiTheme.size(52))
	count_label.add_theme_color_override("font_color", UiTheme.TEXT)
	box.add_child(count_label)

	done_label = Label.new()
	done_label.text = Loc.t("conv.points")
	done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_label.add_theme_font_override("font", UiTheme.font_regular())
	done_label.add_theme_font_size_override("font_size", UiTheme.size(18))
	done_label.add_theme_color_override("font_color", UiTheme.OK)
	done_label.modulate = Color(1, 1, 1, 0)
	box.add_child(done_label)

	var total_label := Label.new()
	total_label.name = "Total"
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_override("font", UiTheme.font_regular())
	total_label.add_theme_font_size_override("font_size", UiTheme.size(16))
	total_label.add_theme_color_override("font_color", UiTheme.DIM)
	total_label.text = Loc.t("conv.total") % int(Save.campaign.get("points", 0))
	box.add_child(total_label)
	var hint_center := CenterContainer.new()
	hint_center.add_child(UiPrompts.make_hint("ui_accept", "Weiter", true))
	box.add_child(hint_center)
	for label in [title_label, detail_label, count_label, done_label, total_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit()

func _process(delta: float) -> void:
	# Panel mittig halten, auch wenn sich die Fenstergröße ändert
	_fit()
	t += delta
	match phase:
		0:
			var dur := clampf(0.4 + float(nectar) * 0.012, 0.55, 1.35)
			var frac := clampf(t / dur, 0.0, 1.0)
			shown = int(round(float(total) * frac))
			count_label.text = "+%d" % shown
			count_label.add_theme_color_override("font_color",
				UiTheme.TEXT.lerp(UiTheme.ACCENT, 0.35 + 0.65 * frac))
			count_label.pivot_offset = count_label.size * 0.5
			count_label.scale = Vector2.ONE * (1.0 + 0.14 * sin(frac * PI))
			_next_sfx -= delta
			if _next_sfx <= 0.0 and nectar > 0:
				_next_sfx = clampf(dur / float(maxi(1, nectar)), 0.035, 0.16)
				Audio.sfx("ui_move", -18.0, 1.0 + frac * 0.8, true)
			if frac >= 1.0:
				phase = 1
				t = 0.0
				count_label.scale = Vector2.ONE
				count_label.text = "+%d" % total
				var tl := find_child("Total", true, false) as Label
				if tl != null:
					tl.text = Loc.t("conv.total") % int(Save.campaign.get("points", 0))
				Audio.sfx("ui_ok", -6.0, 0.9, true)
				Audio.sfx("pickup_heart", -14.0, 1.12, true)
		1:
			done_label.modulate = Color(1, 1, 1, clampf(t / 0.25, 0.0, 1.0))
			if t > 0.9:
				_finish()
		2:
			pass
	if Bindings.consume("ui_accept") or Bindings.consume("ui_cancel") or \
			Bindings.consume("menu") or Bindings.consume("upgrade_buy"):
		if phase == 0:
			phase = 1
			t = 0.0
			count_label.text = "+%d" % total
			Audio.sfx("ui_ok", -6.0, 0.9, true)
		else:
			_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	phase = 2
	if on_done.is_valid():
		on_done.call()
