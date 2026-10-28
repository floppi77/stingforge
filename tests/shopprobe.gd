extends Node
## Prüft Werkstatt (Kauf, Vorbedingungen, Preise), Debugmenü (F4),
## Bossankündigung und die Plasmawaffe – ohne Fenster.

var fails: Array = []
var app: Node

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	_check_price_balance()
	_check_shop_data()
	await _check_shop_screen()
	await _check_effects()
	await _check_boss_intro()
	await _check_debug_menu()
	await _check_plasma()
	await _check_real_key()
	await _check_flow()
	if fails.is_empty():
		print("SHOP_OK")
		get_tree().quit(0)
	else:
		for f in fails:
			print("SHOP_FEHLER: ", f)
		print("SHOP_FAILED")
		get_tree().quit(1)

func _check_price_balance() -> void:
	# Rechnerische Ausbeute eines vollen Durchlaufs (aus den Leveldaten):
	# rund 524.000 Punkte bei perfektem Spiel, realistisch etwa die Hälfte.
	var income := 250000
	var total := ShopData.total_cost()
	if total < income * 1.4:
		fails.append("Werkstatt zu billig: %d Punkte für alles bei ~%d Einkommen" % [total, income])
	if total > income * 4.0:
		fails.append("Werkstatt zu teuer: %d Punkte für alles bei ~%d Einkommen" % [total, income])
	# Erste Stufe muss nach einem Level bezahlbar sein (~20.000 Punkte Ausbeute)
	for it in ShopData.ITEMS:
		var price := int((it.get("costs", []) as Array)[0])
		if price > 8000:
			fails.append("Stufe 1 von %s zu teuer (%d)" % [String(it.id), price])
	print("SHOP: Gesamtpreis %d, Einkommen ~%d, Anteil %.0f %%" % [total, income,
		100.0 * float(total) / float(income)])

func _check_shop_data() -> void:
	if ShopData.ITEMS.size() < 30:
		fails.append("Nur %d Kauf-Upgrades" % ShopData.ITEMS.size())
	for it in ShopData.ITEMS:
		if (it.get("steps", []) as Array).size() != 3:
			fails.append("%s hat nicht 3 Stufen" % String(it.id))
		if (it.get("costs", []) as Array).size() != 3:
			fails.append("%s hat keine 3 Preise" % String(it.id))
		# Vorbedingungen müssen existieren
		for req in it.get("req", []):
			if ShopData.item(String((req as Array)[0])).is_empty():
				fails.append("%s verweist auf unbekannte Vorbedingung %s" % [
					String(it.id), String((req as Array)[0])])
		if String(it.get("name", "")).length() > 22:
			fails.append("%s hat einen zu langen Namen" % String(it.id))
	# mindestens eine Kette mit Vorbedingung
	var chains := 0
	for it in ShopData.ITEMS:
		if not (it.get("req", []) as Array).is_empty():
			chains += 1
	if chains < 3:
		fails.append("Zu wenige aufbauende Ketten: %d" % chains)

func _check_shop_screen() -> void:
	Save.new_campaign("normal", 424242)
	Save.campaign.points = 20000
	Save.campaign.shop = {}
	app.clear_screens()
	app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 1})
	await get_tree().create_timer(0.4, true).timeout
	var shop = app.screens[app.screens.size() - 1]
	if shop == null:
		fails.append("Werkstatt öffnet nicht")
		return
	# Dreispaltige Werkstatt: die Mitte zeigt je Kategorie deren Upgrades.
	var rows := 0
	for c in range(shop._cats.size()):
		shop._select_cat(c)
		for it in shop.items:
			if String(it.get("kind", "")) == "choice":
				rows += 1
	shop._select_cat(0)
	if rows < 32:
		fails.append("Werkstatt zeigt nur %d Einträge" % rows)
	# gesperrter Eintrag ohne Vorbedingung
	var wave_freq_index := -1
	var wave_index := -1
	for i in range(shop.items.size()):
		var id := String(shop.items[i].get("id", ""))
		if id == "wave_freq":
			wave_freq_index = i
		elif id == "wave":
			wave_index = i
	if wave_freq_index < 0 or wave_index < 0:
		fails.append("Einträge fehlen in der Liste")
		return
	if not bool(shop.items[wave_freq_index].get("disabled", false)):
		fails.append("Schnelle Wellen ist ohne Wellenschuss nicht gesperrt")
	# kaufen
	var before := int(Save.campaign.get("points", 0))
	# echten Eingabeweg nehmen: Fokus setzen, dann bestätigen (wie Leertaste/Klick)
	shop.focus = wave_index
	shop._update_focus_visuals()
	shop._activate()
	await get_tree().process_frame
	if int(Save.campaign.get("shop", {}).get("wave", 0)) != 1:
		fails.append("Wellenschuss wurde nicht gekauft")
	var after := int(Save.campaign.get("points", 0))
	if after != before - ShopData.cost("wave", 0):
		fails.append("Punkte falsch abgezogen: %d -> %d" % [before, after])
	# jetzt muss die Folgestufe frei sein
	if bool(shop.items[wave_freq_index].get("disabled", false)):
		fails.append("Schnelle Wellen bleibt nach Wellenschuss gesperrt")
	# zu teuer: alles ausgeben, dann Kaufversuch
	Save.campaign.points = 100
	shop._load_state()
	shop._rebuild_keep_focus()
	var count_before := int(Save.campaign.get("shop", {}).get("orbit", 0))
	shop.focus = shop.items.size() - 2
	shop._activate()
	if int(Save.campaign.get("shop", {}).get("orbit", 0)) != count_before:
		fails.append("Kauf ohne genug Punkte war möglich")
	if int(Save.campaign.get("points", 0)) != 100:
		fails.append("Punkte wurden ohne Kauf verändert")
	app.clear_screens()
	await get_tree().process_frame

