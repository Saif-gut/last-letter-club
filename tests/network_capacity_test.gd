extends "res://tests/network_lobby_test.gd"
## Two real peers: temporarily use a one-member test limit to exercise admission rejection.

func _run() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	lobby = main.get_node("Lobby")
	session = lobby.network_session
	await create_timer(0.25).timeout
	if role == "host":
		# Direct fixture assignment bypasses editor range; production remains sixteen.
		session.max_players = 1
		await _tap(KEY_F8)
		_mark("host_ready")
		await _wait_mark("rejected")
		_expect(session.players.size() == 1 and session.slots.size() == 1 and lobby.remote_players.is_empty(), "Rejected connections must never enter the registry, spawn or occupy a table.")
		await create_timer(2.2).timeout
		_expect(session.rejected_peers.is_empty(), "Temporary rejection slot must be released.")
		await _tap(KEY_F10)
		session.max_players = 16
		await _tap(KEY_F8)
		_mark("reopened")
		await _wait_players(2)
		await _wait_mark("client_rejoined")
		await _tap(KEY_F10)
		_mark("host_left")
	else:
		await _wait_mark("host_ready")
		await _tap(KEY_F9)
		await _wait_offline()
		_expect(session.status.contains("Lobby voll") and lobby.network_panel.status_label.text.contains("Lobby voll"), "Host's lobby-full reason must remain visible offline.")
		await _check_offline()
		_mark("rejected")
		await _wait_mark("reopened")
		await _tap(KEY_F9)
		await _wait_players(2)
		_expect(session.max_players == 16, "Successful rejoin receives actual lobby capacity.")
		_mark("client_rejoined")
		await _wait_mark("host_left")
		await _wait_offline()
	await _check_offline()
	await _capture("capacity_"+role)
	main.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
