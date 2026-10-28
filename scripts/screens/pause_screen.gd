extends "res://scripts/core/ui_screen.gd"

const UiRunStatus := preload("res://scripts/core/ui_run_status.gd")

var reason := ""

func setup(args: Dictionary) -> void:
	reason = String(args.get("reason", ""))
	title_key = "game.paused"
	subtitle_key = ""
	overlay_in_game = true
	side_builder = func(box: VBoxContainer) -> void:
		UiRunStatus.build(box, app, "● SPIEL ANGEHALTEN")

func build_items() -> void:
	var list: Array = []
	if reason == "controller":
		list.append({"kind": "label", "text": "game.controller_lost", "size": 18, "color": UiTheme.DANGER})
		list.append({"kind": "label", "text": "Controller wieder verbinden und fortsetzen wählen.", "size": 15})
	elif reason == "focus":
		list.append({"kind": "label", "text": "Fenster war nicht im Vordergrund. Die Partie ist angehalten.", "size": 15})
	list.append({"kind": "action", "text": "menu.resume", "id": "resume", "accent": true})
	list.append({"kind": "action", "text": "menu.restart_checkpoint", "id": "restart"})
	list.append({"kind": "action", "text": "menu.settings", "id": "settings"})
	list.append({"kind": "action", "text": "menu.build", "id": "build"})
	list.append({"kind": "sep"})
	list.append({"kind": "action", "text": "menu.back_main", "id": "menu"})
	list.append({"kind": "action", "text": "menu.quit", "id": "quit"})
	items = list

func on_activate(index: int) -> void:
	var it: Dictionary = items[index]
	match String(it.get("id", "")):
		"resume":
			app.resume_game()
		"restart":
			app.push_screen("res://scripts/screens/confirm_screen.gd", {
				"title": "menu.restart_checkpoint",
				"message": "Nur der letzte Checkpoint kann fortgesetzt werden.",
				"on_yes": func():
					if app.game != null and app.game.has_method("_restore_checkpoint"):
						app.game._restore_checkpoint()
					app.resume_game(),
			})
		"settings":
			app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "pause"})
		"build":
			app.push_screen("res://scripts/screens/build_overview_screen.gd", {})
		"menu":
			app.push_screen("res://scripts/screens/confirm_screen.gd", {
				"title": "menu.back_main",
				"message": "Der letzte Checkpoint wird gespeichert.",
				"on_yes": func():
					Save.save_all()
					app.menu_main(),
			})
		"quit":
			app.push_screen("res://scripts/screens/confirm_screen.gd", {
				"title": "menu.quit",
				"message": "menu.quit_warn",
				"on_yes": func(): app.quit_to_desktop(),
			})

func do_back() -> void:
	app.resume_game()

func on_return() -> void:
	rebuild()
	refresh()
