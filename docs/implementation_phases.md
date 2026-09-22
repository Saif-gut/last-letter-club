# Entwicklungsbericht – 13.09.2026

Fortlaufender Bericht: Die ersten Abschnitte dokumentieren den damaligen Stand.
Aktuelle Fortsetzung vom 16.09.2026: Windows-Release und Phasen 7–11 am Ende dieser
Datei; Online-Tische, parallele Runden und Zuschauer sind inzwischen implementiert.

Die drei Phasen wurden nacheinander umgesetzt. Vor Beginn der jeweils nächsten
Phase bestand die gesamte zu diesem Zeitpunkt vorhandene Prüfserie. Änderungen
beschränken sich auf Vorgaben, Schwierigkeiten und die private Netzwerklobby;
bestehender Bewegungscontroller, Kamerasysteme, Geometrie, Materialien, Wörterbuch
und Mature-Liste wurden nicht neu gebaut.

## Phase 1: Ein-/Zweibuchstaben-Vorgaben

`required_prefix` ergänzt den unveränderten ersten Kettenbuchstaben. Die gesamte
Vorgabe muss erfüllt sein. Zweite Buchstaben werden ausschließlich aus dem lokalen
Wörterbuch abgeleitet. Mindestens 25 verfügbare Wörter und darunter mindestens
5 kurze Wörter müssen verbleiben; benutzte und bei OFF gesperrte Wörter zählen
nicht mit. Ohne geeignete Kombination bleibt ein einzelner Buchstabe.

Bestanden: Godot-Import, Regeltest, Mature-Test, neuer Präfixtest und die drei
grafischen Tisch-/Lobby-/Countdown-Tests. Danach erst Phase 2.

## Phase 2: Schwierigkeit

F7 wählt Normal (Standard), Hard oder Easy. Profile bestimmen die Hilfe anhand
verbleibender kurzer Wörter und der Verteilung geeigneter Präfixe. Easy bietet
deutlich häufiger Hinweise; Hard nur bei außergewöhnlicher Knappheit. Regeln,
Herzen und Timer hängen nicht von der Schwierigkeit ab. Ein Rundensnapshot schützt
das aktive Profil; Neustart und Aufstehen behalten die Lobbyauswahl bei.

Bestanden: alle vorherigen Prüfungen plus `difficulty_test.gd` einschließlich
5.200 Vorgaben je Modus, beiden Mature-Modi, F7, Snapshot und Neustart. Danach
erst Phase 3. Ergebnisse/Parameter: [Vorgaben](prefixes_and_difficulty.md).

## Phase 3: Private Netzwerklobby

F8 hostet, F9 verbindet über das IP-Feld, F10 trennt. Zwei unabhängige Instanzen
sehen einander und übertragen Bewegung, Yaw, Pitch, Geschwindigkeit und Sprünge.
Jeder steuert nur den eigenen Controller und die eigene Kamera. Entfernte Figuren
sind reine Darstellung. Der Host verwaltet Teilnehmer und verteilt Zustände.

Bestanden: gesamte bisherige Serie, Netzwerkfehlerfälle und zwei echte Prozesse
mit Forward+. Client-Leave, Rejoin, Host-Leave und anschließende Offline-Tischrunde
wurden geprüft. Abschließende gezielte Wiederholungen prüfen zusätzlich Esc im
IP-Feld sowie eine vom Host auf 8 geänderte Kapazität auf dem Client. Der normale
Projektstandard bleibt 16 einschließlich Host.

Die **gemeinsame Tischrunde ist noch nicht synchronisiert**. In verbundenen
Lobbys bleibt Hinsetzen gesperrt. Das verhindert voneinander abweichende lokale
Runden, bis der Host die Regeln übernimmt. Nach Disconnect steht die bestehende
lokale Tischrunde vollständig zur Verfügung. Nächste Schritte für Tischregister,
Sitzbelegung, Zuschauer, autoritative Spielzustände und Reconnect sind in der
[Netzwerkarchitektur](multiplayer_foundation.md) beschrieben.

## Neue und geänderte Dateien

