extends Node
## Prüft drei unterschiedliche Builds im laufenden Spiel (Kampf, Kauf, Schaden).

var fails: Array = []

func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.3, false).timeout
	var builds := [
		{"name": "Fächer + Schild", "buy": ["fan", "fan", "shield"], "weapon": "fan"},
		{"name": "Plasma + Begleiter", "buy": ["plasma", "companion", "plasma"], "weapon": "plasma"},
		{"name": "Blitz + Bomben", "buy": ["lightning", "bombs", "lightning"], "weapon": "lightning"},
	]
	for b in builds:
		await _run_build(app, b)
	print("BUILDS: fails=%d" % fails.size())
	for f in fails:
		print("  FAIL " + f)
	if fails.is_empty():
		print("BUILDS_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _run_build(app, b: Dictionary) -> void:
	app.clear_screens()
	Save.campaign.seed = 4242
	Save.campaign.level = 2
	Save.campaign.upgrades = {}
	Save.campaign.nectar = 900
	Save.campaign.evolutions = []
	app._begin_level(2, 0)
	for i in range(600):
		if app.game != null and is_instance_valid(app.game):
			break
		await get_tree().process_frame
	var g = app.game
	var p = g.player
	for id in b.buy:
		var res: Dictionary = p.try_buy(String(id))
		if not bool(res.get("ok", false)):
			fails.append("%s: Kauf von %s fehlgeschlagen (%s)" % [b.name, id, str(res)])
	p._equip(String(b.weapon))
	p.autofire = true
	var k0: int = g.stats.kills
	var shots0: int = g.stats.shots
	var hp0: int = p.hp
	await get_tree().create_timer(14.0, false).timeout
	var kills: int = g.stats.kills - k0
	if kills <= 0:
		fails.append("%s: keine Abschüsse in 14 s" % b.name)
	if g.stats.shots <= shots0:
		fails.append("%s: kein Schuss abgegeben" % b.name)
	if not is_instance_valid(g.player):
		fails.append("%s: Spieler verschwunden" % b.name)
		return
	print("BUILD %-22s waffe=%s lvl(fan=%d,plasma=%d,lightning=%d,shield=%d,bombs=%d,comp=%d) kills=%d hp=%d/%d nektar=%d" % [
		b.name, g.player.weapon,
		int(g.player.upgrades.get("fan", 0)), int(g.player.upgrades.get("plasma", 0)),
		int(g.player.upgrades.get("lightning", 0)), int(g.player.upgrades.get("shield", 0)),
		int(g.player.upgrades.get("bombs", 0)), int(g.player.upgrades.get("companion", 0)),
		kills, g.player.hp, g.player.max_hp, g.player.nectar])
