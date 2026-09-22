extends SceneTree
## Simulated membership uses real geometry, avatars and host rules, without fake ENet peers.

class Membership extends Node:
	signal roster_changed
	var players: Dictionary = {}
	var active := true
	var hosting := true
	var connected := true
	var local_id := 1
	var local_pose: Dictionary = {}
	var locked_poses: Dictionary = {}

class Registry extends "res://scripts/network/table_service.gd":
	var rejection := ""
	func _publish() -> void:
		_refresh_player_modes()
	func _send_rounds() -> void:
		pass
	func _deny(_id: int, message: String) -> void:
		rejection = message

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var lobby: Node3D = main.get_node("Lobby")
	var membership := Membership.new()
	root.add_child(membership)
	var registry := Registry.new()
	root.add_child(registry)
	registry.set_process(false)
	registry.setup(membership, lobby.table_service.definitions.values())
	for id in range(1,17):
		membership.players[id] = lobby.network_session._pose(Vector3(0,0.05,6),0,0,Vector3.ZERO,true,0)
	registry._membership_changed()
	check(registry.seat_of(0).is_empty(), "Zero is an empty slot, never a player.")
	for id in range(2,10):
		var table_id := "table_01" if id < 6 else "table_02"
		var table: Node3D = registry.definitions[table_id]
		var index := (id-2)%4
		membership.players[id].position = table.seats[index].global_position
		check(registry.player_state(id).mode == "FREE", "New members must be FREE.")
		registry._assign(id, table_id)
		check(registry.player_state(id).mode == "SEATED" and registry.seat_of(id).table_id == table_id, "Seat state and table ID must agree.")
	registry._remove(2)
	check(registry.player_state(2).mode == "FREE" and not membership.locked_poses.has(2), "Leaving clears membership and movement lock.")
	registry._assign(2,"table_01")
	check(membership.players.size() == 16 and registry.tables.table_01.seats.size() == 4 and registry.tables.table_02.seats.size() == 4, "Lobby and table capacities are independent.")
	registry._assign(10,"table_01")
	check(registry.seat_of(10).is_empty() and registry.rejection.contains("Tisch voll"), "Full table must reject a fifth seat with a clear reason.")
	registry.start_round("table_01")
	registry.start_round("table_02")
	var first: RefCounted = registry.host_rounds.table_01
	var second: RefCounted = registry.host_rounds.table_02
	check(first.participants == [2,3,4,5] and second.participants == [6,7,8,9], "Only assigned seats enter their round.")
	check(first.rules.hearts == [3,3,3,3] and registry.player_state(10).mode == "FREE", "Free players receive no hearts or turns.")
	check(registry.player_state(2).mode == "PLAYING", "Countdown participant must be PLAYING.")
	first.tick(first.phase_end)
	var deadline: int = first.rules.deadline_ms
	var before: Dictionary = first.snapshot(deadline-9000)
	registry._submit(10,"table_01","madeup",first.round_id,first.turn_id,1)
	check(first.snapshot(deadline-9000) == before, "Free player's submission cannot change the round.")
	check(registry.set_spectating(10,"table_01") and registry.player_state(10).mode == "SPECTATING", "Watching has a separate table association.")
	check(not registry.set_spectating(2,"table_02"), "Seated participants cannot also become spectators.")
	registry.set_spectating(10,"table_01")
	check(registry.tables.table_01.spectators == [10] and not first.participants.has(10) and first.rules.hearts.size() == 4, "Spectators have no seat, hearts or duplicate subscriptions.")
	registry._submit(10,"table_01","madeup",first.round_id,first.turn_id,2)
	check(first.snapshot(deadline-9000) == before, "Spectator cannot submit words or affect the timer/winner.")
	registry.set_spectating(10,"table_02")
	check(registry.tables.table_01.spectators.is_empty() and registry.tables.table_02.spectators == [10], "Watching another table removes the old subscription.")
	registry.set_spectating(10,"")
	check(registry.player_state(10).mode == "FREE", "Leaving spectator association restores FREE.")
	registry.set_spectating(11,"table_01")
	membership.players.erase(11)
	registry._membership_changed()
	check(registry.tables.table_01.spectators.is_empty() and first.snapshot(deadline-9000) == before, "Spectator disconnect cannot eliminate a participant or alter a round.")
	membership.players[11] = membership.players[1].duplicate()
	first.remove_participant(3,deadline-9000)
	registry._refresh_player_modes()
	check(registry.player_state(3).mode == "ELIMINATED" and first.rules.deadline_ms == deadline, "Eliminated participant remains assigned without a turn.")
	var second_before: Dictionary = second.snapshot(0)
	membership.players.erase(4)
	registry._membership_changed()
	check(registry.seat_of(4).is_empty() and not membership.locked_poses.has(4) and not first.rules.alive[2], "Disconnect removes only that seat and participant.")
	check(second.snapshot(0) == second_before, "Other table is unaffected by membership cleanup.")
	# Exercise production avatar spawning/cleanup with sixteen IDs in one scene.
	lobby.network_session.local_id = 1
	lobby.network_session.players = membership.players.duplicate(true)
	lobby.network_session.players[4] = membership.players[1].duplicate()
	lobby._sync_remote_players()
	check(lobby.remote_players.size() == 15, "Sixteen registry entries must spawn fifteen remote avatars.")
	lobby.network_session.players.erase(4)
	lobby._sync_remote_players()
	await process_frame
	check(lobby.remote_players.size() == 14 and lobby.find_child("RemotePlayer_4",true,false) == null, "Removed avatar must actually leave the tree.")
	lobby.network_session.leave()
	await process_frame
	check(lobby.remote_players.is_empty(), "Registry cleanup leaves no remote avatars.")
	membership.active = false
	registry._membership_changed()
	check(registry.tables.is_empty() and registry.host_rounds.is_empty(), "Session end clears every table model.")
	main.queue_free()
	registry.queue_free()
	membership.queue_free()
	await process_frame
	print("PLAYER_REGISTRY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
