extends Node
## Getrennte, versionierte Speicherung von Profil, Kampagne und Einstellungen.
## Schreibvorgänge sind atomar (tmp -> rename) und halten eine .bak-Sicherung.

const VERSION := 1
const DIR := "user://saves"
## So oft darf ein Lauf scheitern, bevor er vorbei ist (drei Versuche gesamt).
const MAX_CONTINUES := 3
## Pro Modus/Schwierigkeit maximal 20 echte Läufe; Ansichten können Top 10 zeigen.
const HIGHSCORE_BUCKET_LIMIT := 20
const HIGHSCORE_MODES := ["campaign", "rush"]
const HIGHSCORE_DIFFICULTIES := ["relaxed", "normal", "expert"]
## JSON-Zahlen müssen beim Laden exakt darstellbar bleiben.
const MAX_SCORE := 9007199254740991

var settings: Dictionary = {}
var profile: Dictionary = {}
var campaign: Dictionary = {}
var active_campaign: bool = false
var last_load_note: String = ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_migrate_legacy_saves()
	settings = _default_settings()
	profile = _default_profile()
	campaign = {}
	load_settings()
	load_profile()
	load_campaign()

# ------------------------------------------------------------------ Standards
func _default_settings() -> Dictionary:
	return {
		"version": VERSION,
		"display": {
			"monitor": 0, "resolution": 1, "window_mode": "window",
			"vsync": true, "fps_cap": 0, "scaling": "pixel_plus_ui", "ui_size": 100,
		},
		"graphics": {
			"effects": 1.0, "particles": 1.0, "shake": 0.6, "flashes": true,
			"post": true, "crt": false,
		},
		"audio": {
			"master": 0.9, "music": 0.75, "sfx": 0.85, "ui": 0.7, "mute_unfocused": true, "voice_upgrades": true,
		},
		"controls": {
			"deadzone": 0.22, "sensitivity": 1.0, "vibration": true, "vibration_strength": 0.6,
			"bindings": {},
		},
		"game": {
			"difficulty": "normal", "autofire_default": false, "tutorial": true, "hitbox": false,
			"language": "de",
		},
		"access": {
			"font_scale": 1.0, "reduce_effects": false, "contrast_hazards": true,
		},
	}

func _default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"unlocked_evolutions": [],
		"fusions_seen": [],
		"tutorial_done": false,
		"tutorial_offered": false,
		"boss_rush_unlocked": false,
		"campaigns_started": 0,
		"best": {},          # key: mode|difficulty|level|seed -> score entry
		"highscores": [],   # echte Run-Totals; alte Levelbestwerte bleiben separat
		"highscore_seq": 0,
		"highscore_runs": {}, # run_id -> unveränderliche Bucket-/Sequenz-Identität
		"last_start_talent": "",
		"totals": {"kills": 0, "deaths": 0, "playtime": 0.0},
	}

## Kumulativ verdiente Punkte sind unabhängig vom ausgebbaren Werkstattguthaben.
## Alte Läufe erhalten eine konservative Schätzung, keine erfundenen Levelbestwerte.
func ensure_run_score() -> void:
	if campaign.is_empty():
		return
	var id: Variant = campaign.get("run_id", "")
	if not (id is String) or id.strip_edges().is_empty():
		campaign["run_id"] = Crypto.new().generate_random_bytes(16).hex_encode()
	var total: Variant = campaign.get("run_score")
	if not _is_score_integer(total) or int(total) < 0:
		var level_total := 0
		var stats: Variant = campaign.get("level_stats", {})
		if stats is Dictionary:
			for value in stats.values():
				if value is Dictionary and _is_score_integer(value.get("score")):
					level_total = mini(MAX_SCORE, level_total + maxi(0, int(value.score)))
		var wallet: Variant = campaign.get("points", 0)
		var wallet_total := maxi(0, int(wallet)) if _is_score_integer(wallet) else 0
		campaign["run_score"] = maxi(wallet_total, level_total)
		campaign["legacy_score_estimate"] = true
	else:
		campaign["run_score"] = int(total)

