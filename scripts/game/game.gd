class_name Game
extends Node2D
## Spielwelt eines Levels: Spieler, Gegner, Boss, Geschosse, Sammelobjekte,
## Gefahrenmechaniken, Checkpoints und Abschlussauswertung.

signal state_changed

var app: Node
var mode: String = "campaign"
var level_index: int = 1
## Grundgeschwindigkeit der Welt in Pixeln je Sekunde (Bezug für den Hintergrund).
const WORLD_SCROLL := 78.0
var eb_speed: float = 1.0
var checkpoint: int = 0
var level_data: Dictionary = {}
var difficulty: Dictionary = {}

var background: Background
var lighting_vignette: TextureRect
var lighting_top: Sprite2D
var bullets: BulletField
var fx: Fx
var player: Player
const MastersScript := preload("res://scripts/game/masters.gd")
var masters: Node2D
var _last_crit := false
var director: Director
var enemies: Array = []
var pickups: Array = []
var camera: Camera2D

var boss: Boss = null
var miniboss: Enemy = null
var boss_sequence: Array = []
var rush_index: int = 0
var rush_supply_t: float = 0.0
var rush_between := false

var stats := {"score": 0, "kills": 0, "hits": 0, "shots": 0, "time": 0.0, "bosses": 0}
var resume_delay := 0.0
var dead_timer := 0.0
var level_over := false
var boss_intro_t := 0.0
var shake_amount := 0.0
var shake_time := 0.0
var push = Vector2.ZERO
var checkpoint_snapshot: Dictionary = {}
var last_kill_times: Array = []
var swarm_call_cd := 0.0
var rng := RandomNumberGenerator.new()
var started := false
var tutorial_t: float = 0.0
var banner_queue: Array = []
var pollen_clouds: Array = []
var mech_state := {}
## Stillstand beim Bossphasenwechsel (s): Raum für Brüllen, Schockwelle, Banner.
const PHASE_STAGGER := 0.85
var phase_stagger := 0.0
## Glasscheiben (Level 6): Vorwarnzeit und Haltbarkeit in Sekunden Dauerfeuer.
const GLASS_WARN := 1.6
const GLASS_DPS_SECONDS := 2.4
const GLASS_MIN_HP := 60.0
## Höhe der Wasserfontänen in Level 3 (Weltpunkte).
const GEYSER_HEIGHT := 240.0
var frozen_by_death := false
## Steigt bei jedem Checkpoint-Neustart; veraltete Bossankündigungen verfallen.
var _stage_generation := 0
## Ganzzahliger Dichteakkumulator: vier von fünf Anforderungen, ohne RNG.
var _enemy_bullet_density := 0
var _enemy_bullet_difficulty := ""

func setup(cfg: Dictionary) -> void:
	app = cfg.get("app", null)
	mode = String(cfg.get("mode", "campaign"))
	level_index = int(cfg.get("level", 1))
	checkpoint = int(cfg.get("checkpoint", 0))
	level_data = Data.level(level_index)
	eb_speed = 1.0 + 0.035 * float(clampi(level_index - 1, 0, 9))
	difficulty = Data.DIFFICULTY.get(String(Save.campaign.get("difficulty", "normal")), Data.DIFFICULTY["normal"])
	rng.seed = int(Save.campaign.get("seed", 1)) * 131 + level_index
	_build_nodes()
	_apply_level_build()
	director.setup(level_data, level_index, mode, int(Save.campaign.get("seed", 1)), checkpoint)
	_take_checkpoint_snapshot()
	Audio.play_music(String(level_data.get("music", "level1")), 0.8, _level_music_start())
	started = true
	_notify(Loc.t("level." + str(level_index)), 3.0)
	# Einstellung „Tutorialhinweise“: im ersten Level einer neuen Kampagne die
	# aktuelle Tastenbelegung als Banner einblenden (folgen auf den Levelnamen).
	if mode == "campaign" and bool(Save.g("game.tutorial", true)) and bool(Save.campaign.get("level_stats", {}).is_empty()):
		tutorial_t = 9.0
		for line in control_hints():
			_notify(line, 3.0)
	if mode == "tutorial":
		add_child(load("res://scripts/game/tutorial.gd").new(self))
	if mode == "rush":
		_start_boss_rush()

## Dezente Bildfassung: leichter Lichteinfall von oben und eine weiche Vignette.
## Beides liegt über der Szene, aber unter der Anzeige (HUD) und stört nichts.
func _build_lighting() -> void:
	var vign_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/fx/vignette.png"):
		vign_tex = load("res://assets/fx/vignette.png")
	if vign_tex != null and bool(Save.g("graphics.lighting", true)):
		var v := TextureRect.new()
		v.texture = vign_tex
		v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		v.position = Vector2.ZERO
		v.size = Vector2(960, 540)
		v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.modulate = Color(1, 1, 1, 0.45)
		v.z_index = 40
		add_child(v)
		lighting_vignette = v
	if ResourceLoader.exists("res://assets/fx/light_top.png"):
		var tex: Texture2D = load("res://assets/fx/light_top.png")
		if tex != null and bool(Save.g("graphics.lighting", true)):
			var s2 := Sprite2D.new()
			s2.texture = tex
			s2.centered = false
			s2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			s2.scale = Vector2(20.0, 1.35)
			s2.position = Vector2(-160, -40)
			s2.modulate = Color(1, 1, 1, 0.38)
			s2.z_index = 39
			add_child(s2)
			lighting_top = s2

func _build_nodes() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(480, 270)
	# Welt im 960er-Raster, Bild im doppelt so feinen Viewport.
	camera.zoom = Vector2.ONE * App.RENDER_SCALE
	camera.enabled = true
	add_child(camera)
	background = Background.new()
	background.z_index = -60
	add_child(background)
	background.setup(level_data)
	bullets = BulletField.new()
	bullets.contrast_mode = bool(Save.g("access.contrast_hazards", true))
	add_child(bullets)
	_build_lighting()
	fx = Fx.new()
	add_child(fx)
	director = Director.new()
	add_child(director)
	player = Player.new()
	add_child(player)
	masters = MastersScript.new(self)
	add_child(masters)
	player.died.connect(_on_player_died)
	player.notice.connect(func(t): _notify(t, 1.4))
	director.spawn_enemy_requested.connect(_on_spawn_enemy)
	director.hazard_requested.connect(_on_hazard)
	director.checkpoint_reached.connect(_on_checkpoint)
	director.miniboss_started.connect(_on_miniboss)
	director.boss_triggered.connect(_on_boss_triggered)

func _apply_level_build() -> void:
	var build: Dictionary = {
		"difficulty": Save.campaign.get("difficulty", "normal"),
		"hp": Save.campaign.get("hp", 3),
		"max_hp": Save.campaign.get("max_hp", 3),
		"nectar": Save.campaign.get("nectar", 0),
		"points": Save.campaign.get("points", 0),
		"weapon": Save.campaign.get("weapon", "base"),
		"upgrades": Save.campaign.get("upgrades", {}),
		"shop": Save.campaign.get("shop", {}),
		"speed_level": Save.campaign.get("speed_level", 0),
		"evolutions": Save.campaign.get("evolutions", []),
	}
	player.setup(build)
	stats.shots = 0
	stats.kills = 0
	stats.hits = 0
	stats.time = 0.0
	stats.score = int(build.points)
	if String(level_data.get("mechanic", "")) == "water":
		fx.add_hazard({"kind": "water_line", "p": Vector2.ZERO, "y": 470.0, "t": 0.0,
			"life": 1.0e9, "max_life": 1.0e9})

# ------------------------------------------------------------------ Hauptloop
func _physics_process(delta: float) -> void:
	if not started:
		return
	if level_over:
		fx.update(delta)
		return
	if phase_stagger > 0.0:
		# Bossphasenwechsel: kurzer Stillstand, Effekte und Bossleuchten laufen weiter.
		phase_stagger -= delta
		fx.update(delta)
		_update_shake(delta)
		return
	if resume_delay > 0.0:
		resume_delay -= delta
		_update_shake(delta)
		# Levelzeit steht – die durchkomponierte Musik wartet mit.
		Audio.set_music_hold(true)
		return
	Audio.set_music_hold(false)
	if frozen_by_death:
		dead_timer -= delta
		fx.update(delta)
		bullets.update(delta, player.position, _homing_targets())
		_update_shake(delta)
		if dead_timer <= 0.0:
			frozen_by_death = false
			if app != null and app.has_method("show_game_over"):
				app.show_game_over()
			else:
				_restore_checkpoint()
		return
	stats.time += delta
	director.update(delta)
	if mode != "rush":
		Audio.sync_music(String(level_data.get("music", "level1")), director.music_pos())
	background.update(delta, WORLD_SCROLL)
	bullets.update(delta, player.position, _homing_targets())
	fx.update(delta)
	_update_shake(delta)
	_update_push(delta)
	_update_pickups(delta)
	_update_hazards(delta)
	_tick_safe_zone(delta)
	_tick_flood(delta)
	_update_collisions()
	_update_pollens(delta)
	masters.update(delta)
	swarm_call_cd = maxf(0.0, swarm_call_cd - delta)
	if tutorial_t > 0.0:
		tutorial_t -= delta
	if boss != null and is_instance_valid(boss):
		if boss.hp < boss.max_hp:
			pass
	# Boss besiegt?
	if boss != null and boss.dead and not level_over:
		pass

