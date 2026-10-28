extends Node
## Public seams agreed with coordinator: Save APIs/profile persistence and UiScreen hooks.
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
		check(false, "REFUSE to touch non-isolated user data: " + OS.get_user_data_dir())
		_finish()
		return
	App.clear_screens()
	# Existing level records must survive the old-profile load/save path unchanged.
	Save.profile = {"version": 1, "campaigns_started": 9, "totals": {"kills": 42, "deaths": 3, "playtime": 12.5}, "best": {"campaign|normal|3|7|std": {"score": 1234, "rank": "A"}}}
	Save.save_profile()
	Save.profile = {}
	Save.load_profile()
	check(Save.profile.get("best", {}).has("campaign|normal|3|7|std"), "old profile best entries survive save/load")
	check(int(Save.profile.get("campaigns_started", 0)) == 9 and int(Save.profile.totals.kills) == 42, "old JSON integer counters survive load/save")
	check(Save.has_method("ensure_run_score") and Save.has_method("add_run_score"), "public cumulative run-score API exists")
	if Save.has_method("ensure_run_score") and Save.has_method("add_run_score"):
		_test_run_credits()
	check(Save.has_method("record_highscore") and Save.has_method("get_highscores"), "public persistent run-ranking API exists")
	if Save.has_method("record_highscore") and Save.has_method("get_highscores"):
		_test_highscores()
	await _test_ui()
	await _finish()

func _test_run_credits() -> void:
	App.mode = "campaign"
	Save.new_campaign("normal", 7)
	check(Save.campaign.get("run_score", -1) == 0, "fresh run starts at zero earned score")
	var first_id := String(Save.campaign.get("run_id", ""))
	check(not first_id.is_empty(), "fresh campaign has stable run ID")
	Save.add_run_score(500)
	Save.campaign.points = 200 # Werkstattausgabe darf die verdienten 500 nicht senken.
	Save.add_run_score(75)
	Save.add_run_score(-999)
	check(Save.campaign.get("run_score", -1) == 575, "earned score ignores shop spending and negative credits")
	Save.save_campaign()
	Save.campaign = {}
	Save.load_campaign()
	check(Save.campaign.get("run_score", -1) == 575, "earned score survives campaign reload")
	check(Save.campaign.get("run_id", "") == first_id, "continue keeps original run ID")
	Save.new_campaign("normal", 7)
	check(Save.campaign.get("run_id", "") != first_id and Save.campaign.get("run_score", -1) == 0, "new campaign gets new ID even with identical seed")
	Save.campaign.erase("run_score")
	Save.campaign.erase("run_id")
	Save.campaign.points = 900
	Save.campaign.level_stats = {"1": {"score": 600}, "2": {"score": 700}}
	Save.ensure_run_score()
	check(Save.campaign.get("run_score", -1) == 1300 and bool(Save.campaign.get("legacy_score_estimate", false)), "legacy run estimates max(wallet, sum(level scores)) once")
	Save.campaign.points = 0
	Save.ensure_run_score()
	check(Save.campaign.get("run_score", -1) == 1300, "legacy import is not applied twice")
	App.mode = "training"
	Save.add_run_score(999)
	check(Save.campaign.get("run_score", -1) == 1300, "training never adds run credits")
	App.mode = "rush"
	Save.active_campaign = false
	Save.add_run_score(5)
	check(Save.campaign.get("run_score", -1) == 1305, "boss rush earns credits despite inactive campaign flag")
	App.mode = "campaign"
	Save.save_campaign()
	Save.end_campaign()
	Save.load_campaign()
	check(not Save.active_campaign and Save.campaign.is_empty(), "ended runs never resurrect from stale campaign backup")
	Save.new_campaign("normal", 7)
	Save.campaign.run_score = null
	Save.campaign.run_id = ""
	Save.campaign.points = 2000
	Save.campaign.level_stats = {"1": {"score": 600}}
	Save.ensure_run_score()
	check(Save.campaign.get("run_score", -1) == 2000, "invalid legacy total is repaired from the larger wallet estimate")
	Save.save_campaign()
	Save.campaign = {}
	Save.load_campaign()
	var repaired_id := String(Save.campaign.get("run_id", ""))
	Save.campaign = {}
	Save.load_campaign()
	check(not repaired_id.is_empty() and Save.campaign.get("run_id", "") == repaired_id, "repaired empty run identity survives repeated reloads")
	App.mode = ""

