extends "res://scripts/core/ui_screen.gd"

const Recipes := preload("res://scripts/core/evo_recipes.gd")

var offers: Array = []
var level := 1
var reroll_used := false
var _chosen := false

func setup(args: Dictionary) -> void:
	title_key = "evo.title"
	subtitle_key = "evo.subtitle"
	back_enabled = false
	_restored = bool(args.get("restored", false))

var _restored := false

func _ready() -> void:
	_ensure_pending()
	super._ready()
	# "Angebote mischen" als schmaler, mittiger Knopf unter den Karten.
	grid_extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_extra.custom_minimum_size.x = UiTheme.size(250)
	if _restored:
		show_banner_hint()

func show_banner_hint() -> void:
	hint_override = "Offene Evolutionsentscheidung wiederhergestellt – bitte genau eine Evolution wählen."

func _ensure_pending() -> void:
	var pending: Dictionary = Save.campaign.get("pending", {})
	if pending.is_empty() or (pending.get("offers", []) as Array).is_empty():
		if Save.campaign.is_empty():
			return
		pending = {
			"level": int(Save.campaign.get("level", 1)),
			"offers": app._roll_offers(3),
			"reroll_used": false,
		}
		Save.campaign.pending = pending
		Save.save_campaign()
	level = int(pending.get("level", 1))
	offers = (pending.get("offers", []) as Array).duplicate()
	reroll_used = bool(pending.get("reroll_used", false))

func build_items() -> void:
	columns = 3
	footer_text = ""
	var list: Array = []
	for id in offers:
		var e := Data.evo(String(id))
		if e.is_empty():
			continue
		var cur := 0
		for entry in Save.campaign.get("evolutions", []):
			if String(entry.get("id", "")) == String(id):
				cur = int(entry.get("level", 1))
		var lines: Array = []
		lines.append({"text": String(e.desc), "color": UiTheme.TEXT, "size": 15})
		if bool(e.get("master", false)):
			if String(e.get("weapon", "")) != "":
				lines.append({"text": Loc.t("evo.weapon_dependent") % Loc.t("bar." + String(e.weapon)), "size": 12,
					"color": UiTheme.DIM})
			lines.append({"text": Recipes.master_line(String(id), Recipes.owned_ids()), "size": 13, "bbcode": true})
			lines.append({"text": Loc.tx("Beide Eltern bleiben erhalten."), "size": 12, "color": UiTheme.DIM})
			list.append({
				"kind": "card", "text": String(e.name), "family": String(e.family), "id": String(id),
				"value_text": Loc.tx("MEISTER"), "compact": true, "master": true, "lines": lines,
				"illustration": String(id), "stripe": Recipes.MASTER,
			})
			continue
		var downside := _downside_text(e)
		if downside != "":
			lines.append({"text": Loc.t("evo.downside") % downside, "color": Color(1, 0.72, 0.55), "size": 13})
		var w := String(e.get("weapon", ""))
		if w != "":
			var owned := int(Save.campaign.get("upgrades", {}).get(w, 0)) > 0
			lines.append({"text": Loc.t("evo.weapon_dependent") % Loc.t("bar." + w), "size": 12,
				"color": UiTheme.OK if owned else Color(1, 0.6, 0.5)})
		if Save.is_evolution_unlocked(String(id)):
			lines.append({"text": Loc.t("evo.active_campaign") if cur > 0 else Loc.t("evo.profile_only"),
				"size": 12, "color": UiTheme.DIM})
		else:
			lines.append({"text": Loc.t("evo.new_unlock"), "size": 12, "color": UiTheme.OK})
		# Rezepte unten klein: grün vorhanden, grau fehlend, diese Karte pulsiert, wenn sie
		# ein Rezept vervollständigt. Kennzeichen und Farbstreifen zeigen das auf einen Blick.
		var recipe := Recipes.for_offer(String(id))
		for line in recipe.lines:
			lines.append({"text": line, "size": 13, "bbcode": true})
		var badges: Array = []
		var stripe := Color(0, 0, 0, 0)
		if bool(recipe.master):
			badges.append({"text": Loc.tx("★ MEISTERREZEPT"), "color": Recipes.MASTER})
			stripe = Recipes.MASTER
		if bool(recipe.fusion):
			badges.append({"text": Loc.tx("◆ VERSCHMELZUNG"), "color": Recipes.FUSION})
			if stripe.a <= 0.0:
				stripe = Recipes.FUSION
		list.append({
			"kind": "card", "text": String(e.name), "family": String(e.family), "id": String(id),
			"value_text": Loc.tx("Stufe %d/%d") % [cur + 1, int(e.max)], "compact": true,
			"lines": lines, "illustration": String(id), "badges": badges, "stripe": stripe,
		})
	list.append({"kind": "sep"})
	list.append({
		"kind": "action",
		"text": "evo.reroll" if not reroll_used else "evo.reroll_used",
		"id": "reroll",
		"disabled": reroll_used,
	})
	items = list

func _downside_text(e: Dictionary) -> String:
	var eff: Dictionary = e.get("effect", {})
	var parts: Array[String] = []
	if float(eff.get("fire_rate_mult", 0.0)) < 0.0:
		parts.append(Loc.tx("langsamere Schussfolge %d%%") % int(round(absf(float(eff.fire_rate_mult)) * 100.0)))
	if float(eff.get("dmg_mult", 0.0)) < 0.0:
		parts.append(Loc.tx("%d%% weniger Schaden") % int(round(absf(float(eff.dmg_mult)) * 100.0)))
	if float(eff.get("hitbox", 0.0)) > 0.0:
		parts.append("größere Trefferzone")
	if float(eff.get("cost_mult", 0.0)) > 0.0:
		parts.append("teurere Upgrades")
	if String(e.get("weapon", "")) != "":
		pass
	return ", ".join(parts)

func on_adjust(_index: int, dir: int) -> void:
	_move_focus(dir)

func on_activate(index: int) -> void:
	if _chosen:
		return
	var it: Dictionary = items[index]
	if String(it.get("id", "")) == "reroll":
		if reroll_used:
			Audio.sfx("deny", -8.0, 1.0, true)
			return
		reroll_used = true
		Save.campaign.pending.reroll_used = true
		var new_offers: Array = app._roll_offers(3)
		Save.campaign.pending.offers = new_offers
		Save.save_campaign()
		offers = new_offers
		Audio.sfx("ui_ok", -6.0, 1.15, true)
		focus = 0
		rebuild()
		refresh()
		return
	if not it.has("id"):
		return
	_chosen = true
	Audio.sfx("purchase", -3.0, 1.1)
	app._confirm_evolution(String(it.id))

func do_back() -> void:
	Audio.sfx("deny", -10.0, 1.0, true)
