class_name Boss
extends Node2D
## Datengetriebener Endboss: echte Phasenwechsel, angekündigte Angriffe,
## verwundbare Zonen, abtrennbare Module und ein eigener Zeitplan
## (pausensicher, weil alle Verzögerungen über die Spiellogik laufen).

signal defeated
signal phase_changed(index: int)
signal hp_changed(hp: float, max_hp: float)

var id: String = "rose_beetle"
var def: Dictionary = {}
var hp: float = 1000.0
var max_hp: float = 1000.0
var phase: int = 0
var phase_defs: Array = []
var pattern_index: int = 0
var act_timer: float = 2.0
var age: float = 0.0
var dead := false
var vulnerable := true
var damage_mult := 1.0
var hit_flash: float = 0.0
var telegraph: float = 0.0
var telegraph_color := Color(1, 0.4, 0.4, 0.5)
var timeline: Array = []
var parts: Array = []
var move_style := "hover_mid"
var home := Vector2(760, 270)
var target := Vector2(760, 270)
var pattern_cycle: Array = []
var invuln := 0.0
var dying_t := 0.0
var body: Node2D
var core_glow: Node2D
var phase_banner_t := 0.0
## Wutfärbung, die mit jeder Phase zunimmt, und Restzeit des Leuchtbrüllens.
var rage_tint := Color.WHITE
var roar_t := 0.0
## Larve, Phase 3: Dauerregen aus Felsbrocken mit einer wandernden Lücke.
var _cave_t := 0.0
var _cave_shaft: Dictionary = {}
## Weitere angekündigte Phaseneffekte: glühender Käferpanzer, peitschender Hecht.
var _ember_t := 0.0
var _whip_t := 0.0
var name_text := ""
var weak_text := ""
var damage_scale := 1.0
var shots_this_phase := 0
var attack_in_progress := false
## Weicher Phasenwechsel: Der Boss gleitet aus seiner aktuellen Lage in das neue
## Muster, statt an eine feste Ausgangsposition zu springen.
var transition_t := 0.0
var transition_from := Vector2.ZERO
const TRANSITION_TIME := 0.9
const SPEED_NORMAL := 420.0
const SPEED_TRANSITION := 165.0
var _rng := RandomNumberGenerator.new()

var level_index: int = 1
var interval_now: float = 1.1
## Alpha-Zeilenläufe je Einzelbild: einmal auslesen, im Spiel nur Geometrie prüfen.
static var _collision_masks: Dictionary = {}
const HIT_ALPHA := 0.2

## Ein Encounter, zwei Formen – nur der tatsächliche letzte Datenboss in Level10/Rush.
const REBORN_VISUAL = preload("res://scripts/game/boss_reborn_visual.gd")
var reborn_visual: Node2D
## Mantidenpaar: zweite Mantis mit eigenem Körper, eigenem Leben und eigenen Angriffen.
## Bis eine fällt, ist hp die Summe beider; danach kämpft die Überlebende allein weiter.
const TWIN_PART := -2
const ORCHID := Color(1.0, 0.72, 0.95)
var twin: AnimatedSprite2D
var twin_pos := Vector2(660, 150)
var twin_hp := 0.0
var twin_max := 0.0
var primary_hp := 0.0
var twin_dead := true
var twin_act := 2.2
var twin_index := 0
var twin_flash := 0.0
var twin_telegraph := 0.0
const REBORN_HP_MULT := 1.75
## Scheinsieg und Wiedergeburt des Endbosses: Untergang (bis DEATH_END), Ruhe und
## Siegesgefühl (bis CALM_END), dann Grollen und Neubildung (bis REVIVE_TIME).
const REVIVE_TIME := 8.6
const DEATH_END := 2.4
const CALM_END := 5.6
var _revive_stage := 0
var _next_blast := 0.0
## Für HUD: der Boss gilt sichtbar als besiegt (kein Lebensbalken), obwohl er
## sich gerade neu bildet.
var fake_dead := false
var encounter_form := 1
var reviving := false
var revive_t := 0.0
var first_form_max_hp := 0.0
var _revive_target := Vector2.ZERO

## Grundbewegung je Tier statt generischer Muster aus den Phasendaten.
## Ansage beim Phasenwechsel (Phase 2, 3, …) je Boss.
const PHASE_LINES := {
	"rose_beetle": ["Der Panzer glüht rot!", "Letzte Wut des Käfers!"],
	"giant_larva": ["Die Larve rast durch den Boden!", "Die Höhle stürzt ein!"],
	"pike_beast": ["Der Hecht peitscht das Wasser!", "Blutrausch im Schilf!"],
	"fungus_mind": ["Die Knoten platzen auf!", "Das Pilzwesen erwacht ganz!"],
	"mantis_pair": ["Die Überlebende erbt die Klingen!", "Kreuzhieb ohne Pause!"],
	"mech_pollinator": ["Überlast – die Rotoren heulen!", "Notbetrieb: alle Systeme feuern!"],
	"mutant_skater": ["Die Pumpen laufen heiß!", "Die Rohre platzen!", "Die Kanäle fluten!"],
	"harvester": ["Neue Module fahren aus!", "Die Ernte gerät außer Kontrolle!", "Die Dreschtrommel läuft heiß!"],
	"swarm_queen": ["Der Hof schwärmt aus!", "Die Königin entfesselt sich!"],
	"core_organism": ["Der Kern schlägt schneller!", "Der Kern bricht auf!", "Alles oder nichts!"],
}
## Dauer des Leuchtbrüllens beim Phasenwechsel (s).
## Halbe Breite der sicheren Lücke im Felsregen (Weltpunkte).
const CAVE_GAP_HALF := 70.0
const ROAR_TIME := 1.1

const STYLE_BY_BOSS := {
	"rose_beetle": "beetle", "giant_larva": "larva", "pike_beast": "pike",
	"fungus_mind": "fungus", "mantis_pair": "mantis", "mech_pollinator": "pollinator",
	"mutant_skater": "skater", "harvester": "harvester", "swarm_queen": "queen",
	"core_organism": "core",
}
## Geskriptete Bewegung (Ansturm, Sprung, Abtauchen, Gleiten). Solange sie läuft,
## ruht die Grundbewegung – nichts zieht gegeneinander, nichts springt.
var motion: Dictionary = {}
## Unter dem Boden (Larve): außerhalb der Feldbegrenzung und unverwundbar.
var submerged := false
var _bounds_cache := Rect2()
var _bounds_dirty := true
var _prev_pos := Vector2.ZERO
var _vel := Vector2.ZERO
## Nächster Zeitpunkt für einen neuen Gleitpunkt (Wasserläufer, Mantis).
var _idle_next := 0.0
var _speed_mult := 1.0

func _motion(to: Vector2, dur: float, curve: String = "smooth", height: float = 0.0,
		then: Callable = Callable()) -> void:
	motion = {"from": position, "to": to, "t": 0.0, "dur": maxf(0.05, dur), "curve": curve,
		"height": height, "then": then}

## Innehalten an Ort und Stelle (nach einem Aufprall), danach weiter.
func _hold(t: float, then: Callable = Callable()) -> void:
	_motion(position, t, "linear", 0.0, then)

func _tick_motion(delta: float) -> bool:
	if motion.is_empty():
		return false
	motion.t = float(motion.t) + delta
	var k := clampf(float(motion.t) / float(motion.dur), 0.0, 1.0)
	var e := k
	match String(motion.curve):
		"smooth": e = k * k * (3.0 - 2.0 * k)
		"dash": e = k * k            # beschleunigt wie ein Ansturm
		"out": e = 1.0 - pow(1.0 - k, 3.0)   # schnell los, weich aus
		"linear": e = k
	var p: Vector2 = (motion.from as Vector2).lerp(motion.to, e)
	p.y -= sin(PI * k) * float(motion.height)
	position = p
	if k >= 1.0:
		var then: Callable = motion.then
		motion = {}
		# Weich zurück in die Grundbewegung statt eines Sprungs zum Ziel.
		transition_from = position
		# Volle Überblendzeit: die Einblendung beginnt exakt an der jetzigen Stelle.
		transition_t = TRANSITION_TIME
		if then.is_valid():
			then.call()
	return true

## Stabile Begrenzung für das Spielfeld: Körper ungedreht, Module ohne Schwingen.
## Wird nur bei Körper- oder Modulwechsel neu berechnet (kein Zittern am Rand).
func _stable_bounds() -> Rect2:
	if not _bounds_dirty:
		return _bounds_cache
	var rot := body.rotation
	body.rotation = 0.0
	var saved: Array = []
	for part in parts:
		if not part.dead and is_instance_valid(part.get("node")):
			saved.append([part.node, part.node.position])
			part.node.position = part["offset"]
	_bounds_cache = _visual_bounds().grow(6.0)
	for entry in saved:
		entry[0].position = entry[1]
	body.rotation = rot
	_bounds_dirty = false
	return _bounds_cache

## Höhe, auf der ein Bodenwesen (Larve, Pilz, Erntemaschine) steht.
func _ground_y() -> float:
	return App.PLAY_BOTTOM - _stable_bounds().end.y - 2.0

func _clamp_target(t: Vector2) -> Vector2:
	var b := _stable_bounds()
	t.y = clampf(t.y, App.PLAY_TOP - b.position.y + 2.0, App.PLAY_BOTTOM - b.end.y - 2.0)
	t.x = clampf(t.x, 520.0, 900.0)
	return t

func setup(boss_id: String, hp_mult: float = 1.0, level_no: int = 1) -> void:
	id = boss_id
	level_index = clampi(level_no, 1, 10)
	def = Data.boss(boss_id)
	name_text = String(def.get("name", ""))
	weak_text = String(def.get("weak", ""))
	max_hp = float(def.get("hp", 3000)) * hp_mult
	first_form_max_hp = max_hp
	hp = max_hp
	phase_defs = (def.get("phases", []) as Array).duplicate(true)
	_apply_level_threat()
	_rng.seed = 90210 + hash(boss_id)
	position = Vector2(1000, 270)
	home = Vector2(760, 270)
	target = home
	_apply_phase(0, true)
	_build_visuals()
	if id == "mantis_pair":
		_setup_twin()

func _build_visuals() -> void:
	var spr_name := String(def.get("sprite", "boss_beetle"))
	if Art.frame_count(spr_name) > 1:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = Art.sprite_frames(spr_name)
		anim.play("default")
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.z_index = 4
		add_child(anim)
		body = anim
	else:
		body = Sprite2D.new()
		body.texture = Art.sheet(spr_name)
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.z_index = 4
		add_child(body)
	core_glow = preload("res://scripts/game/weak_point_marker.gd").new()
	core_glow.z_index = 5
	add_child(core_glow)
	_spawn_parts()

