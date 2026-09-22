extends Node
## Transport + host-owned membership. Contains no camera, input, table or round rules.
## Clients report only their own locomotion; sender identity comes from ENet.

signal roster_changed
signal pose_received(peer_id: int, pose: Dictionary)
signal local_spawn_requested(position: Vector3)
signal status_changed
signal session_ended

const PROTOCOL_VERSION := 1
const HostAddress = preload("res://scripts/network/host_address.gd")
const DEFAULT_PORT := 24572
const REJECTION_SLOTS := 2 # Transport slots only; never admitted to the player registry.
const SEND_INTERVAL := 0.05
@export_range(2, 64) var max_players := 16

var players: Dictionary = {}
var active := false
var connected := false
var hosting := false
var status := "Offline · lokale Tischrunde verfügbar"
var local_id := 0
var peer: ENetMultiplayerPeer
var slots: Dictionary = {}
var last_received_ms: Dictionary = {}
var connection_deadline := 0
var sequence := 0
var send_elapsed := 0.0
var local_pose: Dictionary = {}
var locked_poses: Dictionary = {}
var rejected_peers: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connection_failed.connect(func(): leave("Connection failed · Verbindung fehlgeschlagen · Offline"))
	multiplayer.server_disconnected.connect(func(): leave("Verbindung getrennt · Host beendet oder verloren · Offline"))


