class_name Player
extends Node2D
## Die Biene: Bewegung, Waffen, Schild, Begleiter, Evolutionseffekte.

signal died
signal hp_changed(hp: int, max_hp: int)
signal nectar_changed(value: int)
signal upgraded(id: String)
signal notice(text: String)

const BASE_SPEED := 252.0
const BASE_INTERVAL := 0.118
## Grenzen gegen Kugelflut: so viele Zusatzschüsse dürfen höchstens dazukommen.
const MAX_RATE_BONUS := 0.30     # höchstens 30 % schnellere Schussfolge
const MIN_INTERVAL := 0.095      # nie schneller als etwa zehn Salven je Sekunde
const MAX_BACK := 2
const MAX_SIDE := 1
const MAX_LANES := 1
const HIT_RADIUS := 4.6
const ShieldRingsVisual := preload("res://scripts/game/shield_rings.gd")
const MAX_COMPANIONS := 5
var play_bounds := Rect2(14, 16, 924, 438)

func _refresh_bounds() -> void:
	# Mindestens die vereinbarten +10; für die 32px hohe Biene 18px,
	# damit auch die Flügel weder hinter Header noch Bodenleiste geraten.
	var inset := maxf(10.0, float(Art.info("bee").get("h", 32)) * 0.5 + 2.0)
	var top := App.PLAY_TOP + inset
	play_bounds = Rect2(14, top, 924, App.PLAY_BOTTOM - top - inset)

var hp: int = 3
var max_hp: int = 3
var nectar: int = 0
var points: int = 0
var weapon: String = "base"
var upgrades: Dictionary = {}
var shop_levels: Dictionary = {}   # Werkstatt: id -> gekaufte Stufe
var shop_mods: Dictionary = {}     # daraus berechnete Werte
var speed_level: int = 0
var evolutions: Array = []
var difficulty: Dictionary = {}

var vel: Vector2 = Vector2.ZERO
var iframes: float = 0.0
var invuln_visual: float = 0.0
var shield_hits: int = 0
var shield_regen_t: float = 0.0
# Bruchteile bleiben über einzelne Treffer/Pickups und Präzisionswechsel erhalten.
var _guard_damage_carry: float = 0.0
var _nectar_carry: float = 0.0
var fire_cd: float = 0.0
var bomb_cd: float = 0.0
var companion_cd: float = 0.0
var companion_phase: float = 0.0
var shot_counter: int = 0
## Messwerte der zuletzt abgefeuerten Salve – Grundlage für die Gegnerhärte.
### Summe des Schadens aller Kugeln einer Salve.
var last_volley_damage: float = 0.0
### Anzahl der Kugeln in dieser Salve.
var last_volley_shots: int = 0
var _volley_acc: float = 0.0
var _has_fired_volley := false
var _volley_shots: int = 0
var _orbit_phases: Array[float] = []
var hold_time: float = 0.0
var pulse_cd: float = 0.0
var calm_bonus: float = 0.0
var tuning_t: float = 0.0
var convert_t: float = 20.0
var drone_cd: float = 0.0
var pollen_cd: float = 0.0
var alive := true
var autofire := false
var fire_held := false
var moving_dir := 1.0
var dead_t := 0.0
var precision := false
var shield_max := 0

var sprite: AnimatedSprite2D
var companions: Array[AnimatedSprite2D] = []
var aura: Node2D
var engine_fx: CPUParticles2D
var last_hit_from := Vector2.RIGHT

func setup(build: Dictionary) -> void:
	_refresh_bounds()
	difficulty = Data.DIFFICULTY.get(String(build.get("difficulty", "normal")), Data.DIFFICULTY["normal"])
	upgrades = (build.get("upgrades", {}) as Dictionary).duplicate(true)
	shop_levels = (build.get("shop", {}) as Dictionary).duplicate(true)
	_build_shop_mods()
	for u in Data.UPGRADES:
		if not upgrades.has(u.id):
			upgrades[u.id] = 0 if u.id != "base" else 1
	evolutions = (build.get("evolutions", []) as Array).duplicate(true)
	weapon = String(build.get("weapon", "base"))
	speed_level = int(build.get("speed_level", 0))
	nectar = int(build.get("nectar", 0))
	points = int(build.get("points", 0))
	# Gespeichertes max_hp ist bereits der Endwert, keine zweite Bonusbasis.
	max_hp = _base_max_hp() + int(evo_effect("hp")) + int(shop_mod("max_hp_add"))
	hp = clampi(int(build.get("hp", max_hp)), 1, max_hp)
	autofire = bool(Save.g("game.autofire_default", false))
	position = Vector2(160, 270)
	_refresh_shield_capacity()
	shield_hits = _initial_shield_hits()
	shield_regen_t = 0.0
	# Frischer Nektar: reparierte Leben zum Levelstart
	var start_heal := int(shop_mod("start_heal"))
	if start_heal > 0:
		hp = mini(max_hp, hp + start_heal)
	_build_visuals()
	hp_changed.emit(hp, max_hp)

func _base_max_hp() -> int:
	var base := int(difficulty.hp)
	var game := get_parent()
	# Boss Rush startet ausdrücklich mit mindestens vier Basisleben. Der
	# gespeicherte Endwert bleibt trotzdem niemals eine zweite Bonusbasis.
	if game != null and game.get("mode") == "rush":
		base = maxi(4, base)
	return base

