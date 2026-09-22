extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	var lobby: Node3D = main.get_node("Lobby")
	var panel: Control = lobby.network_panel
	var session: Node = lobby.network_session
	await process_frame
	for bad_address in ["", "https://host", "999.12.1.1"]:
		panel.address.text = bad_address
		panel.join_button.pressed.emit()
		await process_frame
		check(not session.active and not panel.host_button.disabled and not panel.join_button.disabled and panel.leave_button.disabled, "Invalid address must keep join/host available.")
		check(panel.address.editable and panel.address.has_focus(), "Invalid input keeps focus for correction.")
	panel.address.text = "127.0.0.1"
	panel.join_button.pressed.emit()
	check(session.state_name() == "Connecting" and panel.host_button.disabled and panel.join_button.disabled and not panel.leave_button.disabled, "Pending connection can only be cancelled.")
	panel.leave_button.pressed.emit()
	check(not session.active and panel.address.editable and not panel.host_button.disabled, "Cancelling Connecting restores all controls.")
	panel.host_button.pressed.emit()
	check(session.hosting and panel.status_label.text.contains("Hosting") and panel.lan_label.visible and panel.lan_label.text.begins_with("LAN IP:"), "Host button uses the existing session and displays local addresses.")
	panel.leave_button.pressed.emit()
	check(not panel.host_button.disabled and not panel.join_button.disabled and panel.leave_button.disabled and not panel.lan_label.visible, "Host disconnect cannot leave UI stuck.")
	main.queue_free()
	await process_frame
	print("NETWORK_PANEL: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
