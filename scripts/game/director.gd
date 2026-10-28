class_name Director
extends Node
## Levelregie: handgebaute Abschnitte, geprüfte Begegnungsvarianten (Seed),
## Gefahrenmechaniken, Miniboss, Checkpoints und Bossauslösung.

signal spawn_enemy_requested(id: String, pos: Vector2, opts: Dictionary)
signal hazard_requested(kind: String, data: Dictionary)
signal checkpoint_reached(index: int)
signal miniboss_started()
signal boss_triggered()
signal section_changed(index: int)
signal level_finished()

const FORMATIONS := {
	"moth_line": {"enemy": "moth", "kind": "line", "n": 5, "y": 0.34, "gap_y": 0.10, "gap_x": 0.0, "amp": 36.0},
	"moth_arc": {"enemy": "moth", "kind": "arc", "n": 6, "y": 0.5, "gap_x": 46.0, "amp": 52.0},
	"aphid_cloud": {"enemy": "aphid_swarm", "kind": "cluster", "n": 8, "y": 0.5, "gap_x": 22.0, "amp": 30.0},
	"beetle_row": {"enemy": "beetle_grunt", "kind": "line", "n": 3, "y": 0.42, "gap_y": 0.22, "gap_x": 70.0},
	"pod_field": {"enemy": "pollen_pod", "kind": "line", "n": 4, "y": 0.28, "gap_y": 0.18, "gap_x": 120.0},
	"ladybug_pair": {"enemy": "ladybug_turret", "kind": "pair", "n": 2, "y": 0.5, "gap_y": 0.3},
	"wasp_dive": {"enemy": "wasp_dart", "kind": "column", "n": 4, "y": 0.4, "gap_x": 0.28, "amp": 0.0},
	"borer_emerge": {"enemy": "root_borer", "kind": "bottom", "n": 3, "y": 0.8, "gap_x": 0.5},
	"grub_crawl": {"enemy": "larva_grub", "kind": "line", "n": 2, "y": 0.45, "gap_y": 0.2, "gap_x": 160.0},
	"root_wall": {"enemy": "root_borer", "kind": "top_bottom", "n": 4, "y": 0.5, "gap_x": 0.42},
	"reed_leap": {"enemy": "reed_jumper", "kind": "line", "n": 6, "y": 0.66, "gap_y": 0.05, "gap_x": 28.0},
	"pike_rush": {"enemy": "pike_fry", "kind": "column", "n": 4, "y": 0.55, "gap_x": 0.22},
	"mosquito_arc": {"enemy": "mosquito_pair", "kind": "pair", "n": 4, "y": 0.45, "gap_y": 0.25},
	"dragonfly_dash": {"enemy": "dragonfly_sniper", "kind": "arc", "n": 3, "y": 0.4, "gap_x": 80.0},
	"spore_field": {"enemy": "spore_drifter", "kind": "line", "n": 4, "y": 0.3, "gap_y": 0.2, "gap_x": 130.0},
	"mushroom_guard": {"enemy": "mushroom_cap", "kind": "pair", "n": 2, "y": 0.5, "gap_y": 0.34},
	"vine_sweep": {"enemy": "thorn_vine", "kind": "top_bottom", "n": 4, "y": 0.5, "gap_x": 0.35},
	"mantis_hunt": {"enemy": "mantis_stalker", "kind": "line", "n": 2, "y": 0.4, "gap_y": 0.25, "gap_x": 140.0},
	"wind_gust": {"enemy": "wasp_dart", "kind": "column", "n": 5, "y": 0.5, "gap_x": 0.2},
	"glass_drone_row": {"enemy": "glass_drone", "kind": "line", "n": 3, "y": 0.38, "gap_y": 0.2, "gap_x": 100.0},
	"mirror_orbit": {"enemy": "mirror_orb", "kind": "pair", "n": 2, "y": 0.5, "gap_y": 0.3},
	"crawler_row": {"enemy": "canal_crawler", "kind": "line", "n": 3, "y": 0.6, "gap_y": 0.14, "gap_x": 110.0},
	"sludge_field": {"enemy": "sludge_blob", "kind": "line", "n": 3, "y": 0.35, "gap_y": 0.22, "gap_x": 140.0},
	"piston_charge": {"enemy": "piston_drone", "kind": "column", "n": 3, "y": 0.45, "gap_x": 0.35},
	"generator_order": {"enemy": "generator_unit", "kind": "pair", "n": 2, "y": 0.5, "gap_y": 0.3},
	"hive_guard_row": {"enemy": "hive_guard", "kind": "line", "n": 3, "y": 0.4, "gap_y": 0.2, "gap_x": 120.0},
	"acolyte_orbit": {"enemy": "queen_acolyte", "kind": "arc", "n": 4, "y": 0.5, "gap_x": 60.0},
	"pollen_pod": {"enemy": "spore_drifter", "kind": "line", "n": 3, "y": 0.32, "gap_y": 0.16, "gap_x": 140.0},
	"sluice_current": {"enemy": "canal_crawler", "kind": "bottom", "n": 4, "y": 0.86, "gap_x": 0.22},
	"press_wall": {"enemy": "piston_drone", "kind": "top_bottom", "n": 4, "y": 0.5, "gap_x": 0.36},
	"core_pulse": {"enemy": "core_shard", "kind": "arc", "n": 5, "y": 0.5, "gap_x": 52.0, "amp": 40.0},
	"shard_orbit": {"enemy": "core_shard", "kind": "cluster", "n": 5, "y": 0.5, "gap_x": 50.0},
}

