extends VBoxContainer
## Temporary Host/IP/Join controls. The transport does not depend on this UI.

var address: LineEdit
var host_button: Button
var join_button: Button
var leave_button: Button
var status_label: Label
var session: Node
var walker: CharacterBody3D
var table_service: Node
var admin_row: HBoxContainer
var start_buttons: Dictionary = {}
var players_label: Label
var notice_label: Label
var notice_until := 0
var lan_label: Label
var watch_row: HBoxContainer
var watch_buttons: Dictionary = {}
var stop_watching: Button
var watch_label: Label


func build(network_session: Node, player: CharacterBody3D) -> void:
	session = network_session
	walker = player
	position = Vector2(36, 120)
	add_theme_constant_override("separation", 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	host_button = _button(row, "Host Lobby · F8")
	var address_label := Label.new()
	address_label.text = "Host Address:"
	row.add_child(address_label)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "Host-IP"
	address.custom_minimum_size.x = 180
	address.max_length = 253
	row.add_child(address)
	address.focus_entered.connect(func():
		walker.mouse_released = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	join_button = _button(row, "Join Lobby · F9")
	leave_button = _button(row, "Disconnect · F10")
	host_button.pressed.connect(start_host)
	join_button.pressed.connect(start_join)
	leave_button.pressed.connect(func(): session.leave(); _resume())
	address.text_submitted.connect(func(_text: String): start_join())
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	add_child(status_label)
	var port_label := Label.new()
	port_label.text = "UDP Port: %d" % session.DEFAULT_PORT
	row.add_child(port_label)
	session.status_changed.connect(refresh)
	session.session_ended.connect(_resume)
	refresh()


func _button(row: HBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)
	return button


func start_host() -> void:
	session.host()
	var candidates: PackedStringArray = session.HostAddress.lan_candidates()
	lan_label.text = "LAN IP: " + " · ".join(candidates)
	if candidates.is_empty():
		lan_label.text = "LAN IP: keine IPv4 gefunden · Netzwerkadapter prüfen"
	_refresh_tables()
	_resume()


func start_join() -> void:
	if session.join(address.text) == OK:
		_resume()
	else:
		address.grab_focus()
		address.edit()


func _resume() -> void:
	address.release_focus()
	walker.mouse_released = false
	walker._capture_mouse()


func refresh() -> void:
	host_button.disabled = session.active
	join_button.disabled = session.active
	address.editable = not session.active
	leave_button.disabled = not session.active
	status_label.text = "Network: %s · %s" % [session.state_name(), session.status]
	if not session.active:
		status_label.text += " · Players: 0 / %d" % session.max_players
	if is_instance_valid(admin_row):
		_refresh_tables()


func configure_tables(service: Node) -> void:
	table_service = service
	players_label = Label.new()
	players_label.add_theme_font_size_override("font_size", 15)
	add_child(players_label)
	lan_label = Label.new()
	lan_label.add_theme_font_size_override("font_size", 15)
	lan_label.custom_minimum_size.x = 1000
	lan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_label.tooltip_text = "Bei mehreren Adaptern die IPv4 des gemeinsamen LANs verwenden; VPN/virtuelle Adapter können zusätzlich erscheinen."
	add_child(lan_label)
	watch_row = HBoxContainer.new()
	add_child(watch_row)
	for id: String in service.definitions:
		var watch := _button(watch_row, id + " zuschauen")
		watch.pressed.connect(func(): service.request_spectating(id); _resume())
		watch_buttons[id] = watch
	stop_watching = _button(watch_row, "Zuschauen beenden")
	stop_watching.pressed.connect(func(): service.request_spectating(""); _resume())
	watch_label = Label.new()
	watch_label.add_theme_font_size_override("font_size", 16)
	watch_label.custom_minimum_size.x = 1000
	watch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(watch_label)
	admin_row = HBoxContainer.new()
	admin_row.position = Vector2(36, 222)
	admin_row.add_theme_constant_override("separation", 8)
	get_parent().add_child(admin_row)
	notice_label = Label.new()
	notice_label.position = Vector2(36, 258)
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.modulate = Color("ffb58d")
	get_parent().add_child(notice_label)
	service.rejected.connect(show_notice)
	session.session_ended.connect(func(): show_notice(""))
	for id: String in service.definitions:
		var button := _button(admin_row, "Host: " + id + " starten")
		button.pressed.connect(func(): service.start_round(id))
		start_buttons[id] = button
	service.changed.connect(_refresh_tables)
	_refresh_tables()


func show_notice(message: String) -> void:
	notice_label.text = message
	notice_until = Time.get_ticks_msec() + 5000


func _process(_delta: float) -> void:
	if is_instance_valid(notice_label):
		notice_label.visible = Time.get_ticks_msec() < notice_until and not notice_label.text.is_empty()
		admin_row.position.y = maxf(222, position.y + size.y + 8)
		notice_label.position.y = admin_row.position.y + admin_row.size.y + 8
		_update_watching()


func _refresh_tables() -> void:
	admin_row.visible = session.hosting
	lan_label.visible = session.hosting
	var counts: PackedStringArray = []
	for id: String in table_service.tables:
		var seats: Array = table_service.tables[id].seats
		counts.append("%s: %d/%d" % [id, seats.size()-seats.count(0), seats.size()])
	var own: Dictionary = table_service.player_state(session.local_id)
	watch_row.visible = session.connected and own.mode in ["FREE", "SPECTATING"]
	stop_watching.disabled = own.mode != "SPECTATING"
	for id: String in watch_buttons:
		var target: Dictionary = table_service.tables.get(id, {})
		watch_buttons[id].disabled = own.mode != "FREE" or target.is_empty() or target.phase in ["WAITING", "FINISHED"]
	watch_label.visible = own.mode == "SPECTATING"
	players_label.text = " · ".join(counts) + (" · " if not counts.is_empty() else "") + own.mode
	for id: String in start_buttons:
		var state: Dictionary = table_service.tables.get(id, {})
		start_buttons[id].disabled = state.is_empty() or state.phase not in ["WAITING", "FINISHED"] or state.seats.size() - state.seats.count(0) < 2


func _update_watching() -> void:
	if not watch_label.visible:
		watch_label.text = ""
		return
	var own: Dictionary = table_service.player_state(session.local_id)
	var state: Dictionary = table_service.round_states.get(own.table_id, {})
	if state.is_empty():
		watch_label.text = "ZUSCHAUER · warte auf Tischzustand …"
		return
	var now: int = state.server_now + Time.get_ticks_msec() - table_service.received_at[own.table_id]
	var remaining := maxf(0, float(state.deadline-now)/1000)
	var progress := "Vorgabe %s · %.1f s · Spieler %d" % [state.prefix.to_upper(), remaining, state.active_peer]
	if state.phase == "COUNTDOWN":
		progress = "Countdown " + state.countdown
	elif state.phase == "FINISHED":
		progress = "Gewinner: %d" % state.winner
	var hearts: PackedStringArray = []
	for index in state.participants.size():
		hearts.append("%02d: %s" % [state.participant_seats[index]+1, "♥".repeat(state.hearts[index]) if state.alive[index] else "AUS"])
	watch_label.text = "ZUSCHAUER · %s · %s\nTeilnehmer: %s · Zuletzt: %s" % [own.table_id, progress, " / ".join(hearts), state.last_accepted]