func _update_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		var s := shake_amount * clampf(shake_time / 0.25, 0.0, 1.0)
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))

func shake(amount: float) -> void:
	var mult := float(Save.g("graphics.shake", 0.6))
	if mult <= 0.0:
		return
	shake_amount = maxf(shake_amount, amount * mult)
	shake_time = 0.3

func _update_push(delta: float) -> void:
	push = push.lerp(Vector2.ZERO, clampf(delta * 1.6, 0.0, 1.0))
	# Strömung darf nie stärker schieben, als die Biene fliegen kann.
	push = push.limit_length(Player.BASE_SPEED * 0.62)

func is_play_frozen() -> bool:
	return resume_delay > 0.0 or frozen_by_death or level_over or phase_stagger > 0.0

func start_resume_delay(t: float) -> void:
	resume_delay = t

# ------------------------------------------------------------------- Spawning
## Grundlage der Gegnerhärte: Die Bewaffnung wird immer stärker, die Gegner
## wachsen mit. Ohne diese Kopplung fällt alles beim Eintreffen um.
const REF_DPS := 125.0        # Angriffskraft der Grundbewaffnung ohne Verbesserungen
const HP_BASE_MULT := 2.4     # Grundhärte: kein Gegner fällt mehr im ersten Bild
const REF_SHOT := 7.4         # Schaden einer Grundkugel
## Wenige starke Kugeln sind etwas anderes als viele schwache: der Schaden je
## Kugel geht mit kleinerem Gewicht in die Härte ein.
const HP_SHOT_EXP := 0.10
## Etwas flacher als die Bewaffnung wächst: Verbesserungen sollen sich in
## kürzeren Kämpfen zeigen, nicht nur in mehr Kugeln auf dem Bild.
const HP_POWER_EXP := 0.55

## Faktor auf die Lebenspunkte aller Gegner dieser Ebene.
func enemy_hp_mult() -> float:
	var dps := maxf(REF_DPS, player.attack_dps())
	var per := maxf(REF_SHOT, player.shot_power())
	var power := pow(dps / REF_DPS, HP_POWER_EXP) * pow(per / REF_SHOT, HP_SHOT_EXP)
	return HP_BASE_MULT * power * float(Director.pressure_for_level(level_index).enemy_hp)

func _on_spawn_enemy(id: String, pos: Vector2, opts: Dictionary) -> void:
	if id == "generator_unit" and _generator_count_live() >= 2:
		return
	var o := opts.duplicate()
	o["hp_mult"] = float(o.get("hp_mult", 1.0)) * enemy_hp_mult()
	o["fire_mult"] = float(o.get("fire_mult", 1.0)) * float(Director.pressure_for_level(level_index).fire_mult)
	o["difficulty"] = difficulty
	var e := Enemy.new()
	e.setup(id, pos, o)
	add_child(e)
	enemies.append(e)
	e.killed.connect(_on_enemy_killed)

## Für Prüfläufe: Gegner direkt setzen und zurückgeben.
func spawn_enemy(id: String, pos: Vector2, opts: Dictionary = {}) -> Node:
	var previous_count := enemies.size()
	_on_spawn_enemy(id, pos, opts)
	if enemies.size() == previous_count:
		return null
	return enemies[enemies.size() - 1]

## Für Prüfläufe: Blütenstaubmenge eines Tropfens an dieser Stelle.
## roll < 0: echter Zufallswurf für "Reichere Beute" (Chance auf einen Tropfen mehr),
## scent_roll < 0: echter Zufallswurf für Duftspur (10 % je Stufe, verschmolzen ×1,5).
func drop_amount(amount: int, roll: float = -1.0, scent_roll: float = -1.0) -> int:
	var r := rng.randf() if roll < 0.0 else roll
	var s := rng.randf() if scent_roll < 0.0 else scent_roll
	var scent := 1 if s < player.evo_effect("nectar_drop_chance") else 0
	return amount + scent + (1 if r < nectar_bonus_chance() else 0)

## "Reichere Beute": Wahrscheinlichkeit eines zusätzlichen Blütenstaubs je Gegner.
func nectar_bonus_chance() -> float:
	return clampf(player.shop_mod("nectar_plus"), 0.0, 1.0)

## Für Prüfläufe: Radius der Druckwelle.
func player_pulse_radius() -> float:
	return 150.0 * (1.0 + player.shop_mod("bomb_radius"))

func _on_enemy_killed(e: Enemy) -> void:
	mark_table.erase(e.get_instance_id())
	enemies.erase(e)
	stats.kills += 1
	var score_gain := int(float(e.score) * float(difficulty.score_mult) *
		(1.0 + player.shop_mod("combo")))
	stats.score += score_gain
	player.add_points(score_gain)
	fx.explode(e.position, 1.0 + e.radius / 20.0)
	shake(3.0)
	_drop_nectar(e.position, e.nectar_drop)
	last_kill_times.append(stats.time)
	if masters != null:
		masters.on_kill(e)
	# Pollenexplosion
	if player.evo_has("pollen_burst"):
		spawn_pollen(e.position, 1.4 * player.fusion_factor("pollen_burst"), true)
	# Schwarmruf
	if player.evo_has("swarm_call"):
		while last_kill_times.size() > 0 and stats.time - float(last_kill_times[0]) > 3.0:
			last_kill_times.pop_front()
		if last_kill_times.size() >= int(player.evo_effect("swarm_call")) and swarm_call_cd <= 0.0:
			swarm_call_cd = 6.0
			last_kill_times.clear()
			_swarm_strike()

func _drop_nectar(pos: Vector2, amount: int) -> void:
	var total := drop_amount(amount)
	var count := clampi(total, 1, 5)
	for i in range(count):
		var p := Pickup.new()
		add_child(p)
		var value := ceili(float(total - i) / float(count))
		p.setup("nectar", pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), value)
		pickups.append(p)
	if rng.randf() < 0.045:
		var h := Pickup.new()
		add_child(h)
		h.setup("heart", pos + Vector2(0, -12), 1)
		pickups.append(h)

func _on_hazard(kind: String, data: Dictionary) -> void:
	match kind:
		"blossom":
			var p := Pickup.new()
			add_child(p)
			p.setup("blossom", Vector2(900, float(data.y) * App.PLAY_BOTTOM), 3)
			pickups.append(p)
			fx.add("blossom", Vector2(880, float(data.y) * App.PLAY_BOTTOM), {"life": 0.9, "scale": 2.4})
		"root_spike":
			var x := randf_range(260.0, 820.0)
			fx.add_hazard({"kind": "root_spike", "p": Vector2(x, 0), "base": Vector2(x, App.PLAY_BOTTOM),
				"t": 0.0, "life": 2.6, "max_life": 2.6, "warn": 0.9, "dmg": 1})
		"water_splash":
			var x2 := randf_range(200.0, 860.0)
			# Fontäne: dreimal so hoch und doppelt so lang wie eine Wurzel-Säule.
			fx.add_hazard({"kind": "root_spike", "p": Vector2(x2, 0), "base": Vector2(x2, App.PLAY_BOTTOM),
				"t": 0.0, "life": 3.6, "max_life": 3.6, "warn": 0.7, "dmg": 1, "style": "water",
				"height": GEYSER_HEIGHT})
		"spore_cloud":
			fx.add_hazard({"kind": "spore_cloud", "p": Vector2(1060, float(data.y) * App.PLAY_BOTTOM),
				"radius": 62.0, "t": 0.0, "life": 7.0, "max_life": 7.0,
				"vel": Vector2(-95, 0), "dmg": 1, "hit_cd": 0.0,
				"color": Color(0.5, 1.0, 0.8, 0.3)})
		"wind_zone":
			fx.add_hazard({"kind": "wind_marker", "p": Vector2.ZERO, "dir": float(data.dir),
				"t": 0.0, "life": 3.4, "max_life": 3.4, "push": float(data.dir) * 120.0})
		"reflect_panel":
			var panel_y := rng.randf_range(float(App.PLAY_TOP) + 84.0, float(App.PLAY_BOTTOM) - 84.0)
			# Zerbrechlich: einige gezielte Salven (Trefferpunkte nach aktueller Feuerkraft).
			var glass_hp := maxf(GLASS_MIN_HP, player.attack_dps() * GLASS_DPS_SECONDS)
			fx.add_hazard({"kind": "reflect_panel", "p": Vector2(rng.randf_range(420, 780), panel_y),
				"w": 70.0, "h": 160.0, "t": 0.0, "life": 7.6, "max_life": 7.6, "warn": GLASS_WARN,
				"hp": glass_hp, "max_hp": glass_hp, "cracks": [], "hit_flash": 0.0})
			Audio.sfx("glass_warn", -6.0, 1.0)
		"current":
			fx.add_hazard({"kind": "current", "p": Vector2.ZERO, "dir": float(data.dir),
				"t": 0.0, "life": 4.5, "max_life": 4.5, "push": float(data.dir) * 90.0})
		"gravity_pulse", "gravity_field":
			if not safe_zone.is_empty():
				return
			# Kraft statt Schadensring. Der Player addiert gravity_pull() separat:
			# kein Wind-Gegenfilter, auch im Präzisionsflug zehn Prozent Reserve.
			fx.add_hazard({"kind": "gravity_field", "p": Vector2.ZERO,
				"t": 0.0, "life": 2.8, "max_life": 2.8})
		"order_marker", "generator_relay":
			_spawn_generator_relay()