| Dateien | Änderung |
| --- | --- |
| `scripts/prefix_advisor.gd` (neu) | Zählindex, Abzug gesperrter/benutzter Wörter, Kandidaten und Auswahl |
| `scripts/difficulty_profile.gd` (neu) | Erweiterbare Easy-/Normal-/Hard-Profile |
| `scripts/last_letter_round.gd` | `required_prefix` zurücksetzen/erzeugen, vollständige Vorgabe validieren; Kettenbuchstabe erhalten |
| `scripts/word_validator.gd` | Bestehende Präfixprüfung ausdrücklich auf vollständige Vorgabe benennen |
| `scripts/match_settings.gd` | Schwierigkeit zusätzlich zu Mature Words |
| `scenes/table_prototype/table_prototype.gd` | Vorgabe im bestehenden HUD/Feedback, Profil bei Rundenstart übernehmen |
| `scenes/lobby/lobby.gd` | F7, schlichte Testanzeige, Netzwerkanbindung, Remote-Lebenszyklus, Online-Tischsperre |
| `scripts/network/lobby_session.gd` (neu) | ENet, Host-Teilnehmerliste, Pose-Übertragung, Spawn-Zuweisung, Fehler/Disconnect |
| `scripts/network/remote_lobby_player.gd` (neu) | Bestehender Platzhalter als Remote-Körper mit Interpolation/Blickmarker |
| `scripts/network/lobby_network_panel.gd` (neu) | Einfache Host/IP/Join/Disconnect-Testbedienung |
| `tests/prefix_rules_test.gd` (neu) | Wörterbuchmengen, sichere Präfixe, Kette, Feedback, Herz/Timer/Eingabe |
| `tests/difficulty_test.gd` (neu) | Verteilung aller Modi, sichere Auswahl, Lobbywahl und Rundensnapshot |
| `tests/network_edge_test.gd` (neu) | Payloads, Besitz, Fehlerfälle, Timeout, Eingabe, Offline-Rückkehr, Socketfreigabe |
| `tests/network_lobby_test.gd` (neu) | Zwei echte Instanzen; Input, Bewegung, Kamera, Leave/Rejoin, Offline-Tisch |
| `tests/run_checks.ps1`, `tests/run_network_checks.ps1` (neu) | Reproduzierbare Prüfserien mit Fehlerprüfung und Protokollen |
| `tests/round_rules_test.gd`, `mature_words_test.gd`, `prototype_smoke.gd`, `lobby_smoke.gd` | Feste Testwortketten isolieren die ursprünglichen Regeln ohne zufälligen Zweitbuchstaben |
| `tests/countdown_flow.gd` | Spielt und prüft tatsächlich erzeugte vollständige Vorgaben |
| `README.md`, `docs/lobby_prototype.md`, `table_prototype.md`, `word_list.md` | Aktuelle Bedienung, Zuständigkeiten, Tests und künftiger Windows-Vertrieb |
| `docs/prefixes_and_difficulty.md`, `multiplayer_foundation.md`, `implementation_phases.md` (neu) | Auswahlverfahren, Profile, Architektur, Grenzen und dieser Bericht |

Godot erzeugt zusätzlich `.gd.uid` neben neuen Skripten. Diese gehören zum
Projekt; `.godot/` enthält lokale Importdaten, Testprotokolle und Aufnahmen.
Es wurden keine neuen externen Assets oder Wortquellen eingebunden.

## Prüfung am endgültigen Stand

Engine: **4.7.2.stable.official.ed1daf0bf**.
Grafik: **Forward+ / Vulkan 1.4.341 / NVIDIA GeForce RTX 5060 Ti**.

| Prüfung | Ergebnis |
| --- | --- |
| Godot-Import / Skriptkompilierung | PASS |
| `round_rules_test.gd` | PASS |
| `mature_words_test.gd` | PASS |
| `prefix_rules_test.gd` | PASS |
| `difficulty_test.gd` | PASS |
| `network_edge_test.gd` | PASS, einschließlich abschließender IP-Eingabeprüfung |
| `prototype_smoke.gd` – Forward+ | PASS |
| `lobby_smoke.gd` – Forward+ | PASS |
| `countdown_flow.gd` – Forward+ | PASS |
| `network_lobby_test.gd` – zwei Prozesse mit Forward+ | Host PASS / Client PASS, einschließlich Kapazitäts-Snapshot |

