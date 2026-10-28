extends "res://tests/r3_shots.gd"
## Bildnachweise der dreispaltigen Werkstatt: Kategorieauswahl, Liste, Grafiken.

func _run() -> void:
	Save.new_campaign("normal", 991)
	Save.campaign.points = 42000
	Save.campaign.shop = {"wave": 1, "orbit": 2, "fire_rate": 1}
	Save.campaign.level = 4
	app.mode = "campaign"
	app.clear_screens()
	var shop = app.push_screen("res://scripts/screens/shop_screen.gd", {"from": "menu", "level": 4}, 0.0)
	await _wait(0.5)
	await _shot("w1_kategorien")
	shop._enter_items()
	await _wait(0.3)
	shop._move_focus(1)
	await _wait(0.6)
	await _shot("w2_liste_welle")
	for i in range(5):
		shop._move_focus(1)
	await _wait(0.8)
	await _shot("w3_liste_spirale")
	shop._leave_items()
	shop._select_cat(1)
	shop._enter_items()
	shop._move_focus(1)
	shop._move_focus(1)
	await _wait(0.9)
	await _shot("w4_wirkung_kette")
	shop._leave_items()
	shop._select_cat(3)
	await _wait(0.5)
	await _shot("w5_schutz_kategorie")
	shop._enter_items()
	shop._move_focus(1)
	await _wait(0.7)
	await _shot("w6_schutz_liste")
	shop._leave_items()
	shop._select_cat(4)
	shop._enter_items()
	await _wait(0.7)
	await _shot("w7_ausbeute")
