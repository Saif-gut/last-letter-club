extends "res://tests/network_table_test.gd"

func state() -> Dictionary:
	return service.round_states.get("table_01", {})

func wait_phase(phase: String, active: int = 0) -> void:
	var end := Time.get_ticks_msec() + 13000
	while Time.get_ticks_msec() < end:
		if state().get("phase", "") == phase and (active == 0 or state().get("active_peer",0) == active):
			return
		await process_frame
	_expect(false, "Expected online phase " + phase)

func send_word(word: String) -> void:
	var previous_feedback: int = state().feedback_id
	root.grab_focus()
	await create_timer(0.1).timeout
	_expect(lobby.table.word_input.editable, "Active participant must be able to type.")
	lobby.table.word_input.grab_focus()
	lobby.table.word_input.edit()
	# Type real text events, then Enter through the real LineEdit signal.
	for letter in word:
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
	await _tap(KEY_ENTER)
	var limit := Time.get_ticks_msec() + 3000
	while state().feedback_id == previous_feedback and Time.get_ticks_msec() < limit:
		await process_frame
	_expect(state().feedback_id > previous_feedback, "Submission must receive a new host verdict.")

func _run() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	lobby = main.get_node("Lobby")
	session = lobby.network_session
	service = lobby.table_service
	await create_timer(0.3).timeout
	if role == "host":
		await _tap(KEY_F8)
		_mark("host_ready")
	else:
		await _wait_mark("host_ready")
		await _tap(KEY_F9)
	await _wait_players(2)
	await _seat(0 if role == "host" else 1)
	await _wait_seats(2)
	var other: int = service.tables.table_01.seats[1]
	if role == "host":
		await _wait_mark("client_ready")
		lobby.table.match_settings.difficulty = 0
		await _tap(KEY_F5)
	else:
		await _tap(KEY_F5)
		_expect(state().get("phase", "WAITING") == "WAITING", "Client F5 cannot start the round.")
		_mark("client_ready")
	for stage in ["3","2","1","GO"]:
		var limit := Time.get_ticks_msec() + 1800
		while state().get("countdown", "") != stage and Time.get_ticks_msec() < limit:
			await process_frame
		_expect(lobby.table.countdown_label.text == stage and not lobby.table.word_input.editable, "Host countdown stage must reach both locked views: " + stage)
	await wait_phase("TYPING",1)
	_expect(state().hearts == [3,3] and state().difficulty == 0 and not state().mature, "Both see host settings and initial hearts.")
	if role == "host":
		# Deterministic host fixture after testing the real generated opening/countdown.
		# This lets the network exercise ST, duplicate stone, and a closed word chain.
		var model: RefCounted = service.host_rounds.table_01
		model.rules.prefix_advisor.enabled = false
		model.rules.required_letter = "s"
		model.rules.required_prefix = "st"
		service._send_rounds()
		_mark("fixture_ready")
		await _wait_mark("client_locked")
		await send_word("stone")
		await wait_phase("TYPING",other)
		await _wait_mark("invalid_seen")
		_expect(state().hearts == [3,2] and state().prefix == "e", "Host sees client heart loss and continuing prefix.")
		_mark("invalid_checked")
		await wait_phase("TYPING",1)
		await send_word("STONE")
		await wait_phase("TYPING",1)
		_expect(state().hearts == [2,2] and state().error.contains("schon benutzt"), "Duplicate must be rejected authoritatively.")
		await send_word("snake")
		await wait_phase("TYPING",other)
	else:
		await _wait_mark("fixture_ready")
		await create_timer(0.15).timeout
		_expect(state().prefix == "st" and not lobby.table.word_input.editable, "Client receives full ST prefix but cannot play host's turn.")
		service.submit_word("table_01", "stone") # Deliberate out-of-turn network intention.
		await create_timer(0.15).timeout
		_expect(state().hearts == [3,3] and state().used_words.is_empty(), "Out-of-turn request cannot change state.")
		_mark("client_locked")
		await wait_phase("TYPING",other)
		var deadline: int = state().deadline
		await send_word("eqzxmadeup")
		await wait_phase("TYPING",other)
		_expect(state().hearts == [3,2] and state().deadline == deadline and lobby.table.word_input.text.is_empty()
			and lobby.table.word_input.has_focus() and lobby.table.word_input.is_editing(), "Invalid word clears/focuses without refreshing host deadline.")
		_mark("invalid_seen")
		await _wait_mark("invalid_checked")
		await send_word("epochs")
		await wait_phase("TYPING",1)
		await wait_phase("TYPING",other)
	# Real ten-second timeout on the client; both must name the same winner.
	await wait_phase("FINISHED")
	_expect(state().winner == 1 and state().alive == [true,false] and not lobby.table.word_input.editable, "Both peers must see the same timeout elimination and winner.")
	await _capture("online_winner_" + role)
	if role == "client":
		_mark("winner_seen")
	else:
		await _wait_mark("winner_seen")
		await _tap(KEY_F5)
	await wait_phase("COUNTDOWN")
	_expect(state().round_id == 2 and state().hearts == [3,3] and state().used_words.is_empty() and state().prefix.is_empty()
		and state().difficulty == 0 and not state().mature and _occupied() == 2, "Restart must reset round only, preserving settings and occupied seats.")
	await wait_phase("TYPING",1)
	_expect(session.connected and lobby.seated, "No rejoin required for next round.")
	if role == "client":
		_mark("restart_seen")
	else:
		await _wait_mark("restart_seen")
		await _tap(KEY_F10)
		_mark("host_left")
	if role == "client":
		await _wait_mark("host_left")
		await _wait_offline()
	await _check_offline()
	_expect(not lobby.seated and not lobby.table.table_enabled, "Session end must stop online view.")
	main.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