Die grafischen Regressionen prüfen weiterhin Bewegung, Maus, Springen,
Kamerakollision/-besitz, E/F4, Countdown, erste volle 10 Sekunden, Wortketten,
Herzen, Zeitablauf, automatisches Leeren mit sofortigem Fokus, beide Mature-Modi,
Duplikate, Ausscheiden/Überspringen, Sieger und Neustart. Aufnahmen der neuen
Vorgabe und beider Netzwerkteilnehmer wurden zusätzlich visuell geprüft.

Prüfserien: `.godot/checks-phase1/`, `.godot/checks-phase2/`,
`.godot/checks-phase3/`. Abschließender Zwei-Prozess-Lauf:
`.godot/network_checks/20260913-143006/`.

Zum damaligen Abschluss offen: Tests zwischen verschiedenen Rechnern/über Internet,
16-Spieler-Last, Lag/Paketverlust, autoritative Online-Tische, Sitz-/Zuschauerstatus
und Wiederherstellung einer früheren Spieleridentität. Online-Tische und Status
sind inzwischen ergänzt; der aktuelle Fortsetzungsstand folgt unten.

## Fortsetzung am 14.09.2026: Online-Phasen 4–6

Ausgangspunkt waren die bereits bestandenen Online-Phasen 1–3: Host-Sitzvergabe,
komplette autoritative Runde und Teilnehmer-/Host-Disconnect. Diese Systeme wurden
weiterverwendet. Die vorhandene Tisch-ID-Registry und die bereits vorbereitete
Kamera für versetzte Tischinstanzen benötigten keinen grundlegenden Neubau.
Technische Details und Bedienung: [Online-Tische](online_tables.md).

### Änderungen

- Phase 4: Zweiter einfacher Tisch im vorhandenen Raum standardmäßig aktiv,
  Auswahl über Nähe/E, Kollisionen pro Instanz, generische Host-Startknöpfe pro
  Tisch. Zwei parallel laufende Host-Modelle mit getrennten Einstellungen,
  Countdowns, Vorgaben, Herzen, Timern, Wortverläufen und Gewinnern geprüft.
- Phase 5: Zentrale abgeleitete Status FREE, SEATED, PLAYING, ELIMINATED;
  `Players: X / 16`, Belegung pro Tisch und eigener Status als einfacher Text.
  16 Registry-IDs und 15 entfernte Avatar-Nodes in einer Instanz geprüft.
- Phase 6: Vorhandenes Adressfeld weiterverwendet, zentrale UDP-Portanzeige 24572,
  explizite Wildcard-Bindung, sichtbare Verbindung-/Kapazitäts-/Tischablehnungen.
  Separate Zuschauerliste und SPECTATING-Status samt neutralen Regeltests vorbereitet.
  Kein Zuschauer-UI, Kamerawechsel oder Snapshot-Abonnement implementiert.

Die Lobby bleibt klein, jeder Tisch besitzt vier Sitze. Keine neue Wortquelle,
Lizenzabhängigkeit, Dienste, Accounts, Design-Assets oder Router-/Firewalländerungen.
Das Offline-Regelmodell, Wörterbuch, Mature-Filter, Schwierigkeit und Bewegung
wurden für diese Fortsetzung nicht umgebaut.

### Geänderte Dateien dieser Fortsetzung

| Datei | Änderung |
| --- | --- |
| `scenes/lobby/lobby.gd` | Zweiter registrierter Tisch, Kollisionen, Tischwahl und blockierter Join-Hinweis |
| `scripts/network/table_service.gd` | Statusableitung, Tischvoll-Ablehnung und unabhängige Zuschauerzuordnung |
| `scripts/network/lobby_session.gd` | Mitgliederzählung, Bindung, Kapazitätsaufnahme/Ablehnung, adressierte Roster |
| `scripts/network/lobby_network_panel.gd` | Einfache Tisch-Startknöpfe, Status/Zähler, Adress-/Porttext, Ablehnungsanzeige |
| `tests/network_parallel_tables_test.gd` (neu) | Vier echte Prozesse, unabhängige Runden, Zustände, gezielter Disconnect/Neustart |
| `tests/player_registry_test.gd` (neu) | 16 IDs, Avatar-Bereinigung, Kapazitäten, Status und Zuschauerisolation |
| `tests/network_capacity_test.gd` (neu) | Echte Aufnahmeablehnung und anschließender Rejoin |
| `tests/network_lobby_test.gd` | Optionales Host-Adressargument für denselben Test über LAN-IP |
| `tests/lobby_smoke.gd` | Eingabetest stellt verlorenen OS-Fensterfokus vor Testeingaben wieder her |
| `tests/run_checks.ps1` | Zusätzlicher Registry-Test im Phasendurchlauf |
| `tests/run_network_checks.ps1` | Konfigurierbare Rollenliste für vier Instanzen |
| `README.md`, `docs/online_tables.md`, `docs/multiplayer_foundation.md`, `docs/lobby_prototype.md`, `docs/table_prototype.md`, `docs/implementation_phases.md` | Aktueller Stand, Bedienung, Tests und Grenzen |

