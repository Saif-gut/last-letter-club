# Tischkamera und lokale Kernmechanik

Tischgeometrie, Stühle, Platzhalter, schwebende Label3D-Anzeigen und
Sitzkameraperspektive des bisherigen Prototyps werden weiterverwendet.
Die simulierten Bestätigungen wurden durch eine unabhängige Regelinstanz ersetzt.

## Zuständigkeiten

- table_prototype.gd: Eingabe, HUD, Farbfeedback und bestehende Kamerafahrt.
- last_letter_round.gd: Herzen, aktive Plätze, Wortverlauf, Frist und Gewinner.
- word_validator.gd: Normalisierung und Offline-Wortprüfung.
- word_policy.gd: lokale, lizenzierte Mature-Words-Sperrliste.
- match_settings.gd: Mature Words und Schwierigkeit als Snapshot beim Rundenstart.
- prefix_advisor.gd / difficulty_profile.gd: wörterbuchgestützte Ein-/Zweibuchstaben-Vorgabe.

enter_table(seat_index) beginnt eine frische Runde mit vier lokalen Teilnehmern
am gewählten Platz. Der optionale zweite Parameter ist ein deterministischer
Startbuchstabe für Tests; normales Spielen wählt nach GO zufällig A–Z ohne Q, X und Z.
leave_table() stoppt die Runde, löst den Eingabefokus und bricht Übergänge ab.
Der eigenständige F6-Start bleibt möglich und benutzt denselben Countdown.

## Rundenstart und Neustart

`prepare()` setzt Herzen, ausgeschiedene Plätze, verwendete Wörter, Gewinner,
Startbuchstabe und Deadline zurück. Der erste aktive Sitz steht fest, doch es
gibt noch keinen ausgewählten Buchstaben und keine laufende Zugfrist.
`enter_table()` übernimmt die Mature-Words-Auswahl und ein eigenes Schwierigkeitsprofil und startet zunächst
die neue Präsentationsphase COUNTDOWN.

Eine einfache zentrale Textanzeige zeigt 3, 2 und 1 jeweils für 1.000 ms, danach
GO für 500 ms. Die Anzeige folgt einer monotonen Uhr im Frameprozess. Es gibt
keine asynchronen Countdown-Rückrufe, die nach Verlassen des Tischs weiterlaufen.
Aufstehen stoppt die vorbereitete Runde und entfernt die Anzeige; Wiederbeitreten
startet vollständig neu bei 3.

Erst nach GO ruft die Präsentation `begin_round()` auf. Dieser wählt den ersten
Buchstaben zufällig, ergänzt gegebenenfalls einen sinnvollen zweiten Buchstaben,
setzt die erste Deadline auf jetzt + 10.000 ms und lässt die
Eingabe samt Fokus frei. Q, X und Z werden nur bei dieser Anfangsauswahl vermieden;
gültige Folgewörter dürfen sie weiterhin vorgeben. Wiederholtes `begin_round()`
kann keine laufende Uhr zurücksetzen. `start()` bleibt als Kombination aus
Vorbereiten und Beginnen für die isolierten Regeltests erhalten.

Während der Gewinneranzeige bleiben Eingabe und Bearbeitungsmodus gesperrt und
der Fokus wird freigegeben. Auch die Rückkehr des Fensterfokus gibt die Eingabe
nicht frei. F5 startet am Siegerplatz eine vollständig zurückgesetzte Runde mit
neuem Countdown. Mature Words und Schwierigkeit bleiben erhalten. Eine neue zufällige
Auswahl kann zufällig denselben Buchstaben wie in der vorigen Runde ergeben.

## Kamera und Feedback

| Einstellung | Wert |
| --- | --- |
| Sitzradius | 2,25 m |
| Augenhöhe | 1,22 m |
| Sichtfeld | 78° |
| Kamerafahrt | 0,55 s, kubisches Beschleunigen/Abbremsen |
| Farbfeedback | 0,22 s |

Die Kreisbahn bleibt bestehen. Bei ausgeschiedenen Plätzen umfasst der Bogen
entsprechend mehrere Sitzabstände. Tab hält die bisherige Tischübersicht offen;
das pausiert weder Uhr noch Runde. Der eigene Sitzplatzhalter sowie der gerade
verlassene Körper während der Fahrt bleiben in der Ich-Perspektive ausgeblendet.
Ausgeschiedene Teilnehmer sind ausgeblendet und ihre Bodenringe abgedunkelt.

Die Präsentationszustände sind COUNTDOWN, TYPING, FEEDBACK, MOVING, FINISHED.
Ungültige Abgaben wechseln kurz in FEEDBACK: Der falsche Text bleibt rot sichtbar,
die Eingabe ist für 0,22 Sekunden gesperrt, die Uhr läuft weiter. Danach werden
Eingabe und schwebender Text geleert, TYPING aktiviert und Fokus samt Bearbeitungsmodus
wiederhergestellt. Direktes Tippen funktioniert ohne Klick, Esc oder Backspace.
Die kurze Sperre verhindert, dass der Rückruf eine bereits neue Eingabe löscht.
Erneutes Enter während des Feedbacks kostet kein zusätzliches Herz.