## Keine Nummernfalle: echte abschießbare Generatoren, freie Reihenfolge,
## höchstens zwei gleichzeitig. Die zeitgesteuerte Bossfreigabe bleibt unverändert.
func _generator_count_live() -> int:
	var count := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.id == "generator_unit":
			count += 1
	return count

func _spawn_generator_relay() -> void:
	if level_over or (director != null and director.boss_started) or boss != null:
		return
	var count := _generator_count_live()
	if count >= 2:
		return
	var lane := float(App.PLAY_TOP) + 90.0 if count == 0 else float(App.PLAY_BOTTOM) - 90.0
	_on_spawn_enemy("generator_unit", Vector2(1010, lane), {"target_x": 800.0 + 35.0 * float(count)})
	_notify("Generator-Verstärkung – zerstören, Reihenfolge frei", 2.5)

func _update_hazards(delta: float) -> void:
	for h in fx.hazards:
		match String(h.kind):
			"root_spike":
				if String(h.get("style", "")) == "water":
					# Brunnensäule: Trefferform = gezeichneter Strahl samt Krone.
					if Fx.geyser_hits(h, player.position, 4.6 * (1.0 + player.evo_effect("hitbox"))) and player.take_damage(1, h.base):
						fx.hit_spark(player.position, Color(0.7, 0.9, 1.0))
					continue
				var frac := 1.0 - float(h.life) / float(h.max_life)
				var height := float(h.get("height", 80.0)) * clampf(frac * float(h.max_life) / float(h.warn), 0.0, 1.0)
				var elapsed := frac * float(h.max_life)
				if elapsed > float(h.warn) * 0.72 and height > 20.0:
					var base: Vector2 = h.base
					if absf(player.position.x - base.x) < 20.0 and player.position.y > base.y - height:
						if player.take_damage(1, base):
							fx.hit_spark(player.position, Color(1, 0.7, 0.4))
			"spore_cloud", "pollen_cloud":
				h.p += (h.get("vel", Vector2(-60, 0)) as Vector2) * delta
				h.p.y += sin(float(h.t) * 1.6) * 12.0 * delta
				h.hit_cd = maxf(0.0, float(h.get("hit_cd", 0.0)) - delta)
				if not bool(h.get("friendly", false)) and h.p.distance_to(player.position) < float(h.radius) * 0.82 and float(h.hit_cd) <= 0.0:
					h.hit_cd = 1.0
					player.take_damage(1, h.p)
			"wind_marker":
				var fade := clampf(float(h.life) / 0.8, 0.0, 1.0)
				# push enthält das Vorzeichen bereits; nicht nochmals dir multiplizieren.
				push.y += float(h.get("push", 100.0)) * fade * delta * 1.9
				push = push.limit_length(Player.BASE_SPEED * 0.62)
			"current":
				push.x += float(h.get("push", 80.0)) * delta * 2.4
			"reflect_panel":
				if Fx.is_warning(h) or float(h.get("hp", 1.0)) <= 0.0:
					continue
				h.hit_flash = maxf(0.0, float(h.get("hit_flash", 0.0)) - delta)
				var rect := Fx.panel_rect(h)
				var keep: Array = []
				for b in bullets.player_bullets:
					if float(h.get("hp", 1.0)) > 0.0 and _bullet_hits_panel(b, rect):
						var contact: Vector2 = Geometry2D.get_closest_point_to_segment(rect.get_center(), b.get("prev_p", b.p), b.p).clamp(rect.position, rect.end)
						fx.hit_spark(contact, Color(0.7, 0.9, 1.0))
						_damage_glass(h, float(b.get("dmg", 1.0)), contact, rect)
						continue
					keep.append(b)
				bullets.player_bullets = keep

	# Nicht nur Spawns: Abwehr reagiert auch auf bereits anfliegende Geschosse.
	for b in bullets.enemy_bullets:
		_apply_pollen_defenses(b)

## Wassersäule (Brunnenstrahl mit Vorwarnung) – Level 3 und der Hecht-Boss.
func spawn_geyser(x: float, height: float = GEYSER_HEIGHT, life: float = 3.6, warn: float = 0.7) -> void:
	fx.add_hazard({"kind": "root_spike", "p": Vector2(x, 0), "base": Vector2(x, App.PLAY_BOTTOM),
		"t": 0.0, "life": life, "max_life": life, "warn": warn, "dmg": 1, "style": "water", "height": height})

## Bodenausbruch (Erdsäule mit Vorwarnung) – für Bossangriffe.
func spawn_ground_spike(x: float, warn: float = 0.55, height: float = 96.0, life: float = 1.5) -> void:
	fx.add_hazard({"kind": "root_spike", "p": Vector2(x, 0), "base": Vector2(x, App.PLAY_BOTTOM),
		"t": 0.0, "life": life, "max_life": life, "warn": warn, "dmg": 1, "height": height})

## Risse und rieselnder Staub an der Decke: kündigt herabfallende Brocken an.
func spawn_ceiling_warning(x: float, seconds: float) -> void:
	fx.add_hazard({"kind": "ceiling_crack", "p": Vector2(x, App.PLAY_TOP), "t": 0.0,
		"life": seconds, "max_life": seconds})

## Glasscheibe nimmt Schaden; Risse an den Trefferstellen, bei 0 zerspringt sie.
func _damage_glass(h: Dictionary, dmg: float, contact: Vector2, rect: Rect2) -> void:
	var before := float(h.hp)
	h.hp = before - dmg
	h.hit_flash = 0.12
	var cracks: Array = h.cracks
	var max_hp := float(h.max_hp)
	# Je verlorenem Fünftel ein neuer Riss an der aktuellen Trefferstelle.
	if int(floor((1.0 - before / max_hp) * 5.0)) < int(floor((1.0 - float(h.hp) / max_hp) * 5.0)) and cracks.size() < 6:
		cracks.append(contact)
		Audio.sfx("glass_hit", -4.0, randf_range(0.85, 1.0))
	else:
		Audio.sfx("glass_hit", -14.0, randf_range(1.0, 1.25))
	if float(h.hp) <= 0.0:
		h.life = 0.0
		fx.shatter(rect, contact)
		Audio.sfx("glass_break", -1.0, 1.0)
		shake(5.0)
		var bonus := int(250.0 * float(difficulty.score_mult))
		stats.score += bonus
		player.add_points(bonus)
		fx.add_text(rect.get_center(), "+%d" % bonus, Color(0.7, 0.95, 1.0), 14)

## Nur das wirklich durchflogene Segment, niemals eine vorausberechnete Strecke.
func _bullet_hits_panel(b: Dictionary, panel: Rect2) -> bool:
	if float(b.get("life", 0.0)) <= 0.0:
		return false
	var rect := panel.grow(float(b.get("r", 0.0)) * 0.6)
	var a: Vector2 = b.get("prev_p", b.p)
	var z: Vector2 = b.p
	if rect.has_point(a) or rect.has_point(z):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for edge in range(4):
		if Geometry2D.segment_intersects_segment(a, z, corners[edge], corners[(edge + 1) % 4]) != null:
			return true
	return false