Zu den drei neuen GDScript-Tests gehören die von Godot erzeugten `.gd.uid`-Dateien.
Die zuvor vorbereiteten `table_prototype.gd`, `table_round.gd`, `online_table_view.gd`
und `window_controls.gd` wurden weiterverwendet, nicht erneut geschrieben.

### Phasenprüfung

Phase 4 bestand Import, Regel-/Fehler-/Online-Unit-Tests und alle drei grafischen
Offline-Regressionen (`.godot/checks-multiple-tables/`). Vier echte Instanzen:
`.godot/network_checks/20260914-002022/parallel/`, alle vier PASS. Ein erster
Testlauf hatte eine fehlende Testbarriere zwischen Client-Gewinnerprüfung und
Host-Neustart; diese wurde ergänzt, ohne die Rundenlogik dafür zu ändern.

Phase 5 bestand dieselben Unit-/Regeltests einschließlich Registry-Prüfung.
Grafischer Tischtest und Countdown bestanden; der Lobbytest bestand nach einem
Fokusverlust im Testfenster im Wiederholungslauf mit expliziter Fokusprüfung
(`.godot/checks-player-states/lobby_smoke-retry.log`). Netzwerk-Regression mit
Repeat/Crash Host/Crash Client: `20260914-002802`, alle PASS. Vier Instanzen mit
Statusprüfungen: `20260914-002847/parallel`, alle PASS. Erst danach begann Phase 6.

Phase 6: Zuschauer-/Registry-Test und echter Kapazitätsfehler-/Rejoin-Test bestanden
bereits vor der abschließenden Gesamtprüfung (`20260914-003125/capacity`).

### Abschließende Ergebnisse der Phase 6

Alle folgenden Prüfungen liefen auf dem endgültigen Stand mit Godot
`4.7.2.stable.official.ed1daf0bf`, grafisch mit Forward+ / Vulkan 1.4.341 /
NVIDIA GeForce RTX 5060 Ti:

| Prüfung | Ergebnis / lokales Protokoll |
| --- | --- |
| Import, Regeln, Mature Words, Präfixe, alle Schwierigkeiten, Netzwerkfehler, Online-Regeln, Rundendisconnect, Registry/Zuschauer | PASS – `.godot/checks-lan-spectator/` |
| Offline-Tisch, Lobbybewegung/Kamera und vollständiger Countdown-/Rundenablauf | PASS – gleicher Ordner, drei grafische Tests |
| Host/Join, Bewegung, Rotation, Springen, Leave/Rejoin, harte Host-/Client-Abbrüche | PASS – `20260914-003410/{repeat,crash_host,crash_client}` |
| Gemeinsame Sitzplätze, Kamerabesitz, Aufstehen/Wiederbeitritt | PASS – `20260914-003454/seating` |
| Gemeinsame Runde, Eingabeleerung/Fokus, Host-Timer, Wortkette, Herzen, Wiederholung, Ausscheiden, Gewinner, Neustart | PASS – `20260914-003459/round` |
| Disconnect wartend/aktiv/am Host und Neuverbindung | PASS – `20260914-003523/round-loss` |
| Vier echte Prozesse, zwei parallele Runden und Status | PASS – `20260914-003619/parallel` |
| Lobby voll, saubere Ablehnung, Wiederbeitritt | PASS – `20260914-003635/capacity` |
| Host/Join, Bewegung/Sprung/Rotation und Reconnect über Ethernet-IP `192.168.0.9` | PASS – `20260914-003640/repeat` |
| Vollständige Online-Tischrunde über dieselbe Ethernet-IP | PASS – `20260914-003655/lan-round` |
| Randloser Start, Alt+Enter, proportionale UI und 3D-Kamera, fokussierte Worteingabe ohne versehentliche Abgabe | PASS – `.godot/window_checks/final.log` |