func _wait_game() -> Node:
	for i in range(400):
		if app.game != null and is_instance_valid(app.game) and app.game.player != null:
			return app.game
		await get_tree().process_frame
	return null

func _check_effects() -> void:
	Save.new_campaign("normal", 5151)
	Save.campaign.shop = {"orbit": 1, "wave": 1, "extra_life": 3, "fire_rate": 3,
		"pierce": 2, "back": 1, "side": 1}
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		fails.append("Level startet nicht")
		return
	var p: Player = g.player
	if int(p.shop_mod("max_hp_add")) != 3:
		fails.append("Zusatzleben aus der Werkstatt fehlt")
	if p.max_hp < 6:
		fails.append("max_hp ohne Werkstattbonus: %d" % p.max_hp)
	if not p.shop_has("orbit"):
		fails.append("Kreisflug nicht aktiv")
	# Schuss abgeben und Flugbahn prüfen
	g.bullets.player_bullets.clear()
	p._fire_volley()
	await get_tree().process_frame
	var orbiting := 0
	for b in g.bullets.player_bullets:
		if float(b.get("orbit_r", 0.0)) > 0.0:
			orbiting += 1
		# Durchschlag aus der Werkstatt muss aufgeschlagen sein
		if int(b.get("pierce", 0)) < 2:
			fails.append("Durchschlag fehlt an den Schüssen")
			break
	if orbiting < 1:
		fails.append("Keine kreisenden Schüsse")
	if g.bullets.player_bullets.size() < 3:
		fails.append("Zu wenige Schüsse mit Zusatzläufen: %d" % g.bullets.player_bullets.size())
	# Feuerrate
	var iv := p.fire_interval()
	if iv >= Player.BASE_INTERVAL:
		fails.append("Schnellfeuer wirkt nicht (%.3f)" % iv)
	app.clear_screens()
	await get_tree().process_frame

func _check_boss_intro() -> void:
	Save.new_campaign("normal", 9090)
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		fails.append("Level für Bossprobe startet nicht")
		return
	g.director.start_boss_now()
	await get_tree().create_timer(0.3, false).timeout
	var hud = app.hud
	if hud == null or not hud.has_method("boss_announce"):
		fails.append("HUD kennt die Bossankündigung nicht")
	elif float(hud.boss_t) <= 0.0:
		fails.append("Bossankündigung nicht sichtbar")
	if g.boss != null:
		fails.append("Boss erscheint schon während der Ankündigung")
	await get_tree().create_timer(1.4, false).timeout
	if g.boss == null:
		fails.append("Boss erscheint nach der Ankündigung nicht")
	app.clear_screens()
	await get_tree().process_frame