## Sichttrübung: Chance, dass ein gezieltes Geschoss in einer Pollenwolke erlischt.
const BLIND_CHANCE := 0.15
## Wind im Kernlevel (Anteil der Biene-Geschwindigkeit) und die Schutzzonen-Attacke.
const GRAVITY_STRENGTH := 0.65
const SAFE_ZONE_RADIUS := 34.0
const SAFE_ZONE_REACTION := 0.35
const SAFE_ZONE_DAMAGE := 3
var safe_zone: Dictionary = {}
## Wasserläufer „Die Kanäle fluten!“: das untere Feld steht unter Wasser, Berührung schadet.
const FLOOD_SHARE := 0.30
const FLOOD_RISE_TIME := 2.5
var flood: Dictionary = {}

func _apply_pollen_defenses(b: Dictionary) -> void:
	if player == null or float(b.life) <= 0.0:
		return
	var in_aura := player.evo_has("pollen_shield") and (b.p as Vector2).distance_to(player.position) <= 130.0 * player.fusion_factor("pollen_shield", 1.35)
	if in_aura:
		if not b.has("pollen_base_slow"):
			b["pollen_base_slow"] = float(b.get("slow", 1.0))
		b.slow = minf(float(b.pollen_base_slow), 0.55)
	elif b.has("pollen_base_slow"):
		b.slow = float(b.pollen_base_slow)
		b.erase("pollen_base_slow")
	if not player.evo_has("pollen_blind") or not bool(b.get("aimed", true)) or fx == null:
		return
	# Sichttrübung: nur eigene Pollenwolken, höchstens eine Chance je Geschoss.
	if bool(b.get("blind_checked", false)):
		return
	for h in fx.hazards:
		if String(h.kind) != "pollen_cloud" or not bool(h.get("friendly", false)):
			continue
		if not _segment_hit(b, h.p, float(h.radius)):
			continue
		if not h.has("blind_id"):
			mech_state["pollen_id"] = int(mech_state.get("pollen_id", 0)) + 1
			h["blind_id"] = int(mech_state.pollen_id)
		var seen: Dictionary = b.get("pollen_seen", {})
		if seen.has(h.blind_id):
			continue
		seen[h.blind_id] = true
		b["pollen_seen"] = seen
		b["blind_checked"] = true
		if rng.randf() < BLIND_CHANCE * player.fusion_factor("pollen_blind", 1.5):
			b.life = 0.0
		return

func current_push() -> Vector2:
	return push.limit_length(Player.BASE_SPEED * 0.62)

## Kernorganismus: der ganze Schirm wird zur Warnfläche bis auf eine Schutzzone.
## Das Zeitfenster reicht mit Grundgeschwindigkeit gerade von der fernsten Ecke.
func begin_safe_zone() -> float:
	var b: Rect2 = player.play_bounds
	var margin := SAFE_ZONE_RADIUS + 10.0
	var c := Vector2(b.position.x + margin, (b.position.y + b.end.y) * 0.5)
	# Nie im oder direkt am Boss: die Zone muss mit Abstand neben seinem Körper liegen.
	var avoid := Rect2()
	if boss != null and is_instance_valid(boss):
		avoid = boss._stable_bounds()
		avoid.position += boss.position
		avoid = avoid.grow(SAFE_ZONE_RADIUS + 24.0)
	for attempt in range(40):
		var pick := Vector2(rng.randf_range(b.position.x + margin, minf(b.end.x - margin, 700.0)),
			rng.randf_range(b.position.y + margin, b.end.y - margin))
		if not avoid.has_point(pick):
			c = pick
			break
	var far := 0.0
	for corner in [b.position, Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), b.end]:
		far = maxf(far, (corner as Vector2).distance_to(c))
	var window := maxf(0.0, far - SAFE_ZONE_RADIUS * 0.5) / Player.BASE_SPEED + SAFE_ZONE_REACTION
	# Windstille: laufende Schwerkraftfelder klingen sofort ab.
	for h in fx.hazards:
		if String(h.kind) == "gravity_field":
			h.life = minf(float(h.life), 0.25)
	clear_enemy_bullets()
	safe_zone = {"kind": "safe_zone", "p": c, "r": SAFE_ZONE_RADIUS, "t": 0.0,
		"life": window, "max_life": window}
	fx.add_hazard(safe_zone)
	Audio.sfx("boss_warn", -6.0, 0.7)
	_notify(Loc.tx("Rette dich in die Schutzzone!"), minf(window, 2.5))
	return window

func _tick_safe_zone(_delta: float) -> void:
	if safe_zone.is_empty():
		return
	if boss == null or not is_instance_valid(boss) or boss.dead:
		safe_zone.life = 0.0
		safe_zone = {}
		return
	if float(safe_zone.life) > 0.0:
		return
	var c: Vector2 = safe_zone.p
	var inside := player.position.distance_to(c) <= float(safe_zone.r)
	safe_zone = {}
	if inside:
		Audio.sfx("shield_hit", -10.0, 1.4)
		return
	player.iframes = 0.0
	player.take_damage(SAFE_ZONE_DAMAGE, c)
	shake(9.0)

func begin_flood() -> void:
	if not flood.is_empty():
		return
	var top := float(App.PLAY_BOTTOM) - float(App.PLAY_BOTTOM - App.PLAY_TOP) * FLOOD_SHARE
	flood = {"kind": "flood", "p": Vector2.ZERO, "y": float(App.PLAY_BOTTOM), "target": top,
		"t": 0.0, "life": 1.0e9, "max_life": 1.0e9}
	fx.add_hazard(flood)
	shake(8.0)
	Audio.sfx("explosion_small", -6.0, 0.6)

## Oberkante des Flutwassers (ohne Flut die Unterkante des Spielfelds).
func flood_top() -> float:
	return float(flood.y) if not flood.is_empty() else float(App.PLAY_BOTTOM)

func _tick_flood(delta: float) -> void:
	if flood.is_empty():
		return
	var y := float(flood.y)
	if boss == null or not is_instance_valid(boss) or boss.dead:
		# Boss besiegt: das Wasser läuft wieder ab.
		flood.y = y + 140.0 * delta
		if float(flood.y) >= float(App.PLAY_BOTTOM):
			flood.life = 0.0
			flood = {}
		return
	var rise := (float(App.PLAY_BOTTOM) - float(flood.target)) / FLOOD_RISE_TIME
	flood.y = move_toward(y, float(flood.target), rise * delta)
	var reach := Player.HIT_RADIUS * (1.0 + player.evo_effect("hitbox"))
	if player.position.y + reach >= float(flood.y):
		var at := Vector2(player.position.x, float(flood.y))
		if player.take_damage(1, at):
			fx.water_splash(at, 1.0)

## Eigenständige Schwerkraft: Wind-Gegensteuerung darf diese Kraft nicht auf28%
## abschwächen. Mehrere Felder teilen sich die Obergrenze statt sich zu addieren.
func gravity_pull() -> Vector2:
	if fx == null or player == null or not safe_zone.is_empty():
		return Vector2.ZERO
	var strength := 0.0
	for h in fx.hazards:
		if String(h.kind) == "gravity_field" and float(h.get("life", 0.0)) > 0.0:
			strength = maxf(strength, clampf(float(h.life) / 0.6, 0.0, 1.0))
	return Vector2.DOWN * player._speed() * GRAVITY_STRENGTH * strength

func _update_pickups(delta: float) -> void:
	var keep: Array = []
	for p in pickups:
		if not is_instance_valid(p):
			continue
		if p.collected:
			continue
		if p.position.distance_to(player.position) < 22.0:
			p.collected = true
			match p.kind:
				"heart":
					player.heal(1)
					Audio.sfx("pickup_heart", -5.0, 1.0)
				_:
					# Sammelinstinkt (+1) gilt nur für Blüten, nicht für jeden Beutetropfen.
					player.add_nectar(p.value, true, p.kind == "blossom")
					Audio.sfx_var("pickup_nectar", -8.0)
			p.queue_free()
			continue
		keep.append(p)
	pickups = keep

func magnet_radius() -> float:
	if player == null:
		return 70.0
	return 70.0 * (1.0 + player.evo_effect("magnet") + player.shop_mod("magnet"))

func player_position() -> Vector2:
	return player.position if player != null else Vector2(160, 270)

# ------------------------------------------------------------------ Geschosse
func spawn_player_bullet(pos: Vector2, vel: Vector2, dmg: float, art: String, opts: Dictionary = {}) -> Dictionary:
	var bullet := bullets.spawn_player(pos, vel, dmg, art, opts)
	if not bullet.is_empty():
		stats.shots += 1
	return bullet

