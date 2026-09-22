extends Node
## Seat presentation adapter. Never starts the offline rule model.

var lobby: Node3D
var service: Node
var current_table: Node3D
var local_seat := -1
var offline_subtitle := ""
var offline_hint := ""
var pending := false
var pending_key := ""
var applied_key := ""


func setup(owner_lobby: Node3D, table_service: Node) -> void:
	lobby = owner_lobby
	service = table_service
	service.changed.connect(refresh)
	service.rejected.connect(func(_message: String): pending = false; refresh())
	for table: Node3D in service.definitions.values():
		table.word_input.text_submitted.connect(func(_text: String): _submit())


func refresh() -> void:
	var assignment: Dictionary = service.seat_of(lobby.network_session.local_id)
	if assignment.is_empty() and is_instance_valid(current_table):
		var previous := current_table
		current_table = null
		previous.hud.get_child(0).get_child(1).text = offline_subtitle
		previous.word_input.get_parent().get_child(2).text = offline_hint
		pending = false
		applied_key = ""
		previous.leave_table()
		var angle: float = TAU * local_seat / previous.SEAT_COUNT
		lobby.player.global_position = previous.to_global(Vector3(sin(angle) * 3.5, 0.05, cos(angle) * 3.5))
		lobby.player.rotation.y = previous.rotation.y + angle
		lobby.player.look_pitch = deg_to_rad(-12)
		lobby.seated = false
		lobby.player.set_walking(true)
		local_seat = -1
	elif not assignment.is_empty() and not is_instance_valid(current_table):
		current_table = service.definitions[assignment.table_id]
		local_seat = assignment.seat
		lobby.seated = true
		lobby.player.set_walking(false)
		lobby.player.global_position = current_table.seats[local_seat].global_position
		current_table.active_seat = local_seat
		current_table.phase = current_table.Phase.MOVING
		current_table._place_camera(TAU * local_seat / current_table.SEAT_COUNT)
		current_table.camera.make_current()
		current_table.hud.show()
		current_table.word_input.editable = false
		current_table.turn_label.text = "ONLINE · DEIN PLATZ %02d" % (local_seat + 1)
		current_table.rules_label.text = "WARTE AUF RUNDENSTART"
		current_table.hearts_label.text = ""
		current_table.status_label.text = "Tisch belegt · F4 Aufstehen"
		# Reuse the existing functional HUD without its offline subtitle/hotseat hint.
		offline_subtitle = current_table.hud.get_child(0).get_child(1).text
		offline_hint = current_table.word_input.get_parent().get_child(2).text
		current_table.word_input.get_parent().get_child(2).text = "ENTER  Wort senden · ESC  Leeren\nF5  Host: Runde starten / Neustart · F4 Aufstehen · F10 Disconnect"
		current_table.hud.get_child(0).get_child(1).text = "ONLINE-TISCH / " + assignment.table_id
	for id: String in service.definitions:
		var table: Node3D = service.definitions[id]
		for index in table.SEAT_COUNT:
			var occupant := 0
			if service.tables.has(id):
				occupant = service.tables[id].seats[index]
			table.seats[index].avatar.visible = occupant != 0 and occupant != lobby.network_session.local_id
			table.seats[index].word_label.visible = lobby.network_session.active
			table.seats[index].word_label.pixel_size = 0.0024 if lobby.network_session.active else 0.004
			table.seats[index].word_label.modulate = table.NEUTRAL
			if lobby.network_session.active:
				table.seats[index].word_label.text = "FREI" if occupant == 0 else ("HOST" if occupant == 1 else "SPIELER %d" % occupant)
	for peer_id: int in lobby.remote_players:
		lobby.remote_players[peer_id].visible = service.seat_of(peer_id).is_empty()
	if is_instance_valid(current_table):
		_render_round()
	lobby._update_hud()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(current_table) or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		service.start_round(current_table.table_id)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_F6, KEY_F7] and lobby.network_session.hosting:
		if service.tables[current_table.table_id].phase in ["WAITING", "FINISHED"]:
			if event.keycode == KEY_F6:
				current_table.match_settings.mature_words_allowed = not current_table.match_settings.mature_words_allowed
			else:
				current_table.match_settings.difficulty = (current_table.match_settings.difficulty + 1) % 3
			service.update_settings(current_table.table_id)
			_render_round()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and current_table.word_input.editable:
		current_table.word_input.clear()
		get_viewport().set_input_as_handled()


