extends SceneTree
## Full local loop with real keyboard, mouse and physics events.
## --path . --script res://tests/lobby_smoke.gd [-- --capture]

var lobby: Node3D
var player: CharacterBody3D
var table: Node3D
var failures := 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("LOBBY_SMOKE requires a graphical window for captured mouse input. Run without --headless.")
		quit(2)
		return
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _key(code: Key, pressed: bool, unicode: int = 0) -> void:
	await _focus_input_window()
	var event := InputEventKey.new()
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _tap(code: Key, unicode: int = 0) -> void:
	await _key(code, true, unicode)
	await physics_frame
	await _key(code, false)


func _type(text: String) -> void:
	for character in text:
		await _tap(KEY_NONE, character.unicode_at(0))


func _capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/lobby_checks")
	var result := root.get_texture().get_image().save_png("res://.godot/lobby_checks/" + filename + ".png")
	_expect(result == OK, "Screenshot failed.")


func _mouse(relative: Vector2) -> void:
	await _focus_input_window()
	var event := InputEventMouseMotion.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.relative = relative
	event.screen_relative = relative
	Input.parse_input_event(event)
	await process_frame


func _focus_input_window() -> void:
	if not root.has_focus():
		root.grab_focus()
		await create_timer(0.15).timeout
	_expect(root.has_focus(), "Input test requires the game window in focus.")


