extends SceneTree
## Two independent OS processes, real ENet and real local Input/CharacterBody physics.

var lobby: Node3D
var session: Node
var role := "host"
var directory := ""
var failures := 0
var remote_samples: Array[Dictionary] = []
var camera_stolen := false
var scenario := "repeat"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	directory = args[1]
	if args.size() > 2:
		scenario = args[2]
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(role + ": " + message)


func _mark(name: String) -> void:
	FileAccess.open(directory.path_join(name), FileAccess.WRITE).store_string("ready")


func _wait_mark(name: String, seconds: float = 15.0) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not FileAccess.file_exists(directory.path_join(name)) and Time.get_ticks_msec() < end:
		await process_frame
	_expect(FileAccess.file_exists(directory.path_join(name)), "Missing peer milestone: " + name)


func _wait_players(count: int) -> void:
	var end := Time.get_ticks_msec() + 10000
	while session.players.size() != count and Time.get_ticks_msec() < end:
		await process_frame
	_expect(session.players.size() == count, "Expected roster size %d, got %d" % [count, session.players.size()])


func _key(code: Key, pressed: bool = true) -> void:
	if code == KEY_F9 and pressed:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--host-address="):
				lobby.network_panel.address.text = argument.trim_prefix("--host-address=")
	var event := InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))


func _monitor() -> void:
	if not is_instance_valid(lobby):
		return
	if root.get_camera_3d() != lobby.player.camera:
		camera_stolen = true
	for id: int in lobby.remote_players:
		var remote: Node3D = lobby.remote_players[id]
		if not remote.last_pose.is_empty():
			remote_samples.append(remote.last_pose.duplicate())


