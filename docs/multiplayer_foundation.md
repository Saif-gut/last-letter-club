# Private Netzwerklobby – Phase 3

## Stabilitätsnachtrag: Status und wiederholte Verbindungen

Die bestehende Statuszeile zeigt jetzt ausdrücklich **Network: Offline**, **Host**
oder **Connected / Client**, unabhängig vom zusätzlichen Hinweistext. Während
eines noch ausstehenden Join bleibt der Zustand Offline mit „Verbinde …“ als
Zusatz. Die vorhandene Difficulty-Zeile zeigt weiterhin Easy, Normal oder Hard.

Alle Sitzungsenden räumen Teilnehmer, Slots, Empfangszeiten, Sequenzzähler und
die zwischengespeicherte lokale Pose auf. Das neue `session_ended`-Signal aktiviert
die lokale Maussteuerung auch bei einem asynchronen Host-Abbruch wieder. Es holt
kein fremdes Fenster in den Vordergrund; beim Zurückkehren greift die vorhandene
Fokusbehandlung des Spielers. Der lokale Controller und das Tischspiel bleiben
unverändert.

Verbundene ENet-Peers verwenden einen Timeout-Faktor von 32, 3.000 ms Minimum
und 8.000 ms Maximum sowie 500 ms Ping-Intervall. Das begrenzt die Erkennung eines
ausgefallenen Gegenübers auch ohne geordnete Disconnect-Nachricht. Grundlage:
[ENetPacketPeer.set_timeout](https://docs.godotengine.org/en/stable/classes/class_enetpacketpeer.html#class-enetpacketpeer-method-set-timeout).
Wenn nur ein Client verschwindet, bleibt der überlebende Host natürlich **Host**;
erst das Beenden seiner eigenen Sitzung schaltet ihn auf **Offline**.

`run_network_checks.ps1` prüft jetzt drei getrennte Szenarien mit jeweils zwei
echten Forward+-Instanzen:

1. Host/Join, beidseitige Bewegung, Client-F10, Rejoin samt erneuter Bewegung,
   Host-F10, vollständiger Neustart von Host/Join und nochmals beidseitige Bewegung.
2. Host-Prozess wird ohne `leave()`/Socket-Cleanup abrupt beendet; Client erkennt
   den Ausfall, entfernt die Figur, kann weiterlaufen/springen und erneut hosten.
3. Client-Prozess wird ebenso abrupt beendet; Host entfernt ihn, kann seine Sitzung
   beenden, weiterlaufen/springen und erneut hosten.

Jede Bewegungsprüfung umfasst Rotation, Blickneigung, Sprung, Landung und den
lokalen Kamerabesitz. Der Beobachtungsverlauf wird pro Verbindung zurückgesetzt;
alte Samples können keinen Rejoin-Test bestehen lassen. Die Bereinigung prüft
sowohl die Teilnehmer-Dictionaries als auch echte verbleibende Remote-Nodes.
Am Ende wird der Offline-Tisch mit Countdown erneut betreten.

Bestanden unter Godot **4.7.2.stable.official.ed1daf0bf / Forward+**.
Netzwerkprotokolle: `.godot/network_checks/20260913-144125/` mit Unterordnern
`repeat`, `crash_host`, `crash_client`. Die absichtlich beendeten Prozesse werden
als Crash-Testfälle gewertet, alle überlebenden Instanzen müssen regulär PASS
melden. Das ist ein lokaler Ausfalltest, noch kein Internet-/Paketverlusttest.

Auch die komplette Regression `run_checks.ps1 -Phase network-stability` besteht:
Import, Regeln, Mature Words, Präfixe, Schwierigkeiten, Netzwerkfehlerfälle und
die grafischen Tisch-, Lobby- und Countdown-Tests. Protokolle liegen unter
`.godot/checks-network-stability/`. Damit bleiben insbesondere Offline-Tisch,
Wortkette, Herzen, Timer, Eingabeleerung und Rundenneustart geprüft.

Geändert für diesen Schritt: `lobby_session.gd`, `lobby_network_panel.gd`,
`network_lobby_test.gd`, `run_network_checks.ps1` und dieser Dokumentationsnachtrag.
Keine Online-Tischlogik oder Übertragung von Rundenwerten ergänzt.

## Ausprobieren

Zwei Instanzen derselben Projektversion mit Godot 4.7.2 / Forward+ starten.
In Instanz A **F8 / Host**, in Instanz B **F9 / Join**. Die voreingestellte IP
`127.0.0.1` verbindet beide auf demselben Computer. Für einen anderen Rechner im
LAN: Esc drücken, dessen Host-IP in das kleine Feld eingeben, Join anklicken.
Enter im IP-Feld verbindet ebenfalls. **F10 / Disconnect** trennt die Sitzung.
WASD, Maus, Space und Esc bleiben die vorhandenen lokalen Bedienelemente.

Der Testport ist **UDP 24572**. Für LAN-Verbindungen muss der Host über seine
LAN-IP erreichbar sein und die Windows-Firewall den Godot-/Spielprozess zulassen.
Für Verbindungen über das Internet braucht es einen erreichbaren Host, gewöhnlich
eine UDP-Portweiterleitung oder ein gemeinsames privates Netzwerk. Es gibt noch
keinen Relay-Dienst, NAT-Traversal, Join-Code, Login oder Zugriffspasswort.
Es wurden keine Firewall- oder Routereinstellungen automatisch geändert.
Netzwerkgrundlage: [Godot High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
und [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html).

## Was bereits funktioniert

- Host und Clients laufen gleichzeitig im vorhandenen Raum. Jeder steuert nur
  den eigenen CharacterBody und die eigene Third-Person-Kamera.
- Der Host verwaltet die Teilnehmerliste. Remote-Platzhalter zeigen Position,
  Drehung und Kopf-Blickrichtung; Sprünge werden über Position und Geschwindigkeit
  übertragen. Ein einfacher Fortsatz am Kopf macht die Blickrichtung sichtbar.
- Übertragung mit 20 Hz; entfernte Figuren werden zwischen empfangenen Zuständen
  weich nachgeführt. Sie besitzen keine Kamera und keine Eingabelogik.
- Neue Teilnehmer bekommen einen freien Spawn-Slot; bestehende Teilnehmer und
  Nachzügler erhalten eine vollständige Liste. Leave entfernt die entfernte Figur.
- Join-Fehler, belegter Port und nach 8 Sekunden nicht erreichbare Hosts führen
  zu einer einfachen Statusmeldung. Disconnect und Szenenende schließen den Socket.
- Nach einem Disconnect ist erneutes Join möglich. Das ist eine neue Teilnahme,
  noch keine Wiederherstellung einer früheren Identität oder Tischposition.
- Verlässt der Host die Sitzung, kehren Clients in den Offlinezustand zurück.
  Es gibt noch keine Host-Migration.

**Gemeinsame Tischrunden sind inzwischen online.** Nach erfolgreichem Join fragt E
einen Sitz am nahen Tisch an. Der Host führt jede Tischrunde unabhängig aus;
Clients senden nur Eingabeabsichten. Nach Disconnect funktioniert die bisherige
lokale Vierer-Runde wieder. Offline-Schwierigkeit und Mature Words bleiben erhalten;
Online-Einstellungen werden vom Host pro Tisch gewählt. Aktuelle Architektur und
Prüfungen: [Online-Tische](online_tables.md). Die früheren Stabilitätstests oben
dokumentieren den davor abgeschlossenen Lobby-Grundstein.

## Zuständigkeiten und Vertrauensgrenzen

| Bereich | Implementierung | Verantwortung |
| --- | --- | --- |
| Lokale Eingabe / Physik / Kamera | `first_person_player.gd/.tscn` | Unveränderter Controller, ausschließlich lokaler Spieler |
| Spielerzustand | Pose-Datensatz in `lobby_session.gd` | Position, Yaw, Pitch, Geschwindigkeit, Bodenkontakt, Sequenz |
| Verbindung / Teilnehmer | `scripts/network/lobby_session.gd` | ENet, Host-Liste, Snapshots, Join/Leave, Paketprüfung |
| Entfernte Darstellung | `remote_lobby_player.gd` | Kopie ausschließlich des Platzhalter-Meshs, Interpolation |
| Testbedienung | `lobby_network_panel.gd` | Host/IP/Join/Disconnect, unabhängig vom Transport |
| Integration | `lobby.gd` | Lokale Pose melden, entfernte Figuren erzeugen/entfernen, Tischwahl |
| Tischpräsentation | `table_prototype.gd` | Bisherige lokale Kamera, Anzeigen und Eingabe |
| Rundenmodell | `last_letter_round.gd` | Wiederverwendbare Regeln ohne Netzwerk-/Kamera-Abhängigkeit |

Die RPC-Nodes haben in allen Instanzen denselben Pfad
`/root/Main/Lobby/NetworkSession`. Der Host hat ENet-ID 1. Zuverlässiger Kanal 0
überträgt Mitgliedschaft/Protokollversion; separater `unreliable_ordered`-Kanal 1
überträgt laufende Bewegung. Nur Host-RPCs dürfen Teilnehmerlisten oder fremde
Posen verteilen. Ein Client übermittelt **keine frei wählbare Spieler-ID**:
der Host ermittelt den Absender mit `get_remote_sender_id()`. Er verwirft unbekannte
Absender, alte Sequenzen, übermäßig schnelle Paketfolgen, nicht endliche Zahlen,
unplausible Raumpositionen und Geschwindigkeiten.

Bewegung ist derzeit lokal simuliert und vom Host weitergeleitet. Die groben
Plausibilitätsgrenzen ersetzen keine autoritative Bewegungsphysik oder Anti-Cheat.
Remote-Figuren kollidieren noch nicht miteinander; die bestehende Raum-/Tischphysik
und Kamerakollision des lokalen Spielers bleiben erhalten. Interpolation glättet
Ankunftszustände, hat aber noch keinen eigenen Zeitpuffer oder Netzwerklag-Ausgleich.

Es gibt **keine Client-RPCs für Herzen, Wortgültigkeit, Frist, Zug oder Gewinner**.
Insbesondere wird die Offline-Runde nicht auf jedem Client parallel als angeblich
gemeinsames Spiel gestartet. Die spätere Autorität wird an das bestehende reine
Rundenmodell angeschlossen, nicht an die Kamera.

## Nächster Ausbau ohne Neuschreiben der Regeln

| Thema | Vorgesehene Erweiterung / aktueller Stand |
| --- | --- |
| Etwa 16 Spieler | Standard `max_players = 16` inklusive Host; vier echte Verbindungen und 16 simulierte Registry-Einträge/15 Avatar-Nodes getestet. Noch kein 16-Spieler-Lasttest. |
| Mehrere Tische | Implementiertes Register `table_id → TableRound` mit eigenen Plätzen und Regeln; zwei reale Platzhaltertische und parallele Runden getestet. |
| Tischbelegung | Host entscheidet über `request_seat(table_id)` anhand Entfernung, freier Plätze und Mitgliedschaft. Die Auswahl eines eindeutigen freien Sitzes und die Replikation sind implementiert. |
| Autoritative Runde | Nur der Host ruft prepare/begin_round/submit/expire/advance_player auf. Client sendet Wort plus Tisch-/Runden-/Zugkennung. Host prüft Absender am aktiven Platz, seine eigene Zeit und das eigene Offline-Wörterbuch. |
| Countdown / Timer | Host verwaltet Rundenzustände und monotone Deadline. Clients stellen einen synchronisierten Serverzeit-Schätzwert dar; eine Kameraanimation darf den Hosttimer nicht selbst starten oder verlängern. |
| Einstellungen | Host legt Mature Words und Schwierigkeit für die TableSession fest und veröffentlicht beim Start einen Snapshot. Clients haben dafür keine Ergebnisautorität. |
| Wortanzeige / Kamera | Online-Adapter verwendet Host-Ergebnisse und eine feste eigene Sitzperspektive; Offline-Hotseat bleibt erhalten. Zuschauer behalten die Lobbykamera mit Textanzeige. |
| Freie Spieler | Bleiben unabhängig von TableSessions beweglich; Sitz-/Zuschauermodus bestimmt das gezielte Rundensnapshot-Abonnement. |
| Zuschauer | Separate Host-Liste und SPECTATING-Status, ohne Herzen/Züge/Wortrechte. Einfache Beitritts-/Austrittsknöpfe und lesende Tischanzeige in Phase 11 ergänzt. |
| Disconnect | Figur, Belegung und Zuschauerzuordnung werden entfernt; nur die betroffene Runde eliminiert/überspringt den Teilnehmer oder zeigt den letzten Überlebenden als Gewinner. |
| Reconnect | Heute erneutes Join mit neuer Peer-ID/Spawn. Später separates authentifiziertes Sitzungstoken, begrenzte Reservierungszeit und vollständiger Host-Snapshot; nicht aus IP oder alter Peer-ID ableiten. |
| Join-Link / Code | Später Address-Resolver bzw. Relay vor `join(address, port)` ergänzen. Eingabe-/Rundenmodell bleiben davon unabhängig. |

## Tests und Grenzen

`tests/run_network_checks.ps1` startet zwei unabhängige Windows-Prozesse mit
Forward+ und der echten Hauptszene. Beide verbinden sich über ENet/localhost.
Der Test fokussiert die Fenster nacheinander und sendet echte Godot-Ereignisse für
W, Maus und Space. Die jeweils andere Instanz prüft empfangene Bewegung, Rotation,
Sprung und Landung sowie die unveränderte lokale Kamera. Anschließend werden
Client-Leave, Host-Aufräumen, Rejoin, Host-Leave und Offline-E/Countdown geprüft.
Protokolle und Bilder: `.godot/network_checks/<Zeitstempel>/`.

`network_edge_test.gd` prüft ungültige Posen, Absenderbindung, leere Adresse,
belegten Port, Verbindungs-Timeout, gesperrte lokale Tischregeln während Online,
erhaltene Einstellungen und Socketfreigabe beim Szenenende. Der absichtlich
provozierte Portfehler wird über seinen Error-Rückgabewert geprüft; nur für diesen
einzelnen Aufruf unterdrückt der Test die erwartete Engine-Fehlermeldung.

Gemeinsame Online-Tische und zwei parallele Runden sind umgesetzt und geprüft.
Verbindungen zwischen verschiedenen physischen Rechnern, Internet/NAT, hohe
Latenz/Paketverlust und 16 echte gleichzeitige Verbindungen sind noch offen.
Aktuelle LAN-Konfiguration und Testgrenzen stehen in [Online-Tische](online_tables.md).
Keine Veröffentlichung oder finale Gestaltung.