func _wait_typing() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while table.phase != table.Phase.TYPING and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(table.phase == table.Phase.TYPING, "Table did not return to typing.")


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	lobby = main.get_node("Lobby")
	player = lobby.player
	table = lobby.table
	table.round_state.prefix_advisor.enabled = false
	await create_timer(0.2).timeout
	_expect(not paused and player.is_physics_processing(), "Lobby must not be paused and movement script must be active.")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.get_window().has_focus(),
		"Startup must capture the mouse and focus the game without a click.")
	_expect(not lobby.instructions.text.to_lower().contains("linksklick")
		and not lobby.join_hint.text.to_lower().contains("linksklick"), "Old click-to-play hints must be removed.")
	for action in ["lobby_forward", "lobby_back", "lobby_left", "lobby_right", "lobby_jump"]:
		_expect(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
			"Movement action must have a keyboard binding: " + action)
	_expect(player.walking_enabled and not table.table_enabled, "Must start walking in the lobby.")
	_expect(root.get_camera_3d() == player.camera, "Lobby camera must own the initial view.")
	_expect(player.avatar.visible, "Third person must show the local placeholder.")
	_expect(player.camera.global_position.y > player.global_position.y + 1.6
		and player.camera.global_position.z > player.global_position.z + 1.0, "Lobby camera must be behind and above the player.")
	_expect(player.is_on_floor(), "Player must spawn and settle on the floor.")
	_expect(not table.hud.visible and not table.word_input.has_focus(), "Table UI must stay inactive before joining.")
	_expect(lobby.join_candidate() == -1, "Spawn must be outside the join range.")
	_expect(lobby.instructions.get_global_rect().position.y > 0
		and lobby.instructions.get_global_rect().end.y <= root.size.y, "Lobby controls must be visible inside the viewport.")
	for seat in table.seats:
		_expect(not seat.avatar.visible and not seat.word_label.visible, "Lobby seats must start visibly free.")
	await _capture("01_lobby_spawn")
	_expect(lobby.mature_words_label.text.begins_with("Mature Words: OFF"), "Lobby must default to Mature Words OFF.")
	await _tap(KEY_F6)
	_expect(table.match_settings.mature_words_allowed and lobby.mature_words_label.text.begins_with("Mature Words: ON"),
		"F6 must visibly enable Mature Words in the lobby.")
	await _capture("07_mature_on")
	await _tap(KEY_F6)
	_expect(not table.match_settings.mature_words_allowed, "F6 must also disable Mature Words.")
	await _tap(KEY_E, 101)
	_expect(not lobby.seated, "Cannot join from far away.")
	await _mouse(Vector2(100, -80))
	_expect(player.rotation.y < -0.1 and player.look_pitch > deg_to_rad(-12), "Mouse must control yaw and pitch.")
	await _mouse(Vector2(-100, 80))
	await _tap(KEY_SPACE, 32)
	await create_timer(0.2).timeout
	_expect(player.position.y > 0.25, "Space must jump.")
	await create_timer(0.9).timeout
	_expect(player.is_on_floor(), "Jump must land on the floor.")
	var before: Vector3 = player.position
	await _key(KEY_D, true)
	await create_timer(0.25).timeout
	await _key(KEY_D, false)
	_expect(player.position.x > before.x + 0.5, "D must move right.")
	await _key(KEY_A, true)
	await create_timer(0.25).timeout
	await _key(KEY_A, false)
	await _key(KEY_W, true)
	await create_timer(0.63).timeout
	await _key(KEY_W, false)
	await physics_frame
	_expect(player.position.z < before.z - 2.0, "W must walk toward the table.")
	_expect(lobby.join_candidate() == 0, "Approach must offer the nearest free south seat.")
	await _capture("02_join_hint")
	await _tap(KEY_F6)
	await _tap(KEY_E, 101)
	_expect(lobby.seated and table.table_enabled and not player.walking_enabled, "E must enter the table and disable walking.")
	_expect(root.get_camera_3d() == table.camera, "Table camera must own the view after joining.")
	_expect(not player.avatar.visible, "Lobby body must be hidden at the table.")
	_expect(table.round_state.validator.policy.profanity_allowed, "Joining must copy lobby mode to the active round.")
	await _tap(KEY_F6)
	_expect(table.match_settings.mature_words_allowed and table.round_state.validator.policy.profanity_allowed,
		"The lobby hotkey must not change a running match.")
	table.enter_table(table.active_seat, "a")
	await _wait_typing()
	_expect(table.active_seat == 0 and table.word_input.text.is_empty(), "E must choose seat one without typing an E.")
	_expect(table.word_input.has_focus(), "Joining must focus word entry.")
	_expect(lobby.instructions.get_global_rect().position.y > 0
		and lobby.instructions.get_global_rect().end.y <= root.size.y, "Leave-table hint must be visible inside the viewport.")
	before = player.position
	await _key(KEY_W, true, 119)
	await _tap(KEY_SPACE, 32)
	await _mouse(Vector2(90, 30))
	await create_timer(0.15).timeout
	await _key(KEY_W, false)
	_expect(player.position == before and player.velocity == Vector3.ZERO, "Walking and jumping must stay disabled at the table.")
	await _tap(KEY_ESCAPE)
	await _type("Apfel")
	_expect(table.word_input.text == "Apfel", "Letter F must remain available for word entry.")
	_expect(table.seats[0].word_label.text == "Apfel", "Floating label must work in the lobby instance.")
	await _capture("03_seated")
	await _tap(KEY_ENTER)
	await create_timer(0.3).timeout
	_expect(table.active_seat == 0 and table.word_input.text.is_empty() and table.word_input.is_editing(),
		"Invalid feedback must preserve seat, clear the word and restore editing.")
	_expect(table.round_state.hearts[0] == 2, "English dictionary must reject Apfel and remove one heart.")
	await _type("Apple")
	await _tap(KEY_ENTER)
	await _wait_typing()
	_expect(table.active_seat == 1, "Accepted word must advance the existing camera prototype.")
	await _tap(KEY_F4)
	await create_timer(0.2).timeout
	_expect(not lobby.seated and player.walking_enabled and not table.table_enabled, "F4 must restore the lobby.")
	_expect(root.get_camera_3d() == player.camera and not table.word_input.has_focus(), "Leaving must restore camera and release word focus.")
	_expect(player.avatar.visible, "Leaving must restore the visible third-person body.")
	_expect(player.is_on_floor() and player.position.x > 3.4, "Exit must be on safe ground outside the active chair.")
	await _capture("04_back_in_lobby")
	_expect(lobby.mature_words_label.text.begins_with("Mature Words: ON"), "Selected mode must survive leaving the table.")
	await _tap(KEY_F6)
	await _tap(KEY_E, 101)
	_expect(not table.round_state.validator.policy.profanity_allowed, "Rejoining must apply the newly selected OFF mode.")
	_expect(table.active_seat == 1 and table.word_input.text.is_empty(), "Rejoining must use the nearest free east seat and reset text.")
	table.enter_table(1, "t")
	await _wait_typing()
	# A pending green feedback timer must not affect a freshly joined session.
	await _type("Test")
	await _tap(KEY_ENTER)
	await _tap(KEY_F4)
	await create_timer(0.04).timeout
	await _tap(KEY_E, 101)
	await create_timer(0.4).timeout
	_expect(lobby.seated and table.active_seat == 1 and table.phase == table.Phase.COUNTDOWN,
		"Old feedback must not advance a new session during its countdown.")
	# An old auto-clear must neither erase a new session's word nor steal focus.
	table.enter_table(1, "a")
	await _wait_typing()
	await _type("Apfel")
	await _tap(KEY_ENTER)
	await _tap(KEY_F4)
	await create_timer(0.04).timeout
	await _tap(KEY_E, 101)
	await _wait_typing()
	await _type("fresh")
	await create_timer(0.3).timeout
	_expect(table.word_input.text == "fresh" and table.word_input.has_focus(), "Old rejected-word callback must not clear a newly joined session.")
	table.enter_table(1, "t")
	await _wait_typing()
	await _type("Test")
	await _tap(KEY_ENTER)
	await create_timer(table.feedback_seconds + 0.1).timeout
	_expect(table.phase == table.Phase.MOVING, "Must test leaving during camera movement.")
	await _tap(KEY_F4)
	var camera_after_leaving: Transform3D = table.camera.transform
	await create_timer(0.7).timeout
	_expect(table.camera.transform == camera_after_leaving and root.get_camera_3d() == player.camera,
		"Leaving must cancel the camera tween and prevent focus theft.")
	# Physics checks use clear positions, then actual movement into obstacles.
	player.position = Vector3(0, 0.05, 3.5)
	player.rotation = Vector3.ZERO
	await _key(KEY_W, true)
	await create_timer(0.9).timeout
	await _key(KEY_W, false)
	_expect(player.position.z > 2.8, "Chair collision must prevent walking through it: %s" % player.position)
	player.position = Vector3(2, 0.05, 2)
	player.rotation.y = PI / 4
	await _key(KEY_W, true)
	await create_timer(0.8).timeout
	await _key(KEY_W, false)
	_expect(Vector2(player.position.x, player.position.z).length() > 1.8, "Table collision must block the walking capsule.")
	player.position = Vector3(6, 0.05, 5)
	player.rotation = Vector3.ZERO
	await _key(KEY_D, true)
	await create_timer(0.6).timeout
	await _key(KEY_D, false)
	_expect(player.position.x < 6.6, "Room walls must keep the player inside.")
	# The camera must retract before a wall and extend again in open space.
	player.position = Vector3(4, 0.05, 7.1)
	player.rotation = Vector3.ZERO
	player.look_pitch = deg_to_rad(-12)
	player.reset_camera()
	await create_timer(0.25).timeout
	_expect(player.camera_arm.get_hit_length() < 1.0 and player.camera.global_position.z < 7.8, "Camera spring arm must keep the view inside the south wall.")
	_expect(player.avatar.get_node("Head").transparency > 0.5, "Nearby placeholder must fade instead of obstructing the camera.")
	await _capture("05_camera_wall")
	player.position = Vector3(4, 0.05, 3)
	player.reset_camera()
	await create_timer(0.25).timeout
	_expect(player.camera_arm.get_hit_length() > 3.0, "Camera must recover its normal following distance away from walls.")
	_expect(player.avatar.get_node("Head").transparency < 0.05, "Placeholder must become opaque again in open space.")
	await _capture("06_third_person_clear")
	await _mouse(Vector2(0, -10000))
	await create_timer(0.3).timeout
	_expect(is_equal_approx(player.look_pitch, deg_to_rad(55)) and player.camera.global_position.y > 0.15,
		"Upward look must clamp and the rear camera must stay above the floor.")
	await _mouse(Vector2(0, 10000))
	await create_timer(0.3).timeout
	_expect(is_equal_approx(player.look_pitch, deg_to_rad(-60)) and absf(player.camera_arm.rotation.x - player.look_pitch) < 0.02,
		"Downward look must clamp and the actual camera arm must follow the mouse smoothly.")
	player.look_pitch = deg_to_rad(-12)
	await _tap(KEY_ESCAPE)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape must release the mouse in the lobby.")
	before = player.position
	await _key(KEY_S, true)
	await create_timer(0.2).timeout
	await _key(KEY_S, false)
	_expect(player.position.distance_to(before) < 0.05, "Walking must pause when the cursor is released.")
	await _tap(KEY_ESCAPE)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Escape must resume without a mouse click.")
	before = player.position
	await _key(KEY_S, true)
	await create_timer(0.2).timeout
	await _key(KEY_S, false)
	_expect(player.position.z > before.z + 0.4, "S must move backward after leaving and recapturing.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("LOBBY_SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
