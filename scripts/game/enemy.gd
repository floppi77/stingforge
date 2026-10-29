class_name Enemy
extends Node2D
## Ein Gegnertyp mit Verhalten, Angriffsmuster, Trefferreaktion und Zerstörung.

signal killed(enemy)

var id: String = "moth"
var def: Dictionary = {}
var hp: float = 10.0
var max_hp: float = 10.0
var radius: float = 9.0
var score: int = 0
var nectar_drop: int = 1
var behavior: String = "sine"
var speed: float = 120.0
var fire_interval: float = 2.0
var shots: String = ""
var age: float = 0.0
var fire_t: float = 0.0
var base_y: float = 0.0
var home_x: float = 0.0
var home_y: float = 0.0
var vx: float = -100.0
var vy: float = 0.0
var phase: float = 0.0
var telegraph: float = 0.0
var dead := false
var hit_flash: float = 0.0
var sprite: AnimatedSprite2D
var telegraph_line := false
var amplitude: float = 40.0
var frequency: float = 2.0
var opts: Dictionary = {}
var mirror := 1.0
var anchor_x: float = 0.0
var target_x: float = 0.0
var boss_hp_scale: float = 1.0
var fire_mult: float = 1.0
var bullet_speed_mult: float = 1.0
var tint := Color.WHITE
## Verfolger wählen nach der Warnphase genau eine Flugbahn; kein Umdrehen.
var approach_dir := Vector2.ZERO
## Springfisch: Wartezeit unter Wasser, Sprünge bisher, Spritzer im Scheitel schon abgegeben.
const FISH_GRAVITY := 560.0
## Blickrichtung des Barsch-Sprites (nach links oben), damit er der Flugbahn folgt.
const FISH_BASE_ANGLE := -2.72
var _fish_wait := 0.0
var _fish_jumps := 0
var _fish_spat := false
var body_half_height := 0.0
## Zwischengegner verlassen das Feld nie: eigenes Patrouillenmuster statt des
## Flugmusters ihres Grundtyps, bis sie besiegt sind.
var miniboss := false
const MINI_HOME_X := 760.0
const MINI_LUNGE_EVERY := 6.5

func setup(point_id: String, pos: Vector2, options: Dictionary = {}) -> void:
	id = point_id
	def = Data.enemy(id)
	opts = options
	behavior = String(def.behavior)
	radius = float(def.r)
	score = int(def.score)
	nectar_drop = int(def.nectar)
	speed = float(def.speed) * float(options.get("speed_mult", 1.0))
	fire_interval = float(def.fire)
	shots = String(def.shots)
	hp = float(def.hp) * float(options.get("hp_mult", 1.0)) * boss_hp_scale
	max_hp = hp
	position = pos
	base_y = pos.y
	home_x = pos.x
	home_y = pos.y
	anchor_x = pos.x
	mirror = float(options.get("mirror", 1.0))
	amplitude = float(options.get("amp", 42.0))
	target_x = float(options.get("target_x", 760.0 if behavior == "anchor" else 0.0))
	frequency = float(options.get("freq", 2.2))
	# Optionen gehören dem laufenden Game; Training/Rush besitzen ebenfalls
	# Kampagnen-Run-Daten, auch wenn active_campaign dort false ist.
	var diff: Dictionary = options.get("difficulty", {})
	if diff.is_empty():
		var d := String(Save.campaign.get("difficulty", Save.g("game.difficulty", "normal")))
		diff = Data.DIFFICULTY.get(d, Data.DIFFICULTY["normal"])
	fire_mult = float(diff.fire_mult) * clampf(float(options.get("fire_mult", 1.0)), 0.5, 1.75)
	bullet_speed_mult = float(diff.bullet_speed)
	_build_sprite()
	body_half_height = maxf(radius, float(Art.info(String(def.sprite)).get("h", 16)) * 0.5)
	_clamp_playfield()
	base_y = position.y
	home_y = position.y
	fire_t = fire_interval * randf_range(0.4, 1.0)
	if behavior == "fish_leap":
		_fish_wait = float(options.get("delay", 0.3))
		sprite.visible = false