func _build_visuals() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.sprite_frames("bee")
	sprite.play("default")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 2
	add_child(sprite)
	aura = ShieldRingsVisual.new()
	aura.name = "ShieldRings"
	aura.z_index = -1
	add_child(aura)
	_update_aura()
	engine_fx = CPUParticles2D.new()
	engine_fx.emitting = true
	engine_fx.amount = 10 if bool(Save.g("access.reduce_effects", false)) == false else 4
	engine_fx.lifetime = 0.35
	engine_fx.direction = Vector2(-1, 0)
	engine_fx.spread = 18.0
	engine_fx.initial_velocity_min = 30.0
	engine_fx.initial_velocity_max = 70.0
	engine_fx.scale_amount_min = 1.0
	engine_fx.scale_amount_max = 2.0
	engine_fx.color = Color(1.0, 0.85, 0.35, 0.55)
	engine_fx.z_index = -1
	add_child(engine_fx)
	# Begleiterdrohnen: eigener Körper je Einheit, sonst nur unsichtbare Schüsse
	for i in range(5):
		var c := AnimatedSprite2D.new()
		c.sprite_frames = Art.sprite_frames("drone")
		c.play("default")
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.z_index = 1
		c.visible = false
		c.modulate = Color(0.75, 1.0, 0.85, 0.95)
		add_child(c)
		companions.append(c)

# ------------------------------------------------------------ Werkstattwerte
## Aus den gekauften Stufen die Wirkungssummen bilden. Innerhalb eines Eintrags
## gilt die Stufe absolut (Stufe 3 ersetzt Stufe 2), zwischen Einträgen wird
## addiert.
func _build_shop_mods() -> void:
	shop_mods.clear()
	for id in shop_levels.keys():
		var lvl := int(shop_levels[id])
		if lvl <= 0:
			continue
		var step := ShopData.step(String(id), lvl - 1)
		var mod: Dictionary = step.get("mod", {})
		for k in mod.keys():
			shop_mods[k] = float(shop_mods.get(k, 0.0)) + float(mod[k])

func shop_mod(key: String, default: float = 0.0) -> float:
	if shop_mods.has(key):
		return float(shop_mods[key])
	return default

## Nach Änderungen an den Werkstattstufen (Debugmenü): Grenzen neu setzen.
func apply_shop_changes() -> void:
	var previous_capacity := shield_max
	_build_shop_mods()
	max_hp = _base_max_hp() + int(evo_effect("hp")) + int(shop_mod("max_hp_add"))
	hp = clampi(hp, 1, max_hp)
	_refresh_shield_capacity()
	shield_hits = mini(shield_max, shield_hits + maxi(0, shield_max - previous_capacity))
	if shield_hits >= shield_max or not shield_active():
		shield_regen_t = 0.0
	_update_aura()
	hp_changed.emit(hp, max_hp)

func shop_has(key: String) -> bool:
	return shop_mod(key) > 0.0

# ------------------------------------------------------------- Evolutionswerte
func evo_level(id: String) -> int:
	for e in evolutions:
		if String(e.get("id", "")) == id:
			return int(e.get("level", 1))
	return 0

func _evo_active(e: Dictionary) -> bool:
	var w := String(e.get("weapon", ""))
	if w == "":
		return true
	if w == "shield":
		return shield_active()
	return int(upgrades.get(w, 0)) > 0

func evo_effect(key: String) -> float:
	var total := 0.0
	for entry in evolutions:
		var e := Data.evo(String(entry.get("id", "")))
		if e.is_empty() or not _evo_active(e):
			continue
		var eff: Dictionary = e.get("effect", {})
		if eff.has(key):
			var value := float(eff[key]) * float(entry.get("level", 1))
			if evo_fused(String(e.id)):
				value = Data.fusion_boost(key, value)
			total += value
	return total

## Verschmolzen: ein Synergiepartner ist ebenfalls vorhanden und aktiv.
func evo_fused(id: String) -> bool:
	if evo_level(id) <= 0:
		return false
	for partner in Data.synergy_partners(id):
		if evo_level(String(partner)) > 0 and _evo_active(Data.evo(String(partner))):
			return true
	return false

## Faktor für Ja/Nein-Evolutionen (Pollen, Druckwelle …): verschmolzen stärker.
func fusion_factor(id: String, factor: float = 1.4) -> float:
	return factor if evo_fused(id) else 1.0

## Bestehende Verschmelzungen als Paare [a, b] (je Paar einmal).
func fusions() -> Array:
	var out: Array = []
	for entry in evolutions:
		var a := String(entry.get("id", ""))
		for b in Data.synergy_partners(a):
			if evo_level(String(b)) > 0 and a < String(b):
				out.append([a, String(b)])
	return out

func evo_has(id: String) -> bool:
	return evo_level(id) > 0

