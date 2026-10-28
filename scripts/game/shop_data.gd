class_name ShopData
extends RefCounted
## Kaufbare Werkstatt-Upgrades: drei Stufen je Eintrag, mit Vorbedingungen.
##
## Aufbau je Eintrag:
##   id     Kennung (auch Schlüssel im Spielstand)
##   cat    Gruppe für die Übersicht (shot, impact, tempo, defense, econ)
##   name   Anzeigename
##   req    Vorbedingung: [[id, Stufe], ...] – leer heißt sofort verfügbar
##   costs  Preis der Stufen 1..3 in Punkten
##   steps  je Stufe: Beschreibung + Werte (mod)
##
## Die Werte in "mod" werden im Spiel addiert. Absolute Angaben wie Radius
## stehen deshalb nur in dem einen Eintrag, der sie setzt.

const CATEGORIES := [
	{"id": "shot", "name": "Schussform"},
	{"id": "impact", "name": "Wirkung"},
	{"id": "tempo", "name": "Tempo"},
	{"id": "defense", "name": "Schutz"},
	{"id": "econ", "name": "Ausbeute"},
]

## Formen sind kombinierbar: Welle moduliert die Bahn, Zielsuche ihre Richtung,
## Kreisflug bindet sie an die Biene. Gruppen-API bleibt für ältere Aufrufer erhalten.
const GROUPS := {}