func _build_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.sprite_frames(String(def.sprite))
	sprite.play("default")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 3
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if dead:
		return
	var game := get_parent()
	if game != null and game.has_method("is_play_frozen") and game.is_play_frozen():
		return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	sprite.modulate = Color(2.2, 2.2, 2.2) if hit_flash > 0.0 else tint
	# Jedes Muster setzt seine Position selbst; kein zweites vx-Update hier.
	_move(delta)
	_clamp_playfield()
	if position.x < -90.0 or position.y < -120.0 or position.y > 660.0:
		queue_free()
		return
	_update_fire(delta)
	if telegraph > 0.0:
		telegraph -= delta
		sprite.modulate = Color(1.6, 0.7, 0.7)
	queue_redraw()

func _draw() -> void:
	if behavior == "descend" and not dead:
		# Spinnfaden bis zum oberen Bildrand.
		draw_line(Vector2(0, -position.y), Vector2(0, -10), Color(0.92, 0.92, 1.0, 0.65), 1.0, false)
	elif behavior == "from_behind" and age < 0.9 and not dead:
		# Warnung am linken Rand: pulsierende Pfeilspitze auf Flughöhe.
		var a := 0.5 + 0.5 * sin(age * 18.0)
		var x := 70.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -8), Vector2(x + 12, 0), Vector2(x, 8)]),
			Color(1.0, 0.55, 0.25, 0.9 * a))