func _spawn_parts() -> void:
	_bounds_dirty = true
	for p in parts:
		if p.get("node", null) != null and is_instance_valid(p.node):
			p.node.queue_free()
	parts.clear()
	var count := int(phase_defs[phase].get("nodes", phase_defs[phase].get("modules", 0)))
	for i in range(count):
		var spr := Sprite2D.new()
		spr.texture = Art.frame_tex("mirrororb" if id == "fungus_mind" else "generator", 0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 3
		spr.position = Vector2(-40.0 - i * 34.0, -70.0 + i * 70.0)
		add_child(spr)
		# Erntemaschine Phase 2: zähere Beschützer.
		var part_hp := max_hp * (0.13 if id == "harvester" and phase == 1 else 0.08)
		parts.append({
			"node": spr, "hp": part_hp, "max_hp": part_hp,
			"offset": Vector2(-40.0 - i * 34.0, -70.0 + i * 70.0), "phase": float(i),
			"fire_t": 1.2 + i * 0.4, "dead": false,
		})

func _apply_phase(index: int, initial: bool = false) -> void:
	phase = clampi(index, 0, phase_defs.size() - 1)
	if encounter_form == 2:
		timeline.clear()
		attack_in_progress = false
		_set_reborn_body()
	var ph: Dictionary = phase_defs[phase]
	pattern_cycle = (ph.get("patterns", []) as Array).duplicate()
	pattern_index = _rng.randi_range(0, maxi(0, pattern_cycle.size() - 1))
	move_style = String(STYLE_BY_BOSS.get(id, ph.get("move", "hover_mid")))
	if encounter_form == 2:
		move_style = "final"
	# Spätere Phasen bewegen sich lebhafter, im Rahmen des Tiers.
	_speed_mult = 1.0 + 0.22 * float(phase)
	interval_now = float(ph.get("interval", 1.1)) * _rate()
	act_timer = (1.4 if initial else 0.9) * _rate()
	if not initial:
		# Weicher Übergang: Position halten und von dort ins neue Muster gleiten.
		transition_from = position
		transition_t = TRANSITION_TIME
		invuln = 1.4
		telegraph = 0.9
		telegraph_color = Color(1.0, 0.8, 0.3, 0.35)
		phase_banner_t = 1.2
		# Die wiedergeborene Endgestalt hat eigene Phaseneffekte (reborn_visual).
		if encounter_form != 2:
			roar_t = ROAR_TIME
			rage_tint = Color(1.0, 1.0 - 0.1 * phase, 1.0 - 0.17 * phase)
			if id == "rose_beetle":
				rage_tint = Color(1.35, 0.62, 0.45)  # "Der Panzer glüht rot"
		else:
			roar_t = 0.0
			rage_tint = Color.WHITE
		var old_parts := parts.duplicate()
		phase_changed.emit(phase)
		# Geschosse der vorherigen Phase bleiben im Bild und fliegen weiter.
		_spawn_parts()
		if encounter_form != 2:
			_phase_entry(old_parts)

func _physics_process(delta: float) -> void:
	var game := get_parent()
	# Beim eigenen Phasenwechsel-Stillstand läuft der Boss weiter (Brüllen, Gleiten);
	# Angriffe sperrt dabei phase_banner_t.
	var staggered: bool = game != null and "phase_stagger" in game and float(game.phase_stagger) > 0.0
	if game != null and game.has_method("is_play_frozen") and game.is_play_frozen() and not staggered:
		return
	if dead:
		dying_t += delta
		_dying_tick(delta)
		return
	if reviving:
		_tick_reviving(delta)
		return
	var age_before := age
	age += delta
	# Pilzboss: Heilpilz samt Schirmlingen erscheint kurz nach dem Auftritt.
	if id == "fungus_mind" and age_before < 2.5 and age >= 2.5:
		_fungus_court()
	hit_flash = maxf(0.0, hit_flash - delta)
	telegraph = maxf(0.0, telegraph - delta)
	invuln = maxf(0.0, invuln - delta)
	phase_banner_t = maxf(0.0, phase_banner_t - delta)
	var show_hit := hit_flash > 0.0
	if encounter_form == 2:
		show_hit = show_hit and bool(Save.g("graphics.flashes", true)) and not bool(Save.g("access.reduce_effects", false))
	if id == "giant_larva" and phase >= 2 and not dead:
		_tick_cave_in(delta)
	if id == "rose_beetle" and phase >= 1 and not dead:
		_tick_embers(delta)
	if id == "pike_beast" and phase >= 1 and not dead and not submerged:
		_tick_whip(delta)
	if id == "mutant_skater" and phase >= 2 and not dead:
		_tick_pipes(delta)
	if roar_t > 0.0:
		_tick_roar(delta)
	else:
		body.modulate = Color(2.0, 2.0, 2.0) if show_hit else rage_tint
	if is_instance_valid(reborn_visual):
		reborn_visual.set_status(phase, -1.0, telegraph)
	core_glow.modulate.a = 0.75 + 0.25 * sin(age * 4.0)
	core_glow.position = Vector2(-46, 0)
	core_glow.visible = vulnerable
	_move(delta)
	if not twin_dead:
		_tick_twin(delta)
	_tick_timeline(delta)
	_tick_parts(delta)
	# Auch angekündigte Sprünge/Anstürme im Zeitplan dürfen nicht in den Header.
	_clamp_playfield()
	# Kein neuer Angriff mitten in einem Ansturm, Sprung oder unter der Erde.
	if not attack_in_progress and motion.is_empty() and not submerged and invuln <= 0.0 and phase_banner_t <= 0.0:
		act_timer -= delta
		if act_timer <= 0.0:
			_next_pattern()
	queue_redraw()

## Bedrohungsstufe je Level: 1 = Grundverhalten, 5 = Endkampf.
## Die Härte kommt aus Verhalten, nicht aus Lebenspunkten.
func threat_tier() -> int:
	return clampi(1 + int(float(level_index - 1) * 4.0 / 9.0 + 0.5), 1, 5)

var enrage_done := false
var _prev_style: String = ""
var move_swap_t := 0.0
var move_calls := 0

func _apply_level_threat() -> void:
	var tier := threat_tier()
	if phase_defs.is_empty():
		return
	# Ab Stufe 3: eine zusätzliche Schlussphase mit dem härtesten Muster
	if tier >= 3:
		var last: Dictionary = (phase_defs[phase_defs.size() - 1] as Dictionary).duplicate(true)
		var pats: Array = (last.get("patterns", []) as Array).duplicate()
		pats.append("aimed_spread")
		if tier >= 5:
			pats.append("cross_cut")
		last["patterns"] = pats
		last["hp"] = float(last.get("hp", 0.3)) * 0.45
		last["interval"] = float(last.get("interval", 1.0)) * 0.85
		phase_defs.append(last)
	# Ab Stufe 4: jede Phase bekommt ein zweites, engeres Muster dazu
	if tier >= 4:
		for i in range(phase_defs.size()):
			var ph: Dictionary = phase_defs[i]
			var p2: Array = (ph.get("patterns", []) as Array).duplicate()
			if not p2.has("radial"):
				p2.append("radial")
			ph["patterns"] = p2

## Angriffstakt sinkt mit dem Level (nie unter 62 %).
func _rate() -> float:
	# Spätere Level und höhere Schwierigkeit verkürzen die Pausen zwischen Angriffen.
	var diff_rate := 1.0
	var g := get_parent()
	if g != null and "difficulty" in g:
		diff_rate = float((g.difficulty as Dictionary).get("boss_rate", 1.0))
	return clampf(1.0 - 0.04 * float(level_index - 1), 0.62, 1.0) * diff_rate

## Nach einiger Zeit wechselt der Boss sein Bewegungsmuster (ab Bedrohungsstufe 4).
func _tick_move_swap(delta: float) -> void:
	if threat_tier() < 4:
		return
	move_swap_t += delta
	if move_swap_t < 7.5:
		return
	move_swap_t = 0.0
	move_calls += 1
	var alt := ["orbit", "weave", "ram_line", "drifter", "guard_sweep"]
	var want := String(alt[move_calls % alt.size()])
	if want != move_style:
		_prev_style = move_style
		move_style = want

func _move(delta: float) -> void:
	_vel = (position - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = position
	if _tick_motion(delta):
		_update_pose(delta)
		_move_parts()
		return
	var sp := _speed_mult
	var g := get_parent()
	var player_pos: Vector2 = g.player_position() if g != null and g.has_method("player_position") else Vector2(200, 270)
	match move_style:
		"beetle":
			# Schwerer Käferflug: träges, tiefes Pendeln, kaum seitlich.
			target = Vector2(780 + sin(age * 0.45 * sp) * 30.0, 268 + sin(age * 0.8 * sp) * 95.0)
		"larva":
			# Kriecht am Boden entlang, der Körper hebt und senkt sich wellenförmig.
			target = Vector2(760 + sin(age * 0.35 * sp) * 70.0, _ground_y() - absf(sin(age * 1.4 * sp)) * 10.0)
		"pike":
			# Hecht: ruhiges Schwimmen in langen Bögen, steht dann kurz in der Strömung.
			target = Vector2(770 + sin(age * 0.5 * sp) * 80.0, 300 + sin(age * 0.9 * sp) * 85.0)
		"fungus":
			# Pilz wurzelt am Boden: nur Atmen und leichtes Wiegen, kein Fliegen.
			target = Vector2(800 + sin(age * 0.3) * 12.0, _ground_y())
		"mantis":
			# Lauernd: hält still und richtet sich ruckarm auf die Höhe der Beute aus.
			# Während eines Angriffs keine neue Lauer-/Gleitbewegung.
			if age >= _idle_next and not attack_in_progress:
				_idle_next = age + randf_range(1.4, 2.2) / sp
				_motion(_clamp_target(Vector2(randf_range(720, 840), player_pos.y)), 0.6, "smooth")
			target = position
		"pollinator":
			# Rotor-Drohne: kreist um einen Anker, mit feinem Rotorzittern in der Höhe.
			var oa := age * 0.7 * sp
			target = Vector2(720 + cos(oa) * 90.0, 270 + sin(oa) * 110.0 + sin(age * 9.0) * 2.0)
		"skater":
			# Wasserläufer: gleitet ruckartig zu neuen Punkten auf Wasserbahnen, stoppt.
			# Während eines Angriffs keine neue Lauer-/Gleitbewegung.
			if age >= _idle_next and not attack_in_progress:
				_idle_next = age + randf_range(1.2, 1.9) / sp
				var lanes := [170.0, 290.0, 400.0]
				_motion(_clamp_target(Vector2(randf_range(640, 860), lanes[randi() % lanes.size()])), 0.5, "smooth")
			target = position
		"harvester":
			# Maschine auf Ketten: rollt am Boden vor und zurück.
			target = Vector2(760 + sin(age * 0.4 * sp) * 110.0, _ground_y())
		"queen":
			# Königin: elegante Acht, hoch erhoben.
			target = Vector2(760 + sin(age * 0.6 * sp) * 70.0, 250 + sin(age * 1.2 * sp) * 150.0 * 0.5)
		"core":
			# Kern: schwebt fast reglos und pulsiert.
			target = Vector2(760 + sin(age * 0.35) * 25.0, 270 + sin(age * 0.6 * sp) * 70.0)
		"final":
			target = Vector2(700 + sin(age * 0.9) * 60.0, 270 + sin(age * 1.7) * 120.0)
		_:
			target = Vector2(760, 270 + sin(age * 0.8) * 70.0)
	target = _clamp_target(target)
	var speed_cap := SPEED_NORMAL * 0.55
	if transition_t > 0.0:
		# Das neue Ziel wird weich eingeblendet, damit kein Sprung entsteht.
		transition_t = maxf(0.0, transition_t - delta)
		var k := clampf(1.0 - transition_t / TRANSITION_TIME, 0.0, 1.0)
		var eased := k * k * (3.0 - 2.0 * k)
		target = transition_from.lerp(target, eased)
		speed_cap = SPEED_TRANSITION
	if position.x > 900:
		position.x = move_toward(position.x, target.x, SPEED_NORMAL * delta)
	else:
		# Gedämpftes Folgen statt Vollgas zum Ziel: keine Ruckler bei Zielwechseln.
		var step := (target - position) * clampf(delta * 3.2, 0.0, 1.0)
		position += step.limit_length(speed_cap * delta)
	_update_pose(delta)
	_move_parts()

## Körperhaltung folgt der Bewegung (Neigung), mit Glättung – nie hektisch.
func _update_pose(delta: float) -> void:
	var tilt := clampf(_vel.y * 0.0009 - _vel.x * 0.0003, -0.16, 0.16)
	if move_style in ["larva", "fungus", "harvester"]:
		tilt *= 0.25
	body.rotation = lerpf(body.rotation, tilt, clampf(delta * 5.0, 0.0, 1.0))
	if move_style == "fungus":
		body.scale = Vector2(1.0 + sin(age * 2.0) * 0.025, 1.0 - sin(age * 2.0) * 0.025)

func _move_parts() -> void:
	for p in parts:
		if p.get("node", null) != null and is_instance_valid(p.node) and not p.dead:
			var off: Vector2 = p["offset"]
			if id == "harvester" and phase == 1:
				# Phase 2: die Beschützer schwenken weit um die Maschine.
				off = off.rotated(sin(age * 0.9 + float(p.phase) * 1.7) * 0.7) + Vector2(0, sin(age * 1.6 + float(p.phase)) * 30.0)
			p.node.position = off + Vector2(sin(age * 2.0 + float(p.phase)) * 8.0, cos(age * 1.4 + float(p.phase)) * 6.0)

## Weltposition eines Moduls (folgt der sichtbaren Bewegung).
func _part_world(p: Dictionary) -> Vector2:
	if p.get("node", null) != null and is_instance_valid(p.node):
		return (p.node as Node2D).position + position
	return (p["offset"] as Vector2) + position

func _tick_parts(delta: float) -> void:
	for p in parts:
		if p.dead or p.get("node", null) == null or not is_instance_valid(p.node):
			continue
		p.fire_t -= delta
		if p.fire_t <= 0.0:
			p.fire_t = 1.6
			var world: Vector2 = _part_world(p)
			var g := get_parent()
			if g != null and g.has_method("spawn_enemy_bullet"):
				var aim: Vector2 = (g.player_position() - world).normalized()
				g.spawn_enemy_bullet(world, aim * 210.0, 1, "ebullet_orb")

func _tick_timeline(delta: float) -> void:
	if timeline.is_empty():
		return
	var keep: Array = []
	for e in timeline:
		e.t -= delta
		if e.t <= 0.0:
			var fn: Callable = e.f
			if fn.is_valid():
				fn.call()
		else:
			keep.append(e)
	timeline = keep

func schedule(delay: float, fn: Callable) -> void:
	timeline.append({"t": delay, "f": fn})

# --------------------------------------------------------------- Angriffe
func _next_pattern() -> void:
	if pattern_cycle.is_empty():
		act_timer = 1.5
		return
	pattern_index = (pattern_index + 1) % pattern_cycle.size()
	var name := String(pattern_cycle[pattern_index])
	attack_in_progress = true
	var interval := interval_now
	match name:
		"aimed_burst": _p_aimed_burst()
		"beetle_charge": _p_charge(2)
		"shell_open": _p_shell_open()
		"radial": _p_radial(12, 0.9)
		"burrow": _p_burrow(false)
		"burrow_fast": _p_burrow(true)
		"spit_arc": _p_spit_arc()
		"emerge_strike": _p_emerge_strike()
		"tunnel_chase": _p_tunnel_chase(false)
		"tunnel_chase_fast": _p_tunnel_chase(true)
		"rock_fall": _p_rock_fall(false)
		"rock_fall_dense": _p_rock_fall(true)
		"brood": _p_brood()
		"ember_spray": _p_ember_spray()
		"pike_jump": _p_pike_jump(false)
		"pike_jump_fast": _p_pike_jump(true)
		"vortex": _p_vortex()
		"aimed_spread": _p_aimed_spread(5, 0.42)
		"torpedo": _p_torpedo()
		"node_pulse": _p_node_pulse()
		"orchid_needles": _p_orchid_needles()
		"orchid_scythe": _p_orchid_scythe()
		"sprouts": _p_sprouts()
		"spore_rain": _p_spore_rain()
		"spore_rings": _p_spore_rings()
		"mantis_sweep": _p_mantis_sweep(false)
		"mantis_sweep_fast": _p_mantis_sweep(true)
		"twin_aim": _p_twin_aim()
		"cross_cut": _p_cross_cut()
		"armor_cycle": _p_armor_cycle(false)
		"armor_cycle_fast": _p_armor_cycle(true)
		"reflect_volley": _p_reflect_volley()
		"beam_sweep": _p_beam_sweep(false)
		"pump_slam": _p_pump_slam()
		"drain_gate": _p_drain_gate()
		"sludge_wave": _p_sludge_wave()
		"module_fire": _p_module_fire()
		"press_slam": _p_press_slam()
		"razor_arc": _p_razor_arc()
		"harvester_flank": _p_harvester_flank()
		"harvest_storm": _p_harvest_storm()
		"summon_guards": _p_summon_guards()
		"queen_spiral": _p_queen_spiral(false)
		"queen_spiral_fast": _p_queen_spiral(true)
		"core_beam": _p_core_beam(false)
		"core_beam_fast": _p_core_beam(true)
		"ring_barrage": _p_ring_barrage()
		"spawn_shards": _p_spawn_shards()
		"twin_orbit": _p_twin_orbit()
		"final_fury": _p_final_fury()
		"mantis_pounce": _p_mantis_pounce()
		"queen_dive": _p_queen_dive()
		"skater_dash": _p_skater_dash()
		"skim_strike": _p_skim_strike()
		"ripple_ring": _p_ripple_ring()
		"harvester_ram": _p_harvester_ram()
		"reborn_crown": _p_reborn_crown()
		"reborn_lance": _p_reborn_lance()
		"reborn_wings": _p_reborn_wings()
		"reborn_storm": _p_reborn_storm()
		"safe_zone": _p_safe_zone()
		_:
			_p_radial(10, 0.85)
	act_timer = interval
	_end_attack_after(interval * 0.75)

func _end_attack_after(t: float) -> void:
	schedule(t, func(): attack_in_progress = false)

func _p_aimed_burst() -> void:
	_telegraph(0.5)
	for i in range(4):
		schedule(0.5 + i * 0.16, func():
			var g := get_parent()
			if g == null or dead:
				return
			var aim: Vector2 = (g.player_position() - position).normalized()
			g.spawn_enemy_bullet(position + Vector2(-40, 0), aim * 260.0, 1, "ebullet_orb")
			Audio.sfx("shot_fan", -18.0, 0.8)
		)

## Käfer-Ansturm: kurz zurückweichen (Ankündigung), dann mit Hornstoß auf die
## Höhe der Biene vorpreschen und weich zurückgleiten. reps Wiederholungen.
func _p_charge(reps: int) -> void:
	_telegraph(0.55)
	telegraph_color = Color(1.0, 0.55, 0.3, 0.5)
	var g := get_parent()
	if g == null:
		return
	var start := position
	_motion(_clamp_target(start + Vector2(36, 0)), 0.5, "smooth", 0.0, func():
		_charge_leg(reps, start))

func _charge_leg(left: int, start: Vector2) -> void:
	var g := get_parent()
	if dead or g == null:
		return
	var p: Vector2 = g.player_position()
	var hit := _clamp_target(Vector2(maxf(540.0, position.x - 250.0), p.y))
	Audio.sfx("bomb", -14.0, 1.4)
	_motion(hit, 0.42, "dash", 0.0, func():
		if dead:
			return
		if g.has_method("shake"):
			g.shake(5.0)
		# Rosendornen beim Aufprall.
		for k in range(5):
			g.spawn_enemy_bullet(position + Vector2(-40, 0), Vector2.LEFT.rotated((k - 2) * 0.28) * 210.0, 1, "ebullet_needle")
		# Nach dem Aufprall kurz innehalten statt sofort umzukehren.
		if left > 1:
			_hold(0.3, func(): _charge_leg(left - 1, start))
		else:
			_hold(0.25, func(): _motion(_clamp_target(start), 0.9, "smooth")))

func _p_shell_open() -> void:
	vulnerable = true
	damage_mult = 1.6
	_telegraph(0.7)
	schedule(0.7, func():
		if dead:
			return
		for i in range(3):
			schedule(i * 0.12, func():
				var g := get_parent()
				if g == null:
					return
				for k in range(9):
					var a := PI * 0.5 + (k - 4) * 0.18
					g.spawn_enemy_bullet(position + Vector2(-30, 0), Vector2.LEFT.rotated(a - PI * 0.5) * 240.0, 1, "ebullet_orb")
			)
	)
	schedule(2.2, func(): damage_mult = 1.0)

func _p_radial(n: int, spd: float) -> void:
	_telegraph(0.45)
	schedule(0.45, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(n):
			var a := TAU * float(i) / float(n) + age
			g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(a) * 200.0 * spd, 1, "ebullet_orb")
		Audio.sfx("shot_plasma", -14.0, 0.7)
	)

## Larve gräbt sich ein: sinkt unter den Boden, wühlt unsichtbar zu einer neuen
## Stelle und bricht mit Erdbrocken wieder hervor. Kein Teleport im Bild.
func _p_burrow(fast: bool) -> void:
	_telegraph(0.45)
	telegraph_color = Color(0.7, 0.45, 0.25, 0.45)
	var down := Vector2(position.x, App.PLAY_BOTTOM + 90.0)
	schedule(0.45, func():
		if dead:
			return
		vulnerable = false
		submerged = true
		_dust_burst()
		_motion(down, 0.5, "dash", 0.0, func():
			var g := get_parent()
			if dead or g == null:
				return
			var p: Vector2 = g.player_position()
			var nx := clampf(p.x + 260.0, 600.0, 860.0)
			position = Vector2(nx, App.PLAY_BOTTOM + 90.0)
			schedule(0.55 if fast else 0.85, func():
				if dead:
					return
				_dust_burst()
				_motion(Vector2(nx, _ground_y()), 0.45, "out", 0.0, func():
					submerged = false
					vulnerable = true
					damage_mult = 1.0
					var g2 := get_parent()
					if g2 == null:
						return
					var aim: Vector2 = (g2.player_position() - position).normalized()
					for k in range(5):
						g2.spawn_enemy_bullet(position + Vector2(-50, -10), aim.rotated((k - 2) * 0.2) * 280.0, 1, "ebullet_needle")
				)
			)
		)
	)

## Erdbrocken beim Ein- und Auftauchen.
func _dust_burst() -> void:
	var g := get_parent()
	if g == null:
		return
	for k in range(8):
		var a := -PI * 0.5 + (k - 3.5) * 0.22
		g.spawn_enemy_bullet(Vector2(position.x - 20 + k * 6, App.PLAY_BOTTOM - 6), Vector2.RIGHT.rotated(a) * 190.0, 1, "ebullet_spore")
	if g.has_method("shake"):
		g.shake(3.0)
	Audio.sfx("explosion_small", -12.0, 0.7)

func _p_spit_arc() -> void:
	_telegraph(0.4)
	for i in range(3):
		schedule(0.4 + i * 0.3, func():
			var g := get_parent()
			if g == null or dead:
				return
			# Fächer aus dem Maul, jede Salve neu auf die Biene gerichtet.
			var mouth := position + Vector2(-50, -10)
			var aim: Vector2 = (g.player_position() - mouth).normalized()
			for k in range(7):
				g.spawn_enemy_bullet(mouth, aim.rotated((k - 3) * 0.14) * 230.0, 1, "ebullet_spore")
		)

## Tunnelfahrt: Die Larve wühlt unter dem Boden quer durch die Arena; vor ihr
## brechen in schneller Folge Erdsäulen hervor. Wer am Boden klebt, muss hoch.
func _p_tunnel_chase(fast: bool) -> void:
	_telegraph(0.45)
	schedule(0.45, func():
		if dead:
			return
		vulnerable = false
		submerged = true
		_dust_burst()
		_motion(Vector2(position.x, App.PLAY_BOTTOM + 90.0), 0.4, "dash", 0.0, func():
			if dead or get_parent() == null:
				return
			var step := 0.15 if fast else 0.21
			var xs: Array = []
			var x := position.x - 40.0
			while x > 60.0:
				xs.append(x)
				x -= 62.0
			for i in range(xs.size()):
				var xi: float = xs[i]
				var loud := i % 2 == 0
				schedule(i * step, func():
					var g2 := get_parent()
					if g2 != null and not dead and g2.has_method("spawn_ground_spike"):
						g2.spawn_ground_spike(xi, 0.5, 96.0, 1.4)
						if loud:
							Audio.sfx("explosion_small", -16.0, 0.6)
				)
			# Danach an anderer Stelle rechts wieder auftauchen.
			schedule(xs.size() * step + 0.5, func():
				if dead:
					return
				var nx := 820.0 if position.x < 760.0 else 690.0
				position = Vector2(nx, App.PLAY_BOTTOM + 90.0)
				_dust_burst()
				_motion(Vector2(nx, _ground_y()), 0.45, "out", 0.0, func():
					submerged = false
					vulnerable = true
				)
			)
		)
	)

## Deckeneinsturz: Risse an der Höhlendecke kündigen Brocken an, die in Bahnen
## herabfallen. Eine Bahn nahe der Biene bleibt immer frei.
func _p_rock_fall(dense: bool) -> void:
	_telegraph(0.4)
	var g := get_parent()
	if g == null:
		return
	if g.has_method("shake"):
		g.shake(6.0)
	Audio.sfx("explosion_big", -14.0, 0.5)
	var lanes := 9 if dense else 7
	var span := 780.0 / float(lanes - 1)
	var p: Vector2 = g.player_position()
	var gap := clampi(int(round((p.x - 60.0) / span)) + _rng.randi_range(-1, 1), 0, lanes - 1)
	for i in range(lanes):
		if i == gap:
			continue
		var x := 60.0 + i * span + _rng.randf_range(-10.0, 10.0)
		var delay := 0.8 + _rng.randf() * 0.35
		var drift := _rng.randf_range(-12.0, 12.0)
		if g.has_method("spawn_ceiling_warning"):
			g.spawn_ceiling_warning(x, delay)
		schedule(delay, func():
			var g2 := get_parent()
			if g2 == null or dead:
				return
			for k in range(2 if dense else 1):
				g2.spawn_enemy_bullet(Vector2(x, App.PLAY_TOP + 6.0 - k * 26.0), Vector2(drift, 250.0 + k * 20.0), 1,
					"ebullet_spore", {"scale": 1.8, "r": 8.0, "tint": Color(0.78, 0.58, 0.40)})
		)

## Was die Phasenansage verspricht, passiert auch (PHASE_LINES):
##   Käfer   "Der Panzer glüht rot"        -> Glut, Funkenflug, Glutsalven
##   Hecht   "peitscht das Wasser"          -> häufige, hohe Wassersäulen
##   Pilz    "Die Knoten platzen auf"       -> verlorene Knoten zerplatzen in Sporen
##   Königin "Der Hof schwärmt aus"         -> sofort ein ganzer Hofstaat
##   Erntemaschine "Neue Module fahren aus" -> vier Module (siehe Data)
func _phase_entry(old_parts: Array) -> void:
	var g := get_parent()
	if g == null:
		return
	match id:
		"fungus_mind":
			# Neue Phase: ein verlorener Heilpilz wächst nach.
			_fungus_court()
			var keep := int(phase_defs[phase].get("nodes", 0))
			for i in range(keep, old_parts.size()):
				var p: Dictionary = old_parts[i]
				if bool(p.get("dead", false)):
					continue
				var world: Vector2 = (p["offset"] as Vector2) + position
				for k in range(12):
					g.spawn_enemy_bullet(world, Vector2.RIGHT.rotated(k * TAU / 12.0) * 150.0, 1, "ebullet_spore")
				if g.has_method("_on_hazard"):
					g.fx.add_hazard({"kind": "spore_cloud", "p": world, "radius": 54.0, "t": 0.0, "life": 5.0,
						"max_life": 5.0, "vel": Vector2(-50, 0), "dmg": 1, "hit_cd": 0.0, "color": Color(0.5, 1.0, 0.8, 0.3)})
				g.fx.explode(world, 1.6, Color(0.7, 1.0, 0.6))
			Audio.sfx("explosion_small", -6.0, 0.7)
		"swarm_queen":
			if phase == 1 and g.has_method("spawn_boss_minion"):
				for i in range(5):
					g.spawn_boss_minion("queen_acolyte", Vector2(960 + (i % 2) * 40, 110 + i * 70))
		"pike_beast":
			_whip_t = 0.6

## Käfer ab Phase 2: Der Panzer glüht – Funken steigen auf, Glutsalven (ember_spray).
func _tick_embers(delta: float) -> void:
	_ember_t -= delta
	if _ember_t > 0.0:
		return
	_ember_t = 0.12
	var g := get_parent()
	if g != null:
		g.fx.add("spark", position + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-30, 10)),
			{"life": 0.45, "scale": 0.8, "tint": Color(1.0, 0.45, 0.15), "grow": 0.5})

