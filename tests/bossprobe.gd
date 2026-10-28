extends Node
## Prüft den weichen Phasenwechsel beim Boss:
## kein Sprung in der Position, keine verschwindenden Geschosse.

var fails: Array = []
var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Save.new_campaign("normal", 331177)
	Save.campaign.upgrades = {"base": 3}
	app.clear_screens()
	app._begin_level(1, 0)
	for i in range(14):
		await get_tree().process_frame
	var g = app.game
	if g == null:
		print("BOSS_FAILED: kein Level")
		get_tree().quit(1)
		return
	g.director.start_boss_now()
	for i in range(150):
		await get_tree().physics_frame
	var b = g.boss
	if b == null:
		fails.append("kein Boss")
		_finish()
		return
	# Boss in die erste Phase bringen und ein paar Geschosse erzeugen
	b.position = Vector2(760, 380)
	g.player.autofire = false
	g.player.position = Vector2(140, 500)
	b.attack_in_progress = false
	b.act_timer = 0.0
	for i in range(200):
		await get_tree().physics_frame
	var before_bullets: int = g.bullets.enemy_bullets.size()
	var pos_before: Vector2 = b.position
	var max_jump := 0.0
	# Phasenwechsel auslösen: Lebenspunkte unter die zweite Phasenschwelle drücken
	var phase_before: int = b.phase
	if phase_before + 1 >= b.phase_defs.size():
		fails.append("Boss hat keine weitere Phase (Phase %d)" % phase_before)
		_finish()
		return
	var threshold := float(b.phase_defs[phase_before + 1].get("hp", 0.7))
	b.hp = b.max_hp * (threshold + 0.01)
	b.take_damage(b.max_hp * 0.05)	# löst die Phasenprüfung aus
	# Direkt nach dem Wechsel darf sich die Lage nur wenig ändern.
	await get_tree().physics_frame
	var pos_after_switch: Vector2 = b.position
	var first_step := pos_after_switch.distance_to(pos_before)
	var last: Vector2 = pos_after_switch
	for i in range(90):
		await get_tree().physics_frame
		if is_instance_valid(b):
			max_jump = maxf(max_jump, b.position.distance_to(last))
			last = b.position
	if not is_instance_valid(b):
		fails.append("Boss verschwunden")
		_finish()
		return
	if b.phase == phase_before:
		fails.append("Phase wurde nicht gewechselt")
	if first_step > 25.0:
		fails.append("Boss springt beim Phasenwechsel (%.1f px im ersten Bild)" % first_step)
	if max_jump > 45.0:
		fails.append("Boss ruckt im Übergang (%.1f px in einem Bild)" % max_jump)
	if max_jump < 0.01:
		fails.append("Boss bewegt sich überhaupt nicht")
	# Geschosse der vorherigen Phase müssen weiterfliegen
	var after_bullets: int = g.bullets.enemy_bullets.size()
	if before_bullets >= 3 and after_bullets == 0:
		fails.append("Geschosse der vorherigen Phase wurden gelöscht (%d -> %d)"
			% [before_bullets, after_bullets])
	print("BOSS: Phase %d -> %d, erster Schritt %.1f px, größter Satz %.1f px, Geschosse %d -> %d, Pos %.0f/%.0f -> %.0f/%.0f"
		% [phase_before, b.phase, first_step, max_jump, before_bullets, after_bullets,
			pos_before.x, pos_before.y, b.position.x, b.position.y])
	_finish()

func _finish() -> void:
	for f in fails:
		print("BOSS_FEHLER: " + String(f))
	print("BOSS_OK" if fails.is_empty() else "BOSS_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)
