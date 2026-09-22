extends "res://tests/network_lobby_test.gd"

var service: Node


func _seat(index: int) -> void:
	root.grab_focus()
	lobby.player.global_position = Vector3(sin(TAU * index / 4) * 3.5, 0.05, cos(TAU * index / 4) * 3.5)
	lobby.player.rotation.y = TAU * index / 4
	lobby.player.reset_camera()
	await create_timer(0.35).timeout
	await _tap(KEY_E)
	var end := Time.get_ticks_msec() + 3000
	while not lobby.seated and Time.get_ticks_msec() < end:
		await process_frame
	_expect(lobby.seated and service.seat_of(session.local_id).get("seat", -1) == index, "Host must assign the nearby distinct seat.")
	_expect(not lobby.player.walking_enabled and root.get_camera_3d() == lobby.table.camera, "Only local seat camera must take over.")
	_expect(not lobby.table.table_enabled and not lobby.table.round_state.turn_running, "Online seating must not start an offline round.")


func _wait_seats(count: int) -> void:
	var end := Time.get_ticks_msec() + 4000
	while _occupied() != count and Time.get_ticks_msec() < end:
		await process_frame
	_expect(_occupied() == count, "Synchronized occupied seat count must be %d." % count)
	var seen := {}
	for id: int in service.tables.table_01.seats:
		if id:
			_expect(not seen.has(id), "No player may own two seats.")
			seen[id] = true
	for index in lobby.table.SEAT_COUNT:
		_expect(lobby.table.seats[index].word_label.visible, "Every online seat must visibly show occupancy.")


func _occupied() -> int:
	if not service.tables.has("table_01"):
		return 0
	return service.tables.table_01.seats.size() - service.tables.table_01.seats.count(0)


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
	await create_timer(0.2).timeout
	service.request_seat("table_01")
	await create_timer(0.2).timeout
	_expect(not lobby.seated, "Host must reject seating from outside the allowed range.")
	if role == "host":
		await _seat(0)
		_mark("host_seated")
		await _wait_mark("client_seated")
		await _wait_seats(2)
		_expect(service.tables.table_01.seats[0] == 1 and service.tables.table_01.seats[1] != 0, "Both peers must agree on different seats.")
		await _capture("host_seats")
		_mark("seats_checked")
		await _wait_mark("client_stood")
		await _wait_seats(1)
		_mark("seat_freed")
		await _wait_mark("client_reseated")
		await _wait_seats(2)
		_mark("reseat_checked")
		await _wait_mark("client_disconnected")
		await _wait_players(1)
		await _wait_seats(1)
		_expect(service.tables.table_01.seats[1] == 0 and not lobby.table.seats[1].avatar.visible, "Disconnected seated peer must release seat and body.")
		await _tap(KEY_F10)
		await _check_offline()
		_expect(not lobby.seated, "Host ending session must stand up safely.")
		_mark("host_done")
	else:
		await _wait_mark("host_seated")
		await _seat(1)
		await _wait_seats(2)
		var local_position: Vector3 = lobby.table.camera.position
		_expect(local_position.distance_to(Vector3(2.25, 1.22, 0)) < 0.01, "Client camera must stay at its own seat, not host seat.")
		_mark("client_seated")
		await _wait_mark("seats_checked")
		await _capture("client_seats")
		await _tap(KEY_F4)
		await _wait_seats(1)
		_expect(not lobby.seated and lobby.player.walking_enabled and root.get_camera_3d() == lobby.player.camera, "F4 must restore local walking and camera.")
		_mark("client_stood")
		await _wait_mark("seat_freed")
		await _seat(1)
		_mark("client_reseated")
		await _wait_mark("reseat_checked")
		await _tap(KEY_F10)
		await _check_offline()
		_expect(not lobby.seated, "Client F10 while seated must restore offline walker.")
		_mark("client_disconnected")
		await _wait_mark("host_done")
	main.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)