const HAZARDS := {
	"blossom": {"interval": 7.0, "kind": "blossom"},
	"roots": {"interval": 5.5, "kind": "root_spike"},
	"water": {"interval": 4.5, "kind": "water_splash"},
	"spores": {"interval": 6.0, "kind": "spore_cloud"},
	"wind": {"interval": 8.0, "kind": "wind_zone"},
	"glass": {"interval": 7.5, "kind": "reflect_panel"},
	"currents": {"interval": 9.0, "kind": "current"},
	"order": {"interval": 9.0, "kind": "generator_relay"},
	"combined": {"interval": 6.0, "kind": "wind_zone"},
	"core": {"interval": 7.0, "kind": "gravity_field"},
}

var level_data: Dictionary = {}
var level_index: int = 1
var mode: String = "campaign"
var time: float = 0.0
var section: int = 0
var section_t: float = 0.0
var spawn_t: float = 1.0
var hazard_t: float = 4.0
var checkpoint_index: int = 0
var miniboss_done := false
var boss_started := false
var paused_script := false
var mechanic := ""
var mechanic_rng := RandomNumberGenerator.new()
var visual_rng := RandomNumberGenerator.new()
var spawn_rng := RandomNumberGenerator.new()
var section_pools: Array = []
var enemies_spawned := 0
var checkpoint_times: Array = []
var level_duration: float = 0.0
var intro_t: float = 2.2
var finished := false
var last_formation := ""
## Wartezeit zwischen Miniboss und Boss am Abschnittsende. Läuft als Spielzeit
## (nicht als SceneTree-Timer), damit Pause, Tod und Checkpoint sie mitnehmen.
const FINISH_WAIT := 6.0
## Ruhige Startphase vor dem ersten Abschnitt; die Levelmusik beginnt mit ihr.
const INTRO_TIME := 2.2
var finish_wait := 0.0
## R4: eigene Zufallsquelle für Hinterhalte und Bodengegner, damit die
## bestehenden, per Saatwert reproduzierbaren Wellen unverändert bleiben.
var extra_rng := RandomNumberGenerator.new()
var ambush_t := 12.0
var ground_t := 14.0

## Leveldruck unabhängig von Waffenstärke: mehr Begegnungen und dichteres Feuer,
## nicht bloß größere HP-Säcke. Harte Grenzen halten auch taktische0-Builds spielbar.
static func pressure_for_level(index: int) -> Dictionary:
	var step := float(clampi(index, 1, 10) - 1)
	return {"spawn_mult": 1.0 + 0.05 * step, "fire_mult": 1.0 + 0.04 * step,
		"enemy_hp": 1.0 + 0.10 * step, "boss_hp": 1.0 + 0.17 * step}

