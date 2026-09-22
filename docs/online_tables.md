# Host-autoritative Online-Tische

## Phase 1: Sitzen

`table_service.gd` ist ein separater Host-Dienst neben der ENet-Lobbysitzung.
Er registriert Tische über ihre `table_id` und prüft beim Beitreten den bekannten
Spieler, Bodenkontakt, Höhe, Entfernung und einen freien Platz. Die Zuteilung
erfolgt synchron beim Host, damit zwei Anfragen niemals denselben Platz erhalten.
Clients dürfen nur Beitreten/Aufstehen anfragen; die Absender-ID kommt aus ENet.
Alle erhalten eine zuverlässige Belegungsliste. Sitzende Clients dürfen ihre
gesperrte Bewegungspose nicht durch weitere Laufpakete verändern.

`online_table_view.gd` verwendet die bestehenden Stühle, Platzhalter und die
vorhandene Sitzkamera. Jeder sieht aus seinem eigenen Sitz, während andere
Teilnehmer dort eine sitzende Figur sehen. Die frei laufende Remote-Figur ist
währenddessen ausgeblendet. Die Offline-Regelinstanz wird dabei nicht gestartet.
F4 fragt Aufstehen an; F10 beendet auch eine sitzende Netzwerksitzung. Aufstehen
oder Sitzungsende bringt die eigene Figur wieder an den bisherigen sicheren
Ausstiegspunkt und aktiviert Lobbykamera und Bewegung. Die Offline-Untertitel
werden wiederhergestellt.

Ein grafischer Zwei-Prozess-Test (`network_table_test.gd`) prüft Reichweitenablehnung,
getrennte Sitzplätze/Kameras, sichtbare Belegung, Aufstehen, Wiederbeitritt und
Disconnect während des Sitzens. Ausführung:

```powershell
./tests/run_network_checks.ps1 -TestScript res://tests/network_table_test.gd -Scenarios seating
```

## Bereits vorhandenes Vollbild

Normaler Start verwendet Godots randloses `MODE_FULLSCREEN` und die aktuelle
Monitorauflösung. `canvas_items` plus `expand` skaliert die UI gleichmäßig und
erweitert bei anderem Seitenverhältnis den sichtbaren Bereich. Alt+Enter wird in
einem getrennten `window_controls.gd`-Autoload behandelt und kann keine Wörter
oder IP-Adressen absenden. Mit Godot 4.7.2 / Forward+ bei 2560×1440 Vollbild und
960×540, 1280×960, 1600×680 im Fenster getestet, einschließlich Tischkamera und
aktiver Worteingabe. Testaufnahmen: `.godot/window_checks/`.

## Phase 2: Gemeinsame Runde

Der Host startet am Tisch mit F5, sobald mindestens zwei Spieler sitzen. Vorher
oder nach Rundenende wählt er mit F6 Mature Words und F7 die Schwierigkeit.
Clients haben keinen RPC für Start oder Einstellungen. Beim Start friert
`table_round.gd` die Teilnehmerliste und Einstellungen ein und ruft die bestehende
`last_letter_round.gd`-Regelinstanz auf. Validierung, Wörterbuch, Präfixauswahl,
Herzen und Gewinnerregeln werden weiterverwendet, nicht auf Clients nachgerechnet.

Nur der Host führt Countdown, Feedbackpause (220 ms), Zugwechselpause (550 ms)
und Deadline aus. Ein Client sendet Tisch-ID, Wort, Rundenkennung, Zugkennung und
eine fortlaufende Abgabenummer. Der Host prüft den ENet-Absender gegen dessen Sitz
und den aktiven Teilnehmer. Alte/doppelte Anfragen können kein zweites Herz kosten.
Auch ein gültiges Wort nach der Host-Deadline kommt zu spät.

Rundensnapshots gehen nur an die aktuellen Sitze des jeweiligen Tisches. Sie
enthalten die offizielle Countdownstufe, Uhr, Vorgabe, Herzen und Ergebnisse.
Die Client-Timeranzeige schätzt zwischen Snapshots anhand monoton vergangener Zeit;
sie entscheidet niemals über Frist oder Ausscheiden. Ein Netzwerkversatz kann die
Anzeige geringfügig verzögern. Nach der Verbindung ist keine lokale Uhr identisch
zur Host-Uhr nötig. Der Host versendet regulär alle 100 ms und bei Zustandswechseln.

