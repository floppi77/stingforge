extends Node
## Run after stingforge_r2_scores.tscn in the same isolated XDG directory.
## This process never creates the ranking fixture; the prior engine process did.
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("OK " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func _ready() -> void:
	await get_tree().process_frame
	var safe_root := ProjectSettings.globalize_path("res://build/stingforge-r2-testdata-scores/")
	if not OS.get_user_data_dir().begins_with(safe_root):
		check(false, "REFUSE non-isolated user data")
		await _finish()
		return
	check(Save.profile.get("highscores", []).size() == 120, "fresh engine loads all six capped leaderboard buckets")
	for mode in ["campaign", "rush"]:
		for difficulty in ["relaxed", "normal", "expert"]:
			check(Save.get_highscores(mode, difficulty, 20).size() == 20, "fresh-process bucket survives: " + mode + "/" + difficulty)
	var normal: Array = Save.get_highscores("campaign", "normal", 20)
	check(not normal.is_empty() and normal[0].run_id == "recovery-prior" and int(normal[0].score) == 333333, "fresh engine restores actual persisted order and score")
	check(Save.profile.get("best", {}).has("campaign|normal|3|7|std"), "fresh engine retains legacy level bests")
	check(int(Save.profile.get("campaigns_started", 0)) == 9, "fresh engine retains old profile integer counters")
	check(not Save.record_highscore({"run_id": "recovery-prior", "mode": "campaign", "difficulty": "normal", "score": 333333, "level": 4, "completed": false, "seed": 7}), "fresh engine refuses identical recorded run without adding a duplicate")
	check(not Save.record_highscore({"run_id": "bulk-campaign-normal-00", "mode": "campaign", "difficulty": "expert", "score": 999999, "level": 4}), "fresh engine preserves pruned-run bucket identity receipts")
	check(Save.campaign.get("run_score", -1) == 2000 and not String(Save.campaign.get("run_id", "")).is_empty(), "fresh engine retains campaign earned total and run identity")
	await _finish()

func _finish() -> void:
	App.clear_screens()
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	await get_tree().create_timer(0.3, true).timeout
	print("STINGFORGE_R2_SCORES_RELOAD checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty(): print("STINGFORGE_R2_SCORES_RELOAD_OK")
	get_tree().quit(0 if failures.is_empty() else 1)
