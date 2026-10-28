extends "res://scripts/core/ui_screen.gd"

func _ready() -> void:
	list_width = 600
	title_key = "credits.title"
	subtitle_key = ""
	super._ready()

func build_items() -> void:
	var list: Array = []
	for line in Loc.t("credits.body").split("\n"):
		list.append({"kind": "label", "text": line, "size": 17,
			"color": UiTheme.TEXT if line != "" else UiTheme.DIM})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "menu.back", "id": "back"})
	items = list

func on_activate(_index: int) -> void:
	app.pop_screen()

func do_back() -> void:
	app.pop_screen()
