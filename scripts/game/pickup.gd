class_name Pickup
extends Node2D
## Sammelobjekte: Nektarblüten, Herzen, Bomben.

var kind: String = "nectar"
var value: int = 1
var vel: Vector2 = Vector2(-60, 0)
var magnet := false
var sprite: Sprite2D
var age := 0.0
var collected := false

func setup(p_kind: String, pos: Vector2, p_value: int = 1) -> void:
	kind = p_kind
	value = p_value
	position = pos
	sprite = Sprite2D.new()
	match kind:
		"heart":
			sprite.texture = Art.frame_tex("heart", 0)
		"blossom":
			sprite.texture = Art.frame_tex("blossom", 0)
		_:
			sprite.texture = Art.frame_tex("nectar", 0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 7
	# Weiche Glorie hinter dem Objekt: lässt Nektar leuchten und trennt ihn
	# optisch von den (kalt gefärbten) Geschossen.
	if bool(Save.g("graphics.lighting", true)) and ResourceLoader.exists("res://assets/fx/glow.png"):
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/fx/glow.png")
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.z_index = 6
		glow.scale = Vector2(0.55, 0.55)
		glow.modulate = _glow_color()
		glow.name = "Glow"
		add_child(glow)
	add_child(sprite)
	vel = Vector2(-70.0, randf_range(-18.0, 18.0))

func _glow_color() -> Color:
	match kind:
		"heart":
			return Color(1.0, 0.45, 0.5, 0.35)
		"blossom":
			return Color(1.0, 0.72, 0.95, 0.32)
		_:
			return Color(1.0, 0.84, 0.35, 0.34)

func _physics_process(delta: float) -> void:
	if collected:
		return
	var g := get_parent()
	if g != null and g.has_method("is_play_frozen") and g.is_play_frozen():
		return
	age += delta
	var target: Vector2 = g.player_position() if g != null else Vector2(160, 270)
	var dist := position.distance_to(target)
	var magnet_radius := 70.0
	if g != null and g.has_method("magnet_radius"):
		magnet_radius = g.magnet_radius()
	if dist < magnet_radius:
		var dir: Vector2 = (target - position).normalized()
		vel = vel.lerp(dir * 420.0, clampf(delta * 6.0, 0.0, 1.0))
	position += vel * delta
	sprite.rotation = sin(age * 2.4) * 0.25
	sprite.position.y = sin(age * 3.0) * 2.0
	if position.x < -30 or position.y < -30 or position.y > 570:
		queue_free()
