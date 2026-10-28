extends Node
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func game() -> Game:
	var g := Game.new()
	g.setup({"level": 1})
	g.started = false
	return g

func shot(g: Game, from: Vector2, to: Vector2, radius: float = 0.0, pierce: int = 0) -> Dictionary:
	var b := g.bullets.spawn_player(to, (to - from) * 60.0, 10.0, "bullet_base", {"r": radius, "pierce": pierce})
	b["prev_p"] = from
	return b

func opaque_far(tex: Texture2D) -> Vector2:
	var image := tex.get_image()
	var best := Vector2.ZERO
	var dist := -1.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(image.get_size()) * 0.5
			if image.get_pixel(x, y).a >= 0.5 and p.length_squared() > dist:
				best = p
				dist = p.length_squared()
	return best

func _ready() -> void:
	await get_tree().process_frame
	Save.new_campaign("normal", 18031)
	for id in Data.bosses:
		var g := game()
		var b := Boss.new()
		b.setup(id)
		b.position = Vector2(620, 270)
		g.add_child(b)
		g.boss = b
		var sprite := b.body as AnimatedSprite2D
		sprite.stop()
		for frame in range(Art.frame_count(String(b.def.sprite))):
			sprite.frame = frame
			var tex := sprite.sprite_frames.get_frame_texture("default", frame)
			var outer := opaque_far(tex)
			g.bullets.player_bullets.clear()
			var hp := b.hp
			shot(g, b.position + outer, b.position + outer)
			g._update_collisions()
			check(b.hp < hp, "%s Frame%d sichtbarer Außenkörper/Flügel trifft (Distanz%.1f)" % [id, frame, outer.length()])
			# Transparente Ecken dürfen keine Rechteck-Hitbox werden.
			hp = b.hp
			g.bullets.player_bullets.clear()
			var corner := b.position + Vector2(tex.get_size()) * 0.5 - Vector2(0.5, 0.5)
			shot(g, corner, corner)
			g._update_collisions()
			check(is_equal_approx(b.hp, hp), "%s Frame%d transparente Ecke ist ungefährlich" % [id, frame])
			# Finde unabhängig aus dem Bild die erste durchsichtige Stelle im alten Kreis.
			var image := tex.get_image()
			var tested_hole := false
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var p := Vector2(x + 0.5, y + 0.5) - Vector2(image.get_size()) * 0.5
					if p.length() < 54.0 and image.get_pixel(x, y).a < 0.05:
						g.bullets.player_bullets.clear()
						hp = b.hp
						shot(g, b.position + p, b.position + p)
						g._update_collisions()
						check(is_equal_approx(b.hp, hp), "%s Frame%d transparentes Loch im alten Kreis" % [id, frame])
						tested_hole = true
						break
				if tested_hole:
					break
		# Hochgeschwindigkeitsdurchquerung aus allen Richtungen: beide Endpunkte außen.
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized()]:
			g.bullets.player_bullets.clear()
			var hp := b.hp
			shot(g, b.position - dir * 240.0, b.position + dir * 240.0)
			g._update_collisions()
			check(b.hp < hp, "%s echtes voriges Segment aus%s trifft" % [id, dir])
		# Derselbe durchdringende Schuss darf Boss/Flügel/Module zusammen nur einmal treffen.
		g.bullets.player_bullets.clear()
		shot(g, b.position - Vector2(200, 0), b.position + Vector2(200, 0), 2.0, 99)
		g._update_collisions()
		var hp_after := b.hp
		g._update_collisions()
		check(is_equal_approx(b.hp, hp_after), id + " kein mehrfacher Treffer desselben Bullets")
		# Kontaktverletzung nutzt die sichtbare Körperkante statt fehlendem Kontaktpfad.
		g.bullets.player_bullets.clear()
		g.player.position = b.position + opaque_far(sprite.sprite_frames.get_frame_texture("default", sprite.frame))
		g.player.iframes = 0.0
		g.player.shield_hits = 0
		var player_hp := g.player.hp
		g._update_collisions()
		check(g.player.hp == player_hp - 1, id + " sichtbarer Körper verursacht Kontaktverletzung")
		# Zeitplan-Teleports werden nach dem Timeline-Tick innerhalb des Feldes gehalten.
		for y in [0.0, 700.0]:
			b.schedule(0.0, func(): b.position.y = y)
			b._physics_process(0.0)
			var all_inside := sprite_inside(b.body, App.PLAY_TOP, App.PLAY_BOTTOM)
			for part in b.parts:
				if not part.dead:
					all_inside = all_inside and sprite_inside(part.node, App.PLAY_TOP, App.PLAY_BOTTOM)
			check(all_inside, id + " Körper und Module bleiben einschließlich Timeline unterHeader")
		g.free()
	_test_modules()
	_benchmark_masks()
	# Segment darf auch bei normalen Gegnern NICHT in die Zukunft schauen.
	var g := game()
	var e: Enemy = g.spawn_enemy("beetle_grunt", Vector2(600, 270))
	e.hp = 1000.0
	shot(g, Vector2(300, 270), Vector2(650, 270))
	g._update_collisions()
	check(e.hp < 1000.0, "normale Gegner: bereits durchflogenes Segment trifft")
	g.bullets.player_bullets.clear()
	e.hp = 1000.0
	shot(g, Vector2(540, 270), Vector2(560, 270))
	g._update_collisions()
	check(is_equal_approx(e.hp, 1000.0), "normale Gegner: kein Treffer vor Erreichen der Oberfläche")
	g.free()
	print("STINGFORGE_WORLD_BOSS checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	if failures.is_empty():
		print("STINGFORGE_WORLD_BOSS_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_modules() -> void:
	for id in ["fungus_mind", "harvester"]:
		var g := game()
		g.boss = Boss.new()
		g.boss.setup(id)
		g.boss.position = Vector2(620, 270)
		g.add_child(g.boss)
		g.boss._move(0.0)
		var part: Dictionary = g.boss.parts[2]
		var sprite := part.node as Sprite2D
		var image := sprite.texture.get_image()
		var pixel := Vector2.ZERO
		var found := false
		for x in range(image.get_width()):
			for y in range(image.get_height()):
				if image.get_pixel(x, y).a >= 0.5:
					pixel = Vector2(x + 0.5, y + 0.5) - Vector2(image.get_size()) * 0.5
					found = true
					break
			if found:
				break
		var p := g.boss.position + sprite.position + pixel
		var hp := float(part.hp)
		var first_hp := float(g.boss.parts[0].hp)
		shot(g, p, p)
		g._update_collisions()
		check(float(part.hp) < hp and is_equal_approx(float(g.boss.parts[0].hp), first_hp), id + " äußerer Modultreffer beschädigt genau das sichtbare Modul")
		g.bullets.player_bullets.clear()
		g.player.position = p
		g.player.iframes = 0
		g.player.shield_hits = 0
		var player_hp := g.player.hp
		g._update_collisions()
		check(g.player.hp == player_hp - 1, id + " äußeres Modul verursacht Kontaktverletzung")
		g.player.position = Vector2(160, 270)
		part.dead = true
		hp = g.boss.hp
		shot(g, p, p)
		g._update_collisions()
		check(is_equal_approx(g.boss.hp, hp), id + " zerstörtes Modul besitzt keine unsichtbare Trefferzone")
		# Die gleiche sichtbare Körperstelle bleibt nach Drehung treffbar.
		g.bullets.player_bullets.clear()
		g.boss.body.rotation = 0.37
		p = g.boss.position + opaque_far(Art.frame_tex(String(g.boss.def.sprite))).rotated(0.37)
		hp = g.boss.hp
		shot(g, p, p)
		g._update_collisions()
		check(g.boss.hp < hp, id + " rotierter Körper stimmt mit Trefferform überein")
		g.free()

func _benchmark_masks() -> void:
	var maximum := 0.0
	for id in Data.bosses:
		var b := Boss.new()
		b.setup(id)
		b.position = Vector2(620, 270)
		# Warmup: Bild-/Maskenaufbau nicht in die laufenden Frames mischen.
		b.trace_hit(Vector2(500, 270), Vector2(700, 270), 3.0)
		var start := Time.get_ticks_usec()
		for frame in range(30):
			for i in range(320):
				var p := Vector2(480 + i % 140, 100 + (i * 17) % 340)
				b.trace_hit(p, p + Vector2(14, 2), 3.0)
		var average := float(Time.get_ticks_usec() - start) / 30000.0
		maximum = maxf(maximum, average)
		print("MASK_PERF %s 320Projektile=%.3fms/Frame" % [id, average])
		b.free()
	print("MASK_PERF_MAX_320=%.3fms (CPU, kein Render-FPS-Versprechen)" % maximum)

func sprite_inside(node: Node2D, top: float, bottom: float) -> bool:
	var tex: Texture2D = (node as AnimatedSprite2D).sprite_frames.get_frame_texture("default", (node as AnimatedSprite2D).frame) if node is AnimatedSprite2D else (node as Sprite2D).texture
	var half := Vector2(tex.get_size()) * 0.5
	var image := tex.get_image()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.2:
				continue
			var p: Vector2 = (node.get_parent() as Node2D).transform * (node.transform * (Vector2(x + 0.5, y + 0.5) - half))
			if p.y < top - 0.01 or p.y > bottom + 0.01:
				return false
	return true
