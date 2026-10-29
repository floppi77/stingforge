extends RefCounted
## Pixelflaggen für die Sprachwahl (Deutschland, USA), zur Laufzeit gezeichnet.

const W := 26
const H := 14

static var _cache: Dictionary = {}

static func texture(lang: String) -> Texture2D:
	if _cache.has(lang):
		return _cache[lang]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	if lang == "en":
		_usa(img)
	else:
		_germany(img)
	# Dunkler Pixelrahmen wie bei den übrigen UI-Grafiken.
	for x in range(W):
		img.set_pixel(x, 0, Color("#11101f"))
		img.set_pixel(x, H - 1, Color("#11101f"))
	for y in range(H):
		img.set_pixel(0, y, Color("#11101f"))
		img.set_pixel(W - 1, y, Color("#11101f"))
	var tex := ImageTexture.create_from_image(img)
	_cache[lang] = tex
	return tex

static func _germany(img: Image) -> void:
	var cols := [Color("#141414"), Color("#d21f1f"), Color("#f2c21b")]
	for y in range(H):
		var band := clampi(int(float(y) / float(H) * 3.0), 0, 2)
		for x in range(W):
			img.set_pixel(x, y, cols[band])

static func _usa(img: Image) -> void:
	# Sieben rote und sechs weiße Streifen, auf 14 px Höhe verdichtet.
	for y in range(H):
		var red := int(float(y) / float(H) * 13.0) % 2 == 0
		for x in range(W):
			img.set_pixel(x, y, Color("#c8102e") if red else Color("#f4f4f4"))
	for y in range(8):
		for x in range(12):
			img.set_pixel(x, y, Color("#1d2f6f"))
	for y in range(1, 8, 2):
		for x in range(1, 12, 2):
			if (x + y) % 4 == 0 or (x + y) % 4 == 2:
				img.set_pixel(x, y, Color("#f4f4f4"))
