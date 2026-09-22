extends "res://tests/network_round_test.gd"

func wait_watching(enabled: bool) -> void:
	var limit := Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<limit:
		var mode: String = service.player_state(session.local_id).mode
		if (mode == "SPECTATING") == enabled and (not enabled or not state().is_empty()):
			return
		await process_frame
	_expect(false, "Spectator membership/snapshot transition timed out.")

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
	await _wait_players(3)
	if role != "watcher":
		await _seat(0 if role == "host" else 1)
		await _wait_seats(2)
		_mark(role+"_seated")
	if role == "host":
		await _wait_mark("client_seated")
		await _tap(KEY_F5)
		await wait_phase("TYPING",1)
		var model: RefCounted = service.host_rounds.table_01
		model.rules.required_prefix = "st"
		model.rules.prefix_advisor.enabled = false
		service._send_rounds()
		var deadline: int = model.rules.deadline_ms
		_mark("round_ready")
		await _wait_mark("watcher_checked")
		_expect(model.participants.size() == 2 and model.rules.hearts == [3,3] and model.rules.used_words.is_empty() and model.rules.deadline_ms == deadline,
			"Spectator join and malicious word cannot change hearts, timer, history or participants.")
		await send_word("stone")
		var other: int = service.tables.table_01.seats[1]
		await wait_phase("TYPING",other)
		deadline = model.rules.deadline_ms
		_mark("chain_ready")
		await wait_phase("FINISHED")
		_expect(state().winner == 1 and model.participants.size() == 2, "Spectator must not prevent the last participant from winning.")
		_mark("winner_ready")
		await _wait_mark("watcher_winner")
		await _tap(KEY_F5)
		await wait_phase("COUNTDOWN")
		_mark("restart_ready")
		await _wait_mark("watcher_restart")
		await wait_phase("TYPING",1)
		deadline = model.rules.deadline_ms
		_mark("restart_typing")
		await _wait_mark("watcher_left")
		await _wait_players(2)
		_expect(service.tables.table_01.spectators.is_empty() and model.phase == "TYPING" and model.rules.deadline_ms == deadline and model.rules.alive == [true,true],
			"Spectator exit/disconnect must not eliminate a participant or change deadline.")
		await _tap(KEY_F10)
		_mark("host_left")
	elif role == "client":
		await _wait_mark("host_left", 35.0) # Full 10-second turn plus the next countdown.
		await _wait_offline()
	else:
		await _wait_mark("round_ready")
		_expect(service.player_state(session.local_id).mode == "FREE" and not lobby.network_panel.watch_buttons.table_01.disabled,
			"Only a FREE user can join a running table through the debug button.")
		lobby.network_panel.watch_buttons.table_01.pressed.emit()
		await wait_watching(true)
		_expect(service.seat_of(session.local_id).is_empty() and not state().participants.has(session.local_id) and state().hearts.size()==2,
			"Spectator gets no seat, participant entry or own hearts.")
		_expect(lobby.player.walking_enabled and root.get_camera_3d()==lobby.player.camera and not lobby.table.word_input.editable,
			"Spectator retains lobby camera/movement and cannot use table word entry.")
		service.submit_word("table_01","stone") # Deliberately bypass read-only UI.
		service.request_seat("table_01")
		await create_timer(0.3).timeout
		_expect(state().used_words.is_empty() and state().hearts == [3,3] and lobby.network_panel.notice_label.text.contains("Zuschauen zuerst"),
			"Host must reject spectator words and seat requests.")
		service.request_spectating("table_02")
		await create_timer(0.15).timeout
		_expect(service.spectator_of(session.local_id)=="table_01" and not service.round_states.has("table_02"), "Cannot subscribe to an idle/different table.")
		_mark("watcher_checked")
		await _wait_mark("chain_ready")
		await create_timer(0.15).timeout
		_expect(state().used_words == ["stone"] and lobby.network_panel.watch_label.text.contains("stone"), "Spectator receives read-only word-chain updates.")
		await _capture("spectator_view")
		await _wait_mark("winner_ready")
		await wait_phase("FINISHED")
		await process_frame
		_expect(state().winner == 1 and lobby.network_panel.watch_label.text.contains("Gewinner: 1") and not lobby.table.word_input.editable,
			"Spectator must see the real winner without receiving word entry.")
		_mark("watcher_winner")
		await _wait_mark("restart_ready")
		await wait_phase("COUNTDOWN")
		_expect(service.player_state(session.local_id).mode == "SPECTATING" and state().participants.size() == 2 and state().hearts == [3,3] and state().used_words.is_empty(),
			"Restart preserves spectator membership and resets only the actual players.")
		_mark("watcher_restart")
		await _wait_mark("restart_typing")
		lobby.network_panel.stop_watching.pressed.emit()
		await wait_watching(false)
		_expect(service.round_states.is_empty() and not lobby.network_panel.watch_label.visible, "Leaving must remove stale snapshots and spectator HUD.")
		lobby.network_panel.watch_buttons.table_01.pressed.emit()
		await wait_watching(true)
		await _tap(KEY_F10)
		await _check_offline()
		_mark("watcher_left")
		await _wait_mark("host_left")
	await _check_offline()
	main.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