# ------------------------------------------------------------- Bewegung/Takt
func _physics_process(delta: float) -> void:
	if not alive:
		dead_t += delta
		return
	var game := get_parent()
	if game != null and game.has_method("is_play_frozen") and game.is_play_frozen():
		return
	precision = Bindings.is_precision()
	var input := Bindings.move_vector()
	var spd := _speed()
	vel = input * spd
	# Wind bleibt wie bisher gegensteuerbar; Gravitation ist eine eigene Kraft
	# und läuft ausdrücklich nicht durch die 72%-Windabschwächung.
	var environment := Vector2.ZERO
	if game != null and game.has_method("current_push"):
		var p: Vector2 = game.current_push()
		if input.length() > 0.2:
			var against := -input.normalized()
			var along := p.dot(against)
			if along > 0.0:
				p -= against * along * 0.72
		environment += p
	if game != null and game.has_method("gravity_pull"):
		var gravity: Vector2 = game.gravity_pull()
		environment += gravity
		if gravity.y > 0.0 and input.y < 0.0:
			# Auch diagonal/analog bleiben mindestens 10% der tatsächlich
			# angeforderten Aufwärtsgeschwindigkeit übrig (inkl. Präzision).
			environment.y = minf(environment.y, -input.y * spd * 0.90)
	vel += environment
	position += vel * delta
	position.x = clampf(position.x, play_bounds.position.x, play_bounds.position.x + play_bounds.size.x)
	position.y = clampf(position.y, play_bounds.position.y, play_bounds.end.y)
	if absf(vel.x) > 6.0:
		moving_dir = signf(vel.x)
	# Neigung
	var target_rot := clampf(vel.y / 900.0, -0.32, 0.32)
	if input.length() < 0.05:
		target_rot = sin(Time.get_ticks_msec() * 0.002) * 0.04
	sprite.rotation = lerpf(sprite.rotation, target_rot, clampf(delta * 9.0, 0.0, 1.0))
	sprite.flip_h = moving_dir < 0.0
	if sprite.sprite_frames.get_frame_count("default") > 1:
		sprite.speed_scale = 1.0 + clampf(vel.length() / 700.0, 0.0, 0.8)
	_update_timers(delta)
	_handle_firing(delta)
	_update_companions(delta)
	_update_aura(delta)

func _speed() -> float:
	var base := BASE_SPEED
	base *= 1.0 + 0.10 * float(speed_level)
	base *= 1.0 + evo_effect("speed_mult")
	if precision:
		base *= 0.45
	return base

