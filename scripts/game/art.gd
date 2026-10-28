class_name Art
extends RefCounted
## Zugriff auf alle Sprite-Strips. Manifest: assets/sprites/manifest.json
## {"name": {"w":32,"h":32,"frames":4,"fps":10}}

const DIR := "res://assets/sprites/"
const FALLBACK := {"w": 16, "h": 16, "frames": 1, "fps": 8}

static var _manifest: Dictionary = {}
static var _loaded := false
static var _sheets: Dictionary = {}
static var _frames: Dictionary = {}
static var _frame_tex: Dictionary = {}
static var _fallback_tex: Dictionary = {}

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var path := DIR + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		_manifest = d

static func info(name: String) -> Dictionary:
	_load()
	if _manifest.has(name):
		return _manifest[name]
	return FALLBACK

static func has(name: String) -> bool:
	_load()
	return _manifest.has(name)

static func sheet(name: String) -> Texture2D:
	if _sheets.has(name):
		return _sheets[name]
	var path := DIR + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = _fallback(name)
	_sheets[name] = tex
	return tex

static func _fallback(name: String) -> Texture2D:
	if _fallback_tex.has(name):
		return _fallback_tex[name]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var col := Color("#e8d44a")
	var h := float(abs(name.hash()) % 360) / 360.0
	col = Color.from_hsv(h, 0.55, 0.85, 1.0)
	for y in range(16):
		for x in range(16):
			var dx := (x - 7.5) / 7.5
			var dy := (y - 7.5) / 7.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col if (x + y) % 7 != 0 else col.darkened(0.35))
	var t := ImageTexture.create_from_image(img)
	_fallback_tex[name] = t
	return t

## Einzelbild aus einem Streifen als eigene Textur (Sprite2D zeigt sonst
## alle Bilder nebeneinander).
static func frame_tex(name: String, frame: int = 0) -> Texture2D:
	var key := name + "#" + str(frame)
	if _frame_tex.has(key):
		return _frame_tex[key]
	var at := AtlasTexture.new()
	at.atlas = sheet(name)
	at.region = region(name, frame)
	_frame_tex[key] = at
	return at

static func region(name: String, frame: int) -> Rect2:
	var inf := info(name)
	var n: int = maxi(1, int(inf.get("frames", 1)))
	var w: int = int(inf.get("w", 16))
	var h: int = int(inf.get("h", 16))
	return Rect2(Vector2((frame % n) * w, 0), Vector2(w, h))

static func frame_count(name: String) -> int:
	return maxi(1, int(info(name).get("frames", 1)))

static func sprite_frames(name: String, fps: float = -1.0) -> SpriteFrames:
	var key := name + "|" + str(fps)
	if _frames.has(key):
		return _frames[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("default")
	sf.set_animation_loop("default", true)
	var inf := info(name)
	var rate: float = fps if fps > 0.0 else float(inf.get("fps", 8))
	sf.set_animation_speed("default", rate)
	var n := frame_count(name)
	var tex := sheet(name)
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = region(name, i)
		sf.add_frame("default", at)
	_frames[key] = sf
	return sf

static func bullet_color(kind: String) -> Color:
	match kind:
		"base": return Color("#ffe86a")
		"fan": return Color("#ffd24a")
		"lightning": return Color("#a8f0ff")
		"plasma": return Color("#ff9ae0")
		"rhythm": return Color("#ffffff")
		"swarm": return Color("#c9a0ff")
		"orb": return Color("#ff5a7a")
		"needle": return Color("#ff8a4a")
		"spore": return Color("#a8ff8a")
		"laser": return Color("#ff5aff")
		"bomb": return Color("#ffb84a")
	return Color.WHITE