func _entry(id: String, score: int, difficulty := "normal", mode := "campaign", completed := false, level := 4) -> Dictionary:
	return {"run_id": id, "mode": mode, "difficulty": difficulty, "score": score, "completed": completed, "level": level, "seed": 7}

func _ids(rows: Array) -> Array:
	var ids: Array = []
	for row in rows: ids.append(row.run_id)
	return ids

func _test_highscores() -> void:
	check(Save.profile.get("highscores", null) is Array, "old profiles get an empty real-run ranking")
	check(Save.get_highscores().is_empty(), "old per-level bests are not fabricated into run totals")
	check(Save.record_highscore(_entry("early", 1000)), "first genuine run is accepted")
	check(Save.record_highscore(_entry("late", 1000)), "second genuine run is accepted")
	check(Save.record_highscore(_entry("deep", 1000, "normal", "campaign", false, 8)), "deeper tie accepted")
	check(Save.record_highscore(_entry("win", 1000, "normal", "campaign", true, 3)), "completed tie accepted")
	check(Save.record_highscore(_entry("expert", 2000, "expert")), "expert bucket accepted")
	check(Save.record_highscore(_entry("relaxed", 500, "relaxed")), "relaxed bucket accepted")
	check(Save.record_highscore(_entry("rush", 9000, "normal", "rush")), "boss rush accepted independently")
	check(_ids(Save.get_highscores("campaign", "normal", 10)) == ["win", "deep", "early", "late"], "ties use completed, level, then earliest sequence")
	check(_ids(Save.get_highscores("campaign", "all", 10)) == ["expert", "win", "deep", "early", "late", "relaxed"], "all difficulty filter merges scores descending, not rush")
	check(_ids(Save.get_highscores("rush", "all", 10)) == ["rush"], "rush ranking never mixes campaign")
	check(Save.get_highscores("campaign", "expert").size() == 1 and Save.get_highscores("campaign", "relaxed").size() == 1, "each difficulty can be filtered")
	check(not Save.record_highscore(_entry("early", 1000)), "exact duplicate run submission is a no-op")
	check(Save.record_highscore(_entry("early", 1100)), "same run ID can update its improved result")
	check(Save.get_highscores("campaign", "normal").size() == 4, "upsert never creates a duplicate run")
	check(not Save.record_highscore(_entry("early", 20, "expert")), "same run cannot move to another difficulty bucket")
	check(not Save.record_highscore(_entry("training", 50000, "normal", "training")), "training mode is rejected")
	var training := _entry("forged-training", 50000)
	training.training = true
	check(not Save.record_highscore(training), "explicit training flag is rejected")
	App.mode = "training"
	check(not Save.record_highscore(_entry("live-training", 50000)), "live training context cannot submit a campaign score")
	App.mode = ""
	check(not Save.record_highscore(_entry("negative", -1)), "negative scores are rejected")
	check(not Save.record_highscore(_entry("bad-difficulty", 100, "all")), "all is a filter, never a stored difficulty")
	check(Save.get_highscores("invalid", "all").is_empty() and Save.get_highscores("campaign", "invalid").is_empty(), "invalid filters never broaden the leaderboard")
	var detached: Array = Save.get_highscores("campaign", "normal")
	detached[0].score = 999999
	check(int(Save.get_highscores("campaign", "normal")[0].score) == 1100, "query results cannot mutate saved scores")
	Save.profile = {}
	Save.load_profile() # record_highscore itself must have persisted every accepted run.
	check(Save.get_highscores("campaign", "normal").size() == 4, "recording persists rankings without explicit save_profile")
	check(_ids(Save.get_highscores("campaign", "normal")) == ["early", "win", "deep", "late"], "ordering survives physical JSON profile reload")
	check(String(Save.get_highscores("rush")[0].pilot) == "Yuri", "default pilot is Yuri")
	check(not Save.record_highscore(_entry("early", 1100)), "deduplication persists across reload")
	check(Save.profile.best.has("campaign|normal|3|7|std"), "level best entries remain intact after recording runs")
	check(Save.record_highscore(_entry("win", 1200, "normal", "campaign", false, 1)), "later higher total can update a completed run")
	var winner: Dictionary = Save.get_highscores("campaign", "normal")[0]
	check(winner.run_id == "win" and bool(winner.completed) and int(winner.level) == 3, "upsert preserves completed flag and highest reached level")
	_test_buckets_and_validation()

