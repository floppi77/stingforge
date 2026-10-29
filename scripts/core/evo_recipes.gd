extends RefCounted
## Rezeptzeilen für Meisterevolutionen und Verschmelzungen, einheitlich für
## Evolutionswahl, Sammelbuch und Levelwertung:
##   ★ Gezielter Stich + Zielmarkierung = Todesmal      (Meister, gold)
##   ◆ Gezielter Stich + Stakkato-Stachel = Verschmelzung (Verschmelzung, türkis)
## Farben: im Run vorhanden grün, fehlend grau; die angebotene Karte grau und pulsierend,
## wenn sie das Rezept vervollständigt. Ergebnis „???“, solange nicht entdeckt (Profil).

const UiTheme := preload("res://scripts/core/ui_theme.gd")
const MASTER := Color("#ffd666")
const FUSION := Color("#52d6c4")
const HAVE := Color("#8ee6a0")
const MISSING := Color("#a9acc9")

static func hex(c: Color) -> String:
	return "#" + c.to_html(false)

static func owned_ids() -> Array:
	var out: Array = []
	for entry in Save.campaign.get("evolutions", []):
		out.append(String(entry.get("id", "")))
	return out

static func _name(id: String) -> String:
	return Loc.tx(String(Data.evo(id).get("name", id)))

## Ein Rezeptteil: grün (vorhanden), grau (fehlt) oder grau pulsierend (diese Wahl
## schließt das Rezept). Eckige Klammern im Namen werden für BBCode maskiert.
static func _part(id: String, owned: Array, offered: String, completes: bool) -> String:
	var text := _name(id).replace("[", "[lb]")
	if id == offered:
		if completes:
			return "[color=%s][pulse freq=1.6 color=%s ease=-2.0]%s[/pulse][/color]" % [hex(MISSING), hex(Color.WHITE), text]
		return "[color=%s]%s[/color]" % [hex(MISSING), text]
	return "[color=%s]%s[/color]" % [hex(HAVE if owned.has(id) else MISSING), text]

static func master_line(master_id: String, owned: Array, offered := "") -> String:
	var m := Data.master(master_id)
	var a := String(m.parents[0])
	var b := String(m.parents[1])
	var completes := offered != "" and owned.has(b if offered == a else a)
	var result := "[color=%s]%s[/color]" % [hex(MASTER), Loc.tx(String(m.name))] if Save.is_master_seen(master_id) \
		else "[color=%s]???[/color]" % hex(MISSING)
	return "[color=%s]★[/color] %s + %s = %s" % [hex(MASTER), _part(a, owned, offered, completes),
		_part(b, owned, offered, completes), result]

static func fusion_line(a: String, b: String, owned: Array, offered := "") -> String:
	var completes := offered != "" and owned.has(b if offered == a else a)
	var seen := Save.is_fusion_seen(Data.fusion_key(a, b))
	var result := "[color=%s]%s[/color]" % [hex(FUSION), Loc.tx("Verschmelzung")] if seen \
		else "[color=%s]???[/color]" % hex(MISSING)
	return "[color=%s]◆[/color] %s + %s = %s" % [hex(FUSION), _part(a, owned, offered, completes),
		_part(b, owned, offered, completes), result]

## Rezeptzeilen und Kennzeichen für eine angebotene Evolution.
## Rückgabe: {"lines": [BBCode …], "master": schließt ein Meisterrezept, "fusion": verschmilzt}
static func for_offer(id: String) -> Dictionary:
	var owned := owned_ids()
	var lines: Array = []
	var completes_master := false
	var completes_fusion := false
	for link in Data.master_links(id):
		var partner := String(link[0])
		lines.append(master_line(String(link[1]), owned, id))
		completes_master = completes_master or owned.has(partner)
	for partner in Data.synergy_partners(id):
		lines.append(fusion_line(id, String(partner), owned, id))
		completes_fusion = completes_fusion or owned.has(String(partner))
	return {"lines": lines, "master": completes_master, "fusion": completes_fusion}
