extends Node
## Prüft Game Over: Zähler, Reset der taktischen Upgrades, kein Weiter nach dem
## dritten Game Over.

var app: Node
var fails: Array = []

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	await _run()
	for f in fails:
		print("GAMEOVER_FEHLER: " + String(f))
	print("GAMEOVER_OK" if fails.is_empty() else "GAMEOVER_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _run() -> void:
	Save.new_campaign("normal", 991122)
	# Privater Levelstart ersetzt nicht die öffentliche Kampagnen-Moduswahl.
	app.mode = "campaign"
	# Gekauftes und Erspieltes, das den Reset überleben muss
	Save.campaign.shop = {"orbit": 2, "fire_rate": 3}
	Save.campaign.evolutions = [{"id": "pierce1", "level": 1}]
	Save.save_campaign()
	app.clear_screens()
	app._begin_level(1, 0)
	for i in range(14):
		await get_tree().process_frame
	var g = app.game
	var p = g.player
	# Taktische Upgrades mitten im Level
	p.upgrades = {"base": 3, "fan": 2, "lightning": 1, "plasma": 0, "companion": 1,
		"bombs": 1, "shield": 1, "speed": 2}
	p.weapon = "fan"
	p.nectar = 40
	p.speed_level = 2
	_ok(p.shop_levels.has("orbit"), "Werkstatt-Stufen sind gesetzt")
	# --- Erster Tod
	await _die(g)
	_ok(app.run_deaths() == 1, "erster Game Over gezählt (%d)" % app.run_deaths())
	_ok(app.screens.size() == 1, "Game-Over-Bildschirm ist offen")
	var scr = app.screens[0]
	_ok(int(scr.attempts_left) == 2, "zwei weitere Versuche (%d)" % int(scr.attempts_left))
	# --- Weiter
	app.continue_after_death()
	for i in range(8):
		await get_tree().process_frame
	var p2 = app.game.player
	for id in ["fan", "lightning", "plasma", "companion", "bombs", "shield", "speed", "repair"]:
		_ok(int(p2.upgrades.get(id, -1)) == 0, "Tod setzt taktischen Kauf exakt auf 0: " + id)
	_ok(int(p2.speed_level) == 0, "Tod setzt aktives Flugtempo auf 0")
	_ok(not p2.shield_active() and p2.shield_max == 0 and p2.shield_hits == 0,
		"Tod entfernt Schildfreischaltung und alle Ladungen")
	_ok(int(p2.upgrades.get("base", 0)) == 1, "Grundwaffe wieder Stufe 1")
	_ok(String(p2.weapon) == "base", "Waffe zurück auf Grundform (%s)" % p2.weapon)
	_ok(p2.nectar == 0, "Nektar geleert (%d)" % p2.nectar)
	_ok(p2.shop_mods.has("orbit_r"), "Werkstatt-Mods bleiben erhalten")
	_ok(p2.evolutions.size() >= 1, "Evolutionen bleiben erhalten")
	# --- Zweiter Tod
	await _die(app.game)
	_ok(app.run_deaths() == 2, "zweiter Game Over gezählt (%d)" % app.run_deaths())
	app.continue_after_death()
	for i in range(8):
		await get_tree().process_frame
	# --- Dritter Tod: kein Weiter mehr
	await _die(app.game)
	_ok(app.run_deaths() == 3, "dritter Game Over gezählt (%d)" % app.run_deaths())
	var scr2 = app.screens[0]
	_ok(int(scr2.attempts_left) == 0, "kein Weiter mehr (%d)" % int(scr2.attempts_left))
	var has_continue := false
	for it in scr2.items:
		if String((it as Dictionary).get("id", "")) == "continue":
			has_continue = true
	_ok(not has_continue, "Bildschirm bietet keinen Weiter-Eintrag")
	# --- Run beenden
	app.abandon_run()
	for i in range(10):
		await get_tree().process_frame
	_ok(not Save.active_campaign, "Kampagne nach Run-Ende gelöscht")
	_ok(not app.is_in_game(), "zurück im Menü")

## Spieler sterben lassen und den Game-Over-Bildschirm abwarten.
func _die(g) -> void:
	app.game.player.iframes = 0.0
	app.game.player.hp = 1
	app.game.player.take_damage(99, Vector2.ZERO)
	if not app.game.frozen_by_death:
		app.game._on_player_died()
	app.game.dead_timer = 0.0
	for i in range(240):
		await get_tree().process_frame
		if app.screens.size() > 0:
			return
	print("  Hinweis: kein Game-Over-Bildschirm erschienen")
