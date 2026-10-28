extends Node
## Zentrale Designdatenbank. Alle Waffen, Evolutionen, Gegner, Bosse und Level
## werden hier als strukturierte Daten gepflegt, damit Spiellogik und Inhalte
## getrennt bleiben.

# ---------------------------------------------------------------- Schwierigkeit
const DIFFICULTY := {
	"relaxed": {
		"name": "diff.relaxed", "hp": 4, "dmg_mult": 0.8, "fire_mult": 0.75,
		"bullet_speed": 0.85, "spawn_mult": 0.8, "iframes": 1.9, "score_mult": 0.7,
		"shield_hits": 3, "boss_hp": 0.8,
	},
	"normal": {
		"name": "diff.normal", "hp": 3, "dmg_mult": 1.0, "fire_mult": 1.0,
		"bullet_speed": 1.0, "spawn_mult": 1.0, "iframes": 1.3, "score_mult": 1.0,
		"shield_hits": 2, "boss_hp": 1.0,
	},
	"expert": {
		"name": "diff.expert", "hp": 3, "dmg_mult": 1.35, "fire_mult": 1.35,
		"bullet_speed": 1.18, "spawn_mult": 1.25, "iframes": 0.95, "score_mult": 1.4,
		"shield_hits": 1, "boss_hp": 1.15,
	},
}

# ------------------------------------------------------------------ Waffenleiste
## Reihenfolge der taktischen Leiste. Kosten je Stufe, Maximalstufe, Effekt.
const UPGRADES := [
	{
		"id": "base", "name": "bar.base", "short": "Basis", "icon": "base", "kind": "weapon",
		"max": 1, "costs": [0], "desc": "Immer verfügbar. Zwei präzise Stachelschüsse.",
	},
	{
		"id": "fan", "name": "bar.fan", "short": "Fächer", "icon": "fan", "kind": "weapon",
		"max": 3, "costs": [30, 70, 130],
		"desc": "Breiter Fächer, mehr Trefferfläche, etwas weniger Schaden je Schuss.",
	},
	{
		"id": "lightning", "name": "bar.lightning", "short": "Blitz", "icon": "lightning", "kind": "weapon",
		"max": 3, "costs": [35, 80, 150],
		"desc": "Schnelle Blitzkugeln (Stufe 1/2/3: zwei, drei, vier), durchschlagen ein zusätzliches Ziel und springen über.",
	},
	{
		"id": "plasma", "name": "bar.plasma", "short": "Plasma", "icon": "plasma", "kind": "weapon",
		"max": 3, "costs": [40, 90, 160],
		"desc": "Langsame Plasmakugeln mit Flächenschaden, hoher Einzelschaden.",
	},
	{
		"id": "companion", "name": "bar.companion", "short": "Drohne", "icon": "companion", "kind": "support",
		"max": 3, "costs": [30, 75, 140],
		"desc": "Begleitdrohne feuert automatisch mit. Jede Stufe eine weitere Drohne.",
	},
	{
		"id": "bombs", "name": "bar.bombs", "short": "Bombe", "icon": "bombs", "kind": "support",
		"max": 3, "costs": [25, 65, 120],
		"desc": "Bomben lösen automatisch aus, räumen gegnerisches Feuer und schaden flächig.",
	},
	{
		"id": "shield", "name": "bar.shield", "short": "Schild", "icon": "shield", "kind": "support",
		"max": 3, "costs": [25, 70, 130],
		"desc": "Erst dieser Kauf aktiviert das Schild: Stufe 1/2/3 gibt genau 1/2/3 Ladungen. Lädt automatisch nach.",
	},
	{
		"id": "speed", "name": "bar.speed", "short": "Tempo", "icon": "speed", "kind": "passive",
		"max": 3, "costs": [20, 50, 90],
		"desc": "Höheres Flugtempo. Erneut aktivieren senkt es wieder auf eine freigeschaltete Stufe.",
	},
	{
		"id": "repair", "name": "bar.repair", "short": "Reparatur", "icon": "repair", "kind": "instant",
		"max": 1, "costs": [35],
		"desc": "Repariert ein Leben. Bei vollen Leben wird nichts verbraucht.",
	},
]

const WEAPON_ORDER := ["base", "fan", "lightning", "plasma"]

