extends SceneTree

const Rules = preload("res://scripts/last_letter_round.gd")
const Profile = preload("res://scripts/difficulty_profile.gd")
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
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)


func _run() -> void:
	var game := Rules.new()
	var advisor := game.prefix_advisor
	var hints: Array[int] = [0, 0, 0]
	for mode in 3:
		advisor.profile = Profile.for_mode(mode)
		advisor.rng.seed = 68271
		for mature in [false, true]:
			game.validator.policy.profanity_allowed = mature
			for initial in Rules.START_LETTERS:
				var used := {"stone": true, "school": true, "shit": true}
				var stats := advisor.availability(initial, game.validator, used)
				for sample in 100:
					var prefix := advisor.choose(initial, game.validator, used)
					if prefix.length() == 2:
						hints[mode] += 1
						_expect(stats.counts[prefix] >= 25 and stats.short_counts[prefix] >= 5, "Every difficulty must keep enough allowed, unused solutions.")
					_expect(prefix.begins_with(initial), "Every difficulty must preserve the chain.")
				if mode == Profile.Mode.HARD and stats.short_total > 40:
					_expect(advisor.profile.hint_chance(stats) == 0.0, "Hard only helps in exceptional dictionary scarcity.")
	_expect(hints[0] > hints[1] * 1.7 and hints[1] > hints[2] * 4, "Easy, Normal and Hard must differ substantially on the actual dictionary.")
	_expect(hints[0] < 5200 and hints[1] > 500 and hints[2] < 260, "Modes must include Easy singles, Normal mixture, and almost all Hard singles.")
	var abundant := advisor.availability("s", game.validator, {})
	var scarce := advisor.availability("x", game.validator, {})
	for mode in [Profile.Mode.EASY, Profile.Mode.NORMAL]:
		var profile: Resource = Profile.for_mode(mode)
		_expect(profile.hint_chance(scarce) > profile.hint_chance(abundant), "Real sparse letters must receive more help.")
	print("Hint counts / 5200 per mode: Easy=%d Normal=%d Hard=%d" % hints)
	var scene := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var lobby: Node3D = scene.get_node("Lobby")
	_expect(lobby.table.match_settings.difficulty == Profile.Mode.NORMAL, "Normal must be default.")
	_key(KEY_F7)
	await process_frame
	_expect(lobby.table.match_settings.difficulty == Profile.Mode.HARD and lobby.difficulty_label.text.contains("Hard"), "Lobby F7 must change and display difficulty.")
	lobby.seated = true
	lobby.player.set_walking(false)
	lobby.table.enter_table(0)
	var snapshot: Resource = lobby.table.round_state.prefix_advisor.profile
	_key(KEY_F7)
	await process_frame
	_expect(lobby.table.match_settings.difficulty == Profile.Mode.HARD and snapshot.display_name == "Hard", "Lobby hotkey must not change a seated round.")
	lobby.table.match_settings.difficulty = Profile.Mode.EASY
	_expect(snapshot.display_name == "Hard", "Round profile must be a snapshot, not a live setting reference.")
	lobby.table.round_state.finished = true
	lobby.table.round_state.winner = 1
	lobby.table.phase = lobby.table.Phase.FINISHED
	_key(KEY_F5)
	await process_frame
	_expect(lobby.table.round_state.prefix_advisor.profile.display_name == "Easy" and lobby.table.phase == lobby.table.Phase.COUNTDOWN,
		"A new round must take the chosen setting and restart countdown.")
	lobby.table.round_state.finished = true
	lobby.table.round_state.winner = 1
	lobby.table.phase = lobby.table.Phase.FINISHED
	_key(KEY_F5)
	await process_frame
	_expect(lobby.table.match_settings.difficulty == Profile.Mode.EASY and lobby.table.round_state.prefix_advisor.profile.display_name == "Easy", "Restart must preserve difficulty.")
	lobby.leave_table()
	scene.queue_free()
	await process_frame
	print("DIFFICULTY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
