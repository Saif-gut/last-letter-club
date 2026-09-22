extends Resource
## Hint policy only; hearts, deadlines and validation never depend on difficulty.
## New modes can provide another resource with different scarcity/weight parameters.

enum Mode { EASY, NORMAL, HARD }
@export var display_name := "Normal"
@export var baseline := 0.15
@export var scarcity_weight := 0.55
@export var concentration_weight := 0.15
@export var short_word_reference := 600.0
@export var exceptional_short_limit := 0


static func for_mode(mode: int) -> Resource:
	var profile := load("res://scripts/difficulty_profile.gd").new() as Resource
	if mode == Mode.EASY:
		profile.display_name = "Easy"
		profile.baseline = 0.6
		profile.scarcity_weight = 0.3
		profile.concentration_weight = 0.05
	elif mode == Mode.HARD:
		profile.display_name = "Hard"
		profile.baseline = 0.0
		profile.scarcity_weight = 0.15
		profile.concentration_weight = 0.0
		profile.exceptional_short_limit = 40
	return profile


func hint_chance(stats: Dictionary) -> float:
	if stats.candidates.is_empty():
		return 0.0
	if exceptional_short_limit > 0 and stats.short_total > exceptional_short_limit:
		return 0.0
	var scarcity := 1.0 - clampf(float(stats.short_total) / short_word_reference, 0.0, 1.0)
	var strongest := 0
	for prefix: String in stats.candidates:
		strongest = maxi(strongest, stats.short_counts[prefix])
	var concentration := float(strongest) / maxf(1.0, float(stats.short_total))
	return clampf(baseline + scarcity_weight * scarcity + concentration_weight * concentration, 0.0, 0.95)