Online bleibt jede Kamera an ihrem eigenen Sitz. Der Hotseat-Kamerakreis würde
sonst den Spieler auf einen fremden Sitz versetzen. Stattdessen bleibt das
vorhandene rote/grüne Feedback erhalten und der Host hält die gleiche Zugwechsel-
Dauer ein. Erst danach beginnen die nächsten vollen 10 Sekunden. Ein ungültiges
Wort leert sich nach bestätigtem roten Feedback und erhält den Fokus zurück;
der Host behält die ursprüngliche Deadline bei. Siegeranzeige sperrt Eingabe.
F5 setzt die Runde zurück, aber weder Sitzplätze noch Verbindung oder Einstellungen.

`online_round_rules_test.gd` prüft die Host-Orchestrierung mit kontrollierter Uhr,
allen Schwierigkeits-/Mature-Modi, falschem Vollpräfix, Paketwiederholung, Herzen,
Wortwiederholung, Zeitablauf und Neustart. `network_round_test.gd` spielt mit zwei
echten Forward+-Fenstern eine komplette Runde samt Neustart. Nach Prüfung des
echten zufälligen Starts setzt der Test ausschließlich auf dem Host eine bekannte
ST-Vorgabe, um `stone → epochs → [STONE abgelehnt] → snake` reproduzierbar über
das Netzwerk zu prüfen. Produktiv gibt es keinen RPC zum Setzen eines Präfixes.

## Phase 3: Verlust von Teilnehmern

Der Host entfernt getrennte Spieler aus der Belegung und ruft für die eingefrorene
Rundenteilnehmerliste `remove_participant()` auf. Die bestehende Regelklasse besitzt
dafür eine idempotente `eliminate_player(index)`-Operation. Ein wartender Teilnehmer
ändert weder den aktiven Spieler noch dessen Deadline. Ein aktiver Teilnehmer
wird sofort übersprungen; nach der normalen kurzen Zugwechselpause erhält der
nächste Überlebende zehn Sekunden. Bei einem verbleibenden Spieler endet die Runde
sofort mit diesem Gewinner, auch während Countdown oder Feedback.

Aufstehen mit F4 ist während der laufenden Runde vorerst gesperrt. F10 und echte
Verbindungsabbrüche bleiben jederzeit möglich. Ausgeschiedene Teilnehmer dürfen
der restlichen Runde an ihrem eigenen Sitz zusehen, aber keine Worte mehr senden.
Ein neu verbundener Spieler erhält keine alte Rundenteilnahme zurück und darf sich
während einer laufenden Runde nicht hineinsetzen. Nach deren Ende kann er einen
freien Platz belegen und am nächsten Neustart teilnehmen.

Der Host besitzt alle Regeln; bei seinem Ausfall gibt es keine weiterlaufende
Client-Runde und keine Host-Migration. Netzwerkzustand und Sitzbelegung werden
geleert, die Tischanzeige gesperrt und die Lobbykamera samt Bewegung wiederhergestellt.
Echtes Reconnect benötigt später eine separate verifizierte Identität, eine zeitlich
begrenzte Platzreservierung und einen vollständigen aktuellen Host-Snapshot.
Eine alte ENet-ID oder IP allein reicht dafür nicht.

`online_disconnect_test.gd` prüft mit vier Teilnehmern aktive/nicht aktive Verluste
in Countdown, Eingabe, Feedback und Zugwechsel sowie doppelte Ereignisse. Der
Zwei-Prozess-Test `network_round_disconnect_test.gd` prüft wartenden/aktiven Client-
Disconnect, identischen Gewinner, Rejoin, Host-Ende mitten in der Runde und eine
anschließend erneut aufgebaute Host-/Join-Verbindung.

## Phase 4: unabhängige Tischinstanzen