Ein gültiges Wort stoppt die Zugfrist. Grünfeedback und Kamerafahrt sperren weitere
Abgaben. Erst _finish_move() startet die nächsten vollen 10 Sekunden.
Beim Ausscheiden wird der nächste lebende Platz gewählt; beim letzten Überlebenden
wechselt die Präsentation nach kurzem Feedback auf FINISHED. F5 startet neu.

## Fristen und Unterbrechungen

Die Regeln erhalten Time.get_ticks_msec(), eine monotone Uhr. Sie vergleichen
sie mit einer absoluten Frist. Auch bei einem langsamen Frame oder Fokusverlust
entsteht dadurch keine zusätzliche Bedenkzeit. Sowohl der Frameprozess als auch
die Abgabe prüfen den Zeitablauf. Eine Abgabe exakt bei 10.000 ms kommt zu spät.
Die Regelinstanz selbst benötigt keine Szene, Timer-Nodes oder Internetverbindung.

Rotes Feedback besitzt einen eigenen fortlaufenden Token zusätzlich zur
Sitzungsnummer. Neue Abgaben, Zeitablauf oder Aufstehen machen alte Rückrufe
wirkungslos. Deshalb kann ein alter roter Rückruf weder grünes Feedback
überschreiben noch einen ausgeschiedenen Spieler reaktivieren.
Das gilt auch für das neue automatische Leeren. Die Deadline wird unmittelbar
vor der erneuten Eingabefreigabe nochmals geprüft. Auch bei Herzverlust auf 0
wird das abgelehnte Wort nach dem roten Feedback geleert, ohne Eingabe freizugeben.
Gültige Wörter und reine Timeouts erhalten keine zusätzliche Auto-Clear-Aktion;
das bisherige Leeren beim Platzwechsel bleibt bestehen.

## Wortdefinition und Grenzen

Siehe [Wortliste](word_list.md) für Quelle und MIT-Lizenz. Die Spielregeln stehen
in der [README](../README.md). Pro Eingabe werden höchstens 24 Zeichen angenommen.
Leere Abgaben zählen als ungültiger Versuch; Esc allein kostet kein Herz.
Der Verlauf speichert ausschließlich akzeptierte, normalisierte Wörter und wird
bei einer neuen Runde zurückgesetzt. Der aktive [Mature-Words-Filter](mature_words.md)
wird mit F6 in der Lobby gewählt und beim Start übernommen. Er ändert keine
anderen Wort- oder Rundenregeln. Online übernimmt der Host dieselbe Partieeinstellung
vor Beginn pro Tisch. Die private Netzwerklobby verwendet einen getrennten Adapter:
Die Offline-Regelinstanz bleibt während einer Verbindung inaktiv; Host-Snapshots
steuern stattdessen die vorhandenen Anzeigen und die eigene Sitzkamera.
Siehe [Online-Tische](online_tables.md).

Die vollständige angezeigte Vorgabe (`required_prefix`) muss erfüllt werden.
Der erste Buchstabe (`required_letter`) bleibt die Last-Letter-Kette. Details:
[Vorgaben und Schwierigkeiten](prefixes_and_difficulty.md).

## Prüfung

- round_rules_test.gd: volle Offline-Liste und Lizenz, Normalisierung, Fantasiewörter,
  falsche Initialen, Duplikate, Herzverlust, Ausscheiden, exakte Zeitgrenze, Gewinner,
  Neustart, erlaubte Zeichen, Filter-Schnittstelle und Stoppen der Runde.
- prototype_smoke.gd: echte Eingabeereignisse, Live-Anzeige, Backspace, Esc,
  Zeichenlimit, rote/grüne Anzeige, automatisches Leeren, Fokus, doppelte Bestätigung,
  Kameraradius/-höhe, Platzreihenfolge, Herz- und Zeitausscheiden, Sieger und Neustart.
  Enthält einen 180°-Bogen über einen ausgeschiedenen Platz und einen Zeitablauf
  über echte 10 Sekunden. Weitere Grenzfälle setzen gezielt eine kurze Restfrist.
- lobby_smoke.gd: Integration in die Lobby einschließlich Aufstehen während
  Feedback und Fahrt sowie Wiederbeitritt ohne Einwirkung alter Rückrufe;
  außerdem F6, angezeigter Modus und Übernahme beim Hinsetzen.
- mature_words_test.gd: alle 1.015 Filtereinträge bei OFF/ON, häufige Schimpfwörter
  und Flexionen, unverfängliche Wörter und Teilwort-Falschpositive, echte Wortkette
  mit gefilterten Wörtern, Herzverlust, Wiederholungen und feste Rundeneinstellung.
- countdown_flow.gd: kompletter grafischer Ablauf aus der Lobby; alle vier
  Countdownstufen mit echten Zeitabständen, Eingabesperre, noch nicht gesetzter
  Buchstabe/Timer, automatische Freigabe mit vollen 10 Sekunden, reale erste
  Bedenkzeit, Wortkette, Ausscheiden, Gewinner, F5-Neustart und Rücksetzen aller
  Rundendaten bei erhaltener Mature-Words-Auswahl. Auch Verlassen während GO und
  schnelles Wiederbeitreten werden geprüft. Bilder: .godot/countdown_checks/.

Grafische Prüfung: Godot 4.7.2.stable.official.ed1daf0bf, Forward+,
Vulkan 1.4.341, NVIDIA GeForce RTX 5060 Ti. Die aufgezeichneten Bilder liegen
unter .godot/prototype_checks/ und .godot/lobby_checks/.