func _check_debug_menu() -> void:
	Save.new_campaign("normal", 6161)
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		fails.append("Level für Debugprobe startet nicht")
		return
	app.debug_game()
	await get_tree().create_timer(0.4, true).timeout
	if not app.paused:
		fails.append("F4 pausiert das Spiel nicht")
	var dbg = app.screens[app.screens.size() - 1]
	if dbg == null:
		fails.append("Debugmenü öffnet nicht")
		return
	var has_heal := false
	var has_boss := false
	for it in dbg.items:
		match String(it.get("id", "")):
			"heal": has_heal = true
			"boss": has_boss = true
	if not has_heal or not has_boss:
		fails.append("Debugmenü ohne Heilung/Boss-Sprung")
	# Leben setzen und heilen (Zeile über die Kennung suchen, nicht über den Index)
	var p: Player = g.player
	p.hp = 1
	var heal_index := -1
	for i in range(dbg.items.size()):
		if String(dbg.items[i].get("id", "")) == "heal":
			heal_index = i
	if heal_index < 0:
		fails.append("Vollheilen fehlt im Debugmenü")
	else:
		dbg.focus = heal_index
	dbg._activate()
	await get_tree().process_frame
	if p.hp != p.max_hp:
		fails.append("Vollheilen wirkt nicht (%d/%d)" % [p.hp, p.max_hp])
	# Kauf-Upgrade im Debugmenü setzen
	var orbit_index := -1
	for i in range(dbg.items.size()):
		if String(dbg.items[i].get("id", "")) == "s:orbit":
			orbit_index = i
	if orbit_index < 0:
		fails.append("Kauf-Upgrades fehlen im Debugmenü")
	else:
		dbg.on_adjust(orbit_index, 1)
		await get_tree().process_frame
		if int(g.player.shop_levels.get("orbit", 0)) != 1:
			fails.append("Debugmenü setzt Kauf-Upgrades nicht")
	if int(Save.campaign.get("shop", {}).get("orbit", 0)) != 1:
		fails.append("Debugmenü speichert Kauf-Upgrades nicht")
	app.debug_close()
	await get_tree().create_timer(0.5, false).timeout
	if app.paused:
		fails.append("Debugmenü setzt das Spiel nicht fort")
	app.clear_screens()
	await get_tree().process_frame

## Der gemeldete Fehler: Bestätigen kaufte nichts. Hier mit echter Taste.
func _check_real_key() -> void:
	Save.new_campaign("normal", 7171)
	Save.campaign.points = 20000
	Save.campaign.shop = {}
	app.clear_screens()
	app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 1})
	await get_tree().create_timer(0.5, false).timeout
	var shop = app.screens[app.screens.size() - 1]
	if shop == null:
		fails.append("Werkstatt öffnet für die Tastenprobe nicht")
		return
	# Erste Leertaste öffnet die Upgradeliste der Kategorie, kauft aber nichts.
	await _press(KEY_SPACE)
	if shop.mode != "items" or not Save.campaign.get("shop", {}).is_empty():
		fails.append("Leertaste in den Kategorien öffnet die Liste nicht (oder kauft)")
	for i in range(shop.items.size()):
		if String(shop.items[i].get("id", "")) == "orbit":
			shop.focus = i
			shop._update_focus_visuals()
			break
	await get_tree().process_frame
	await _press(KEY_SPACE)
	var bought := int(Save.campaign.get("shop", {}).get("orbit", 0))
	if bought != 1:
		fails.append("Leertaste kauft in der Werkstatt nicht (Stufe %d)" % bought)
	else:
		print("SHOP: Leertaste kauft, Restpunkte %d" % int(Save.campaign.get("points", 0)))
	# zweiter Druck erhöht auf Stufe 2
	await _press(KEY_SPACE)
	if int(Save.campaign.get("shop", {}).get("orbit", 0)) != 2:
		fails.append("Zweiter Kauf hebt die Stufe nicht an")
	# Pfeil rechts darf nicht kaufen (nur blättern)
	await _press(KEY_RIGHT)
	if int(Save.campaign.get("shop", {}).get("orbit", 0)) != 2:
		fails.append("Pfeil rechts löst einen Kauf aus")
	# Pfeil links führt zurück in die Kategorien, ohne zu kaufen.
	await _press(KEY_LEFT)
	if shop.mode != "cats" or int(Save.campaign.get("shop", {}).get("orbit", 0)) != 2:
		fails.append("Pfeil links führt nicht zurück in die Kategorien")
	app.clear_screens()
	await get_tree().process_frame

## Tastendruck über mehrere Bilder halten: die Kantenerkennung liest nur
## Physikbilder, ein Druck und Lösen im selben Bild kommt nie an.
func _press(key: int) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().create_timer(0.25, false).timeout
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().create_timer(0.3, false).timeout

