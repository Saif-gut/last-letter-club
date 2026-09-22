extends RefCounted
## Dictionary-derived hints. The first character always belongs to the last-letter chain.
## Counts include only playable words and discount mature/used words without rescanning 198k entries.

const MIN_OPTIONS := 25
const MIN_SHORT_OPTIONS := 5
const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
static var totals: Dictionary = {}
static var short_totals: Dictionary = {}
var enabled := true
var rng := RandomNumberGenerator.new()
var profile: Resource = DifficultyProfile.for_mode(DifficultyProfile.Mode.NORMAL)


func _init(validator: RefCounted) -> void:
	rng.randomize()
	if totals.is_empty():
		for word: String in validator.dictionary:
			for size in range(1, mini(2, word.length()) + 1):
				var prefix := word.left(size)
				totals[prefix] = totals.get(prefix, 0) + 1
				if word.length() <= 8:
					short_totals[prefix] = short_totals.get(prefix, 0) + 1


func availability(initial: String, validator: RefCounted, used_words: Dictionary) -> Dictionary:
	var counts := {initial: int(totals.get(initial, 0))}
	var short_counts := {initial: int(short_totals.get(initial, 0))}
	for second in "abcdefghijklmnopqrstuvwxyz":
		var prefix := initial + second
		counts[prefix] = int(totals.get(prefix, 0))
		short_counts[prefix] = int(short_totals.get(prefix, 0))
	var excluded := used_words.duplicate()
	if not validator.policy.profanity_allowed:
		excluded.merge(validator.policy.blocked_words)
	for word: String in excluded:
		if not word.begins_with(initial) or not validator.dictionary.has(word):
			continue
		for size in range(1, mini(2, word.length()) + 1):
			var prefix := word.left(size)
			counts[prefix] -= 1
			if word.length() <= 8:
				short_counts[prefix] -= 1
	var candidates: Array[String] = []
	for prefix: String in counts:
		if prefix.length() == 2 and counts[prefix] >= MIN_OPTIONS and short_counts[prefix] >= MIN_SHORT_OPTIONS:
			candidates.append(prefix)
	return {"counts": counts, "short_counts": short_counts, "candidates": candidates,
		"total": counts[initial], "short_total": short_counts[initial]}


func choose(initial: String, validator: RefCounted, used_words: Dictionary) -> String:
	if not enabled:
		return initial
	var stats := availability(initial, validator, used_words)
	if stats.candidates.is_empty():
		return initial
	var chance: float = profile.hint_chance(stats)
	if rng.randf() >= chance:
		return initial
	# Weight candidates by short-word availability, not by random A-Z combinations.
	var total_weight := 0.0
	for prefix: String in stats.candidates:
		total_weight += sqrt(float(stats.short_counts[prefix]))
	var pick := rng.randf() * total_weight
	for prefix: String in stats.candidates:
		pick -= sqrt(float(stats.short_counts[prefix]))
		if pick <= 0:
			return prefix
	return stats.candidates.back()