func _update_timers(delta: float) -> void:
	iframes = maxf(0.0, iframes - delta)
	invuln_visual += delta
	fire_cd = maxf(0.0, fire_cd - delta)
	bomb_cd = maxf(0.0, bomb_cd - delta)
	companion_cd = maxf(0.0, companion_cd - delta)
	pulse_cd = maxf(0.0, pulse_cd - delta)
	tuning_t = maxf(0.0, tuning_t - delta)
	convert_t = maxf(0.0, convert_t - delta)
	drone_cd = maxf(0.0, drone_cd - delta)
	companion_phase += delta
	# Nur der taktische Kauf gibt Kapazität und Regeneration frei.
	# Werkstatt/Bastion beschleunigen, Nektarstau füllt nur gekaufte Ladungen.
	if shield_active() and shield_hits < shield_max:
		shield_regen_t += delta
		var duration := shield_regen_duration()
		while shield_regen_t + 0.000001 >= duration and shield_hits < shield_max:
			shield_regen_t = maxf(0.0, shield_regen_t - duration)
			shield_hits += 1
			Audio.sfx("shield_hit", -16.0, 1.4)
	if shield_hits >= shield_max or not shield_active():
		shield_regen_t = 0.0
	sprite.visible = true
	if iframes > 0.0:
		sprite.modulate.a = 0.35 if int(invuln_visual * 18.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	# Nektar-Umwandlung
	if convert_t <= 0.0 and evo_has("nectar_convert") and nectar >= int(evo_effect("nectar_convert")) and hp < max_hp:
		convert_t = 20.0
		nectar -= int(evo_effect("nectar_convert"))
		heal(1)
		nectar_changed.emit(nectar)
		Audio.sfx("pickup_heart", -6.0, 1.0)
		notice.emit("Blütenstaub zu Leben umgewandelt")
	# Pollenschleier
	if evo_has("pollen_trail"):
		pollen_cd -= delta
		if pollen_cd <= 0.0 and vel.length() > 40.0:
			pollen_cd = 0.22 / fusion_factor("pollen_trail", 1.35)
			var g := get_parent()
			if g != null and g.has_method("spawn_pollen"):
				g.spawn_pollen(position, (1.0 + evo_level("pollen_trail") * 0.5) * fusion_factor("pollen_trail"))
	# Taktische Bombe: lädt nach und räumt von selbst auf
	if int(upgrades.get("bombs", 0)) > 0 and bomb_cd <= 0.0 and get_parent() != null:
		var g := get_parent()
		if g.has_method("player_pulse"):
			var lvl := int(upgrades.get("bombs", 0))
			bomb_cd = (17.0 - 2.0 * float(lvl)) / (1.0 + shop_mod("bomb_rate"))
			g.player_pulse(position)
			Audio.sfx("bomb", -10.0, 1.05)
	# Druckwelle
	if evo_has("resonance_pulse"):
		if fire_active() and pulse_cd <= 0.0:
			hold_time += delta
			if hold_time >= 3.0 / fusion_factor("resonance_pulse", 1.5):
				hold_time = 0.0
				pulse_cd = 6.0 / fusion_factor("resonance_pulse", 1.5)
				if get_parent() != null and get_parent().has_method("player_pulse"):
					get_parent().player_pulse(position)

func fire_active() -> bool:
	return Bindings.is_firing() or autofire

func _handle_firing(delta: float) -> void:
	fire_held = Bindings.is_firing()
	if not fire_active():
		hold_time = 0.0
		calm_bonus = maxf(0.0, calm_bonus - delta * 1.5)
		return
	if fire_cd > 0.0:
		return
	fire_cd = fire_interval()
	_fire_volley()
	shot_counter += 1
	# Ruhepol
	if evo_has("resonance_calm"):
		calm_bonus = minf(float(evo_effect("calm")), calm_bonus + 0.04)
	# Taktgeber
	var rhythm_n := rhythm_interval()
	if rhythm_n > 0 and shot_counter % rhythm_n == 0:
		_fire_rhythm()
		last_volley_damage = _volley_acc
		last_volley_shots = _volley_shots
	# Druckwelle-Timer läuft in _update_timers

## HUD-Vertrag: nur der taktische Kauf schaltet frei, auch bei null Ladungen.
## Werkstatt/Evolution bleiben gespeichert, sind aber niemals eine Schildquelle.
func shield_active() -> bool:
	return int(upgrades.get("shield", 0)) > 0

func _refresh_shield_capacity() -> void:
	shield_max = clampi(int(upgrades.get("shield", 0)), 0, 3)
	shield_hits = clampi(shield_hits, 0, shield_max)
	if not shield_active():
		shield_regen_t = 0.0

func _initial_shield_hits() -> int:
	return shield_max

func shield_regen_duration() -> float:
	return 12.0 * (1.0 - clampf(evo_effect("shield_regen"), 0.0, 0.6)) / shield_regen_speed()

func shield_regen_progress() -> float:
	if not shield_active():
		return 0.0
	if shield_hits >= shield_max:
		return 1.0
	return clampf(shield_regen_t / shield_regen_duration(), 0.0, 1.0)

func shield_regen_speed() -> float:
	return maxf(0.1, 1.0 + shop_mod("shield_regen"))

## Für Prüfläufe: Dauer der Unverwundbarkeit nach einem Treffer.
func iframe_time() -> float:
	return float(difficulty.iframes) + evo_effect("iframes") + shop_mod("iframe_add")

## Für Prüfläufe: Ladezeit der Druckwelle.
func bomb_cycle() -> float:
	return (17.0 - 2.0 * float(int(upgrades.get("bombs", 0)))) / (1.0 + shop_mod("bomb_rate"))

## Schussfolge. Nach oben gedeckelt: ab etwa elf Salven je Sekunde wird das Bild
## unlesbar, und der Reiz der Verbesserungen liegt nicht im Dauerfeuer.
func fire_interval() -> float:
	var rate := minf(evo_effect("fire_rate_mult") + shop_mod("fire_rate"), MAX_RATE_BONUS)
	var iv := BASE_INTERVAL / maxf(0.45, 1.0 + rate)
	return maxf(MIN_INTERVAL, iv)

## Gemessene Angriffskraft: Schaden je Sekunde aus der letzten Salve, mit der
## Trefferchance-Verstärkung (Volltreffer) als Erwartungswert.
func attack_dps() -> float:
	var dmg := last_volley_damage
	if dmg <= 0.0 and not _has_fired_volley:
		# Nur vor dem ersten Schuss: Grundbewaffnung annehmen.
		dmg = 2.0 * 7.4 * dmg_mult()
	var crit := clampf(shop_mod("crit") + evo_effect("crit_chance"), 0.0, 1.0)
	dmg *= 1.0 + crit          # Volltreffer verdoppelt, also im Schnitt 1 + Chance
	return dmg / fire_interval()

## Durchschnittlicher Schaden einer einzelnen Kugel. Wichtig für die Gegnerhärte:
## viele schwache Kugeln sind etwas anderes als wenige starke, auch bei gleichem
## Gesamtschaden je Sekunde.
func shot_power() -> float:
	var n := maxi(1, last_volley_shots)
	var per := last_volley_damage / float(n)
	if per <= 0.0 and not _has_fired_volley:
		per = 7.4 * dmg_mult()
	return per * (1.0 + clampf(shop_mod("crit") + evo_effect("crit_chance"), 0.0, 1.0))

## Ungenutztes Schnellfeuer oberhalb der echten Taktgrenze wird in Wucht
## umgerechnet. So bleibt jede Kaufstufe spürbar, die Kugelzahl aber gedeckelt.
func rate_damage_mult() -> float:
	var requested := maxf(0.45, 1.0 + evo_effect("fire_rate_mult") + shop_mod("fire_rate"))
	return maxf(1.0, requested * fire_interval() / BASE_INTERVAL)

func dmg_mult() -> float:
	var m := 1.0 + evo_effect("dmg_mult") + shop_mod("dmg") + calm_bonus
	if tuning_t > 0.0:
		m *= 1.25
	return maxf(0.35, m) * rate_damage_mult()

func _fire_volley() -> void:
	var lvl := int(upgrades.get(weapon, 0))
	var dm := dmg_mult()
	_volley_acc = 0.0
	_volley_shots = 0
	_orbit_phases.clear()
	var game := get_parent()
	if game == null or not game.has_method("spawn_player_bullet"):
		return
	_has_fired_volley = true
	var muzzle := position + Vector2(20, 0)
	var pierce := int(evo_effect("pierce"))
	match weapon:
		"fan":
			# Fächer = Fläche: 4/5/6 Stacheln. Mit Kreisflug oder Welle liegen sie in
			# gestaffelten Bahnen (fan_k), statt alle auf derselben Linie zu laufen.
			var count: int = [4, 5, 6][clampi(lvl, 1, 3) - 1]
			var spread := 0.30 + 0.06 * lvl
			for i in range(count):
				var k := float(i) / float(maxi(1, count - 1))
				var a := lerpf(-spread, spread, k)
				_spawn(muzzle, Vector2.RIGHT.rotated(a) * 640.0,
					5.6 * dm, "bullet_fan", {"pierce": pierce, "r": 5.0, "rot": true, "fan_k": k}, true)
		"lightning":
			# Jede Stufe eine Blitzkugel mehr (2/3/4), damit Stufe 2 sichtbar zählt.
			var offs := [-6.0, 6.0]
			if lvl == 2:
				offs = [-10.0, 0.0, 10.0]
			elif lvl >= 3:
				offs = [-15.0, -5.0, 5.0, 15.0]
			for o in offs:
				_spawn(muzzle + Vector2(0, o), Vector2(940, 0),
					5.8 * dm, "bullet_lightning", {"pierce": 1 + pierce, "r": 4.0, "life": 1.1,
						"lchain": 1 + lvl}, true)
		"plasma":
			# Plasmawaffe: kleiner Fächer (etwa ein Viertel des Fächerschusses)
			# und mehr Wucht je Kugel.
			var y_off := [0.0] if lvl < 2 else [-8.0, 8.0]
			if lvl >= 3:
				y_off = [-10.0, 0.0, 10.0]
			var plasma_spread := 0.075 + 0.02 * lvl
			for i in range(y_off.size()):
				var po: float = y_off[i]
				var pa := 0.0
				if y_off.size() > 1:
					pa = lerpf(-plasma_spread, plasma_spread,
						float(i) / float(maxi(1, y_off.size() - 1)))
				_spawn(muzzle + Vector2(0, po), Vector2.RIGHT.rotated(pa) * 430.0,
					18.4 * dm, "bullet_plasma", {"pierce": pierce, "r": 9.0, "splash": 28.0,
						"life": 2.0, "scale": 0.9 + 0.1 * lvl, "rot": true}, true)
		_:
			var lv := int(upgrades.get("base", 1))
			var y_off2 := [-7.0, 7.0] if lv < 2 else [-9.0, 0.0, 9.0]
			for o in y_off2:
				_spawn(muzzle + Vector2(0, o), Vector2(760, 0),
					7.4 * dm, "bullet_base", {"pierce": pierce, "r": 5.0}, true)
	_fire_shop_patterns(muzzle, dm, pierce)
	last_volley_damage = _volley_acc
	last_volley_shots = _volley_shots
	if lvl > 0:
		Audio.sfx_var("shot_" + weapon, -19.0)
	else:
		Audio.sfx_var("shot_base", -20.0)

## Ein Schuss mit allen Werkstatt-Zusätzen (Durchschlag, Wucht, Zielsuche,
## Kreisflug, Wellenform).
func _spawn(pos: Vector2, vel: Vector2, dmg: float, art: String, opts: Dictionary = {},
		shape: bool = false) -> void:
	var game := get_parent()
	if game == null or not game.has_method("spawn_player_bullet"):
		return
	var o := opts.duplicate(true)
	o["pierce"] = int(o.get("pierce", 0)) + int(shop_mod("pierce_add"))
	o["splash"] = float(o.get("splash", 0.0)) + shop_mod("splash")
	o["chain"] = int(o.get("chain", 0)) + int(shop_mod("chain"))
	if shape:
		var homing := float(o.get("homing", 0.0)) + shop_mod("homing") + shop_mod("homing_add")
		if homing > 0.0:
			o["homing"] = homing
	var big := shop_mod("big", 1.0)
	if big > 1.0:
		o["scale"] = float(o.get("scale", 1.0)) * big
		o["r"] = float(o.get("r", 5.0)) * (1.0 + (big - 1.0) * 0.5)
	# Formen komponieren: Kreisphase wahrt Richtung/Mündung, Welle moduliert
	# den Radius, Zielsuche zieht die Phase zum Ziel. Keine neue Feuerquelle.
	var fan_k := float(o.get("fan_k", -1.0))
	o.erase("fan_k")
	if shape and shop_has("orbit"):
		o["orbit_r"] = shop_mod("orbit_r")
		if fan_k >= 0.0:
			# Fächer im Kreisflug: drei versetzte Ringe statt einem.
			o["orbit_r"] = float(o.orbit_r) * lerpf(0.62, 1.38, fan_k)
		o["orbit_w"] = shop_mod("orbit_w", 2.4) * (1.0 + shop_mod("bullet_speed"))
		o["orbit_center"] = position
		var transverse := (pos - position).rotated(-vel.angle()).y
		var phase := vel.angle() + clampf(transverse * 0.028, -0.5, 0.5) + float(shot_counter) * 0.41
		# Auch Nebenläufe dürfen nicht genau auf Hauptkugeln landen.
		for attempt in range(32):
			var occupied := false
			for other in _orbit_phases:
				if absf(angle_difference(phase, other)) < 0.28:
					occupied = true
					break
			if not occupied:
				break
			phase += 0.30
		_orbit_phases.append(phase)
		o["orbit_a"] = phase
		o["life"] = maxf(float(o.get("life", 1.6)), 2.2)
	if shape and shop_has("wave"):
		# Aufeinanderfolgende Kugeln schwingen gegenphasig: eine Doppelhelix.
		var flip := -1.0 if _volley_shots % 2 == 1 else 1.0
		o["wave_amp"] = (shop_mod("wave_amp") + shop_mod("wave_amp_add")) * flip
		if fan_k >= 0.0:
			# Fächer in der Welle: unterschiedlich weite Wellen ergeben ein breites Band.
			o["wave_amp"] = float(o.wave_amp) * lerpf(0.45, 1.55, fan_k)
		o["wave_len"] = shop_mod("wave_len", 300.0)
		o["wave_sp"] = 1.0 + shop_mod("wave_speed")
	var speed := 1.0 + shop_mod("bullet_speed")
	var emitted: Variant = game.spawn_player_bullet(pos, vel * speed, dmg, art, o)
	if emitted is Dictionary and not emitted.is_empty():
		_volley_acc += dmg
		_volley_shots += 1

## Zusätzliche Schussformen aus der Werkstatt: Heck, Seiten, Doppelläufe,
## Spirale und Salven.
func _fire_shop_patterns(muzzle: Vector2, dm: float, pierce: int) -> void:
	var back_n := mini(MAX_BACK, int(shop_mod("back_n")))
	var back_dmg := 5.4 * dm * (1.0 + shop_mod("back_dmg"))
	for i in range(back_n):
		var a := PI + (float(i) - float(back_n - 1) * 0.5) * 0.16
		_spawn_pattern(position + Vector2(-18, 0), Vector2.RIGHT.rotated(a) * 560.0,
			back_dmg, pierce, {"r": 4.6, "rot": true})
	var side_n := mini(MAX_SIDE, int(shop_mod("side_n")))
	if side_n > 0:
		var side_dmg := 4.6 * dm * (1.0 + shop_mod("side_dmg"))
		for i in range(side_n):
			var off := float(i) * 9.0
			for dir in [-1.0, 1.0]:
				_spawn_pattern(position + Vector2(2, dir * 12.0), Vector2(0, dir * 620.0),
					side_dmg, pierce, {"r": 4.2, "rot": true, "life": 1.1 + off * 0.02})
	var lanes := mini(MAX_LANES, int(shop_mod("lanes_add")))
	if lanes > 0:
		var lane_dmg := dmg_mult() * 4.4 * (1.0 + shop_mod("lane_dmg"))
		for i in range(lanes):
			var off := (float(i) + 1.0) * 15.0 * (1.0 if i % 2 == 0 else -1.0)
			_spawn_pattern(muzzle + Vector2(0, off), Vector2(720, 0), lane_dmg, pierce,
				{"r": 4.4})
	var spiral := shop_mod("spiral")
	if spiral > 0.0:
		# Nur jede dritte Salve eine Spiralkugel – sonst wächst die Kugelzahl
		# schneller als der Bildschirm verkraftet.
		var ang := float(shot_counter) * spiral
		for k in range(1 if shot_counter % 3 == 0 else 0):
			var a := ang + float(k) * PI
			_spawn_pattern(position, Vector2.RIGHT.rotated(a) * 600.0, 4.8 * dm, pierce,
				{"r": 4.4, "rot": true})
	var burst := int(shop_mod("burst"))
	if burst > 0 and (shot_counter + 1) % maxi(4, burst) == 0:
		for k in range(2):
			var a := (-1.0 if k == 0 else 1.0) * 0.22
			_spawn_pattern(muzzle, Vector2.RIGHT.rotated(a) * 660.0, 5.0 * dm, pierce,
				{"r": 5.0, "rot": true, "life": 1.3})

## Ein Zusatzgeschoss übernimmt EIN Waffenprofil, nie einen zusätzlichen Fächer.
## Die relativen Muster-Schäden bleiben erhalten, Material/Tempo/Wirkung stimmen.
func _spawn_pattern(pos: Vector2, velocity: Vector2, damage: float, pierce: int,
		opts: Dictionary = {}) -> void:
	var o := opts.duplicate(true)
	o["pierce"] = pierce
	var art := "bullet_" + weapon
	var damage_ratio := 1.0
	var speed_ratio := 1.0
	match weapon:
		"plasma":
			damage_ratio = 18.4 / 7.4
			speed_ratio = 430.0 / 760.0
			o["splash"] = 28.0
			o["r"] = float(o.get("r", 5.0)) * 1.8
			o["scale"] = 0.9 + 0.1 * float(upgrades.get("plasma", 1))
		"lightning":
			damage_ratio = 5.8 / 7.4
			speed_ratio = 940.0 / 760.0
			o["pierce"] = pierce + 1
			o["lchain"] = 1 + int(upgrades.get("lightning", 1))
		"fan":
			damage_ratio = 5.6 / 7.4
			speed_ratio = 640.0 / 760.0
		_:
			art = "bullet_base"
	_spawn(pos, velocity * speed_ratio, damage * damage_ratio, art, o, true)

func rhythm_interval() -> int:
	var level := evo_level("resonance_beat")
	if level <= 0:
		return 0
	var effect: Dictionary = Data.evo("resonance_beat").get("effect", {})
	var n := float(effect.get("rhythm", 12)) / float(level)
	if evo_fused("resonance_beat"):
		n = Data.fusion_boost("rhythm", n)
	return maxi(3, int(n))

func _fire_rhythm() -> void:
	var mult := 2.4 * (1.0 + evo_effect("rhythm_mult"))
	var chain := int(evo_effect("rhythm_chain"))
	_spawn(position + Vector2(24, 0), Vector2(820, 0), 9.0 * dmg_mult() * mult,
		"bullet_plasma", {"pierce": 2 + int(evo_effect("pierce")), "r": 9.0, "scale": 1.15,
			"chain": chain, "life": 1.8, "tint": Color(1.4, 1.4, 1.6)}, true)
	Audio.sfx("shot_plasma", -12.0, 1.3)

func _update_companions(delta: float) -> void:
	# Höchstens fünf Begleiter (so viele kann die Biene sichtbar führen), auch verschmolzen.
	var count := mini(MAX_COMPANIONS, int(upgrades.get("companion", 0)) + int(evo_effect("companion_add")))
	companion_phase += delta
	_update_companion_visuals(count)
	if count <= 0:
		return
	if companion_cd <= 0.0:
		var rate := 0.44 / (1.0 + evo_effect("companion_rate"))
		companion_cd = rate
		var game := get_parent()
		if game != null and game.has_method("spawn_player_bullet"):
			for i in range(count):
				var p := companion_position(i, count)
				var opts := {"r": 4.0, "tint": Color(0.8, 1.0, 0.9)}
				if evo_has("swarm_echo"):
					_spawn_pattern(p + Vector2(10, 0), Vector2(700, 0), 4.4 * dmg_mult(), int(evo_effect("pierce")), opts)
				else:
					_spawn(p + Vector2(10, 0), Vector2(700, 0), 4.4 * dmg_mult(), "bullet_base", opts, true)
	# Opferdrohne
	if evo_has("drone_sacrifice") and drone_cd <= 0.0:
		var g := get_parent()
		if g != null and g.has_method("drone_intercept"):
			if g.drone_intercept(position):
				drone_cd = float(evo_effect("drone_shield"))

func _update_companion_visuals(count: int) -> void:
	for i in range(companions.size()):
		var c := companions[i]
		if i >= count:
			c.visible = false
			continue
		c.visible = true
		c.position = companion_position(i, count) - position
		c.scale = Vector2(0.9, 0.9)
		var bob := sin(companion_phase * 6.0 + float(i)) * 0.5
		c.modulate.a = 0.9 + 0.1 * bob

func companion_position(i: int, count: int) -> Vector2:
	var form := 0.0
	if evo_has("companion_form"):
		form = 1.0 if vel.x > 30.0 else 0.0
	var t := companion_phase * 1.7 + TAU * float(i) / float(maxi(1, count))
	if form > 0.0:
		var back := -26.0 - 12.0 * float(i % 2)
		var lane := 1.0 if count <= 1 else float(i) / float(count - 1)
		return position + Vector2(back, -14.0 + 28.0 * lane)
	return position + Vector2(cos(t) * 30.0 - 6.0, sin(t) * 26.0)

func _update_aura(delta: float = 0.0) -> void:
	if not is_instance_valid(aura):
		return
	aura.set_status(shield_hits if alive and shield_active() else 0,
		bool(Save.g("access.reduce_effects", false)))
	aura.advance(delta)

# --------------------------------------------------------------- Schaden/Leben
func take_damage(amount: int, from: Vector2 = Vector2.RIGHT) -> bool:
	if not alive or iframes > 0.0:
		return false
	last_hit_from = from
	if shield_active() and shield_hits > 0:
		shield_hits -= 1
		shield_regen_t = 0.0
		iframes = 0.55 + shop_mod("shield_grace")
		invuln_visual = 0.0
		_update_aura()
		if evo_has("chitin_bastion"):
			var g := get_parent()
			if g != null and g.has_method("shield_break_pulse"):
				g.shield_break_pulse(position)
		Audio.sfx("shield_hit", -4.0, 0.9)
		_knockback(from)
		return true
	var dmg := amount
	if precision and evo_has("chitin_guard"):
		var due := float(amount) * (1.0 - clampf(evo_effect("precision_guard"), 0.0, 0.9)) + _guard_damage_carry
		dmg = int(floor(due + 0.000001))
		_guard_damage_carry = maxf(0.0, due - float(dmg))
	hp -= dmg
	iframes = float(difficulty.iframes) + evo_effect("iframes") + shop_mod("iframe_add")
	invuln_visual = 0.0
	_knockback(from)
	hp_changed.emit(hp, max_hp)
	Audio.sfx("player_hit", -2.0, 0.95)
	if get_parent() != null and get_parent().has_method("on_player_hit"):
		get_parent().on_player_hit(amount)
	if hp <= 0:
		_die()
	return true

func _knockback(from: Vector2) -> void:
	var dir := (position - from)
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	position += dir.normalized() * 10.0
	position.x = clampf(position.x, play_bounds.position.x, play_bounds.end.x)
	position.y = clampf(position.y, play_bounds.position.y, play_bounds.end.y)

func _die() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	_update_aura()
	sprite.visible = false
	engine_fx.emitting = false
	hp_changed.emit(0, max_hp)
	Audio.sfx("explosion_big", -2.0, 0.8)
	died.emit()

func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)

