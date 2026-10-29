extends Node2D
## Meisterevolutionen (Data.MASTERS): eigene Mechaniken, die aus zwei Eltern-Evolutionen
## entstehen. Game und Player rufen die Haken auf; Zeichnung und Kollisionen der
## neuen Effekte (Wirbel, Klangring, Schildwall, Markierungen) liegen hier.

const STORM_ORBIT := 64.0
const STORM_RADIUS := 24.0
const STORM_DPS := 30.0
const ECHO_RADIUS := 46.0
const ECHO_BUILD := 3.0
const ECHO_TIME := 4.0
const ECHO_COOLDOWN := 5.0
const WALL_DOWN := 3.0
const WALL_RADIUS := 11.0
const MARK_TIME := 3.0
const BLOOM_DELAY := 0.3
const BLOOM_LINK := 90.0
const GOLD_EVERY := 6
const GOLD_VALUE := 5
const LIFE_RESERVE := 30

var game: Node
var storm_angle := 0.0
var _storm_tick := 0.0
var echo_charge := 0.0
var echo_t := 0.0
var echo_cd := 0.0
## Schildwall: Ausfallzeit je Drohne (Index wie Player.companion_position).
var wall_down: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## Kettenblüte: anstehende Explosionen {p, r, t}.
var blooms: Array = []
var kills := 0
var _t := 0.0

func _init(owner_game: Node = null) -> void:
	game = owner_game
	z_index = 14
	name = "Masters"

func has(id: String) -> bool:
	return game != null and game.player != null and game.player.evo_has(id) \
		and game.player._evo_active(Data.evo(id))

# ------------------------------------------------------------------ Takt
func update(delta: float) -> void:
	_t += delta
	if game == null or game.player == null or not game.player.alive:
		queue_redraw()
		return
	if has("m_pollen_storm"):
		_update_storm(delta)
	if has("m_echo_shield"):
		_update_echo(delta)
	if has("m_shield_wall"):
		_update_wall(delta)
	if not blooms.is_empty():
		_update_blooms(delta)
	queue_redraw()

## Pollensturm: Wirbel kreist um die Biene, trifft Gegner im Takt und löscht Geschosse.
func storm_center() -> Vector2:
	return game.player.position + Vector2.from_angle(storm_angle) * STORM_ORBIT

func _update_storm(delta: float) -> void:
	storm_angle = fposmod(storm_angle + delta * 3.0, TAU)
	var c := storm_center()
	for b in game.bullets.enemy_bullets:
		if float(b.life) > 0.0 and (b.p as Vector2).distance_to(c) <= STORM_RADIUS + float(b.r):
			b.life = 0.0
	_storm_tick -= delta
	if _storm_tick > 0.0:
		return
	_storm_tick = 0.25
	var dmg: float = STORM_DPS * 0.25 * game.player.dmg_mult()
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e.position.distance_to(c) <= STORM_RADIUS + e.radius:
			e.take_damage(dmg * game._target_damage_mult(e), c)
	if game.boss != null and is_instance_valid(game.boss) and not game.boss.dead:
		var contact: Dictionary = game.boss.trace_hit(c, c, STORM_RADIUS)
		if not contact.is_empty():
			game.boss.take_damage(dmg * game._target_damage_mult(game.boss), contact.p, int(contact.part))

## Echoschild: Dauerfeuer lädt den Klangring; aktiv wirft er Feindgeschosse zurück.
func _update_echo(delta: float) -> void:
	echo_cd = maxf(0.0, echo_cd - delta)
	if echo_t > 0.0:
		echo_t -= delta
		var pos: Vector2 = game.player.position
		for b in game.bullets.enemy_bullets:
			if float(b.life) <= 0.0 or (b.p as Vector2).distance_to(pos) > ECHO_RADIUS + float(b.r):
				continue
			b.life = 0.0
			var back := ((b.p as Vector2) - pos).normalized()
			if back == Vector2.ZERO:
				back = Vector2.RIGHT
			game.spawn_player_bullet(b.p, back * 520.0, 10.0 * game.player.dmg_mult(), "bullet_lightning",
				{"r": 5.0, "life": 1.2, "proc_depth": 1, "tint": Color(0.8, 1.0, 1.0)})
		if echo_t <= 0.0:
			echo_cd = ECHO_COOLDOWN
		return
	if echo_cd <= 0.0 and game.player.fire_active():
		echo_charge = minf(1.0, echo_charge + delta / ECHO_BUILD)
		if echo_charge >= 1.0:
			echo_charge = 0.0
			echo_t = ECHO_TIME
			Audio.sfx("combo_ready", -8.0, 1.4)
	else:
		echo_charge = maxf(0.0, echo_charge - delta * 0.5)