Die vorhandene ID-Registry verwaltet jetzt standardmäßig zwei Platzhaltertische
im bisherigen Raum (`table_01`, `table_02`). `--single-table` blendet den zweiten
für gezielte Vergleichstests aus. Online wählt die Nähe zu einem freien Stuhl den
Tisch für E. Kollisionen werden für jede Instanz erzeugt; die Sitzkamera verwendet
den jeweiligen globalen Tischmittelpunkt. Das lokale Hotseat-Spiel bleibt am
ursprünglichen Tisch unverändert verfügbar.

Jeder registrierte Tisch besitzt seine eigene `TableRound`, Plätze, eingefrorene
Teilnehmer, Einstellungen, Countdown, Uhr, Vorgabe, Historie und Gewinner. Der Host
tickt alle Instanzen unabhängig. Einfache Host-Startknöpfe pro Tisch erlauben auch
den Start eines anderen Tisches, während der Host selbst spielt. Einstellungen
bleiben über F6/F7 am jeweiligen Host-Sitz zugänglich. Weitere Tische können über
dieselbe Registrierung hinzukommen; der Dienst enthält keine Sonderregeln für zwei.

`network_parallel_tables_test.gd` startet vier echte Forward+-Instanzen (Host/B/C/D):
je zwei Sitze, zeitversetzte parallele Countdowns, Easy/OFF und Hard/ON, getrennte
ST-/E-Vorgaben, Herzen und Historien, Client-Verlust an Tisch 02 während Tisch 01
weiterläuft, Gewinner und unabhängiger Neustart. Die Kamerarichtung am versetzten
Tisch und die Zustellung ausschließlich eigener Rundensnapshots werden geprüft.
Gewinnerprüfung und Neustart werden im Test ausdrücklich synchronisiert, damit ein
schneller Host nicht die noch ausstehende Client-Prüfung überspringt.

```powershell
./tests/run_network_checks.ps1 -TestScript res://tests/network_parallel_tables_test.gd -Scenarios parallel -Roles host,b,c,d
```

## Phase 5: Spielerzustände und Lobbykapazität

`player_state(peer_id)` liefert zentral `mode`, `table_id`, `seat`. FREE bedeutet
keine Tischzuordnung, SEATED einen wartenden Sitz, PLAYING einen lebenden Teilnehmer
während Countdown/Runde und ELIMINATED einen ausgeschiedenen, noch sitzenden
Teilnehmer. Die Status werden aus Belegung und Host-Regelmodell abgeleitet und
zuverlässig mit der Belegung verteilt. Es gibt keinen zweiten mutierbaren
Spielerstatus auf Clients. Gewinner wechseln am Rundenende zu SEATED; ausgeschiedene
Sitze bleiben bis Neustart/Aufstehen ELIMINATED. Ein Neustart nimmt alle aktuell
belegten Sitze wieder auf. ID 0 bezeichnet ausschließlich einen freien Platz.

Die Lobby hat weiterhin eine unabhängige maximale Mitgliederzahl von 16 inklusive
Host, jeder Tisch vier Plätze. Die einfache Debug-Anzeige nennt `Players: X / 16`,
Tischbelegungen und den eigenen Status. `player_registry_test.gd` prüft sechzehn
simulierte IDs in einer einzigen Godot-Instanz: zwei volle Tische, weitere freie
Spieler, Zustandswechsel, abgewiesene fremde Worteingaben, gezielte Disconnect-
Bereinigung sowie Erzeugung von fünfzehn echten entfernten Avatar-Nodes und deren
Entfernung. Dies ist ein Funktionstest der Registry, kein Last-/Bandbreitentest
mit sechzehn echten Verbindungen. Der Vier-Prozess-Test prüft dieselben Status
zusätzlich über echte ENet-Snapshots.

## Phase 6: Adressen, Aufnahmefehler und Zuschauergrundlage

Das vorhandene Feld heißt `Host Address`; es nimmt IP-Adressen oder Hostnamen an.
Standard bleibt `127.0.0.1`. `LobbySession.DEFAULT_PORT = 24572` ist die gemeinsame
zentrale UDP-Portvorgabe für Host und Join und wird in der Debug-Anzeige genannt.
Die Host-Bindung ist ausdrücklich `*` (bereits zuvor der Godot-Standard), also
nicht auf Loopback beschränkt. Es werden keine Firewall-/Routerregeln automatisch
geändert und keine externen Server kontaktiert.