func _move(delta: float) -> void:
	var p := _player_pos()
	if miniboss:
		_move_miniboss(delta, p)
		return
	match behavior:
		"from_behind":
			# Warnung am linken Rand, dann überholt sie, schwebt kurz, dreht nach oben ab.
			if age < 0.9:
				position.x = -60.0
			elif age < 2.4:
				var tx := float(opts.get("target_x", 480.0))
				position.x = move_toward(position.x, tx, speed * delta)
				position.y = base_y + sin(age * 3.0) * 18.0
				sprite.flip_h = position.x < tx - 4.0
			elif age < 4.6:
				sprite.flip_h = false
				position.y = base_y + sin(age * 3.0) * 18.0
			else:
				position.y -= speed * 0.9 * delta
				position.x -= 40.0 * delta
		"descend":
			# Seilt sich am Faden ab, pendelt, feuert, klettert wieder hoch.
			var hang := float(opts.get("hang_y", 200.0))
			if age < 1.3:
				position.y = lerpf(-30.0, hang, smoothstep(0.0, 1.3, age))
			elif age < 5.2:
				position.y = hang + sin(age * 1.6) * 8.0
			else:
				position.y -= 120.0 * delta
			position.x = home_x - age * 18.0 + sin(age * 1.2) * 10.0
		"ground_walk":
			# Läuft am Boden entlang; bleibt zum Schießen kurz stehen.
			var walking := fmod(age, 3.0) < 2.3
			if walking:
				position.x -= speed * delta
			position.y = App.PLAY_BOTTOM - body_half_height + (1.0 if walking and int(age * 8.0) % 2 == 0 else 0.0)
		"pop_up":
			# Bricht aus dem Boden, schleudert Sporen, taucht wieder ab.
			var ground := App.PLAY_BOTTOM - body_half_height
			if age < 0.45:
				position.y = lerpf(App.PLAY_BOTTOM + 30.0, ground, smoothstep(0.0, 0.45, age))
			elif age < 3.0:
				position.y = ground
			else:
				position.y += 120.0 * delta
				if position.y > App.PLAY_BOTTOM + 40.0:
					queue_free()
		"sine":
			vx = -speed
			position.y = base_y + sin(age * frequency) * amplitude
			position.x += vx * delta
		"straight":
			vx = -speed
			position.x += vx * delta
		"dive":
			_move_approach(delta, p, 0.35, 160.0)
		"wobble":
			vx = -speed
			position.x += vx * delta
			position.y = base_y + sin(age * 6.0 + mirror) * 14.0
		"drift":
			vx = -speed
			position.x += vx * delta
			position.y = base_y + sin(age * 0.9) * 30.0
		"hover":
			var tx := target_x if target_x > 0.0 else 760.0
			position.x = move_toward(position.x, tx, speed * delta)
			position.y = home_y + sin(age * 1.6) * 34.0
		"emerge":
			if age < 0.8:
				position.y -= 160.0 * delta
			else:
				position.x -= speed * delta
			position.y = clampf(position.y, 24.0, App.PLAY_BOTTOM - 16.0)
		"crawl":
			vx = -speed
			position.x += vx * delta
			position.y = base_y + sin(age * 2.4) * 12.0
		"dash":
			if age < 0.6:
				position.x -= 40.0 * delta
			elif age < 1.5:
				telegraph = 0.4
				position.x -= 20.0 * delta
			else:
				position.x -= speed * delta
				position.y = lerpf(position.y, p.y, clampf(delta * 2.2, 0.0, 1.0))
		"mirror":
			vx = -speed
			position.x += vx * delta
			position.y = base_y + sin(age * 2.6 + (0.0 if mirror > 0 else PI)) * 52.0 * mirror
		"leap":
			var cycle := fmod(age, 2.0)
			position.x -= speed * 0.35 * delta
			if cycle < 1.4:
				position.y = base_y - sin(cycle / 1.4 * PI) * 150.0
			else:
				position.y = base_y
		"rush":
			position.x -= speed * delta
			position.y = base_y + sin(age * 8.0) * 3.0
		"fish_leap":
			_fish_leap(delta, p)
		"sweep":
			vx = -speed * 0.55
			position.x += vx * delta
			position.y = base_y + sin(age * 2.2) * 90.0
		"track":
			position.x -= speed * delta
			position.y = lerpf(position.y, p.y, clampf(delta * 1.4, 0.0, 1.0))
		"orbit":
			var c := Vector2(home_x - 60.0 * age, home_y)
			position = c + Vector2(cos(age * 1.8) * 46.0, sin(age * 1.8) * 46.0)
			position.x -= speed * 0.2 * delta
		"charge":
			_move_approach(delta, p, 1.0, 145.0)
		"anchor":
			# Generator-Daten haben speed0: trotzdem erst sichtbar einfliegen,
			# anschließend an der gewählten Bahn verankern.
			position.x = move_toward(position.x, target_x, 95.0 * delta)
			position.y = home_y + sin(age * 1.2) * 8.0
		_:
			position.x -= speed * delta

## Einfliegen, dann rechts patrouillieren und der Biene in der Höhe folgen; in
## festen Abständen ein angekündigter Vorstoß nach links und wieder zurück.
func _move_miniboss(delta: float, p: Vector2) -> void:
	if age < 2.2 and position.x > MINI_HOME_X + 4.0:
		position.x = move_toward(position.x, MINI_HOME_X, 140.0 * delta)
		return
	var cycle := fmod(age, MINI_LUNGE_EVERY)
	var home := MINI_HOME_X + sin(age * 0.7) * 80.0
	var tx := home
	if cycle > MINI_LUNGE_EVERY - 1.6:
		var k := (cycle - (MINI_LUNGE_EVERY - 1.6)) / 1.6
		if k < 0.35:
			telegraph = 0.2
		tx = lerpf(home, 560.0, sin(clampf((k - 0.35) / 0.65, 0.0, 1.0) * PI))
	position.x = move_toward(position.x, tx, 220.0 * delta)
	var ty := lerpf(home_y + sin(age * 1.3) * 90.0, p.y, 0.45)
	position.y = move_toward(position.y, ty, 70.0 * delta)

