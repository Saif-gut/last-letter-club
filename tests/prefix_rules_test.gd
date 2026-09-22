extends SceneTree

const Rules = preload("res://scripts/last_letter_round.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var game := Rules.new()
	var advisor := game.prefix_advisor
	advisor.rng.seed = 1729
	var modes_seen: Dictionary = {}
	for mature in [false, true]:
		game.validator.policy.profanity_allowed = mature
		var used := {"stone": true, "school": true, "shit": true}
		for initial in Rules.START_LETTERS:
			var stats := advisor.availability(initial, game.validator, used)
			# Independently count actual valid words for each candidate prefix.
			var actual: Dictionary = {}
			for word: String in game.validator.dictionary:
				if word.begins_with(initial) and not used.has(word) and game.validator.policy.allows(word):
					var prefix := word.left(2)
					actual[prefix] = actual.get(prefix, 0) + 1
			for prefix: String in stats.candidates:
				_expect(stats.counts[prefix] == actual.get(prefix, 0), "Prefix counts must exclude used and mature words exactly once.")
			for attempt in 20:
				var prefix := advisor.choose(initial, game.validator, used)
				modes_seen[prefix.length()] = true
				_expect(prefix.begins_with(initial) and prefix.length() <= 2, "Prefix must preserve mandatory initial.")
				if prefix.length() == 2:
					_expect(actual.get(prefix, 0) >= advisor.MIN_OPTIONS and stats.short_counts[prefix] >= advisor.MIN_SHORT_OPTIONS,
						"Generated prefix must have enough genuinely available dictionary words.")
	_expect(modes_seen.has(1) and modes_seen.has(2), "Both single and double prefixes must occur.")
	var depleted: Dictionary = {}
	for word: String in game.validator.dictionary:
		if word.begins_with("x"):
			depleted[word] = true
	_expect(advisor.choose("x", game.validator, depleted) == "x", "Exhausted two-letter options must fall back to the chain initial.")
	game.start(4, 0, 0, "s")
	game.required_prefix = "st"
	_expect(game.submit("snake", 1) == Rules.Verdict.INVALID and game.hearts[0] == 2 and game.deadline_ms == 10000,
		"Wrong complete prefix costs one heart without changing time.")
	_expect(game.submit("stone", 2) == Rules.Verdict.VALID and game.required_letter == "e" and game.required_prefix.begins_with("e"),
		"Last character must remain the next first mandatory letter.")
	game.advance_player()
	game.begin_turn(3)
	game.required_letter = "s"
	game.required_prefix = "st"
	_expect(game.submit("STONE", 4) == Rules.Verdict.INVALID and game.last_error.contains("schon benutzt"), "Two-letter prompts must still reject duplicates.")
	# Actual table feedback path: incorrect prefix -> red -> empty -> valid retry.
	var table := (load("res://scenes/table_prototype/table_prototype.tscn") as PackedScene).instantiate()
	root.add_child(table)
	table.enter_table(0, "s")
	var wait_limit := Time.get_ticks_msec() + 5000
	while table.phase != table.Phase.TYPING and Time.get_ticks_msec() < wait_limit:
		await process_frame
	_expect(table.phase == table.Phase.TYPING, "Table countdown must finish before testing input.")
	table.round_state.required_prefix = "st"
	table.word_input.text = "snake"
	var deadline: int = table.round_state.deadline_ms
	table._submit()
	_expect(table.input_panel.border_color == table.FAILURE, "Incorrect full prefix must show red feedback.")
	await create_timer(0.3).timeout
	_expect(table.word_input.text.is_empty() and table.word_input.editable and table.word_input.is_editing()
		and table.round_state.deadline_ms == deadline and table.round_state.hearts[0] == 2,
		"Prefix rejection must clear input, keep focus and preserve deadline.")
	table.word_input.text = "stone"
	table._submit()
	await create_timer(0.9).timeout
	_expect(table.active_seat == 1 and table.round_state.required_prefix.begins_with("e"), "Valid prefix retry must advance existing table camera and chain.")
	table.leave_table()
	table.queue_free()
	await process_frame
	print("PREFIX_RULES: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