func _move_and_jump() -> void:
	root.grab_focus()
	await create_timer(0.25).timeout
	_expect(not lobby.player.mouse_released and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Movement must resume without repairing input flags.")
	var start: Vector3 = lobby.player.global_position
	var mouse := InputEventMouseMotion.new()
	mouse.screen_relative = Vector2(120, -100)
	Input.parse_input_event(mouse)
	await _key(KEY_W)
	await create_timer(0.5).timeout
	await _key(KEY_SPACE)
	await _key(KEY_SPACE, false)
	await create_timer(0.32).timeout
	_expect(lobby.player.global_position.y > 0.45, "Real Space input must jump locally.")
	await _capture(role + "_jump")
	await _key(KEY_W, false)
	await create_timer(0.8).timeout
	_expect(lobby.player.global_position.distance_to(start) > 1.0, "Real W input must move only the local controller.")
	_expect(absf(lobby.player.rotation.y) > 0.1 and lobby.player.look_pitch > -0.1, "Real mouse input must rotate local view.")


func _check_remote_motion() -> void:
	var jumped := false
	var rotated := false
	var moving := false
	var grounded := false
	var start: Vector3 = remote_samples[0].position if not remote_samples.is_empty() else Vector3.ZERO
	for sample in remote_samples:
		jumped = jumped or (sample.position.y > 0.45 and not sample.grounded)
		grounded = grounded or sample.grounded
		rotated = rotated or (absf(sample.yaw) > 0.1 and sample.pitch > -0.1)
		moving = moving or (sample.position.distance_to(start) > 1.0 and sample.velocity.length() > 1)
	_expect(jumped and grounded and rotated and moving, "Remote must receive position, velocity, yaw, pitch, jump and landing.")
	_expect(not camera_stolen, "Remote updates must never replace the local camera.")
	for id: int in lobby.remote_players:
		var remote: Node3D = lobby.remote_players[id]
		_expect(remote.find_children("*", "Camera3D", true, false).is_empty(), "Remote avatar must have no camera.")
		_expect(remote.global_position.distance_to(remote.target_position) < 0.15, "Remote interpolation must settle at received position.")


func _run() -> void:
	var scene := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	lobby = scene.get_node("Lobby")
	session = lobby.network_session
	root.title = "Last Letter Club · Network Test · " + role
	process_frame.connect(_monitor)
	await create_timer(0.3).timeout
	if scenario != "repeat":
		await _crash_scenario()
	else:
		for cycle in 3:
			var tag := "cycle_%d" % cycle
			if role == "host":
				if cycle != 1:
					session.max_players = 8
					await _tap(KEY_F8)
				_mark(tag + "_host_ready")
			else:
				await _wait_mark(tag + "_host_ready")
				await _tap(KEY_F9)
			await _wait_players(2)
			_expect(session.state_name() == ("Host" if role == "host" else "Connected / Client"), "Correct network role must be visible.")
			_expect(lobby.network_panel.status_label.text.contains(session.state_name()), "HUD must show actual network role.")
			_expect(lobby.difficulty_label.text.contains("Normal"), "Chosen difficulty must stay visible.")
			_expect(session.max_players == 8, "Host capacity must survive rejoin.")
			_expect(lobby.remote_players.size() == 1, "Exactly one remote avatar after every join.")
			await _exchange_motion(tag)
			if cycle == 0:
				if role == "client":
					await _tap(KEY_F10)
					await _check_offline()
					_mark(tag + "_client_left")
				else:
					await _wait_mark(tag + "_client_left")
					await _wait_players(1)
					await _check_no_avatars()
					_expect(session.state_name() == "Host", "Remaining host must keep Host status.")
			else:
				if role == "host":
					await _wait_mark(tag + "_disconnect_ready")
					await _tap(KEY_F10)
					await _check_offline()
					_mark(tag + "_host_left")
					await _wait_mark(tag + "_client_offline")
				else:
					# Release mouse before an asynchronous disconnect, to check automatic recovery.
					lobby.player.mouse_released = true
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					_mark(tag + "_disconnect_ready")
					await _wait_mark(tag + "_host_left")
					await _wait_offline()
					await _check_offline()
					_mark(tag + "_client_offline")
	# Offline table remains usable after the network session, with its full countdown.
	root.grab_focus()
	lobby.player.mouse_released = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lobby.player.position = Vector3(0, 0.05, 3.5)
	lobby.player.rotation.y = 0
	lobby.player.reset_camera()
	await create_timer(0.4).timeout
	await _key(KEY_E)
	await _key(KEY_E, false)
	_expect(lobby.seated and lobby.table.phase == lobby.table.Phase.COUNTDOWN, "Offline E/table countdown must work after disconnect.")
	lobby.leave_table()
	process_frame.disconnect(_monitor)
	scene.queue_free()
	await process_frame
	print("NETWORK_%s: %s" % [role.to_upper(), "PASS" if failures == 0 else "FAIL"])
	quit(0 if failures == 0 else 1)


func _tap(code: Key) -> void:
	await _key(code)
	await _key(code, false)


func _check_no_avatars() -> void:
	await process_frame
	await process_frame
	_expect(lobby.remote_players.is_empty() and lobby.find_children("RemotePlayer_*", "", false, false).is_empty(),
		"No old/invisible remote nodes may survive cleanup.")


func _check_offline() -> void:
	await _check_no_avatars()
	_expect(not session.active and session.state_name() == "Offline" and lobby.network_panel.status_label.text.begins_with("Network: Offline"), "Disconnect HUD must say Offline.")
	_expect(not lobby.player.mouse_released and lobby.player.walking_enabled and root.get_camera_3d() == lobby.player.camera, "Disconnect must leave local input/camera enabled.")
	_expect(not lobby.network_panel.host_button.disabled and not lobby.network_panel.join_button.disabled, "Host and Join must be reusable.")


func _wait_offline() -> void:
	var end := Time.get_ticks_msec() + 12000
	while session.active and Time.get_ticks_msec() < end:
		await process_frame
	_expect(not session.active, "Lost host must be detected within 12 seconds.")


func _reset_test_position() -> void:
	lobby.player.position = Vector3(0, 0.05, 6) if role == "host" else Vector3(-3.75, 0.05, 5.5)
	lobby.player.velocity = Vector3.ZERO
	lobby.player.rotation.y = 0
	lobby.player.look_pitch = deg_to_rad(-12)
	lobby.player.reset_camera()


func _exchange_motion(tag: String) -> void:
	_reset_test_position()
	remote_samples.clear()
	if role == "host":
		_mark(tag + "_observe_ready")
		await _wait_mark(tag + "_client_moved")
		_check_remote_motion()
		await _move_and_jump()
		_mark(tag + "_host_moved")
		await _wait_mark(tag + "_observed")
	else:
		await _wait_mark(tag + "_observe_ready")
		await _move_and_jump()
		_mark(tag + "_client_moved")
		await _wait_mark(tag + "_host_moved")
		_check_remote_motion()
		_mark(tag + "_observed")
	await _capture(tag + "_" + role)


func _crash_scenario() -> void:
	if role == "host":
		await _tap(KEY_F8)
		_mark("crash_host_ready")
	else:
		await _wait_mark("crash_host_ready")
		await _tap(KEY_F9)
	await _wait_players(2)
	await _exchange_motion("before_crash")
	var victim := scenario == "crash_" + role
	if victim:
		await _wait_mark("survivor_ready")
		_mark("crash_armed")
		OS.kill(OS.get_process_id()) # Deliberately skips leave(), close() and scene teardown.
		return
	lobby.player.mouse_released = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mark("survivor_ready")
	if role == "client":
		await _wait_offline()
		await _check_offline()
	else:
		await _wait_players(1)
		await _check_no_avatars()
		_expect(session.state_name() == "Host", "Client crash must not end the host session.")
		await _tap(KEY_F10)
		await _check_offline()
	_reset_test_position()
	await _move_and_jump()
	await _tap(KEY_F8)
	_expect(session.hosting, "Survivor must be able to host again after abrupt loss.")
	await _tap(KEY_F10)
	await _check_offline()
