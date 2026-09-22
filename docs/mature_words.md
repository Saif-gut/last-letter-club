# Mature Words: ON / OFF

F6 schaltet in der Lobby **Mature Words: ON / OFF** um. Standard ist OFF.
Die Anzeige ist eine funktionale Test-Einstellung, kein finales Menü.
OFF lehnt Einträge der lokalen Sperrliste als ungültig ab: ein Herz geht verloren,
rotes Feedback erscheint, die Frist läuft weiter und das Eingabefeld wird danach
automatisch geleert. ON erlaubt diese Wörter nur bei gültigem englischem Wort,
passendem Anfangsbuchstaben und ohne Wiederholung innerhalb der Runde.

## Quelle und Lizenz

- Quelle: [words/cuss – englische Liste](https://github.com/words/cuss)
- Feste Revision: `6bab3fef250481e34ba55bc400fac5c6d25f1429`
- Originaldatei: [index.js](https://github.com/words/cuss/blob/6bab3fef250481e34ba55bc400fac5c6d25f1429/index.js)
- Lokale unveränderte Kopie: `resources/words/cuss_source.js`
- SHA-256: `1d18ada207c6551513c767492b9441619ceea0dfe0895552410040ee0c937223`
- Abruf: 13.09.2026
- Lizenz: **MIT**, Copyright (c) 2016 Titus Wormer.
  [Vollständiger Original-Lizenztext](../resources/words/CUSS_LICENSE.txt)

Die MIT-Lizenz erlaubt auch kommerzielle Nutzung und Änderungen unter Beibehaltung
des Copyright- und Lizenzhinweises. Beide sind als Datei mitgeliefert und zusätzlich
in der geladenen Godot-Ressource enthalten. Die Daten werden lokal aufbereitet;
es wird weder ein npm-Paket installiert noch fremder JavaScript-Code ausgeführt.

## Dokumentierte Projektanpassungen

`python scripts/build_mature_word_list.py` erzeugt `resources/words/mature_words.tres`
reproduzierbar ohne Netzwerk aus der fixierten Quelle und den Projektentscheidungen
in `resources/words/mature_overrides.json`.

Die Quelle enthält 1.795 bewertete Wörter und Phrasen. Ihre Bewertung beschreibt
die Wahrscheinlichkeit anstößiger Verwendung, nicht deren Schwere. Auswahl:

1. Englische Einzelwörter mit Quellbewertung **2** werden übernommen.
2. Die explizite Include-Liste ergänzt gebräuchliche Schimpfwörter und Beleidigungen,
   die die Quelle teils nur wegen möglicher anderer Bedeutungen mit 1 bewertet,
   etwa `shit`, `bitch`, `bastard`, `damn`. Weitere Projektentscheidungen sind in
   derselben Datei nachvollziehbar. `cocky` wird ausdrücklich ausgenommen.
3. Häufige Endungen werden ergänzt: s/es, ed/ing, er/ers, y/ly, ier/iest,
   ness/less sowie einfache e-/y-/Doppelkonsonantenvarianten. Kandidaten werden
   ausschließlich übernommen, wenn sie bereits in unserem englischen Wörterbuch
   stehen und 1–24 Buchstaben A–Z haben. Von der Quelle ausdrücklich mit 0
   bewertete Wörter bleiben ohne expliziten Include-Eintrag erlaubt.
4. Die Ausgabe wird dedupliziert und sortiert: aktuell **1.015 gültige Wörter**.

Die Abfrage vergleicht vollständige normalisierte Wörter. Es gibt keine beliebige
Teilwortsuche und keine Ableitung neuer Wörter während des Spiels. Deshalb bleiben
zum Beispiel `class`, `assassin`, `cocktail`, `analysis` und `grape` gültig.
Neutrale Identitätsbegriffe wie `gay`, `lesbian`, `homosexual`, `black` und `white`
werden nicht pauschal gesperrt und sind in beiden Modi getestet.

Das ist eine klar definierte Wortspielregel auf Listenbasis, keine Kontextanalyse
oder universell vollständige Erkennung jeder Beleidigung. Einzelne Begriffe können
je nach Zusammenhang auch harmlose Bedeutungen haben. Die Quelle selbst warnt vor
pauschalem Einsatz als allgemeinem Textfilter. Dieses Spiel prüft einzelne Wörter;
die transparente Include-/Exclude-Liste ermöglicht spätere gezielte Korrekturen.

## Architektur und Export

`match_settings.gd` beschreibt die Partieeinstellung. Der lokale Lobby-Schalter
ändert sie nur vor dem Hinsetzen. `enter_table()` kopiert sie in die Policy der
aktiven Runde. Änderungen an der Konfiguration beeinflussen somit keine laufende
Runde; neue Runden und Wiederbeitritte übernehmen den gewählten Wert.
Ein zukünftiger Host kann dieselbe Konfiguration bereitstellen. Es gibt noch
keine Netzwerk- oder Host-Implementierung und keine dauerhafte Benutzereinstellung.

`word_policy.gd` lädt die Sperrliste mit `preload`. Die Godot-Ressource enthält
Wörter, Quell-URL und MIT-Lizenz und wird über die normale Abhängigkeitskette in
Exporte aufgenommen. Runtime-Zugriffe sind reine Dictionary-Abfragen im Speicher.
Die vorhandene Wordnik-Liste und ihre Lizenz bleiben davon getrennt.

## Verifikation

Mit Godot **4.7.2 Stable** geprüft; grafische Tests mit **Forward+**, Vulkan 1.4.341,
NVIDIA GeForce RTX 5060 Ti. Die Tests prüfen:

- Alle 1.015 Filterwörter bei OFF und ON sowie Copyright in der Ressource.
- Echte gefilterte Wörter, Wortformen, Normalisierung, normale Wörter in beiden
  Modi und Schutz vor Teilwort-Falschpositiven.
- Fantasiewörter, falsche Initialen und Wiederholungen bleiben in beiden Modi ungültig.
- Gefiltertes Wort bei OFF: genau ein Herz verloren, unveränderte Zugfrist,
  automatisches Leeren und anschließende normale Abgabe.
- Gültiges gefiltertes Wort bei ON: kein Herzverlust, korrekter nächster Buchstabe,
  Folgezug und Wiederholungsverbot.
- Rotes Feedback → leeres Eingabefeld → sofortiges Tippen ohne weitere Bedienung.
- Kein zusätzliches Leeren akzeptierter Wörter; kein späteres Löschen in einer
  neuen Sitzung; Zeitablauf während Rot reaktiviert keine ausgeschiedene Figur.
- Bestehende Herzen, Ausscheiden, Gewinner, Kamerafahrten, Lobbybewegung und
  Hinsetzen/Aufstehen sowie funktionaler F6-Schalter.

Testdateien: `tests/mature_words_test.gd`, `tests/round_rules_test.gd`,
`tests/prototype_smoke.gd`, `tests/lobby_smoke.gd`.
