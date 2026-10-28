class_name Tutorial
extends Node
## Übungsflug in der ersten Welt: ein kurzes, geskriptetes Level. Bei jedem
## erklärungswürdigen Moment hält das Spiel an und ein kleines Fenster erklärt
## in Bildern, was passiert (App.show_tutorial_tip). Danach geht es weiter, bis
## die Bedingung des Schritts erfüllt ist.
##
## Ablauf: Fliegen → Schießen → Blütenstaub → Waffenleiste (LB/RB, Kosten) →
## Kauf und Stufen → Gegenfeuer → Schild und Bombe → Levelende (Umrechnung,
## Werkstatt, Highscore) – die letzten Erklärungen zeigt die App nach dem Level.

const TIPS := {
	"welcome": {"title": "Willkommen, Yuri!",
		"text": "Das hier ist dein Übungsflug über das Blütenmeer. Steuere die Biene mit den Pfeiltasten oder WASD – am Controller mit dem linken Stick. Flieg ein paar Runden wie ein Bienchen im Frühlingswind!",
		"visual": [{"sprite": "bee"}, {"text": "←  ↑  ↓  →"}, {"action": "move_up"}]},
	"shoot": {"title": "Stacheln los!",
		"text": "Da summen Blattläuse heran. Halte die Feuertaste gedrückt: Deine Stacheln fliegen wie goldener Regen nach vorn. Mit R schaltest du Autofeuer ein, dann musst du nicht mehr halten.",
		"visual": [{"action": "fire"}, {"text": "→"}, {"sprite": "bullet_base", "scale": 3.0}, {"text": "→"}, {"sprite": "aphid"}]},
	"nectar": {"title": "Blütenstaub sammeln",
		"text": "Jeder besiegte Gegner verliert Blütenstaub – kleine goldene Tropfen. Flieg einfach hindurch, um sie einzusammeln. Oben im Kopfbalken siehst du deinen Vorrat: Blütenstaub ist dein Taschengeld für diesen Flug.",
		"visual": [{"sprite": "aphid"}, {"text": "→"}, {"sprite": "nectar", "scale": 3.0}, {"text": "→"}, {"icon": "icon_nectar", "scale": 2.5}]},
	"bar": {"title": "Deine Waffenleiste",
		"text": "Unten liegt deine Waffenleiste – dein Werkzeuggürtel. Blättere mit LB/RB (Tastatur Q/E); eine Stimme sagt dir die Wahl an. Mit RT (Tastatur F) kaufst du. Jeder Kauf kostet Blütenstaub, der Preis steht unter dem Eintrag. Ich lege dir etwas dazu – kauf dir den Fächer!",
		"visual": [{"action": "upgrade_prev"}, {"icon": "icon_fan", "scale": 2.5}, {"action": "upgrade_next"}, {"text": "+"}, {"action": "upgrade_buy"}, {"text": "="}, {"icon": "icon_nectar", "scale": 2.0}, {"text": "−30", "color": Color("#ffd666")}]},
	"bought": {"title": "Gekauft!",
		"text": "Stark! Jede Waffe wächst in drei Stufen – kauf dieselbe noch einmal für die nächste. Aber merke dir: Was du in der Leiste kaufst, gilt nur bis zum Levelende. Danach beginnt sie wieder bei der Basis. Gib deinen Blütenstaub also ruhig aus!",
		"visual": [{"icon": "icon_fan", "scale": 2.5}, {"text": "Stufe 1 → 2 → 3"}]},
	"danger": {"title": "Achtung, Gegenfeuer!",
		"text": "Dieser Marienkäfer schießt zurück. Weiche den leuchtenden Kugeln aus – jeder Treffer kostet ein Herz (oben links). Sind alle Herzen weg, ist der Flug vorbei. Im Übungsflug fange ich dich noch auf.",
		"visual": [{"sprite": "ladybug"}, {"text": "→"}, {"sprite": "ebullet_orb", "scale": 3.0}, {"text": "→"}, {"icon": "icon_hp", "scale": 2.5}]},
	"defense": {"title": "Schild und Bombe",
		"text": "Zwei Helfer für brenzlige Lagen: Der Schild legt sich wie eine Wabe um dich und schluckt Treffer – verbrauchte Waben wachsen nach. Die Bombe musst du nicht zünden: Sie löst ganz von selbst alle paar Sekunden eine Druckwelle aus, die Geschosse um dich wegfegt. Probier beide aus!",
		"visual": [{"icon": "icon_shield", "scale": 2.0}, {"text": "+"}, {"icon": "icon_bombs", "scale": 2.0}]},
	"end": {"title": "Geschafft!",
		"text": "Am Ende jedes Levels wird übriger Blütenstaub eingeschmolzen: Jeder Tropfen wird zu 10 Punkten. Schau zu!",
		"visual": [{"icon": "icon_nectar", "scale": 2.5}, {"text": "×10  →"}, {"text": "Punkte", "color": Color("#ffd666")}]},
	"points": {"title": "Punkte und Highscore",
		"text": "Punkte sind dein Erspartes. Zwischen den Leveln kaufst du damit in der Werkstatt dauerhafte Verbesserungen. Aber Vorsicht: Jeder ausgegebene Punkt fehlt in deinem Highscore. Stärker werden oder höher punkten – du entscheidest.",
		"visual": [{"text": "Punkte"}, {"text": "→"}, {"text": "Werkstatt", "color": Color("#ffd666")}, {"text": "−  Highscore", "color": Color("#ff5c84")}]},
	"shop": {"title": "Die Werkstatt",
		"text": "Links wählst du eine Kategorie, in der Mitte erscheinen ihre Upgrades, rechts zeigt dir ein kleines Bild, was sie bewirken. Mit Bestätigen springst du in die Liste und kaufst. Weiter führt zurück ins Hauptmenü.",
		"visual": []},
	"evolution": {"title": "Evolutionen",
		"text": "Nach jedem Level wählst du außerdem eine Evolution – eine dauerhafte Weiterentwicklung deiner Biene. Passende Evolutionen verschmelzen und werden gemeinsam stärker. Entdeckte Verschmelzungen findest du im Hauptmenü. Viel Glück, Yuri!",
		"visual": [{"sprite": "bee", "scale": 2.5}]},
}