## Springfisch: wartet unter Wasser, springt im Bogen Richtung Biene, spritzt im
## Scheitel einen Tropfenfächer und taucht ein; bis zu drei Sprünge hintereinander.
func _fish_leap(delta: float, p: Vector2) -> void:
	if _fish_wait > 0.0:
		_fish_wait -= delta
		position.y = App.PLAY_BOTTOM + 30.0
		if _fish_wait > 0.0:
			return
		var v := sqrt(2.0 * FISH_GRAVITY * randf_range(170.0, 250.0))
		var flight := 2.0 * v / FISH_GRAVITY
		vx = clampf((p.x - position.x) / flight, -260.0, -50.0)
		vy = -v
		position.y = App.PLAY_BOTTOM + 4.0
		sprite.visible = true
		_fish_spat = false
		_fish_splash()
	vy += FISH_GRAVITY * delta
	position += Vector2(vx, vy) * delta
	sprite.rotation = Vector2(vx, vy).angle() - FISH_BASE_ANGLE
	if not _fish_spat and vy >= 0.0:
		_fish_spat = true
		var g := get_parent()
		if g != null and g.has_method("spawn_enemy_bullet"):
			var aim := (p - position).normalized()
			for a in [-0.28, 0.0, 0.28]:
				g.spawn_enemy_bullet(position, aim.rotated(a) * 170.0 * bullet_speed_mult, 1, "ebullet_orb", {"scale": 0.8})
	if vy > 0.0 and position.y > App.PLAY_BOTTOM + 6.0:
		_fish_splash()
		_fish_jumps += 1
		sprite.visible = false
		if _fish_jumps >= 3:
			queue_free()
			return
		_fish_wait = 0.55

func _fish_splash() -> void:
	var g := get_parent()
	if g != null and "fx" in g and g.fx != null and g.fx.has_method("water_splash"):
		g.fx.water_splash(Vector2(position.x, App.PLAY_BOTTOM - 2.0), 1.0)

func _clamp_playfield() -> void:
	# Abseil-, Auftauch-, Sprung- und Abflugbewegungen führen bewusst über den Feldrand.
	if behavior in ["descend", "pop_up", "fish_leap"] or (behavior == "from_behind" and age > 4.6):
		return
	position.y = clampf(position.y, App.PLAY_TOP + body_half_height + 2.0,
		App.PLAY_BOTTOM - body_half_height - 2.0)

func _move_approach(delta: float, player_pos: Vector2, warning: float, cap: float) -> void:
	vx = 0.0
	if age < warning:
		position.x -= minf(50.0, speed * 0.25) * delta
		if behavior == "charge":
			telegraph = minf(0.25, warning - age)
		return
	if approach_dir == Vector2.ZERO:
		var aim := (player_pos - position).normalized()
		# Vorwärtsanteil bleibt negativ, auch wenn die Biene vorbeigeflogen ist.
		approach_dir = Vector2(-maxf(absf(aim.x), 0.8), clampf(aim.y, -0.6, 0.6)).normalized()
	position += approach_dir * minf(speed * 0.6, cap) * delta

func _player_pos() -> Vector2:
	var g := get_parent()
	if g != null and g.has_method("player_position"):
		return g.player_position()
	return Vector2(120, 270)

func _update_fire(delta: float) -> void:
	if shots == "" or fire_interval <= 0.0:
		return
	fire_t -= delta * fire_mult
	if fire_t > 0.0:
		return
	fire_t = fire_interval
	_shoot()