# -------------------------------------------------------------------- Evolutionen
## start=true -> im Pool der 20 Starttalente (Kampagnenstart zieht zufällig drei). weapon -> nur mit dieser Hauptwaffe aktiv.
const EVOLUTIONS := [
	# ---- Stachel ----
	{"id": "pierce1", "family": "sting", "name": "Durchschlagstachel", "max": 2, "start": true, "start_base": true,
	 "desc": "Stachel durchschlägt ein weiteres Ziel hinter dem ersten.",
	 "effect": {"pierce": 1}, "synergy": "pierce_master", "req": []},
	{"id": "splinter", "family": "sting", "name": "Splittstachel", "max": 2, "start": true,
	 "desc": "Bei jedem Treffer brechen zwei seitliche Splitter heraus.",
	 "effect": {"splinter": 1}, "synergy": "pierce1", "req": []},
	{"id": "crit", "family": "sting", "name": "Gezielter Stich", "max": 2, "start": true, "start_base": true,
	 "desc": "14% Chance auf einen kritischen Treffer mit doppeltem Schaden.",
	 "effect": {"crit_chance": 0.14}, "synergy": "resonance_beat", "req": []},
	{"id": "stinger_rapid", "family": "sting", "name": "Stakkato-Stachel", "max": 2, "start": true,
	 "desc": "20% mehr Feuertempo; am Taktlimit zusätzliche Wucht. 8% weniger Grundschaden.",
	 "effect": {"fire_rate_mult": 0.2, "dmg_mult": -0.08}, "synergy": "resonance_pulse", "req": []},
	{"id": "heavy_sting", "family": "sting", "name": "Schwerer Stachel", "max": 2, "start": true, "start_base": true,
	 "desc": "35% mehr Schaden, 12% langsamere Schussfolge.",
	 "effect": {"dmg_mult": 0.35, "fire_rate_mult": -0.12}, "synergy": "splinter", "req": []},
	{"id": "pierce_master", "family": "sting", "name": "Nadelkette", "max": 1, "start": false,
	 "desc": "Zwei weitere Ziele werden durchschlagen. Nur mit Durchschlagstachel.",
	 "effect": {"pierce": 2}, "synergy": "splinter", "req": ["pierce1"], "req_level": 1},
	# ---- Schwarm ----
	{"id": "companion_form", "family": "swarm", "name": "Formationsbegleiter", "max": 1, "start": false,
	 "desc": "Beim Vorwärtsflug stehen Begleiter in Angriffsreihe; sonst kreisen sie kompakt um die Biene.",
	 "effect": {"companion_form": 1}, "synergy": "companion_add", "req": [], "weapon": "companion"},
	{"id": "companion_add", "family": "swarm", "name": "Brutbegleiter", "max": 2, "start": false,
	 "desc": "Ein zusätzlicher Begleiter umkreist die Biene.",
	 "effect": {"companion_add": 1}, "synergy": "companion_form", "req": [], "weapon": "companion"},
	{"id": "swarm_mark", "family": "swarm", "name": "Zielmarkierung", "max": 1, "start": true,
	 "desc": "Sechs genaue Treffer auf ein Ziel rufen einen koordinierten Schwarmangriff.",
	 "effect": {"swarm_mark": 6}, "synergy": "crit", "req": []},
	{"id": "swarm_echo", "family": "swarm", "name": "Schwarmecho", "max": 2, "start": false,
	 "desc": "Begleiter feuern 25% schneller und spiegeln deine Schüsse.",
	 "effect": {"companion_rate": 0.25}, "synergy": "companion_add", "req": [], "weapon": "companion"},
	{"id": "drone_sacrifice", "family": "swarm", "name": "Opferdrohne", "max": 1, "start": false,
	 "desc": "Alle 8 Sekunden fängt eine Drohne ein gegnerisches Geschoss ab.",
	 "effect": {"drone_shield": 8.0}, "synergy": "companion_form", "req": [], "weapon": "companion"},
	{"id": "swarm_call", "family": "swarm", "name": "Schwarmruf", "max": 1, "start": true,
	 "desc": "Fünf Abschüsse innerhalb von drei Sekunden entfesseln eine Schwarmwelle.",
	 "effect": {"swarm_call": 5}, "synergy": "swarm_mark", "req": []},
	# ---- Pollen ----
	{"id": "pollen_trail", "family": "pollen", "name": "Pollenschleier", "max": 2, "start": true,
	 "desc": "Hinter der Biene bleiben Pollenwolken, die kurz Flächenschaden verursachen.",
	 "effect": {"pollen_trail": 1}, "synergy": "pollen_burst", "req": []},
	{"id": "pollen_burst", "family": "pollen", "name": "Staubexplosion", "max": 2, "start": true,
	 "desc": "Zerstörte Gegner setzen eine Pollenwolke frei, die Nachbarn schädigt.",
	 "effect": {"pollen_burst": 1}, "synergy": "pollen_trail", "req": []},
	{"id": "pollen_shield", "family": "pollen", "name": "Allergieaura", "max": 1, "start": true,
	 "desc": "Gegnerische Geschosse im Umkreis werden deutlich verlangsamt.",
	 "effect": {"pollen_slow": 1}, "synergy": "pollen_trail", "req": []},
	{"id": "pollen_economy", "family": "pollen", "name": "Sammelinstinkt", "max": 2, "start": false,
	 "desc": "Sammeleinzug 60% größer, jede Blüte gibt einen Nektar mehr.",
	 "effect": {"magnet": 0.6, "nectar_pickup": 1}, "synergy": "nectar_scent", "req": []},
	{"id": "pollen_blind", "family": "pollen", "name": "Sichttrübung", "max": 1, "start": false,
	 "desc": "Pollenwolken lassen gezielte Gegnerschüsse mit 40% Chance erlöschen.",
	 "effect": {"pollen_blind": 1}, "synergy": "pollen_shield", "req": ["pollen_trail"], "req_level": 1},
	{"id": "wind_rider", "family": "pollen", "name": "Windreiter", "max": 1, "start": true,
	 "desc": "12% mehr Tempo, Pollenwolken driften mit der Biene.",
	 "effect": {"speed_mult": 0.12}, "synergy": "pollen_trail", "req": []},
	# ---- Chitin ----
	{"id": "chitin_plate", "family": "chitin", "name": "Chitinpanzer", "max": 2, "start": true,
	 "desc": "Ein zusätzlicher Trefferpunkt.",
	 "effect": {"hp": 1}, "synergy": "chitin_regen", "req": []},
	{"id": "chitin_regen", "family": "chitin", "name": "Häutung", "max": 2, "start": true,
	 "desc": "Heilt an jedem Checkpoint einen Punkt; Schutzphase je Stufe 0,3 Sekunden länger.",
	 "effect": {"heal_checkpoint": 1, "iframes": 0.3}, "synergy": "chitin_plate", "req": []},
	{"id": "chitin_thorns", "family": "chitin", "name": "Stachelhaut", "max": 1, "start": true,
	 "desc": "Berührte Gegner nehmen Schaden und werden zurückgestoßen.",
	 "effect": {"thorns": 1}, "synergy": "chitin_plate", "req": []},
	{"id": "chitin_light", "family": "chitin", "name": "Leichtbau", "max": 2, "start": true,
	 "desc": "Trefferzone 15% kleiner, 8% mehr Tempo.",
	 "effect": {"hitbox": -0.15, "speed_mult": 0.08}, "synergy": "chitin_guard", "req": []},
	{"id": "chitin_guard", "family": "chitin", "name": "Panzerhaltung", "max": 1, "start": false,
	 "desc": "Im Präzisionsmodus 25% weniger Schaden.",
	 "effect": {"precision_guard": 0.25}, "synergy": "chitin_light", "req": []},
	{"id": "chitin_bastion", "family": "chitin", "name": "Bastion", "max": 1, "start": false,
	 "desc": "Ein gekauftes Schild hat 35% kürzere Ladezeit; beim Schildtreffer entsteht ein Gegenimpuls.",
	 "effect": {"shield_regen": 0.35}, "synergy": "chitin_guard", "req": [], "weapon": "shield"},
	# ---- Resonanz ----
	{"id": "resonance_beat", "family": "resonance", "name": "Taktgeber", "max": 2, "start": true,
	 "desc": "Jede zwölfte Salve wird ein verstärkter Resonanzschuss; Stufe 2: jede sechste.",
	 "effect": {"rhythm": 12}, "synergy": "resonance_chain", "req": []},
	{"id": "resonance_chain", "family": "resonance", "name": "Kettenresonanz", "max": 1, "start": false,
	 "desc": "Resonanzschüsse springen auf zwei weitere Gegner über.",
	 "effect": {"rhythm_chain": 2}, "synergy": "resonance_beat", "req": ["resonance_beat"], "req_level": 1},
	{"id": "resonance_calm", "family": "resonance", "name": "Ruhepol", "max": 1, "start": true,
	 "desc": "Gleichmäßiges Dauerfeuer erhöht den Schaden bis +20%.",
	 "effect": {"calm": 0.2}, "synergy": "resonance_pulse", "req": []},
	{"id": "resonance_pulse", "family": "resonance", "name": "Druckwelle", "max": 1, "start": true,
	 "desc": "Drei Sekunden Dauerfeuer lösen eine Ringwelle aus (6 s Abklingzeit).",
	 "effect": {"pulse": 1}, "synergy": "resonance_calm", "req": []},
	{"id": "resonance_tuning", "family": "resonance", "name": "Stimmung", "max": 1, "start": false,
	 "desc": "Waffenwechsel gibt zwei Sekunden 25% mehr Schaden.",
	 "effect": {"tuning": 1}, "synergy": "resonance_beat", "req": []},
	{"id": "resonance_final", "family": "resonance", "name": "Endton", "max": 1, "start": false,
	 "desc": "Resonanzschüsse doppelt so stark, Schussfolge 10% langsamer.",
	 "effect": {"rhythm_mult": 1.0, "fire_rate_mult": -0.1}, "synergy": "resonance_chain",
	 "req": ["resonance_beat"], "req_level": 1},
	# ---- Nektar ----
	{"id": "nectar_overflow", "family": "nectar", "name": "Nektarstau", "max": 1, "start": false,
	 "desc": "Bei voller Waffenstufe geben Blüten zusätzlich Punkte und füllen einen freigeschalteten Schild.",
	 "effect": {"nectar_overflow": 1}, "synergy": "nectar_gluttony", "req": []},
	{"id": "nectar_convert", "family": "nectar", "name": "Umwandlung", "max": 1, "start": false,
	 "desc": "Zehn Nektar werden alle 20 Sekunden automatisch zu einem Leben.",
	 "effect": {"nectar_convert": 10}, "synergy": "nectar_overflow", "req": []},
	{"id": "nectar_scent", "family": "nectar", "name": "Duftspur", "max": 2, "start": true,
	 "desc": "Gegner lassen einen Nektar mehr fallen.",
	 "effect": {"nectar_drop": 1}, "synergy": "pollen_economy", "req": []},
	{"id": "nectar_gluttony", "family": "nectar", "name": "Völlerei", "max": 1, "start": false,
	 "desc": "20% mehr Nektar, 10% langsamere Schussfolge.",
	 "effect": {"nectar_mult": 0.2, "fire_rate_mult": -0.1}, "synergy": "nectar_overflow", "req": []},
	{"id": "nectar_bargain", "family": "nectar", "name": "Handel", "max": 1, "start": true,
	 "desc": "Alle Verbesserungen kosten 15% weniger Nektar.",
	 "effect": {"cost_mult": -0.15}, "synergy": "nectar_gluttony", "req": []},
	{"id": "nectar_font", "family": "nectar", "name": "Nektarquellé", "max": 1, "start": false,
	 "desc": "Jeder Bossphasenwechsel spendet 15 Nektar.",
	 "effect": {"nectar_phase": 15}, "synergy": "nectar_overflow", "req": []},
]

