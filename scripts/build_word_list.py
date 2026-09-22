"""Rebuild the bundled Godot resource from the pinned, vendored Wordnik source.

No network access. Run: python scripts/build_word_list.py
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORDS = ROOT / "resources" / "words"
SOURCE_SHA256 = "bfd1b4eb4ade1ba81e84c7e24248b9a1aecec9d9baA427453b367a83e30e0451".lower()
source = (WORDS / "wordnik_source.txt").read_bytes()
assert hashlib.sha256(source).hexdigest() == SOURCE_SHA256, "Unexpected source revision"
entries = [json.loads(line) for line in source.decode("utf-8").splitlines() if line.strip()]
words = sorted({word for word in entries if re.fullmatch(r"[a-z]{1,24}", word)} | {"a", "i"})
license_text = (WORDS / "WORDNIK_LICENSE.txt").read_text(encoding="utf-8")
resource = '\n'.join([
    '[gd_resource type="Resource" load_steps=2 format=3]', '',
    '[ext_resource type="Script" path="res://scripts/word_lexicon.gd" id="1"]', '',
    '[resource]', 'script = ExtResource("1")',
    'words = PackedStringArray(' + ', '.join(json.dumps(word) for word in words) + ')',
    'license_text = ' + json.dumps(license_text),
    'source_url = "https://github.com/wordnik/wordlist/tree/46e6215d0f90356afe9c8ba4be347e7e98cb425c"', '',
])
(WORDS / "english_words.tres").write_text(resource, encoding="utf-8", newline="\n")
print(f"Bundled {len(words)} words from {len(entries)} source entries (+ a/i); license included.")
