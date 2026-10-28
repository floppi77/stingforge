extends "res://scripts/core/ui_screen.gd"
## Starttalent: Aus dem Pool der 20 Starttalente werden bei jedem Kampagnenstart
## drei zufällig angeboten, möglichst aus verschiedenen Familien.

const OFFER_COUNT := 3

var difficulty := "normal"
var offers: Array = []

func setup(args: Dictionary) -> void:
	difficulty = String(args.get("difficulty", "normal"))
	title_key = "menu.new_campaign"
	subtitle_key = "evo.start_talent"
	offers = roll_offers(OFFER_COUNT)

## Alle als Starttalent markierten Evolutionen (Data: "start": true).
static func start_pool() -> Array:
	var out: Array = []
	for e in Data.EVOLUTIONS:
		if bool(e.get("start", false)):
			out.append(e)
	return out

## Zufällige Auswahl ohne Doppelungen; zuerst je Familie höchstens eins.
static func roll_offers(count: int, seed_value: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var pool := start_pool()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var chosen: Array = []
	var families: Array = []
	for e in pool:
		if chosen.size() >= count:
			break
		if not families.has(String(e.family)):
			chosen.append(e)
			families.append(String(e.family))
	for e in pool:
		if chosen.size() >= count:
			break
		if not chosen.has(e):
			chosen.append(e)
	return chosen

func build_items() -> void:
	columns = 3
	var list: Array = []
	for e in offers:
		var unlocked := Save.is_evolution_unlocked(String(e.id))
		list.append({
			"kind": "card", "text": String(e.name), "family": String(e.family),
			"id": String(e.id),
			"value_text": Loc.t("evo.start_talent"), "compact": true,
			"lines": [
				{"text": String(e.desc), "color": UiTheme.TEXT, "size": 16},
				{"text": "Im Profil freigeschaltet" if unlocked else Loc.t("evo.new_unlock"), "size": 14,
					"color": UiTheme.DIM if unlocked else UiTheme.OK},
			],
		})
	list.append({"kind": "sep"})
	list.append({"kind": "label", "text": "Drei von %d Starttalenten, zufällig gezogen. Genau eines wählen – spätere Evolutionen kommen nach jedem Level dazu." % start_pool().size(),
		"size": 15})
	items = list

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	if not it.has("id"):
		return
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	Save.set_g("game.difficulty", difficulty)
	app.start_new_campaign(difficulty, String(it.id))

func do_back() -> void:
	app.pop_screen()
