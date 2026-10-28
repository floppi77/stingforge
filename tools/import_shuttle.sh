#!/usr/bin/env bash
# Importiert neue Grafik-/Schriftdateien über ein Hilfsprojekt und kopiert die
# Ergebnisse in den Projektcache.
#
# Grund: In dieser Umgebung führt `godot --import` im Hauptprojekt keine
# Neuimporte aus (der Importdienst startet nicht). Ein kleines Projekt mit
# gleichem res://-Pfad importiert dagegen zuverlässig; die erzeugten Dateien
# (.import, .ctex/.fontdata, .md5) sind pfadgebunden und lassen sich
# unverändert übernehmen.
#
# Aufruf: tools/import_shuttle.sh assets/sprites/neu.png [weitere ...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH="$ROOT/tests/_shuttle"
if [ "$#" -eq 0 ]; then
	echo "Aufruf: tools/import_shuttle.sh <pfad> [...]" >&2
	exit 2
fi
rm -rf "$SH"
mkdir -p "$SH"
printf 'config_version=5\n\n[application]\n\nconfig/name="shuttle"\nconfig/features=PackedStringArray("4.7")\n' > "$SH/project.godot"
for f in "$@"; do
	rel="${f#"$ROOT"/}"
	mkdir -p "$SH/$(dirname "$rel")"
	cp "$f" "$SH/$rel"
done
# Godot stürzt beim Beenden gelegentlich ab, nachdem der Import fertig ist. Maßgeblich
# ist deshalb, ob die Importdateien entstanden sind (Prüfung unten), nicht der Rückgabewert.
( cd "$SH" && XDG_DATA_HOME="$ROOT/.godot_data" godot --headless --path . --import > "$ROOT/.godot_data/shuttle.log" 2>&1 ) \
	|| echo "Hinweis: Godot endete mit Fehlercode $?, Importergebnis wird geprüft" >&2
copied=0
for f in "$@"; do
	rel="${f#"$ROOT"/}"
	base="$(basename "$rel")"
	[ -f "$SH/$rel.import" ] || { echo "kein Import für $rel" >&2; continue; }
	cp "$SH/$rel.import" "$ROOT/$rel.import"
	for art in "$SH/.godot/imported/$base"-*; do
		[ -e "$art" ] || continue
		cp "$art" "$ROOT/.godot/imported/"
	done
	copied=$((copied + 1))
	echo "importiert: $rel"
done
rm -rf "$SH"
[ "$copied" -gt 0 ] || { echo "keine Datei importiert" >&2; exit 1; }