func setup(data: Dictionary, index: int, run_mode: String, seed_value: int, checkpoint: int) -> void:
	level_data = data
	level_index = index
	mode = run_mode
	mechanic = String(data.get("mechanic", "blossom"))
	mechanic_rng.seed = seed_value * 31 + index
	visual_rng.seed = seed_value * 7919 + index * 13
	spawn_rng.seed = seed_value * 104729 + index * 7
	extra_rng.seed = seed_value * 7703 + index * 31
	checkpoint_index = checkpoint
	checkpoint_times.clear()
	var acc := 0.0
	checkpoint_times.append(0.0)
	for i in range(data.sections.size()):
		acc += float(data.sections[i].dur)
		if i < data.sections.size() - 1:
			checkpoint_times.append(acc)
	level_duration = acc
	_restart_from_checkpoint(checkpoint)

func _restart_from_checkpoint(cp: int) -> void:
	checkpoint_index = cp
	section = mini(cp, maxi(0, level_data.sections.size() - 1))
	time = checkpoint_times[mini(cp, checkpoint_times.size() - 1)]
	section_t = 0.0
	spawn_t = 2.5
	hazard_t = 5.0
	ambush_t = 12.0
	ground_t = 14.0
	miniboss_done = cp > 0
	boss_started = false
	finished = false
	finish_wait = 0.0
	last_formation = ""
	intro_t = 1.4 if cp > 0 else INTRO_TIME
	section_changed.emit(section)

func start_boss_now() -> void:
	if boss_started:
		return
	boss_started = true
	boss_triggered.emit()

func update(delta: float) -> void:
	if finished:
		return
	if intro_t > 0.0:
		intro_t -= delta
		return
	time += delta
	section_t += delta
	# Boss-Rush und Übungsflug: keine Abschnitte, Wellen, Hindernisse oder Bosse.
	if mode == "rush" or mode == "tutorial":
		return
	if finish_wait > 0.0:
		finish_wait -= delta
		if finish_wait <= 0.0:
			finish_wait = 0.0
			_trigger_boss()
	if section < level_data.sections.size():
		var sec: Dictionary = level_data.sections[section]
		if section_t >= float(sec.dur):
			section += 1
			section_t = 0.0
			if section < level_data.sections.size():
				checkpoint_index = section
				checkpoint_reached.emit(section)
				section_changed.emit(section)
			else:
				_finish_sections()
			return
		_update_spawner(delta, sec)
		_update_extras(delta)
	_update_hazards(delta)
	if not miniboss_done and float(level_data.get("miniboss", {}).get("t", 1e9)) <= time:
		miniboss_done = true
		miniboss_started.emit()

## Ruhige Passage = kaum Gegner im Bild. Dann kommen Hornissen von hinten oder
## eine Spinne von oben; unabhängig davon patrouillieren Bodengegner.
func _update_extras(delta: float) -> void:
	if mode not in ["campaign", "training"]:
		return
	ambush_t -= delta
	ground_t -= delta
	var game := get_parent()
	var live := 0
	if game != null and "enemies" in game:
		for e in game.enemies:
			if is_instance_valid(e) and not e.dead:
				live += 1
	if ambush_t <= 0.0 and live <= 2:
		ambush_t = extra_rng.randf_range(10.0, 15.0)
		if extra_rng.randf() < 0.5:
			var y := extra_rng.randf_range(App.PLAY_TOP + 60.0, App.PLAY_BOTTOM - 70.0)
			for i in range(2 if level_index >= 3 else 1):
				_spawn("hornet_flank", Vector2(-60.0, y + i * 46.0), {"target_x": 420.0 + i * 90.0})
		else:
			for i in range(1 + int(level_index >= 4)):
				var x := extra_rng.randf_range(420.0, 820.0)
				_spawn("web_spider", Vector2(x, -30.0), {"hang_y": extra_rng.randf_range(140.0, 300.0)})
	elif ambush_t <= 0.0:
		ambush_t = 2.0
	if ground_t <= 0.0:
		ground_t = extra_rng.randf_range(11.0, 16.0)
		if extra_rng.randf() < 0.55:
			for i in range(2):
				_spawn("ant_gunner", Vector2(1000.0 + i * 70.0, App.PLAY_BOTTOM - 20.0), {})
		else:
			for i in range(2):
				_spawn("mole_cricket", Vector2(extra_rng.randf_range(380.0, 860.0), App.PLAY_BOTTOM + 30.0), {})