## Schildwall: Drohnen stehen als Wand vor der Biene und schlucken Feindgeschosse.
func wall_position(i: int, count: int) -> Vector2:
	var lane := 0.5 if count <= 1 else float(i) / float(count - 1)
	return game.player.position + Vector2(34.0, -36.0 + 72.0 * lane)

func wall_active(i: int) -> bool:
	return i < wall_down.size() and float(wall_down[i]) <= 0.0

func _update_wall(delta: float) -> void:
	var count: int = game.player.companion_count()
	for i in range(wall_down.size()):
		wall_down[i] = maxf(0.0, float(wall_down[i]) - delta)
	for i in range(count):
		if not wall_active(i):
			continue
		var p := wall_position(i, count)
		for b in game.bullets.enemy_bullets:
			if float(b.life) > 0.0 and (b.p as Vector2).distance_to(p) <= WALL_RADIUS + float(b.r):
				b.life = 0.0
				wall_down[i] = WALL_DOWN
				game.fx.add("spark", b.p, {"life": 0.25, "scale": 1.3, "tint": Color(0.7, 0.95, 1.0)})
				Audio.sfx("shield_hit", -12.0, 1.4)
				break

# ------------------------------------------------------------------ Haken
## Gegner besiegt: Goldrausch zählt mit, Kettenblüte plant die Explosion ein.
func on_kill(e: Node2D) -> void:
	if has("m_gold_rush"):
		kills += 1
		if kills % GOLD_EVERY == 0:
			game.spawn_gold_drop(e.position, GOLD_VALUE)

## Kettenblüte: Explosionswolke zündet nach kurzer Zeit und steckt Nachbarwolken an.
func schedule_bloom(pos: Vector2, radius: float) -> void:
	if has("m_chain_bloom"):
		blooms.append({"p": pos, "r": radius, "t": BLOOM_DELAY})

func _update_blooms(delta: float) -> void:
	var due: Array = []
	for bl in blooms:
		bl.t = float(bl.t) - delta
		if float(bl.t) <= 0.0:
			due.append(bl)
	for bl in due:
		blooms.erase(bl)
		_detonate(bl.p, float(bl.r))

func _detonate(pos: Vector2, radius: float) -> void:
	var r := radius * 1.3
	var dmg: float = 16.0 * float(maxi(1, game.player.evo_level("pollen_burst"))) * game.player.dmg_mult()
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e.position.distance_to(pos) <= r + e.radius:
			e.take_damage(dmg * game._target_damage_mult(e), pos)
	game.fx.add("ring", pos, {"life": 0.35, "scale": r / 20.0, "grow": 0.6, "tint": Color(1.0, 0.85, 0.35, 0.8)})
	game.shake(2.0)
	# Nachbarwolken (auch Pollenschleier) zünden mit; jede Wolke nur einmal.
	for h in game.fx.hazards:
		if String(h.kind) != "pollen_cloud" or not bool(h.get("friendly", false)) or bool(h.get("bloomed", false)):
			continue
		if (h.p as Vector2).distance_to(pos) <= BLOOM_LINK:
			h["bloomed"] = true
			h.life = minf(float(h.life), 0.2)
			blooms.append({"p": h.p, "r": float(h.radius), "t": 0.12})

## Todesmal: kritischer Treffer markiert das Ziel.
func mark(target: Node2D) -> void:
	if has("m_death_mark") and is_instance_valid(target):
		target.set_meta("death_mark", _t + MARK_TIME)