func _p_ember_spray() -> void:
	_telegraph(0.45)
	for w in range(3):
		schedule(0.45 + w * 0.28, func():
			var g := get_parent()
			if g == null or dead:
				return
			for k in range(9):
				var a := PI + (float(k) - 4.0) * 0.17 + _rng.randf_range(-0.04, 0.04)
				g.spawn_enemy_bullet(position + Vector2(-30, -10), Vector2.RIGHT.rotated(a) * (190.0 + w * 25.0), 1,
					"ebullet_orb", {"tint": Color(1.0, 0.5, 0.2), "scale": 1.2})
			Audio.sfx("shot_plasma", -14.0, 0.6)
		)

## Hecht ab Phase 2: Mit jedem Schwanzschlag schießen Wassersäulen hoch – in der
## Nähe der Biene und doppelt so oft wie im Level, höher und länger.
func _tick_whip(delta: float) -> void:
	_whip_t -= delta
	if _whip_t > 0.0:
		return
	_whip_t = 1.7
	var g := get_parent()
	if g == null or not g.has_method("spawn_geyser"):
		return
	var p: Vector2 = g.player_position()
	var x := clampf(p.x + _rng.randf_range(-60.0, 60.0), 60.0, 900.0)
	g.spawn_geyser(x, 300.0, 3.2, 0.75)
	g.spawn_geyser(clampf(x + (150.0 if _rng.randf() < 0.5 else -150.0), 60.0, 900.0), 260.0, 3.0, 0.9)
	if g.has_method("shake"):
		g.shake(3.0)