const FAMILIES := ["sting", "swarm", "pollen", "chitin", "resonance", "nectar"]

# ---------------------------------------------------------------------- Gegner
## behavior: steuert die Bewegungs-/Angriffsroutine in enemy.gd
const ENEMIES := {
	# R4: Hornisse überholt von hinten, Spinne seilt sich von oben ab (ruhige
	# Passagen); Ameisenkanonier und Maulwurfsgrille greifen vom Boden an.
	"hornet_flank": {"name": "Hornisse", "hp": 22, "score": 140, "nectar": 4, "sprite": "hornet", "r": 10,
			 "behavior": "from_behind", "speed": 260, "fire": 1.15, "shots": "aimed2", "dmg": 1},
	"web_spider": {"name": "Kreuzspinne", "hp": 30, "score": 150, "nectar": 4, "sprite": "spider", "r": 12,
			 "behavior": "descend", "speed": 90, "fire": 1.7, "shots": "web", "dmg": 1},
	"ant_gunner": {"name": "Ameisenkanonier", "hp": 34, "score": 140, "nectar": 4, "sprite": "ant_gunner", "r": 11,
			 "behavior": "ground_walk", "speed": 55, "fire": 2.3, "shots": "mortar", "dmg": 1},
	"mole_cricket": {"name": "Maulwurfsgrille", "hp": 28, "score": 130, "nectar": 4, "sprite": "molecricket", "r": 12,
			 "behavior": "pop_up", "speed": 0, "fire": 1.1, "shots": "spore_lob", "dmg": 1},
	"moth": {"name": "Motte", "hp": 14, "score": 60, "nectar": 2, "sprite": "moth", "r": 9,
			 "behavior": "sine", "speed": 120, "fire": 2.4, "shots": "aimed1", "dmg": 1},
	"beetle_grunt": {"name": "Laufkäfer", "hp": 26, "score": 90, "nectar": 3, "sprite": "beetle", "r": 11,
			 "behavior": "straight", "speed": 95, "fire": 2.0, "shots": "forward", "dmg": 1},
	"wasp_dart": {"name": "Wespenpfeil", "hp": 16, "score": 110, "nectar": 3, "sprite": "wasp", "r": 8,
			 "behavior": "dive", "speed": 230, "fire": 0.0, "shots": "", "dmg": 1},
	"aphid_swarm": {"name": "Blattlaus", "hp": 6, "score": 30, "nectar": 1, "sprite": "aphid", "r": 6,
			 "behavior": "wobble", "speed": 150, "fire": 0.0, "shots": "", "dmg": 1},
	"pollen_pod": {"name": "Pollenkapsel", "hp": 18, "score": 70, "nectar": 3, "sprite": "pod", "r": 10,
			 "behavior": "drift", "speed": 55, "fire": 3.2, "shots": "ring3", "dmg": 1},
	"ladybug_turret": {"name": "Marienkäfergeschütz", "hp": 40, "score": 130, "nectar": 4, "sprite": "ladybug", "r": 12,
			 "behavior": "hover", "speed": 60, "fire": 1.5, "shots": "aimed3", "dmg": 1},
	"root_borer": {"name": "Wurzelbohrer", "hp": 32, "score": 120, "nectar": 4, "sprite": "borer", "r": 11,
			 "behavior": "emerge", "speed": 130, "fire": 2.6, "shots": "up3", "dmg": 1},
	"larva_grub": {"name": "Riesenmade", "hp": 45, "score": 150, "nectar": 5, "sprite": "grub", "r": 13,
			 "behavior": "crawl", "speed": 70, "fire": 2.2, "shots": "spit", "dmg": 1},
	"dragonfly_sniper": {"name": "Libellenjäger", "hp": 24, "score": 140, "nectar": 4, "sprite": "dragonfly", "r": 9,
			 "behavior": "dash", "speed": 260, "fire": 3.0, "shots": "laserline", "dmg": 1},
	"mosquito_pair": {"name": "Mückenschwarm", "hp": 12, "score": 60, "nectar": 2, "sprite": "mosquito", "r": 7,
			 "behavior": "mirror", "speed": 170, "fire": 2.8, "shots": "aimed1", "dmg": 1},
	"reed_jumper": {"name": "Schilfspringer", "hp": 22, "score": 110, "nectar": 3, "sprite": "hopper", "r": 9,
			 "behavior": "leap", "speed": 200, "fire": 0.0, "shots": "", "dmg": 1},
	"pike_fry": {"name": "Hechtbrut", "hp": 20, "score": 100, "nectar": 3, "sprite": "pike", "r": 10,
			 "behavior": "rush", "speed": 300, "fire": 0.0, "shots": "", "dmg": 1},
	"spore_drifter": {"name": "Sporenträger", "hp": 28, "score": 100, "nectar": 3, "sprite": "spore", "r": 10,
			 "behavior": "drift", "speed": 50, "fire": 2.6, "shots": "spore", "dmg": 1},
	"mushroom_cap": {"name": "Kappenwächter", "hp": 38, "score": 140, "nectar": 4, "sprite": "mushroom", "r": 12,
			 "behavior": "hover", "speed": 55, "fire": 2.2, "shots": "ring6", "dmg": 1},
	"thorn_vine": {"name": "Dornenranke", "hp": 30, "score": 90, "nectar": 3, "sprite": "vine", "r": 10,
			 "behavior": "sweep", "speed": 145, "fire": 0.0, "shots": "", "dmg": 1},
	"mantis_stalker": {"name": "Mantis", "hp": 34, "score": 160, "nectar": 4, "sprite": "mantis", "r": 11,
			 "behavior": "track", "speed": 105, "fire": 2.4, "shots": "aimed2", "dmg": 1},
	"glass_drone": {"name": "Glasdrohne", "hp": 30, "score": 150, "nectar": 4, "sprite": "glassdrone", "r": 10,
			 "behavior": "hover", "speed": 90, "fire": 1.9, "shots": "reflect", "dmg": 1},
	"mirror_orb": {"name": "Spiegelkugel", "hp": 42, "score": 170, "nectar": 5, "sprite": "mirrororb", "r": 11,
			 "behavior": "orbit", "speed": 110, "fire": 2.8, "shots": "bounce", "dmg": 1},
	"canal_crawler": {"name": "Kanalgräber", "hp": 50, "score": 160, "nectar": 5, "sprite": "crawler", "r": 13,
			 "behavior": "crawl", "speed": 80, "fire": 2.0, "shots": "down3", "dmg": 1},
	"sludge_blob": {"name": "Schlammklumpen", "hp": 60, "score": 130, "nectar": 4, "sprite": "sludge", "r": 14,
			 "behavior": "drift", "speed": 40, "fire": 3.4, "shots": "spore", "dmg": 1},
	"piston_drone": {"name": "Pressendrohne", "hp": 44, "score": 170, "nectar": 5, "sprite": "piston", "r": 12,
			 "behavior": "charge", "speed": 210, "fire": 2.2, "shots": "forward2", "dmg": 1},
	"generator_unit": {"name": "Generator", "hp": 70, "score": 200, "nectar": 6, "sprite": "generator", "r": 13,
			 "behavior": "anchor", "speed": 0, "fire": 1.6, "shots": "ring4", "dmg": 1},
	"hive_guard": {"name": "Stockwächter", "hp": 55, "score": 190, "nectar": 5, "sprite": "hiveguard", "r": 12,
			 "behavior": "hover", "speed": 75, "fire": 1.8, "shots": "aimed3", "dmg": 1},
	"queen_acolyte": {"name": "Königinnenbrut", "hp": 48, "score": 210, "nectar": 6, "sprite": "acolyte", "r": 11,
			 "behavior": "orbit", "speed": 130, "fire": 2.0, "shots": "spiral", "dmg": 1},
	"core_shard": {"name": "Kernsplitter", "hp": 40, "score": 220, "nectar": 6, "sprite": "shard", "r": 10,
			 "behavior": "orbit", "speed": 160, "fire": 1.6, "shots": "radial", "dmg": 1},
}