func spawn_enemy_bullet(pos: Vector2, vel: Vector2, dmg: int, art: String, opts: Dictionary = {}) -> void:
	# Die laufende Welt ist maßgeblich, auch in Training/Rush ohne aktive Kampagne.
	var difficulty_id := String(difficulty.get("name", "")).trim_prefix("diff.")
	if not Data.DIFFICULTY.has(difficulty_id):
		difficulty_id = String(Save.campaign.get("difficulty", "normal")) if Save.active_campaign else String(Save.g("game.difficulty", "normal"))
	if difficulty_id != _enemy_bullet_difficulty:
		_enemy_bullet_density = 0
		_enemy_bullet_difficulty = difficulty_id
	# Geschossdichte je Schwierigkeit (Entspannt 3 von 5, Normal 4 von 5, Experte alle),
	# als feste Folge ohne Zufall.
	var diff: Dictionary = Data.DIFFICULTY[difficulty_id]
	var keep := int(round(float(diff.get("bullet_density", 1.0)) * 5.0))
	if keep < 5:
		_enemy_bullet_density += keep
		if _enemy_bullet_density < 5:
			return
		_enemy_bullet_density -= 5
	# Gegnerkugeln werden je Level schneller (Bosseskalation und Levels 2-10) und je
	# Schwierigkeit (gilt für Gegner, Bosse und Gefahren gleichermaßen).
	var b: Dictionary = bullets.spawn_enemy(pos, vel * eb_speed * float(diff.get("bullet_speed", 1.0)), dmg, art, opts)
	if b.is_empty():
		return
	_apply_pollen_defenses(b)

func clear_enemy_bullets() -> void:
	bullets.enemy_bullets.clear()

## Trefferschaden inklusive Werkstattwerten (Volltreffer, Doppelschlag, Bosse).
## Anflugziele für die Zielsuche: Gegner und Boss (höchstens 24 Punkte).
func _homing_targets() -> Array:
	var out: Array = []
	for e in enemies:
		# Abgetauchte Springfische (Sprite unsichtbar) sind kein Ziel.
		if is_instance_valid(e) and not e.dead and e.sprite.visible:
			out.append(e.position)
			if out.size() >= 24:
				return out
	if boss != null and is_instance_valid(boss) and not boss.dead:
		out.append(boss.position)
	return out

func _shot_damage(raw: float, is_boss: bool = false) -> float:
	var dmg := raw
	var crit := clampf(player.shop_mod("crit") + player.evo_effect("crit_chance"), 0.0, 1.0)
	_last_crit = crit > 0.0 and randf() < crit
	if _last_crit:
		dmg *= 2.0
	if is_boss:
		dmg *= 1.0 + player.shop_mod("boss_dmg")
	return dmg

func _update_collisions() -> void:
	var ppos := player.position
	# Spielerkugeln gegen Gegner und Boss; echte vergangene Flugsegmente.
	for b in bullets.player_bullets:
		if float(b.life) <= 0.0:
			continue
		for e in enemies.duplicate():
			if not is_instance_valid(e) or e.dead or b.hit.has(e.get_instance_id()):
				continue
			if _segment_hit(b, e.position, e.radius + float(b.r) * 0.6):
				var impact := Geometry2D.get_closest_point_to_segment(e.position, b.get("prev_p", b.p), b.p)
				_projectile_impact(b, e, impact)
				break
		if float(b.life) > 0.0 and boss != null and is_instance_valid(boss) and not boss.dead and not b.hit.has(boss.get_instance_id()):
			var contact := boss.trace_hit(b.get("prev_p", b.p), b.p, float(b.r) * 0.6)
			if not contact.is_empty():
				_projectile_impact(b, boss, contact.p, int(contact.part))
	# Gegnerkugeln gegen Spieler
	var pr := 4.6 * (1.0 + player.evo_effect("hitbox"))
	var graze_points := int(player.shop_mod("graze"))
	for b in bullets.enemy_bullets:
		if float(b.life) <= 0.0:
			continue
		if _segment_hit(b, ppos, pr + float(b.r) * 0.55):
			if player.take_damage(int(b.dmg), b.p):
				fx.hit_spark(b.p, Color(1, 0.5, 0.5))
				b.life = 0.0
			else:
				b.life = 0.0
		elif graze_points > 0 and not bool(b.get("grazed", false)):
			# nah vorbei, aber nicht getroffen
			if (b.p as Vector2).distance_to(ppos) < 26.0 + float(b.r):
				b["grazed"] = true
				player.add_points(graze_points)
				fx.add_text(b.p, "+%d" % graze_points, Color(0.75, 0.95, 1.0), 11)
	# Gegnerkörper gegen Spieler
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.position.distance_to(ppos) < e.radius + pr:
			if player.take_damage(1, e.position):
				if player.evo_has("chitin_thorns"):
					e.take_damage(24.0 * player.fusion_factor("chitin_thorns", 1.6))
					e.position += (e.position - ppos).normalized() * 24.0
	# Bosskontakt prüft denselben sichtbaren Körper samt lebenden Modulen.
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var contact := boss.trace_hit(ppos, ppos, pr)
		if not contact.is_empty() and player.take_damage(1, contact.p):
			fx.hit_spark(player.position, Color(1, 0.5, 0.5))
			if player.evo_has("chitin_thorns"):
				boss.take_damage(24.0 * player.fusion_factor("chitin_thorns", 1.6), contact.p, int(contact.part))

## Einschlagfarben beschreiben das getroffene Material, nicht ein schwarzes Loch.
func _impact_color(target: Node2D) -> Color:
	var sprite_id := String(target.def.get("sprite", ""))
	if sprite_id in ["glassdrone", "mirrororb"]:
		return Color(0.55, 0.88, 1.0)
	if sprite_id in ["piston", "generator", "boss_pollinator", "boss_harvester"]:
		return Color(0.72, 0.82, 0.92)
	if sprite_id in ["spore", "mushroom", "vine", "boss_fungus", "shard"]:
		return Color(0.60, 0.83, 0.48)
	return Color(0.95, 0.68, 0.35)

## Ein Crit-Wurf pro Einschlag. Erworbene Effekte addieren sich unabhängig;
## das gemeinsame hit-Set verhindert anschließend erneute direkte Berührungen.
func _projectile_impact(b: Dictionary, target: Node2D, impact: Vector2, part: int = -1) -> void:
	var id := target.get_instance_id()
	b.hit[id] = true
	_last_crit = false
	var base := float(b.dmg) if bool(b.get("crit_rolled", false)) else _shot_damage(float(b.dmg))
	if _last_crit and masters != null:
		masters.mark(target)
	var damage := base * _target_damage_mult(target)
	if target == boss:
		boss.take_damage(damage, impact, part)
	else:
		target.take_damage(damage, impact)
	fx.hit_spark(impact, _impact_color(target))
	Audio.sfx("hit", -26.0, 1.0)
	# Jeder Effekt erhält denselben Stand VOR den anderen Effekten.
	var excluded: Dictionary = b.hit.duplicate()
	_proc_splinters(b, impact, base)
	if player.evo_has("swarm_mark") and int(b.get("proc_depth", 0)) == 0 and not target.dead:
		_mark_hit(target)
	if int(b.chain) > 0:
		_chain_from(b, impact, int(b.chain), base, excluded)
	if int(b.get("lchain", 0)) > 0:
		for hit_id in _lightning_chain(impact, base, int(b.lchain), excluded.keys()):
			b.hit[hit_id] = true
	if float(b.splash) > 0.0:
		var splash_hits := excluded.duplicate()
		_splash_damage(impact, float(b.splash), base * 0.5, id, splash_hits)
		b.hit.merge(splash_hits)
	if int(b.pierce) > 0:
		b.pierce = int(b.pierce) - 1
	else:
		b.life = 0.0

func _target_damage_mult(target: Node2D) -> float:
	var mark: float = masters.mark_mult(target) if masters != null else 1.0
	return (1.0 + player.shop_mod("boss_dmg") if target == boss or target == miniboss else 1.0) * mark

func _segment_hit(b: Dictionary, center: Vector2, radius: float) -> bool:
	var p: Vector2 = b.p
	var previous: Vector2 = b.get("prev_p", p)
	var closest := Geometry2D.get_closest_point_to_segment(center, previous, p)
	return closest.distance_to(center) <= radius