## Phase 3 der Larve: Die Höhle stürzt ein. Felsbrocken regnen ohne Pause in
## Bahnen, eine Lücke (zwei Bahnen breit) wandert langsam hin und her und ist
## mit einem Lichtschacht markiert. So bleibt immer ein sicherer Weg.
func cave_gap_x() -> float:
	return 470.0 + sin(age * 0.32) * 320.0

func _tick_cave_in(delta: float) -> void:
	var g := get_parent()
	if g == null:
		return
	var gap := cave_gap_x()
	if _cave_shaft.is_empty() or float(_cave_shaft.get("life", 0.0)) <= 0.0:
		_cave_shaft = {"kind": "light_shaft", "p": Vector2(gap, App.PLAY_TOP), "t": 0.0,
			"life": 9999.0, "max_life": 9999.0, "w": CAVE_GAP_HALF * 2.0}
		g.fx.add_hazard(_cave_shaft)
	_cave_shaft.p = Vector2(gap, App.PLAY_TOP)
	_cave_t -= delta
	if _cave_t > 0.0:
		return
	_cave_t = 0.32
	# Drei bis vier Brocken pro Takt, nie in der Lücke.
	for k in range(3 + _rng.randi_range(0, 1)):
		var x := _rng.randf_range(30.0, 930.0)
		if absf(x - gap) < CAVE_GAP_HALF + 12.0:
			continue
		g.spawn_enemy_bullet(Vector2(x, App.PLAY_TOP + 4.0), Vector2(_rng.randf_range(-8.0, 8.0), 240.0 + _rng.randf_range(0, 40.0)),
			1, "ebullet_spore", {"scale": 1.8, "r": 8.0, "tint": Color(0.78, 0.58, 0.40), "life": 3.0})

## Brut: Riesenmaden kriechen am Boden auf die Biene zu (höchstens vier zugleich).
func _p_brood() -> void:
	_telegraph(0.5)
	var g := get_parent()
	if g == null:
		return
	var live := 0
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead and e.id == "larva_grub":
			live += 1
	var count := mini(2 + int(phase >= 1), 4 - live)
	for i in range(count):
		var lane := float(i)
		schedule(0.5 + i * 0.35, func():
			var g2 := get_parent()
			if g2 == null or dead:
				return
			g2.spawn_enemy("larva_grub", Vector2(position.x - 70.0 - lane * 12.0, App.PLAY_BOTTOM - 18.0), {})
			Audio.sfx("explosion_small", -18.0, 0.8)
		)

## Larve schnellt unter der Biene aus dem Boden hoch und zieht sich zurück.
func _p_emerge_strike() -> void:
	_telegraph(0.5)
	var g := get_parent()
	if g == null:
		return
	submerged = true
	vulnerable = false
	_motion(Vector2(position.x, App.PLAY_BOTTOM + 90.0), 0.45, "dash", 0.0, func():
		var g2 := get_parent()
		if dead or g2 == null:
			return
		var p: Vector2 = g2.player_position()
		var x := clampf(p.x + 200.0, 560.0, 860.0)
		position = Vector2(x, App.PLAY_BOTTOM + 90.0)
		# Warnung: Staubfontäne an der Austrittsstelle, dann der Stoß.
		for i in range(3):
			g2.spawn_enemy_bullet(Vector2(p.x, App.PLAY_BOTTOM), Vector2.UP * (330 + i * 30), 1, "ebullet_needle")
		schedule(0.35, func():
			if dead:
				return
			_dust_burst()
			_motion(_clamp_target(Vector2(x, maxf(p.y, 200.0))), 0.35, "out", 0.0, func():
				submerged = false
				vulnerable = true
				_motion(Vector2(x, _ground_y()), 0.7, "smooth")
			)
		)
	)

## Hecht springt in einem Bogen aus dem Wasser über die Biene hinweg und lässt
## dabei Tropfen regnen; landet weich und schwimmt weiter.
func _p_pike_jump(fast: bool) -> void:
	_telegraph(0.5)
	var g := get_parent()
	if g == null:
		return
	schedule(0.5, func():
		if dead:
			return
		var p: Vector2 = g.player_position()
		var land := _clamp_target(Vector2(clampf(p.x + 200.0, 560.0, 860.0), 360.0))
		var dur := 0.75 if fast else 0.95
		# Nach dem Eintauchen kurz treiben lassen, statt sofort umzukehren.
		_motion(land, dur, "smooth", 170.0, func(): _hold(0.25))
		for i in range(6):
			schedule(dur * (0.15 + i * 0.13), func():
				if dead:
					return
				g.spawn_enemy_bullet(position + Vector2(0, 30), Vector2(-60.0, 160.0 + i * 12.0), 1, "ebullet_spore")
			)
		Audio.sfx("dash", -10.0, 0.8)
	)

