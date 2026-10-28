extends Node
## Prüfwerkzeug: Ablauf am Levelende (Blütenstaub -> Evolution -> Ergebnis).
var fails: Array[String] = []
var checks := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  OK   %s" % what)
	else:
		fails.append(what)
		print("  FAIL %s" % what)

func _ready() -> void:
	await get_tree().process_frame
	var app := get_tree().root.get_node_or_null("App")
	await get_tree().create_timer(0.6).timeout
	app.clear_screens()
	app.mode = "campaign"
	Save.new_campaign("normal", 4242)
	Save.campaign.level = 1
	Save.campaign.nectar = 40
	Save.campaign.points = 0
	Save.save_campaign()
	app.run_level = 1
	app.on_level_complete({"level": 1, "score": 1200, "rank": "B", "hits": 3, "lives": 3})
	# Bannerphase abwarten, dann muss die Umrechnung kommen
	for i in range(240):
		await get_tree().process_frame
		if _screen_of(app, "nectar_convert_screen") != null:
			break
	var conv: Control = _screen_of(app, "nectar_convert_screen")
	_ok(conv != null, "Umrechnung erscheint am Levelende")
	_ok(int(Save.campaign.get("nectar", -1)) == 0, "Blütenstaub wird auf 0 gesetzt")
	_ok(int(Save.campaign.get("points", 0)) == 400, "40 Nektar geben 400 Punkte (%d)" % int(Save.campaign.get("points", 0)))
	if conv != null:
		conv._finish()
	for i in range(120):
		await get_tree().process_frame
		if _screen_of(app, "evolution_screen") != null:
			break
	var evo: Control = _screen_of(app, "evolution_screen")
	_ok(evo != null, "Danach kommt die Evolutionswahl")
	if evo != null:
		var offers: Array = (Save.campaign.get("pending", {}) as Dictionary).get("offers", [])
		_ok(offers.size() >= 1, "Es liegen drei Angebote bereit (%d)" % offers.size())
		var first = offers[0]
		var fid := String(first.get("id", "")) if first is Dictionary else String(first)
		app._confirm_evolution(fid)
	for i in range(120):
		await get_tree().process_frame
		if _screen_of(app, "level_result_screen") != null:
			break
	_ok(_screen_of(app, "level_result_screen") != null, "Abschlussbildschirm erscheint")
	print("ABLAUF: checks=%d fails=%d" % [checks, fails.size()])
	print("ABLAUF_OK" if fails.is_empty() else "ABLAUF_FAIL")
	get_tree().quit(0 if fails.is_empty() else 1)

func _screen_of(app, res_name: String):
	for s in app.screens:
		if is_instance_valid(s) and s.get_script() != null:
			if String((s.get_script() as Script).resource_path).contains(res_name):
				return s
	return null