const ITEMS := [
	# ------------------------------------------------------------- Schussform
	{
		"id": "orbit", "cat": "shot", "name": "Kreisflug", "max": 3,
		"costs": [5500, 12000, 22000], "req": [],
		"steps": [
			{"desc": "Deine Schüsse kreisen mit 110 Punkten Radius um die Biene und erreichen schon auf Stufe 1 entfernte Ziele.",
			 "mod": {"orbit": 1.0, "orbit_r": 110.0, "orbit_w": 2.4}},
			{"desc": "Weiter Kreis: 142 Punkte Radius decken deutlich mehr Höhe und Entfernung ab.",
			 "mod": {"orbit": 1.0, "orbit_r": 142.0, "orbit_w": 2.4}},
			{"desc": "166 Punkte Radius und schnellerer Kreis: größere Reichweite und häufigere Treffer.",
			 "mod": {"orbit": 1.0, "orbit_r": 166.0, "orbit_w": 3.6}},
		],
	},
	{
		"id": "wave", "cat": "shot", "name": "Wellenschuss", "max": 3,
		"costs": [5500, 12000, 22000], "req": [],
		"steps": [
			{"desc": "Schüsse laufen in einer Wellenlinie nach vorn und treffen so auch Ziele über und unter der Flugbahn.",
			 "mod": {"wave": 1.0, "wave_amp": 22.0, "wave_len": 300.0}},
			{"desc": "Weitere Wellen: die Auslenkung wächst, die Schüsse decken mehr Höhe ab.",
			 "mod": {"wave": 1.0, "wave_amp": 32.0, "wave_len": 330.0}},
			{"desc": "Breite Wellen: 44 Punkte Auslenkung je Seite, im Kreisflug ein pulsierender Radius.",
			 "mod": {"wave": 1.0, "wave_amp": 44.0, "wave_len": 360.0}},
		],
	},
	{
		"id": "wave_freq", "cat": "shot", "name": "Schnelle Wellen", "max": 3,
		"costs": [3500, 8000, 15000], "req": [["wave", 1]],
		"steps": [
			{"desc": "Die Wellen laufen 30 % schneller – dichter beieinander, schwerer zu umfliegen.",
			 "mod": {"wave_speed": 0.3}},
			{"desc": "60 % schneller: die Wellenfolge wird eng.",
			 "mod": {"wave_speed": 0.6}},
			{"desc": "Doppelt so schnell: ein dichtes Wellenband vor der Biene.",
			 "mod": {"wave_speed": 1.0}},
		],
	},
	{
		"id": "wave_amp", "cat": "shot", "name": "Weite Wellen", "max": 3,
		"costs": [3500, 8000, 15000], "req": [["wave", 1]],
		"steps": [
			{"desc": "Größere Auslenkung und 6 % mehr Schaden je Schuss.",
			 "mod": {"wave_amp_add": 10.0, "dmg": 0.06}},
			{"desc": "Noch weitere Ausschläge, 12 % mehr Schaden.",
			 "mod": {"wave_amp_add": 18.0, "dmg": 0.12}},
			{"desc": "+28 Punkte zusätzliche Auslenkung und 20 % mehr Schaden.",
			 "mod": {"wave_amp_add": 28.0, "dmg": 0.2}},
		],
	},
	{
		"id": "back", "cat": "shot", "name": "Heckstachel", "max": 3,
		"costs": [4000, 9000, 17000], "req": [],
		"steps": [
			{"desc": "Zusätzlich ein Schuss nach hinten – gegen Verfolger im Rücken.",
			 "mod": {"back_n": 1.0}},
			{"desc": "Zwei Schüsse nach hinten, leicht gefächert.",
			 "mod": {"back_n": 2.0}},
			{"desc": "Die Heckschüsse schlagen deutlich härter ein.",
			 "mod": {"back_n": 2.0, "back_dmg": 0.8}},
		],
	},
	{
		"id": "side", "cat": "shot", "name": "Seitenstachel", "max": 3,
		"costs": [4000, 9000, 17000], "req": [],
		"steps": [
			{"desc": "Je ein Schuss nach oben und unten – deckt Gegner ab, die seitlich vorbeiziehen.",
			 "mod": {"side_n": 1.0}},
			{"desc": "Die Seitenstacheln werden kräftiger.",
			 "mod": {"side_n": 1.0, "side_dmg": 0.45}},
			{"desc": "Seitenstacheln mit voller Wucht.",
			 "mod": {"side_n": 1.0, "side_dmg": 1.0}},
		],
	},
	{
		"id": "multishot", "cat": "shot", "name": "Doppelläufe", "max": 3,
		"costs": [5000, 11000, 20000], "req": [],
		"steps": [
			{"desc": "Ein zusätzlicher Lauf versetzt zur Hauptwaffe.",
			 "mod": {"lanes_add": 1.0}},
			{"desc": "Der Nebenlauf legt an Wucht zu.",
			 "mod": {"lanes_add": 1.0, "lane_dmg": 0.6}},
			{"desc": "Der Nebenlauf schießt mit fast voller Wucht.",
			 "mod": {"lanes_add": 1.0, "lane_dmg": 1.4}},
		],
	},
	{
		"id": "spiral", "cat": "shot", "name": "Spiralschuss", "max": 3,
		"costs": [4500, 9500, 18000], "req": [],
		"steps": [
			{"desc": "Jede dritte Salve ergänzt ein Geschoss der Hauptwaffe mit weitergedrehtem Winkel; auch mit Kreisflug, Welle und Zielsuche.",
			 "mod": {"spiral": 0.22}},
			{"desc": "Größerer Drehschritt verteilt die einzelnen Spiralkugeln weiter über den Kreis.",
			 "mod": {"spiral": 0.34}},
			{"desc": "Schnelldreher: die begrenzten Zusatzgeschosse verteilen sich rundum.",
			 "mod": {"spiral": 0.48}},
		],
	},
	{
		"id": "homing", "cat": "shot", "name": "Zielsuche", "max": 3,
		"costs": [6000, 13000, 24000], "req": [],
		"steps": [
			{"desc": "Schüsse drehen leicht zu nahen Gegnern ein, die ihre Bahn kreuzen.",
			 "mod": {"homing": 1.2}},
			{"desc": "Stärkere Zielsuche: Schüsse folgen auch ausweichenden Zielen ein Stück.",
			 "mod": {"homing": 1.8}},
			{"desc": "Deutliche Zielsuche: Schüsse biegen sicher auf nahe Ziele ein.",
			 "mod": {"homing": 2.5}},
		],
	},
	{
		"id": "homing_power", "cat": "shot", "name": "Starke Zielsuche", "max": 3,
		"costs": [3500, 8000, 15000], "req": [["homing", 1]],
		"steps": [
			{"desc": "Zusätzliche Lenkstärke +0,8; Schüsse drehen schneller zum Ziel ein.",
			 "mod": {"homing_add": 0.8}},
			{"desc": "Um 1,3 stärker – Schüsse halten engere Kurven.",
			 "mod": {"homing_add": 1.3}},
			{"desc": "Um 1,8 stärker: enge Kurven, aber weite Ziele bleiben außer Reichweite.",
			 "mod": {"homing_add": 1.8}},
		],
	},
	# --------------------------------------------------------------- Wirkung
	{
		"id": "pierce", "cat": "impact", "name": "Durchschlag", "max": 3,
		"costs": [3000, 7000, 13000], "req": [],
		"steps": [
			{"desc": "Jeder Schuss durchschlägt ein zusätzliches Ziel.",
			 "mod": {"pierce_add": 1.0}},
			{"desc": "Zwei zusätzliche Ziele hintereinander.",
			 "mod": {"pierce_add": 2.0}},
			{"desc": "Drei zusätzliche Ziele – eine Reihe fällt in einem Schuss.",
			 "mod": {"pierce_add": 3.0}},
		],
	},
	{
		"id": "splash", "cat": "impact", "name": "Splitterwolke", "max": 3,
		"costs": [4000, 9000, 17000], "req": [],
		"steps": [
			{"desc": "Treffer erhalten +20 Punkte Flächenradius; addiert sich auch zur Plasmawirkung.",
			 "mod": {"splash": 20.0}},
			{"desc": "+32 Punkte Flächenradius, zusätzlich zum vorhandenen Waffenradius.",
			 "mod": {"splash": 32.0}},
			{"desc": "+46 Punkte Flächenradius, auch für Plasma- und Spiralkugeln.",
			 "mod": {"splash": 46.0}},
		],
	},
	{
		"id": "chain", "cat": "impact", "name": "Kettenblitz", "max": 3,
		"costs": [4500, 10000, 19000], "req": [],
		"steps": [
			{"desc": "Treffer springen auf einen Gegner in der Nähe über.",
			 "mod": {"chain": 1.0}},
			{"desc": "Zwei Sprünge weiter.",
			 "mod": {"chain": 2.0}},
			{"desc": "Drei Sprünge: ganze Gruppen leiden mit.",
			 "mod": {"chain": 3.0}},
		],
	},
	{
		"id": "big_bullet", "cat": "impact", "name": "Schwere Geschosse", "max": 3,
		"costs": [4500, 10000, 19000], "req": [],
		"steps": [
			{"desc": "Geschosse werden größer und richten 8 % mehr Schaden an.",
			 "mod": {"big": 1.2, "dmg": 0.08}},
			{"desc": "Deutlich größere Trefferfläche, 18 % mehr Schaden.",
			 "mod": {"big": 1.45, "dmg": 0.18}},
			{"desc": "Wuchtgeschosse mit 70 % mehr Größe und 30 % mehr Schaden.",
			 "mod": {"big": 1.7, "dmg": 0.3}},
		],
	},
	{
		"id": "crit", "cat": "impact", "name": "Volltreffer", "max": 3,
		"costs": [3500, 8000, 15000], "req": [],
		"steps": [
			{"desc": "12 % Chance auf doppelten Schaden je Treffer.",
			 "mod": {"crit": 0.12}},
			{"desc": "20 % Chance auf doppelten Schaden.",
			 "mod": {"crit": 0.2}},
			{"desc": "30 % Chance auf doppelten Schaden.",
			 "mod": {"crit": 0.3}},
		],
	},
	{
		"id": "boss_bane", "cat": "impact", "name": "Panzerbrecher", "max": 3,
		"costs": [4000, 9000, 17000], "req": [["big_bullet", 1]],
		"steps": [
			{"desc": "15 % mehr Schaden gegen Bosse und Minibosse.",
			 "mod": {"boss_dmg": 0.15}},
			{"desc": "30 % mehr Schaden gegen Bosse.",
			 "mod": {"boss_dmg": 0.3}},
			{"desc": "50 % mehr Schaden gegen Bosse – Panzerung zählt weniger.",
			 "mod": {"boss_dmg": 0.5}},
		],
	},
	# ------------------------------------------------------------------ Tempo
	{
		"id": "fire_rate", "cat": "tempo", "name": "Schnellfeuer", "max": 3,
		"costs": [3500, 8000, 15000], "req": [],
		"steps": [
			{"desc": "+15 % Feuertakt. Überschuss am Taktlimit wird in Schusswucht umgewandelt.",
			 "mod": {"fire_rate": 0.15}},
			{"desc": "+30 % Feuertakt; oberhalb des Limits mehr Wucht statt Kugelflut.",
			 "mod": {"fire_rate": 0.3}},
			{"desc": "+45 % Feuertakt-Budget. Am Limit steigt der Schaden weiter, nicht die Kugelzahl.",
			 "mod": {"fire_rate": 0.45}},
		],
	},
	{
		"id": "bullet_speed", "cat": "tempo", "name": "Hochgeschwindigkeit", "max": 3,
		"costs": [3000, 6500, 12000], "req": [],
		"steps": [
			{"desc": "Geschosse fliegen 20 % schneller.",
			 "mod": {"bullet_speed": 0.2}},
			{"desc": "35 % schneller – kürzere Vorhaltezeit.",
			 "mod": {"bullet_speed": 0.35}},
			{"desc": "50 % schneller: fast ohne Vorhalten.",
			 "mod": {"bullet_speed": 0.5}},
		],
	},
	{
		"id": "burst", "cat": "tempo", "name": "Salve", "max": 3,
		"costs": [4000, 9000, 17000], "req": [],
		"steps": [
			{"desc": "Jeder sechste Schuss ist eine dreifache Salve.",
			 "mod": {"burst": 6.0}},
			{"desc": "Jeder fünfte Schuss eine Salve.",
			 "mod": {"burst": 5.0}},
			{"desc": "Jeder vierte Schuss eine Salve.",
			 "mod": {"burst": 4.0}},
		],
	},
	{
		"id": "splinter", "cat": "impact", "name": "Splitterkern", "max": 3,
		"costs": [4000, 9000, 17000], "req": [],
		"steps": [
			{"desc": "Jeder fünfte Treffer platzt in einen kleinen Splitter, der weiterfliegt.",
			 "mod": {"splinter_chance": 0.2}},
			{"desc": "Jeder dritte Treffer setzt einen Splitter frei.",
			 "mod": {"splinter_chance": 0.33}},
			{"desc": "Jeder zweite Treffer splittert.",
			 "mod": {"splinter_chance": 0.5}},
		],
	},
	# ------------------------------------------------------------------ Schutz
	{
		"id": "shield_regen", "cat": "defense", "name": "Schildaufladung", "max": 3,
		"costs": [3500, 8000, 15000], "req": [],
		"steps": [
			{"desc": "Der Schild lädt 50 % schneller nach.",
			 "mod": {"shield_regen": 0.5}},
			{"desc": "Doppelt so schnell.",
			 "mod": {"shield_regen": 1.0}},
			{"desc": "Dreimal so schnell – der Schild ist fast immer bereit.",
			 "mod": {"shield_regen": 2.0}},
		],
	},
	{
		"id": "extra_shield", "cat": "defense", "name": "Schildstabilität", "max": 3,
		"costs": [4000, 9000, 17000], "req": [],
		"steps": [
			{"desc": "Nach jeder verlorenen Schildladung 0,25 s länger geschützt. Benötigt ein taktisch gekauftes Schild; keine zusätzliche Kapazität.",
			 "mod": {"shield_grace": 0.25}},
			{"desc": "0,5 s zusätzlicher Schutz nach jeder verlorenen Ladung des gekauften Schilds.",
			 "mod": {"shield_grace": 0.5}},
			{"desc": "0,85 s zusätzlicher Schutz nach jeder verlorenen Ladung. Die taktische Stufe bestimmt weiterhin allein die Kapazität.",
			 "mod": {"shield_grace": 0.85}},
		],
	},
	{
		"id": "extra_life", "cat": "defense", "name": "Zusätzliches Leben", "max": 3,
		"costs": [6000, 13000, 24000], "req": [],
		"steps": [
			{"desc": "Ein Lebenspunkt mehr, dauerhaft.",
			 "mod": {"max_hp_add": 1.0}},
			{"desc": "Zwei Lebenspunkte mehr.",
			 "mod": {"max_hp_add": 2.0}},
			{"desc": "Drei Lebenspunkte mehr.",
			 "mod": {"max_hp_add": 3.0}},
		],
	},
	{
		"id": "iframe_plus", "cat": "defense", "name": "Nachbrenner", "max": 3,
		"costs": [3000, 7000, 13000], "req": [],
		"steps": [
			{"desc": "Nach einem Treffer bist du 0,3 s länger unverwundbar.",
			 "mod": {"iframe_add": 0.3}},
			{"desc": "0,55 s länger.",
			 "mod": {"iframe_add": 0.55}},
			{"desc": "0,85 s länger – Zeit zum Neusortieren.",
			 "mod": {"iframe_add": 0.85}},
		],
	},
	{
		"id": "bomb_radius", "cat": "defense", "name": "Bombenradius", "max": 3,
		"costs": [3000, 6500, 12000], "req": [],
		"steps": [
			{"desc": "Bomben räumen mit 40 % größerem Radius.",
			 "mod": {"bomb_radius": 0.4}},
			{"desc": "70 % größerer Bombenradius.",
			 "mod": {"bomb_radius": 0.7}},
			{"desc": "Doppelter Bombenradius.",
			 "mod": {"bomb_radius": 1.0}},
		],
	},
	{
		"id": "bomb_charge", "cat": "defense", "name": "Bombenlager", "max": 3,
		"costs": [3500, 7500, 14000], "req": [],
		"steps": [
			{"desc": "Bomben laden 25 % schneller nach.",
			 "mod": {"bomb_rate": 0.25}},
			{"desc": "45 % schneller.",
			 "mod": {"bomb_rate": 0.45}},
			{"desc": "65 % schneller.",
			 "mod": {"bomb_rate": 0.65}},
		],
	},
	# ---------------------------------------------------------------- Ausbeute
	{
		"id": "magnet", "cat": "econ", "name": "Blütenstaub-Magnet", "max": 3,
		"costs": [2500, 5500, 10000], "req": [],
		"steps": [
			{"desc": "Blütenstaub wird aus 60 % größerer Nähe angezogen.",
			 "mod": {"magnet": 0.6}},
			{"desc": "120 % größerer Anziehradius.",
			 "mod": {"magnet": 1.2}},
			{"desc": "200 % größerer Radius – fast alles kommt von selbst.",
			 "mod": {"magnet": 2.0}},
		],
	},
	{
		"id": "nectar_plus", "cat": "econ", "name": "Reichere Beute", "max": 3,
		"costs": [3000, 6500, 12000], "req": [],
		"steps": [
			{"desc": "Jeder Gegner lässt einen Blütenstaub mehr fallen.",
			 "mod": {"nectar_plus": 1.0}},
			{"desc": "Zwei mehr je Gegner.",
			 "mod": {"nectar_plus": 2.0}},
			{"desc": "Drei mehr je Gegner.",
			 "mod": {"nectar_plus": 3.0}},
		],
	},
	{
		"id": "graze", "cat": "econ", "name": "Streiftreffer", "max": 3,
		"costs": [2500, 5500, 10000], "req": [],
		"steps": [
			{"desc": "Knapp verfehlte Gegnerschüsse geben 3 Punkte.",
			 "mod": {"graze": 3.0}},
			{"desc": "6 Punkte je Streiftreffer.",
			 "mod": {"graze": 6.0}},
			{"desc": "10 Punkte je Streiftreffer – Ausweichen zahlt sich aus.",
			 "mod": {"graze": 10.0}},
		],
	},
	{
		"id": "combo", "cat": "econ", "name": "Serie", "max": 3,
		"costs": [3500, 7500, 14000], "req": [],
		"steps": [
			{"desc": "Abschüsse geben 8 % mehr Punkte.",
			 "mod": {"combo": 0.08}},
			{"desc": "16 % mehr Punkte je Abschuss.",
			 "mod": {"combo": 0.16}},
			{"desc": "26 % mehr Punkte je Abschuss.",
			 "mod": {"combo": 0.26}},
		],
	},
	{
		"id": "convert_bonus", "cat": "econ", "name": "Bessere Umrechnung", "max": 3,
		"costs": [3000, 6500, 12000], "req": [],
		"steps": [
			{"desc": "Blütenstaub bringt am Levelende 25 % mehr Punkte.",
			 "mod": {"convert_bonus": 0.25}},
			{"desc": "50 % mehr Punkte aus Blütenstaub.",
			 "mod": {"convert_bonus": 0.5}},
			{"desc": "80 % mehr Punkte aus Blütenstaub.",
			 "mod": {"convert_bonus": 0.8}},
		],
	},
	{
		"id": "start_heal", "cat": "econ", "name": "Frischer Nektar", "max": 3,
		"costs": [2500, 5500, 10000], "req": [],
		"steps": [
			{"desc": "Jedes Level beginnt mit einem reparierten Leben.",
			 "mod": {"start_heal": 1.0}},
			{"desc": "Zwei Leben zu Beginn jedes Levels.",
			 "mod": {"start_heal": 2.0}},
			{"desc": "Drei Leben zu Beginn jedes Levels.",
			 "mod": {"start_heal": 3.0}},
		],
	},
]

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if String(it.id) == id:
			return it
	return {}

