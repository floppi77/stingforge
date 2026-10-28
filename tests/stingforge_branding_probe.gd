extends Node
## Isolierte Prozessprüfung für Branding und die nicht-destruktive Save-Übernahme.
var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	var root := ProjectSettings.globalize_path("res://build/stingforge-testdata-branding")
	var user_dir := OS.get_user_data_dir()
	if not user_dir.begins_with(root + "/"):
		push_error("Unsicherer Testdatenpfad: " + user_dir)
		get_tree().quit(2)
		return
	_check(String(ProjectSettings.get_setting("application/config/name")) == "Stingforge", "Fenstertitel")
	_check(user_dir.get_file() == "Stingforge", "Neuer Speicherordner")
	_check(Loc.t("game.title") == "STINGFORGE", "Titel")
	_check(Loc.t("game.subtitle") == "Evolve. Adapt. Strike.", "Untertitel")
	_check(Loc.t("credits.body").begins_with("Stingforge\nEvolve. Adapt. Strike."), "Credits")
	var mode := OS.get_environment("STINGFORGE_MIGRATION_CASE")
	var expected_points := 9988 if mode == "existing" else 43210
	var expected_volume := 0.42 if mode == "existing" else 0.37
	_check(Save.active_campaign, "Kampagne übernommen")
	_check(int(Save.campaign.get("points", -1)) == expected_points, "Kampagnenwert korrekt / vorhandener Save gewinnt")
	_check(int(Save.campaign.get("level", -1)) == 4, "Fortschritt Level 4")
	_check(Save.profile.get("unlocked_evolutions", []).has("pierce1"), "Profilfreischaltungen übernommen")
	_check(is_equal_approx(float(Save.g("audio.master", -1)), expected_volume), "Einstellungen übernommen / vorhandene Einstellung gewinnt")
	_check(Save.campaign.get("shop", {}).get("orbit", 0) == 2, "Werkstattstufen unverändert")
	_check(int(Save.campaign.get("deaths", -1)) == 1, "Game-Over-Zähler unverändert")
	var legacy := user_dir.get_base_dir().path_join("Apidya Reimagined/saves")
	_check(FileAccess.file_exists(legacy.path_join("campaign.save")), "Alte Datei nicht entfernt")
	_check(Save._read_json(legacy.path_join("profile.save")).get("sentinel", "") == "untouched", "Altes Profil unverändert")
	for name in ["settings", "profile", "campaign"]:
		_check(FileAccess.file_exists("user://saves/" + name + ".save"), "Neue Speicherdatei " + name)
	_check(FileAccess.file_exists("user://saves/campaign.save.bak") if mode != "existing" else true, "Vorhandene alte Sicherung erhalten")
	print("STINGFORGE_BRANDING mode=%s checks=%d failures=%d" % [mode, checks, failures.size()])
	for f in failures: print("FAIL " + f)
	print("STINGFORGE_BRANDING_OK" if failures.is_empty() else "STINGFORGE_BRANDING_FAILED")
	App.clear_screens()
	for child in Audio.get_children():
		if child is AudioStreamPlayer: child.stop()
	for i in range(3): await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
