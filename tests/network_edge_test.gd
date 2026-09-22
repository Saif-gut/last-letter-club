extends SceneTree

const Session = preload("res://scripts/network/lobby_session.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	_expect(Session.valid_pose(Vector3(1, 1, 2), 1, 0.5, Vector3(2, 4, 0)), "Valid walker pose must pass.")
	_expect(not Session.valid_pose(Vector3(NAN, 0, 0), 0, 0, Vector3.ZERO), "NaN positions must fail.")
	_expect(not Session.valid_pose(Vector3.ZERO, INF, 0, Vector3.ZERO), "Infinite rotations must fail.")
	_expect(not Session.valid_pose(Vector3(100, 0, 0), 0, 0, Vector3.ZERO), "Out-of-room payloads must fail.")
	_expect(not Session.valid_pose(Vector3.ZERO, 0, 0, Vector3(200, 0, 0)), "Invalid velocity must fail.")
	var scene := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var lobby: Node3D = scene.get_node("Lobby")
	var session: Node = lobby.network_session
	lobby.table.match_settings.mature_words_allowed = true
	lobby.table.match_settings.difficulty = 0
	lobby.network_panel.address.grab_focus()
	await _key(KEY_F6)
	_expect(lobby.table.match_settings.mature_words_allowed, "Editing an IP must not change local match settings.")
	await _key(KEY_ESCAPE)
	_expect(not lobby.network_panel.address.has_focus() and not lobby.player.mouse_released, "Esc must abandon IP editing and restore walking input.")
	_expect(session.join("") == ERR_INVALID_PARAMETER and not session.active, "Empty address must stay offline.")
	var occupied := ENetMultiplayerPeer.new()
	_expect(occupied.create_server(24574) == OK, "Test port must be available.")
	# ENet logs an engine error for this deliberately occupied port; assert its return.
	Engine.print_error_messages = false
	var occupied_result: Error = session.host(24574)
	Engine.print_error_messages = true
	_expect(occupied_result != OK and not session.active, "Port in use must report failure and remain offline.")
	occupied.close()
	_expect(session.host(24574) == OK, "Host must work after port failure.")
	await _key(KEY_F6)
	await _key(KEY_F7)
	_expect(lobby.table.match_settings.mature_words_allowed and lobby.table.match_settings.difficulty == 0,
		"Offline settings must not be changed while networked.")
	await _key(KEY_E)
	_expect(not lobby.seated and not lobby.table.round_state.turn_running, "Online E must not start a private round.")
	var roster: Dictionary = session.players.duplicate(true)
	session._submit_pose(Vector3.ZERO, 0, 0, Vector3.ZERO, true, 99)
	_expect(session.players == roster, "Direct unowned movement has no valid remote sender and cannot alter players.")
	session.leave()
	_expect(lobby.table.match_settings.mature_words_allowed and lobby.table.match_settings.difficulty == 0,
		"Disconnect must preserve offline match settings.")
	_expect(session.join("127.0.0.1", 24574) == OK, "Connection to an absent host must begin asynchronously.")
	var end := Time.get_ticks_msec() + 9500
	while session.active and Time.get_ticks_msec() < end:
		await process_frame
	_expect(not session.active and session.players.is_empty() and session.status.contains("Offline"), "Unreachable host must time out and restore offline mode.")
	_expect(session.host(24574) == OK, "Host must work after a failed connection.")
	# Free a live session: no dangling roster callbacks or socket left in use.
	scene.queue_free()
	await process_frame
	await process_frame
	var probe := ENetMultiplayerPeer.new()
	_expect(probe.create_server(24574) == OK, "Scene teardown must release the socket.")
	probe.close()
	print("NETWORK_EDGE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
