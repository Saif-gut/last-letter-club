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
	game.prepare(4, 2)
	_expect(game.required_letter.is_empty() and game.deadline_ms == 0 and not game.turn_running,
		"Preparation must reset the letter and clock without starting a turn.")
	game.begin_turn(1000)
	_expect(not game.turn_running and not game.expire(100000), "Countdown cannot start or expire a turn.")
	_expect(game.submit("apple", 100000) == Rules.Verdict.IGNORED and game.hearts == [3, 3, 3, 3],
		"Countdown submissions must not cost hearts or create words.")
	game.begin_round(200000)
	_expect(game.deadline_ms == 210000 and game.seconds_left(200000) == 10.0,
		"Only countdown completion starts the full first ten seconds.")
	game.begin_round(200500)
	_expect(game.deadline_ms == 210000, "Repeated countdown completion must not reset the clock.")
	game.prepare(4, 0)
	game.stop()
	game.begin_round(300000)
	_expect(not game.turn_running and game.required_letter.is_empty(), "Cancelled preparation cannot start later.")
	var initials: Dictionary = {}
	for index in 256:
		game.start(4, 0, 0)
		initials[game.required_letter] = true
		_expect(game.required_letter.length() == 1 and Rules.FIRST_START_LETTERS.contains(game.required_letter)
			and not "qxz".contains(game.required_letter), "Random opening letters must exclude Q, X and Z.")
	_expect(initials.size() > 1, "Opening letter must not be constant.")
	for pair in [["suq", "q"], ["box", "x"], ["jazz", "z"]]:
		game.start(4, 0, 0, pair[0].left(1))
		_expect(game.submit(pair[0], 1) == Rules.Verdict.VALID and game.required_letter == pair[1],
			"The opening restriction must not affect later chain letters.")
	game.start(4, 0, 1000, "a")
	_expect(game.hearts == [3, 3, 3, 3] and game.alive.count(true) == 4, "All players start with three hearts.")
	_expect(game.seconds_left(1000) == 10.0 and game.required_letter == "a", "New turn starts with ten seconds and a letter.")
	_expect(game.validator.dictionary.size() == 198419, "The full offline dictionary must be present.")
	_expect(game.validator.Lexicon.license_text.contains("Copyright (c) 2020 Wordnik"), "Exported lexicon must include attribution.")
	_expect(game.submit("aqzxmadeup", 2000) == Rules.Verdict.INVALID, "Invented words must fail.")
	_expect(game.hearts[0] == 2 and game.active_player == 0 and game.deadline_ms == 11000, "Invalid loses one heart without changing seat or deadline.")
	_expect(game.submit("banana", 3000) == Rules.Verdict.INVALID, "Wrong initial must fail.")
	_expect(game.hearts[0] == 1 and game.seconds_left(4000) == 7.0, "Retry clock must continue.")
	_expect(game.submit("  ApPlE  ", 4500) == Rules.Verdict.VALID, "Normalize case and outer whitespace.")
	_expect(game.required_letter == "e" and game.used_words.has("apple"), "Last letter becomes required initial and word is remembered.")
	_expect(game.submit("apple", 4600) == Rules.Verdict.IGNORED and game.hearts[0] == 1, "Repeated Enter during transition must be ignored.")
	_expect(not game.expire(50000), "Camera travel must not cause timeouts.")
	_expect(game.advance_player() == 1, "Valid word advances to the next player.")
	game.begin_turn(50000)
	_expect(game.seconds_left(50000) == 10.0, "Next turn receives a fresh ten seconds after camera travel.")
	_expect(game.submit("era", 50001) == Rules.Verdict.VALID, "A second valid word must chain.")
	game.advance_player()
	game.begin_turn(60000)
	_expect(game.submit("APPLE", 60001) == Rules.Verdict.INVALID, "Repeated word must be rejected case-insensitively.")
	_expect(game.last_error.contains("schon benutzt"), "Duplicate should have the correct reason.")
	_expect(game.submit("Apfel", 60002) == Rules.Verdict.INVALID, "German word absent from English dictionary must fail.")
	_expect(game.submit("", 60003) == Rules.Verdict.ELIMINATED, "Third invalid attempt eliminates, including empty submissions.")
	_expect(game.hearts[2] == 0 and not game.alive[2], "No hearts means out.")
	_expect(game.advance_player() == 3, "Elimination advances to a survivor.")
	game.begin_turn(70000)
	_expect(not game.expire(79999), "Must allow the last millisecond.")
	_expect(game.submit("apple", 80000) == Rules.Verdict.TIMEOUT, "Deadline must win over a submission at exactly ten seconds.")
	_expect(not game.alive[3] and game.hearts[3] == 3, "Timeout eliminates immediately even with three hearts.")
	_expect(game.advance_player() == 0, "Seat order must wrap.")
	game.begin_turn(81000)
	_expect(game.submit("ant", 81001) == Rules.Verdict.VALID, "Remaining survivor can continue.")
	game.advance_player()
	game.begin_turn(82000)
	_expect(game.submit("tree", 82001) == Rules.Verdict.VALID, "Second survivor can continue.")
	_expect(game.advance_player() == 0, "Eliminated seats must be skipped.")
	game.begin_turn(83000)
	_expect(game.expire(93000), "Survivor can time out.")
	_expect(game.finished and game.winner == 1, "Last player wins.")
	_expect(game.submit("egg", 94000) == Rules.Verdict.IGNORED, "Finished round must lock submissions.")
	game.start(4, 3, 100000, "a")
	_expect(game.hearts == [3, 3, 3, 3] and game.used_words.is_empty() and game.winner == -1 and not game.finished, "Restart must reset all state.")
	_expect(game.submit("apple", 100001) == Rules.Verdict.VALID, "Previous round words may be reused.")
	game.start(2, 0, 0, "a")
	for word in ["abc123", "apple-pie", "Äpfel"]:
		_expect(not game.validator.rejection_reason(word, "a", {}).is_empty(), "Reject unsupported characters: " + word)
	_expect(game.validator.rejection_reason("a", "a", {}).is_empty(), "English one-letter word a is supported.")
	_expect(game.validator.rejection_reason("I", "i", {}).is_empty(), "English one-letter word I is supported.")
	game.validator.policy.blocked_words["apple"] = true
	_expect(game.submit("apple", 1) == Rules.Verdict.INVALID, "Prepared policy can reject a dictionary word.")
	game.validator.policy.profanity_allowed = true
	_expect(game.submit("apple", 2) == Rules.Verdict.VALID, "Policy setting can permit tagged words.")
	_expect(not game.validator.rejection_reason("aqzxmadeup", "a", {}).is_empty(), "Policy cannot permit invented words.")
	game.start(4, 0, 0, "e")
	_expect(game.submit("eqzxmadeup", 9900) == Rules.Verdict.INVALID, "Late invalid retry loses one heart.")
	_expect(game.expire(10000) and not game.alive[0] and game.hearts[0] == 2, "Timeout during red feedback must still eliminate.")
	game.start(2, 0, 0, "a")
	game.stop()
	_expect(not game.expire(100000) and game.submit("apple", 1) == Rules.Verdict.IGNORED, "Leaving stops the round clock and submissions.")
	print("ROUND_RULES: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