var game: Node
var app: Node
var step := ""
var _t := 0.0
var _moved := 0.0
var _last_pos := Vector2.ZERO
var _kills_at := 0
var _spawn_t := 0.0
var _done := false

func _init(g: Node) -> void:
	game = g
	app = g.app
	name = "Tutorial"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_last_pos = game.player.position
	step = "intro"

func _tip(id: String, then: String) -> void:
	step = "wait"
	if app == null:
		_enter(then)
		return
	app.show_tutorial_tip(TIPS[id], func(): _enter(then))

func _enter(s: String) -> void:
	step = s
	_t = 0.0
	_kills_at = int(game.stats.kills)
	_spawn_t = 0.0

func _physics_process(delta: float) -> void:
	if _done or game == null or game.player == null or game.is_play_frozen():
		return
	_t += delta
	var p = game.player
	# Im Übungsflug geht niemand verloren: kurz vor dem letzten Herz wird geheilt.
	if p.hp <= 1:
		p.hp = p.max_hp
	_moved += p.position.distance_to(_last_pos)
	_last_pos = p.position
	match step:
		"intro":
			if _t > 0.8:
				_tip("welcome", "move")
		"move":
			if _moved > 600.0 or _t > 12.0:
				_tip("shoot", "shoot")
				_spawn_aphids()
		"shoot":
			_spawn_t += delta
			if _alive() == 0 and _spawn_t > 2.0:
				_spawn_aphids()
			if not game.pickups.is_empty():
				_tip("nectar", "collect")
		"collect":
			if p.nectar >= 3 or _t > 8.0:
				p.nectar = maxi(p.nectar, 0) + 80
				_tip("bar", "buy")
		"buy":
			if int(p.upgrades.get("fan", 0)) > 0 or int(p.upgrades.get("lightning", 0)) > 0 \
					or int(p.upgrades.get("plasma", 0)) > 0 or int(p.upgrades.get("companion", 0)) > 0:
				_tip("bought", "try")
			elif _t > 25.0 and p.nectar < 30:
				p.nectar += 40
				_t = 0.0
		"try":
			_spawn_t += delta
			if _spawn_t > 1.8 and int(game.stats.kills) - _kills_at < 8:
				_spawn_t = 0.0
				game.director.spawn_formation("moth_line")
			if int(game.stats.kills) - _kills_at >= 8 or _t > 20.0:
				game.spawn_enemy("ladybug_turret", Vector2(1000, 230), {})
				_enter("danger_wait")
		"danger_wait":
			if not game.bullets.enemy_bullets.is_empty() or _t > 4.0:
				_tip("danger", "dodge")
		"dodge":
			if _t > 8.0 or _alive() == 0:
				p.nectar += 120
				_tip("defense", "defend")
		"defend":
			_spawn_t += delta
			if _spawn_t > 2.2:
				_spawn_t = 0.0
				game.director.spawn_formation("moth_arc")
			var has_def: bool = int(p.upgrades.get("shield", 0)) > 0 or int(p.upgrades.get("bombs", 0)) > 0
			if (has_def and _t > 10.0) or _t > 24.0:
				_enter("calm")
		"calm":
			if _alive() == 0 or _t > 6.0:
				_done = true
				app.show_tutorial_tip(TIPS["end"], func(): app.finish_tutorial_level())

func _alive() -> int:
	var n := 0
	for e in game.enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n

func _spawn_aphids() -> void:
	for i in range(4):
		game.spawn_enemy("aphid_swarm", Vector2(980 + i * 40, 180 + i * 50), {})