func _p_vortex() -> void:
	_telegraph(0.4)
	schedule(0.4, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(18):
			var a := float(i) * 0.35
			var r := 30.0 + i * 3.0
			var p := position + Vector2(cos(a) * r, sin(a) * r)
			g.spawn_enemy_bullet(p, Vector2.RIGHT.rotated(a + PI * 0.5) * 150.0, 1, "ebullet_spore")
	)

func _p_aimed_spread(n: int, arc: float) -> void:
	_telegraph(0.4)
	schedule(0.4, func():
		var g := get_parent()
		if g == null or dead:
			return
		var aim: Vector2 = (g.player_position() - position).normalized()
		for i in range(n):
			var a := lerpf(-arc, arc, float(i) / float(maxi(1, n - 1)))
			g.spawn_enemy_bullet(position, aim.rotated(a) * 250.0, 1, "ebullet_needle")
	)

## Hecht stößt wie ein Torpedo in der Höhe der Biene nach links vor.
func _p_torpedo() -> void:
	_telegraph(0.45)
	var g := get_parent()
	if g == null:
		return
	var start := position
	schedule(0.45, func():
		if dead:
			return
		var p: Vector2 = g.player_position()
		_motion(_clamp_target(Vector2(560.0, p.y)), 0.4, "dash", 0.0, func():
			for k in range(3):
				g.spawn_enemy_bullet(position + Vector2(-60, 0), Vector2.LEFT.rotated((k - 1) * 0.15) * 340.0, 1, "ebullet_laser", {"r": 8.0})
			_hold(0.2, func(): _motion(_clamp_target(start), 0.85, "smooth"))
		)
	)

## Pilzboss: Heilung durch den Heilpilz, höchstens bis zum Beginn der laufenden Phase.
func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	var cap := max_hp * float(phase_defs[phase].get("hp", 1.0))
	if hp >= cap:
		return
	hp = minf(cap, hp + amount)
	var g := get_parent()
	if g != null and "fx" in g:
		g.fx.add("spark", position + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
			{"life": 0.4, "scale": 1.4, "tint": Color(0.5, 1.0, 0.5)})

## Pilzboss: Heilpilz mit drei kreisenden Schirmlingen hinter dem Boss.
func _fungus_court() -> void:
	var g := get_parent()
	if g == null or not g.has_method("spawn_enemy"):
		return
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead and e.id == "fungus_healer":
			return
	var healer = g.spawn_enemy("fungus_healer", Vector2(980, 130), {})
	if healer == null:
		return
	for i in range(3):
		g.spawn_enemy("fungus_guard", healer.position, {"host": healer, "mirror": float(i)})
	Audio.sfx("explosion_small", -8.0, 1.3)

## Pilzlinge brechen an drei Stellen aus dem Waldboden.
func _p_sprouts() -> void:
	_telegraph(0.4)
	var g := get_parent()
	if g == null:
		return
	var live := 0
	for e in g.enemies:
		if is_instance_valid(e) and not e.dead and e.id == "fungus_sprout":
			live += 1
	for i in range(mini(3, 6 - live)):
		var x := 320.0 + i * 150.0 + _rng.randf_range(-30, 30)
		schedule(0.4 + i * 0.25, func():
			var g2 := get_parent()
			if g2 != null and not dead:
				g2.spawn_enemy("fungus_sprout", Vector2(x, App.PLAY_BOTTOM - 22.0), {})
		)

# --------------------------------------------------------------- Mantidenpaar
func _setup_twin() -> void:
	twin = AnimatedSprite2D.new()
	twin.sprite_frames = Art.sprite_frames(String(def.get("sprite", "boss_mantis")))
	twin.play("default")
	twin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	twin.z_index = 4
	twin.scale = Vector2(0.85, 0.85)
	twin.modulate = ORCHID
	add_child(twin)
	primary_hp = max_hp * 0.5
	twin_max = max_hp * 0.5
	twin_hp = twin_max
	twin_dead = false
	twin_pos = Vector2(1040, 150)
	twin.position = twin_pos - position

## Die Orchideenmantis lauert spiegelbildlich zur grünen und greift im eigenen Takt an.
func _tick_twin(delta: float) -> void:
	var mirror_y := clampf(App.PLAY_BOTTOM + App.PLAY_TOP - position.y, 110.0, 430.0)
	var goal := Vector2(650.0 + sin(age * 0.6) * 40.0, mirror_y + sin(age * 1.7) * 12.0)
	twin_pos = twin_pos.lerp(goal, clampf(delta * 1.6, 0.0, 1.0))
	twin.position = twin_pos - position
	twin_flash = maxf(0.0, twin_flash - delta)
	twin_telegraph = maxf(0.0, twin_telegraph - delta)
	if twin_flash > 0.0:
		twin.modulate = Color(2.0, 2.0, 2.0)
	elif twin_telegraph > 0.0:
		twin.modulate = Color(1.6, 0.7, 0.9)
	else:
		twin.modulate = ORCHID
	if invuln > 0.0 or phase_banner_t > 0.0 or age < 2.0:
		return
	twin_act -= delta
	if twin_act > 0.0:
		return
	twin_act = 1.8 * _rate()
	var pats: Array = phase_defs[0].get("twin_patterns", ["orchid_needles"])
	twin_index = (twin_index + 1) % pats.size()
	match String(pats[twin_index]):
		"orchid_needles": _p_orchid_needles()
		"orchid_scythe": _p_orchid_scythe()

## Treffer gehen an die getroffene Mantis; hp bleibt die Summe für Balken und Wertung.
func _pair_damage(amount: float, hit_part: int) -> void:
	var dmg := amount * damage_mult
	if not vulnerable:
		dmg *= 0.35
	if hit_part == TWIN_PART:
		twin_hp -= dmg
		twin_flash = 0.06
	else:
		primary_hp -= dmg
		hit_flash = 0.06
	hp = maxf(0.0, primary_hp) + maxf(0.0, twin_hp)
	hp_changed.emit(hp, max_hp)
	if twin_hp <= 0.0:
		_pair_falls(false)
	elif primary_hp <= 0.0:
		_pair_falls(true)

## Eine Mantis fällt: die andere erbt ihre Angriffe (Phase II).
func _pair_falls(primary_fell: bool) -> void:
	var g := get_parent()
	var fall_pos := position if primary_fell else twin_pos
	if g != null and "fx" in g:
		g.fx.explode(fall_pos, 3.0, Color(0.7, 1.0, 0.6) if primary_fell else ORCHID)
	Audio.sfx("explosion_big", -2.0, 0.9)
	if primary_fell:
		# Die Orchideenmantis übernimmt den Platz und das Kommando.
		position = twin_pos
		hp = maxf(1.0, twin_hp)
		body.scale = twin.scale
	else:
		hp = maxf(1.0, primary_hp)
	twin.visible = false
	twin_dead = true
	_bounds_dirty = true
	hp_changed.emit(hp, max_hp)
	_apply_phase(1)
	if primary_fell:
		rage_tint = ORCHID * rage_tint

## Ursprung der Orchideen-Angriffe: die zweite Mantis, nach ihrem Erbe die Überlebende.
func _orchid_origin() -> Vector2:
	return twin_pos if not twin_dead else position

func _orchid_telegraph(t: float) -> void:
	if not twin_dead:
		twin_telegraph = t
		Audio.sfx("boss_warn", -22.0, 1.7)
	else:
		_telegraph(t)

## Nadelfächer: drei gezielte Salven aus je fünf Nadeln.
func _p_orchid_needles() -> void:
	_orchid_telegraph(0.4)
	for v in range(3):
		schedule(0.4 + v * 0.28, func():
			var g := get_parent()
			if g == null or dead:
				return
			var from := _orchid_origin() + Vector2(-40, 0)
			var aim: Vector2 = (g.player_position() - from).normalized()
			for k in range(5):
				g.spawn_enemy_bullet(from, aim.rotated((k - 2) * 0.11) * 300.0, 1, "ebullet_needle")
		)

## Sensenwelle: ein Bogen aus Kugeln, der sich von oben nach unten auffächert.
func _p_orchid_scythe() -> void:
	_orchid_telegraph(0.5)
	for k in range(11):
		schedule(0.5 + k * 0.045, func():
			var g := get_parent()
			if g == null or dead:
				return
			var from := _orchid_origin() + Vector2(-30, 0)
			var a := PI - 0.9 + float(k) * 0.18
			g.spawn_enemy_bullet(from, Vector2.RIGHT.rotated(a) * 230.0, 1, "ebullet_orb")
		)

func _p_node_pulse() -> void:
	var alive_parts := parts.filter(func(p): return not p.dead)
	if alive_parts.is_empty():
		_p_radial(10, 0.9)
		return
	_telegraph(0.5)
	for p in alive_parts:
		schedule(0.5, func():
			var g := get_parent()
			if g == null or dead or p.dead:
				return
			var world: Vector2 = (p["offset"] as Vector2) + position
			for i in range(8):
				g.spawn_enemy_bullet(world, Vector2.RIGHT.rotated(i * TAU / 8.0) * 180.0, 1, "ebullet_orb")
		)

func _p_spore_rain() -> void:
	_telegraph(0.35)
	schedule(0.35, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(9):
			var x := 380.0 + i * 62.0
			g.spawn_enemy_bullet(Vector2(x, -20), Vector2.DOWN * (140 + (i % 3) * 30), 1, "ebullet_spore")
	)

func _p_spore_rings() -> void:
	for k in range(2):
		schedule(k * 0.6, func():
			var g := get_parent()
			if g == null or dead:
				return
			for i in range(14):
				var a := TAU * float(i) / 14.0 + k * 0.2
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(a) * 165.0, 1, "ebullet_spore")
		)

func _p_mantis_sweep(fast: bool) -> void:
	_telegraph(0.55)
	var count := 5
	var step := 0.09 if fast else 0.13
	schedule(0.55, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(count):
			schedule(i * step, func():
				var y := 80.0 + i * 80.0
				g.spawn_enemy_bullet(Vector2(1000, y), Vector2.LEFT * 420.0, 1, "ebullet_needle", {"r": 6.0})
			)
	)

func _p_twin_aim() -> void:
	_telegraph(0.35)
	schedule(0.35, func():
		var g := get_parent()
		if g == null or dead:
			return
		var p: Vector2 = g.player_position()
		for oy in [-60.0, 60.0]:
			var aim: Vector2 = (p - (position + Vector2(0, oy))).normalized()
			for k in range(3):
				g.spawn_enemy_bullet(position + Vector2(0, oy), aim.rotated((k - 1) * 0.13) * 280.0, 1, "ebullet_orb")
	)

func _p_cross_cut() -> void:
	_telegraph(0.6)
	schedule(0.6, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(12):
			g.spawn_enemy_bullet(Vector2(1000, 40 + i * 42), Vector2.LEFT * 380.0, 1, "ebullet_needle", {"r": 5.0})
		schedule(0.22, func():
			if dead or g == null:
				return
			for i in range(11):
				g.spawn_enemy_bullet(Vector2(1000, 62 + i * 42), Vector2.LEFT * 380.0, 1, "ebullet_needle", {"r": 5.0})
		)
	)

