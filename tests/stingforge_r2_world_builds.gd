extends Node
## Reale Salven/Projektilsegmente plus kontrollierte Level1–10-Buildmessung.
var failures: Array[String] = []
var checks := 0
var rows: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	await get_tree().process_frame
	for level in range(1, 11):
		for context in ["entry", "field"]:
			_measure(level, context)
	check(rows.size() == 20, "alle20 Level/Build-Kombinationen wirklich durchlaufen")
	var file := FileAccess.open("res://build/stingforge-r2-world-metrics.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "measurements": rows}, "\t"))
		file.close()
	else:
		check(false, "Buildmessungen konnten gespeichert werden")
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.05).timeout
	print("STINGFORGE_R2_WORLD_BUILDS checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("STINGFORGE_R2_WORLD_BUILDS_OK")
		print("STINGFORGE_R2_WORLD_OK")
	get_tree().quit(0 if failures.is_empty() else 1)

func _shop(level: int) -> Dictionary:
	var shop := {}
	if level >= 2:
		shop["big_bullet"] = 1 if level < 5 else (2 if level < 8 else 3)
	if level >= 3:
		shop["fire_rate"] = 1 if level < 6 else (2 if level < 9 else 3)
	if level >= 4:
		shop["crit"] = 1 if level < 7 else (2 if level < 10 else 3)
	if level >= 5:
		shop["multishot"] = 1
	if level >= 6:
		shop["boss_bane"] = 1 if level < 9 else 2
	return shop

func _measure(level: int, context: String) -> void:
	Save.new_campaign("normal", 18031)
	Save.campaign.shop = _shop(level)
	var spent := 0
	for id in Save.campaign.shop:
		for step in range(int(Save.campaign.shop[id])):
			spent += int(ShopData.item(id).costs[step])
	check(spent <= (level - 1) * 16000, "L%d aufbauender Shopbuild liegt im ausgewiesenen16000Punkte/Level-Budget" % level)
	var evolutions: Array = [{"id": "crit", "level": 1 if level < 7 else 2}]
	if level >= 3:
		evolutions.append({"id": "heavy_sting", "level": 1})
	if level >= 6:
		evolutions.append({"id": "splinter", "level": 1})
	if level >= 8:
		evolutions.append({"id": "pollen_trail", "level": 1})
	Save.campaign.evolutions = evolutions
	var upgrades := {}
	for item in Data.UPGRADES:
		upgrades[item.id] = 0
	upgrades["base"] = 1 # kostenlose Standardwaffe, kein taktischer Kauf
	var weapon := "base"
	if context == "field":
		weapon = "base" if level < 3 else ("fan" if level < 6 else ("lightning" if level < 8 else "plasma"))
		upgrades[weapon] = mini(3, 1 + int((level - 1) / 3))
		upgrades["shield"] = mini(3, 1 + int((level - 1) / 4))
	Save.campaign.upgrades = upgrades
	Save.campaign.weapon = weapon
	var g := Game.new()
	g.setup({"level": level})
	g.started = false
	g.player._fire_volley()
	var dps := g.player.attack_dps()
	var shot := g.player.shot_power()
	var enemy: Enemy = g.spawn_enemy("beetle_grunt", Vector2(260, 270))
	var enemy_hp := enemy.max_hp
	g.bullets.clear()
	g.player.autofire = true
	g.player.fire_cd = 0.0
	seed(80420 + level)
	var frames := 0
	for frame in range(600):
		g.player.fire_cd = maxf(0.0, g.player.fire_cd - 1.0 / 60.0)
		g.player._handle_firing(1.0 / 60.0)
		g.bullets.update(1.0 / 60.0, g.player.position)
		g._update_collisions()
		frames += 1
		if enemy.dead:
			break
	check(enemy.dead, "L%d %s tötet Testgegner über echte Salven/Bewegungssegmente" % [level, context])
	g._spawn_boss()
	var boss_hp := g.boss.max_hp
	var boss_dps := dps * (1.0 + g.player.shop_mod("boss_dmg"))
	var row := {"level": level, "context": context, "weapon": weapon, "shop_spent": spent,
		"shop": Save.campaign.shop.duplicate(true), "evolutions": evolutions,
		"dps": dps, "shot_power": shot, "enemy_hp": enemy_hp,
		"enemy_live_seconds": float(frames) / 60.0, "boss_first_form_hp": boss_hp,
		"boss_ideal_seconds": boss_hp / boss_dps,
		"spawn_mult": Director.pressure_for_level(level).spawn_mult,
		"fire_mult": Director.pressure_for_level(level).fire_mult}
	rows.append(row)
	print("WORLD_LEVEL_BUILD " + JSON.stringify(row))
	# Derselbe Build mit zusätzlichem offensiven Kauf darf nicht relativ langsamer
	# werden: bekannte50%-Schadenssteigerung muss die HP-Steigerung übertreffen.
	var before_hp := g._boss_hp_scale()
	var before_dps := dps
	g.player.shop_mods["dmg"] = g.player.shop_mod("dmg") + 0.5
	g.bullets.clear()
	g.player._fire_volley()
	check(g._boss_hp_scale() / before_hp < g.player.attack_dps() / before_dps,
		"L%d %s zusätzliche Wucht bleibt trotzLevelskalierung echter Boss-TTK-Gewinn" % [level, context])
	if context == "entry":
		check(not g.player.shield_active() and g.player.weapon == "base" and int(g.player.upgrades.base) == 1,
			"L%d Einstieg behält kostenloseBasis1 und keine taktischen Käufe" % level)
	g.free()