func mark_mult(target: Node2D) -> float:
	if not is_instance_valid(target) or not target.has_meta("death_mark"):
		return 1.0
	if float(target.get_meta("death_mark")) < _t:
		target.remove_meta("death_mark")
		return 1.0
	return 1.5 if target == game.boss else 2.0

## Dornenpanzer: jeder eingesteckte Treffer schleudert zwölf Stacheln rundum.
func on_player_struck() -> void:
	if not has("m_thorn_armor"):
		return
	var pos: Vector2 = game.player.position
	for i in range(12):
		var dir := Vector2.from_angle(TAU * float(i) / 12.0)
		game.spawn_player_bullet(pos + dir * 10.0, dir * 460.0, 14.0 * game.player.dmg_mult(), "bullet_base",
			{"r": 4.0, "life": 0.7, "pierce": 1, "proc_depth": 1, "tint": Color(0.9, 1.0, 0.7)})
	game.fx.add("ring", pos, {"life": 0.3, "scale": 2.4, "grow": 0.8, "tint": Color(0.85, 1.0, 0.6, 0.8)})

# ------------------------------------------------------------------ Zeichnung
func _draw() -> void:
	if game == null or game.player == null or not game.player.alive:
		return
	if has("m_pollen_storm"):
		var c := storm_center()
		for k in range(14):
			var a := _t * 7.0 + float(k) * 0.45
			var d := STORM_RADIUS * (0.2 + 0.8 * fposmod(float(k) * 0.37 + _t * 0.6, 1.0))
			draw_rect(Rect2((c + Vector2.from_angle(a) * d).floor(), Vector2(2, 2)), Color(1.0, 0.88, 0.4, 0.75))
		draw_arc(c, STORM_RADIUS, _t * 4.0, _t * 4.0 + PI * 1.3, 18, Color(1.0, 0.82, 0.35, 0.45), 2.0)
		draw_arc(c, STORM_RADIUS * 0.6, -_t * 5.0, -_t * 5.0 + PI, 12, Color(1.0, 0.95, 0.6, 0.4), 2.0)
	if has("m_echo_shield"):
		var pos: Vector2 = game.player.position
		if echo_t > 0.0:
			var pulse := 0.55 + 0.25 * sin(_t * 14.0)
			draw_arc(pos, ECHO_RADIUS, 0.0, TAU, 36, Color(0.7, 1.0, 1.0, pulse), 2.0)
			draw_arc(pos, ECHO_RADIUS - 5.0, 0.0, TAU, 32, Color(0.7, 1.0, 1.0, pulse * 0.4), 1.0)
		elif echo_charge > 0.05:
			draw_arc(pos, ECHO_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * echo_charge, 32, Color(0.7, 1.0, 1.0, 0.35), 1.5)
	if has("m_shield_wall"):
		var count: int = game.player.companion_count()
		for i in range(count):
			var p := wall_position(i, count)
			var col := Color(0.6, 0.95, 1.0, 0.5) if wall_active(i) else Color(0.6, 0.7, 0.8, 0.18)
			draw_arc(p, WALL_RADIUS, 0.0, TAU, 14, col, 1.5)
	if has("m_death_mark"):
		for e in game.enemies:
			if is_instance_valid(e) and not e.dead and mark_mult(e) > 1.0:
				_draw_mark(e.position, e.radius + 6.0)
		if game.boss != null and is_instance_valid(game.boss) and mark_mult(game.boss) > 1.0:
			_draw_mark(game.boss.position, 40.0)

func _draw_mark(p: Vector2, r: float) -> void:
	var col := Color(1.0, 0.25, 0.3, 0.75 + 0.25 * sin(_t * 10.0))
	draw_arc(p, r, 0.0, TAU, 20, col, 1.5)
	for k in range(4):
		var d := Vector2.from_angle(PI * 0.5 * float(k))
		draw_line(p + d * (r - 4.0), p + d * (r + 5.0), col, 2.0)
