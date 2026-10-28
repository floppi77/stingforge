extends Node
## Spielgefühl-Messung: 40 Sekunden echtes Spiel je Ausbaustufe. Gemessen wird,
## wie viele Gegner gleichzeitig im Bild sind und wie lange sie leben.

var app: Node
var fails: Array = []
var rows: Array = []

const CONFIGS := [
	{"name": "Start", "shop": {}, "weapon": "base", "lv": 1, "weapon_lv": 1},
	{"name": "Mitte", "shop": {"fire_rate": 2, "multishot": 1, "back": 1, "crit": 1,
		"pierce": 1, "big_bullet": 1}, "weapon": "fan", "lv": 3, "weapon_lv": 2},
	{"name": "Alles", "shop": {"fire_rate": 3, "multishot": 3, "back": 3, "side": 3,
		"crit": 3, "pierce": 3, "big_bullet": 3, "splash": 3, "chain": 3, "burst": 3,
		"spiral": 3, "wave": 3, "wave_amp": 3, "wave_freq": 3, "homing": 3},
		"weapon": "fan", "lv": 3, "weapon_lv": 3},
]

func _ready() -> void:
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	for cfg in CONFIGS:
		await _play(cfg)
	_report()
	get_tree().quit(0 if fails.is_empty() else 1)

func _play(cfg: Dictionary) -> void:
	Save.new_campaign("normal", 424242)
	Save.campaign.shop = (cfg["shop"] as Dictionary).duplicate()
	Save.save_campaign()
	app.clear_screens()
	app._begin_level(int(cfg["lv"]), 0)
	for i in range(14):
		await get_tree().process_frame
	var g = app.game
	var p = g.player
	p.upgrades[String(cfg["weapon"])] = int(cfg["weapon_lv"])
	p.weapon = String(cfg["weapon"])
	p.autofire = true
	var seen := {}            # Instanz-ID -> Startzeit
	var lifetimes: Array = []
	var max_alive := 0
	var alive_sum := 0
	var samples := 0
	var frames := 40 * 60
	for i in range(frames):
		# unverwundbar halten: hier geht es um Gegner, nicht um den Spieler
		p.iframes = 2.0
		await get_tree().physics_frame
		var t := float(i) / 60.0
		for e in g.enemies:
			if not is_instance_valid(e):
				continue
			var k: int = e.get_instance_id()
			if not seen.has(k):
				seen[k] = t
		if i % 6 == 0:
			var alive := 0
			for e in g.enemies:
				if is_instance_valid(e) and float(e.get("hp")) > 0.0:
					alive += 1
			alive_sum += alive
			samples += 1
			max_alive = maxi(max_alive, alive)
	# Lebensdauer der Gegner, die nicht mehr da sind
	for k in seen.keys():
		var found := false
		for e in g.enemies:
			if is_instance_valid(e) and e.get_instance_id() == k:
				found = true
				break
		if not found:
			lifetimes.append(40.0 - float(seen[k]))
	var short := 0
	for lt in lifetimes:
		if float(lt) < 0.35:
			short += 1
	var avg_live := float(alive_sum) / float(maxi(1, samples))
	var short_share := float(short) / float(maxi(1, lifetimes.size()))
	rows.append({"name": cfg["name"], "kills": int(g.stats.kills), "max_alive": max_alive,
		"avg_alive": avg_live, "short": short_share})
	if max_alive > 26:
		fails.append("%s: bis zu %d Gegner gleichzeitig (Gedränge)" % [cfg["name"], max_alive])
	if cfg["name"] == "Alles" and short_share > 0.35:
		fails.append("Alles: %.0f %% der Gegner fallen unter 0,35 s" % (short_share * 100.0))
	app.clear_screens()
	for i in range(3):
		await get_tree().process_frame

func _report() -> void:
	print("LIVE: %-7s %8s %10s %10s %12s" %
		["Stufe", "Abschüsse", "max gleichz.", "Ø gleichz.", "unter 0,35 s"])
	for r in rows:
		print("LIVE: %-7s %8d %10d %10.1f %11.0f %%" %
			[r.name, r.kills, r.max_alive, r.avg_alive, r.short * 100.0])
	for f in fails:
		print("LIVE_FEHLER: " + String(f))
	print("LIVE_OK" if fails.is_empty() else "LIVE_FAILED")