## Nur positive Einnahmen; häufige Kill-Credits lösen keinen Diskzugriff aus.
func add_run_score(amount: int) -> void:
	var application := get_node_or_null("/root/App")
	if campaign.is_empty() or (application != null and application.mode == "training"):
		return
	if amount <= 0:
		return
	ensure_run_score()
	campaign["run_score"] = int(campaign.run_score) + mini(amount, MAX_SCORE - int(campaign.run_score))

## Werkstattkauf: ausgegebene Punkte schmälern den Highscore des Laufs
## (Abwägung zwischen Stärke und Wertung). Nie unter null.
func spend_run_score(amount: int) -> void:
	if campaign.is_empty() or amount <= 0:
		return
	ensure_run_score()
	campaign["run_score"] = maxi(0, int(campaign.run_score) - amount)

func new_campaign(difficulty: String, seed_value: int) -> Dictionary:
	campaign = {
		"version": VERSION,
		"difficulty": difficulty,
		"seed": seed_value,
		"level": 1,
		"checkpoint": 0,
		"hp": 3,
		"max_hp": 3,
		"nectar": 0,
		"points": 0,
		"run_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"run_score": 0,
		"weapon": "base",
		"upgrades": {"base": 1, "fan": 0, "lightning": 0, "plasma": 0,
					 "companion": 0, "bombs": 0, "shield": 0, "speed": 0},
		"speed_level": 0,
		"evolutions": [],
		"shop": {},         # Werkstatt: id -> gekaufte Stufe
		"start_talent": "",
		"rewarded_levels": [],
		"pending": {},      # offene Evolutionsentscheidung
		"level_stats": {},
		"level_scores": {},
		"completed": false,
		"deaths": 0,        # Game Over in diesem Lauf (nach 3 ist der Run vorbei)
		"created": Time.get_unix_time_from_system(),
	}
	active_campaign = true
	return campaign

## Bosse, die im laufenden Run schon besiegt wurden (in Level-Reihenfolge); nur diese
## stehen im Boss-Rush zur Wahl.
func run_bosses() -> Array:
	var out: Array = []
	if not active_campaign or campaign.is_empty():
		return out
	var levels: Array = []
	for k in (campaign.get("level_stats", {}) as Dictionary).keys():
		levels.append(int(k))
	levels.sort()
	for lv in levels:
		var b := String(Data.level(lv).get("boss", ""))
		if b != "" and not out.has(b):
			out.append(b)
	return out

## Run beenden: Die Kampagne wird gelöscht, das Profil (Evolutionen, Bestwerte)
## bleibt erhalten. Im Hauptmenü gibt es dann kein „Fortsetzen“ mehr.
func end_campaign() -> void:
	clear_campaign()

func clear_campaign() -> void:
	campaign = {}
	active_campaign = false
	# Kein beendeter Run darf nach Neustart aus einem alten Backup wiederkehren.
	for suffix in ["", ".bak", ".tmp"]:
		_remove_file(_path("campaign") + suffix)

# ---------------------------------------------------------------- Pfad/IO
## Die Umbenennung ändert Godots user://-Ordner. Nur fehlende Dateien übernehmen;
## alte Originale und bereits vorhandene Stingforge-Spielstände nie überschreiben.
## Derselbe Elternordner funktioniert unter Linux und Windows (app_userdata).
func _migrate_legacy_saves() -> void:
	var current_dir := OS.get_user_data_dir()
	if current_dir.get_file() != "Stingforge":
		return
	var legacy_dir := current_dir.get_base_dir().path_join("Apidya Reimagined/saves")
	if not DirAccess.dir_exists_absolute(legacy_dir):
		return
	var migrated := false
	for name in ["settings", "profile", "campaign"]:
		var target := ProjectSettings.globalize_path(_path(name))
		if FileAccess.file_exists(target) or FileAccess.file_exists(target + ".bak"):
			continue
		var original := legacy_dir.path_join(name + ".save")
		var source := original
		if _read_json(source) == null:
			source += ".bak"
		if _read_json(source) == null:
			continue
		# Erst verifiziertes temporäres Duplikat, dann atomar als neue Datei ablegen.
		var temporary := target + ".migrating"
		if DirAccess.copy_absolute(source, temporary) != OK or _read_json(temporary) == null:
			push_warning(Loc.tx("Alter Spielstand konnte nicht übernommen werden: ") + name)
			continue
		if DirAccess.rename_absolute(temporary, target) != OK:
			push_warning(Loc.tx("Übernommener Spielstand konnte nicht abgelegt werden: ") + name)
			continue
		if _read_json(original + ".bak") != null:
			DirAccess.copy_absolute(original + ".bak", target + ".bak")
		migrated = true
	if migrated:
		last_load_note = "Vorhandener Spielstand nach Stingforge übernommen"