func _splash_damage(pos: Vector2, radius: float, dmg: float, exclude: int, hit_ids: Dictionary = {}) -> void:
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.get_instance_id() == exclude or hit_ids.has(e.get_instance_id()):
			continue
		if e.position.distance_to(pos) <= radius:
			e.take_damage(dmg * _target_damage_mult(e))
			hit_ids[e.get_instance_id()] = true
	if boss != null and is_instance_valid(boss) and not boss.dead and boss.get_instance_id() != exclude and not hit_ids.has(boss.get_instance_id()):
		var contact := boss.trace_hit(pos, pos, radius)
		if not contact.is_empty():
			boss.take_damage(dmg * (1.0 + player.shop_mod("boss_dmg")), contact.p, int(contact.part))
			hit_ids[boss.get_instance_id()] = true
	fx.add("ring", pos, {"life": 0.3, "scale": radius / 32.0, "tint": Color(1, 0.8, 1, 0.7)})

## Kettenblitz der Blitzwaffe: erster Sprung 66 %, zweiter Sprung 33 % Schaden.
func _lightning_chain(from_pos: Vector2, dmg: float, jumps: int, hit_ids: Array = [],
		radius: float = 160.0) -> Array:
	var factor := 0.66
	var cur := from_pos
	var used := hit_ids.duplicate()
	for i in range(jumps):
		var best: Node2D = null
		var best_d := radius
		for e in _chain_targets():
			if used.has(e.get_instance_id()):
				continue
			var d: float = e.position.distance_to(from_pos if i == 0 else cur)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			return used
		best.take_damage(dmg * factor * _target_damage_mult(best), cur)
		fx.add_arc(cur, best.position, Color(0.72, 0.95, 1.0), 0.18)
		fx.add("spark", best.position, {"life": 0.2, "scale": 1.3, "tint": Color(0.75, 0.95, 1.0)})
		Audio.sfx("hit", -27.0, 1.35 + 0.15 * float(i))
		used.append(best.get_instance_id())
		cur = best.position
		factor *= 0.5
	return used

func _chain_targets() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	if boss != null and is_instance_valid(boss) and not boss.dead:
		out.append(boss)
	return out

func _chain_from(b: Dictionary, from_pos: Vector2, count: int, damage: float = -1.0, excluded: Dictionary = {}) -> void:
	var hits := 0
	var base := float(b.dmg) if damage < 0.0 else damage
	var used: Dictionary = b.hit if excluded.is_empty() else excluded
	for e in _chain_targets():
		if hits >= count:
			break
		if not is_instance_valid(e) or e.dead:
			continue
		if used.has(e.get_instance_id()):
			continue
		if e.position.distance_to(from_pos) < 130.0:
			e.take_damage(base * 0.55 * _target_damage_mult(e))
			b.hit[e.get_instance_id()] = true
			fx.add("spark", e.position, {"life": 0.2, "scale": 1.2, "tint": Color(0.7, 0.9, 1.0)})
			hits += 1

func _proc_splinters(b: Dictionary, pos: Vector2, dmg: float) -> void:
	# Splitterlanze: Splitter zerbrechen bei ihrem Treffer noch einmal (eine Generation).
	if int(b.get("proc_depth", 0)) == 1 and bool(b.get("lance", false)) and masters != null and masters.has("m_splinter_lance"):
		_spawn_splinter(pos, dmg, 2, b.hit, 2)
		return
	if int(b.get("proc_depth", 0)) > 0:
		return
	if player.evo_has("splinter"):
		_spawn_splinter(pos, dmg, mini(4, 2 * int(player.evo_effect("splinter"))), b.hit)
	# Werkstatt und Evolution ergänzen sich, aber höchstens sechs Splitter/Treffer.
	if player.shop_mod("splinter_chance") > 0.0 and randf() < minf(1.0, player.shop_mod("splinter_chance")):
		_spawn_splinter(pos, dmg * 0.6, 2, b.hit)

## Splitter fliegen schräg nach oben und unten aus dem Ziel (zwei: ±60°, vier: zusätzlich
## ±30°), bernsteinfarben, damit man sie von den eigenen Schüssen unterscheidet.
const SPLINTER_ANGLES := [-1.05, 1.05, -0.5, 0.5, -1.45, 1.45]
const SPLINTER_TINT := Color(2.2, 1.25, 0.45)

func _spawn_splinter(pos: Vector2, dmg: float, amount: int = 2, hit_ids: Dictionary = {}, depth: int = 1) -> void:
	var lance: bool = masters != null and masters.has("m_splinter_lance")
	fx.add("spark", pos, {"life": 0.18, "scale": 1.1, "tint": SPLINTER_TINT})
	for i in range(mini(amount, SPLINTER_ANGLES.size())):
		var a := float(SPLINTER_ANGLES[i])
		var child := bullets.spawn_player(pos, Vector2.RIGHT.rotated(a) * 420.0, dmg * 0.35, "bullet_fan",
			{"r": 4.0, "life": 0.8 if lance else 0.55, "pierce": 2 if lance else 1, "proc_depth": depth,
				"tint": SPLINTER_TINT, "scale": 0.85, "rot": true})
		if not child.is_empty():
			child["proc_depth"] = depth
			child["lance"] = lance and depth == 1
			child["crit_rolled"] = true
			child.hit = hit_ids.duplicate()

var mark_table: Dictionary = {}

func _mark_hit(e: Node2D) -> void:
	var id := e.get_instance_id()
	mark_table[id] = int(mark_table.get(id, 0)) + 1
	if int(mark_table[id]) >= int(maxf(1.0, player.evo_effect("swarm_mark"))):
		mark_table.erase(id)
		_swarm_strike(Vector2(0, 0))

func _swarm_strike(_unused: Vector2 = Vector2.ZERO) -> void:
	var targets := enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	if targets.is_empty() and boss != null and is_instance_valid(boss) and not boss.dead:
		targets = [boss]
	if targets.is_empty():
		return
	for i in range(6):
		var t: Node2D = targets[i % targets.size()]
		var from: Vector2 = player.position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var dir: Vector2 = (t.position - from).normalized()
		var child := bullets.spawn_player(from, dir * 620.0, 8.0 * player.dmg_mult(), "bullet_lightning",
			{"r": 4.0, "homing": 3.0, "life": 1.2, "proc_depth": 1, "tint": Color(0.8, 0.7, 1.0)})
		if not child.is_empty():
			child["proc_depth"] = 1
	Audio.sfx("combo_ready", -8.0, 1.0)

# ------------------------------------------------------------------ Pollen
func spawn_pollen(pos: Vector2, strength: float, burst: bool = false) -> void:
	var radius := 34.0 * strength
	var drift := Vector2(-40, 0)
	if player.evo_has("wind_rider"):
		drift += player.vel * 0.65
	fx.add_hazard({"kind": "pollen_cloud", "p": pos, "radius": radius, "t": 0.0,
		"life": 2.4 if not burst else 1.6, "max_life": 2.4 if not burst else 1.6,
		"vel": drift, "dmg": 1, "hit_cd": 0.0, "friendly": true, "burst": burst,
		"color": Color(0.7, 1.0, 0.6, 0.26)})
	# Explosionswolken stapeln sich bei vielen Abschüssen: deutlich durchsichtiger,
	# damit die Biene darin sichtbar bleibt.
	fx.add("pollen", pos, {"life": 0.9, "scale": strength, "tint": Color(0.9, 1.0, 0.8, 0.22 if burst else 0.32)})
	if burst and masters != null:
		masters.schedule_bloom(pos, radius)
	if burst:
		for e in enemies.duplicate():
			if is_instance_valid(e) and not e.dead and e.position.distance_to(pos) < radius + 10.0:
				e.take_damage(9.0 * player.evo_level("pollen_burst"))

func _update_pollens(delta: float) -> void:
	var damage := 3.0 * player.evo_level("pollen_trail")
	if damage <= 0.0:
		return
	# Eine Wolke, ein gemeinsamer Takt, alle überlappenden Ziele. Duplikate
	# schützen die Iteration vor endlichen Pollenburst-Abschusskaskaden.
	for h in fx.hazards.duplicate():
		if String(h.kind) != "pollen_cloud" or not bool(h.get("friendly", false)):
			continue
		var timer := float(h.get("dmg_t", 0.0)) - delta
		while timer <= 0.000001:
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.position.distance_to(h.p) <= float(h.radius) + e.radius:
					e.take_damage(damage * _target_damage_mult(e), h.p)
			if boss != null and is_instance_valid(boss) and not boss.dead:
				var contact := boss.trace_hit(h.p, h.p, float(h.radius))
				if not contact.is_empty():
					boss.take_damage(damage * _target_damage_mult(boss), contact.p, int(contact.part))
			timer += 0.4
		h["dmg_t"] = timer

