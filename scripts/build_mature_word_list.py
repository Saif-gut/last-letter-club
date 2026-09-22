"""Build an exact-match, offline game filter from the pinned MIT-licensed cuss data.

Run: python scripts/build_mature_word_list.py. No JS execution or network access.
Only existing Wordnik words are emitted; see docs/mature_words.md for policy.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORDS = ROOT / "resources" / "words"
REVISION = "6bab3fef250481e34ba55bc400fac5c6d25f1429"
SOURCE_SHA256 = "1d18ada207c6551513c767492b9441619ceea0dfe0895552410040ee0c937223"
source = (WORDS / "cuss_source.js").read_bytes()
assert hashlib.sha256(source).hexdigest() == SOURCE_SHA256, "Unexpected cuss source"
# Strictly parse data rows, never evaluate third-party JavaScript.
ratings = {}
for line in source.decode("utf-8").splitlines():
    match = re.fullmatch(r"  (?:([a-z][a-z0-9]*)|'([^']*)'|\"([^\"]*)\"): ([012]),?", line)
    if match:
        word = next(group for group in match.groups()[:3] if group is not None)
        ratings[word] = int(match.group(4))
    elif line.startswith("  "):
        raise ValueError(f"Unrecognized source row: {line}")
assert len(ratings) > 1700
overrides = json.loads((WORDS / "mature_overrides.json").read_text(encoding="utf-8"))
roots = {word for word, rating in ratings.items() if rating == 2 and re.fullmatch(r"[a-z]+", word)}
roots.update(overrides["include"])
roots.difference_update(overrides["exclude"])
candidates = set(roots)
# Cover regular plurals and common inflections without arbitrary substring matching.
for word in roots:
    candidates.update(word + suffix for suffix in ("s", "es", "ed", "ing", "er", "ers", "y", "ly", "ier", "iest", "ness", "less"))
    if word.endswith("e"):
        candidates.update(word[:-1] + suffix for suffix in ("ing", "er", "ers", "y"))
    if word.endswith("y"):
        candidates.update(word[:-1] + suffix for suffix in ("ies", "ied", "ier", "iest", "iness"))
    if len(word) > 2 and word[-1] not in "aeiouwxy" and word[-2] in "aeiou" and word[-3] not in "aeiou":
        candidates.update(word + word[-1] + suffix for suffix in ("ed", "ing", "er", "ers", "y"))
dictionary = {json.loads(line) for line in (WORDS / "wordnik_source.txt").read_text(encoding="utf-8").splitlines() if line.strip()}
blocked = sorted(word for word in candidates & dictionary if re.fullmatch(r"[a-z]{1,24}", word)
                 and word not in overrides["exclude"]
                 and (ratings.get(word, 2) != 0 or word in overrides["include"]))
license_text = (WORDS / "CUSS_LICENSE.txt").read_text(encoding="utf-8")
resource = '\n'.join([
    '[gd_resource type="Resource" load_steps=2 format=3]', '',
    '[ext_resource type="Script" path="res://scripts/word_lexicon.gd" id="1"]', '',
    '[resource]', 'script = ExtResource("1")',
    'words = PackedStringArray(' + ', '.join(json.dumps(word) for word in blocked) + ')',
    'license_text = ' + json.dumps(license_text),
    'source_url = "https://github.com/words/cuss/tree/' + REVISION + '"', '',
])
(WORDS / "mature_words.tres").write_text(resource, encoding="utf-8", newline="\n")
print(f"Cuss source: {len(ratings)} entries; {len(blocked)} dictionary words blocked in OFF mode.")