func _path(name: String) -> String:
	return DIR + "/" + name + ".save"

func _remove_file(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _read_json(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	# Erwartete defekte Dateien werden über .bak abgefangen, ohne Engine-Error-Spam.
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		return null
	var parsed: Variant = parser.data
	if parsed is Dictionary:
		return parsed
	return null

func _write_json(p: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error(Loc.tx("Speichern fehlgeschlagen: ") + tmp)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	# Prüfen, dann tauschen, alte Datei als .bak behalten.
	var check: Variant = _read_json(tmp)
	if not (check is Dictionary):
		push_error(Loc.tx("Speicherdatei unlesbar: ") + tmp)
		return false
	var gpath := ProjectSettings.globalize_path(p)
	var gt := ProjectSettings.globalize_path(tmp)
	var gb := ProjectSettings.globalize_path(p + ".bak")
	var rotated := false
	if FileAccess.file_exists(p):
		if _read_json(p) != null:
			if FileAccess.file_exists(p + ".bak") and DirAccess.remove_absolute(gb) != OK:
				push_error(Loc.tx("Sicherung konnte nicht erneuert werden: ") + p)
				return false
			if DirAccess.rename_absolute(gpath, gb) != OK:
				push_error(Loc.tx("Vorheriger Spielstand konnte nicht gesichert werden: ") + p)
				return false
			rotated = true
		else:
			# Nach Backup-Recovery nie die gute .bak mit der defekten Datei ersetzen.
			if DirAccess.remove_absolute(gpath) != OK:
				push_error(Loc.tx("Defekter Spielstand konnte nicht ersetzt werden: ") + p)
				return false
	if DirAccess.rename_absolute(gt, gpath) != OK:
		if rotated:
			DirAccess.copy_absolute(gb, gpath)
		push_error(Loc.tx("Neuer Spielstand konnte nicht abgelegt werden: ") + p)
		return false
	return true

func _load_with_backup(name: String) -> Variant:
	var p := _path(name)
	var d: Variant = _read_json(p)
	if d != null:
		return d
	var b: Variant = _read_json(p + ".bak")
	if b != null:
		last_load_note = name + Loc.tx(" aus Sicherung geladen")
		return b
	return null

# ---------------------------------------------------------------- Laden/Sichern
func load_settings() -> void:
	var d: Variant = _load_with_backup("settings")
	if d is Dictionary:
		settings = _merge_defaults(_default_settings(), d)
	else:
		settings = _default_settings()

func load_profile() -> void:
	var d: Variant = _load_with_backup("profile")
	profile = _merge_defaults(_default_profile(), d if d is Dictionary else {})
	_normalize_highscores()

func load_campaign() -> void:
	var d: Variant = _load_with_backup("campaign")
	if d is Dictionary and d.has("level"):
		campaign = d
		active_campaign = true
		var prior_id: Variant = campaign.get("run_id")
		var prior_score: Variant = campaign.get("run_score")
		ensure_run_score()
		if campaign.run_id != prior_id or campaign.run_score != prior_score:
			save_campaign()
	else:
		campaign = {}
		active_campaign = false

func save_settings() -> void:
	_write_json(_path("settings"), settings)

func save_profile() -> void:
	_write_json(_path("profile"), profile)

func save_campaign() -> void:
	if active_campaign and not campaign.is_empty():
		ensure_run_score()
		_write_json(_path("campaign"), campaign)

func save_all() -> void:
	save_settings()
	save_profile()
	save_campaign()

func _merge_defaults(def: Dictionary, got: Variant) -> Dictionary:
	if not (got is Dictionary):
		return def.duplicate(true)
	# Leere Dictionaries sind offene Karten (Bestwerte, Belegungen), kein Schema.
	# Ihre gespeicherten Schlüssel müssen beim Laden vollständig erhalten bleiben.
	if def.is_empty():
		return got.duplicate(true)
	var out := {}
	for k in def:
		# JSON.parse_string liefert auch ganze Zahlen als float. Zähler/Sequenz
		# nicht wegen dieses Darstellungsunterschieds auf den Standard zurücksetzen.
		if got.has(k) and def[k] is int and _is_score_integer(got[k]):
			out[k] = int(got[k])
		elif got.has(k) and typeof(got[k]) == typeof(def[k]):
			if def[k] is Dictionary:
				out[k] = _merge_defaults(def[k], got[k])
			else:
				out[k] = got[k]
		else:
			out[k] = def[k].duplicate(true) if def[k] is Dictionary or def[k] is Array else def[k]
	return out

# ---------------------------------------------------------------- Hilfszugriffe
func g(path: String, fallback: Variant = null) -> Variant:
	var parts := path.split(".")
	var cur: Variant = settings
	for p in parts:
		if not (cur is Dictionary) or not cur.has(p):
			return fallback
		cur = cur[p]
	return cur

func set_g(path: String, value: Variant) -> void:
	var parts := path.split(".")
	var cur: Dictionary = settings
	for i in range(parts.size() - 1):
		if not cur.has(parts[i]) or not (cur[parts[i]] is Dictionary):
			cur[parts[i]] = {}
		cur = cur[parts[i]]
	cur[parts[parts.size() - 1]] = value
	save_settings()

func reset_settings_section(section: String) -> void:
	var def := _default_settings()
	if section == "all":
		var keep: Variant = settings.controls.bindings
		settings = def
		settings.controls.bindings = keep if keep != null else {}
	elif def.has(section):
		settings[section] = def[section]
	save_settings()

# ---------------------------------------------------------------- Profil
func unlock_evolution(id: String) -> bool:
	var arr: Array = profile.unlocked_evolutions
	if arr.has(id):
		return false
	arr.append(id)
	save_profile()
	return true

## Verschmelzungen im Profil: einmal entdeckt, bleiben sie in der Übersicht sichtbar.
func discover_fusion(key: String) -> bool:
	var arr: Array = profile.get("fusions_seen", [])
	if arr.has(key):
		return false
	arr.append(key)
	profile["fusions_seen"] = arr
	save_profile()
	return true

func is_fusion_seen(key: String) -> bool:
	return (profile.get("fusions_seen", []) as Array).has(key)

func is_evolution_unlocked(id: String) -> bool:
	return profile.unlocked_evolutions.has(id)

# ------------------------------------------------------------ Run-Ranglisten
func _is_score_integer(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= MAX_SCORE

## Kanonische Einträge halten falsche Modi, Training und kaputte Daten fern.
func _highscore_entry(entry: Dictionary) -> Dictionary:
	for key in ["run_id", "mode", "difficulty"]:
		if not (entry.get(key) is String):
			return {}
	var id: String = entry.run_id.strip_edges()
	if id.is_empty() or id.length() > 128 or "\n" in id or "\r" in id:
		return {}
	if entry.mode not in HIGHSCORE_MODES or entry.difficulty not in HIGHSCORE_DIFFICULTIES:
		return {}
	if bool(entry.get("training", false)):
		return {}
	var score: Variant = entry.get("score")
	var level: Variant = entry.get("level", 1)
	var seed_value: Variant = entry.get("seed", 0)
	if not _is_score_integer(score) or int(score) < 0:
		return {}
	if not _is_score_integer(level) or int(level) < 1 or int(level) > 10:
		return {}
	if not _is_score_integer(seed_value) or not (entry.get("completed", false) is bool):
		return {}
	var pilot: String = entry.get("pilot", "Yuri") if entry.get("pilot", "Yuri") is String else "Yuri"
	pilot = pilot.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").left(32)
	if pilot.is_empty(): pilot = "Yuri"
	return {"run_id": id, "mode": entry.mode, "difficulty": entry.difficulty,
		"score": int(score), "level": int(level), "completed": bool(entry.get("completed", false)),
		"seed": int(seed_value), "pilot": pilot,
		"legacy_score_estimate": bool(entry.get("legacy_score_estimate", false))}

## Vollständige, deterministische Ordnung; die Uhrzeit ist kein Tie-Breaker.
func _highscore_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.score) != int(b.score): return int(a.score) > int(b.score)
	if bool(a.completed) != bool(b.completed): return bool(a.completed)
	if int(a.level) != int(b.level): return int(a.level) > int(b.level)
	if int(a.seq) != int(b.seq): return int(a.seq) < int(b.seq)
	return String(a.run_id) < String(b.run_id)

func _trim_highscores(rows: Array) -> Array:
	rows.sort_custom(_highscore_before)
	var counts: Dictionary = {}
	var kept: Array = []
	for row in rows:
		var bucket: String = row.mode + "|" + row.difficulty
		var count := int(counts.get(bucket, 0))
		if count < HIGHSCORE_BUCKET_LIMIT:
			kept.append(row)
			counts[bucket] = count + 1
	return kept

## Kleine dauerhafte Quittung auch für aus Top20 verdrängte Läufe. So bleiben
## Bucket, Sequenz, Sieg und maximale Stufe bei späteren Wiederholungen erhalten.
func _highscore_receipt(row: Dictionary) -> Dictionary:
	return {"seq": int(row.seq), "mode": row.mode, "difficulty": row.difficulty,
		"score": int(row.score), "level": int(row.level), "completed": bool(row.completed),
		"legacy_score_estimate": bool(row.get("legacy_score_estimate", false))}

## Namenseingabe nach einem Lauf: Pilotennamen eines bereits gespeicherten Eintrags
## setzen und als Vorschlag für den nächsten Lauf merken.
func rename_highscore(run_id: String, pilot: String) -> bool:
	var name := pilot.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ").left(12)
	if name.is_empty():
		return false
	_normalize_highscores()
	var changed := false
	for row in profile.highscores:
		if String(row.run_id) == run_id:
			row.pilot = name
			changed = true
	profile["last_pilot"] = name
	_write_json(_path("profile"), profile)
	return changed

## Rang (1-basiert) eines Laufs in seiner Modusliste, 0 = nicht in den Top N.
func highscore_rank(run_id: String, mode: String, limit: int = 20) -> int:
	var rows := get_highscores(mode, "all", limit)
	for i in range(rows.size()):
		if String(rows[i].run_id) == run_id:
			return i + 1
	return 0

func _preserve_highscore_progress(row: Dictionary, previous: Dictionary) -> void:
	# Ein schon eingetragener Name bleibt, wenn spätere Aufrufe nur den Standard liefern.
	if String(row.get("pilot", "Yuri")) == "Yuri" and String(previous.get("pilot", "Yuri")) != "Yuri":
		row.pilot = previous.pilot
	row.score = maxi(int(row.score), int(previous.get("score", 0)))
	row.completed = bool(row.completed) or bool(previous.get("completed", false))
	row.level = maxi(int(row.level), int(previous.get("level", 1)))
	row.legacy_score_estimate = bool(row.get("legacy_score_estimate", false)) or bool(previous.get("legacy_score_estimate", false))

## Repariert/validiert nur echte Run-Einträge. profile.best wird nie umgedeutet.
func _normalize_highscores() -> void:
	var receipts: Dictionary = {}
	var sequence := 0
	var stored_receipts: Variant = profile.get("highscore_runs", {})
	if stored_receipts is Dictionary:
		for id in stored_receipts:
			var receipt: Variant = stored_receipts[id]
			if not (id is String and receipt is Dictionary): continue
			if receipt.get("mode", "") not in HIGHSCORE_MODES or receipt.get("difficulty", "") not in HIGHSCORE_DIFFICULTIES: continue
			if not _is_score_integer(receipt.get("seq")) or int(receipt.seq) < 1: continue
			var prior_score: Variant = receipt.get("score", 0)
			var prior_level: Variant = receipt.get("level", 1)
			receipts[id] = {"seq": int(receipt.seq), "mode": receipt.mode, "difficulty": receipt.difficulty,
				"score": maxi(0, int(prior_score)) if _is_score_integer(prior_score) else 0,
				"level": clampi(int(prior_level), 1, 10) if _is_score_integer(prior_level) else 1,
				"completed": receipt.get("completed", false) == true,
				"legacy_score_estimate": receipt.get("legacy_score_estimate", false) == true}
			sequence = maxi(sequence, int(receipt.seq))
	var stored_seq: Variant = profile.get("highscore_seq", 0)
	if _is_score_integer(stored_seq): sequence = maxi(sequence, int(stored_seq))
	var unique: Dictionary = {}
	var stored_rows: Variant = profile.get("highscores", [])
	if stored_rows is Array:
		for value in stored_rows:
			if not (value is Dictionary): continue
			var row := _highscore_entry(value)
			if row.is_empty(): continue
			var id: String = row.run_id
			var receipt: Dictionary = receipts.get(id, {})
			if not receipt.is_empty():
				if receipt.mode != row.mode or receipt.difficulty != row.difficulty: continue
				row["seq"] = int(receipt.seq)
				_preserve_highscore_progress(row, receipt)
			else:
				var seq: Variant = value.get("seq")
				if _is_score_integer(seq) and int(seq) > 0:
					row["seq"] = int(seq)
				else:
					row["seq"] = sequence + 1
				sequence = maxi(sequence, int(row.seq))
			receipts[id] = _highscore_receipt(row)
			if not unique.has(id) or _highscore_before(row, unique[id]):
				unique[id] = row
	profile["highscores"] = _trim_highscores(unique.values())
	profile["highscore_runs"] = receipts
	profile["highscore_seq"] = sequence

## True nur bei neuer/verbesserter, tatsächlich gespeicherter Ranglistenänderung.
## Wiederholung desselben run_id ersetzt niemals seinen Bucket oder seine Sequenz.
func record_highscore(entry: Dictionary) -> bool:
	var application := get_node_or_null("/root/App")
	if application != null and application.mode == "training": return false
	var row := _highscore_entry(entry)
	if row.is_empty(): return false
	_normalize_highscores()
	var previous := profile.duplicate(true)
	var rows: Array = profile.highscores.duplicate(true)
	var receipts: Dictionary = profile.highscore_runs
	var id: String = row.run_id
	var receipt: Dictionary = receipts.get(id, {})
	if not receipt.is_empty():
		if receipt.mode != row.mode or receipt.difficulty != row.difficulty: return false
		row["seq"] = int(receipt.seq)
		_preserve_highscore_progress(row, receipt)
	else:
		row["seq"] = int(profile.highscore_seq) + 1
	for i in range(rows.size()):
		if rows[i].run_id != id: continue
		# Ein späterer Quit-/Retry-Aufruf darf einen bereits gewonnenen Lauf
		# weder entwerten noch seine erreichte Stufe oder Gesamtpunkte senken.
		_preserve_highscore_progress(row, rows[i])
		if not _highscore_before(row, rows[i]): return false
		rows.remove_at(i)
		break
	rows.append(row)
	var kept := _trim_highscores(rows)
	var next_receipt := _highscore_receipt(row)
	if not receipt.is_empty() and kept == profile.highscores and next_receipt == receipt: return false
	profile["highscores"] = kept
	receipts[id] = next_receipt
	profile["highscore_seq"] = maxi(int(profile.highscore_seq), int(row.seq))
	if not _write_json(_path("profile"), profile):
		profile = previous
		return false
	return true

## Abfrage liefert Kopien; unbekannte Filter liefern ausdrücklich keine Ergebnisse.
func get_highscores(mode: String = "campaign", difficulty: String = "all", limit: int = 10) -> Array:
	if mode not in HIGHSCORE_MODES or (difficulty != "all" and difficulty not in HIGHSCORE_DIFFICULTIES): return []
	if limit <= 0: return []
	_normalize_highscores()
	var result: Array = []
	for row in profile.highscores:
		if row.mode != mode or (difficulty != "all" and row.difficulty != difficulty): continue
		result.append(row.duplicate(true))
		if result.size() >= mini(limit, HIGHSCORE_BUCKET_LIMIT): break
	return result

func record_best(key: String, entry: Dictionary) -> bool:
	var best: Dictionary = profile.best
	var prev: Dictionary = best.get(key, {})
	var better: bool = prev.is_empty() or entry.get("score", 0) > prev.get("score", 0)
	if better:
		best[key] = entry
		save_profile()
	return better