Netzwerkpfade sind relativ zu `.godot/network_checks/`. Bei der letzten
Vier-Prozess-Prüfung wurde zusätzlich die SEATED-Testprüfung vor das gemeinsame
Startsignal verlegt: Eine vorherige Fassung prüfte teilweise erst nach dem
bereits korrekten Wechsel zu PLAYING. Der Wiederholungslauf bestand für alle
vier Prozesse. An der Spiellogik war dafür keine Änderung nötig.

Die LAN-Testbilder zeigen das tatsächlich eingegebene `192.168.0.9`. Der lokale
UDP-Endpunkt wurde während einer Runde als Wildcard `::`, Port 24572 beobachtet;
die erfolgreiche Verbindung zur Ethernet-IPv4 bestätigt dessen IPv4-Erreichbarkeit
auf diesem Rechner. Die Bilder von Lobby, zweiten Tisch und LAN-Client wurden
visuell geprüft. Der Bewegungs-Regressionslauf setzt absichtlich Kapazität 8 als
Testfixture, um deren Host-Replikation zu prüfen; normale Starts und die anderen
Tests verwenden weiterhin 16.

Vollbild wurde bei nativen 2560×1440 und Fenstern 960×540, 1280×960 und 1600×680
geprüft. Das Skalierungsverhältnis blieb gleichmäßig, die Kamera verzerrte keine
Objektproportionen. Alt+Enter änderte weder Herzen noch Worteingabe oder Deadline.

### Verbleibende Grenzen / technische Schulden

Keine bekannten fehlgeschlagenen Funktionsprüfungen am endgültigen Stand.
Disconnect und Rejoin funktionieren in den geprüften lokalen Szenarien zuverlässig.
Rejoin ist weiterhin eine neue Teilnahme, keine Wiederherstellung der früheren
Identität/des Sitzes. Noch nicht geprüft: zweiter physischer PC, reale WAN-/NAT-
Verbindung, absichtlicher Paketverlust/Lag und 16 echte simultane Verbindungen.
Zuschauer haben erst die interne Zuordnung, noch keine Bedienung oder Ansicht.
Host-Migration, verifizierte Wiederverbindung und endgültige Netzwerk-Härtung
bleiben spätere Arbeit. Der feste kleine Raum, Spawnpunkte und Bewegungsgrenzen
sind weiter ein Prototyp; die Tabelle/Registry kann zusätzliche Instanzen aufnehmen.
Internetvoraussetzungen und Grenzen stehen im Abschnitt LAN/Internet der
[Online-Tisch-Dokumentation](online_tables.md).

## Phase 7: eigenständiger Windows-Build (Fortsetzung 15.09.2026)

Der vorhandene Windows-x86_64-Release-Export unter `builds/windows/` wurde
weiterverwendet. Lieferstruktur: `LastLetterClub.exe`, `LastLetterClub.pck`,
`licenses/` und ein kurzer Starttext. `export_presets.cfg` und
`scripts/build_windows.ps1` erzeugen einen Release ohne Konsolen-Wrapper,
Entwicklertests oder rohe Wortquellen. `builds/` ist bereits in `.gitignore`.
Die offiziellen Godot-4.7.2-Exporttemplates wurden im vorherigen Schritt geladen
und anhand des SHA-256 aus den Release-Metadaten geprüft.

Zwei tatsächliche Release-EXEs wurden ohne laufenden Godot-Editor gestartet und
mit Windows-Eingaben bedient: Host zeigte 1/16, Join 2/16 und Connected / Client;
entfernte Figur sichtbar. Client-Disconnect wechselte sauber nach Offline und
erneutes Join wieder nach 2/16. Kleine Bewegungseingaben wurden im Release geprüft;
die ausführlichen Bewegungs-/Sprung-/Rotationsprüfungen bleiben im Godot-Testlauf.
Beide Release-Fehlerprotokolle waren leer (`.godot/export-checks/host.err`,
`client.err`). Randloses Vollbild und die Lobby wurden visuell bestätigt.