func host(port: int = DEFAULT_PORT) -> Error:
	if active:
		return ERR_ALREADY_IN_USE
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip("*") # LAN + localhost; no automatic router or firewall changes.
	var error := peer.create_server(port, max_players - 1 + REJECTION_SLOTS, 2)
	if error != OK:
		peer = null
		_set_status("Host fehlgeschlagen: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	connected = true
	hosting = true
	local_id = 1
	slots[1] = 0
	players[1] = _pose(Vector3(0, 0.05, 6), 0, 0, Vector3.ZERO, false, 0)
	if not local_pose.is_empty():
		players[1] = local_pose.duplicate()
	roster_changed.emit()
	_update_connected_status()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	if active:
		return ERR_ALREADY_IN_USE
	if address.strip_edges().is_empty():
		_set_status("Bitte Host-IP eingeben")
		return ERR_INVALID_PARAMETER
	if not HostAddress.valid(address):
		_set_status("Ungültige Host-Adresse · IP oder Hostname ohne URL/Port eingeben")
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port, 2)
	if error != OK:
		peer = null
		_set_status("Join fehlgeschlagen: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	connection_deadline = Time.get_ticks_msec() + 8000
	_set_status("Connecting · Verbinde mit %s:%d …" % [address.strip_edges(), port])
	return OK


func leave(reason: String = "Disconnected · Verbindung getrennt · lokale Tischrunde verfügbar") -> void:
	var was_active := active
	active = false
	connected = false
	hosting = false
	local_id = 0
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	slots.clear()
	last_received_ms.clear()
	connection_deadline = 0
	sequence = 0
	send_elapsed = 0
	local_pose.clear() # Never reuse the previous session's sequence/pose on immediate rehost.
	locked_poses.clear()
	rejected_peers.clear()
	roster_changed.emit()
	_set_status(reason)
	if was_active:
		session_ended.emit()


func set_local_pose(position: Vector3, yaw: float, pitch: float, velocity: Vector3, grounded: bool) -> void:
	local_pose = _pose(position, yaw, pitch, velocity, grounded, sequence)


func _process(delta: float) -> void:
	if hosting:
		for id: int in rejected_peers.keys():
			if Time.get_ticks_msec() >= rejected_peers[id]:
				rejected_peers.erase(id)
				peer.disconnect_peer(id)
	if active and not connected and Time.get_ticks_msec() >= connection_deadline:
		leave("Host nicht erreichbar (8 s) · Offline")
	if not connected or local_pose.is_empty():
		return
	send_elapsed += delta
	if send_elapsed < SEND_INTERVAL:
		return
	send_elapsed = fmod(send_elapsed, SEND_INTERVAL)
	sequence += 1
	local_pose.sequence = sequence
	if hosting:
		players[1] = local_pose.duplicate()
		if players.size() > 1:
			_receive_poses.rpc(players)
	else:
		_submit_pose.rpc_id(1, local_pose.position, local_pose.yaw, local_pose.pitch,
			local_pose.velocity, local_pose.grounded, sequence)


func _peer_connected(id: int) -> void:
	if peer and (hosting or id == 1):
		peer.get_peer(id).set_timeout(32, 3000, 8000)
		peer.get_peer(id).ping_interval(500)
	if not hosting:
		return
	if players.size() >= max_players:
		rejected_peers[id] = Time.get_ticks_msec() + 2000
		_reject_join.rpc_id(id, "Lobby full · Lobby voll · maximal %d Spieler · Offline" % max_players)
		return
	var slot := 1
	while slots.values().has(slot):
		slot += 1
	slots[id] = slot
	# Temporary room spawn layout. Peer membership is independent of table seat count.
	var spawn := Vector3(-5.25 + (slot % 8) * 1.5, 0.05, 5.5 if slot < 8 else -5.5)
	players[id] = _pose(spawn, 0, 0, Vector3.ZERO, false, 0)
	_send_roster()
	roster_changed.emit()
	_update_connected_status()


func _peer_disconnected(id: int) -> void:
	if not hosting:
		return # Clients accept membership changes only from the host snapshot.
	if not players.has(id):
		rejected_peers.erase(id)
		return
	players.erase(id)
	slots.erase(id)
	last_received_ms.erase(id)
	if players.size() > 1:
		_send_roster()
	roster_changed.emit()
	_update_connected_status()


func _send_roster() -> void:
	for id: int in players:
		if id != local_id:
			_receive_roster.rpc_id(id, PROTOCOL_VERSION, max_players, players)


@rpc("authority", "call_remote", "reliable", 0)
func _reject_join(reason: String) -> void:
	if active and not connected and not hosting:
		leave(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_roster(version: int, capacity: int, roster: Dictionary) -> void:
	if not active or hosting:
		return
	if version != PROTOCOL_VERSION:
		leave("Unterschiedliche Spielversionen · Offline")
		return
	var first_snapshot := not connected
	local_id = multiplayer.get_unique_id()
	if not roster.has(local_id):
		leave("Host hat den lokalen Spieler entfernt · Offline")
		return
	players = roster.duplicate(true)
	max_players = capacity
	connected = true
	connection_deadline = 0
	if first_snapshot:
		local_spawn_requested.emit(players[local_id].position)
	roster_changed.emit()
	_update_connected_status()


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_pose(position: Vector3, yaw: float, pitch: float, velocity: Vector3, grounded: bool, serial: int) -> void:
	if not hosting:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender) or sender == 1 or locked_poses.has(sender):
		return
	if not valid_pose(position, yaw, pitch, velocity) or serial <= int(players[sender].sequence):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_received_ms.get(sender, -1000)) < 20:
		return
	last_received_ms[sender] = now
	players[sender] = _pose(position, wrapf(yaw, -PI, PI), clampf(pitch, -PI / 3, PI / 3), velocity, grounded, serial)
	pose_received.emit(sender, players[sender])


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_poses(poses: Dictionary) -> void:
	if not connected or hosting:
		return
	for id: int in poses:
		if id != local_id and players.has(id) and int(poses[id].sequence) >= int(players[id].sequence):
			players[id] = poses[id]
			pose_received.emit(id, players[id])


static func valid_pose(position: Vector3, yaw: float, pitch: float, velocity: Vector3) -> bool:
	# Basic payload sanity for this test room, not authoritative movement/anti-cheat.
	return position.is_finite() and velocity.is_finite() and is_finite(yaw) and is_finite(pitch) \
		and absf(position.x) <= 7 and absf(position.z) <= 8 and position.y >= -0.5 and position.y <= 5 \
		and velocity.length() <= 20


static func _pose(position: Vector3, yaw: float, pitch: float, velocity: Vector3, grounded: bool, serial: int) -> Dictionary:
	return {"position": position, "yaw": yaw, "pitch": pitch, "velocity": velocity, "grounded": grounded, "sequence": serial}


func _update_connected_status() -> void:
	_set_status("%s · Players: %d / %d" % ["Hosting" if hosting else "Connected", players.size(), max_players])


func state_name() -> String:
	if hosting:
		return "Host"
	if connected:
		return "Connected / Client"
	if active:
		return "Connecting"
	return "Offline"


func _set_status(message: String) -> void:
	status = message
	status_changed.emit()


func _exit_tree() -> void:
	# During scene teardown sibling avatars may already be freed; emit no UI signals.
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