func add_max_hp(n: int) -> void:
	max_hp += n
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)

func add_nectar(n: int, pickup: bool = true) -> void:
	if pickup:
		n += int(evo_effect("nectar_pickup"))
		var due := float(n) * (1.0 + evo_effect("nectar_mult")) + _nectar_carry
		n = int(floor(due + 0.000001))
		_nectar_carry = maxf(0.0, due - float(n))
	if evo_has("nectar_overflow") and int(upgrades.get(weapon, 0)) >= _weapon_max(weapon):
		add_points(int(8.0 * float(n) * fusion_factor("nectar_overflow", 1.5)))
		if shield_active() and shield_hits < shield_max:
			shield_hits += 1
			if shield_hits >= shield_max:
				shield_regen_t = 0.0
			_update_aura()
	nectar += n
	nectar_changed.emit(nectar)

func add_points(n: int) -> void:
	points += n
	# Verdiente Runpunkte sind nicht das ausgebbare Werkstattguthaben.
	# Training sowie reine Player-Vorschauen dürfen keinen Lauf kreditieren.
	var game := get_parent()
	if game is Game and game.mode in ["campaign", "rush"] and Save.has_method("add_run_score"):
		Save.call("add_run_score", n)

func _weapon_max(w: String) -> int:
	var u := Data.upgrade(w)
	return int(u.get("max", 3))

