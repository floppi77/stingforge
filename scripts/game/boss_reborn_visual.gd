extends Node2D
## Local, non-colliding telegraph only. Crown/wings/spikes live in the body PNGs,
## so Boss.trace_hit always uses their actual current AtlasTexture alpha pixels.
const FRAME_SIZE := Vector2(224, 224)
static var _frames: Dictionary = {}
var phase_index := 0
var revive_progress := -1.0
var warning := 0.0
var reduced := false

static func frames_for_phase(index: int) -> SpriteFrames:
	var safe_index := clampi(index, 0, 2)
	if _frames.has(safe_index):
		return _frames[safe_index]
	var path := "res://assets/sprites/boss_reborn_p%d.png" % (safe_index + 1)
	# No preload/import race: MAIN imports the PNGs before the coordinated run.
	if not ResourceLoader.exists(path):
		push_warning("Stingforge reborn asset awaits MAIN import: " + path)
		return null
	var sheet := load(path) as Texture2D
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 6.25)
	frames.set_animation_loop("default", true)
	for frame in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(frame * 224, 0), FRAME_SIZE)
		frames.add_frame("default", atlas, 1.125 if frame == 0 else 0.875)
	_frames[safe_index] = frames
	return frames

func set_status(index: int, progress: float, telegraph: float) -> void:
	phase_index = clampi(index, 0, 2)
	revive_progress = progress
	warning = telegraph
	reduced = bool(Save.g("access.reduce_effects", false)) or not bool(Save.g("graphics.flashes", true))
	queue_redraw()

func _draw() -> void:
	if revive_progress >= 0.0:
		var r := lerpf(62.0, 105.0, revive_progress)
		var col := Color("#e5bd85")
		col.a = 0.65 if reduced else 0.85
		draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * maxf(0.01, revive_progress), 48, col, 2.0, false)
		# Three crown marks announce the coming three phases; no flashing screen.
		for i in range(3):
			var x := float(i - 1) * 16.0
			draw_polyline(PackedVector2Array([Vector2(x - 5, -42), Vector2(x, -51), Vector2(x + 5, -42)]), col, 2.0, false)
	elif warning > 0.0:
		var col := Color("#ffd49d")
		col.a = 0.5 if reduced else 0.8
		# Clearly cosmetic broken warning arcs, not extra contact hitboxes.
		for i in range(phase_index + 1):
			var angle := PI * 0.65 + float(i) * 0.5
			draw_arc(Vector2.ZERO, 106.0, angle, angle + 0.36, 10, col, 2.0, false)
