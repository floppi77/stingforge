extends "res://scripts/core/ui_screen.gd"

func _ready() -> void:
	title_key = "game.campaign_complete"
	subtitle_key = ""
	Save.profile.boss_rush_unlocked = true
	Save.campaign.completed = true
	Save.save_profile()
	Save.save_campaign()
	super._ready()
	Audio.play_music("ending", 1.2)

func build_items() -> void:
	var total := 0
	for k in Save.campaign.get("level_scores", {}):
		total += int(Save.campaign.level_scores[k].get("score", 0))
	items = [
		{"kind": "label", "text": Loc.t("story.end.1"), "size": 20, "color": UiTheme.TEXT},
		{"kind": "label", "text": Loc.t("story.end.2"), "size": 20, "color": UiTheme.TEXT},
		{"kind": "sep"},
		{"kind": "label", "text": "Gesamtpunkte: %d" % total, "size": 18, "color": UiTheme.ACCENT},
		{"kind": "label", "text": "Freigeschaltete Evolutionen: %d / %d" % [
			(Save.profile.unlocked_evolutions as Array).size(), Data.EVOLUTIONS.size()], "size": 17},
		{"kind": "label", "text": "Boss-Rush freigeschaltet: im Hauptmenü verfügbar.", "size": 16, "color": UiTheme.OK},
		{"kind": "sep"},
		{"kind": "action", "text": "menu.back_main", "id": "menu", "accent": true},
	]

func on_activate(_index: int) -> void:
	Audio.sfx("ui_ok", -6.0, 1.0, true)
	app.menu_main()

func do_back() -> void:
	on_activate(0)