# ------------------------------------------------------------------ Sonderaktionen
func player_pulse(pos: Vector2) -> void:
	var radius := 150.0 * (1.0 + player.shop_mod("bomb_radius"))
	fx.add("ring", pos, {"life": 0.5, "scale": 5.5 * (radius / 150.0),
		"tint": Color(1, 0.9, 0.5, 0.8), "important": true})
	bullets.clear_enemy_area(pos, radius)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.position.distance_to(pos) < radius:
			e.take_damage(26.0 * player.dmg_mult())
	if boss != null and is_instance_valid(boss) and boss.position.distance_to(pos) < radius:
		boss.take_damage(40.0 * player.dmg_mult())
	shake(5.0)
	Audio.sfx("bomb", -6.0, 1.1)

func shield_break_pulse(pos: Vector2) -> void:
	fx.add("ring", pos, {"life": 0.4, "scale": 3.2, "tint": Color(0.7, 0.95, 1.0, 0.8), "important": true})
	bullets.clear_enemy_area(pos, 110.0)
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.position.distance_to(pos) < 100.0:
			e.take_damage(18.0)

## Goldrausch: goldener Tropfen mit mehreren Blütenstaub, der von selbst zur Biene fliegt.
func spawn_gold_drop(pos: Vector2, value: int) -> void:
	var p := Pickup.new()
	add_child(p)
	p.setup("nectar", pos, value)
	p.magnet = true
	p.scale = Vector2(1.5, 1.5)
	p.modulate = Color(1.4, 1.15, 0.45)
	pickups.append(p)
	fx.add_text(pos + Vector2(0, -12), "+%d" % value, Color(1.0, 0.85, 0.3), 12)

func drone_intercept(pos: Vector2) -> bool:
	for b in bullets.enemy_bullets:
		if b.p.distance_to(pos) < 34.0:
			b.life = 0.0
			fx.add("spark", b.p, {"life": 0.2, "scale": 1.2, "tint": Color(0.7, 0.95, 1.0)})
			Audio.sfx("shield_hit", -10.0, 1.3)
			return true
	return false

func on_player_hit(_amount: int) -> void:
	stats.hits += 1
	shake(8.0)
	background.flash(Color(1, 0.2, 0.2), 0.25, 0.4)
	if player.hp <= 1:
		Audio.sfx("low_hp_warn", -6.0, 1.0)

func spawn_explosion(pos: Vector2, scale: float) -> void:
	fx.explode(pos, scale)
	shake(4.0 * scale)
	Audio.sfx("explosion_big", -4.0, 0.9)

func spawn_boss_minion(id: String, pos: Vector2) -> void:
	_on_spawn_enemy(id, pos, {"hp_mult": 1.0})

## Kurzanleitung mit der aktuellen Belegung (Tastatur und Controller).
## Einstellungen, die im laufenden Level greifen (nach Rückkehr aus dem Pausemenü).
func apply_settings() -> void:
	fx.apply_settings()
	bullets.contrast_mode = bool(Save.g("access.contrast_hazards", true))

func control_hints() -> Array[String]:
	var keys := ""
	for a in ["move_up", "move_left", "move_down", "move_right"]:
		for b in Bindings.bindings_for(a):
			if String(b.get("t", "")) == "key":
				keys += Bindings.describe_binding(b)
				break
	return [
		Loc.tx("Fliegen: %s / Stick  ·  Schießen: %s") % [keys, Bindings.describe_action("fire")],
		Loc.tx("Waffenleiste: %s und %s  ·  Kaufen: %s") % [Bindings.describe_action("upgrade_prev"),
			Bindings.describe_action("upgrade_next"), Bindings.describe_action("upgrade_buy")],
	]

func _notify(text: String, t: float) -> void:
	banner_queue.append({"text": text, "t": t})
	if app != null and app.hud != null and app.hud.has_method("show_banner"):
		app.hud.show_banner(text, t)

# ------------------------------------------------------------------ Checkpoints
func _on_checkpoint(index: int) -> void:
	checkpoint = index
	if mode == "campaign" and app != null:
		app.on_checkpoint(index)
	_take_checkpoint_snapshot()

func _take_checkpoint_snapshot() -> void:
	if player.evo_has("chitin_regen"):
		player.heal(int(player.evo_effect("heal_checkpoint")))
	checkpoint_snapshot = {
		"hp": player.hp, "nectar": player.nectar, "points": player.points,
		"upgrades": player.upgrades.duplicate(true), "weapon": player.weapon,
		"speed_level": player.speed_level, "evolutions": player.evolutions.duplicate(true),
		"checkpoint": checkpoint,
	}

func _on_player_died() -> void:
	frozen_by_death = true
	dead_timer = 2.0
	fx.explode(player.position, 2.0, Color(1, 0.8, 0.4))
	shake(12.0)
	if app != null:
		app.on_player_death()
	Save.profile.totals.deaths = int(Save.profile.get("totals", {}).get("deaths", 0)) + 1
	Save.save_profile()

## Nach „Weiter“: taktische Upgrades (unterer Rand) zurücksetzen, Werkstatt und
## Evolutionen bleiben, dann am Kontrollpunkt weitermachen.
func continue_after_death() -> void:
	_reset_tactical_upgrades()
	_restore_checkpoint()

## Setzt Waffenstufen, Nektar und Zusatzwaffen auf den Stand eines neuen Levels
## zurück. Werkstatt-Stufen (shop_levels) und Evolutionen bleiben unberührt.
func _reset_tactical_upgrades() -> void:
	var fresh := {}
	for u in Data.UPGRADES:
		fresh[u.id] = 0 if u.id != "base" else 1
	player.upgrades = fresh
	player.weapon = "base"
	player.speed_level = 0
	player.nectar = 0
	player.attack_timer_reset()
	checkpoint_snapshot["upgrades"] = fresh.duplicate(true)
	checkpoint_snapshot["weapon"] = "base"
	checkpoint_snapshot["speed_level"] = 0
	checkpoint_snapshot["nectar"] = 0
	Save.campaign.upgrades = fresh.duplicate(true)
	Save.campaign.weapon = "base"
	Save.campaign.speed_level = 0
	Save.campaign.nectar = 0
	Save.save_campaign()
	_notify("Taktische Upgrades zurückgesetzt", 1.8)

func _restore_checkpoint() -> void:
	bullets.clear()
	fx.hazards.clear()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	if miniboss != null and is_instance_valid(miniboss):
		miniboss.queue_free()
	miniboss = null
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	pickups.clear()
	mark_table.clear()
	last_kill_times.clear()
	player.reset_for_checkpoint({
		"hp": checkpoint_snapshot.get("hp", player.max_hp),
		"nectar": checkpoint_snapshot.get("nectar", 0),
		"upgrades": checkpoint_snapshot.get("upgrades", player.upgrades),
		"weapon": checkpoint_snapshot.get("weapon", "base"),
		"speed_level": checkpoint_snapshot.get("speed_level", 0),
	})
	stats.score = int(checkpoint_snapshot.get("points", 0))
	stats.kills = 0
	stats.hits = 0
	stats.shots = 0
	frozen_by_death = false
	_stage_generation += 1
	director._restart_from_checkpoint(checkpoint)
	resume_delay = 1.0
	Audio.stop_music(0.2)
	Audio.play_music(String(level_data.get("music", "level1")), 0.4, _level_music_start())
	_notify(Loc.t("cp.reached"), 1.6)

# ------------------------------------------------------------------ Boss
func _on_miniboss() -> void:
	var cfg: Dictionary = director.miniboss_config()
	if cfg.is_empty():
		return
	var e := Enemy.new()
	e.miniboss = true
	e.boss_hp_scale = float(cfg.get("hp_mult", 6.0))
	e.setup(String(cfg.get("enemy", "ladybug_turret")), Vector2(880, 270),
		{"hp_mult": float(cfg.get("hp_mult", 6.0)), "speed_mult": 0.8,
		"fire_mult": float(Director.pressure_for_level(level_index).fire_mult), "difficulty": difficulty})
	add_child(e)
	enemies.append(e)
	e.killed.connect(_on_enemy_killed)
	miniboss = e
	_notify(String(cfg.get("title", "Miniboss")), 2.5)
	# Miniboss bleibt bei der Levelmusik - Bossmusik laeuft nur beim Boss.
	Audio.sfx("boss_warn", -8.0, 1.15)
	shake(4.0)

