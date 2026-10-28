extends "res://scripts/core/ui_screen.gd"

func setup(_args: Dictionary) -> void:
	title_key = "training.title"
	subtitle_key = "training.subtitle"

func _completed_levels() -> Array:
	var out: Array = []
	var scores: Dictionary = Save.campaign.get("level_scores", {})
	for k in scores.keys():
		var n := int(k)
		if n >= 1 and n <= 10 and not out.has(n):
			out.append(n)
	if bool(Save.profile.get("boss_rush_unlocked", false)):
		for i in range(1, 11):
			if not out.has(i):
				out.append(i)
	out.sort()
	return out

func build_items() -> void:
	var list: Array = []
	list.append({"kind": "label", "text": "training.levels", "size": 20, "color": UiTheme.ACCENT})
	var lv := _completed_levels()
	if lv.is_empty():
		list.append({"kind": "label", "text": "training.locked", "size": 16, "color": UiTheme.DIM})
	for n in lv:
		list.append({"kind": "action", "text": Loc.t("level." + str(n)), "id": "lv%d" % n,
			"value_text": "Level %d" % n})
	list.append({"kind": "sep"})
	list.append({"kind": "label", "text": "training.bosses", "size": 20, "color": UiTheme.ACCENT})
	for n in lv:
		var ldata := Data.level(n)
		var bdef := Data.boss(String(ldata.get("boss", "")))
		list.append({"kind": "action", "text": String(bdef.get("name", "")), "id": "boss%d" % n,
			"value_text": "Boss %d" % n})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "menu.back", "id": "back"})
	items = list

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	var id := String(it.get("id", ""))
	if id == "back":
		app.pop_screen()
		return
	if id.begins_with("lv"):
		app.start_training(int(id.substr(2)), "level")
	elif id.begins_with("boss"):
		app.start_training(int(id.substr(4)), "boss")

func do_back() -> void:
	app.pop_screen()