static func items_of(cat: String) -> Array:
	var out: Array = []
	for it in ITEMS:
		if String(it.get("cat", "")) == cat:
			out.append(it)
	return out

static func cost(id: String, level: int) -> int:
	var it := item(id)
	if it.is_empty():
		return 0
	var costs: Array = it.get("costs", [])
	if level < 0 or level >= costs.size():
		return 0
	return int(costs[level])

static func step(id: String, level: int) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return {}
	var steps: Array = it.get("steps", [])
	if level < 0 or level >= steps.size():
		return {}
	return steps[level]

static func total_cost() -> int:
	var sum := 0
	for it in ITEMS:
		for c in it.get("costs", []):
			sum += int(c)
	return sum

# ------------------------------------------------------------------ Gruppen
static func group_of(id: String) -> String:
	return String(item(id).get("group", ""))

static func group_members(group: String) -> Array:
	var out: Array = []
	if group == "":
		return out
	for it in ITEMS:
		if String(it.get("group", "")) == group:
			out.append(String(it.id))
	return out

## Welcher Eintrag sperrt diesen? Leer, wenn nichts sperrt.
## Gekauft ist gekauft: eine Stufe ≥ 1 in der eigenen Gruppe sperrt die anderen.
static func blocker_of(id: String, levels: Dictionary) -> String:
	var g := group_of(id)
	if g == "":
		return ""
	for other in group_members(g):
		if other == id:
			continue
		if int(levels.get(other, 0)) > 0:
			return String(other)
	return ""