func _shoot() -> void:
	var g := get_parent()
	if g == null or not g.has_method("spawn_enemy_bullet"):
		return
	var p := _player_pos()
	var aim := (p - position).normalized()
	var spd := 210.0 * bullet_speed_mult
	match shots:
		"aimed1":
			g.spawn_enemy_bullet(position, aim * spd, 1, "ebullet_orb")
		"aimed2":
			for a in [-0.16, 0.16]:
				g.spawn_enemy_bullet(position, aim.rotated(a) * spd, 1, "ebullet_needle")
		"aimed3":
			for a in [-0.26, 0.0, 0.26]:
				g.spawn_enemy_bullet(position, aim.rotated(a) * spd, 1, "ebullet_orb")
		"forward":
			g.spawn_enemy_bullet(position + Vector2(-12, 0), Vector2(-spd, 0), 1, "ebullet_needle")
		"forward2":
			for o in [-8.0, 8.0]:
				g.spawn_enemy_bullet(position + Vector2(-12, o), Vector2(-spd, 0), 1, "ebullet_needle")
		"ring3":
			for i in range(3):
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(PI + (i - 1) * 0.5) * spd * 0.9, 1, "ebullet_orb")
		"ring4":
			for i in range(4):
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(PI * 0.25 + i * PI * 0.5) * spd * 0.85, 1, "ebullet_orb")
		"ring6":
			for i in range(6):
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(i * TAU / 6.0) * spd * 0.8, 1, "ebullet_orb")
		"spiral":
			phase += 0.6
			g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(phase) * spd, 1, "ebullet_orb")
			g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(phase + PI) * spd, 1, "ebullet_orb")
		"spore":
			g.spawn_enemy_bullet(position, aim * spd * 0.55, 1, "ebullet_spore", {"r": 6.0})
		"web":
			# Netzklumpen: langsam, leicht gestreut.
			for a in [-0.12, 0.12]:
				g.spawn_enemy_bullet(position + Vector2(0, 10), aim.rotated(a) * spd * 0.6, 1, "ebullet_spore", {"r": 6.0})
		"mortar":
			# Kanone auf dem Rücken: Fächer schräg nach oben in Richtung Biene.
			var up := (p - position).normalized()
			up.y = minf(up.y, -0.35)
			up = up.normalized()
			for a in [-0.2, 0.0, 0.2]:
				g.spawn_enemy_bullet(position + Vector2(-6, -12), up.rotated(a) * spd * 0.85, 1, "ebullet_orb")
		"spore_lob":
			if position.y < App.PLAY_BOTTOM:
				for a in [-0.35, 0.0, 0.35]:
					g.spawn_enemy_bullet(position + Vector2(0, -12), aim.rotated(a) * spd * 0.6, 1, "ebullet_spore", {"r": 6.0})
		"up3":
			for a in [-0.3, 0.0, 0.3]:
				g.spawn_enemy_bullet(position, Vector2.UP.rotated(a) * spd, 1, "ebullet_needle")
		"down3":
			for a in [-0.3, 0.0, 0.3]:
				g.spawn_enemy_bullet(position, Vector2.DOWN.rotated(a) * spd, 1, "ebullet_needle")
		"laserline":
			telegraph = 0.55
			# Pausierbarer Timer: Ein Laser darf nicht hinter dem Pausebildschirm feuern.
			await get_tree().create_timer(0.55, false).timeout
			if not is_inside_tree() or dead:
				return
			g.spawn_enemy_bullet(position, Vector2.LEFT * 520.0 * bullet_speed_mult, 1, "ebullet_laser", {"r": 7.0, "life": 1.4})
		"radial":
			for i in range(8):
				g.spawn_enemy_bullet(position, Vector2.RIGHT.rotated(i * TAU / 8.0 + age) * spd * 0.8, 1, "ebullet_orb")
		"bounce":
			var v := aim * spd
			g.spawn_enemy_bullet(position, v, 1, "ebullet_orb")
		"reflect":
			g.spawn_enemy_bullet(position, Vector2.LEFT * spd * 1.2, 1, "ebullet_laser", {"r": 6.0})
	audio_fire()

func audio_fire() -> void:
	pass

func take_damage(amount: float, _src: Vector2 = Vector2.ZERO) -> bool:
	if dead:
		return false
	hp -= amount
	hit_flash = 0.08
	if hp <= 0.0:
		_die()
		return true
	return false

func _die() -> void:
	if dead:
		return
	dead = true
	Audio.sfx_var("explosion_small", -10.0)
	killed.emit(self)
	queue_free()