func _finish_sections() -> void:
	if not miniboss_done:
		miniboss_done = true
		miniboss_started.emit()
		finish_wait = FINISH_WAIT
		return
	_trigger_boss()

func _trigger_boss() -> void:
	if not boss_started:
		boss_started = true
		boss_triggered.emit()

func _running_difficulty() -> Dictionary:
	var game := get_parent()
	if game != null and game.has_method("current_push"):
		var current: Dictionary = game.get("difficulty")
		if not current.is_empty():
			return current
	var name := String(Save.campaign.get("difficulty", Save.g("game.difficulty", "normal")))
	return Data.DIFFICULTY.get(name, Data.DIFFICULTY["normal"])

func _update_spawner(delta: float, sec: Dictionary) -> void:
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	var diff_mult := float(_running_difficulty().spawn_mult)
	var level_spawn := float(pressure_for_level(level_index).spawn_mult)
	spawn_t = maxf(2.4, spawn_rng.randf_range(3.2, 5.2) / (diff_mult * level_spawn))
	var pools: Array = sec.pools
	spawn_formation(_select_formation(pools))
	# gelegentlich zweite Welle für Dichte in späteren Abschnitten
	if section >= 2 and spawn_rng.randf() < 0.35 * diff_mult:
		spawn_formation(_select_formation(pools), 0.9)

## Nur handgebaute Abschnittsformationen, aber keine direkte Wiederholung, wenn
## eine Alternative existiert. Keine zusätzlichen RNG-Aufrufe für den Fallback.
func _select_formation(pools: Array) -> String:
	var pool: Array = pools[spawn_rng.randi_range(0, pools.size() - 1)]
	var selected := String(pool[spawn_rng.randi_range(0, pool.size() - 1)])
	if selected == last_formation:
		for candidates in pools:
			for candidate in candidates:
				if String(candidate) != last_formation:
					selected = String(candidate)
					break
			if selected != last_formation:
				break
	last_formation = selected
	return selected

func spawn_formation(name: String, hp_scale: float = 1.0) -> void:
	if not FORMATIONS.has(name):
		return
	var f: Dictionary = FORMATIONS[name]
	var enemy_id := String(f.enemy)
	var n := int(f.n)
	# Startbahn so begrenzen, dass Musterschwankungen nicht unter die Leiste laufen
	var base_y := clampf(float(f.y) * App.PLAY_BOTTOM, 72.0, App.PLAY_BOTTOM - 84.0)
	var opts := {"hp_mult": hp_scale}
	match String(f.kind):
		"line":
			for i in range(n):
				var y := base_y + (float(i) - float(n - 1) * 0.5) * float(f.get("gap_y", 0.1)) * App.PLAY_BOTTOM
				var x := 1010.0 + i * float(f.get("gap_x", 0.0))
				_spawn(enemy_id, Vector2(x, y), opts.merged({"amp": f.get("amp", 40.0)}, true))
		"arc":
			for i in range(n):
				var t := float(i) / float(maxi(1, n - 1))
				var y2 := base_y + sin(t * PI) * -70.0
				_spawn(enemy_id, Vector2(1010.0 + t * 90.0 + i * float(f.get("gap_x", 40.0)), y2), opts)
		"cluster":
			for i in range(n):
				var a := TAU * float(i) / float(n)
				var p := Vector2(1040, base_y) + Vector2(cos(a), sin(a)) * (30.0 + float(i % 3) * 22.0)
				_spawn(enemy_id, p, opts)
		"pair":
			for i in range(n):
				var y3 := base_y + (-1.0 if i % 2 == 0 else 1.0) * float(f.get("gap_y", 0.3)) * App.PLAY_BOTTOM * 0.5
				_spawn(enemy_id, Vector2(1010.0 + i * 40.0, y3), opts.merged({"mirror": 1.0 if i % 2 == 0 else -1.0}, true))
		"column":
			for i in range(n):
				_spawn(enemy_id, Vector2(1010.0 + i * float(f.get("gap_x", 0.3)) * 400.0, base_y), opts)
		"bottom":
			for i in range(n):
				_spawn(enemy_id, Vector2(680.0 + i * 90.0, App.PLAY_BOTTOM + 20.0), opts)
		"top_bottom":
			for i in range(n):
				var from_top := i % 2 == 0
				_spawn(enemy_id, Vector2(1010.0 + i * float(f.get("gap_x", 0.4)) * 300.0, -20.0 if from_top else App.PLAY_BOTTOM + 30.0),
					opts.merged({"mirror": 1.0 if from_top else -1.0}, true))
		_:
			for i in range(n):
				_spawn(enemy_id, Vector2(1010.0 + i * 40.0, base_y), opts)
	enemies_spawned += n