func _p_armor_cycle(fast: bool) -> void:
	vulnerable = false
	damage_mult = 0.15
	_telegraph(0.5)
	schedule(0.5, func():
		var g := get_parent()
		if g == null or dead:
			return
		for k in range(6):
			schedule(k * 0.14, func():
				var p: Vector2 = g.player_position() if g != null else Vector2(200, 270)
				var aim: Vector2 = (p - position).normalized()
				g.spawn_enemy_bullet(position, aim.rotated(randf_range(-0.2, 0.2)) * 300.0, 1, "ebullet_needle")
			)
	)
	schedule(0.6 if fast else 0.9, func():
		vulnerable = true
		damage_mult = 1.35
		Audio.sfx("shield_break", -12.0, 1.1)
	)
	schedule(2.0 if fast else 2.6, func(): damage_mult = 1.0)

func _p_reflect_volley() -> void:
	_telegraph(0.45)
	schedule(0.45, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(5):
			var y := 150.0 + i * 60.0
			g.spawn_enemy_bullet(Vector2(1000, y), Vector2.LEFT * 250.0, 1, "ebullet_laser", {"r": 7.0, "aimed": false})
	)

func _p_beam_sweep(fast: bool) -> void:
	_telegraph(0.7)
	telegraph_color = Color(1.0, 0.2, 0.2, 0.30)
	schedule(0.7, func():
		var g := get_parent()
		if g == null or dead:
			return
		var steps := 22
		for i in range(steps):
			schedule(i * (0.035 if fast else 0.05), func():
				if dead or g == null:
					return
				var y := 60.0 + float(i) * 18.0
				g.spawn_enemy_bullet(Vector2(880, y), Vector2.LEFT * 400.0, 1, "ebullet_laser", {"r": 6.0, "life": 2.2})
		)
	)

func _p_pump_slam() -> void:
	_telegraph(0.5)
	schedule(0.5, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(6):
			var x := 420.0 + i * 90.0
			g.spawn_enemy_bullet(Vector2(x, 560), Vector2.UP * 300.0, 1, "ebullet_needle", {"r": 7.0})
			g.spawn_enemy_bullet(Vector2(x, -20), Vector2.DOWN * 300.0, 1, "ebullet_needle", {"r": 7.0})
	)

func _p_drain_gate() -> void:
	_telegraph(0.4)
	schedule(0.4, func():
		var g := get_parent()
		if g == null or dead:
			return
		var p: Vector2 = g.player_position()
		# Schleusenschwall: Fächer von oben über der Biene.
		for i in range(9):
			g.spawn_enemy_bullet(Vector2(p.x, -20), Vector2.DOWN.rotated((float(i) - 4.0) * 0.22) * 200.0, 1, "ebullet_spore")
	)

func _p_sludge_wave() -> void:
	_telegraph(0.4)
	schedule(0.4, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(5):
			schedule(i * 0.16, func():
				if dead or g == null:
					return
				g.spawn_enemy_bullet(Vector2(1020, 130 + i * 70), Vector2.LEFT * 210.0, 1, "ebullet_spore", {"r": 8.0, "life": 6.0})
		)
	)

func _p_module_fire() -> void:
	var alive_parts := parts.filter(func(p): return not p.dead)
	if alive_parts.is_empty():
		_p_aimed_spread(7, 0.5)
		return
	for p in alive_parts:
		schedule(0.0, func():
			var g := get_parent()
			if g == null or dead or p.dead:
				return
			var world: Vector2 = _part_world(p)
			var aim: Vector2 = (g.player_position() - world).normalized()
			for k in range(3):
				g.spawn_enemy_bullet(world, aim.rotated((k - 1) * 0.2) * 240.0, 1, "ebullet_needle")
		)

func _p_press_slam() -> void:
	_telegraph(0.55)
	schedule(0.55, func():
		var g := get_parent()
		if g == null or dead:
			return
		var p: Vector2 = g.player_position()
		for i in range(3):
			schedule(i * 0.25, func():
				if g == null or dead:
					return
				for k in range(6):
					g.spawn_enemy_bullet(Vector2(p.x + 80 + k * 40, 0), Vector2.DOWN * 280.0, 1, "ebullet_orb")
			)
	)

## Erntemaschine: ab Phase 3 deutlich mehr Geschosse, in der kurzen Schlussphase noch mehr.
func _harvest_density() -> int:
	if id != "harvester":
		return 0
	return 0 if phase < 2 else (1 if phase == 2 else 2)

func _p_razor_arc() -> void:
	_telegraph(0.4)
	var extra := _harvest_density()
	for i in range(3 + extra):
		schedule(0.4 + i * 0.24, func():
			var g := get_parent()
			if g == null or dead:
				return
			var p: Vector2 = g.player_position()
			var aim: Vector2 = (p - position).normalized()
			var n := 9 + extra * 4
			for k in range(n):
				g.spawn_enemy_bullet(position, aim.rotated((float(k) - float(n - 1) * 0.5) * 0.12) * 320.0, 1, "ebullet_needle", {"r": 5.0})
		)

## Erntemaschine: Dreschsturm – rotierende Spirale aus der Trommel.
func _p_harvest_storm() -> void:
	_telegraph(0.4)
	var arms := 3 + _harvest_density()
	for i in range(28):
		schedule(0.4 + i * 0.06, func():
			var g := get_parent()
			if g == null or dead:
				return
			for a in range(arms):
				var ang := PI + float(i) * 0.23 + TAU * float(a) / float(arms)
				g.spawn_enemy_bullet(position + Vector2(-30, -10), Vector2.RIGHT.rotated(ang) * 210.0, 1, "ebullet_orb")
		)

## Erntemaschine Phase 1: rollt rechts aus dem Bild, kommt links hinter der Biene herein,
## feuert nach rechts, verschwindet links und rollt rechts wieder herein.
func _p_harvester_flank() -> void:
	var g := get_parent()
	if g == null:
		return
	attack_in_progress = true
	_telegraph(0.4)
	var gy := _ground_y()
	_motion(Vector2(1130.0, gy), 0.9, "smooth", 0.0, func():
		position = Vector2(-170.0, gy)
		Audio.sfx("boss_warn", -8.0, 0.8)
		_motion(Vector2(110.0, gy), 0.9, "smooth", 0.0, func():
			for v in range(4):
				schedule(v * 0.4, func():
					var g2 := get_parent()
					if g2 == null or dead:
						return
					var from := position + Vector2(50, -20)
					var aim: Vector2 = ((g2.player_position() as Vector2) - from).normalized()
					if aim.x < 0.2:
						aim = Vector2(1, aim.y).normalized()
					for k in range(5):
						g2.spawn_enemy_bullet(from, aim.rotated((k - 2) * 0.16) * 270.0, 1, "ebullet_needle")
				)
			_hold(1.9, func():
				_motion(Vector2(-170.0, gy), 0.8, "smooth", 0.0, func():
					position = Vector2(1130.0, gy)
					_motion(Vector2(780.0, gy), 1.0, "smooth", 0.0, func(): attack_in_progress = false)))))

func _p_summon_guards() -> void:
	_telegraph(0.5)
	schedule(0.5, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(3):
			if g.has_method("spawn_boss_minion"):
				g.spawn_boss_minion("queen_acolyte", Vector2(940, 140 + i * 130))
		Audio.sfx("boss_warn", -12.0, 1.2)
	)

func _p_queen_spiral(fast: bool) -> void:
	for i in range(14 if not fast else 20):
		schedule(i * (0.05 if fast else 0.075), func():
			var g := get_parent()
			if g == null or dead:
				return
			var a := float(i) * 0.55
			g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(a) * 220.0, 1, "ebullet_orb")
			g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(a + PI) * 220.0, 1, "ebullet_orb")
		)

func _p_core_beam(fast: bool) -> void:
	_telegraph(0.8)
	telegraph_color = Color(1.0, 0.3, 0.6, 0.30)
	schedule(0.8, func():
		var g := get_parent()
		if g == null or dead:
			return
		var p: Vector2 = g.player_position()
		for i in range(16 if not fast else 22):
			schedule(i * 0.045, func():
				if g == null or dead:
					return
				var aim: Vector2 = (p - position).normalized()
				g.spawn_enemy_bullet(position + Vector2(-30, 0), aim.rotated(randf_range(-0.05, 0.05)) * 460.0, 1, "ebullet_laser", {"r": 6.0})
		)
	)

func _p_ring_barrage() -> void:
	for k in range(3):
		schedule(k * 0.4, func():
			var g := get_parent()
			if g == null or dead:
				return
			var n := 16
			var off := float(k) * 0.2
			for i in range(n):
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(TAU * float(i) / float(n) + off) * 190.0, 1, "ebullet_orb")
		)

func _p_spawn_shards() -> void:
	_telegraph(0.4)
	schedule(0.4, func():
		var g := get_parent()
		if g == null or dead:
			return
		for i in range(3):
			if g.has_method("spawn_boss_minion"):
				g.spawn_boss_minion("core_shard", Vector2(980, 120 + i * 150))
	)

func _p_twin_orbit() -> void:
	for i in range(10):
		schedule(i * 0.09, func():
			var g := get_parent()
			if g == null or dead:
				return
			var a := float(i) * 0.8
			var off := Vector2(cos(a) * 90.0, sin(a) * 90.0)
			var aim: Vector2 = (g.player_position() - (position + off)).normalized()
			g.spawn_enemy_bullet(position + off, aim * 260.0, 1, "ebullet_needle")
		)

func _p_final_fury() -> void:
	_telegraph(0.6)
	telegraph_color = Color(1.0, 1.0, 1.0, 0.4)
	schedule(0.6, func():
		for k in range(3):
			schedule(k * 0.25, func():
				var g := get_parent()
				if g == null or dead:
					return
				for i in range(14):
					var a := TAU * float(i) / 14.0 + k * 0.15
					g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(a) * 230.0, 1, "ebullet_orb")
				var p: Vector2 = g.player_position()
				for i in range(5):
					var aim: Vector2 = (p - position).normalized()
					g.spawn_enemy_bullet(position, aim.rotated((i - 2) * 0.1) * 340.0, 1, "ebullet_laser", {"r": 6.0})
			)
	)

## Kernorganismus: hält inne, der ganze Schirm wird zur Warnfläche bis auf eine
## Schutzzone. Höchstens alle SAFE_ZONE_COOLDOWN Sekunden, sonst ein Strahl.
const SAFE_ZONE_COOLDOWN := 9.0
var _safe_zone_last := -100.0

func _p_safe_zone() -> void:
	var g := get_parent()
	if g == null or not g.has_method("begin_safe_zone") or age - _safe_zone_last < SAFE_ZONE_COOLDOWN:
		_p_core_beam(true)
		return
	_safe_zone_last = age
	var window: float = g.begin_safe_zone()
	telegraph = window
	telegraph_color = Color(1.0, 0.2, 0.15, 0.5)
	_hold(window + 0.6)

## Neue Form: angekuendigte Kombinationen, alle Kugeln weiterhin zentral durch Game.
func _p_reborn_crown() -> void:
	_p_radial(14, 1.05)
	schedule(0.3, func(): _p_aimed_spread(5, 0.3))

func _p_reborn_lance() -> void:
	_p_core_beam(true)
	schedule(0.65, _p_twin_aim)

func _p_reborn_wings() -> void:
	_telegraph(0.55)
	schedule(0.55, _p_twin_orbit)
	schedule(0.95, func(): _p_aimed_spread(7, 0.38))

