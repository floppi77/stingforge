extends Node
## Prüfwerkzeug: Anzeige-Einstellungen (Skalierung, Auflösungsliste, Übernehmen).

const UiTheme := preload("res://scripts/core/ui_theme.gd")

var fails: Array[String] = []
var checks := 0

func _ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  OK   %s" % what)
	else:
		fails.append(what)
		print("  FAIL %s" % what)

func _ready() -> void:
	await get_tree().process_frame
	var app := get_tree().root.get_node_or_null("App")
	await get_tree().create_timer(0.8).timeout

	# --- 1. Skalierung hängt nicht von der Fenstergröße ab
	Save.set_g("display.ui_size", 100)
	Save.set_g("access.font_scale", 1.0)
	var before := UiTheme.size(16)
	get_window().size = Vector2i(2560, 1440)
	await get_tree().process_frame
	await get_tree().process_frame
	var big := UiTheme.size(16)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var small := UiTheme.size(16)
	_ok(before == big and big == small,
		"Schriftgröße bleibt bei jeder Fenstergröße gleich (%d/%d/%d)" % [before, big, small])
	_ok(UiTheme.size(540) == 540, "Höhe von 540 Canvas-Einheiten bleibt 540 (%d)" % UiTheme.size(540))

	# --- 2. Auflösungsliste passt zum Monitor
	var usable := DisplayServer.screen_get_usable_rect(0).size
	var opts: Array = app.resolution_options()
	var labels: Array = app.resolution_labels()
	var fits := true
	for r in opts:
		var v: Vector2i = r
		if v.x > usable.x or v.y > usable.y:
			fits = false
	_ok(fits, "alle Angebote passen auf den Monitor (%s von %s)" % [str(opts), str(usable)])
	_ok(labels.size() == opts.size(), "zu jeder Auflösung gibt es eine Beschriftung")
	_ok(String(labels[0]).contains("×"), "Beschriftung nennt Breite × Höhe (%s)" % String(labels[0]))

	# --- 3. Auswahl wird gestuft, nicht sofort angewendet
	app.clear_screens()
	app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
	await get_tree().create_timer(0.4).timeout
	var set_screen: Control = app.screens[-1]
	var saved_before := int(Save.g("display.resolution", 2))
	set_screen._adjust_choice("resolution", -1)
	var staged_val: Variant = set_screen.staged.get("display.resolution", null)
	_ok(staged_val != null, "Auflösung wird erst vorgemerkt")
	_ok(int(Save.g("display.resolution", 2)) == saved_before,
		"gespeicherte Auflösung bleibt bis zum Übernehmen unverändert")
	if staged_val != null:
		_ok(staged_val is int, "vorgemerkt wird ein Listen-Index (%s)" % str(staged_val))
		var opts2: Array = app.resolution_options()
		var want_vec: Vector2i = app.RESOLUTIONS[int(staged_val)]
		_ok(opts2.has(want_vec), "vorgemerkte Auflösung ist wählbar (%s)" % str(want_vec))
		var want_idx := clampi(app.resolution_index() - 1, 0, opts2.size() - 1)
		_ok(opts2[want_idx] == want_vec,
			"links geht genau eine Stufe zurück (Index %d, %s)" % [want_idx, str(want_vec)])
		set_screen.apply_staged_display()
		await get_tree().create_timer(0.35).timeout
		_ok(set_screen.staged.is_empty(), "nach dem Übernehmen ist nichts mehr vorgemerkt")
		_ok(int(Save.g("display.resolution", -1)) == int(staged_val),
			"übernommener Index ist gespeichert (%s)" % str(Save.g("display.resolution", -1)))

	# --- 3b. Weg der Eingabe: links/rechts merkt vor, ohne Dialog
	app.clear_screens()
	app.push_screen("res://scripts/screens/settings_screen.gd", {"from": "main"})
	await get_tree().create_timer(0.4).timeout
	var sc: Control = app.screens[-1]
	var before_idx := int(Save.g("display.resolution", 2))
	sc._adjust(1)
	var dialog := app._display_confirm != null
	_ok(not dialog, "rechts öffnet keine Rückfrage mehr")
	_ok(int(Save.g("display.resolution", 2)) == before_idx, "rechts ändert die gespeicherte Auflösung nicht")
	_ok(not sc.staged.is_empty(), "rechts merkt die neue Auflösung vor")
	if not sc.staged.is_empty():
		sc._activate()
		await get_tree().create_timer(0.4).timeout
		_ok(app._display_confirm != null, "Leertaste übernimmt und zeigt die Rückfrage")
		app.revert_display_now()
		await get_tree().create_timer(0.3).timeout
		_ok(int(Save.g("display.resolution", 2)) == before_idx,
			"Zurückstellen macht die Änderung rückgängig")

	# --- 4. Rückfrage: Titel mit Countdown, links/rechts bedienbar
	var conf: Control = app._display_confirm
	if conf == null:
		app.begin_display_test({"display.resolution": saved_before})
		await get_tree().create_timer(0.3).timeout
		conf = app._display_confirm
	_ok(conf != null, "Rückfrage erscheint nach dem Übernehmen")
	if conf != null:
		var foot: String = (conf.footer_label as Label).text
		_ok(foot.contains("15") or foot.contains("14"), "Fußzeile zeigt den Countdown (%s)" % foot)
		_ok(String((conf.title_label as Label).text) == Loc.t("set.confirm_title"),
			"Titel bleibt kurz (%s)" % String((conf.title_label as Label).text))
		conf.on_adjust(0, 1)
		_ok(int(conf.focus) == 1, "rechts wählt die zweite Antwort (Fokus %d)" % int(conf.focus))
		conf.on_adjust(1, -1)
		_ok(int(conf.focus) == 0, "links wählt die erste Antwort (Fokus %d)" % int(conf.focus))
		app.confirm_display()
		await get_tree().process_frame
		_ok(app._display_confirm == null, "Behalten schließt die Rückfrage")

	print("ANZEIGE: checks=%d fails=%d" % [checks, fails.size()])
	print("ANZEIGE_OK" if fails.is_empty() else "ANZEIGE_FAIL")
	get_tree().quit(0 if fails.is_empty() else 1)