Release-Templates unterstützen den Editor-Schalter `--script` nicht. Der beim
vorherigen Abbruch vorbereitete externe Skript-Testweg wurde deshalb entfernt;
es werden keine Testhaken in die Release-Version eingebaut. Netzwerk-Regressions-
skripte laufen weiterhin mit Godot 4.7.2, Release-Prüfungen am unveränderten EXE/PCK
über echte Fensterbedienung. Die beiden Testprozesse wurden danach beendet.

## Phasen 8–10: LAN, Internet-Planung und Testoberfläche

`host_address.gd` prüft IP-/Hostname-Syntax vor dem Verbindungsaufbau und ermittelt
lokale IPv4-Adapter über Godots `IP.get_local_interfaces()`. Keine externe Abfrage.
Loopback, Link-Local und doppelte Adressen werden ausgefiltert; mehrere Adapter
bleiben mit Namen sichtbar statt einen vermeintlich richtigen zu raten. Derzeit
werden Ethernet, WLAN und ein virtueller WSL-Adapter erkannt. Der Host bleibt an
Wildcard gebunden, Standardport UDP 24572. Adressen werden beim Hoststart erneuert.
Die kurze Anleitung „LAN Test mit zwei PCs“ steht in `docs/online_tables.md`.
Firewall/Router bleiben unverändert; privates Netzwerk muss der Benutzer zulassen.

Phase 8: Import, sämtliche Regel-/Offline-Tests, neue Adress-/Adaptertests und
Registry bestanden (`.godot/checks-phase8`). Erneuter Zwei-Prozess-LAN-Lauf über
192.168.0.9: `20260915-223750/repeat`, Host/Client PASS. Ein physischer zweiter PC
wurde nicht getestet.

Phase 9 ist eine dokumentierte Architekturprüfung ohne Produktcodeänderung:
Discovery/Signaling, NAT-Traversal, Relay und Godot-Spielschicht sind getrennt.
Direktes Internet-ENet setzt öffentliche Erreichbarkeit und oft UDP-Weiterleitung
voraus; CGNAT kann es verhindern. Für echte Codes fehlen ein erreichbarer Resolver,
Einladungsnachweise und eine getestete Verbindungs-/Relay-Strategie. Kein Dienst,
Accountsystem, Fake-Code oder automatische Router-Konfiguration hinzugefügt.

Phase 10 erweitert die vorhandene Oberfläche um eindeutige Bezeichnungen
Host Lobby / Join Lobby und Connecting/Hosting/Connected/Disconnected-Meldungen.
Ungültige Adresse hält den Eingabefokus zur Korrektur. Alle Knöpfe rufen dieselbe
LobbySession auf wie F8/F9/F10; es gibt keine zweite Netzwerklogik.
`network_panel_test.gd` prüft Fehler, Bearbeitungsfokus, Verbindungsabbruch während
Connecting und erneutes Hosten; PASS. Kapazitätsfehler mit zwei echten Prozessen:
`20260915-223930/capacity`, PASS.
Anschließend bestand auch Repeat mit Disconnect/Rejoin und vollständigem
Neuaufbau der Sitzung (`20260915-223935/repeat`, beide Prozesse PASS).

## Phase 11: funktionaler Zuschauerbeitritt (16.09.2026)

Die vorhandene getrennte Zuschauerliste wurde um einen hostgeprüften Beitritts-
und Austrittswunsch ergänzt. Freie Spieler wählen in der bestehenden Testoberfläche
einen laufenden Tisch. Der Host verteilt dessen unveränderte Rundensnapshots
zusätzlich an dessen Zuschauer. Die bisherige Sitzprüfung blockiert Wortabgaben
weiterhin auch bei direktem Aufruf ohne UI. Lobbybewegung und Third-Person-Kamera
bleiben aktiv; es gibt nur eine lesende Textanzeige statt einer neuen Kamera.

Zuschauer erhalten keine eigenen Herzen, keinen Sitz und keinen Zug. Die Anzeige
enthält die Herzen der tatsächlichen Teilnehmer. Beenden/Disconnect entfernt
Abonnement, lokalen Snapshot und Anzeige. Rundenende und Neustart behalten das
Abonnement, ohne die Zuschauer in die eingefrorene Teilnehmerliste aufzunehmen.
Das Offline-Regelmodell, Bewegung und Kameracontroller wurden nicht verändert.

