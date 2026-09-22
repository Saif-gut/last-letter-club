# Last Letter Club

3D-PC-Prototyp in **Godot 4.7.2 Stable / Forward+**. Langfristig ist eine
Windows-Version zum Download über die eigene Website geplant; Veröffentlichung,
Website, Installer und Updater sind noch nicht Teil dieses Prototyps.
Die Startszene enthält eine begehbare Third-Person-Lobby und zwei einfache
Tischinstanzen. Online sitzen Spieler an ihrer eigenen Kamera; offline bleibt
der ursprüngliche Hotseat-Tisch mit seinen Kamerafahrten erhalten. Der normale
Start verwendet randloses Vollbild; Alt+Enter wechselt in den Fenstermodus.

## Start und Steuerung

`project.godot` in Godot importieren und mit **F5** starten. Die Szenengeometrie
wird aus Grundformen erzeugt, deshalb ist die Szene im Editor weitgehend leer.
Die Maus wird beim Start und bei Rückkehr ins Spielfenster automatisch eingefangen.

Eigenständiger Windows-Testbuild: `builds/windows/LastLetterClub.exe` starten.
Die danebenliegende `.pck` und den Ordner `licenses/` gemeinsam weitergeben;
Godot-Editor und Steam sind nicht erforderlich. Reproduzierbarer Export mit
`scripts/build_windows.ps1`. [Kurzer Zwei-PC-LAN-Test](docs/online_tables.md#lan-test-mit-zwei-pcs).

| Bereich | Taste | Funktion |
| --- | --- | --- |
| Lobby | WASD / Maus / Space | Gehen / Blickrichtung / Springen |
| Lobby | E nahe einem freien Stuhl | Offline Runde beginnen; online Sitz am gewählten Tisch anfragen |
| Lobby | Esc | Maus freigeben / weiterspielen |
| Lobby | F6 | Mature Words: ON / OFF umschalten (Standard: OFF) |
| Lobby | F7 | Difficulty: Normal / Hard / Easy umschalten (offline) |
| Lobby | F8 / F9 / F10 | Host / Join über das IP-Feld / Disconnect |
| Tisch | Buchstaben / Backspace | Englisches Wort eingeben / korrigieren |
| Tisch | Enter | Wort prüfen |
| Tisch | Esc | Eingabe leeren, ohne Zeit oder Herzen zurückzusetzen |
| Tisch | Tab halten | Bestehende Tischübersicht anzeigen |
| Tisch | F5 | Offline Neustart nach Ende; online Host startet/neustartet den eigenen Tisch |
| Tisch | F4 | Aufstehen und zur Third-Person-Lobby zurückkehren |

Offline werden die vier Plätze **nacheinander mit derselben Tastatur** gespielt.
Die private Netzwerklobby unterstützt bis zu 16 Mitglieder und vier Sitze pro Tisch.
Online verwaltet der Host Sitze und vollständige Runden; zwei Tische können parallel
mit getrennten Einstellungen, Timern und Wortketten spielen. Mindestens zwei
belegte Plätze sind zum Start nötig. Einfache Host-Knöpfe starten jeden Tisch;
F6/F7 am Host-Sitz ändern dessen Einstellungen vor/nach einer Runde. F4 ist online
während laufender Runden gesperrt, F10 bleibt möglich. Nach Disconnect steht
das lokale Spiel wieder bereit. Es gibt keine Bots oder finalen Skins.
Netzwerktest: erste Instanz F8, zweite Instanz F9 (Standard-IP `127.0.0.1`).
Esc gibt die Maus zur IP-Eingabe frei. Details und Grenzen:
[Online-Tische und Zustände](docs/online_tables.md) sowie
[Multiplayer-Grundlage](docs/multiplayer_foundation.md).
Die vorhandenen Knöpfe **Host Lobby / Join Lobby / Disconnect** ersetzen bei Bedarf
die Tastenkürzel. Der Host sieht die lokalen LAN-Adressen mit Adapternamen.
Freie verbundene Spieler können über **table_01/table_02 zuschauen** eine laufende
Runde verfolgen: reine Statusanzeige, eigene Lobbykamera, keine Plätze oder Wortrechte.
**Zuschauen beenden** gibt die Teilnahme an einem Tisch wieder frei.
Die Tischszene `scenes/table_prototype/table_prototype.tscn` bleibt mit F6
eigenständig startbar; dort gibt es keine Lobby zum Aufstehen.

## Rundenregeln

- Jeder Platz startet mit **3 Herzen**. Beim Hinsetzen und nach jedem Neustart
  erscheint **3 → 2 → 1** für jeweils eine Sekunde, anschließend **GO** für 0,5 Sekunden.
  Währenddessen sind Worteingabe und Zugtimer gesperrt; der Startbuchstabe steht
  noch nicht fest.
- Nach GO wird ein zufälliger Startbuchstabe aus **A–Z ohne Q, X und Z** gewählt
  und angezeigt. Gleichzeitig beginnen die vollen **10 Sekunden** des ersten Zugs
  und die Worteingabe des aktiven Spielers erhält automatisch den Fokus.
- Weitere Züge dauern ebenfalls **10 Sekunden**, beginnend bei Ankunft der
  Tischkamera (online nach derselben kurzen Wechselpause an der eigenen Sitzkamera).
  Zwischen normalen Zügen gibt es keinen weiteren Countdown.
  Q, X und Z bleiben als Folgebuchstaben der Wortkette erlaubt.
- Ein oder zwei Anfangsbuchstaben bilden die vollständige **Vorgabe**.
  Hinweise stammen aus noch verfügbaren, erlaubten Offline-Wörtern.
  Easy gibt häufig Hinweise, Normal eine Mischung, Hard fast nur einen Buchstaben.
  Details: [Vorgaben und Schwierigkeit](docs/prefixes_and_difficulty.md).
- Enter prüft ein englisches Wort mit der gesamten angezeigten Vorgabe.
  Der letzte Buchstabe eines gültigen Worts gilt für den nächsten Platz.
- Gültige Wörter dürfen innerhalb derselben Runde nicht wiederholt werden.
- Jede ungültige Abgabe kostet **1 Herz**. Das gilt auch für leere Eingaben,
  falsche Anfangsbuchstaben, Wiederholungen und nicht unterstützte Zeichen.
- Die Anzeige wird für 0,22 Sekunden rot und hält das falsche Wort sichtbar.
  Danach wird die Eingabe automatisch vollständig geleert und ist ohne Klick
  sofort wieder beschreibbar. Während des kurzen Feedbacks ist sie gesperrt;
  die ursprüngliche Zeitfrist läuft unverändert weiter.
- Bei **0 Herzen** scheidet der Platz aus. Nach **10 Sekunden ohne gültiges Wort**
  scheidet er sofort aus, auch mit vollen Herzen. An der exakten Zeitgrenze hat
  der Zeitablauf Vorrang vor einer Abgabe.
- Gültige Wörter leuchten kurz grün, dann folgt die vorhandene Kamerafahrt.
  Während Grünfeedback und Fahrt sind Abgaben gesperrt. Ausgeschiedene Plätze
  werden übersprungen. Erst bei Ankunft beginnt die nächste volle Zugzeit.
- Der letzte verbleibende Platz gewinnt; während der Gewinneranzeige ist keine
  Worteingabe möglich. F5 startet eine neue Runde samt Countdown und setzt
  Herzen, ausgeschiedene Plätze, Wortverlauf, Startbuchstabe und Uhr vollständig
  zurück. Der Gewinner beginnt; Mature Words und Schwierigkeit bleiben erhalten.
  Aufstehen beendet die lokale Runde;
  erneutes Hinsetzen beginnt ebenfalls eine neue Runde.

Timer, Anfangsbuchstabe und Herzen der Teilnehmer sind sichtbar. Tab oder
Fokusverlust pausieren die Tischuhr nicht. Die Anzeige über dem aktiven Platz
und das Eingabefeld verwenden weiterhin denselben Text und dieselben Farben.

## Offline-Wörterbuch und Wortfilter

**198.419 Wörter** sind lokal als Godot-Ressource enthalten. Es gibt weder eine
Internet-API noch Downloads während des Spiels. Grundlage ist die offene
[Wordnik Wordlist](https://github.com/wordnik/wordlist) unter MIT-Lizenz.
Copyright und Lizenztext sind im Projekt und in der Wörterbuch-Ressource enthalten.
Details zu fester Quellversion, Verarbeitung, Grenzen und Export:
[Wortliste und Lizenz](docs/word_list.md).

Akzeptiert werden 1–24 Buchstaben A–Z. Groß-/Kleinschreibung und äußere Leerzeichen
werden normalisiert; Bindestriche, Apostrophe, Zahlen und Umlaute sind nicht
zulässig. Die Wortspielliste enthält auch seltene englische Wörter und Flexionen.

**Mature Words: ON / OFF** lässt sich in der Lobby mit **F6** umschalten.
Standard ist OFF: Eine lokale Liste sperrt 1.015 englische Wörter einschließlich
häufiger Wortformen. ON erlaubt diese Wörter nur, wenn auch Wörterbuch,
Anfangsbuchstabe und Wiederholungssperre erfüllt sind. Der Schalter ist während
des Sitzens gesperrt und wird bei Rundenstart übernommen. Beim Aufstehen bleibt
die Auswahl erhalten; ein neuer Programmstart beginnt mit OFF.

Die Sperrliste basiert auf **cuss** unter MIT-Lizenz mit dokumentierten
Projektanpassungen. Es gibt keine Netzwerkabfrage und keine beliebige
Teilwortsuche: Normale Wörter wie `class`, `assassin` und `cocktail` bleiben
gültig. Quelle, Lizenz, Auswahlregeln und Grenzen: [Mature Words](docs/mature_words.md).

## Aufbau

| Datei / Ordner | Aufgabe |
| --- | --- |
| `scenes/main/main.tscn` | Einstieg in die Lobby |
| `scenes/lobby/lobby.gd` | Bestehender Raum, Kollisionen, E/F4 und Kameraübergabe |
| `scenes/lobby/first_person_player.gd/.tscn` | Bestehende Bewegung plus Third-Person-Kamera; historischer Dateiname bleibt erhalten |
| `scenes/table_prototype/table_prototype.gd` | Tisch, Eingabe, Feedback, HUD und bestehende Sitzkamera |
| `scenes/table_prototype/prototype_seat.gd` | Unveränderte Stühle, Platzhalter und 3D-Wortanzeigen |
| `scripts/last_letter_round.gd` | Unabhängige Regeln, Herzen, Frist, Wortverlauf und Gewinner |
| `scripts/word_validator.gd` | Offline-Wortprüfung und Normalisierung |
| `scripts/word_policy.gd` | Aktiver Offline-Mature-Words-Filter |
| `scripts/match_settings.gd` | Mature Words und Schwierigkeit; Rundensnapshot |
| `scripts/prefix_advisor.gd` | Verfügbare Wörter zählen und sinnvolle Präfixe auswählen |
| `scripts/difficulty_profile.gd` | Erweiterbare Wörterbuch-abhängige Hinweisprofile |
| `resources/words/` | Wörterbuch, Originalquelle und MIT-Lizenz |
| `scripts/build_word_list.py` | Reproduzierbarer Neuaufbau der Ressource ohne Netzwerk |
| `scripts/build_mature_word_list.py` | Offline-Neuaufbau der Sperrliste mit Quellenprüfung |
| `scripts/network/` | Private ENet-Lobby, entfernte Platzhalter und einfache Testbedienung |
| `tests/` | Regel-, Tisch-, Lobby-, Präfix-, Schwierigkeits- und Netzwerktests |

Technische Details: [Lobby](docs/lobby_prototype.md), [Tisch](docs/table_prototype.md).
Es wurde kein Git-Repository initialisiert. `.godot/` ist lokaler Cache;
Godot-`.uid`-Dateien neben Skripten gehören dagegen zu den Projektdateien.

## Prüfung

Mit Godot `4.7.2.stable.official.ed1daf0bf` geprüft; aktuelle Phasen und Ergebnisse
stehen im [Entwicklungsbericht](docs/implementation_phases.md).
Grafische Tests laufen mit Forward+ / Vulkan 1.4.341 auf NVIDIA GeForce RTX 5060 Ti.

```powershell
./tests/run_checks.ps1 -Phase final
./tests/run_network_checks.ps1
```

Die erste Serie prüft den Godot-Import, Regeln, Mature Words, Wörterbuch-Präfixe,
Schwierigkeit, Netzwerkfehlerfälle sowie die drei grafischen Tisch-/Lobby-/
Countdown-Tests. Die zweite startet zwei echte Godot-Instanzen mit Forward+ für
Host/Join, Bewegung, Blickrichtung, Springen, getrennte Kameras und Disconnects.
Grafische Tests benötigen Fensterfokus; währenddessen die Testfenster arbeiten lassen.

Die drei Entwicklungsphasen wurden nacheinander geprüft, jeweils vor Beginn der
nächsten Phase. Protokolle liegen unter `.godot/checks-phase1/`, `checks-phase2/`
und `checks-phase3/`. Netzwerkläufe speichern eigene Protokolle und Aufnahmen in
`.godot/network_checks/<Zeitstempel>/`. Weitere Aufnahmen liegen in
`.godot/lobby_checks/`, `prototype_checks/` und `countdown_checks/`.

Unverändert geprüft: Lobbybewegung, Third-Person-Kamera und Kamerakollision,
Springen, Hinsetzen/Aufstehen, 3–2–1–GO, vollständige 10 Sekunden, Wortkette,
3 Herzen, rotes/grünes Feedback, automatische Eingabeleerung, Mature Words,
Wiederholungssperre, Ausscheiden/Überspringen, Gewinner und Rundenneustart.
Der Tischtest enthält einen echten zehnsekündigen Zeitablauf; der Countdown-Test
spielt mit den tatsächlich erzeugten Ein-/Zweibuchstaben-Vorgaben.

Umsetzungsübersicht und Dateien: [Entwicklungsbericht](docs/implementation_phases.md).
