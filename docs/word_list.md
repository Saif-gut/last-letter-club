# Offline-Wortliste und Lizenz

Verwendet wird die offene **Wordnik Wordlist** für Wortspiele:

- Repository: https://github.com/wordnik/wordlist
- Feste Version: `46e6215d0f90356afe9c8ba4be347e7e98cb425c`
- Quelldatei: [wordlist-20210729.txt](https://github.com/wordnik/wordlist/blob/46e6215d0f90356afe9c8ba4be347e7e98cb425c/wordlist-20210729.txt)
- Abruf: 13.09.2026
- Lizenz: [MIT, Copyright (c) 2020 Wordnik](../resources/words/WORDNIK_LICENSE.txt)
- Unveränderte lokale Quelle: `resources/words/wordnik_source.txt`
- SHA-256 der Quelle: `bfd1b4eb4ade1ba81e84c7e24248b9a1aecec9d9baa427453b367a83e30e0451`

Die MIT-Lizenz erlaubt Nutzung, Änderung und Weitergabe auch in kommerziellen
Spielen. Der Copyright- und Lizenzhinweis muss erhalten bleiben. Der vollständige
Originaltext liegt neben der Quelle und zusätzlich im exportierten Wörterbuch.
Es wird ausschließlich diese offene Wortliste verwendet, nicht das separate
kostenpflichtige Wordnik Games Dataset und auch nicht die Wordnik-Laufzeit-API.

## Aufbereitung

`python scripts/build_word_list.py` prüft den Quellhash und baut ohne Netzwerk
die Ressource `resources/words/english_words.tres` neu auf.

1. Jede zitierte Zeile der Originaldatei wird als JSON-String gelesen.
2. Übernommen werden kleingeschriebene A–Z-Wörter mit 1–24 Buchstaben.
3. Die englischen Einbuchstabenwörter **a** und **i** werden ergänzt.
4. Wörter werden dedupliziert und sortiert.

Die Quelle enthält 198.422 Einträge; die resultierende Ressource enthält
**198.419 eindeutige Wörter**. Die Begrenzung entspricht dem bestehenden
24-Zeichen-Eingabefeld. Apostrophe, Bindestriche und sonstige Zeichen sind derzeit
keine gültigen Spieleingaben. Groß-/Kleinschreibung und äußere Leerzeichen werden
beim Prüfen normalisiert. Wörter aus verschiedenen gültigen Flexionsformen zählen
als verschiedene Wörter. Ausschließlich akzeptierte Wörter sperren Wiederholungen.

## Laufzeit und Export

word_validator.gd lädt die .tres über preload; die Liste ist dadurch eine
reguläre Godot-Exportabhängigkeit. Sie hängt nicht von einem Export-Include für
beliebige .txt-Dateien ab. word_lexicon.gd speichert neben den Wörtern auch
Quell-URL und den vollständigen MIT-Lizenztext in dieser Ressource.
Die Wörter werden einmalig in ein gemeinsames Dictionary geladen; die Prüfung
benötigt anschließend ausschließlich lokale Speicherzugriffe.

Für spätere Windows-Distributionen den mitgelieferten Lizenztext außerdem in den
Credits oder Third-Party Notices zugänglich machen. Ein veröffentlichter Windows-Build oder fertiges
Exportprofil ist nicht Bestandteil dieses Prototyps.

## Wörterbuchumfang und Mature Words

Eine Wortspielliste definiert die akzeptierte Vokabelmenge; sie ist kein Beweis
für Vollständigkeit der englischen Sprache. Seltene Wörter und Flexionen können
gültig sein, neue Wörter können fehlen. Fantasiewörter außerhalb der Liste werden
abgewiesen. Die offene Liste enthält keine zuverlässigen Mature-/Profanity-Tags.

word_policy.gd prüft nach dem Wörterbuch eine separate lokale Sperrliste.
Mature Words OFF blockiert ihre Einträge; ON hebt nur diese Sperre auf und
umgeht keine Sprach-, Buchstaben- oder Wiederholungsprüfung. Die Lobby zeigt
die Einstellung und schaltet sie mit F6 um. Die aktive Runde übernimmt den Wert
beim Start. Quelle und Lizenz der zusätzlichen Liste sowie ihre Aufbereitung
stehen unter [Mature Words](mature_words.md). Das englische Wörterbuch selbst
bleibt unverändert; die Sperrliste wird als eigene Godot-Ressource mitgeliefert.