Die Host-Registry erzwingt die Lobbykapazität unabhängig von ENet-Transportslots.
Zwei zusätzliche kurzlebige Transportslots ermöglichen eine zuverlässige Meldung
`Lobby voll`, ohne diese Verbindungen als Spieler aufzunehmen. Nach spätestens
zwei Sekunden räumt der Host sie ab, wenn der abgewiesene Client nicht selbst
trennt. Bei gleichzeitig mehr Ablehnungsversuchen als diesen Slots kann ENet
weiterhin nur einen allgemeinen Verbindungsfehler liefern. Roster-Snapshots gehen
nur an zugelassene Mitglieder. `network_capacity_test.gd` prüft mit zwei echten
Prozessen eine absichtlich auf einen Teilnehmer reduzierte Testkapazität, sichtbare
Ablehnung ohne Avatar/Sitz, Bereinigung und erfolgreichen Rejoin bei wieder 16
Plätzen. Im normalen Spiel beträgt die Kapazität weiterhin 16.

Verbindungsfehler, achtsekündige Nichterreichbarkeit und Host-Verlust bleiben in
der bestehenden Statuszeile sichtbar. Tischablehnungen erscheinen für fünf
Sekunden als einfacher Text, auch während des Sitzens. Bei Annäherung an volle
Tische/gesperrte Runden wird bereits im bestehenden Join-Hinweis der Grund genannt;
der Host prüft trotzdem jeden Sitzwunsch erneut.

Pro Tisch existiert nun eine separate `spectators`-Liste. Der Host-interne Aufruf
`set_spectating(peer_id, table_id)` setzt eine eindeutige Zuschauerzuordnung; ein
leerer Tischname beendet sie. Sitzende Teilnehmer dürfen nicht gleichzeitig
Zuschauer werden. `player_state()` liefert hierfür SPECTATING. Zuschauer werden
nie in die eingefrorenen Rundenteilnehmer übernommen, erhalten keine Herzen,
keinen Zug und kein Wortabgaberecht. Disconnect entfernt nur den Zuschauereintrag.
Der Registry-Test prüft Wechsel, doppelte Anmeldung, ungültige Abgabe und
Disconnect ohne jede Regeländerung. Phase 11 ergänzt inzwischen Bedienung und
ein gezieltes Snapshot-Abonnement (siehe unten). Ausgeschiedene Sitzteilnehmer bleiben
ELIMINATED und sind nicht automatisch Mitglieder dieser Zuschauerliste.

### LAN und Internet

Im LAN trägt ein zweiter Rechner die LAN-IPv4 des Hosts ein, auf diesem Rechner
aktuell `192.168.0.9` (Ethernet). Beide verwenden denselben Build und UDP-Port.
Die Windows-Firewall muss eingehenden Verkehr für den Host zulassen; WLAN-
Client-Isolation kann Verbindungen zwischen Geräten verhindern. Ein Test zur
eigenen Ethernet-Adresse prüft Adresswahl/Bindung, ersetzt aber keinen Test mit
einem zweiten physischen Rechner und dessen Netzwerkpfad.