func _p_reborn_storm() -> void:
	_p_final_fury()
	schedule(0.45, func(): _p_core_beam(true))

## Mantis: Lauerhaltung, dann Sprung auf die Höhe der Beute mit Sichelhieb.
func _p_mantis_pounce() -> void:
	_telegraph(0.6)
	telegraph_color = Color(0.6, 1.0, 0.5, 0.45)
	var g := get_parent()
	if g == null:
		return
	var start := position
	schedule(0.6, func():
		if dead:
			return
		var p: Vector2 = g.player_position()
		_motion(_clamp_target(Vector2(maxf(560.0, start.x - 200.0), p.y)), 0.42, "smooth", 60.0, func():
			for k in range(9):
				var a := PI + (k - 4) * 0.16
				g.spawn_enemy_bullet(position + Vector2(-50, 0), Vector2.RIGHT.rotated(a) * 250.0, 1, "ebullet_needle")
			Audio.sfx("shot_fan", -12.0, 0.7)
			_hold(0.35, func(): _motion(_clamp_target(start), 0.7, "smooth"))
		)
	)

## Königin: Stachelsturz schräg auf die Biene, Gift-Spur, zurück in die Höhe.
func _p_queen_dive() -> void:
	_telegraph(0.55)
	telegraph_color = Color(1.0, 0.75, 0.25, 0.5)
	var g := get_parent()
	if g == null:
		return
	var start := position
	schedule(0.55, func():
		if dead:
			return
		var p: Vector2 = g.player_position()
		_motion(_clamp_target(Vector2(maxf(560.0, p.x + 160.0), p.y)), 0.5, "dash", 0.0, func():
			for k in range(6):
				g.spawn_enemy_bullet(position + Vector2(-30, 30), Vector2.LEFT.rotated(-0.6 + k * 0.24) * 230.0, 1, "ebullet_needle")
			_hold(0.25, func(): _motion(_clamp_target(start), 0.9, "smooth"))
		)
	)

## Wasserläufer: blitzschnelles Gleiten über die Bahn, Wellen spritzen hinterher.
## Wasserläufer: rast auf der Höhe der Biene quer durch die Arena und zurück; die
## zurückgelassenen Blasen zerplatzen kurz darauf zu Spritzern.
func _p_skim_strike() -> void:
	var g := get_parent()
	if g == null:
		return
	var lane := clampf((g.player_position() as Vector2).y, 130.0, 430.0)
	var start := position
	_telegraph(0.7)
	telegraph_color = Color(0.5, 0.85, 1.0, 0.5)
	_motion(_clamp_target(Vector2(position.x, lane)), 0.5, "smooth")
	schedule(0.75, func():
		if dead:
			return
		Audio.sfx("dash", -8.0, 0.8)
		_motion(Vector2(120.0, lane), 0.75, "smooth", 0.0, func():
			_hold(0.25, func(): _motion(_clamp_target(start), 0.8, "smooth")))
		for i in range(8):
			schedule(i * 0.09, func():
				var g2 := get_parent()
				if g2 == null or dead:
					return
				var at := position + Vector2(30, 0)
				var bubble: Dictionary = g2.bullets.spawn_enemy(at, Vector2.ZERO, 1, "ebullet_orb",
					{"life": 1.1, "scale": 1.3, "tint": Color(0.6, 0.85, 1.0), "aimed": false})
				schedule(1.0, func():
					var g3 := get_parent()
					if g3 == null or dead:
						return
					for k in range(4):
						g3.spawn_enemy_bullet(at, Vector2.UP.rotated(k * PI * 0.5 + 0.4) * 170.0, 1, "ebullet_spore",
							{"tint": Color(0.6, 0.85, 1.0)})
				)
			)
	)

## Wellenringe: drei Ringe aus Kugeln, jeder mit einer Lücke in Richtung der Biene.
func _p_ripple_ring() -> void:
	_telegraph(0.45)
	for r in range(3):
		schedule(0.45 + r * 0.38, func():
			var g := get_parent()
			if g == null or dead:
				return
			var gap: float = ((g.player_position() as Vector2) - position).angle() + _rng.randf_range(-0.5, 0.5)
			for k in range(18):
				var a := TAU * float(k) / 18.0
				if absf(wrapf(a - gap, -PI, PI)) < 0.42:
					continue
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(a) * 165.0, 1, "ebullet_orb",
					{"tint": Color(0.6, 0.85, 1.0)})
			Audio.sfx("hit", -12.0, 0.6)
		)

## Phase 3 "Die Rohre platzen": Dauerregen aus Wasserspritzern von oben, dazu Rohrbrüche.
var _pipe_t := 0.0
var _pipe_burst_t := 1.0

func _tick_pipes(delta: float) -> void:
	var g := get_parent()
	if g == null or phase_banner_t > 0.0:
		return
	_pipe_t -= delta
	_pipe_burst_t -= delta
	var p: Vector2 = g.player_position()
	while _pipe_t <= 0.0:
		_pipe_t += 0.09
		var x := _rng.randf_range(40.0, 920.0)
		var drift := clampf((p.x - x) * 0.25, -70.0, 70.0)
		g.spawn_enemy_bullet(Vector2(x, App.PLAY_TOP - 6.0), Vector2(drift, _rng.randf_range(250.0, 320.0)), 1,
			"ebullet_spore", {"tint": Color(0.6, 0.85, 1.0)})
	if _pipe_burst_t <= 0.0:
		_pipe_burst_t = 1.4
		var bx := clampf(p.x + _rng.randf_range(-160.0, 160.0), 60.0, 900.0)
		for k in range(7):
			g.spawn_enemy_bullet(Vector2(bx, App.PLAY_TOP - 6.0), Vector2.DOWN.rotated((k - 3) * 0.2) * 280.0, 1,
				"ebullet_spore", {"tint": Color(0.6, 0.85, 1.0)})
		if "fx" in g:
			g.fx.water_splash(Vector2(bx, App.PLAY_TOP + 4.0), 1.2)
		Audio.sfx("explosion_small", -12.0, 1.4)

func _p_skater_dash() -> void:
	_telegraph(0.4)
	var g := get_parent()
	if g == null:
		return
	var start := position
	schedule(0.4, func():
		if dead:
			return
		_motion(_clamp_target(Vector2(570.0, position.y)), 0.45, "smooth", 0.0, func():
			_hold(0.15, func(): _motion(_clamp_target(start), 0.6, "smooth")))
		for i in range(5):
			schedule(i * 0.1, func():
				if not dead:
					g.spawn_enemy_bullet(position + Vector2(40, 20), Vector2(40, -150 - i * 20), 1, "ebullet_orb")
			)
	)

## Erntemaschine: rollt mit drehender Dreschtrommel am Boden nach vorn.
func _p_harvester_ram() -> void:
	_telegraph(0.6)
	telegraph_color = Color(1.0, 0.5, 0.2, 0.5)
	var g := get_parent()
	if g == null:
		return
	var start := position
	schedule(0.6, func():
		if dead:
			return
		_motion(Vector2(570.0, _ground_y()), 0.7, "dash", 0.0, func():
			if g.has_method("shake"):
				g.shake(6.0)
			for k in range(7):
				g.spawn_enemy_bullet(position + Vector2(-70, -20), Vector2.LEFT.rotated(-0.9 + k * 0.15) * 220.0, 1, "ebullet_needle")
			_hold(0.3, func(): _motion(Vector2(start.x, _ground_y()), 1.1, "smooth"))
		)
	)

## Leuchtbrüllen: Körper glüht auf und pulsiert, klingt in die Wutfärbung aus.
func _tick_roar(delta: float) -> void:
	roar_t = maxf(0.0, roar_t - delta)
	var k := roar_t / ROAR_TIME
	# Pulsieren über die Helligkeit, nicht über die Größe: Trefferform bleibt exakt.
	var pulse := 0.6 + 0.4 * absf(sin((ROAR_TIME - roar_t) * 18.0))
	var glow := Color(1.6 + 1.2 * pulse, 1.3 + 0.8 * pulse, 1.0 + 0.6 * pulse).lerp(rage_tint, 1.0 - k * k)
	body.modulate = glow
	if roar_t <= 0.0:
		body.modulate = rage_tint

func phase_line(index: int) -> String:
	var lines: Array = PHASE_LINES.get(id, [])
	if index - 1 >= 0 and index - 1 < lines.size():
		return String(lines[index - 1])
	return "Der Gegner wird stärker!"

func _telegraph(t: float) -> void:
	telegraph = t
	telegraph_color = Color(1.0, 0.45, 0.35, 0.35)
	Audio.sfx("boss_warn", -20.0, 1.5)

# --------------------------------------------------------- Sichtbare Trefferform
func _texture(node: Node2D) -> Texture2D:
	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		return anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	return (node as Sprite2D).texture

static func _mask(tex: Texture2D) -> Dictionary:
	var key := tex.get_instance_id()
	if _collision_masks.has(key):
		return _collision_masks[key]
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	var rows: Array = []
	var bounds := Rect2()
	var first := true
	for y in range(image.get_height()):
		var runs: Array = []
		var start := -1
		for x in range(image.get_width() + 1):
			var opaque := x < image.get_width() and image.get_pixel(x, y).a >= HIT_ALPHA
			if opaque and start < 0:
				start = x
			elif not opaque and start >= 0:
				var run := Rect2(start, y, x - start, 1)
				runs.append(run)
				bounds = run if first else bounds.merge(run)
				first = false
				start = -1
		rows.append(runs)
	var result := {"rows": rows, "bounds": bounds, "size": Vector2(image.get_size())}
	_collision_masks[key] = result
	return result

func _sprite_to_game(node: Node2D, mask: Dictionary) -> Transform2D:
	var offset: Vector2 = node.get("offset")
	if bool(node.get("centered")):
		offset -= (mask.size as Vector2) * 0.5
	var flip := Vector2(-1.0 if bool(node.get("flip_h")) else 1.0,
		-1.0 if bool(node.get("flip_v")) else 1.0)
	return transform * node.transform * Transform2D(0.0, flip, 0.0, Vector2.ZERO) * Transform2D(0.0, offset)

## Ein Treffer pro Projektil, unabhängig davon, wie viele Flügel/Module es kreuzt.
## Koordinaten sind im selben Spielraum wie position und BulletField.p.
func trace_hit(from: Vector2, to: Vector2, radius: float = 0.0) -> Dictionary:
	if dead or reviving:
		return {}
	var targets: Array = [{"node": body, "part": -1}]
	if not twin_dead and is_instance_valid(twin):
		targets.append({"node": twin, "part": TWIN_PART})
	for i in range(parts.size()):
		var part: Dictionary = parts[i]
		if not part.dead and is_instance_valid(part.get("node")):
			targets.append({"node": part.node, "part": i})
	var result := {}
	var earliest := INF
	for item in targets:
		var node := item.node as Node2D
		if node == null or not node.visible:
			continue
		var mask := _mask(_texture(node))
		var matrix := _sprite_to_game(node, mask)
		var inverse := matrix.affine_inverse()
		var a := inverse * from
		var b := inverse * to
		var r := radius / maxf(0.001, minf(matrix.x.length(), matrix.y.length()))
		var bounds := (mask.bounds as Rect2).grow(r)
		if _rect_entry(a, b, bounds) < 0.0:
			continue
		var y0 := maxi(0, int(floor(minf(a.y, b.y) - r)))
		var y1 := mini((mask.rows as Array).size() - 1, int(floor(maxf(a.y, b.y) + r)))
		for y in range(y0, y1 + 1):
			for run: Rect2 in mask.rows[y]:
				var entry := _rect_entry(a, b, run.grow(r))
				if entry < 0.0 or entry >= earliest or not _capsule_rect(a, b, run, r):
					continue
				earliest = entry
				result = {"p": matrix * a.lerp(b, entry).clamp(run.position, run.end), "part": int(item.part)}
	return result