## Einträge, die ein Kauf dieses Eintrags für den Lauf sperren würde.
static func locks_of(id: String, levels: Dictionary) -> Array:
	var g := group_of(id)
	var out: Array = []
	if g == "":
		return out
	if int(levels.get(id, 0)) <= 0:
		return out
	for other in group_members(g):
		if other != id and int(levels.get(other, 0)) <= 0:
			out.append(other)
	return out

## Namen der Einträge, die durch diesen Eintrag gesperrt würden (für Hinweise).
static func lock_names(ids: Array) -> String:
	var names: Array = []
	for id in ids:
		names.append(String(item(String(id)).get("name", id)))
	return _join_de(names)

## Einträge, die dieser Eintrag sperren würde, sobald man ihn kauft.
static func would_lock(id: String, levels: Dictionary) -> Array:
	var g := group_of(id)
	var out: Array = []
	if g == "":
		return out
	for other in group_members(g):
		if other != id and int(levels.get(other, 0)) <= 0:
			out.append(other)
	return out

static func group_note(id: String) -> String:
	var g := group_of(id)
	if g == "":
		return ""
	return String((GROUPS.get(g, {}) as Dictionary).get("note", ""))

static func group_name(id: String) -> String:
	var g := group_of(id)
	if g == "":
		return ""
	return String((GROUPS.get(g, {}) as Dictionary).get("name", g))

static func _join_de(items: Array) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return String(items[0])
	if items.size() == 2:
		return "%s und %s" % [String(items[0]), String(items[1])]
	var head := ""
	for i in range(items.size() - 1):
		head += String(items[i]) + ", "
	return head + "und " + String(items[items.size() - 1])