Erster Drei-Prozess-Test bestand für Host, Client und Zuschauer:
`.godot/network_checks/20260916-185314/spectator`. Zusätzlich visuell geprüft:
Status SPECTATING, 2/4 belegte Plätze bei 3 Lobbyspielern, lesender Wortkettenstand
und unveränderte Lobbykamera. Der Test wurde danach um echte Zeitablauf-/Gewinner-
und Neustartprüfung erweitert. Dabei benötigte die wartende Client-Testrolle
35 statt 15 Sekunden für den gesamten Ablauf; nur die Testbarriere wurde angepasst.

### Dateien in Phasen 7–11

| Datei | Änderung |
| --- | --- |
| `export_presets.cfg` | Windows-x86_64-Release mit separater PCK, ohne Konsolen-Wrapper/Testdateien |
| `scripts/build_windows.ps1`, `tests/export_notices.gd` | Reproduzierbarer Export, Lizenzordner und kurze mitgelieferte Start-/LAN-Anleitung |
| `scripts/network/host_address.gd` | Lokale Adressvalidierung und IPv4-Adapteranzeige |
| `scripts/network/lobby_session.gd` | Validierung vor Join, eindeutige Verbindungs-/Fehlermeldungen |
| `scripts/network/lobby_network_panel.gd` | Bestehende Knöpfe/Status präzisiert, LAN-Anzeige, Zuschauerknöpfe und lesender Tischstatus |
| `scripts/network/table_service.gd` | Autorisierte Zuschauerwünsche, gezielte Snapshot-Verteilung und Bereinigung |
| `tests/host_address_test.gd`, `tests/network_panel_test.gd` | Syntax, Adapter, Fehlerzustände, Fokus und erneute Bedienbarkeit |
| `tests/network_spectator_test.gd` | Drei echte Prozesse: Zuschauen, unberechtigte Abgabe, Timer-/Regelisolation, Gewinner, Neustart, Austritt/Disconnect |
| `tests/run_checks.ps1` | Neue Adress- und Bedienungsprüfungen in bestehender Prüfserie |
| `README.md`, `docs/online_tables.md`, `docs/multiplayer_foundation.md`, `docs/implementation_phases.md` | Build, LAN-Anleitung, Internetarchitektur, Zuschauerstand und Nachweise |

Zu neuen GDScript-Dateien gehören die erzeugten `.gd.uid`-Dateien. Es gibt keine
neuen Design-Assets, Wortquellen, externen Dienste oder Laufzeitabhängigkeiten.
Der Release bleibt `LastLetterClub.exe` + `LastLetterClub.pck` + `licenses/`,
ergänzt um `START.txt`. Lokale Prüfprotokolle werden nicht mitgeliefert.

### Abschlussprüfung vom 16.09.2026

Engine unverändert `4.7.2.stable.official.ed1daf0bf`; grafische Tests und
Mehrprozessläufe mit Forward+ / Vulkan 1.4.341 / NVIDIA GeForce RTX 5060 Ti.

| Prüfung | Ergebnis / lokales Protokoll |
| --- | --- |
| Import, Offline-Regeln, Mature Words, Präfixe, alle Schwierigkeiten, Netzwerkfehler, Online-Regeln/Disconnect, Adressen/UI, 16-ID-Registry | PASS – `.godot/checks-phase11-final/` |
| Grafischer Offline-Tisch | PASS – `prototype_smoke.log` im selben Ordner |
| Drei echte Prozesse mit Zuschauer, unberechtigten Abgaben, echter 10-Sekunden-Elimination, Gewinner/Neustart und Zuschauer-Disconnect | Alle PASS – `20260916-190004/spectator` |
| Bewegung/Sprung/Rotation, Rejoin, erneutes Host+Join und harte Host-/Client-Abbrüche | PASS – `20260916-190026/{repeat,crash_host,crash_client}` |
| Gemeinsame Sitze und Kamerabesitz | PASS – `20260916-190110/seating` |
| Vollständige Online-Runde, Feedback/Fokus, Herzen, Timer, Wortkette, Wiederholung, Gewinner und Neustart | PASS – `20260916-190115/round` |
| Disconnect wartend/aktiv, Host-Ende und Neuverbindung | PASS – `20260916-190139/round-loss` |
| Vier echte Prozesse, zwei parallele Tische mit getrennten Einstellungen/Runden und gezieltem Disconnect/Neustart | Alle PASS – `20260916-190154/parallel` |
| Kapazitätsablehnung und erneuter Join | PASS – `20260916-190209/capacity` |