static func _rect_entry(a: Vector2, b: Vector2, rect: Rect2) -> float:
	var low := 0.0
	var high := 1.0
	var d := b - a
	for axis in range(2):
		if absf(d[axis]) < 0.000001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]:
				return -1.0
			continue
		var near := (rect.position[axis] - a[axis]) / d[axis]
		var far := (rect.end[axis] - a[axis]) / d[axis]
		low = maxf(low, minf(near, far))
		high = minf(high, maxf(near, far))
		if low > high:
			return -1.0
	return low

static func _capsule_rect(a: Vector2, b: Vector2, rect: Rect2, radius: float) -> bool:
	if _rect_entry(a, b, rect) >= 0.0:
		return true
	var squared := radius * radius
	if a.distance_squared_to(a.clamp(rect.position, rect.end)) <= squared or b.distance_squared_to(b.clamp(rect.position, rect.end)) <= squared:
		return true
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		if corner.distance_squared_to(Geometry2D.get_closest_point_to_segment(corner, a, b)) <= squared:
			return true
	return false

func _visual_bounds() -> Rect2:
	var nodes: Array = [body]
	for part in parts:
		if not part.dead and is_instance_valid(part.get("node")):
			nodes.append(part.node)
	var bounds := Rect2()
	var first := true
	for node: Node2D in nodes:
		var mask := _mask(_texture(node))
		var matrix := transform.affine_inverse() * _sprite_to_game(node, mask)
		var rect: Rect2 = mask.bounds
		for p in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
			var point: Vector2 = matrix * p
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	return bounds

func _clamp_playfield() -> void:
	if submerged:
		return
	var bounds := _stable_bounds()
	position.y = clampf(position.y, App.PLAY_TOP - bounds.position.y + 2.0,
		App.PLAY_BOTTOM - bounds.end.y - 2.0)

# --------------------------------------------------------------- Schaden
func _end_cave_in() -> void:
	if not _cave_shaft.is_empty():
		_cave_shaft.life = 0.0

func take_damage(amount: float, src: Vector2 = Vector2.ZERO, hit_part: int = -1) -> void:
	if dead or reviving or invuln > 0.0:
		return
	if not twin_dead:
		_pair_damage(amount, hit_part)
		return
	var dmg := amount * damage_mult
	if not vulnerable:
		dmg *= 0.35
	# Module absorbieren einen Teil, solange sie leben
	var alive_parts := parts.filter(func(p): return not p.dead)
	if not alive_parts.is_empty():
		var p: Dictionary = parts[hit_part] if hit_part >= 0 and hit_part < parts.size() and not parts[hit_part].dead else alive_parts[0]
		p.hp -= dmg
		if p.hp <= 0.0:
			p.dead = true
			_bounds_dirty = true
			if p.get("node", null) != null and is_instance_valid(p.node):
				p.node.queue_free()
			Audio.sfx("explosion_big", -6.0, 1.2)
		dmg *= 0.45
	hp -= dmg
	hit_flash = 0.06
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
		return
	# Phasenwechsel prüfen
	for i in range(phase_defs.size() - 1, phase - 1, -1):
		if i > phase and hp <= max_hp * float(phase_defs[i].get("hp", 0.0)):
			_apply_phase(i)
			break

func _is_final_encounter() -> bool:
	var final_level: Dictionary = Data.level(Data.levels.size())
	return id == String(final_level.get("boss", "")) and level_index == int(final_level.get("id", 10))

func _ensure_reborn_visual() -> void:
	if is_instance_valid(reborn_visual):
		return
	reborn_visual = REBORN_VISUAL.new()
	reborn_visual.z_index = 6
	add_child(reborn_visual)

func _set_reborn_body() -> void:
	rage_tint = Color.WHITE
	roar_t = 0.0
	_bounds_dirty = true
	var frames: SpriteFrames = REBORN_VISUAL.frames_for_phase(phase)
	if frames == null:
		return
	if body is AnimatedSprite2D:
		(body as AnimatedSprite2D).sprite_frames = frames
		(body as AnimatedSprite2D).play("default")
	else:
		body.queue_free()
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.z_index = 4
		add_child(anim)
		anim.play("default")
		body = anim

func _begin_reviving() -> void:
	reviving = true
	fake_dead = true
	revive_t = 0.0
	_revive_stage = 0
	_next_blast = 0.0
	hp = 0.0
	vulnerable = false
	invuln = REVIVE_TIME
	attack_in_progress = false
	timeline.clear()
	motion = {}
	hit_flash = 0.0
	damage_mult = 1.0
	name_text = "Kernorganismus"
	_ensure_reborn_visual()
	# Status sofort setzen (ruhige Variante bei reduzierten Effekten), sichtbar erst in Akt 3.
	reborn_visual.set_status(0, 0.0, 0.0)
	reborn_visual.visible = false
	# Platz für die größere neue Silhouette schaffen, ohne einen Positionssprung.
	_revive_target = Vector2(position.x, clampf(position.y, App.PLAY_TOP + 114.0, App.PLAY_BOTTOM - 114.0))
	var g := get_parent()
	if g != null and g.has_method("clear_enemy_bullets"):
		g.clear_enemy_bullets()
	# Akt 1: der Kern stirbt scheinbar wie jeder andere Boss.
	Audio.sfx("boss_death", 0.0, 1.0)

func _calm_effects() -> bool:
	return bool(Save.g("access.reduce_effects", false)) or not bool(Save.g("graphics.flashes", true))

func _tick_reviving(delta: float) -> void:
	revive_t += delta
	position = position.move_toward(_revive_target, SPEED_TRANSITION * delta)
	core_glow.visible = false
	var g := get_parent()
	if revive_t < DEATH_END:
		# Untergang: Aufblitzen (ruhig bei reduzierten Effekten), Drehen, Explosionen.
		if _calm_effects():
			body.modulate = Color(1, 1, 1, maxf(0.3, 1.0 - revive_t / DEATH_END))
		else:
			body.modulate = Color(2.0, 1.2, 0.8) if int(revive_t * 8.0) % 2 == 0 else Color(1, 1, 1, 0.6)
		body.rotation += delta * 0.6
		if revive_t >= _next_blast and g != null:
			_next_blast = revive_t + 0.32
			if g.has_method("spawn_explosion"):
				g.spawn_explosion(position + Vector2(randf_range(-60, 60), randf_range(-50, 50)), 1.2)
			if g.has_method("shake"):
				g.shake(5.0)
	elif revive_t < CALM_END:
		if _revive_stage < 1:
			# Akt 2: Sieg! Kern zerbirst, Siegesmusik, Ruhe.
			_revive_stage = 1
			body.visible = false
			if g != null:
				if g.has_method("spawn_explosion"):
					g.spawn_explosion(position, 2.4)
				if g.has_method("shake"):
					g.shake(12.0)
				if g.app != null and g.app.hud != null and g.app.hud.has_method("show_banner"):
					g.app.hud.show_banner("KERNORGANISMUS BESIEGT!", 3.0)
			Audio.play_music("level_clear", 0.3)
	else:
		if _revive_stage < 2:
			# Akt 3: Stille, Grollen – etwas regt sich in den Trümmern.
			_revive_stage = 2
			Audio.stop_music(0.6)
			Audio.sfx("boss_warn", -2.0, 0.6)
			_set_reborn_body()
			body.visible = true
			body.rotation = 0.0
			reborn_visual.visible = true
			if g != null and g.app != null and g.app.hud != null and g.app.hud.has_method("show_banner"):
				g.app.hud.show_banner("… DER KERN LEBT!", 2.6)
		var k := clampf((revive_t - CALM_END) / (REVIVE_TIME - CALM_END), 0.0, 1.0)
		# Neubildung: wächst aus einem glimmenden Rest, bebt zunehmend.
		body.scale = Vector2.ONE * lerpf(0.25, 1.0, k * k)
		var flicker := 1.0 if _calm_effects() else (0.7 + 0.3 * sin(revive_t * 30.0))
		body.modulate = Color(1.0, 0.8, 0.95, lerpf(0.2, 1.0, k) * flicker)
		reborn_visual.set_status(0, k, 0.0)
		if g != null and g.has_method("shake") and int(revive_t * 6.0) != int((revive_t - delta) * 6.0):
			g.shake(2.0 + 8.0 * k)
	if revive_t >= REVIVE_TIME:
		if g != null and g.has_method("_boss_music"):
			Audio.play_music(g._boss_music(id), 0.2)
		_finish_reviving()

func _finish_reviving() -> void:
	reviving = false
	encounter_form = 2
	timeline.clear()
	max_hp = first_form_max_hp * REBORN_HP_MULT
	hp = max_hp
	# Keine erneute Bedrohungsaufbereitung: diese Form besitzt GENAU drei Phasen.
	phase_defs = [
		{"hp": 1.0, "patterns": ["reborn_crown", "reborn_lance"], "interval": 1.15 * 0.8, "move": "orbit"},
		{"hp": 0.66, "patterns": ["reborn_wings", "reborn_lance", "safe_zone", "reborn_crown"], "interval": 0.9 * 0.8, "move": "weave"},
		{"hp": 0.33, "patterns": ["reborn_storm", "safe_zone", "reborn_wings", "reborn_lance"], "interval": 0.6 * 0.8, "move": "final"},
	]
	name_text = "Kern · Wiedergeboren"
	fake_dead = false
	body.visible = true
	if is_instance_valid(reborn_visual):
		reborn_visual.visible = true
	weak_text = "Drei Kronenphasen – den angekündigten Speeren ausweichen."
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	body.rotation = 0.0
	vulnerable = true
	damage_mult = 1.0
	move_swap_t = 0.0
	move_calls = 0
	_apply_phase(0)
	_clamp_playfield()
	reborn_visual.set_status(0, -1.0, telegraph)
	hp_changed.emit(hp, max_hp)
	var g := get_parent()
	if g != null and g.has_method("clear_enemy_bullets"):
		g.clear_enemy_bullets()

func _die() -> void:
	_end_cave_in()
	if dead or reviving:
		return
	Bindings.rumble(0.8, 1.0, 0.9)
	if encounter_form == 1 and _is_final_encounter():
		_begin_reviving()
		return
	dead = true
	if encounter_form == 2:
		timeline.clear()
		reborn_visual.visible = false
	dying_t = 0.0
	vulnerable = false
	Audio.sfx("boss_death", 0.0, 1.0)
	defeated.emit()

func _dying_tick(delta: float) -> void:
	if encounter_form == 2 and (bool(Save.g("access.reduce_effects", false)) or not bool(Save.g("graphics.flashes", true))):
		body.modulate = Color(1.0, 1.0, 1.0, maxf(0.25, 1.0 - dying_t / 3.0))
	elif int(dying_t * 8.0) % 2 == 0:
		body.modulate = Color(2.0, 1.2, 0.8)
	else:
		body.modulate = Color(1, 1, 1, 0.6)
	body.rotation += delta * 0.6
	if dying_t > 2.4:
		var g := get_parent()
		if g != null and g.has_method("spawn_explosion"):
			g.spawn_explosion(position, 2.2)
		queue_free()
