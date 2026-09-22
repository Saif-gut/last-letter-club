# Third-Person-Lobby

Die vorhandene CharacterBody3D, Input Map, Geschwindigkeiten, Schwerkraft,
Sprungsteuerung, Mausbindung und Raumkollisionen bleiben erhalten.
`first_person_player.gd/.tscn` behält seinen historischen Dateinamen, enthält
inzwischen jedoch die Third-Person-Kamera.

## Kamera

CameraArm ist ein vom Spielertransform unabhängiger SpringArm3D mit einer
direkten Camera3D als Kind. Er folgt dem Spieler gedämpft auf Schulterhöhe,
leicht nach rechts versetzt. Seine Kugelprüfung zieht die Kamera vor Wänden,
Stühlen, Tisch und Boden heran; die eigene Spielerkollision ist ausgeschlossen.
Der Platzhalter besteht aus Kapsel und Kugel und ist nur beim Laufen sichtbar.
Bei sehr kurzer Kameradistanz wird er weich transparent, damit der Kopf vor
einer Wand nicht die Sicht versperrt. Bei freier Distanz wird er wieder deckend.

| Einstellung | Standard |
| --- | --- |
| Laufgeschwindigkeit | 3,8 m/s |
| Sprunggeschwindigkeit | 4,5 m/s |
| Mausempfindlichkeit | 0,002 rad/Pixel |
| Kameradistanz | bis zu 3,2 m, bei Hindernissen kürzer |
| Kameraziel relativ zur Figur | 0,22 m rechts / 1,5 m hoch |
| Ausgangsneigung | −12° |
| Vertikaler Blickbereich | −60° bis +55° |
| Positionsdämpfung | 18 pro Sekunde |
| Blickdämpfung | 24 pro Sekunde |
| Kollisionsprobe / Abstand | Kugelradius 0,18 m / Margin 0,08 m |

Maus-Yaw dreht weiterhin die Figur und damit die WASD-Richtung. Der Kameraarm
folgt mit kurzer, bildratenunabhängiger exponentieller Dämpfung. Godots
Physikinterpolation glättet die Darstellung zwischen Physikschritten.
Die bestehende Tischkamera verwendet weiterhin ihren eigenen Frame-Tween und
hat Physikinterpolation ausdrücklich ausgeschaltet.

Beim Start und Aufstehen wird der Kameraarm direkt an die neue Spielerposition
gesetzt und die Interpolationshistorie zurückgesetzt. Dadurch fährt die Kamera
nicht quer durch den Raum vom alten Aufenthaltsort heran.

## Übergänge und Eingabe

Im Offline-Modus funktioniert E innerhalb von 1,6 Metern zum nächsten Stuhl, auf dem Boden und
bei eingefangener Maus. set_walking(false) deaktiviert Bewegung, Laufkollision
und Platzhalter. Die vorhandene Tischkamera und die Worteingabe übernehmen.
Die Worteingabe bleibt zunächst für 3 → 2 → 1 → GO gesperrt. Erst danach zeigt
der Tisch den zufälligen Anfangsbuchstaben und startet die erste Zugfrist.
F4 beendet die lokale Runde und setzt die Figur 3,5 Meter außerhalb der Tischmitte
am zuletzt aktiven Stuhl ab. Die Third-Person-Kamera übernimmt automatisch.

Beim Aufstehen werden Kameratween, Rundenfrist und alte Feedbackaktionen beendet.
Sitzungs- und Feedbacknummern schützen auch schnelles Wiederbeitreten.
In der Lobby sind anschließend alle Stühle wieder frei. Die vier Tischplätze
sind lokale Teilnehmer, die über dieselbe Tastatur gespielt werden, keine Bots.

Esc gibt beim Laufen die Maus frei und pausiert die Bewegungseingabe. Erneutes
Esc oder Rückkehr nach Fokusverlust fängt die Maus wieder ein. Am Tisch leert
Esc ausschließlich das Wort. WASD und Space bewegen dort die Lauffigur nicht.

Eine einfache Textanzeige unter dem Lobbytitel zeigt **Mature Words: ON / OFF**.
F6 schaltet die Einstellung ohne Mausbedienung um, standardmäßig steht sie auf OFF.
Der Wert liegt in der MatchSettings-Ressource des Tischs und wird bei Rundenstart
in die Wortprüfung kopiert. Während des Sitzens hat F6 keine Wirkung. Beim
Aufstehen bleibt die Auswahl erhalten; es gibt noch keine Speicherung über
Programmstarts hinweg. Kamera, Bewegung und Tischgeometrie wurden dafür nicht geändert.

Der bestehende Raum bleibt 14 × 16 Meter groß, mit 4,5 Meter hohen Wänden.
Die festen Ausstiegspunkte passen zu diesem Testraum. Im eingebetteten
Godot-Spielfenster muss der Interaktionsmodus **Eingabe** aktiv sein, damit
Spielereingaben ankommen; 2D/3D sind Editor-Inspektionsmodi.

F7 wählt Easy/Normal/Hard für die lokale Runde. F8/Host und F9/Join verbinden
mehrere Instanzen über die separate Netzwerksitzung; F10 trennt sie wieder.
Online fragt E einen Host-verwalteten Sitz am nahen Tisch an; die lokalen
Match-Schalter bleiben gesperrt. Der Host stellt stattdessen den jeweiligen
Online-Tisch ein. Zwei Tischinstanzen verwenden getrennte Runden. Esc verlässt
auch die Bearbeitung des IP-Felds und gibt die Bewegungssteuerung frei.
Remote-Figuren besitzen keine Kamera oder Eingaben. Details:
[Private Netzwerklobby](multiplayer_foundation.md), [Online-Tische](online_tables.md).

## Prüfung

tests/lobby_smoke.gd besteht grafisch mit Godot 4.7.2 / Forward+.
Geprüft werden Startfokus ohne Klick, Maus, WASD, Sprung, Boden, Stühle, Tisch,
Wände, Join-Reichweite, sichtbarer Laufkörper, Kamerabesitz, Eingabetrennung,
Aufstehen, Wiederbeitritt, Verlassen während Feedback/Fahrt und Zurückziehen
der Kamera vor einer Wand samt Wiederherstellung der freien Distanz.
Bilder unter .godot/lobby_checks/ wurden auf Perspektive und Lesbarkeit geprüft.
Das subjektive Kameragefühl lässt sich mit den Inspector-Werten feinabstimmen.
