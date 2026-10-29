extends Node
## Zentrale Textverwaltung. Deutsch ist die Quellsprache: Schlüssel-Texte (STRINGS)
## und deutsche Literale im Code. Englisch kommt aus assets/i18n/en.json
## (deutscher Text -> englischer Text) und wird zweifach genutzt:
##  - als Godot-Translation: Labels/Buttons übersetzen ihren Text automatisch,
##  - über tx()/t() für selbst gezeichnete Texte (HUD, Banner, Effekttexte) und
##    Formatstrings, die erst nach der Übersetzung mit Werten gefüllt werden.

const DEFAULT_LANG := "de"
const LANGS := ["de", "en"]
const EN_PATH := "res://assets/i18n/en.json"

var lang := DEFAULT_LANG
var _en: Dictionary = {}
var _translation: Translation

func _ready() -> void:
	if FileAccess.file_exists(EN_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EN_PATH))
		if parsed is Dictionary:
			_en = parsed
	_translation = Translation.new()
	_translation.locale = "en"
	for k in _en:
		_translation.add_message(String(k), String(_en[k]))
	TranslationServer.add_translation(_translation)
	# Deutsch ist Quellsprache: ohne eigene Übersetzung nie auf Englisch zurückfallen.
	ProjectSettings.set_setting("internationalization/locale/fallback", DEFAULT_LANG)
	TranslationServer.set_locale(DEFAULT_LANG)

## Sprache umschalten ("de"/"en"); Labels aktualisieren sich selbst.
func set_language(code: String) -> void:
	lang = code if code in LANGS else DEFAULT_LANG
	TranslationServer.set_locale(lang)

## Deutschen Anzeigetext in die aktuelle Sprache übersetzen (unbekannt: unverändert).
func tx(text: String) -> String:
	if lang == "de" or text == "":
		return text
	return String(_en.get(text, text))

## Tausendertrennzeichen der Sprache ("48.280" / "48,280").
func group_sep() -> String:
	return "." if lang == "de" else ","

## Dezimalzahl als Text mit dem Trennzeichen der Sprache ("0,3" / "0.3").
func dec(text: String) -> String:
	return text.replace(".", ",") if lang == "de" else text.replace(",", ".")

## Gibt es für diesen deutschen Text eine Übersetzung? (Prüfungen)
func has_translation(text: String) -> bool:
	return _en.has(text)