func _submit() -> void:
	if not is_instance_valid(current_table) or not current_table.word_input.editable or pending:
		return
	pending = true
	pending_key = applied_key
	current_table.word_input.editable = false
	service.submit_word(current_table.table_id, current_table.word_input.text)


func _render_round() -> void:
	var table := current_table
	var state: Dictionary = service.round_states.get(table.table_id, {})
	if state.is_empty() or state.phase == "WAITING":
		table.status_label.text = "Host: F5 starten (mind. 2 Spieler) · F6 Mature · F7 Difficulty" if lobby.network_session.hosting else "Warte auf den Host · F4 Aufstehen"
		var settings: Dictionary = service.tables.get(table.table_id, {})
		table.rules_label.text = "WARTE · %s · Mature %s" % [["Easy", "Normal", "Hard"][settings.get("difficulty", 1)], "ON" if settings.get("mature", false) else "OFF"]
		return
	var key := "%d:%d:%d:%s" % [state.round_id, state.turn_id, state.feedback_id, state.phase]
	if key != applied_key:
		if state.phase != "FEEDBACK":
			table.word_input.clear()
		applied_key = key
	if pending and key != pending_key:
		pending = false
	var can_type: bool = state.phase == "TYPING" and state.active_peer == lobby.network_session.local_id and not pending
	if table.word_input.editable != can_type:
		table.word_input.editable = can_type
		if can_type:
			table.word_input.grab_focus()
			table.word_input.edit()
		else:
			table.word_input.release_focus()
	table.countdown_label.visible = state.phase == "COUNTDOWN"
	table.countdown_label.text = state.countdown
	var rows: PackedStringArray = []
	for index in state.participants.size():
		rows.append("%02d %s" % [state.participant_seats[index] + 1, "♥".repeat(state.hearts[index]) if state.alive[index] else "AUS"])
	table.hearts_label.text = "    ·    ".join(rows)
	var color: Color = table.NEUTRAL
	var message := "DEIN ZUG" if can_type else "SPIELER %d IST DRAN" % state.active_peer
	if state.phase == "COUNTDOWN":
		message = "RUNDE STARTET …"
	elif state.phase == "MOVING":
		message = "ZUGWECHSEL …"
	elif state.phase == "FINISHED":
		message = "SPIELER %d GEWINNT! · Host: F5 neue Runde" % state.winner
		color = table.SUCCESS
	elif state.phase == "FEEDBACK":
		var valid: bool = state.verdict == service.TableRound.Rules.Verdict.VALID
		color = table.SUCCESS if valid else table.FAILURE
		message = "BESTÄTIGT: " + state.feedback_word if valid else state.error
		var actor_index: int = state.participants.find(state.feedback_actor)
		if actor_index >= 0:
			var label: Label3D = table.seats[state.participant_seats[actor_index]].word_label
			label.text = state.feedback_word
			label.modulate = color
	if not state.last_accepted.is_empty() and state.phase not in ["FEEDBACK", "FINISHED"]:
		message += " · Zuletzt: " + state.last_accepted
	table._set_feedback(color, message)
	table.turn_label.text = "ONLINE · DEIN PLATZ %02d" % (local_seat + 1)
	_update_timer()


func _process(_delta: float) -> void:
	if is_instance_valid(current_table):
		_update_timer()


func _update_timer() -> void:
	var state: Dictionary = service.round_states.get(current_table.table_id, {})
	if state.is_empty() or state.phase == "WAITING":
		return
	var now_estimate: int = state.server_now + Time.get_ticks_msec() - service.received_at[current_table.table_id]
	var seconds := maxf(0.0, float(state.deadline - now_estimate) / 1000)
	var text := "VORGABE NACH GO" if state.phase == "COUNTDOWN" else "VORGABE %s · %.1f s" % [state.prefix.to_upper(), seconds]
	if state.phase == "FINISHED":
		text = "RUNDE BEENDET · SIEGER %d" % state.winner
	current_table.rules_label.text = text + " · %s · Mature %s" % [["Easy", "Normal", "Hard"][state.difficulty], "ON" if state.mature else "OFF"]
