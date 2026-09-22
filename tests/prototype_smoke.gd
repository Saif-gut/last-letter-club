extends SceneTree
## Run with --path . --script res://tests/prototype_smoke.gd.
## Optional: -- --capture saves rendered frames under .godot/prototype_checks/.

var prototype: Node3D
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _key(code: Key, unicode: int = 0, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.unicode = unicode
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	if pressed and code != KEY_TAB:
		var release := InputEventKey.new()
		release.keycode = code
		Input.parse_input_event(release)
		await process_frame


func _type(text: String) -> void:
	for character in text:
		await _key(KEY_NONE, character.unicode_at(0))
		_expect(prototype.seats[prototype.active_seat].word_label.text == prototype.word_input.text,
			"Floating word must update after each typed character.")


func _capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/prototype_checks")
	var result := root.get_texture().get_image().save_png("res://.godot/prototype_checks/" + filename + ".png")
	_expect(result == OK, "Screenshot could not be saved.")


func _wait_for_phase(expected: int) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while prototype.phase != expected and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(prototype.phase == expected, "Timed out waiting for phase %d." % expected)


func _expect_one_active() -> void:
	var visible_words := 0
	for seat in prototype.seats:
		if seat.word_label.visible:
			visible_words += 1
	_expect(visible_words == 1, "Exactly one seat must have an active word display.")


func _run() -> void:
	var scene := load("res://scenes/table_prototype/table_prototype.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	prototype = main
	prototype.round_state.prefix_advisor.enabled = false
	prototype.enter_table(0, "a")
	await _wait_for_phase(prototype.Phase.TYPING)
	await process_frame
	await process_frame
	prototype.word_input.grab_focus()
	_expect(prototype.seats.size() == 4, "Four seats must exist.")
	_expect(prototype.camera.current, "Seat camera must be current.")
	_expect(is_equal_approx(prototype.camera.position.y, 1.22), "Camera must start at seated eye height.")
	_expect_one_active()
	await _type("Apfel")
	_expect(prototype.word_input.text == "Apfel", "Keyboard entry must reach the LineEdit.")
	await _capture("01_typing")
	await _key(KEY_BACKSPACE)
	_expect(prototype.word_input.text == "Apfe", "Backspace must edit the word.")
	_expect(prototype.seats[0].word_label.text == "Apfe", "Backspace must update the floating word.")
	await _type("l")
	await _key(KEY_TAB)
	_expect(prototype.overview, "Holding Tab must show the overview.")
	await _capture("02_overview")
	var retry_deadline: int = prototype.round_state.deadline_ms
	var retry_remaining: float = prototype.round_state.seconds_left(Time.get_ticks_msec())
	await _key(KEY_ENTER)
	_expect(prototype.phase == prototype.Phase.FEEDBACK and not prototype.word_input.editable, "Red feedback briefly locks the rejected text before clearing.")
	_expect(prototype.round_state.hearts[0] == 2, "Invalid word must cost one heart.")
	_expect(prototype.seats[0].word_label.modulate == prototype.FAILURE, "Rejected word must flash red.")
	await _key(KEY_ENTER)
	await _key(KEY_X, 120)
	_expect(prototype.word_input.text == "Apfel" and prototype.round_state.hearts[0] == 2, "Red feedback preserves rejected text and ignores duplicate submissions.")
	await _capture("03_invalid")
	await create_timer(prototype.feedback_seconds + 0.05).timeout
	_expect(prototype.active_seat == 0 and prototype.word_input.text.is_empty()
		and prototype.seats[0].word_label.text == "…", "Rejected word must clear automatically in both displays without changing seat.")
	_expect(prototype.word_input.has_focus() and prototype.word_input.is_editing() and prototype.word_input.editable,
		"Auto-clear must restore editing without clicking.")
	_expect(prototype.round_state.deadline_ms == retry_deadline
		and prototype.round_state.seconds_left(Time.get_ticks_msec()) < retry_remaining - 0.2, "Red feedback and auto-clear must not pause or restart the timer.")
	await _capture("09_auto_cleared")
	await _key(KEY_TAB, 0, false)
	_expect(not prototype.overview, "Releasing Tab must restore first person.")
	var initial_position: Vector3 = prototype.camera.position
	await _type("Apple")
	_expect(prototype.word_input.text == "Apple", "Next word must work without Esc, Backspace or a click.")
	await _key(KEY_ENTER)
	_expect(prototype.word_input.text == "Apple", "Auto-clear must not erase accepted words during green feedback.")
	_expect(prototype.seats[0].word_label.modulate == prototype.SUCCESS, "Accepted word must flash green.")
	await _capture("04_valid")
	await _key(KEY_ENTER)
	await _wait_for_phase(prototype.Phase.MOVING)
	_expect_one_active()
	_expect(not prototype.seats[0].avatar.visible, "Departing avatar must not intersect the camera.")
	await create_timer(0.22).timeout
	_expect(prototype.camera.position.distance_to(initial_position) > 0.1, "Camera must move between seats.")
	_expect(is_equal_approx(Vector2(prototype.camera.position.x, prototype.camera.position.z).length(), 2.25),
		"Camera must orbit outside the table at constant radius.")
	_expect(is_equal_approx(prototype.camera.position.y, 1.22), "Camera must remain at seated height during the transition.")
	await _key(KEY_X, "x".unicode_at(0))
	_expect(prototype.word_input.text.is_empty(), "Typing must be locked during movement.")
	await _capture("05_transition")
	await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.active_seat == 1, "Repeated Enter must advance exactly one seat.")
	_expect(prototype.seats[0].avatar.visible and not prototype.seats[1].avatar.visible,
		"Only the current first-person avatar should be hidden after arrival.")
	_expect(prototype.camera.position.is_equal_approx(Vector3(2.25, 1.22, 0)), "Camera must arrive at seat two.")
	_expect(prototype.word_input.has_focus(), "Input focus must return after movement.")
	await _key(KEY_ENTER)
	await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.active_seat == 1, "Empty input must not advance the turn.")
	await _type("Ärger")
	_expect(prototype.word_input.text == "Ärger", "German characters must work.")
	await _key(KEY_ESCAPE)
	_expect(prototype.word_input.text.is_empty(), "Escape must clear the word.")
	await _type("abcdefghijklmnopqrstuvwxyz")
	_expect(prototype.word_input.text.length() == 24, "Input must be limited to 24 characters.")
	await _capture("06_long_word")
	await _key(KEY_ESCAPE)
	var chain := ["Eagle", "Earth", "House"]
	for expected_seat in [2, 3, 0]:
		await _type(chain.pop_front())
		await _key(KEY_ENTER)
		await _wait_for_phase(prototype.Phase.MOVING)
		_expect_one_active()
		await _wait_for_phase(prototype.Phase.TYPING)
		_expect(prototype.active_seat == expected_seat, "Seat order or wraparound is incorrect.")
	_expect(prototype.camera.position.is_equal_approx(initial_position), "Full round must return to the initial camera position.")
	_expect(prototype.round_state.required_letter == "e" and prototype.round_state.used_words.size() == 4, "Camera turns must follow the real word chain.")
	# Red feedback must not delay timeout or revive an expired turn.
	prototype.word_input.text = "eqzxmadeup"
	prototype.round_state.deadline_ms = Time.get_ticks_msec() + 90
	prototype._submit()
	await create_timer(0.15).timeout
	_expect(not prototype.round_state.alive[0] and not prototype.word_input.editable, "Timeout during red feedback must eliminate and lock input.")
	await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.active_seat == 1 and prototype.round_state.seconds_left(Time.get_ticks_msec()) > 9.5, "Next survivor must receive full time after travel.")
	for expected_seat in [2, 3]:
		prototype.round_state.deadline_ms = Time.get_ticks_msec()
		await _wait_for_phase(prototype.Phase.FEEDBACK)
		await _wait_for_phase(prototype.Phase.TYPING if expected_seat == 2 else prototype.Phase.FINISHED)
	_expect(prototype.round_state.winner == 3 and prototype.rules_label.text.contains("04 GEWINNT"), "Last player must be announced as winner.")
	await _capture("07_winner")
	await _key(KEY_ENTER)
	_expect(prototype.phase == prototype.Phase.FINISHED, "Enter cannot alter a completed round.")
	await _key(KEY_F5)
	_expect(prototype.phase == prototype.Phase.COUNTDOWN and prototype.round_state.hearts == [3, 3, 3, 3]
		and prototype.round_state.used_words.is_empty(), "F5 restarts all round state.")
	# Real UI heart elimination, then a 180-degree arc past that eliminated seat.
	prototype.enter_table(1, "a")
	await _wait_for_phase(prototype.Phase.TYPING)
	for attempt in 3:
		await _type("Apfel")
		await _key(KEY_ENTER)
		if attempt < 2:
			await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.round_state.hearts[1] == 0 and not prototype.round_state.alive[1], "Three actual Enter submissions must eliminate the seat.")
	await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.active_seat == 2, "Heart elimination must move the table camera.")
	for word in ["Apple", "Eagle"]:
		await _type(word)
		await _key(KEY_ENTER)
		await _wait_for_phase(prototype.Phase.MOVING)
		await _wait_for_phase(prototype.Phase.TYPING)
	await _type("Earth")
	await _key(KEY_ENTER)
	await _wait_for_phase(prototype.Phase.MOVING)
	_expect(prototype.active_seat == 2, "Camera must skip eliminated seat two.")
	await create_timer(0.22).timeout
	_expect(is_equal_approx(Vector2(prototype.camera.position.x, prototype.camera.position.z).length(), 2.25)
		and is_equal_approx(prototype.camera.position.y, 1.22), "Skipped-seat arc must keep the existing radius and eye height.")
	await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.camera.position.is_equal_approx(Vector3(0, 1.22, -2.25)), "Skipped-seat arc must arrive at the correct chair.")
	# One wall-clock test exercises the real process loop with the unmodified 10s limit.
	prototype.enter_table(0, "a")
	await _wait_for_phase(prototype.Phase.TYPING)
	await create_timer(9.7).timeout
	_expect(prototype.round_state.alive[0] and prototype.phase == prototype.Phase.TYPING, "Player must still be alive just before the real deadline.")
	await create_timer(0.4).timeout
	_expect(not prototype.round_state.alive[0] and prototype.round_state.hearts[0] == 3, "Ten real seconds without a word must eliminate a player with full hearts.")
	await _capture("08_timeout")
	await _wait_for_phase(prototype.Phase.TYPING)
	_expect(prototype.active_seat == 1, "Real timeout must continue to the next player.")
	# Exercise the actual filter through the same word-entry UI in both modes.
	for allowed in [false, true]:
		prototype.match_settings.mature_words_allowed = allowed
		prototype.enter_table(0, "s")
		await _wait_for_phase(prototype.Phase.TYPING)
		await _type("shit")
		await _key(KEY_ENTER)
		_expect(prototype.input_panel.border_color == (prototype.SUCCESS if allowed else prototype.FAILURE),
			"Mature mode must drive real word feedback.")
		if allowed:
			_expect(prototype.round_state.used_words.has("shit") and prototype.round_state.hearts[0] == 3,
				"ON must accept a dictionary profanity without heart loss.")
			await _wait_for_phase(prototype.Phase.MOVING)
			await _wait_for_phase(prototype.Phase.TYPING)
		else:
			await _wait_for_phase(prototype.Phase.TYPING)
			_expect(prototype.word_input.text.is_empty() and prototype.round_state.hearts[0] == 2,
				"OFF must reject and automatically clear a profanity.")
			await _type("sun")
			await _key(KEY_ENTER)
			_expect(prototype.round_state.used_words.has("sun"), "Normal retry after filtered word must succeed.")
			await _wait_for_phase(prototype.Phase.MOVING)
			await _wait_for_phase(prototype.Phase.TYPING)
	# The last rejected word also clears if heart loss ends the entire round.
	prototype.enter_table(0, "a")
	await _wait_for_phase(prototype.Phase.TYPING)
	prototype.round_state.start(2, 0, Time.get_ticks_msec(), "a")
	# Keep four presentation entries, with the last two already eliminated.
	prototype.round_state.hearts.append_array([0, 0])
	prototype.round_state.alive.append_array([false, false])
	prototype.round_state.hearts[0] = 1
	await _type("Apfel")
	await _key(KEY_ENTER)
	await _wait_for_phase(prototype.Phase.FINISHED)
	_expect(prototype.word_input.text.is_empty() and not prototype.word_input.editable
		and prototype.round_state.winner == 1, "Rejected final word clears without reviving eliminated player.")
	print("PROTOTYPE_SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
