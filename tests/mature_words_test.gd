extends SceneTree

const Rules = preload("res://scripts/last_letter_round.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var game := Rules.new()
	game.prefix_advisor.enabled = false # Isolate the existing single-letter rule regression.
	var validator := game.validator
	var policy := validator.policy
	_expect(not policy.profanity_allowed and policy.blocked_words.size() == 1015, "Default OFF must load the complete bundled filter.")
	_expect(policy.MatureLexicon.license_text.contains("Copyright (c) 2016 Titus Wormer"), "Filter resource must carry its MIT attribution into exports.")
	for word in ["shit", "fuck", "fucked", "fucking", "bitch", "bitches", "bastards", "asshole", "damn", "idiot", "moron", "shitting"]:
		_expect(policy.blocked_words.has(word), "Common profanity or inflection is missing: " + word)
	# Every compiled filter entry must be a real word: OFF rejects it, ON accepts it.
	for word: String in policy.blocked_words:
		policy.profanity_allowed = false
		_expect(validator.rejection_reason(word, word.left(1), {}).contains("Wortfilter"), "OFF must reject a listed real word: " + word)
		policy.profanity_allowed = true
		_expect(validator.rejection_reason(word, word.left(1), {}).is_empty(), "ON must allow a listed dictionary word: " + word)
	for allowed in [false, true]:
		policy.profanity_allowed = allowed
		for word in ["apple", "sun", "class", "classic", "assassin", "cocktail", "grape", "analysis", "gay", "lesbian", "homosexual", "black", "white", "addict"]:
			_expect(validator.rejection_reason(word, word.left(1), {}).is_empty(), "Ordinary complete words must work in both modes: " + word)
		_expect(not validator.rejection_reason("shitzqxmadeup", "s", {}).is_empty(), "ON must not bypass dictionary validation.")
		_expect(not validator.rejection_reason("apple", "b", {}).is_empty(), "Both modes must enforce initial letters.")
		_expect(validator.rejection_reason("APPLE", "a", {"apple": true}).contains("schon benutzt"), "Both modes must reject normal repeated words.")
		game.start(4, 0, 0, "s")
		var result := game.submit("  ShIt  ", 1000)
		if not allowed:
			_expect(result == Rules.Verdict.INVALID and game.hearts[0] == 2 and game.deadline_ms == 10000
				and game.used_words.is_empty() and game.required_letter == "s", "Filtered word must cost exactly one heart and leave the clock and chain unchanged.")
			_expect(game.submit("sun", 1100) == Rules.Verdict.VALID, "A normal word must remain valid after a filtered attempt.")
		else:
			_expect(result == Rules.Verdict.VALID and game.hearts[0] == 3 and game.required_letter == "t", "Allowed mature word must participate in the real chain.")
			game.advance_player()
			game.begin_turn(2000)
			_expect(game.submit("toss", 2100) == Rules.Verdict.VALID, "A normal word can follow an accepted mature word.")
			game.advance_player()
			game.begin_turn(3000)
			_expect(game.submit("SHIT", 3100) == Rules.Verdict.INVALID and game.last_error.contains("schon benutzt"), "ON must still reject repeated mature words.")
	# Match configuration is copied at start, not read live by the validator.
	var table := (load("res://scenes/table_prototype/table_prototype.tscn") as PackedScene).instantiate()
	root.add_child(table)
	table.match_settings.mature_words_allowed = true
	table.enter_table(0, "s")
	table.match_settings.mature_words_allowed = false
	_expect(table.round_state.validator.policy.profanity_allowed, "Changing pending settings must not change the active round snapshot.")
	table.enter_table(0, "s")
	_expect(not table.round_state.validator.policy.profanity_allowed, "Next round must take the new setting.")
	table.leave_table()
	table.queue_free()
	await process_frame
	print("MATURE_WORDS: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
