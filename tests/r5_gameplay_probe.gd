extends Node
## R5: Larven-Boss (neue Angriffe, drei Phasen), Fontänen in Level 3, Zielsuche,
## zerbrechliches Glas in Level 6, Phasen-Auftritt und Upgrade-Ansage.

var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	for c in get_window().focus_exited.get_connections():
		get_window().focus_exited.disconnect(c.callable)
	await _wait(0.4)
	_data()
	await _larva()
	await _geyser()
	await _glass()
	await _voice()
	for f in fails:
		print("R5_GAME_FEHLER: " + f)
	print("R5_GAME_OK" if fails.is_empty() else "R5_GAME_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _ok(cond: bool, note: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + note)
	if not cond:
		fails.append(note)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _protect(g: Node) -> void:
	if g != null and is_instance_valid(g) and g.player != null:
		g.player.max_hp = 99
		g.player.hp = 99
		g.player.iframes = 1.0e6

func _start(level: int) -> Node:
	Save.new_campaign("normal", 9090 + level)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await _wait(0.5)
	_protect(app.game)
	return app.game

func _data() -> void:
	var homing := 0.0
	var add := 0.0
	for step in ShopData.item("homing").steps:
		homing = maxf(homing, float(step.mod.homing))
	for step in ShopData.item("homing_power").steps:
		add = maxf(add, float(step.mod.homing_add))
	_ok(homing <= 2.5 and add <= 1.8, "Zielsuche abgeschwächt (max %.1f + %.1f)" % [homing, add])
	var phases: Array = Data.boss("giant_larva").phases
	var all := []
	for ph in phases:
		all.append_array(ph.patterns)
	_ok(phases.size() == 3 and all.has("tunnel_chase") and all.has("rock_fall") and all.has("brood"),
		"Larve: drei Phasen mit Tunnelfahrt, Deckeneinsturz und Brut")

func _larva() -> void:
	var g := await _start(2)
	g._spawn_boss()
	await _wait(0.2)
	var boss = g.boss
	_protect(g)
	boss._p_tunnel_chase(true)
	await _wait(2.6)
	var spikes := 0
	for h in g.fx.hazards:
		if String(h.kind) == "root_spike" and float(h.get("height", 80.0)) >= 90.0:
			spikes += 1
	_ok(spikes >= 4, "Tunnelfahrt: Erdsäulen-Reihe am Boden (%d)" % spikes)
	await _wait(1.6)
	_ok(not boss.submerged and boss.vulnerable, "Larve taucht nach der Tunnelfahrt wieder auf")
	boss._p_rock_fall(true)
	await _wait(0.2)
	var cracks := 0
	for h in g.fx.hazards:
		if String(h.kind) == "ceiling_crack":
			cracks += 1
	_ok(cracks >= 6, "Deckeneinsturz kündigt Brocken mit Rissen an (%d)" % cracks)
	await _wait(1.3)
	var rocks := 0
	for b in g.bullets.enemy_bullets:
		if float(b.get("scale", 1.0)) > 1.5 and (b.v as Vector2).y > 200.0:
			rocks += 1
	_ok(rocks >= 4, "Brocken fallen von der Decke (%d)" % rocks)
	boss._p_brood()
	await _wait(1.6)
	var grubs := 0
	for e in g.enemies:
		if is_instance_valid(e) and e.id == "larva_grub":
			grubs += 1
	_ok(grubs >= 2, "Brut: Maden kriechen am Boden (%d)" % grubs)
	# Phasenwechsel mit Auftritt
	boss.take_damage(boss.max_hp * 0.45)
	await _wait(0.1)
	_ok(g.phase_stagger > 0.0 and g.is_play_frozen(), "Phasenwechsel: kurzer Stillstand")
	_ok(app.hud.phase_t > 0.0 and app.hud.phase_num == 2, "Phasenwechsel: großes Banner PHASE II")
	_ok(boss.roar_t > 0.0, "Phasenwechsel: Boss leuchtet und brüllt")
	await _wait(1.4)
	_ok(not g.is_play_frozen() and boss.rage_tint != Color.WHITE, "Danach läuft der Kampf weiter, Boss in Wutfärbung")

func _geyser() -> void:
	var g := await _start(3)
	g.fx.hazards.clear()
	g._on_hazard("water_splash", {})
	var h: Dictionary = g.fx.hazards[0]
	_ok(float(h.height) >= 239.0 and float(h.max_life) >= 3.59, "Fontäne: 240 hoch, 3,6 s lang")
	h.base = Vector2(g.player.position.x, App.PLAY_BOTTOM)
	g.player.position.y = App.PLAY_BOTTOM - 200.0
	g.player.iframes = 0.0
	var hp_before: int = g.player.hp
	h.t = 1.0
	h.life = h.max_life - 1.0
	g._update_hazards(0.016)
	_ok(g.player.hp < hp_before, "Fontäne trifft auch 200 Punkte über dem Boden")
	_protect(g)

func _glass() -> void:
	var g := await _start(6)
	g.fx.hazards.clear()
	g._on_hazard("reflect_panel", {})
	var h: Dictionary = g.fx.hazards[0]
	_ok(float(h.warn) >= 1.5, "Glas: längere Vorwarnung (%.1f s)" % float(h.warn))
	_ok(float(h.max_hp) >= 60.0, "Glas hat Trefferpunkte (%.0f)" % float(h.max_hp))
	h.t = float(h.warn) + 0.1
	var rect: Rect2 = Fx.panel_rect(h)
	var shots := 0
	while float(h.hp) > 0.0 and shots < 2000:
		g.bullets.clear()
		var b: Dictionary = g.bullets.spawn_player(rect.get_center() + Vector2(20, 0), Vector2.ZERO, g.player.shot_power(), "bullet_base")
		b.prev_p = rect.get_center() - Vector2(60, 0)
		g._update_hazards(0.016)
		shots += 1
	_ok(float(h.hp) <= 0.0 and shots > 8, "Glas zerspringt nach mehreren Salven (%d Treffer)" % shots)
	g.fx.update(0.016)
	_ok(g.fx.shards.size() > 10, "Scherben fliegen (%d)" % g.fx.shards.size())
	var still := false
	for hz in g.fx.hazards:
		if String(hz.kind) == "reflect_panel":
			still = true
	_ok(not still, "Zersprungene Scheibe fängt keine Schüsse mehr ab")

func _voice() -> void:
	var g := await _start(1)
	app.hud.selected = 1
	app.hud._announce_selected()
	var clips := 0
	for u in Data.UPGRADES:
		var s: AudioStream = Audio._load_voice("upgrade_" + String(u.id))
		if s != null and s.get_length() > 0.3 and s.get_length() < 1.5:
			clips += 1
	_ok(clips == Data.UPGRADES.size(), "Sprachclip für jedes Upgrade (%d/%d)" % [clips, Data.UPGRADES.size()])
	_ok(Audio._voice_player.playing, "Ansage spielt beim Blättern")
	_ok(bool(Save.g("audio.voice_upgrades", true)), "Ansage standardmäßig an")
	app.menu_main()
	await _wait(0.3)
