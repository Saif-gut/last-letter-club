extends "res://tests/network_round_test.gd"

var target_id := "table_01"
var isolated := true

func state() -> Dictionary:
	return service.round_states.get(target_id, {})

func _watch_scope() -> void:
	for id: String in service.round_states:
		if id != target_id:
			isolated = false

func seat_at(table_id: String, index: int) -> void:
	var table: Node3D = service.definitions[table_id]
	root.grab_focus()
	lobby.player.global_position = table.to_global(Vector3(sin(TAU*index/4)*3.5,0.05,cos(TAU*index/4)*3.5))
	lobby.player.rotation.y = TAU*index/4
	lobby.player.reset_camera()
	await create_timer(0.4).timeout
	await _tap(KEY_E)
	var end := Time.get_ticks_msec()+3000
	while service.seat_of(session.local_id).is_empty() and Time.get_ticks_msec()<end:
		await process_frame
	_expect(service.seat_of(session.local_id).get("table_id","") == table_id, "Walking to the desired table must select its ID.")
	_expect(lobby.online_view.current_table == table and root.get_camera_3d() == table.camera, "Own translated table must own the local camera.")
	var direction: Vector3 = (table.to_global(Vector3(0,0.95,0)) - table.camera.global_position).normalized()
	_expect(direction.dot(-table.camera.global_basis.z) > 0.999, "Translated table camera must look at its own center.")

func send_word(word: String) -> void:
	var table: Node3D = lobby.online_view.current_table
	var feedback: int = state().feedback_id
	root.grab_focus()
	await create_timer(0.1).timeout
	_expect(table.word_input.editable, "Only active local participant may type.")
	table.word_input.grab_focus()
	table.word_input.edit()
	for character in word:
		var key := InputEventKey.new()
		key.unicode = character.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
	await _tap(KEY_ENTER)
	var limit := Time.get_ticks_msec()+3000
	while state().feedback_id == feedback and Time.get_ticks_msec()<limit:
		await process_frame
	_expect(state().feedback_id > feedback, "Word must receive a host verdict.")

