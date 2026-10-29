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
	list.append({"kind": "action", "text": "Kaffee spendieren (Ko-fi)", "id": "kofi",
		"value_text": "ko-fi.com/floppi77"})
	list.append({"kind": "action", "text": "menu.back", "id": "back"})
	items = list

func on_activate(index: int) -> void:
	if String(items[index].get("id", "")) == "kofi":
		Audio.sfx("ui_ok", -6.0, 1.0, true)
		app.open_link("https://ko-fi.com/floppi77")
		return
	app.pop_screen()

func do_back() -> void:
	app.pop_screen()