func _check_flow() -> void:
	# Nach dem Level: Ergebnis -> Werkstatt -> nächstes Level
	Save.new_campaign("normal", 2020)
	Save.campaign.points = 20000
	app.mode = "campaign"
	app.clear_screens()
	app.advance_after_level(1)
	await get_tree().create_timer(0.4, true).timeout
	var top = app.screens[app.screens.size() - 1]
	if top == null or not (top.get_script() != null):
		fails.append("Nach dem Level öffnet keine Werkstatt")
		return
	var path := String(top.get_script().resource_path)
	if not path.ends_with("shop_screen.gd"):
		fails.append("Nach dem Level öffnet %s statt der Werkstatt" % path)
		return
	# im Shop mit echter Taste kaufen – muss im nächsten Level ankommen
	await _press(KEY_RIGHT)
	var bought := false
	for i in range(top.items.size()):
		if String(top.items[i].get("id", "")) == "wave":
			top.focus = i
			top._update_focus_visuals()
			bought = true
			break
	if not bought:
		fails.append("Wellenschuss fehlt in der Werkstatt nach dem Level")
	await _press(KEY_SPACE)
	if int(Save.campaign.get("shop", {}).get("wave", 0)) != 1:
		fails.append("Kauf nach dem Level schlägt fehl")
	app.shop_done(1, true)
	# Zwischensequenz bestätigen, sonst startet das Level nicht
	for i in range(200):
		if not app.screens.is_empty():
			var sc = app.screens[app.screens.size() - 1]
			var path2 := String(sc.get_script().resource_path) if sc.get_script() != null else ""
			if path2.ends_with("story_screen.gd"):
				sc.on_activate(0)
				break
		await get_tree().process_frame
	for i in range(400):
		if app.game != null and is_instance_valid(app.game) and app.game.player != null:
			break
		await get_tree().process_frame
	if app.game == null:
		fails.append("Nach der Werkstatt startet kein Level")
	elif int(app.game.player.shop_levels.get("wave", 0)) < 1:
		fails.append("Gekauftes Upgrade fehlt im nächsten Level")
	elif int(app.game.level_index) != 2:
		fails.append("Nach der Werkstatt läuft Level %d statt 2" % int(app.game.level_index))
	app.clear_screens()
	await get_tree().process_frame

func _check_plasma() -> void:
	Save.new_campaign("normal", 3131)
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game()
	if g == null:
		fails.append("Level für Plasmaprobe startet nicht")
		return
	var p: Player = g.player
	p.upgrades["plasma"] = 3
	p.weapon = "plasma"
	g.bullets.player_bullets.clear()
	p._fire_volley()
	await get_tree().process_frame
	var n: int = int(g.bullets.player_bullets.size())
	if n < 3:
		fails.append("Plasma Stufe 3 schießt nur %d Kugeln" % n)
		return
	var angles: Array = []
	var dmg := 0.0
	for b in g.bullets.player_bullets:
		angles.append(rad_to_deg((b.v as Vector2).angle()))
		dmg = maxf(dmg, float(b.dmg))
	angles.sort()
	var spread: float = float(angles[angles.size() - 1]) - float(angles[0])
	if spread < 3.0:
		fails.append("Plasma hat keinen Spread (%.1f°)" % spread)
	if spread > 25.0:
		fails.append("Plasma-Spread zu groß (%.1f°)" % spread)
	# Vergleich mit dem Fächerschuss: etwa ein Viertel davon
	p.upgrades["fan"] = 3
	p.weapon = "fan"
	g.bullets.player_bullets.clear()
	p._fire_volley()
	await get_tree().process_frame
	var fan_angles: Array = []
	for b in g.bullets.player_bullets:
		fan_angles.append(rad_to_deg((b.v as Vector2).angle()))
	fan_angles.sort()
	var fan_spread: float = float(fan_angles[fan_angles.size() - 1]) - float(fan_angles[0])
	var ratio := spread / maxf(0.01, fan_spread)
	print("SHOP: Plasma-Spread %.1f°, Fächer %.1f°, Verhältnis %.2f" % [spread, fan_spread, ratio])
	if ratio < 0.15 or ratio > 0.45:
		fails.append("Plasma-Spread ist %.0f %% des Fächers (erwartet ~25 %%)" % (ratio * 100.0))
	if dmg < 17.0:
		fails.append("Plasma macht zu wenig Schaden (%.1f)" % dmg)
	app.clear_screens()
	await get_tree().process_frame