func _test_buckets_and_validation() -> void:
	for mode in ["campaign", "rush"]:
		for difficulty in ["relaxed", "normal", "expert"]:
			for n in range(25):
				Save.record_highscore(_entry("bulk-%s-%s-%02d" % [mode, difficulty, n], 10000 + n, difficulty, mode))
			var bucket: Array = Save.get_highscores(mode, difficulty, 20)
			check(bucket.size() == 20 and int(bucket[0].score) == 10024 and int(bucket[19].score) == 10005, "top20 cap and descending order: " + mode + "/" + difficulty)
			check(Save.get_highscores(mode, difficulty).size() == 10, "default top10: " + mode + "/" + difficulty)
	check(Save.profile.highscores.size() == 120, "all six buckets independently retain 20 records")
	check(Save.get_highscores("campaign", "all", 999).size() == 20 and Save.get_highscores("campaign", "all", 0).is_empty(), "queries clamp large limits to20 and respect zero")
	Save.profile = {}
	Save.load_profile()
	check(not Save.record_highscore(_entry("bulk-campaign-normal-00", 10000)), "pruned repeated run cannot reenter lower than bucket threshold")
	check(not Save.record_highscore(_entry("bulk-campaign-normal-00", 99999, "expert")), "pruned run identity still cannot change difficulty after reload")
	check(Save.record_highscore(_entry("bulk-campaign-normal-00", 99999)), "improved pruned run can enter original bucket without new identity")
	Save.record_highscore(_entry("completed-pruned", 1, "normal", "campaign", true, 10))
	Save.profile = {}
	Save.load_profile()
	check(Save.record_highscore(_entry("completed-pruned", 10025, "normal", "campaign", false, 1)), "pruned completed run can reenter on an improved score")
	var restored_rows: Array = Save.get_highscores("campaign", "normal", 20).filter(func(row): return row.run_id == "completed-pruned")
	check(restored_rows.size() == 1 and bool(restored_rows[0].completed) and int(restored_rows[0].level) == 10, "completion and maximum level remain monotone even after pruning and reload")
	for invalid_score in [null, "500", 1.5, INF, NAN, {}, []]:
		var bad := _entry("bad", 1)
		bad.score = invalid_score
		check(not Save.record_highscore(bad), "reject malformed score " + str(invalid_score))
	var bad_level := _entry("bad-level", 1)
	bad_level.level = []
	check(not Save.record_highscore(bad_level), "reject malformed level without crashing")
	Save.profile.highscores.append({"mode": "training", "score": 500})
	Save.profile.highscores.append(Save.profile.highscores[0].duplicate(true))
	Save.save_profile()
	Save.profile = {}
	Save.load_profile()
	check(Save.profile.highscores.size() == 120, "load drops malformed and duplicate saved rows without harming buckets")
	_test_backup_recovery()

func _corrupt_profile_fixture() -> void:
	# _ready refuses any user-data root outside our isolated build fixture.
	var file := FileAccess.open("user://saves/profile.save", FileAccess.WRITE)
	file.store_string("{ interrupted write")
	file.close()

func _test_backup_recovery() -> void:
	Save.record_highscore(_entry("recovery-prior", 333333))
	Save.record_highscore(_entry("recovery-latest", 444444))
	_corrupt_profile_fixture()
	Save.profile = {}
	Save.load_profile()
	check(_ids(Save.get_highscores()).has("recovery-prior"), "corrupt primary profile recovers scores from backup")
	check(Save.last_load_note.contains("Sicherung"), "backup recovery is disclosed")
	Save.record_highscore(_entry("after-recovery", 555555))
	_corrupt_profile_fixture()
	Save.profile = {}
	Save.load_profile()
	check(_ids(Save.get_highscores()).has("recovery-prior"), "writing after recovery never replaces healthy backup with corrupt primary")
	Save.save_profile() # Leave a clean, deterministic fixture for the fresh-process reload scene.

