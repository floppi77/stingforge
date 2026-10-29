extends Node
func _ready() -> void:
	var app = get_node("/root/App")
	await get_tree().create_timer(0.4, true).timeout
	Save.new_campaign("normal", 4711)
	Save.campaign.evolutions = [{"id": "swarm_mark", "level": 1}, {"id": "wind_rider", "level": 1}]
	Save.profile["masters_seen"] = ["m_pollen_storm", "m_splinter_lance"]
	Save.profile["fusions_seen"] = [Data.fusion_key("crit", "resonance_beat")]
	Save.campaign.pending = {"level": 3, "offers": ["crit", "pollen_trail", "m_splinter_lance"], "reroll_used": false}
	Save.campaign.level = 3
	app.mode = "campaign"
	app.clear_screens()
	app.push_screen("res://scripts/screens/evolution_screen.gd", {"on_choose": func(_id): pass}, 0.0)
	await get_tree().create_timer(1.2, true).timeout
	await _shot("/tmp/claude-1000/-home-floppi-Dokumente-DSH-Workspaces-Apidya/94a522b1-5fef-4061-8449-205ca04d6e6d/scratchpad/shot_evo.png")
	app.clear_screens()
	var f = app.push_screen("res://scripts/screens/fusion_screen.gd", {}, 0.0)
	await get_tree().create_timer(0.4, true).timeout
	for i in range(f.items.size()):
		if String(f.items[i].get("id", "")) == "master:m_pollen_storm":
			f.focus = i
	f._update_focus_visuals()
	f._fill_side()
	await get_tree().create_timer(1.0, true).timeout
	await _shot("/tmp/claude-1000/-home-floppi-Dokumente-DSH-Workspaces-Apidya/94a522b1-5fef-4061-8449-205ca04d6e6d/scratchpad/shot_fus1.png")
	for i in range(f.items.size()):
		if String(f.items[i].get("id", "")) == Data.fusion_key("crit", "resonance_beat"):
			f.focus = i
	f._update_focus_visuals()
	f._fill_side()
	await get_tree().create_timer(1.0, true).timeout
	await _shot("/tmp/claude-1000/-home-floppi-Dokumente-DSH-Workspaces-Apidya/94a522b1-5fef-4061-8449-205ca04d6e6d/scratchpad/shot_fus2.png")
	get_tree().quit(0)

func _shot(path: String) -> void:
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