Netzwerkpfade sind relativ zu `.godot/network_checks/`.
Die ersten grafischen Lobby-Wiederholungen und der erste erneute Ethernet-Lauf
waren durch veränderte Blickrichtung/Fensterfokus gestört (sichtbar im Spawn-Bild
bzw. explizitem Fokus-Fehler); diese Läufe werden nicht als bestanden gezählt.
Controller und Kamera wurden dafür nicht geändert. Isolierte Abschlussläufe
und der abschließende Release-Nachweis werden nachfolgend separat aufgeführt.

Isolierte Abschlussläufe: `lobby_smoke-isolated.log`, `countdown_flow.log` und
`window_check.log` unter `.godot/checks-phase11-final/` jeweils PASS, ohne Fehler.
Die Fensterprüfung bestätigt randlosen Start mit nativen 2560×1440, proportionale
UI/3D-Projektion bei 960×540, 1280×960 und 1600×680 sowie Alt+Enter während
fokussierter Worteingabe ohne Abgabe, Herzverlust oder veränderte Zeitfrist.
Ethernet-Wiederholung über `192.168.0.9`: `20260916-190358/repeat`, Host/Client PASS.

Der Release wurde anschließend mit den Änderungen aus Phasen 8–11 aktualisiert.
Export-/Import-/Lizenzprotokolle in `.godot/export-cache/` enthalten keine Fehler
oder Warnungen. EXE: 109.127.680 Bytes, separate PCK: 2.875.796 Bytes. Der Ordner
enthält ausschließlich EXE, PCK, START.txt und drei Lizenzdateien unter `licenses/`.
SHA-256 der PCK: `C032317817A58E0340D082EC3F58784461E2C0C7C8AB94D3ED5F9A67B8B889D5`.

Zwei tatsächliche aktualisierte Release-EXEs wurden mit Windows-Fenstereingaben
getestet: nativer Vollbildstart, Host 1/16, Join über 127.0.0.1 mit 2/16,
Client-Disconnect über den sichtbaren Knopf, Host zurück auf 1/16, Rejoin 2/16,
Host-F10 und automatische Offline-Rückkehr des Clients. Anschließend erneut
Host gestartet und mit dem sichtbaren Join-Lobby-Knopf erfolgreich verbunden.
Die neue LAN-Anzeige zeigt `192.168.0.9 (Ethernet)`; beide Tisch- und Zuschauer-
Knopfreihen sind vorhanden und bei leeren Tischen korrekt gesperrt.
Beide Release-Logs bestätigen Godot 4.7.2 / Forward+; beide `.err` sind leer
(`.godot/export-checks/phase11/`). Die eigenen Testprozesse wurden danach beendet.
Ausführliche Bewegungs-, Runden- und Zuschauertests sind die obigen Godot-Prozesse;
die Release-Prüfung behauptet keine darüber hinaus manuell gespielte Tischrunde.

### Abschlussstand und nächste externe Prüfung

Phasen 7–11 sind abgeschlossen. Der vollständige Ordner `builds/windows/` ist
für den Zwei-PC-LAN-Test vorbereitet. Kurzablauf steht in dessen `START.txt` und
unter „LAN Test mit zwei PCs“ in `docs/online_tables.md`. Privates Netzwerk und
UDP 24572 müssen erreichbar sein; keine Firewall-/Routerregel wurde verändert.

Disconnect/Rejoin und neuer Sitzungsaufbau funktionieren in den geprüften lokalen
Szenarien zuverlässig. Noch nicht geprüft: zwei physische PCs, reale Internet-/NAT-
Verbindung, absichtlicher WAN-Lag/Paketverlust und 16 gleichzeitige echte Clients.
Ein Rejoin bleibt eine neue Teilnahme; Host-Migration ist nicht implementiert.
Direktes Internet-ENet setzt erreichbaren Host/gegebenenfalls Portweiterleitung
voraus; für einen echten Join-Code fehlen Resolver/Signaling und eine getestete
Direkt-/Relay-Verbindungsstrategie. Hier wurde keine externe Infrastruktur gebaut.