## Nach einem Neustart am Kontrollpunkt: Taktung und Messwerte frisch aufsetzen.
func attack_timer_reset() -> void:
	fire_cd = 0.0
	shot_counter = 0
	_has_fired_volley = false
	_volley_acc = 0.0
	_volley_shots = 0
	last_volley_damage = 0.0
	last_volley_shots = 0

func reset_for_checkpoint(build: Dictionary) -> void:
	hp = int(build.get("hp", max_hp))
	nectar = int(build.get("nectar", nectar))
	upgrades = (build.get("upgrades", upgrades) as Dictionary).duplicate(true)
	weapon = String(build.get("weapon", weapon))
	speed_level = int(build.get("speed_level", speed_level))
	position = Vector2(160, 270)
	iframes = 2.0
	alive = true
	sprite.visible = true
	engine_fx.emitting = true
	_refresh_shield_capacity()
	shield_hits = _initial_shield_hits()
	shield_regen_t = 0.0
	_update_aura()
	hp_changed.emit(hp, max_hp)

# ------------------------------------------------------------- Kauf/Ausrüstung
func upgrade_cost_for(id: String) -> int:
	var u := Data.upgrade(id)
	if u.is_empty():
		return 0
	var cur := int(upgrades.get(id, 0))
	if cur >= int(u.get("max", 1)):
		return 0
	return Data.upgrade_cost(id, cur, evo_effect("cost_mult"))

