extends Node
## Prüft Abspann und Boss-Rush (Freischaltung, zehn Bosse, Abschluss).

var fails: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Engine.time_scale = 6.0
	# 1) Abspann schaltet Boss-Rush frei
	Save.profile.boss_rush_unlocked = false
	app.clear_screens()
	app.push_screen("res://scripts/screens/ending_screen.gd", {})
	await get_tree().create_timer(0.5, false).timeout
	if not bool(Save.profile.get("boss_rush_unlocked", false)):
		fails.append("Abspann schaltet Boss-Rush nicht frei")
	# 2) Boss-Rush starten: nach dem Abspann sind alle zehn Bosse des Runs besiegt.
	app.clear_screens()
	Save.new_campaign("normal", 1)
	Save.campaign.completed = true
	for lv in range(1, 11):
		Save.campaign.level_stats[str(lv)] = {}
	app.start_boss_rush()
	var g = null
	for i in range(900):
		if app.game != null and is_instance_valid(app.game):
			g = app.game
			break
		await get_tree().process_frame
	if g == null:
		fails.append("Boss-Rush startet nicht")
		_finish()
		return
	if String(g.mode) != "rush":
		fails.append("Boss-Rush läuft im Modus " + String(g.mode))
	g.player.autofire = true
	g.player.max_hp = 9
	var killed := 0
	var guard := 0
	var final_revival_seen := false
	var final_second_seen := false
	while not g.level_over and guard < 6000:
		guard += 1
		if g.boss != null and is_instance_valid(g.boss):
			var b = g.boss
			if String(b.id) == "core_organism" and b.reviving:
				final_revival_seen = true
				if g.level_over or b.dead:
					fails.append("Finaler Rush-Boss meldet Sieg beim ersten Tod")
			elif String(b.id) == "core_organism" and b.encounter_form == 2 and not final_second_seen:
				final_second_seen = true
				if not is_equal_approx(b.max_hp, b.first_form_max_hp * 1.75) or b.phase_defs.size() != 3:
					fails.append("Finale Rush-Form hat nicht exakt1.75xHP/3Phasen")
			if not b.reviving:
				b.invuln = 0.0
				b.vulnerable = true
				b.take_damage(500.0)
		elif g.rush_between:
			g.rush_supply_t = 0.0
		await get_tree().process_frame
		killed = int(g.rush_index)
	if not g.level_over:
		fails.append("Boss-Rush endet nicht (Bosse besiegt: %d)" % killed)
	if not final_revival_seen or not final_second_seen:
		fails.append("Finaler Rush-Boss muss natürlich wiederkehren und erneut besiegt werden")
	print("ENDING: bosse=%d level_over=%s final_revival=%s final_second=%s" % [killed, str(g.level_over), str(final_revival_seen), str(final_second_seen)])
	_finish()

func _finish() -> void:
	Engine.time_scale = 1.0
	print("ENDING: fails=%d" % fails.size())
	for f in fails:
		print("  FAIL " + f)
	if fails.is_empty():
		print("ENDING_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