func _on_boss_triggered() -> void:
	if mode == "rush":
		_spawn_rush_boss()
		return
	clear_enemy_bullets()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	# Ankündigung: Rütteln, Aufblitzen, Schriftzug, dann erst der Boss. Den Klang
	# übernimmt bei durchkomponierter Levelmusik deren Auftakt (kein Warnton darüber).
	var timed_music := Audio.is_timed_music(String(level_data.get("music", "level1")))
	if not timed_music:
		Audio.sfx("boss_warn", -2.0, 0.92)
	shake(16.0)
	background.flash(Color(1, 1, 1), 0.5, 0.55)
	if app != null and app.hud != null and app.hud.has_method("boss_announce"):
		app.hud.boss_announce(1.3, not timed_music)
	var generation := _stage_generation
	await get_tree().create_timer(1.25, false).timeout
	if level_over or not is_inside_tree() or generation != _stage_generation:
		return
	# Während der Ankündigung können Wellen nachgerückt sein – Bühne freiräumen.
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	clear_enemy_bullets()
	_spawn_boss()

func _spawn_boss() -> void:
	boss = Boss.new()
	boss.setup(String(level_data.get("boss", "rose_beetle")),
		float(difficulty.get("boss_hp", 1.0)) * _boss_hp_scale(), level_index)
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	boss.phase_changed.connect(_on_boss_phase)
	boss_intro_t = 2.5
	# Nahtlos: Der Leveltrack endet genau jetzt mit seinem Auftakt, die Bossmusik
	# setzt auf dem nächsten Schlag ein – harter Schnitt statt Überblendung.
	var seamless := Audio.is_timed_music(String(level_data.get("music", "level1"))) and mode != "rush"
	Audio.play_music(_boss_music(String(level_data.get("boss", ""))), 0.03 if seamless else 0.8)
	_notify(String(boss.name_text), 3.0)
	background.flash(Color(1, 0.4, 0.4), 0.18, 0.6)

## Startposition der Levelmusik: Level- oder Checkpointbeginn, bei
## geloopten Altlasten immer der Anfang.
func _level_music_start() -> float:
	if mode == "rush" or not Audio.is_timed_music(String(level_data.get("music", "level1"))):
		return 0.0
	return director.music_pos()

## Jeder Boss hat seinen eigenen Track: boss1 ... boss10.
func _boss_music(boss_id: String) -> String:
	if boss_id != "":
		for lv in Data.levels:
			if String(lv.get("boss", "")) == boss_id:
				return "boss%d" % int(lv.get("id", 1))
	return "boss%d" % clampi(level_index, 1, 10)

func _boss_hp_scale(for_level: int = 0) -> float:
	var dps := maxf(REF_DPS, player.attack_dps())
	var per := maxf(REF_SHOT, player.shot_power())
	var power := pow(dps / REF_DPS, HP_POWER_EXP) * pow(per / REF_SHOT, HP_SHOT_EXP)
	# Eigenständiger Leveldruck, aber weiter sublineares Waffenwachstum und keine
	# Steuer pro Evolution: nichtoffensive Talente erhöhen keine Lebenspunkte.
	var index := level_index if for_level <= 0 else for_level
	return power * float(Director.pressure_for_level(index).boss_hp)

func _on_boss_phase(index: int) -> void:
	player.on_boss_phase()
	# Der Phasenwechsel friert alles ein: eine laufende Schutzzone verfällt ohne Schaden.
	if not safe_zone.is_empty():
		safe_zone.life = 0.0
		safe_zone = {}
	if boss != null and is_instance_valid(boss) and String(boss.id) == "mutant_skater" and index >= 3:
		begin_flood()
	Bindings.rumble(0.4, 0.9, 0.5)
	# Laufende Geschosse zerplatzen sichtbar, statt einfach zu verschwinden.
	var sparks := 0
	for b in bullets.enemy_bullets:
		if sparks >= 48:
			break
		fx.hit_spark(b.p, Color(1.0, 0.72, 0.4))
		sparks += 1
	clear_enemy_bullets()
	Audio.sfx("phase_roar", -1.0, 1.0)
	Audio.sfx("phase_change", -5.0, 0.9)
	shake(18.0)
	if background != null:
		background.flash(Color(1.0, 0.42, 0.25), 0.45, 0.8)
	if boss != null and is_instance_valid(boss):
		fx.explode(boss.position, 3.0, Color(1.0, 0.62, 0.35))
		for k in range(2):
			fx.add("ring", boss.position, {"life": 0.75 + 0.25 * k, "scale": 1.0 + k, "grow": 7.0 + 3.0 * k,
				"tint": Color(1.0, 0.7 - 0.2 * k, 0.4), "important": true})
	phase_stagger = PHASE_STAGGER
	var hud = app.hud if app != null and "hud" in app else null
	if hud != null and hud.has_method("phase_announce") and boss != null:
		hud.phase_announce(index + 1, boss.phase_line(index))
	else:
		_notify("Phase %d" % (index + 1), 1.6)

func _on_boss_defeated() -> void:
	stats.bosses += 1
	var gain := 3000 + level_index * 500
	var reward := int(float(gain) * float(difficulty.score_mult) * (1.0 + player.shop_mod("combo")))
	stats.score += reward
	player.add_points(reward)
	clear_enemy_bullets()
	if mode == "rush":
		_rush_after_boss()
		return
	_finish_level()

func _finish_level() -> void:
	if level_over:
		return
	level_over = true
	Audio.play_music("level_clear")
	var accuracy := 0.0
	if stats.shots > 0:
		accuracy = clampf(1.0 - float(stats.hits) * 3.0 / float(maxi(1, stats.shots)) * 0.02, 0.0, 1.0)
	var rank := _compute_rank()
	var out := {
		"level": level_index,
		"score": stats.score,
		"kills": stats.kills,
		"hits": stats.hits,
		"time": stats.time,
		"accuracy": accuracy,
		"rank": rank["letter"],
		"rank_text": rank["text"],
		"difficulty": String(Save.campaign.get("difficulty", "normal")),
		"seed": int(Save.campaign.get("seed", 0)),
		"hp_left": player.hp,
	}
	Save.campaign.points = player.points
	Save.campaign.nectar = player.nectar
	Save.campaign.hp = player.hp
	Save.campaign.upgrades = player.upgrades.duplicate(true)
	Save.campaign.shop = player.shop_levels.duplicate(true)
	Save.campaign.weapon = player.weapon
	Save.campaign.speed_level = player.speed_level
	if mode == "campaign":
		Save.save_campaign()
	if app != null:
		app.on_level_complete(out)

func _compute_rank() -> Dictionary:
	var score := 0
	score += 40 if stats.hits == 0 else (25 if stats.hits <= 2 else (12 if stats.hits <= 5 else 0))
	var acc := 0.0
	if stats.shots > 0:
		acc = 1.0 - float(stats.hits) * 40.0 / float(stats.shots)
	score += int(clampf(acc, 0.0, 1.0) * 30.0)
	score += mini(30, stats.kills / 8)
	if score >= 85:
		return {"letter": "S", "text": "Perfekter Flug"}
	if score >= 70:
		return {"letter": "A", "text": "Meisterhaft"}
	if score >= 55:
		return {"letter": "B", "text": "Solide"}
	if score >= 40:
		return {"letter": "C", "text": "Bestanden"}
	return {"letter": "D", "text": "Knapp"}

# ------------------------------------------------------------------ Boss-Rush
func _start_boss_rush() -> void:
	# Nur die im laufenden Run besiegten Bosse (App.start_boss_rush legt sie fest).
	boss_sequence = (Save.campaign.get("rush_bosses", []) as Array).duplicate()
	if boss_sequence.is_empty():
		boss_sequence = ["rose_beetle", "giant_larva", "pike_beast", "fungus_mind", "mantis_pair",
			"mech_pollinator", "mutant_skater", "harvester", "swarm_queen", "core_organism"]
	rush_index = 0
	director.boss_started = true
	_spawn_rush_boss()

func _spawn_rush_boss() -> void:
	if rush_index >= boss_sequence.size():
		_finish_level()
		return
	bullets.clear()
	boss = Boss.new()
	boss.setup(String(boss_sequence[rush_index]), 0.85 * _boss_hp_scale(rush_index + 1), rush_index + 6)
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	boss.phase_changed.connect(_on_boss_phase)
	_notify("%d/%d  %s" % [rush_index + 1, boss_sequence.size(), boss.name_text], 2.6)
	Audio.play_music(_boss_music(String(boss_sequence[rush_index])))
	Audio.sfx("boss_warn", -4.0, 1.0)

func _rush_after_boss() -> void:
	rush_index += 1
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	if rush_index >= boss_sequence.size():
		_finish_level()
		return
	rush_between = true
	rush_supply_t = 3.0
	player.heal(2)
	player.nectar += 30
	_notify(Loc.t("game.rush_next", [3]), 2.5)

func _process(delta: float) -> void:
	if rush_between:
		rush_supply_t -= delta
		if rush_supply_t <= 0.0:
			rush_between = false
			_spawn_rush_boss()

func _unhandled_input(event: InputEvent) -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		pass
