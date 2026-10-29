extends Node
## Spielt die gesamte Kampagne automatisch durch: alle zehn Level, alle Bosse,
## jede Evolutionsentscheidung, Abspann. Prüft dabei Fortschritt und Speicherstand.

var fails: Array = []
var evolutions_seen: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	app.clear_screens()
	Save.new_campaign("normal", 987654)
	Save.campaign.start_talent = "pierce1"
	Engine.time_scale = 4.0
	for lv in range(1, 11):
		await _play_level(app, lv)
		if not fails.is_empty() and fails.size() > 6:
			break
	Engine.time_scale = 1.0
	print("CAMPAIGN: evolutions=%d level=%d completed=%s" % [
		evolutions_seen.size(), int(Save.campaign.get("level", 0)),
		str(Save.campaign.get("completed", false))])
	print("CAMPAIGN: freigeschaltet=%d rush=%s" % [
		(Save.profile.unlocked_evolutions as Array).size(), str(Save.profile.get("boss_rush_unlocked", false))])
	for f in fails:
		print("  FAIL " + f)
	if fails.is_empty():
		print("CAMPAIGN_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _fail(msg: String) -> void:
	fails.append(msg)

func _play_level(app, lv: int) -> void:
	# Direkt ins Level (ohne Zwischensequenz), damit der Test schnell bleibt.
	app.clear_screens()
	Save.campaign.level = lv
	Save.campaign.checkpoint = 0
	app._begin_level(lv, 0)
	var g = null
	for i in range(900):
		if app.game != null and is_instance_valid(app.game):
			g = app.game
			break
		await get_tree().process_frame
	if g == null:
		_fail("Level %d: Spiel startet nicht" % lv)
		return
	var p = g.player
	p.autofire = true
	p.max_hp = 9
	p.hp = 9
	# Boss sofort erzwingen und besiegen
	g.director.start_boss_now()
	var waited := 0.0
	while (g.boss == null or not is_instance_valid(g.boss)) and waited < 20.0:
		await get_tree().create_timer(0.1, false).timeout
		waited += 0.1
		if not is_instance_valid(g):
			_fail("Level %d: Spiel endet vor dem Boss" % lv)
			return
	if g.boss == null or not is_instance_valid(g.boss):
		_fail("Level %d: Boss erscheint nicht" % lv)
		return
	var names := []
	var guard := 0
	var final_revival_seen := false
	var final_second_seen := false
	var first_max_hp: float = g.boss.max_hp
	while not g.level_over and guard < 4000:
		if g.boss != null and is_instance_valid(g.boss):
			var b = g.boss
			var bname := String(b.id)
			if not names.has(bname):
				names.append(bname)
			if bname == "core_organism" and b.reviving:
				# Reale Physik lässt die1.65s Häutung vergehen, keine direkte Zustandsmutation.
				final_revival_seen = true
				if b.dead or g.level_over:
					_fail("Level10: erster Tod darf keinen Sieg auslösen")
			elif bname == "core_organism" and b.encounter_form == 2 and not final_second_seen:
				final_second_seen = true
				if not is_equal_approx(b.max_hp, first_max_hp * 1.75) or b.phase_defs.size() != 3:
					_fail("Level10: zweite Form braucht exakt1.75xHP und3Phasen")
			if not b.reviving:
				b.invuln = 0.0
				b.vulnerable = true
				b.take_damage(400.0, Vector2.ZERO)
		await get_tree().process_frame
		guard += 1
	if lv == 10 and (not final_revival_seen or not final_second_seen):
		_fail("Level10: beide Formen müssen über natürlichen Übergang besiegt werden")
	if not g.level_over:
		_fail("Level %d: Boss lässt sich nicht besiegen (%d Bilder)" % [lv, guard])
		return
	if lv == 10:
		# Nach dem letzten Boss keine Evolutionswahl: Wertung, danach das Abspann-Level.
		var result = null
		for i in range(600):
			if app.screens.size() > 0:
				var top = app.screens[app.screens.size() - 1]
				if top != null and is_instance_valid(top) and top.get_script() != null:
					var path := String(top.get_script().resource_path)
					if path.ends_with("evolution_screen.gd"):
						_fail("Level 10: Evolutionsangebot nach dem letzten Boss")
						return
					if path.ends_with("level_result_screen.gd"):
						result = top
						break
			await get_tree().process_frame
		if result == null:
			_fail("Level 10: keine Wertung nach dem letzten Boss")
			return
		if not (Save.campaign.get("rewarded_levels", []) as Array).has(lv) or not bool(Save.campaign.get("completed", false)):
			_fail("Level 10: Run nicht abgeschlossen")
		print("CAMPAIGN level %d ok boss=%s ohne Evolutionswahl" % [lv, str(names)])
		return
	# Evolutionsbildschirm abwarten und erste Wahl nehmen
	var ev = null
	for i in range(600):
		if app.screens.size() > 0:
			var top = app.screens[app.screens.size() - 1]
			if top != null and is_instance_valid(top) and top.get_script() != null \
					and String(top.get_script().resource_path).ends_with("evolution_screen.gd"):
				ev = top
				break
		await get_tree().process_frame
	if ev == null:
		_fail("Level %d: kein Evolutionsangebot" % lv)
		return
	if (ev.offers as Array).size() != 3:
		_fail("Level %d: Angebot hat %d Einträge" % [lv, (ev.offers as Array).size()])
	var pick := String(ev.offers[0])
	ev.on_activate(0)
	await get_tree().create_timer(0.4, false).timeout
	evolutions_seen.append(pick)
	if int(Save.campaign.get("level", 0)) != lv:
		_fail("Level %d: Kampagnenstand steht auf %d" % [lv, int(Save.campaign.get("level", 0))])
	if not (Save.campaign.get("rewarded_levels", []) as Array).has(lv):
		_fail("Level %d: Belohnung nicht vermerkt" % lv)
	if lv < 10:
		# Ergebnisbildschirm wegklicken und Levelwechsel prüfen
		if app.screens.size() > 0:
			var res = app.screens[app.screens.size() - 1]
			if res != null and is_instance_valid(res) and res.has_method("on_activate"):
				res.on_activate(0)
		await get_tree().create_timer(0.5, false).timeout
	print("CAMPAIGN level %d ok boss=%s evo=%s" % [lv, str(names), pick])
