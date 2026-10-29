extends Node
## Agreed seams: real Boss damage/physics and Game defeated/reward/level completion.
var failures: Array[String] = []
var checks := 0

class CompletionSink:
	extends Node
	var hud: Node = null
	var endings: Array = []
	func on_level_complete(result: Dictionary) -> void:
		endings.append(result)

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	await get_tree().process_frame
	Save.new_campaign("normal", 18031)
	var g := Game.new()
	g.setup({"level": 10})
	g.started = false
	g._spawn_boss()
	var b := g.boss
	b.position = Vector2(700, 266)
	check(b.id == "core_organism", "actual Data level10 boss is core_organism")
	var signals := [0]
	b.defeated.connect(func(): signals[0] += 1)
	var sink := CompletionSink.new()
	g.app = sink
	var phase_signals: Array[int] = []
	b.phase_changed.connect(func(index: int): phase_signals.append(index))
	var hp_signals: Array = []
	b.hp_changed.connect(func(value: float, maximum: float): hp_signals.append([value, maximum]))
	var score_before := int(g.stats.score)
	var points_before := g.player.points
	for i in range(5):
		g.spawn_enemy_bullet(Vector2(500, 250), Vector2.LEFT * 100.0, 1, "ebullet_orb")
	check(not g.bullets.enemy_bullets.is_empty(), "real enemy bullet field is populated before first death")
	b.schedule(0.01, func(): failures.append("stale first-form attack executed"))
	b.take_damage(b.max_hp * 10.0)
	check(signals[0] == 0, "first-form HP0 does not emit final defeated")
	check(not b.dead and not b.is_queued_for_deletion(), "first form remains one living encounter")
	check(not g.level_over and int(g.stats.bosses) == 0, "first kill does not finish actual Game level10")
	check(int(g.stats.score) == score_before and g.player.points == points_before, "no reward before final form dies")
	check(b.timeline.is_empty(), "first-form attack timeline clears at resurrection")
	check(not b.vulnerable and b.invuln > 0.0, "resurrection telegraph is invulnerable")
	check(g.bullets.enemy_bullets.is_empty(), "real enemy bullets clear immediately before revival telegraph")
	check(b.trace_hit(b.position, b.position).is_empty(), "reviving body cannot hurt through contact alpha mask")
	check(sink.endings.is_empty(), "no ending callback before second form")
	# Real engine ticks, not skipping invulnerability/phase gates with one HP assignment.
	add_child(g)
	g.player.set_physics_process(false)
	g.player.autofire = false
	var before_revive := b.position
	b.take_damage(1.0e12)
	check(b.hp <= 0.0, "damage during revival cannot skip into final death")
	# R4: Scheinsieg mit Ruhephase – echte Laufzeit bis zur zweiten Form abwarten.
	for frame in range(int(b.REVIVE_TIME * 60.0) + 12):
		await get_tree().physics_frame
	check(is_instance_valid(b) and not b.dead, "boss survives the real staged resurrection without queuefree")
	check(not g.level_over and signals[0] == 0, "real revival runtime still does not finish level or emit defeated")
	check(b.max_hp > b.first_form_max_hp * 1.64 and b.max_hp < b.first_form_max_hp * 1.81,
		"reborn HP is1.65–1.8times already scaled initial maximum")
	check(b.phase_defs.size() == 3 and b.phase == 0, "second form has exactly three phases, starts at1of3")
	check(b.position.distance_to(before_revive) < 30.0, "resurrection preserves position softly")
	var old_tex := Art.frame_tex("boss_core", 0)
	var current_tex := b._texture(b.body)
	check(current_tex.get_size() != old_tex.get_size(), "new form changes silhouette composition beyond a recolor")
	check(phase_signals == [0], "new phase1 signal resets HUD phase count to1of3")
	check(hp_signals[-1][0] == b.hp and hp_signals[-1][1] == b.max_hp, "new full HP and maximum are emitted for HUD")
	check(g.bullets.enemy_bullets.is_empty(), "no first-form bullet survives into second form")
	await _wait_vulnerable(b)
	var silhouettes: Array = []
	for stage in range(3):
		check(b.phase == stage and b.phase_defs.size() == 3, "reborn stage%d remains exactly three phases" % (stage + 1))
		check(is_equal_approx(float(b.phase_defs[stage].hp), [1.0, 0.66, 0.33][stage]), "reborn stage%d uses specified independent HP gate" % (stage + 1))
		var baseline_interval := [1.15, 0.9, 0.6][stage] as float
		check(b.interval_now >= baseline_interval * 0.64 * 0.75 and b.interval_now <= baseline_interval * 0.64 * 0.85,
			"stage%d intervals retain level rate and add15–25percent pressure" % (stage + 1))
		silhouettes.append(_test_body(g, b, stage))
		_test_attack_admission(g, b, stage)
		if stage < 2:
			var gate := [0.66, 0.33][stage] as float
			var amount := b.hp - b.max_hp * (gate - 0.005)
			var pos := b.position
			b.take_damage(amount)
			check(b.phase == stage + 1 and b.hp > 0.0, "real damage crosses gate without HP0 shortcut")
			check(b.position.distance_to(pos) < 1.0, "phase gate does not teleport boss")
			check(b.timeline.is_empty(), "previous reborn combo timeline clears at phase gate")
			var hp_at_gate := b.hp
			b.take_damage(b.max_hp * 10.0)
			check(b.hp == hp_at_gate and not b.dead, "phase invulnerability cannot be bypassed by lethal damage")
			await _wait_vulnerable(b)
	check(silhouettes[0] != silhouettes[1] and silhouettes[1] != silhouettes[2], "all three phases have independently different body art")
	check(phase_signals == [0, 1, 2], "HUD gets exactly three ordered reborn phase signals")
	check(signals[0] == 0 and sink.endings.is_empty() and not g.level_over, "even third phase begins before any reward/ending")
	b.take_damage(b.max_hp * 10.0)
	check(signals[0] == 1 and b.dead and g.level_over, "second kill emits exactly one final defeated and finishes real Game")
	check(int(g.stats.bosses) == 1 and int(g.stats.score) == score_before + 8000,
		"real level10 rewards exactly one8000point boss reward")
	check(g.player.points == points_before + 8000 and sink.endings.size() == 1, "exactly one player reward and one ending callback")
	b.take_damage(b.max_hp * 10.0)
	check(signals[0] == 1 and int(g.stats.bosses) == 1 and sink.endings.size() == 1,
		"repeated lethal damage cannot duplicate reward or ending")
	g.free()
	sink.free()
	_test_other_bosses()
	_test_scaled_revival()
	_test_first_form_gates()
	_test_accessibility_and_freeze()
	await _test_rush()
	print("STINGFORGE_R2_FINAL checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	if failures.is_empty():
		print("STINGFORGE_R2_FINAL_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func _wait_vulnerable(b: Boss) -> void:
	var frames := 0
	while is_instance_valid(b) and b.invuln > 0.0 and frames < 100:
		await get_tree().physics_frame
		frames += 1
	check(frames < 100 and b.hp > 0.0 and b.vulnerable, "positive HP survives real phase gate invulnerability")

func _test_body(g: Game, b: Boss, stage: int) -> int:
	var sprite := b.body as AnimatedSprite2D
	check(sprite.sprite_frames.get_frame_count("default") == 2, "stage%d has two body AtlasFrames without manifest changes" % (stage + 1))
	sprite.stop()
	var hashes: Array[int] = []
	for frame in range(2):
		sprite.frame = frame
		var tex := sprite.sprite_frames.get_frame_texture("default", frame)
		var image := tex.get_image()
		if image.is_compressed():
			image.decompress()
		hashes.append(hash(image.get_data()))
		var samples: Array[Vector2] = []
		# Independently find real opaque crown and outer-wing pixels in delivered art.
		for region in [Rect2i(75, 0, 75, 34), Rect2i(0, 35, 54, 150)]:
			var found := false
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if image.get_pixel(x, y).a >= 0.8:
						samples.append(Vector2(x + 0.5, y + 0.5))
						found = true
						break
				if found:
					break
		check(samples.size() == 2, "stage%d frame%d visibly has a crown and additional outer wing" % [stage + 1, frame])
		for pixel in samples:
			var p := b.transform * sprite.transform * (pixel - Vector2(tex.get_size()) * 0.5)
			check(not b.trace_hit(p, p).is_empty(), "current crown/wing alpha is colliding, not cosmetic phantom")
			g.bullets.player_bullets.clear()
			var hp_before := b.hp
			g.bullets.spawn_player(p, Vector2.ZERO, 1.0, "bullet_base", {"r": 0.0})
			g._update_collisions()
			check(b.hp < hp_before, "actual Game bullet collision damages visible reborn crown/wing")
		var corner := b.transform * sprite.transform * (Vector2(0.5, 0.5) - Vector2(tex.get_size()) * 0.5)
		check(b.trace_hit(corner, corner).is_empty(), "transparent body-frame corner has no rectangle hitbox")
		# Rotation and current-frame alpha must be honored together.
		sprite.rotation = 0.29
		var pixel := samples[-1]
		var rotated := b.transform * sprite.transform * (pixel - Vector2(tex.get_size()) * 0.5)
		check(not b.trace_hit(rotated, rotated).is_empty(), "rotated current wing remains alpha-collidable")
		sprite.rotation = 0.0
		for y in [0.0, 700.0]:
			b.position.y = y
			b._physics_process(0.0)
			var rect := b._visual_bounds()
			check(b.position.y + rect.position.y >= App.PLAY_TOP and b.position.y + rect.end.y <= App.PLAY_BOTTOM,
				"all current opaque body pixels remain inside the HUD-free field")
		b.position = Vector2(700, 266)
	check(hashes[0] != hashes[1], "two animation poses are actually different")
	g.bullets.player_bullets.clear()
	sprite.play("default")
	return hashes[0]

func _test_attack_admission(g: Game, b: Boss, stage: int) -> void:
	# Exercise public scheduler/physics plus real central Game spawn and density/cap.
	b.timeline.clear()
	g.bullets.enemy_bullets.clear()
	b.invuln = 0.0
	b.phase_banner_t = 0.0
	b.act_timer = 0.0
	b.attack_in_progress = false
	b._physics_process(0.01)
	check(b.telegraph > 0.0 and g.bullets.enemy_bullets.is_empty(), "stage%d combo is announced before bullets fire" % (stage + 1))
	for frame in range(180):
		b._physics_process(1.0 / 60.0)
	# Die Schutzzone ist ebenfalls ein echter Angriff, feuert aber bewusst keine Geschosse.
	check(not g.bullets.enemy_bullets.is_empty() or not g.safe_zone.is_empty(), "stage%d executes a real scheduled new combo" % (stage + 1))
	g.safe_zone = {}
	check(g.bullets.enemy_bullets.size() <= 420, "reborn barrage respects unchanged enemy cap420")
	b.timeline.clear()
	b.attack_in_progress = false
	b.act_timer = 20.0
	g.bullets.enemy_bullets.clear()
	for difficulty in ["relaxed", "normal", "expert"]:
		g.difficulty = Data.DIFFICULTY[difficulty]
		for i in range(1000):
			g.spawn_enemy_bullet(Vector2(600, 266), Vector2.LEFT, 1, "ebullet_orb")
			if i == 4:
				check(g.bullets.enemy_bullets.size() == {"relaxed": 3, "normal": 4, "expert": 5}[difficulty], "reborn Game keeps cumulative 0.6/0.8/1.0 density for " + difficulty)
		check(g.bullets.enemy_bullets.size() == 420, "central enemy max420 survives1000requests in" + difficulty)
		g.bullets.enemy_bullets.clear()
	g.difficulty = Data.DIFFICULTY.normal

func _test_other_bosses() -> void:
	for level in range(1, 10):
		Save.new_campaign("normal", 18031)
		var g := Game.new()
		g.setup({"level": level})
		g.started = false
		g._spawn_boss()
		var b := g.boss
		var count := [0]
		b.defeated.connect(func(): count[0] += 1)
		var hp_before := b.max_hp
		if not b.twin_dead:
			# Mantidenpaar: zwei Lebensbalken, beide müssen fallen.
			b.take_damage(hp_before * 10.0, Vector2.ZERO, b.TWIN_PART)
			b.invuln = 0.0
		b.take_damage(hp_before * 10.0)
		check(b.dead and not b.reviving and b.encounter_form == 1 and count[0] == 1,
			"normal boss%d still finishes immediately in first form" % level)
		check(g.level_over and int(g.stats.bosses) == 1, "normal boss%d still ends real Game once" % level)
		g.free()

func _test_scaled_revival() -> void:
	for difficulty in ["relaxed", "normal", "expert"]:
		Save.new_campaign(difficulty, 18031)
		var g := Game.new()
		g.setup({"level": 10})
		g.started = false
		var base_scale := g._boss_hp_scale()
		g.player.upgrades = {"base": 1, "fan": 3, "lightning": 3, "plasma": 3}
		g.player.shop_levels = {"wave_amp": 3, "big_bullet": 3}
		g.player.apply_shop_changes()
		check(g._boss_hp_scale() > base_scale, "test build actually exercises power scaling in" + difficulty)
		g._spawn_boss()
		var b := g.boss
		var first_hp := b.max_hp
		check(first_hp > 0.0 and b.hp == first_hp, "initial scaled" + difficulty + "boss has positive full HP")
		b.take_damage(first_hp * 10.0)
		for frame in range(int(b.REVIVE_TIME * 60.0) + 8):
			b._physics_process(1.0 / 60.0)
		check(is_equal_approx(b.max_hp, first_hp * 1.75) and b.hp > 0.0,
			"reborn inherits already level/difficulty/power-scaled maxHP exactly once in" + difficulty)
		check(b.phase_defs.size() == 3 and not b.dead and not g.level_over, "no tick death or accidental fourth phase in" + difficulty)
		g.free()

func _test_first_form_gates() -> void:
	Save.new_campaign("normal", 18031)
	var g := Game.new()
	g.setup({"level": 10})
	g.started = false
	g._spawn_boss()
	var b := g.boss
	check(b.phase_defs.size() == 4, "first form retains original level10 threat/enrage phase count")
	for stage in range(1, 4):
		var target_hp := b.max_hp * (float(b.phase_defs[stage].hp) - 0.005)
		b.take_damage(b.hp - target_hp)
		check(b.phase == stage and b.hp > 0.0 and b.encounter_form == 1 and not b.reviving,
			"first form standard phase%d remains unchanged and positive HP" % (stage + 1))
		for frame in range(90):
			b._physics_process(1.0 / 60.0)
		check(b.hp > 0.0 and not b.dead and not g.level_over, "first-form gate survives tick, not artificial HP0 death")
	b.take_damage(b.max_hp * 10.0)
	check(b.reviving and not g.level_over, "after all original phases, actual first death still revives")
	g.free()

func _test_accessibility_and_freeze() -> void:
	var old_reduce: bool = Save.g("access.reduce_effects", false)
	var old_flashes: bool = Save.g("graphics.flashes", true)
	for config in [[true, true], [false, false]]:
		Save.set_g("access.reduce_effects", config[0])
		Save.set_g("graphics.flashes", config[1])
		Save.new_campaign("normal", 18031)
		var g := Game.new()
		g.setup({"level": 10})
		g.started = false
		g._spawn_boss()
		var b := g.boss
		b.position = Vector2(700, 140)
		b.take_damage(b.max_hp * 10.0)
		var last := b.position
		var max_step := 0.0
		for frame in range(24):
			b._physics_process(1.0 / 60.0)
			max_step = maxf(max_step, b.position.distance_to(last))
			last = b.position
		check(b.reborn_visual.reduced and b.body.modulate.r <= 1.0, "reduce_effects or flashoff produces calm local revival, not flashing body")
		var elapsed := b.revive_t
		g.resume_delay = 1.0
		b._physics_process(1.0)
		check(b.revive_t == elapsed and b.reviving, "world freeze suspends revival timer and timeline")
		g.resume_delay = 0.0
		# R4: längere Inszenierung (Scheinsieg, Ruhe, Neubildung) statt 1,65 s.
		for frame in range(int(b.REVIVE_TIME * 60.0) + 20):
			if b.encounter_form == 2:
				break
			b._physics_process(1.0 / 60.0)
			max_step = maxf(max_step, b.position.distance_to(last))
			last = b.position
		check(b.encounter_form == 2 and max_step <= 3.0, "edge resurrection makes room softly, no body teleport")
		b.hit_flash = 0.1
		b._physics_process(0.01)
		check(b.body.modulate == Color.WHITE, "reduce_effects or flashoff suppresses new-form hit flashes")
		g.free()
	Save.set_g("access.reduce_effects", old_reduce)
	Save.set_g("graphics.flashes", old_flashes)

func _test_rush() -> void:
	Save.new_campaign("normal", 18031)
	var g := Game.new()
	g.setup({"level": 10, "mode": "rush"})
	g.started = false
	g.boss.free()
	g.boss = null
	g.rush_index = 9
	g._spawn_rush_boss()
	var b := g.boss
	var signals := [0]
	b.defeated.connect(func(): signals[0] += 1)
	check(b.id == "core_organism" and b.level_index == 10, "actual final Rush spawn selects same last encounter")
	b.take_damage(b.max_hp * 10.0)
	check(g.rush_index == 9 and not g.level_over and signals[0] == 0 and g.boss == b,
		"first-form Rush kill neither advances sequence nor frees boss")
	add_child(g)
	g.player.set_physics_process(false)
	g.player.autofire = false
	for frame in range(int(b.REVIVE_TIME * 60.0) + 12):
		await get_tree().physics_frame
	await _wait_vulnerable(b)
	check(b.encounter_form == 2 and b.phase_defs.size() == 3 and b.hp > 0.0,
		"actual Rush physics completes two-form revival")
	b.take_damage(b.max_hp * 10.0)
	check(g.level_over and g.rush_index == 10 and int(g.stats.bosses) == 1 and signals[0] == 1,
		"only second Rush kill ends sequence and rewards exactly one boss")
	g.free()