const STRINGS := {
	"de": {
		# --- Allgemein / Menü ---
		"game.title": "STINGFORGE",
		"game.subtitle": "Evolve. Adapt. Strike.",
		"menu.new_campaign": "Neuer Run",
		"menu.continue": "Fortsetzen",
		"menu.boss_rush": "Boss-Rush",
		"menu.boss_rush_locked": "Boss-Rush (Bosse aus dem laufenden Run)",
		"menu.rush_locked": "Erst im laufenden Run einen Boss besiegen",
		"menu.settings": "Einstellungen",
		"menu.highscores": "Highscores",
		"menu.credits": "Credits",
		"menu.quit": "Spiel beenden",
		"menu.back": "Zurück",
		"menu.back_main": "Zurück zum Hauptmenü",
		"menu.resume": "Fortsetzen",
		"menu.restart_checkpoint": "Am Checkpoint neu starten",
		"menu.build": "Build-Übersicht",
		"menu.difficulty": "Schwierigkeit",
		"menu.new_campaign_warn": "Ein neuer Run überschreibt den laufenden Fortschritt.",
		"menu.quit_warn": "Spiel beenden? Der letzte Checkpoint wird gespeichert.",
		"menu.only_checkpoint": "Nur der letzte Checkpoint kann fortgesetzt werden.",
		"menu.confirm": "Bestätigen",
		"menu.cancel": "Abbrechen",
		"menu.yes": "Ja",
		"menu.no": "Nein",
		"menu.empty": "Kein Eintrag vorhanden.",
		"menu.grid_hint_joy": "Stick links/rechts: Karte wählen   runter: Angebot neu ziehen   A: Bestätigen   B: Zurück",
		"menu.grid_hint_kb": "A/D oder Pfeil links/rechts: Karte wählen   S/Pfeil runter: Angebot neu ziehen   Leertaste: Bestätigen   Esc: Zurück",
		"menu.controller_hint": "Stick/Steuerkreuz oder Maus: Wählen   A/Klick: Bestätigen   B/Esc: Zurück",
		"menu.keyboard_hint": "WASD/Pfeile oder Maus: Wählen   Leertaste/Klick: Bestätigen   Esc: Zurück",

		# --- Schwierigkeit ---
		"diff.relaxed": "Entspannt",
		"diff.normal": "Normal",
		"diff.expert": "Experte",
		"diff.relaxed.desc": "Weniger und langsamere Geschosse, Bosse mit mehr Pausen, lange Gnadenzeit. Jeder fünfte Treffer wird verziehen. Punkte ×0,7.",
		"diff.normal.desc": "Der beabsichtigte Schwierigkeitsgrad.",
		"diff.expert.desc": "Volles Sperrfeuer, schnellere Geschosse, mehr Gegner, Bosse ohne Atempause. Etwa jeder dritte Treffer kostet doppelt, der Schild lädt langsamer. Punkte ×1,4.",

		# --- HUD ---
		"hud.hp": "Leben",
		"hud.shield": "Schild",
		"hud.nectar": "Blütenstaub",
		"hud.score": "Punkte",
		"hud.autofire_on": "AUTOFEUER",
		"hud.autofire_off": "",
		"hud.boss": "BOSS",
		"hud.level": "Level",
		"hud.upgrade_bar": "Ausrüstung",
		"hud.gate": "WEITER",

		# --- Waffenleiste ---
		"bar.base": "Basisschuss",
		"bar.speed": "Flugtempo",
		"bar.bombs": "Bomben",
		"bar.fan": "Fächerschuss",
		"bar.lightning": "Blitzwaffe",
		"bar.plasma": "Plasmawaffe",
		"bar.companion": "Begleiter",
		"bar.shield": "Schild",
		"bar.repair": "Reparatur",
		"bar.level": "Stufe %d/%d",
		"bar.max": "MAX",
		"bar.cost": "%d Blütenstaub",
		"bar.owned": "Ausrüsten",
		"bar.active": "Aktiv",
		"bar.slower": "Tempo senken",
		"bar.full_hp": "Leben voll",
		"bar.maxed": "Voll ausgebaut",
		"bar.no_nectar": "Zu wenig Blütenstaub",
		"bar.select": "Q/E wählen   F kaufen/aktivieren",
		"bar.locked_weapon": "Erst kaufen",

		# --- Evolution ---
		"evo.title": "Evolution wählen",
		"conv.title": "Blütenstaub wird zu Punkten",
		"conv.detail": "%d Blütenstaub übrig · %d Punkte je Tropfen",
		"conv.points": "Punkte gutgeschrieben",
		"conv.total": "Punktestand danach: %d",
		"conv.skip": "A/Leertaste: weiter",
		"evo.reset_note": "Gekaufte Upgrades starten im nächsten Level wieder auf Stufe 1.",
		"evo.subtitle": "Genau eine Wahl für diesen Levelabschluss.",
		"evo.offers": "Angebote",
		"evo.reroll": "Angebote mischen (1×)",
		"evo.reroll_used": "Angebote bereits gemischt",
		"evo.confirm": "Wählen",
		"evo.claimed": "Gewählt",
		"evo.start_talent": "STARTTALENT",
		"evo.new_unlock": "NEU IM PROFIL",
		"evo.active_campaign": "IN DIESEM RUN AKTIV",
		"evo.profile_only": "Nur Profilfreischaltung",
		"evo.weapon_dependent": "Waffenabhängig: braucht %s",
		"evo.maxed": "Ausgeschöpft",
		"evo.prereq": "Voraussetzung: %s",
		"evo.downside": "Nachteil: %s",
		"evo.synergy": "Verschmilzt mit: %s",
		"evo.synergy_now": "Verschmilzt sofort mit %s – beide werden stärker!",
		"evo.family.sting": "Stachel",
		"evo.family.swarm": "Schwarm",
		"evo.family.pollen": "Pollen",
		"evo.family.chitin": "Chitin",
		"evo.family.resonance": "Resonanz",
		"evo.family.nectar": "Nektar",
		"evo.none_active": "Noch keine Evolution aktiv.",
		"evo.pool_empty": "Alle Angebote ausgeschöpft – Ersatzangebote werden gewährt.",

		# --- Spiel ---
		"game.paused": "PAUSE",
		"game.resume_countdown": "Bereit...",
		"game.level_complete": "LEVEL GESCHAFFT",
		"game.game_over": "GAME OVER",
		"game.checkpoint": "CHECKPOINT",
		"game.continue": "Weiter",
		"game.campaign_complete": "RUN ABGESCHLOSSEN",
		"game.score": "Punkte",
		"game.time": "Zeit",
		"game.hits_taken": "Treffer",
		"game.accuracy": "Präzision",
		"game.rank": "Wertung",
		"game.new_best": "NEUE BESTLEISTUNG",
		"game.training_note": "Boss-Rush: kein Einfluss auf den Run oder das Profil.",
		"game.boss_rush_note": "Boss-Rush: eigener Build, keine Evolutionsbelohnung.",
		"game.rush_next": "Nächster Boss in %d s",
		"game.rush_clear": "BOSS-RUSH GESCHAFFT",
		"game.controller_lost": "Controller getrennt",
		"game.press_any": "Beliebige Taste drücken",
		"game.skip": "Überspringen",
		"game.level_intro": "LEVEL %d",

		"level.1": "Blütenmeer",
		"level.2": "Wurzelreich",
		"level.3": "Schilf und Teich",
		"level.4": "Pilzwald",
		"level.5": "Dornen im Sturm",
		"level.6": "Gläsernes Gewächshaus",
		"level.7": "Verlorene Kanalisation",
		"level.8": "Maschinenherz",
		"level.9": "Biomechanischer Schwarmstock",
		"level.10": "Kern der Verwandlung",

		# --- Story ---
		"story.intro.1": "Die Blütenmeere sterben. Ein grauer Stahl wächst durch Wurzeln und Teiche.",
		"story.intro.2": "Yuri, eine Feldbiene, trinkt vom letzten reinen Nektar – und verwandelt sich.",
		"story.intro.3": "Zehn Reiche trennen sie vom Kern. Sie fliegt sie der Reihe nach.",
		"story.level.1": "Rosenkäfer bewachen die erste Blüte.",
		"story.level.2": "Unter der Erde graben Larven die Wurzeln ab.",
		"story.level.3": "Der Teich ist unruhig. Etwas Großes jagt im Schilf.",
		"story.level.4": "Pilze leuchten im Dunkeln – und atmen Sporen.",
		"story.level.5": "Der Sturm reißt an den Dornen. Zwei Klingen warten.",
		"story.level.6": "Glas, Licht, Reflexe: der Garten wurde zur Maschine.",
		"story.level.7": "In der Kanalisation fließt etwas, das kein Wasser ist.",
		"story.level.8": "Das Maschinenherz pumpt. Pressen und Generatoren arbeiten.",
		"story.level.9": "Der Schwarmstock verschmilzt Chitin und Stahl.",
		"story.level.10": "Im Kern der Verwandlung entscheidet sich, was Blüten wieder bedeuten.",
		"story.end.1": "Der Kern bricht. Aus seinen Splittern wächst neuer Nektar.",
		"story.end.2": "Yuri kehrt zurück – größer als die Blüte, aus der sie kam.",

		# --- Einstellungen ---
		"set.title": "Einstellungen",
		"set.tab.display": "Anzeige",
		"set.tab.graphics": "Grafik",
		"set.tab.audio": "Audio",
		"set.tab.controls": "Steuerung",
		"set.tab.game": "Spiel",
		"set.tab.access": "Zugänglichkeit",
		"set.reset": "Standard wiederherstellen",
		"set.reset_all": "Alle Standards",
		"set.monitor": "Monitor",
		"set.resolution": "Auflösung",
		"set.window_mode": "Fenstermodus",
		"set.vsync": "VSync",
		"set.fps_cap": "Bildratenbegrenzung",
		"set.scaling": "Skalierungsmodus",
		"set.ui_size": "UI-Größe",
		"set.effects": "Effektdichte",
		"set.particles": "Partikeldichte",
		"set.shake": "Bildschirmerschütterung",
		"set.flashes": "Lichtblitze",
		"set.post": "Nachbearbeitung (Vignette/Glow)",
		"set.lighting": "Beleuchtung & Schatten",
		"set.crt": "CRT-Filter",
		"set.master": "Gesamtlautstärke",
		"set.music": "Musik",
		"set.sfx": "Effekte",
		"set.ui_sound": "UI-Klänge",
		"set.mute_unfocused": "Stumm bei inaktivem Fenster",
		"set.voice_upgrades": "Sprachansagen",
		"set.deadzone": "Stick-Totzone",
		"set.sensitivity": "Analoge Empfindlichkeit",
		"set.vibration": "Vibration",
		"set.vibration_strength": "Vibrationsstärke",
		"set.rebind": "Belegung ändern",
		"set.rebind_wait": "Eingabe drücken... (Esc: abbrechen)",
		"set.rebind_conflict": "Bereits belegt mit %s – trotzdem setzen?",
		"set.rebind_ok": "Belegung gespeichert",
		"set.gamepad": "Controller",
		"set.keyboard": "Tastatur",
		"set.autofire_default": "Autofeuer-Voreinstellung",
		"set.tutorial": "Tutorialhinweise",
		"set.hitbox": "Trefferzonenanzeige",
		"set.font_scale": "Schriftgröße",
		"set.reduce_effects": "Reduzierte Effekte",
		"set.contrast_hazards": "Kontrastreiche Gefahrenkennzeichnung",
		"set.difficulty": "Schwierigkeit",
		"set.display_test": "Anzeige testen",
		"set.display_test_hint": "Wird nach 15 s automatisch zurückgesetzt",
		"set.keep": "Behalten",
		"set.apply_display": "Anzeige übernehmen",
		"set.apply_display_hint": "Leertaste / A",
		"set.res_window_only": "wirkt nur im Fenstermodus",
		"set.staged": "noch nicht übernommen",
		"set.display_hint_kb": "←/→ ändern   Leertaste: übernehmen   Esc: zurück",
		"set.display_hint_joy": "Stick links/rechts ändern   A: übernehmen   B: zurück",
		"set.confirm_title": "Anzeige behalten?",
		"set.confirm_keep": "Behalten",
		"set.confirm_revert": "Zurück zum vorherigen Bild",
		"set.confirm_hint_kb": "←/→ wählen   Leertaste: behalten   Esc: zurück",
		"set.confirm_hint_joy": "Stick links/rechts wählen   A: behalten   B: zurück",
		"set.confirm_countdown_footer": "Ohne Antwort wird in %d s zurückgestellt",
		"set.unsupported": "Auf diesem Gerät nicht verfügbar",
		"set.requires_restart": "Wird sofort übernommen",
		"set.saved": "Gespeichert",
		"set.value_on": "An",
		"set.value_off": "Aus",
		"set.integer_scaling": "Ganzzahlige Skalierung",
		"set.smooth_scaling": "Glatte Skalierung",
		"set.pixel_plus_ui": "Pixel + scharfe UI",

		# --- Aktionen ---
		"act.move_left": "Nach links",
		"act.move_right": "Nach rechts",
		"act.move_up": "Nach oben",
		"act.move_down": "Nach unten",
		"act.fire": "Schießen",
		"act.autofire": "Autofeuer umschalten",
		"act.upgrade_prev": "Upgrade-Leiste links",
		"act.upgrade_next": "Upgrade-Leiste rechts",
		"act.upgrade_buy": "Upgrade kaufen/aktivieren",
		"act.menu": "Menü / Pause",
		"act.precision": "Präzisionsmodus",
		"act.ui_accept": "Bestätigen",
		"act.ui_cancel": "Zurück",
		"act.ui_up": "Menü auf",
		"act.ui_down": "Menü ab",
		"act.ui_left": "Menü links",
		"act.ui_right": "Menü rechts",

		# --- Credits ---
		"credits.title": "Credits",
		"credits.body": "Stingforge\nEvolve. Adapt. Strike.\nEin eigenständiges Bienen-Shoot’em-up, inspiriert von Apidya (Kaiko, 1992).\n\nDesign, Code, Pixelgrafik, Musik und Sound: Team Stingforge\nHauptmenü-Hintergrund und Stingforge-Logo: vom Nutzer bereitgestellt\nEngine: Godot Engine 4.7.2\n3D-Vorlagen und Tiefenebenen: Blender 5.2\nPixelarbeit und Animationen: Aseprite 1.3.18\nSoundtrack: sfizz und Csound mit VSCO 2 CE und VCSL (CC0)\nSprachansagen: Qwen3-TTS\nSchriften: Jersey 10, Silkscreen, Pixelify Sans, Nunito, Oxanium (SIL OFL 1.1)\n\n© 2026 floppi77 · Code: PolyForm Noncommercial 1.0.0 · Inhalte: CC BY-NC-SA 4.0\nGodot Engine: MIT-Lizenz, © 2014-present Godot Engine contributors,\n© 2007-2014 Juan Linietsky, Ariel Manzur\n\nDank an Kaiko und Chris Hülsbeck für das Original.",
		"credits.hint": "B oder Esc: zurück",

		# --- Training ---

		# --- Checkpoint ---
		"cp.reached": "Checkpoint erreicht",
		"cp.before_boss": "Checkpoint vor dem Boss",
	},
}

func t(key: String, args: Array = []) -> String:
	var s := tx(String(STRINGS["de"].get(key, key)))
	if args.size() > 0:
		return s % args
	return s
