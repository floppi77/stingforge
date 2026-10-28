extends Node
## Prüft die Balance: Wie stark ist die Bewaffnung, wie zäh sind die Gegner, und
## wie lange dauert es, bis ein Gegner fällt?

var app: Node
var fails: Array = []
var rows: Array = []

const CONFIGS := [
	{"name": "Start", "shop": {}, "weapon": "base", "lv": 1, "weapon_lv": 1},
	{"name": "Mitte", "shop": {"fire_rate": 2, "multishot": 1, "back": 1, "crit": 1,
		"pierce": 1, "big_bullet": 1}, "weapon": "fan", "lv": 2},
	{"name": "Alles", "shop": {"fire_rate": 3, "multishot": 3, "back": 3, "side": 3,
		"crit": 3, "pierce": 3, "big_bullet": 3, "splash": 3, "chain": 3, "burst": 3,
		"spiral": 3, "wave": 3, "wave_amp": 3, "wave_freq": 3, "homing": 3}, "weapon": "fan", "lv": 3},
	{"name": "Alles+", "shop": {"fire_rate": 3, "multishot": 3, "back": 3, "side": 3,
		"crit": 3, "pierce": 3, "big_bullet": 3, "splash": 3, "chain": 3, "burst": 3,
		"spiral": 3, "dmg": 0, "boss_bane": 3}, "weapon": "plasma", "lv": 3},
]

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	for cfg in CONFIGS:
		await _measure(cfg)
	_report()
	get_tree().quit(0 if fails.is_empty() else 1)

func _measure(cfg: Dictionary) -> void:
	Save.new_campaign("normal", 771100)
	Save.campaign.shop = (cfg["shop"] as Dictionary).duplicate()
	Save.campaign.upgrades = {"base": 1, "fan": 0, "lightning": 0, "plasma": 0,
		"companion": 0, "bombs": 0, "shield": 0, "speed": 0}
	Save.save_campaign()
	app.clear_screens()
	app._begin_level(int(cfg["lv"]), 0)
	for i in range(14):
		await get_tree().process_frame
	var g = app.game
	if g == null:
		fails.append("Level startet nicht")
		return
	var p = g.player
	p.upgrades[String(cfg["weapon"])] = int(cfg.get("weapon_lv", 3))
	p.weapon = String(cfg["weapon"])
	# Drei Sekunden echt feuern: der Durchschnitt zählt, nicht die stärkste Salve.
	p.autofire = true
	for i in range(30):
		await get_tree().physics_frame
	var shots_before: int = int(g.stats.shots)
	for i in range(180):
		await get_tree().physics_frame
	var shots_fired: int = int(g.stats.shots) - shots_before
	var dps: float = p.attack_dps()
	var shots: int = p.last_volley_shots
	var iv: float = p.fire_interval()
	var shots_per_s := float(shots_fired) / 3.0
	var hard: float = g.enemy_hp_mult()
	# Echte Abschusszeit: Gegner im Schussfeld, Feuer frei, Zeit messen.
	var moth = g.spawn_enemy("moth", Vector2(900, 200))
	var lady = g.spawn_enemy("ladybug_turret", Vector2(900, 380))
	var ttk_moth := float(moth.max_hp) / maxf(1.0, dps)
	var hp_moth := float(moth.max_hp)
	var ttk_lady := float(lady.max_hp) / maxf(1.0, dps)
	var hp_lady := float(lady.max_hp)
	p.autofire = true
	rows.append({"name": cfg["name"], "dps": dps, "shots": shots, "sps": shots_per_s,
		"hard": hard, "hp_moth": hp_moth, "hp_lady": hp_lady,
		"ttk_moth": ttk_moth, "ttk_lady": ttk_lady})
	# Stingforge: teure Ausbauten sollen kleine Gegner deutlich schneller besiegen.
	# Die frühere 0,12s-Untergrenze neutralisierte diesen ausdrücklich gewünschten
	# Vorteil. Ein Kollaps auf praktisch null (unter etwa 2–3 Physikbilder) bleibt rot.
	if ttk_moth < 0.04:
		fails.append("%s: Motte fällt rechnerisch in %.3f s (praktisch sofort)" % [cfg["name"], ttk_moth])
	if ttk_moth > 0.55:
		fails.append("%s: Motte braucht rechnerisch %.2f s (zu zäh)" % [cfg["name"], ttk_moth])
	if ttk_lady > 2.2:
		fails.append("%s: Marienkäfer braucht rechnerisch %.2f s (zu zäh)" % [cfg["name"], ttk_lady])
	if shots_per_s > 120.0:
		fails.append("%s: %.0f Kugeln je Sekunde (zu viele)" % [cfg["name"], shots_per_s])
	app.clear_screens()
	for i in range(3):
		await get_tree().process_frame

func _report() -> void:
	print("BALANCE: %-7s %9s %7s %8s %8s %9s %9s %9s" %
		["Stufe", "DPS", "Kugeln", "Kugel/s", "Härte", "LP/Motte", "Reihe s", "Käfer s"])
	for r in rows:
		print("BALANCE: %-7s %9.0f %7d %8.1f %8.2f %9.0f %9.2f %9.2f" %
			[r.name, r.dps, r.shots, r.sps, r.hard, r.hp_moth, r.ttk_moth, r.ttk_lady])
	if rows.size() >= 3:
		var start_dps := float((rows[0] as Dictionary).dps)
		var max_dps := float((rows[rows.size() - 1] as Dictionary).dps)
		var gain := max_dps / maxf(1.0, start_dps)
		print("BALANCE: Angriffskraft wächst um das %.1f-fache, Motte braucht "
			% gain + "%.2f s gegen %.2f s" % [
				float((rows[0] as Dictionary).ttk_moth),
				float((rows[rows.size() - 1] as Dictionary).ttk_moth)])
		if gain < 3.0:
			fails.append("Verbesserungen bringen zu wenig (nur das %.1f-fache)" % gain)
		for i in range(1, rows.size()):
			var prior: Dictionary = rows[i - 1]
			var next: Dictionary = rows[i]
			if float(next.dps) > float(prior.dps) and float(next.ttk_moth) >= float(prior.ttk_moth) - 0.005:
				fails.append("%s: mehr Angriffskraft muss die Abschusszeit gegenüber %s spürbar senken" % [next.name, prior.name])
	for f in fails:
		print("BALANCE_FEHLER: " + String(f))
	print("BALANCE_OK" if fails.is_empty() else "BALANCE_FAILED")