func _spawn(enemy_id: String, pos: Vector2, opts: Dictionary) -> void:
	spawn_enemy_requested.emit(enemy_id, pos, opts)

func _update_hazards(delta: float) -> void:
	if mode != "campaign" and mode != "training":
		return
	hazard_t -= delta
	if hazard_t > 0.0:
		return
	var h: Dictionary = HAZARDS.get(mechanic, HAZARDS["blossom"])
	hazard_t = float(h.interval) * mechanic_rng.randf_range(0.8, 1.25)
	hazard_requested.emit(String(h.kind), {
		"y": mechanic_rng.randf_range(0.15, 0.85),
		"dir": 1.0 if mechanic_rng.randf() < 0.5 else -1.0,
	})

func section_start_time(idx: int) -> float:
	return checkpoint_times[clampi(idx, 0, checkpoint_times.size() - 1)]

## Laufzeitschätzung für HUD und Pause: Fortschritt bis zum Boss, Restsekunden
## (inklusive Intro und Miniboss-Wartezeit) und Checkpoint-Markierungen (0..1).
## Position in der durchkomponierten Levelmusik (Sekunden): Intro + Levelzeit.
## Nach einem Checkpoint-Neustart läuft das kürzere Intro bis zur Abschnittsgrenze.
func music_pos() -> float:
	return INTRO_TIME + time - maxf(0.0, intro_t)

func eta() -> Dictionary:
	var total := maxf(1.0, level_duration)
	var marks: Array = []
	for i in range(1, checkpoint_times.size()):
		marks.append(clampf(float(checkpoint_times[i]) / total, 0.0, 1.0))
	var mini_t := float(level_data.get("miniboss", {}).get("t", -1.0))
	var phase := "run"
	var remaining := maxf(0.0, level_duration - time) + maxf(0.0, intro_t)
	if boss_started:
		phase = "boss"
		remaining = 0.0
	elif finish_wait > 0.0 or section >= level_data.get("sections", []).size():
		phase = "wait"
		remaining = finish_wait
	elif not miniboss_done and (mini_t < 0.0 or mini_t >= level_duration):
		remaining += FINISH_WAIT
	return {"progress": 1.0 if phase != "run" else clampf(time / total, 0.0, 1.0),
		"remaining": remaining, "phase": phase, "marks": marks,
		"miniboss": clampf(mini_t / total, 0.0, 1.0) if mini_t >= 0.0 and mini_t < level_duration else -1.0,
		"checkpoint": checkpoint_index, "total": total + FINISH_WAIT}

func progress() -> float:
	if level_duration <= 0.0:
		return 0.0
	return clampf(time / level_duration, 0.0, 1.0)

func miniboss_config() -> Dictionary:
	return level_data.get("miniboss", {})
