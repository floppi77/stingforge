extends "res://scripts/core/ui_screen.gd"

var run_mode := "campaign"

func setup(args: Dictionary) -> void:
	run_mode = String(args.get("run_mode", "campaign"))
	title_key = "menu.boss_rush" if run_mode == "rush" else "menu.new_campaign"
	subtitle_key = "menu.difficulty"

func build_items() -> void:
	var keys := ["relaxed", "normal", "expert"]
	var list: Array = []
	for k in keys:
		var d: Dictionary = Data.DIFFICULTY[k]
		list.append({
			"kind": "action", "text": String(d.name), "id": k,
			"value_text": "%d HP" % int(d.hp),
			"accent": k == "normal",
		})
		list.append({"kind": "label", "text": Loc.t(String(d.name) + ".desc"), "size": 15})
		list.append({"kind": "sep"})
	items = list

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	if not it.has("id"):
		return
	var diff := String(it.id)
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	if run_mode == "rush":
		app.start_boss_rush(diff)
	else:
		app.push_screen("res://scripts/screens/start_talent_screen.gd", {"difficulty": diff})

func do_back() -> void:
	app.pop_screen()
