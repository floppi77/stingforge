extends Node
## Prüft die gemeldeten Punkte im laufenden Fenster und legt Belege ab.

var fails: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	Save.new_campaign("normal", 777001)
	Save.campaign.start_talent = "pierce1"
	app.clear_screens()
	app._begin_level(1, 0)
	var g = await _wait_game(app)
	g.player.autofire = true
	g.player.nectar = 900
	g.player.try_buy("companion")
	g.player.try_buy("companion")
	await get_tree().create_timer(2.0, false).timeout
	# 1) Begleiter sichtbar?
	var visible_companions := 0
	for c in g.player.companions:
		if c.visible:
			visible_companions += 1
	if visible_companions < 1:
		fails.append("Begleiter nicht sichtbar")
	await _shot("fix_01_begleiter")
	# 2) Spielbereich endet über der Leiste?
	if g.player.play_bounds.end.y > App.PLAY_BOTTOM:
		fails.append("Spielergrenze %s liegt unter der Leiste %s" % [
			str(g.player.play_bounds.end.y), str(App.PLAY_BOTTOM)])
	# 3) Esc öffnet die Pause
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().create_timer(0.4, true).timeout
	var esc_up := InputEventKey.new()
	esc_up.physical_keycode = KEY_ESCAPE
	esc_up.keycode = KEY_ESCAPE
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	await get_tree().create_timer(0.3, true).timeout
	if not app.paused:
		fails.append("Esc öffnet die Pause nicht")
	else:
		await _shot("fix_02_pause")
	# Pause wieder schließen
	app.resume_game()
	await get_tree().create_timer(0.6, false).timeout
	# 4) Boss einzeln dargestellt?
	app.clear_screens()
	app._begin_level(5, 0)
	g = await _wait_game(app)
	g.player.autofire = true
	g.director.start_boss_now()
	for i in range(300):
		if g.boss != null and is_instance_valid(g.boss):
			break
		await get_tree().process_frame
	await get_tree().create_timer(2.4, false).timeout
	if g.boss == null:
		fails.append("Boss erscheint nicht")
	else:
		var boss_children := 0
		for c in g.boss.get_children():
			if c is CanvasItem and (c as CanvasItem).is_visible_in_tree():
				boss_children += 1
		print("BOSS sichtbare Kindknoten: %d, Texturbreite: %d" % [boss_children, _boss_tex_width(g.boss)])
		await _shot("fix_03_boss")
	# 5) Evolutionswahl: drei Karten nebeneinander
	app.clear_screens()
	Save.campaign.level = 3
	Save.campaign.pending = {"level": 3, "offers": app._roll_offers(3), "reroll_used": false}
	var ev = app.push_screen("res://scripts/screens/evolution_screen.gd", {})
	await get_tree().create_timer(0.4, false).timeout
	if ev != null and is_instance_valid(ev):
		print("EVO spalten=%d scrollbar=%s" % [ev.columns, str(ev.scroll_container.visible)])
		if ev.columns != 3:
			fails.append("Evolution nicht dreispaltig")
		if ev.scroll_container.visible:
			fails.append("Evolution nutzt weiterhin den Scrollbereich")
		var card_h := 0.0
		for r in ev._rows:
			card_h = maxf(card_h, r.size.y)
		print("EVO Kartenhöhe=%.0f, Bereich=%.0f" % [card_h, ev.grid_wrap.size.y])
		if card_h > ev.grid_wrap.size.y + 1.0:
			fails.append("Evolutionskarten passen nicht in den Bereich")
		await _shot("fix_04_evolution")
	# 6) Einstellungen: Kategorieleiste bleibt nach Scrollen stehen
	app.clear_screens()
	var st = app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main", "tab": 0})
	await get_tree().create_timer(0.4, false).timeout
	if st != null and is_instance_valid(st):
		st.scroll_container.scroll_vertical = 400
		await get_tree().process_frame
		st.scroll_container.scroll_vertical = 0
		await get_tree().create_timer(0.3, false).timeout
		if not st.note_label.visible or String(st.note_label.text) == "":
			fails.append("Kategorieleiste nach dem Scrollen nicht sichtbar")
		await _shot("fix_05_einstellungen")
	# 7) Starttalent dreispaltig
	app.clear_screens()
	var tal = app.push_screen("res://scripts/screens/start_talent_screen.gd", {"difficulty": "normal"})
	await get_tree().create_timer(0.4, false).timeout
	if tal != null and is_instance_valid(tal):
		if tal.columns != 3:
			fails.append("Starttalente nicht dreispaltig")
		await _shot("fix_06_starttalente")
	print("FIXES: fails=%d" % fails.size())
	for f in fails:
		print("  FAIL " + f)
	print("FIXES_OK" if fails.is_empty() else "FIXES_FAIL")
	get_tree().quit(0 if fails.is_empty() else 1)

func _boss_tex_width(b) -> int:
	if b.body == null:
		return 0
	if b.body is AnimatedSprite2D:
		var f = (b.body as AnimatedSprite2D).sprite_frames.get_frame_texture("default", 0)
		if f is AtlasTexture:
			return int((f as AtlasTexture).region.size.x)
		return int(f.get_width())
	return int((b.body as Sprite2D).texture.get_width())

func _wait_game(app) -> Node:
	for i in range(600):
		if app.game != null and is_instance_valid(app.game):
			return app.game
		await get_tree().process_frame
	return null

func _shot(name: String) -> void:
	await get_tree().create_timer(0.15, true).timeout
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % name))
	print("SHOT ", name)
