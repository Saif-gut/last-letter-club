extends SceneTree
## Real graphical lobby -> countdown -> chain -> winner -> restart integration.

var lobby: Node3D
var table: Node3D
var failures := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("COUNTDOWN_FLOW requires a graphical window for lobby input.")
		quit(2)
		return
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _key(code: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _type(word: String) -> void:
	for letter in word:
		await _key(KEY_NONE, letter.unicode_at(0))


func _wait_phase(expected: int) -> void:
	var limit := Time.get_ticks_msec() + 5000
	while table.phase != expected and Time.get_ticks_msec() < limit:
		await process_frame
	_expect(table.phase == expected, "Expected table phase %d" % expected)


func _capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/countdown_checks")
	_expect(root.get_texture().get_image().save_png("res://.godot/countdown_checks/%s.png" % name) == OK, "Capture failed.")


func _check_countdown(prefix: String) -> void:
	var started: int = table.countdown_started_ms
	for stage in ["3", "2", "1", "GO"]:
		var limit := Time.get_ticks_msec() + 1500
		while table.countdown_label.text != stage and Time.get_ticks_msec() < limit:
			await process_frame
		_expect(table.countdown_label.visible and table.countdown_label.text == stage, "Missing countdown stage " + stage)
		var elapsed := Time.get_ticks_msec() - started
		var expected_ms: int = ["3", "2", "1", "GO"].find(stage) * 1000
		_expect(elapsed >= expected_ms and elapsed < expected_ms + 350, "Each countdown number must last about a second.")
		_expect(not table.word_input.editable and not table.round_state.turn_running
			and table.round_state.required_letter.is_empty() and table.round_state.deadline_ms == 0,
			"No input, chosen letter or running deadline during " + stage)
		await _type("test")
		await _key(KEY_ENTER)
		await _key(KEY_F5)
		_expect(table.word_input.text.is_empty() and table.round_state.hearts == [3, 3, 3, 3]
			and table.round_state.used_words.is_empty() and table.countdown_started_ms == started,
			"Countdown input must not submit words, lose hearts or restart countdown.")
		await _capture(prefix + "_" + stage)
	await _wait_phase(table.Phase.TYPING)
	var now := Time.get_ticks_msec()
	_expect(now - started >= 3500 and now - started < 3900, "GO must be visible briefly before the first turn.")
	_expect(table.round_state.seconds_left(now) > 9.9 and table.round_state.seconds_left(now) <= 10.0,
		"First player must receive ten full seconds after GO.")
	_expect(table.round_state.required_letter.length() == 1
		and table.RoundRules.FIRST_START_LETTERS.contains(table.round_state.required_letter), "Opening letter must be a random permitted letter.")
	_expect(table.word_input.has_focus() and table.word_input.is_editing() and not table.countdown_label.visible,
		"GO completion must restore input without a click.")
	_expect(table.rules_label.text.contains("VORGABE  " + table.round_state.required_prefix.to_upper()), "Selected letter must be visible.")
	await _capture(prefix + "_first_turn")


func _valid_word() -> String:
	for word: String in table.round_state.validator.dictionary:
		if word.length() >= 3 and word.length() <= 7 and table.round_state.validator.rejection_reason(
			word, table.round_state.required_prefix, table.round_state.used_words).is_empty():
			return word
	return ""


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	lobby = main.get_node("Lobby")
	table = lobby.table
	await create_timer(0.2).timeout
	await _key(KEY_F6)
	lobby.player.position = Vector3(0, 0.05, 3.5)
	lobby.player.reset_camera()
	await create_timer(0.2).timeout
	await _key(KEY_E, 101)
	_expect(lobby.seated and root.get_camera_3d() == table.camera, "E must hand control to the table.")
	await _check_countdown("01_start")
	_expect(table.round_state.validator.policy.profanity_allowed, "Countdown must preserve Mature Words ON.")
	# Wait through most of the actual first turn; no countdown time may be deducted.
	await create_timer(9.0).timeout
	_expect(table.round_state.alive[0] and table.phase == table.Phase.TYPING
		and table.round_state.seconds_left(Time.get_ticks_msec()) > 0.6, "First turn must still be active nine seconds after GO.")
	for turn in 2:
		var word := _valid_word()
		_expect(not word.is_empty(), "Need a legal test word for the random initial.")
		await _type(word)
		await _key(KEY_ENTER)
		_expect(table.round_state.required_letter == word.right(1), "Accepted word must drive the unchanged word chain.")
		await _wait_phase(table.Phase.MOVING)
		await _wait_phase(table.Phase.TYPING)
		_expect(not table.countdown_label.visible and table.active_seat == turn + 1, "Countdown must not repeat between turns.")
	# Eliminate three participants with real invalid submissions.
	for eliminated in [2, 3, 0]:
		for attempt in 3:
			await _type("qzxmadeup")
			await _key(KEY_ENTER)
			if attempt < 2:
				await _wait_phase(table.Phase.TYPING)
		_expect(table.round_state.hearts[eliminated] == 0 and not table.round_state.alive[eliminated], "Three invalid attempts eliminate their player.")
		await _wait_phase(table.Phase.FINISHED if eliminated == 0 else table.Phase.TYPING)
	_expect(table.round_state.winner == 1 and table.rules_label.text.contains("02 GEWINNT"), "Last survivor must win.")
	await _type("winner")
	await _key(KEY_ENTER)
	await _key(KEY_ESCAPE)
	table._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(table.word_input.text.is_empty() and not table.word_input.editable and not table.word_input.has_focus()
		and table.phase == table.Phase.FINISHED, "Winner screen must lock word input, including after focus returns.")
	await _capture("02_winner")
	await _key(KEY_F5)
	_expect(table.phase == table.Phase.COUNTDOWN and table.active_seat == 1 and table.round_state.winner == -1
		and not table.round_state.finished and table.round_state.alive == [true, true, true, true]
		and table.round_state.used_words.is_empty(), "Restart must reset the completed round before counting down.")
	_expect(table.round_state.validator.policy.profanity_allowed and table.match_settings.mature_words_allowed,
		"Restart must retain Mature Words.")
	await _check_countdown("03_restart")
	# Leave during GO, rejoin, and ensure the old countdown cannot start the new round early.
	await _key(KEY_F4)
	await create_timer(0.2).timeout
	await _key(KEY_E, 101)
	await create_timer(3.1).timeout
	_expect(table.countdown_label.text == "GO", "Cancellation check must occur during GO.")
	await _key(KEY_F4)
	await create_timer(0.2).timeout
	await _key(KEY_E, 101)
	await create_timer(0.5).timeout
	_expect(table.phase == table.Phase.COUNTDOWN and table.countdown_label.text == "3"
		and not table.round_state.turn_running, "Cancelled countdown cannot start a freshly joined round.")
	await _key(KEY_F4)
	await create_timer(3.2).timeout
	_expect(not table.table_enabled and not table.round_state.turn_running and not table.countdown_label.visible
		and root.get_camera_3d() == lobby.player.camera, "Leaving countdown must keep lobby camera and input ownership.")
	print("COUNTDOWN_FLOW: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