Für direkte Verbindungen über getrennte Internetanschlüsse benötigen Freunde
eine erreichbare öffentliche Host-Adresse und üblicherweise eine UDP-
Portweiterleitung `24572` am Router auf den Host. Eine private LAN-IP ist von
außen nicht erreichbar. Godot dokumentiert Wildcard-Bindung, IP/Hostname-Unterstützung
und UDP-Portweiterleitung in [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
und [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html).

Bei Carrier-Grade NAT, Double NAT oder restriktiven Firewalls reicht eine lokale
Portweiterleitung möglicherweise nicht aus. Für den späteren Vertrieb wären ein
erreichbarer dedizierter Host oder ein Relay und gegebenenfalls NAT-Traversal zu
bewerten. Ein kleiner Lobby-Service könnte einen kurzen Join-Code auf eine Sitzung
abbilden; dieser Code allein macht den Host aber nicht erreichbar. Eine eigene
Codeauflösung braucht einen erreichbaren Dienst oder eine Plattformintegration,
ein Relay zusätzlich einen tatsächlichen Datenpfad. Davon ist hier nichts
integriert, ebenso wenig Accounts, öffentliche Listen oder bezahlte Dienste.

Weitere Grenzen: kein Host-Wechsel, keine Wiederherstellung alter Spieleridentität
beim Rejoin, keine Belastungsprüfung mit 16 echten Verbindungen und kein simulierter
WAN-Lag/Paketverlust. Bewegung besitzt nur Plausibilitätsprüfungen im bisherigen
Testraum, noch keinen autoritativen Bewegungsserver. Eine größere Map braucht
passende Spawnpunkte, Ausstiege und Bewegungsgrenzen; dies ist von Tisch-IDs und
Lobbykapazität getrennt.

Abschließender LAN-Nachweis am 14.09.2026: Zwei Prozesse verbanden sich erfolgreich
über die Ethernet-Adresse `192.168.0.9` desselben Rechners. Sowohl der vollständige
Bewegungs-/Reconnect-Test als auch die gemeinsame Tischrunde bestanden. Prüfpfade:
`.godot/network_checks/20260914-003640/repeat` und `20260914-003655/lan-round`.
Dies ist ausdrücklich noch kein Test zwischen zwei physischen PCs oder über das
Internet. Vollständige Testmatrix: [Entwicklungsbericht](implementation_phases.md).

## LAN Test mit zwei PCs

1. Beide PCs mit demselben LAN/WLAN verbinden und denselben vollständigen Build kopieren.
2. Jeweils `LastLetterClub.exe` starten; `.pck` und `licenses/` daneben belassen.
3. Esc gibt die Maus frei. PC A klickt **Host Lobby** (alternativ F8).
4. PC A liest **LAN IP** ab; bei mehreren Adaptern die IPv4 des gemeinsamen
   Ethernet-/WLAN-Netzes wählen, nicht VPN/virtuellen Adapter.
5. PC B trägt diese Adresse unter **Host Address** ein und klickt **Join Lobby** (F9).
6. Beide prüfen Spielerzahl und laufen/springen durch die Lobby.
7. Beide gehen zum selben Tisch und setzen sich mit E auf verschiedene freie Plätze.
8. Der Host startet über den Tisch-Startknopf oder F5. Countdown und Runde gemeinsam prüfen.
9. Client trennt und joint erneut; danach auch Host-Ende prüfen.

Windows fragt beim ersten Start eventuell nach Netzwerkzugriff. Zugriff für das
**private Netzwerk** muss erlaubt sein; verwendet wird **UDP 24572**. Das Spiel
ändert keine Firewall- oder Routerregeln. Bei Nichterreichbarkeit IP, privates
Netzwerk und mögliche WLAN-Client-Isolation prüfen. Die LAN-Anzeige ermittelt nur
lokale Adapter, keine öffentliche Internet-IP; nach Adapterwechsel Host neu starten.

## Phase 9: Weg von einer Adresse zu einem echten Join-Code

Die bestehende Transportgrenze ist `LobbySession.host()/join(address, port)`;
Tisch-Service und Rundenregeln hängen am Godot-Multiplayer, nicht am Eingabefeld.
Direktes Internetspiel ist damit grundsätzlich möglich, sofern der Host von außen
auf UDP 24572 erreichbar ist. Eine öffentliche Adresse, Router-Portweiterleitung
auf den Host und passende Firewall-Freigabe sind üblicherweise erforderlich.
Es gibt keine automatische Router-Konfiguration und keinen externen IP-Abfragedienst.
[Godot: Hosting considerations](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#hosting-considerations).

Bei CGNAT liegt eine weitere Adressübersetzung beim Provider; eine Weiterleitung
am eigenen Router genügt dann häufig nicht. Shared Address Space ist nicht global
routbar. Double NAT, unterschiedliche NAT-Abbildungen und Firewalls können den
Direktpfad ebenfalls verhindern. [RFC 6598](https://www.rfc-editor.org/rfc/rfc6598.html).

| Baustein | Aufgabe | Aufwand / Grenze für unser Projekt |
| --- | --- | --- |
| Kleiner Lobby-/Signaling-Service | Kurzlebigen Code auf Sitzung, Protokollversion und Endpunkt/Kandidaten abbilden; Einladungen austauschen | Löst Discovery, aber öffnet keinen Port. Braucht erreichbaren Dienst, Ablaufzeiten, zufällige Einladungsnachweise und Missbrauchsbegrenzung. |
| NAT Traversal / UDP Hole Punching | Über Signaling koordinierte direkte UDP-Verbindung versuchen | Muss NAT-Verhalten, Ports, Timeouts und Fallback berücksichtigen. Nicht für alle Netze erfolgreich; kein bloßer Austausch von `join()` gegen einen Code. |
| Relay | Datenverkehr über einen erreichbaren Server weiterleiten, wenn Direktpfad scheitert | Zuverlässigerer erreichbarer Pfad, aber Serverbetrieb/Bandbreite/Latenz. Passenden ENet-Transportadapter oder Plattformtransport auswählen und testen. |
| Godot-Multiplayer und Host-Runden | Mitgliedschaft, Peer-IDs, RPCs, autoritative Tischregeln | Bleiben die Spielschicht. Auch ein Relay darf Clients keine Autorität über Herzen, Timer oder Ergebnisse geben. |

Hole Punching und seine Grenzen beschreibt [RFC 5128](https://www.rfc-editor.org/rfc/rfc5128.html).
TURN ist ein standardisiertes Relay-Verfahren, siehe [RFC 8656](https://www.rfc-editor.org/rfc/rfc8656.html);
es ist hier **nicht** eingebaut und kein automatisch nutzbarer ENet-Schalter.

Architekturvorschlag für später: UI → Code-Resolver → Verbindungsstrategie
(direktes ENet, sonst geeigneter Relay-Transport) → bestehende LobbySession →
TableService/TableRound. Der Resolver liefert geprüfte Verbindungsdaten und eine
Sitzungskennung; der Verbindungsaufbau besitzt eigene Connecting/Failed-Zustände.
Keine Client-Seite darf einen unbekannten Code still auf localhost abbilden.
Vor Umsetzung sind Hosting/Plattform, Einladungsnachweise, Relay-Protokoll und
NAT-Fallback zu entscheiden. Ein separat gehosteter autoritativer Godot-Server
wäre eine weitere Möglichkeit, verändert aber die heutige Host-Rolle und benötigt
Serverbetrieb. In dieser Phase wurde ausschließlich analysiert und dokumentiert;
kein Dienst bereitgestellt, kein Join-Code simuliert, keine Infrastruktur angelegt.

## Phase 11: Einfaches Zuschauen

Ein verbundener FREE-Spieler gibt mit Esc die Maus frei und klickt bei einer
laufenden Runde auf **table_01 zuschauen** oder **table_02 zuschauen**. Der Host
prüft Mitgliedschaft, Rundenphase und fehlenden Sitzplatz. Der Spieler bleibt mit
seiner bestehenden Third-Person-Kamera in der Lobby beweglich; es gibt keine neue
Kamera oder automatische Platzvergabe. Die Textanzeige zeigt Vorgabe, verbleibende
Zeit, aktiven Spieler, Teilnehmerherzen, zuletzt angenommenes Wort und Gewinner.
Angezeigte Herzen gehören den Rundenteilnehmern, niemals dem Zuschauer.

Die bestehenden autoritativen Snapshots gehen zusätzlich an die separate
Zuschauerliste genau dieses Tisches. Ohne Sitzplatz verwirft der Host weiterhin
jede Wortabgabe, auch bei Umgehung der Oberfläche. Zuschauer verändern weder
Teilnehmerliste noch Herzen, Zug, Zeitfrist oder Gewinner. Ein Rundenneustart
behält das Abonnement bei, ohne Zuschauer in die neue Runde aufzunehmen.

**Zuschauen beenden** entfernt das Abonnement und den lokalen Snapshot; danach
ist Hinsetzen wieder möglich. Disconnect entfernt den Zuschauer und die Anzeige.
Bestehende Zuschauer sehen das Rundenende; ein neuer Zuschauerbeitritt ist nur
während einer laufenden Runde einschließlich Countdown möglich.

Reproduzierbarer Drei-Prozess-Test mit Godot 4.7.2 / Forward+:

```powershell
./tests/run_network_checks.ps1 -TestScript res://tests/network_spectator_test.gd -Scenarios spectator -Roles host,client,watcher
```