func try_buy(id: String) -> Dictionary:
	var u := Data.upgrade(id)
	if u.is_empty():
		return {"ok": false, "msg": ""}
	if id == "repair":
		if hp >= max_hp:
			return {"ok": false, "msg": "bar.full_hp"}
		var cost := Data.upgrade_cost("repair", 0, evo_effect("cost_mult"))
		if nectar < cost:
			return {"ok": false, "msg": "bar.no_nectar"}
		nectar -= cost
		heal(1)
		nectar_changed.emit(nectar)
		return {"ok": true, "msg": ""}
	var cur := int(upgrades.get(id, 0))
	if cur >= int(u.get("max", 1)):
		# Ausgeschöpft: bei Waffen bedeutet das nur "ausrüsten", kein Verbrauch.
		if String(u.get("kind", "")) == "weapon":
			if id == "base" or cur > 0:
				_equip(id)
				return {"ok": true, "msg": ""}
		if id == "speed":
			_cycle_speed()
			return {"ok": true, "msg": ""}
		return {"ok": false, "msg": ""}
	var cost := upgrade_cost_for(id)
	if nectar < cost:
		# Zu wenig Blütenstaub: Waffen lassen sich trotzdem ausrüsten,
		# der Versuch zu verbessern wechselt also auf die Waffe.
		if String(u.get("kind", "")) == "weapon" and (id == "base" or cur > 0):
			_equip(id)
			return {"ok": false, "msg": "bar.no_nectar", "equipped": true}
		return {"ok": false, "msg": "bar.no_nectar"}
	nectar -= cost
	upgrades[id] = cur + 1
	nectar_changed.emit(nectar)
	if String(u.get("kind", "")) == "weapon":
		if id != "base":
			_equip(id)
	elif id == "speed":
		speed_level = int(upgrades.get("speed", 0))
	elif id == "shield":
		_refresh_shield_capacity()
		shield_hits = mini(shield_max, shield_hits + 1)
		shield_regen_t = 0.0
		_update_aura()
	upgraded.emit(id)
	return {"ok": true, "msg": ""}

func _equip(id: String) -> void:
	if weapon == id:
		return
	weapon = id
	if evo_has("resonance_tuning"):
		tuning_t = 2.0 * fusion_factor("resonance_tuning", 1.5)
	Audio.sfx("purchase", -6.0, 1.15)

func _cycle_speed() -> void:
	# Reduktion auf eine bereits freigeschaltete niedrigere Stufe
	var maxlvl := int(upgrades.get("speed", 0))
	if maxlvl <= 0:
		return
	speed_level = speed_level - 1 if speed_level > 0 else maxlvl
	Audio.sfx("ui_move", -8.0, 1.2, true)

func on_boss_phase() -> void:
	if evo_has("nectar_font"):
		add_nectar(int(evo_effect("nectar_phase")), false)

func evo_summary() -> Array:
	var out: Array = []
	for entry in evolutions:
		var e := Data.evo(String(entry.get("id", "")))
		if e.is_empty():
			continue
		out.append({
			"id": e.id, "name": e.name, "family": e.family,
			"level": int(entry.get("level", 1)), "max": int(e.max),
			"desc": e.desc, "active": _evo_active(e),
			"weapon": String(e.get("weapon", "")),
		})
	return out