func _run() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	lobby = main.get_node("Lobby")
	session = lobby.network_session
	service = lobby.table_service
	var index: int = ["host","b","c","d"].find(role)
	target_id = "table_01" if index < 2 else "table_02"
	process_frame.connect(_watch_scope)
	await create_timer(0.3).timeout
	_expect(service.definitions.size() == 2, "Two real placeholder tables must exist.")
	if role == "host":
		await _tap(KEY_F8)
		_mark("host_ready")
	else:
		await _wait_mark("host_ready")
		await _tap(KEY_F9)
	await _wait_players(4)
	_expect(service.player_state(session.local_id).mode == "FREE", "Joined player must be FREE before choosing a table.")
	if index > 0:
		await _wait_mark("seat_%d" % (index-1))
	await seat_at(target_id, index if index < 2 else index-1)
	_expect(service.player_state(session.local_id).mode == "SEATED", "Host-assigned seat must expose SEATED status.")
	_mark("seat_%d" % index)
	await _wait_mark("seat_3")
	await create_timer(0.15).timeout
	_expect(service.tables.table_01.seats.count(0) == 2 and service.tables.table_02.seats.count(0) == 2, "Occupancy must be independent, two players per table.")
	var b: int = service.tables.table_01.seats[1]
	var c: int = service.tables.table_02.seats[1]
	var d: int = service.tables.table_02.seats[2]
	if role == "host":
		service.definitions.table_01.match_settings.difficulty = 0
		service.definitions.table_02.match_settings.difficulty = 2
		service.definitions.table_02.match_settings.mature_words_allowed = true
		lobby.network_panel.start_buttons.table_01.pressed.emit()
		await wait_phase("TYPING",1)
		var first: RefCounted = service.host_rounds.table_01
		first.rules.required_prefix = "st"
		first.rules.prefix_advisor.enabled = false
		service._send_rounds()
		lobby.network_panel.start_buttons.table_02.pressed.emit()
		await send_word("stone")
		await wait_phase("TYPING",b)
		var limit := Time.get_ticks_msec()+5000
		while service.host_rounds.table_02.phase != "TYPING" and Time.get_ticks_msec()<limit:
			await process_frame
		var second: RefCounted = service.host_rounds.table_02
		second.rules.required_prefix = "e"
		second.rules.prefix_advisor.enabled = false
		service._send_rounds()
		_expect(first.phase == "TYPING" and second.phase == "TYPING" and first.rules.deadline_ms != second.rules.deadline_ms, "Two simultaneous independent deadlines must run.")
		var first_deadline: int = first.rules.deadline_ms
		_mark("parallel_ready")
		await _wait_mark("c_invalid")
		_expect(first.rules.hearts == [3,3] and first.rules.used_words.has("stone") and first.rules.deadline_ms == first_deadline, "Other table's invalid word must not affect table 01.")
		_expect(second.rules.hearts == [2,3] and not second.rules.used_words.has("stone"), "Only table 02 loses its own heart.")
		_mark("invalid_checked")
		await _wait_mark("d_left")
		await _wait_mark("c_winner")
		_expect(second.phase == "FINISHED" and second.snapshot(Time.get_ticks_msec()).winner == c and first.phase == "TYPING", "Disconnect must finish only the departed player's table.")
		_mark("loss_checked")
		await wait_phase("FINISHED")
		await _wait_mark("b_finished")
		var second_state: Dictionary = second.snapshot(Time.get_ticks_msec())
		lobby.network_panel.start_buttons.table_01.pressed.emit()
		await wait_phase("COUNTDOWN")
		_expect(second.round_id == second_state.round_id and second.rules.hearts == second_state.hearts and second.rules.used_words.keys() == second_state.used_words,
			"Restarting table 01 cannot reset table 02.")
		_mark("restart_checked")
	elif role == "b":
		await _wait_mark("parallel_ready")
		_expect(state().difficulty == 0 and not state().mature, "Table 01 receives only its own settings.")
		_expect(service.player_state(session.local_id).mode == "PLAYING", "Active round participant must expose PLAYING status.")
		await _wait_mark("loss_checked")
		_expect(state().phase == "TYPING" and state().active_peer == b and state().hearts == [3,3], "Table 02 disconnect must not eliminate table 01 participant.")
		for attempt in 3:
			await send_word("zzzzmadeup")
			await wait_phase("TYPING" if attempt < 2 else "FINISHED")
		_mark("b_finished")
		_expect(service.player_state(session.local_id).mode == "ELIMINATED", "Eliminated client retains assignment without input rights.")
		await _wait_mark("restart_checked")
	elif role == "c":
		await _wait_mark("parallel_ready")
		await wait_phase("TYPING",c)
		_expect(state().difficulty == 2 and state().mature and not state().used_words.has("stone"), "Table 02 has separate settings, prefix and word history.")
		var deadline: int = state().deadline
		await send_word("eqzxmadeup")
		await wait_phase("TYPING",c)
		_expect(state().hearts == [2,3] and state().deadline == deadline, "Table 02 keeps its own deadline after invalid input.")
		_mark("c_invalid")
		await _wait_mark("invalid_checked")
		await send_word("epochs")
		await wait_phase("TYPING",d)
		_mark("c_valid")
		await wait_phase("FINISHED")
		_expect(state().winner == c and state().used_words == ["epochs"], "Table 02 winner/history must be separate.")
		_mark("c_winner")
		await _wait_mark("restart_checked")
		_expect(state().round_id == 1 and state().phase == "FINISHED" and state().hearts == [2,3], "Other table restart must not reset this client.")
	else:
		await _wait_mark("c_valid")
		await _tap(KEY_F10)
		await _check_offline()
		_mark("d_left")
		await _wait_mark("restart_checked")
	_expect(isolated, "No client may receive round snapshots for a different table.")
	await _capture("parallel_" + role)
	_mark("checked_" + role)
	if role == "host":
		for peer_role in ["b","c","d"]:
			await _wait_mark("checked_" + peer_role)
		await _tap(KEY_F10)
		_mark("host_left")
	else:
		await _wait_mark("host_left")
		if session.active:
			await _wait_offline()
	process_frame.disconnect(_watch_scope)
	await _check_offline()
	main.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
