extends Node2D
## Kontrollierte echte Fensterzeichnung; keine Grafikimporte und kein HUD-Eingriff.
var world: Game

func _ready() -> void:
	await get_tree().process_frame
	App.clear_screens()
	Save.new_campaign("normal", 18031)
	world = Game.new()
	add_child(world)
	world.setup({"level": 10})
	world.started = false
	world.player.set_physics_process(false)
	world.player.position = Vector2(175, 270)
	world._on_hazard("gravity_field", {})
	world.fx.add_hazard({"kind": "reflect_panel", "p": Vector2(480, 270), "w": 70.0, "h": 160.0,
		"t": 0.0, "life": 6.0, "max_life": 6.0, "warn": 1.0})
	var glass: Enemy = world.spawn_enemy("glass_drone", Vector2(670, 210))
	glass.set_physics_process(false)
	var metal: Enemy = world.spawn_enemy("piston_drone", Vector2(790, 350))
	metal.set_physics_process(false)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var title := Label.new()
	title.text = "WORLD R2   |   Gravitation: Feldlinien abwärts   |   Glas: 4 Warnpulse / 1 s"
	title.position = Vector2(24, 16)
	overlay.add_child(title)
	var captures: Array = []
	for phase in range(8):
		captures.append({"at": float(phase) * 0.125 + 0.04,
			"name": "pulse" if phase == 0 else ("pause" if phase == 1 else ""), "on": phase % 2 == 0})
	# R5: aktives Glas zeigt bewusst einen hellen Rand (deutlich sichtbar).
	captures.append({"at": 1.06, "name": "active", "on": true})
	var failures := 0
	for shot in captures:
		world.fx.reset()
		world.fx.add_hazard({"kind": "gravity_field", "p": Vector2.ZERO, "t": float(shot.at), "life": 3.0, "max_life": 3.4})
		world.fx.add_hazard({"kind": "reflect_panel", "p": Vector2(480, 270), "w": 70.0, "h": 160.0,
			"t": float(shot.at) - 0.04, "life": 6.0, "max_life": 6.0, "warn": 1.0})
		world.fx.hit_spark(glass.position + Vector2(-12, 0), Color(0.55, 0.88, 1.0))
		world.fx.hit_spark(metal.position + Vector2(-12, 0), Color(0.72, 0.82, 0.92))
		world.fx.update(0.04)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var pixel := image.get_pixel(roundi(445.0 / 960.0 * float(image.get_width())), roundi(270.0 / 540.0 * float(image.get_height())))
		var lit := pixel.g > 0.7 and pixel.b > 0.7 and pixel.r < 0.6
		var valid := lit == bool(shot.on)
		if not valid:
			failures += 1
		print("WORLD_VISUAL_STATE at=", shot.at, " expected_lit=", shot.on, " pixel_ok=", valid)
		if not String(shot.name).is_empty():
			var path := "res://build/stingforge-r2-world-visual-%s.png" % String(shot.name)
			var error := image.save_png(path)
			print("WORLD_VISUAL ", path, " save_error=", error)
			if error != OK:
				failures += 1
	await get_tree().create_timer(0.10).timeout
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	print("WORLD_VISUAL checks=9 failures=", failures)
	if failures == 0:
		print("STINGFORGE_R2_WORLD_VISUAL_OK")
	get_tree().quit(0 if failures == 0 else 1)
