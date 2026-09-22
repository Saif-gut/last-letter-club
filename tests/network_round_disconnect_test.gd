extends "res://tests/network_round_test.gd"

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
	for cycle in 3:
		var tag := "loss_%d" % cycle
		await _wait_players(2)
		if not lobby.seated:
			await _seat(0 if role == "host" else 1)
		await _wait_seats(2)
		if role == "client":
			_mark(tag + "_ready")
		else:
			await _wait_mark(tag + "_ready")
			await _tap(KEY_F5)
		await wait_phase("TYPING",1)
		# Cycle 0: waiting client; cycle 1: active client; cycle 2: host goes away.
		if cycle == 1:
			if role == "host":
				var model: RefCounted = service.host_rounds.table_01
				model.rules.required_prefix = "s"
				service._send_rounds()
				await send_word("stone")
			await wait_phase("TYPING",service.tables.table_01.seats[1])
		if cycle < 2:
			if role == "client":
				await _tap(KEY_F10)
				await _check_offline()
				_expect(not lobby.seated, "Disconnected participant must return to lobby camera.")
				_mark(tag + "_left")
				await _wait_mark(tag + "_winner")
				await _tap(KEY_F9)
				await _wait_players(2)
				_expect(not lobby.seated and service.seat_of(session.local_id).is_empty(), "Rejoin must not restore the old running seat/identity.")
			else:
				await _wait_mark(tag + "_left")
				await wait_phase("FINISHED")
				_expect(state().winner == 1 and state().alive == [true,false] and _occupied() == 1, "Host must immediately win and free the departed seat.")
				_mark(tag + "_winner")
		else:
			if role == "host":
				await _tap(KEY_F10)
				_mark("host_left")
			else:
				await _wait_mark("host_left")
				await _wait_offline()
			await _check_offline()
			_expect(not lobby.seated and service.round_states.is_empty() and not lobby.table.word_input.editable, "Host departure clears round, seat, input and camera.")
	# Fresh complete Host/Join after ending an active round.
	if role == "host":
		await _tap(KEY_F8)
		_mark("fresh_host")
	else:
		await _wait_mark("fresh_host")
		await _tap(KEY_F9)
	await _wait_players(2)
	if role == "client":
		_mark("fresh_join")
	else:
		await _wait_mark("fresh_join")
	await _tap(KEY_F10)
	await _check_offline()
	main.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
