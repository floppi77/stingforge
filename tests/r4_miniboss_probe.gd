extends Node
## R4: Der Zwischengegner bleibt in jedem Level im Feld, bis er besiegt ist.
var app: Node
var fails: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	app = get_node("/root/App")
	await get_tree().create_timer(0.3, true, false, true).timeout
	for level in range(1, 11):
		await _level(level)
	Engine.time_scale = 1.0
	for f in fails:
		print("R4_MINIBOSS_FEHLER: " + f)
	print("R4_MINIBOSS_OK" if fails.is_empty() else "R4_MINIBOSS_FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _level(level: int) -> void:
	Engine.time_scale = 1.0
	Save.new_campaign("normal", 5150 + level)
	app.mode = "campaign"
	app.clear_screens()
	app._begin_level(level, 0)
	await get_tree().create_timer(0.5, true, false, true).timeout
	var g = app.game
	g.player.max_hp = 99
	g.player.hp = 99
	g.player.iframes = 1.0e6
	g.player.autofire = false
	g._on_miniboss()
	var mb = g.miniboss
	if mb == null:
		fails.append("Level %d: kein Zwischengegner" % level)
		return
	mb.hp = 1.0e9
	mb.max_hp = 1.0e9
	Engine.time_scale = 4.0
	var min_x := 9999.0
	var max_x := -9999.0
	for i in range(50):
		await get_tree().create_timer(0.4, true, false, false).timeout
		if not is_instance_valid(mb) or mb.dead:
			break
		if mb.age > 2.5:
			min_x = minf(min_x, mb.position.x)
			max_x = maxf(max_x, mb.position.x)
	Engine.time_scale = 1.0
	var alive: bool = is_instance_valid(mb) and not mb.dead
	var age: float = mb.age if alive else 0.0
	var ok: bool = alive and age >= 18.0 and min_x >= 480.0 and max_x <= 940.0
	print(("  OK   " if ok else "  FAIL ") + "Level %d %s: %.1f s im Feld, x %.0f…%.0f" % [
		level, mb.id if alive else "?", age, min_x, max_x])
	if not ok:
		fails.append("Level %d: Zwischengegner verlässt das Feld oder verschwindet" % level)
	app.menu_main()
	await get_tree().create_timer(0.2, true, false, true).timeout
