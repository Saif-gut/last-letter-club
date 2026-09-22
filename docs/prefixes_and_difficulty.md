# Wörterbuchgestützte Vorgaben

`required_letter` bleibt der erste Pflichtbuchstabe der Last-Letter-Kette.
`required_prefix` ist die komplette angezeigte und validierte Vorgabe (1–2 Zeichen).
Der letzte Buchstabe einer akzeptierten Eingabe bestimmt weiterhin den nächsten
ersten Pflichtbuchstaben. Die Vorgabe erscheint erst nach dem bestehenden Countdown.

`prefix_advisor.gd` zählt beim ersten Laden des Offline-Wörterbuchs alle Ein- und
Zweibuchstabenpräfixe. Vor jeder Auswahl zieht es gesperrte Mature Words und bereits
verwendete Wörter ab, ohne doppelt abzuziehen. Eine Zweibuchstabenhilfe braucht
mindestens 25 weiterhin gültige Wörter, darunter mindestens 5 mit höchstens
8 Buchstaben. Es werden ausschließlich Präfixe tatsächlicher Wörter gewählt.
Ohne geeignete Kombination bleibt der erste Pflichtbuchstabe allein stehen.

Kurze Wörter dienen vorerst als nachvollziehbarer Näherungswert für Zugänglichkeit;
das vorhandene Wörterbuch enthält keine verlässlichen Häufigkeitsdaten. Eine
Zweibuchstabenhilfe gibt einen Suchhinweis, schränkt aber zugleich die Lösungsmenge
ein. Sie kann daher nicht mehr Lösungen erzeugen als der einzelne Pflichtbuchstabe.
Ist selbst dessen Wortmenge erschöpft, wird die Kette nicht heimlich geändert.

Die Anzeige verwendet „Vorgabe“ und prüft immer das vollständige Präfix. Ein falsches
Präfix durchläuft unverändert Herzverlust, rotes Feedback, automatisches Leeren
und dieselbe weiterlaufende Deadline.

## Schwierigkeiten

F7 schaltet in der Lobby Normal → Hard → Easy → Normal. Standard ist Normal.
`match_settings.gd` hält die Auswahl; beim Hinsetzen und Neustart erstellt der
Tisch eine eigene `difficulty_profile.gd`-Ressource für die Runde. Während des
Sitzens ist F7 gesperrt. Aufstehen und Neustart behalten die Einstellung;
ein Programmneustart beginnt wieder mit Normal. Mature Words bleibt unabhängig.

Die Hint-Wahrscheinlichkeit folgt der verbleibenden Wörterbuchmenge:
`Knappheit = 1 − clamp(kurze Wörter / 600, 0, 1)`.
`Konzentration = kurze Wörter des stärksten geeigneten Präfixes / kurze Wörter`.

| Modus | Grundwert | Knappheitsgewicht | Konzentrationsgewicht | Zusatzbedingung |
| --- | ---: | ---: | ---: | --- |
| Easy | 0,60 | 0,30 | 0,05 | keine |
| Normal | 0,15 | 0,55 | 0,15 | keine |
| Hard | 0 | 0,15 | 0 | höchstens 40 kurze Wörter für den Pflichtbuchstaben |

Die Summe ist auf 0–0,95 begrenzt. Ohne geeignete Kandidaten gibt es nie einen
Hinweis. Unter geeigneten Präfixen wird mit der Quadratwurzel ihrer kurzen
Wortanzahl gewichtet. Somit gibt es Zufallsvariation, aber die Entscheidung
reagiert auf Wörterbuch, Wiederholungen und Mature-Filter, nicht nur den Modus.
Auf dem aktuellen, noch nicht erschöpften Wörterbuch benötigt Hard keine Hilfe.
Weitere Modi können eigene Profilressourcen bereitstellen; Rundenregeln und
Wortvalidierung bleiben davon unabhängig. Die Zahlen sind transparente erste
Spielparameter, noch keine durch Spielertests ausbalancierte Schwierigkeit.

## Tests

Tests: `prefix_rules_test.gd` zählt Wörter unabhängig nach und prüft alle A–Z,
beide Mature-Modi, erschöpfte Mengen, Wortkette und den echten Tisch-Feedbackpfad.
Bestehende feste Wortfolgen in Regressionstests deaktivieren die Hilfen gezielt;
der vollständige Countdown-Ablauftest spielt dagegen mit echten erzeugten Vorgaben.
`difficulty_test.gd` prüft alle Buchstaben und beide Filtermodi mit festem Seed:
von je 5.200 Vorgaben waren 3.191 / 1.149 / 0 zweibuchstabig (Easy / Normal / Hard).
Zusätzlich werden F7, Rundensnapshot und F5-Neustart geprüft.
`tests/run_checks.ps1 -Phase phase2` führt Import, Regeln, Filter, Präfixe,
Schwierigkeit und alle drei grafischen Regressionstests nacheinander aus.