# ----------------------------------------------------------------------- Bosse
## patterns: Namen aus boss.gd; phase wechselt bei hp_frac.
var bosses := {}

# ----------------------------------------------------------------------- Level
var levels: Array = []

func _ready() -> void:
	_build_bosses()
	_build_levels()

# ------------------------------------------------------------------ Formationen
static func F(kind: String, enemy: String, n: int, opts: Dictionary = {}) -> Dictionary:
	var d := {"kind": kind, "enemy": enemy, "n": n}
	for k in opts:
		d[k] = opts[k]
	return d

# --------------------------------------------------------------------- Bosse
func _build_bosses() -> void:
	bosses = {
		"rose_beetle": {
			"name": "Gepanzerter Rosenkäfer", "sprite": "boss_beetle", "hp": 3400,
			"phases": [
				{"hp": 1.0, "patterns": ["aimed_burst", "beetle_charge"], "interval": 1.35, "move": "beetle"}, {"hp": 0.55, "patterns": ["shell_open", "radial", "beetle_charge"], "interval": 1.0, "move": "beetle"},
			],
			"weak": "Öffnungsphase: Panzer klappt auf und gibt den Rücken frei.",
		},
		"giant_larva": {
			"name": "Grabende Riesenlarve", "sprite": "boss_larva", "hp": 4000,
			"phases": [
				{"hp": 1.0, "patterns": ["burrow", "tunnel_chase", "spit_arc", "rock_fall", "emerge_strike"], "interval": 1.45, "move": "larva"},
				{"hp": 0.62, "patterns": ["tunnel_chase_fast", "brood", "rock_fall", "burrow_fast", "spit_arc"], "interval": 1.15, "move": "larva"},
				{"hp": 0.3, "patterns": ["tunnel_chase_fast", "rock_fall_dense", "brood", "emerge_strike", "radial"], "interval": 0.95, "move": "larva"},
			],
			"weak": "Nach dem Durchbruch ist der Kopf ungeschützt.",
		},
		"pike_beast": {
			"name": "Schilfhecht", "sprite": "boss_pike", "hp": 4300,
			"phases": [
				{"hp": 1.0, "patterns": ["pike_jump", "torpedo", "vortex", "aimed_spread"], "interval": 1.3, "move": "pike"}, {"hp": 0.55, "patterns": ["pike_jump_fast", "vortex", "aimed_spread", "torpedo"], "interval": 1.0, "move": "pike"},
			],
			"weak": "Nach dem Sprung liegt die Kiemenseite offen.",
		},
		"fungus_mind": {
			"name": "Parasitäres Pilzwesen", "sprite": "boss_fungus", "hp": 4600,
			"phases": [
				{"hp": 1.0, "patterns": ["node_pulse", "spore_rain"], "interval": 1.2, "move": "fungus", "nodes": 3}, {"hp": 0.6, "patterns": ["node_pulse", "spore_rain", "spore_rings"], "interval": 0.95, "move": "fungus", "nodes": 2}, {"hp": 0.25, "patterns": ["spore_rings", "radial", "aimed_burst"], "interval": 0.8, "move": "fungus", "nodes": 0},
			],
			"weak": "Angriffsknoten müssen einzeln zerstört werden.",
		},
		"mantis_pair": {
			"name": "Mantidenpaar", "sprite": "boss_mantis", "hp": 4800,
			"phases": [
				{"hp": 1.0, "patterns": ["mantis_sweep", "mantis_pounce", "twin_aim"], "interval": 1.25, "move": "mantis"}, {"hp": 0.5, "patterns": ["mantis_sweep_fast", "mantis_pounce", "twin_aim", "cross_cut"], "interval": 0.9, "move": "mantis"},
			],
			"weak": "Beide Klingen teilen sich einen Lebensbalken – Konter nur nach dem Kreuzhieb.",
		},
		"mech_pollinator": {
			"name": "Mechanischer Bestäuber", "sprite": "boss_pollinator", "hp": 5200,
			"phases": [
				{"hp": 1.0, "patterns": ["armor_cycle", "reflect_volley", "beam_sweep"], "interval": 1.25, "move": "pollinator"}, {"hp": 0.6, "patterns": ["armor_cycle_fast", "reflect_volley", "beam_sweep", "radial"], "interval": 0.95, "move": "pollinator"},
			],
			"weak": "Nur die ungepanzerte Seite nimmt vollen Schaden.",
		},
		"mutant_skater": {
			"name": "Mutierter Wasserläufer", "sprite": "boss_skater", "hp": 5600,
			"phases": [
				{"hp": 1.0, "patterns": ["pump_slam", "skater_dash", "drain_gate", "aimed_burst"], "interval": 1.2, "move": "skater"}, {"hp": 0.55, "patterns": ["pump_slam", "skater_dash", "drain_gate", "radial", "sludge_wave"], "interval": 0.95, "move": "skater"},
			],
			"weak": "Zwischen den Pumpen ist der Panzer weich.",
		},
		"harvester": {
			"name": "Insektenförmige Erntemaschine", "sprite": "boss_harvester", "hp": 6000,
			"phases": [
				{"hp": 1.0, "patterns": ["module_fire", "harvester_ram", "press_slam"], "interval": 1.15, "move": "harvester", "modules": 3}, {"hp": 0.65, "patterns": ["module_fire", "press_slam", "razor_arc"], "interval": 0.95, "move": "harvester", "modules": 2}, {"hp": 0.3, "patterns": ["razor_arc", "radial", "aimed_burst"], "interval": 0.8, "move": "harvester", "modules": 0},
			],
			"weak": "Module einzeln abtrennen; der Kern ist erst danach verwundbar.",
		},
		"swarm_queen": {
			"name": "Schwarmkönigin", "sprite": "boss_queen", "hp": 6800,
			"phases": [
				{"hp": 1.0, "patterns": ["summon_guards", "queen_dive", "queen_spiral", "aimed_burst"], "interval": 1.2, "move": "queen"}, {"hp": 0.6, "patterns": ["summon_guards", "queen_dive", "queen_spiral", "cross_cut", "radial"], "interval": 0.95, "move": "queen"}, {"hp": 0.3, "patterns": ["queen_spiral_fast", "cross_cut", "summon_guards"], "interval": 0.8, "move": "queen"},
			],
			"weak": "Der Schwarm schützt sie; erst Begleiter brechen, dann der Panzer.",
		},
		"core_organism": {
			"name": "Kernorganismus", "sprite": "boss_core", "hp": 8200,
			"phases": [
				{"hp": 1.0, "patterns": ["core_beam", "ring_barrage", "spawn_shards"], "interval": 1.15, "move": "core"}, {"hp": 0.62, "patterns": ["core_beam_fast", "ring_barrage", "twin_orbit", "spawn_shards"], "interval": 0.9, "move": "core"}, {"hp": 0.32, "patterns": ["final_fury", "core_beam_fast", "twin_orbit", "ring_barrage"], "interval": 0.6, "move": "core"},
			],
			"weak": "Die Schlussphase öffnet den Kern dauerhaft, verstärkt aber jeden Angriff.",
		},
	}