func _test_ui() -> void:
	var path := "res://scripts/screens/highscore_screen.gd"
	check(FileAccess.file_exists(path), "standalone modern highscore screen exists")
	if not FileAccess.file_exists(path): return
	var screen = App.push_screen(path, {"mode": "campaign", "difficulty": "normal", "limit": 20}, 0.0)
	for frame in range(4): await get_tree().process_frame
	check(screen.items[0].kind == "choice" and screen.items[1].kind == "choice" and screen.items[2].kind == "choice", "all three filters are purchase-free UiScreen choices")
	check(screen.scores.size() == 20, "screen renders selected Top20 bucket")
	var badges := {"key": 0, "pad": 0}
	_count_badges(screen.prompt_bar, badges)
	check(badges.key > 0 and badges.pad > 0, "footer shows keyboard and Xbox prompts simultaneously")
	var profile_before := JSON.stringify(Save.profile)
	var wallet_before := int(Save.campaign.get("points", 0))
	screen.on_adjust(0, 1)
	check(screen.selected_mode == "rush" and screen.focus == 0, "left/right mode choice switches without purchase or lost focus")
	screen.on_adjust(1, -1)
	check(screen.difficulty_filter == "relaxed", "difficulty choice wraps backwards normal->relaxed")
	screen.on_adjust(2, 1)
	check(screen.row_limit == 10 and screen.scores.size() == 10, "top20 choice switches to top10")
	check(int(Save.campaign.get("points", 0)) == wallet_before and JSON.stringify(Save.profile) == profile_before, "viewing/changing filters never spends points or changes profile")
	# Large accessibility font must still keep prompts and rows within canvas.
	var theme_script = load("res://scripts/core/ui_theme.gd")
	for scale in [1.0, 1.6]:
		theme_script.set_scale_override(scale)
		App.pop_screen(0.0)
		await get_tree().process_frame
		screen = App.push_screen(path, {"mode": "campaign", "difficulty": "normal", "limit": 20}, 0.0)
		for frame in range(5): await get_tree().process_frame
		var viewport_rect := get_viewport().get_visible_rect()
		var footer_rect: Rect2 = screen.prompt_bar.get_global_rect()
		check(footer_rect.position.y >= 0 and footer_rect.end.y <= viewport_rect.end.y + 1 and footer_rect.end.x <= viewport_rect.end.x + 1, "dual footer fits at font scale " + str(scale))
		check(screen.scroll_container.get_v_scroll_bar().max_value > screen.scroll_container.size.y, "top20 list has usable scrollbar at font scale " + str(scale))
		for row in screen._rows:
			check(row.get_global_rect().end.x <= viewport_rect.end.x + 1, "score row fits horizontally at font scale " + str(scale))
		screen.focus = screen.items.size() - 1
		screen.on_activate(screen.focus)
		await get_tree().process_frame
		check(not App.screens.has(screen), "back action pops exactly the score screen")
		# Restore the screen so the next scale can pop it first.
		screen = App.push_screen(path, {}, 0.0)
	theme_script.set_scale_override(-1.0)
	screen.do_back()
	await get_tree().process_frame
	var empty_profile := Save.profile.duplicate(true)
	Save.profile.highscores = []
	screen = App.push_screen(path, {"mode": "rush", "difficulty": "expert"}, 0.0)
	for frame in range(3): await get_tree().process_frame
	check(screen.scores.is_empty() and screen.items.any(func(item): return item.get("id", "") == "empty"), "empty filtered bucket has an explicit readable state")
	screen.do_back()
	Save.profile = empty_profile
	await get_tree().process_frame
	# Coordinated Main integration, driven through its real public action hook.
	App.menu_main()
	for frame in range(3): await get_tree().process_frame
	var menu = App.screens[-1]
	var score_item := -1
	for index in range(menu.items.size()):
		if menu.items[index].get("id", "") == "scores": score_item = index
	check(score_item >= 0, "coordinated real main menu exposes the scores action")
	if score_item >= 0:
		menu.on_activate(score_item)
		for frame in range(3): await get_tree().process_frame
		var opened = App.screens[-1]
		check(opened.get_script().resource_path == path, "main-menu scores action opens the real HighscoreScreen")
		opened.do_back()
		await get_tree().process_frame
		check(App.screens[-1] == menu and menu.visible, "back from highscores restores the same visible main menu")

func _count_badges(node: Node, counts: Dictionary) -> void:
	if node.has_meta("prompt_kind"):
		counts[String(node.get_meta("prompt_kind"))] += 1
	for child in node.get_children(): _count_badges(child, counts)

func _finish() -> void:
	print("STINGFORGE_R2_SCORES checks=%d failures=%d" % [checks, failures.size()])
	for audio in Audio.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	App.clear_screens()
	for frame in range(8): await get_tree().process_frame
	# Dummy audio still retires Ogg playback on its worker thread, not render frames.
	await get_tree().create_timer(0.3, true).timeout
	if failures.is_empty(): print("STINGFORGE_R2_SCORES_OK")
	get_tree().quit(0 if failures.is_empty() else 1)
