extends Node
## Host-owned table registry. Geometry is registered locally; clients send intentions only.

signal changed
signal rejected(message: String)
var session: Node
var definitions: Dictionary = {}
var tables: Dictionary = {}
const TableRound = preload("res://scripts/network/table_round.gd")
var host_rounds: Dictionary = {}
var round_states: Dictionary = {}
var received_at: Dictionary = {}
var broadcast_elapsed := 0.0
var submission_serial := 0


func setup(network_session: Node, table_nodes: Array) -> void:
	session = network_session
	for table: Node3D in table_nodes:
		assert(not definitions.has(table.table_id), "Each table needs a unique table_id")
		definitions[table.table_id] = table
	session.roster_changed.connect(_membership_changed)


func seat_of(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return {}
	for id: String in tables:
		var index: int = tables[id].seats.find(peer_id)
		if index >= 0:
			return {"table_id": id, "seat": index}
	return {}


func request_seat(table_id: String) -> void:
	if session.hosting:
		_assign(session.local_id, table_id)
	elif session.connected:
		_request_seat.rpc_id(1, table_id)


func request_leave() -> void:
	if session.hosting:
		_remove(session.local_id)
	elif session.connected:
		_request_leave.rpc_id(1)


func request_spectating(table_id: String) -> void:
	if session.hosting:
		_watch(session.local_id, table_id)
	elif session.connected:
		_request_spectating.rpc_id(1, table_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_spectating(table_id: String) -> void:
	if session.hosting:
		_watch(multiplayer.get_remote_sender_id(), table_id)


func _watch(peer_id: int, table_id: String) -> void:
	if not session.players.has(peer_id):
		return
	if not table_id.is_empty() and (not tables.has(table_id) or tables[table_id].phase in ["WAITING", "FINISHED"]):
		_deny(peer_id, "Zuschauen ist bei einer laufenden Runde möglich")
		return
	if not set_spectating(peer_id, table_id):
		_deny(peer_id, "Zum Zuschauen zuerst den Spielerplatz verlassen")


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_seat(table_id: String) -> void:
	if session.hosting:
		_assign(multiplayer.get_remote_sender_id(), table_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_leave() -> void:
	if session.hosting:
		_remove(multiplayer.get_remote_sender_id())


func _assign(id: int, table_id: String) -> void:
	if not session.players.has(id) or not tables.has(table_id) or not seat_of(id).is_empty():
		return
	if not spectator_of(id).is_empty():
		_deny(id, "Zuschauen zuerst beenden")
		return
	if not tables[table_id].seats.has(0):
		_deny(id, "Tisch voll · %s" % table_id)
		return
	if tables[table_id].phase not in ["WAITING", "FINISHED"]:
		_deny(id, "Runde läuft · bitte bis zum Rundenende warten")
		return
	var pose: Dictionary = session.players[id] if id != 1 else session.local_pose
	var table: Node3D = definitions[table_id]
	var nearest := -1
	var distance := 1.6
	if pose.is_empty() or not pose.grounded or absf(pose.position.y - table.global_position.y) > 0.35:
		_deny(id, "Zum Hinsetzen auf dem Boden zum Tisch gehen")
		return
	for index in tables[table_id].seats.size():
		var next_distance: float = pose.position.distance_to(table.seats[index].global_position)
		if tables[table_id].seats[index] == 0 and next_distance <= distance:
			nearest = index
			distance = next_distance
	if nearest < 0:
		_deny(id, "Kein freier Platz in Reichweite")
		return
	tables[table_id].seats[nearest] = id
	session.locked_poses[id] = true
	_publish()


func _remove(id: int) -> void:
	var seat := seat_of(id)
	if seat.is_empty():
		return
	# Running-round departures are handled by the disconnect policy in phase 3.
	if tables[seat.table_id].phase not in ["WAITING", "FINISHED"]:
		_deny(id, "Runde läuft · Aufstehen nach Rundenende")
		return
	tables[seat.table_id].seats[seat.seat] = 0
	session.locked_poses.erase(id)
	_publish()


func _membership_changed() -> void:
	if not session.active:
		tables.clear()
		host_rounds.clear()
		round_states.clear()
		received_at.clear()
		submission_serial = 0
		changed.emit()
		return
	if not session.hosting:
		return
	if tables.is_empty():
		for id: String in definitions:
			var seats: Array[int] = []
			seats.resize(definitions[id].SEAT_COUNT)
			seats.fill(0)
			tables[id] = {"table_id": id, "seats": seats, "spectators": [], "phase": "WAITING", "mature": definitions[id].match_settings.mature_words_allowed, "difficulty": definitions[id].match_settings.difficulty}
			host_rounds[id] = TableRound.new()
	for table: Dictionary in tables.values():
		for id: int in table.spectators.duplicate():
			if not session.players.has(id):
				table.spectators.erase(id)
		for index in table.seats.size():
			if table.seats[index] != 0 and not session.players.has(table.seats[index]):
				host_rounds[table.table_id].remove_participant(table.seats[index], Time.get_ticks_msec())
				table.phase = host_rounds[table.table_id].phase
				session.locked_poses.erase(table.seats[index])
				table.seats[index] = 0
	_publish()


func _publish() -> void:
	_refresh_player_modes()
	var own := player_state(session.local_id)
	for id: String in round_states.keys():
		if own.get("table_id", "") != id:
			round_states.erase(id)
			received_at.erase(id)
	if session.players.size() > 1:
		_receive_tables.rpc(tables)
	changed.emit()
	_send_rounds()


func _refresh_player_modes() -> void:
	for id: String in tables:
		tables[id].player_modes = {}
		var model: RefCounted = host_rounds[id]
		for peer_id: int in tables[id].seats:
			if peer_id == 0:
				continue
			var index: int = model.participants.find(peer_id)
			var mode := "SEATED"
			if index >= 0 and not model.rules.alive[index]:
				mode = "ELIMINATED"
			elif tables[id].phase not in ["WAITING", "FINISHED"]:
				mode = "PLAYING"
			tables[id].player_modes[peer_id] = mode


@rpc("authority", "call_remote", "reliable", 0)
func _receive_tables(snapshot: Dictionary) -> void:
	if session.connected and not session.hosting:
		tables = snapshot.duplicate(true)
		var own := player_state(session.local_id)
		for id: String in round_states.keys():
			if own.get("table_id", "") != id:
				round_states.erase(id)
				received_at.erase(id)
		changed.emit()


func start_round(table_id: String) -> void:
	# There is deliberately no client RPC for start or settings.
	if session.hosting and host_rounds.has(table_id):
		if host_rounds[table_id].start(tables[table_id].seats, Time.get_ticks_msec(), definitions[table_id].match_settings):
			tables[table_id].phase = "COUNTDOWN"
			_publish()


func update_settings(table_id: String) -> void:
	if session.hosting and tables.has(table_id) and tables[table_id].phase in ["WAITING", "FINISHED"]:
		tables[table_id].mature = definitions[table_id].match_settings.mature_words_allowed
		tables[table_id].difficulty = definitions[table_id].match_settings.difficulty
		_publish()


func submit_word(table_id: String, word: String) -> void:
	if not round_states.has(table_id):
		return
	submission_serial += 1
	var state: Dictionary = round_states[table_id]
	if session.hosting:
		_submit(session.local_id, table_id, word, state.round_id, state.turn_id, submission_serial)
	elif session.connected:
		_submit_word.rpc_id(1, table_id, word, state.round_id, state.turn_id, submission_serial)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_word(table_id: String, word: String, round_id: int, turn_id: int, serial: int) -> void:
	if session.hosting:
		_submit(multiplayer.get_remote_sender_id(), table_id, word, round_id, turn_id, serial)


func _submit(id: int, table_id: String, word: String, round_id: int, turn_id: int, serial: int) -> void:
	if not host_rounds.has(table_id) or seat_of(id).get("table_id", "") != table_id:
		return
	if host_rounds[table_id].submit(id, word, round_id, turn_id, serial, Time.get_ticks_msec()):
		tables[table_id].phase = host_rounds[table_id].phase
		_publish()
	else:
		_deny(id, "Abgabe verworfen · aktuellen Zug beachten")
		_send_rounds() # Restore UI from current truth after a stale/out-of-turn intent.


func _process(delta: float) -> void:
	if not is_instance_valid(session) or not session.hosting:
		return
	var dirty := false
	for id: String in host_rounds:
		host_rounds[id].tick(Time.get_ticks_msec())
		if tables[id].phase != host_rounds[id].phase:
			tables[id].phase = host_rounds[id].phase
			dirty = true
	broadcast_elapsed += delta
	if dirty:
		_publish()
	elif broadcast_elapsed >= 0.1:
		_send_rounds()
	if broadcast_elapsed >= 0.1:
		broadcast_elapsed = 0


func _send_rounds() -> void:
	if not session.hosting:
		return
	for id: String in host_rounds:
		var state: Dictionary = host_rounds[id].snapshot(Time.get_ticks_msec())
		for peer_id: int in tables[id].seats + tables[id].spectators:
			if peer_id == 0 or not session.players.has(peer_id):
				continue
			if peer_id == session.local_id:
				round_states[id] = state
				received_at[id] = Time.get_ticks_msec()
				changed.emit()
			else:
				_receive_round.rpc_id(peer_id, id, state)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_round(table_id: String, state: Dictionary) -> void:
	if session.connected and player_state(session.local_id).table_id == table_id:
		round_states[table_id] = state
		received_at[table_id] = Time.get_ticks_msec()
		changed.emit()


func player_state(peer_id: int) -> Dictionary:
	var seat := seat_of(peer_id)
	if seat.is_empty():
		var watching := spectator_of(peer_id)
		if not watching.is_empty():
			return {"mode": "SPECTATING", "table_id": watching, "seat": -1}
		return {"mode": "FREE", "table_id": "", "seat": -1}
	return {"mode": tables[seat.table_id].get("player_modes", {}).get(peer_id, "SEATED"), "table_id": seat.table_id, "seat": seat.seat}


func spectator_of(peer_id: int) -> String:
	for id: String in tables:
		if tables[id].spectators.has(peer_id):
			return id
	return ""


func set_spectating(peer_id: int, table_id: String) -> bool:
	# Separate read-only membership; never changes seats or the frozen round participants.
	if not session.hosting or not session.players.has(peer_id) or not seat_of(peer_id).is_empty():
		return false
	if not table_id.is_empty() and not tables.has(table_id):
		return false
	for table: Dictionary in tables.values():
		table.spectators.erase(peer_id)
	if not table_id.is_empty():
		tables[table_id].spectators.append(peer_id)
	_publish()
	return true


func _deny(id: int, message: String) -> void:
	if id == session.local_id:
		rejected.emit(message)
	else:
		_denied.rpc_id(id, message)


@rpc("authority", "call_remote", "reliable", 0)
func _denied(message: String) -> void:
	rejected.emit(message)