# --------------------------------------------------------------------- Level
func _build_levels() -> void:
	levels = [
	{
		"id": 1, "name": "Blütenmeer", "boss": "rose_beetle",
		"palette": {"sky": Color("#f7c8d8"), "haze": Color("#ffd9e6"), "ground": Color("#3f7a3a"),
					"accent": Color("#ffd34e"), "dark": Color("#22331f")},
		"music": "level1", "cruise": 88.0, "bg": "l01",
		"mechanic": "blossom", "mechanic_text": "Riesige Blüten geben Deckung und verstecken Nektar.",
		"enemy_pool": ["moth", "beetle_grunt", "aphid_swarm", "pollen_pod", "ladybug_turret"],
		"sections": [
			{"dur": 56, "pools": [["moth_line", "moth_arc"], ["aphid_cloud", "beetle_row"]]},
			{"dur": 62, "pools": [["beetle_row", "aphid_cloud"], ["pod_field", "ladybug_pair"]]},
			{"dur": 60, "pools": [["moth_arc", "ladybug_pair"], ["beetle_row", "aphid_cloud"]]},
			{"dur": 54, "pools": [["pod_field", "moth_line"], ["ladybug_pair", "beetle_row"]]},
			{"dur": 48, "pools": [["aphid_cloud", "wasp_dive"], ["moth_arc", "pod_field"]]},
		],
		"miniboss": {"t": 150.0, "enemy": "ladybug_turret", "hp_mult": 6.0, "title": "Blütengeschütz"},
		"boss_intro": "Der Rosenkäfer öffnet seinen Panzer. Nur dann ist er verwundbar.",
	},
	{
		"id": 2, "name": "Wurzelreich", "boss": "giant_larva",
		"palette": {"sky": Color("#2b2018"), "haze": Color("#4a3524"), "ground": Color("#6b4a2a"),
					"accent": Color("#c8892c"), "dark": Color("#150f0a")},
		"music": "level2", "cruise": 82.0, "bg": "l02",
		"mechanic": "roots", "mechanic_text": "Wurzeln fahren aus dem Boden: Deckung oder Falle.",
		"enemy_pool": ["root_borer", "larva_grub", "beetle_grunt", "moth", "aphid_swarm"],
		"sections": [
			{"dur": 60, "pools": [["borer_emerge", "grub_crawl"], ["beetle_row", "aphid_cloud"]]},
			{"dur": 62, "pools": [["root_wall", "borer_emerge"], ["grub_crawl", "moth_arc"]]},
			{"dur": 60, "pools": [["root_wall", "aphid_cloud"], ["borer_emerge", "beetle_row"]]},
			{"dur": 54, "pools": [["grub_crawl", "moth_line"], ["root_wall", "borer_emerge"]]},
			{"dur": 46, "pools": [["borer_emerge", "root_wall"], ["grub_crawl", "aphid_cloud"]]},
		],
		"miniboss": {"t": 148.0, "enemy": "grub", "hp_mult": 7.0, "title": "Wurzelfresser"},
		"boss_intro": "Die Larve gräbt sich ein. Jeder Durchbruch kündigt sich an.",
	},
	{
		"id": 3, "name": "Schilf und Teich", "boss": "pike_beast",
		"palette": {"sky": Color("#7fc8e8"), "haze": Color("#bfe8f2"), "ground": Color("#2f6b52"),
					"accent": Color("#ffe08a"), "dark": Color("#12303a")},
		"music": "level3", "cruise": 96.0, "bg": "l03",
		"mechanic": "water", "mechanic_text": "Die Wasserlinie teilt die Arena: unten lauern Sprünge.",
		"enemy_pool": ["reed_jumper", "pike_fry", "mosquito_pair", "dragonfly_sniper", "moth"],
		"sections": [
			{"dur": 56, "pools": [["reed_leap", "mosquito_arc"], ["pike_rush", "moth_line"]]},
			{"dur": 62, "pools": [["pike_rush", "reed_leap"], ["dragonfly_dash", "mosquito_arc"]]},
			{"dur": 60, "pools": [["mosquito_arc", "dragonfly_dash"], ["reed_leap", "pike_rush"]]},
			{"dur": 54, "pools": [["pike_rush", "mosquito_arc"], ["reed_leap", "moth_arc"]]},
			{"dur": 46, "pools": [["dragonfly_dash", "reed_leap"], ["pike_rush", "mosquito_arc"]]},
		],
		"miniboss": {"t": 146.0, "enemy": "dragonfly_sniper", "hp_mult": 8.0, "title": "Libellenwache"},
		"boss_intro": "Der Hecht springt aus dem Wasser. Nach der Landung ist er offen.",
	},
	{
		"id": 4, "name": "Pilzwald", "boss": "fungus_mind",
		"palette": {"sky": Color("#141a2e"), "haze": Color("#233a52"), "ground": Color("#2b4a4a"),
					"accent": Color("#6ef0c8"), "dark": Color("#080b14")},
		"music": "level4", "cruise": 80.0, "bg": "l04",
		"mechanic": "spores", "mechanic_text": "Wandernde Sporenfelder engen die sicheren Korridore ein.",
		"enemy_pool": ["spore_drifter", "mushroom_cap", "moth", "aphid_swarm", "pollen_pod"],
		"sections": [
			{"dur": 56, "pools": [["spore_field", "mushroom_guard"], ["moth_arc", "aphid_cloud"]]},
			{"dur": 62, "pools": [["mushroom_guard", "spore_field"], ["pod_field", "moth_line"]]},
			{"dur": 60, "pools": [["spore_field", "aphid_cloud"], ["mushroom_guard", "moth_arc"]]},
			{"dur": 54, "pools": [["pod_field", "spore_field"], ["mushroom_guard", "moth_line"]]},
			{"dur": 48, "pools": [["spore_field", "mushroom_guard"], ["aphid_cloud", "pollen_pod"]]},
		],
		"miniboss": {"t": 148.0, "enemy": "mushroom_cap", "hp_mult": 7.0, "title": "Sporenhüter"},
		"boss_intro": "Drei Angriffsknoten verbinden das Pilzwesen mit dem Boden.",
	},
	{
		"id": 5, "name": "Dornen im Sturm", "boss": "mantis_pair",
		"palette": {"sky": Color("#3a2a4a"), "haze": Color("#6b4a72"), "ground": Color("#4a3a2a"),
					"accent": Color("#ff9a5a"), "dark": Color("#120c18")},
		"music": "level5", "cruise": 104.0, "bg": "l05",
		"mechanic": "wind", "mechanic_text": "Angekündigte Windzonen drücken die Biene nach oben oder unten.",
		"enemy_pool": ["thorn_vine", "mantis_stalker", "wasp_dart", "moth", "beetle_grunt"],
		"sections": [
			{"dur": 54, "pools": [["vine_sweep", "wasp_dive"], ["mantis_hunt", "moth_arc"]]},
			{"dur": 60, "pools": [["wind_gust", "vine_sweep"], ["beetle_row", "wasp_dive"]]},
			{"dur": 60, "pools": [["mantis_hunt", "vine_sweep"], ["wind_gust", "wasp_dive"]]},
			{"dur": 56, "pools": [["wind_gust", "beetle_row"], ["mantis_hunt", "moth_arc"]]},
			{"dur": 46, "pools": [["vine_sweep", "wasp_dive"], ["wind_gust", "mantis_hunt"]]},
		],
		"miniboss": {"t": 142.0, "enemy": "mantis_stalker", "hp_mult": 8.0, "title": "Dornenwache"},
		"boss_intro": "Zwei Klingen, ein Rhythmus. Der Kreuzhieb öffnet das Fenster.",
	},
	{
		"id": 6, "name": "Gläsernes Gewächshaus", "boss": "mech_pollinator",
		"palette": {"sky": Color("#cfe8ff"), "haze": Color("#e8f4ff"), "ground": Color("#5a7a8a"),
					"accent": Color("#ffd0f0"), "dark": Color("#1a2630")},
		"music": "level6", "cruise": 92.0, "bg": "l06",
		"mechanic": "glass", "mechanic_text": "Glasflächen blinken viermal, dann fangen sie Schüsse ab. Umfliege die aktive Fläche.",
		"enemy_pool": ["glass_drone", "mirror_orb", "moth", "beetle_grunt", "ladybug_turret"],
		"sections": [
			{"dur": 56, "pools": [["glass_drone_row", "mirror_orbit"], ["moth_line", "beetle_row"]]},
			{"dur": 62, "pools": [["mirror_orbit", "glass_drone_row"], ["ladybug_pair", "moth_arc"]]},
			{"dur": 60, "pools": [["glass_drone_row", "ladybug_pair"], ["mirror_orbit", "beetle_row"]]},
			{"dur": 54, "pools": [["mirror_orbit", "moth_arc"], ["glass_drone_row", "ladybug_pair"]]},
			{"dur": 46, "pools": [["glass_drone_row", "mirror_orbit"], ["beetle_row", "moth_line"]]},
		],
		"miniboss": {"t": 146.0, "enemy": "mirror_orb", "hp_mult": 7.0, "title": "Spiegelwächter"},
		"boss_intro": "Der Bestäuber dreht seine Panzerung. Treffer prallen an der Außenseite ab.",
	},
	{
		"id": 7, "name": "Verlorene Kanalisation", "boss": "mutant_skater",
		"palette": {"sky": Color("#1a2024"), "haze": Color("#2f3a34"), "ground": Color("#4a5a3a"),
					"accent": Color("#a8e05a"), "dark": Color("#080c0a")},
		"music": "level7", "cruise": 86.0, "bg": "l07",
		"mechanic": "currents", "mechanic_text": "Schleusen erzeugen Strömung: Position halten kostet Tempo.",
		"enemy_pool": ["canal_crawler", "sludge_blob", "mosquito_pair", "piston_drone", "glass_drone"],
		"sections": [
			{"dur": 56, "pools": [["crawler_row", "sludge_field"], ["mosquito_arc", "piston_charge"]]},
			{"dur": 62, "pools": [["sluice_current", "crawler_row"], ["sludge_field", "mosquito_arc"]]},
			{"dur": 60, "pools": [["piston_charge", "sludge_field"], ["sluice_current", "crawler_row"]]},
			{"dur": 54, "pools": [["crawler_row", "mosquito_arc"], ["piston_charge", "sludge_field"]]},
			{"dur": 46, "pools": [["sluice_current", "piston_charge"], ["sludge_field", "crawler_row"]]},
		],
		"miniboss": {"t": 146.0, "enemy": "canal_crawler", "hp_mult": 8.0, "title": "Schleusenwärter"},
		"boss_intro": "Der Wasserläufer gleitet an den Pumpen entlang. Dazwischen ist er weich.",
	},
	{
		"id": 8, "name": "Maschinenherz", "boss": "harvester",
		"palette": {"sky": Color("#241c1c"), "haze": Color("#3d2a26"), "ground": Color("#6a4a30"),
					"accent": Color("#ff7a3c"), "dark": Color("#0e0a08")},
		"music": "level8", "cruise": 94.0, "bg": "l08",
		"mechanic": "order", "mechanic_text": "Generatoren fliegen ein und feuern Ringsalven. Schalte sie aus – keine Abschussreihenfolge nötig.",
		"enemy_pool": ["piston_drone", "generator_unit", "glass_drone", "beetle_grunt", "ladybug_turret"],
		"sections": [
			{"dur": 56, "pools": [["generator_order", "piston_charge"], ["beetle_row", "glass_drone_row"]]},
			{"dur": 62, "pools": [["press_wall", "generator_order"], ["piston_charge", "ladybug_pair"]]},
			{"dur": 60, "pools": [["generator_order", "press_wall"], ["glass_drone_row", "piston_charge"]]},
			{"dur": 54, "pools": [["piston_charge", "beetle_row"], ["press_wall", "generator_order"]]},
			{"dur": 46, "pools": [["generator_order", "piston_charge"], ["glass_drone_row", "press_wall"]]},
		],
		"miniboss": {"t": 144.0, "enemy": "generator_unit", "hp_mult": 7.0, "title": "Hauptgenerator"},
		"boss_intro": "Der Erntemaschine wachsen Module. Jedes Modul feuert eigenständig.",
	},
	{
		"id": 9, "name": "Biomechanischer Schwarmstock", "boss": "swarm_queen",
		"palette": {"sky": Color("#2a1c3a"), "haze": Color("#4a2a52"), "ground": Color("#5a6a3a"),
					"accent": Color("#ffcf5a"), "dark": Color("#0c0812")},
		"music": "level9", "cruise": 98.0, "bg": "l09",
		"mechanic": "combined", "mechanic_text": "Chitin und Stahl: alle bisherigen Muster kehren kombiniert zurück.",
		"enemy_pool": ["hive_guard", "queen_acolyte", "glass_drone", "piston_drone", "mantis_stalker"],
		"sections": [
			{"dur": 56, "pools": [["hive_guard_row", "acolyte_orbit"], ["glass_drone_row", "piston_charge"]]},
			{"dur": 62, "pools": [["acolyte_orbit", "wind_gust"], ["hive_guard_row", "mantis_hunt"]]},
			{"dur": 60, "pools": [["piston_charge", "hive_guard_row"], ["acolyte_orbit", "glass_drone_row"]]},
			{"dur": 54, "pools": [["wind_gust", "mantis_hunt"], ["hive_guard_row", "acolyte_orbit"]]},
			{"dur": 46, "pools": [["acolyte_orbit", "piston_charge"], ["hive_guard_row", "glass_drone_row"]]},
		],
		"miniboss": {"t": 144.0, "enemy": "hive_guard", "hp_mult": 8.0, "title": "Stockwache"},
		"boss_intro": "Die Königin ruft ihren Hof. Wer die Begleiter bricht, trifft sie.",
	},
	{
		"id": 10, "name": "Kern der Verwandlung", "boss": "core_organism",
		"palette": {"sky": Color("#101018"), "haze": Color("#2a1a2a"), "ground": Color("#4a2a3a"),
					"accent": Color("#ff5a8a"), "dark": Color("#05050a")},
		"music": "level10", "cruise": 90.0, "bg": "l10",
		"mechanic": "core", "mechanic_text": "Senkrechte Schwerkraftfelder drücken nach unten. Gegensteuern bleibt möglich.",
		"enemy_pool": ["core_shard", "queen_acolyte", "glass_drone", "piston_drone", "mantis_stalker"],
		"sections": [
			{"dur": 54, "pools": [["shard_orbit", "acolyte_orbit"], ["glass_drone_row", "piston_charge"]]},
			{"dur": 60, "pools": [["core_pulse", "shard_orbit"], ["mantis_hunt", "acolyte_orbit"]]},
			{"dur": 60, "pools": [["shard_orbit", "wind_gust"], ["piston_charge", "glass_drone_row"]]},
			{"dur": 56, "pools": [["core_pulse", "shard_orbit"], ["acolyte_orbit", "mantis_hunt"]]},
			{"dur": 46, "pools": [["shard_orbit", "core_pulse"], ["piston_charge", "glass_drone_row"]]},
		],
		"miniboss": {"t": 140.0, "enemy": "core_shard", "hp_mult": 9.0, "title": "Kernwächter"},
		"boss_intro": "Der Kern schlägt. Drei Phasen, drei Regeln, ein Ende.",
	},
	]

# ------------------------------------------------------------------ Hilfsabfragen
func evo(id: String) -> Dictionary:
	for e in EVOLUTIONS:
		if e.id == id:
			return e
	return {}

func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

func enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, ENEMIES["moth"])

func level(n: int) -> Dictionary:
	return levels[clampi(n - 1, 0, levels.size() - 1)]

func boss(id: String) -> Dictionary:
	return bosses.get(id, bosses["rose_beetle"])

func evolution_cost(level_index: int, shot_level: int) -> int:
	return 30 + level_index * 40 + shot_level * 15

func upgrade_cost(id: String, current_level: int, cost_mod: float) -> int:
	var u := upgrade(id)
	if current_level >= u.max:
		return 0
	var base: int = u.costs[clampi(current_level, 0, u.costs.size() - 1)]
	return maxi(0, int(round(base * (1.0 + cost_mod))))
