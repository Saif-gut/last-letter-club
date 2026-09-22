extends Node3D
## Coordinates one local walker and the existing table prototype.

const Geometry = preload("res://scenes/table_prototype/prototype_seat.gd")
const JOIN_DISTANCE := 1.6
const EXIT_RADIUS := 3.5
const NetworkSession = preload("res://scripts/network/lobby_session.gd")
const RemotePlayer = preload("res://scripts/network/remote_lobby_player.gd")
const NetworkPanel = preload("res://scripts/network/lobby_network_panel.gd")

@onready var table: Node3D = $TablePrototype
@onready var player: CharacterBody3D = $LobbyPlayer

var seated := false
var join_hint: Label
var instructions: Label
var title: Label
var crosshair: Label
var mature_words_label: Label
var difficulty_label: Label
var network_session: Node
var network_panel: Control
var remote_players: Dictionary = {}
var table_service: Node
var online_view: Node
var join_table_id := "table_01"
var join_blocked_reason := ""


func _ready() -> void:
	var table_nodes: Array = [table]
	if "--single-table" not in OS.get_cmdline_user_args():
		var second: Node3D = load("res://scenes/table_prototype/table_prototype.tscn").instantiate()
		second.name = "TablePrototype02"
		second.table_id = "table_02"
		second.embedded_in_lobby = true
		second.position = Vector3(3.1, 0, -4)
		add_child(second)
		table_nodes.append(second)
	_build_room()
	for node: Node3D in table_nodes:
		_build_table_collisions(node)
	network_session = NetworkSession.new()
	network_session.name = "NetworkSession" # Identical RPC path in every instance.
	add_child(network_session)
	network_session.roster_changed.connect(_sync_remote_players)
	network_session.pose_received.connect(_receive_remote_pose)
	network_session.local_spawn_requested.connect(_network_spawn)
	_build_hud()
	table_service = preload("res://scripts/network/table_service.gd").new()
	table_service.name = "TableService"
	add_child(table_service)
	table_service.setup(network_session, table_nodes)
	online_view = preload("res://scripts/network/online_table_view.gd").new()
	add_child(online_view)
	online_view.setup(self, table_service)
	network_panel.configure_tables(table_service)
	player.set_walking(true)
	_update_hud()


func _process(_delta: float) -> void:
	network_session.set_local_pose(player.global_position, player.rotation.y, player.look_pitch, player.velocity, player.is_on_floor())
	_update_hud()


func join_candidate() -> int:
	join_table_id = table.table_id
	join_blocked_reason = ""
	if seated or not player.is_on_floor() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return -1
	if network_session.active:
		if not network_session.connected:
			return -1
		var best := -1
		var distance := JOIN_DISTANCE
		var blocked_distance := JOIN_DISTANCE
		for id: String in table_service.tables:
			if not table_service.definitions.has(id):
				continue
			var candidate_table: Node3D = table_service.definitions[id]
			for index in candidate_table.SEAT_COUNT:
				var candidate_distance: float = player.global_position.distance_to(candidate_table.seats[index].global_position)
				var available: bool = table_service.tables[id].phase in ["WAITING", "FINISHED"] and table_service.tables[id].seats[index] == 0
				if available and candidate_distance <= distance:
					best = index
					distance = candidate_distance
					join_table_id = id
				elif not available and candidate_distance <= blocked_distance:
					blocked_distance = candidate_distance
					join_blocked_reason = "%s · %s" % [id, "Tisch voll" if not table_service.tables[id].seats.has(0) else ("Runde läuft" if table_service.tables[id].phase not in ["WAITING", "FINISHED"] else "Platz belegt – freien Stuhl wählen")]
		if best >= 0:
			join_blocked_reason = ""
		return best
	if absf(player.global_position.y - table.global_position.y) > 0.35:
		return -1
	var seat: int = table.nearest_free_seat(player.global_position)
	if seat < 0 or player.global_position.distance_to(table.seats[seat].global_position) > JOIN_DISTANCE:
		return -1
	return seat


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if (not seated and event.keycode in [KEY_F8, KEY_F9, KEY_F10]) or (network_session.active and event.keycode == KEY_F10):
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_F8:
			network_panel.start_host()
		elif event.keycode == KEY_F9:
			network_panel.start_join()
		else:
			network_session.leave()
			network_panel._resume()
		return
	if network_panel.address.has_focus():
		if event.keycode == KEY_ESCAPE:
			network_panel._resume()
			get_viewport().set_input_as_handled()
		return # Typing an IP must not join a table or change match settings.
	if seated and event.keycode == KEY_F4:
		get_viewport().set_input_as_handled()
		if network_session.connected:
			table_service.request_leave()
		else:
			leave_table()
	elif not seated and not network_session.active and event.keycode == KEY_F6:
		get_viewport().set_input_as_handled()
		table.match_settings.mature_words_allowed = not table.match_settings.mature_words_allowed
		_update_hud()
	elif not seated and not network_session.active and event.keycode == KEY_F7:
		get_viewport().set_input_as_handled()
		table.match_settings.difficulty = (table.match_settings.difficulty + 1) % 3
		_update_hud()
	elif not seated and event.keycode == KEY_E:
		# Consume E before activating the LineEdit, so it cannot leak into the word.
		get_viewport().set_input_as_handled()
		var seat := join_candidate()
		if seat < 0 and not join_blocked_reason.is_empty():
			network_panel.show_notice(join_blocked_reason)
		if seat >= 0:
			if network_session.connected:
				table_service.request_seat(join_table_id)
				return
			seated = true
			player.set_walking(false)
			table.enter_table(seat)
			_update_hud()


func leave_table() -> void:
	if not seated:
		return
	var angle: float = TAU * table.active_seat / table.SEAT_COUNT
	# Dedicated clear points outside the chairs, all within the fixed test room.
	var exit_position := Vector3(sin(angle) * EXIT_RADIUS, 0.05, cos(angle) * EXIT_RADIUS)
	table.leave_table()
	player.global_position = table.to_global(exit_position)
	player.rotation.y = table.rotation.y + angle
	player.look_pitch = deg_to_rad(-12.0)
	seated = false
	player.set_walking(true)
	_update_hud()


func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("15242c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d1d6")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -25, 0)
	light.light_color = Color("ffe0b2")
	light.light_energy = 1.6
	light.shadow_enabled = true
	add_child(light)
	_solid_box("Floor", Vector3(14, 0.2, 16), Vector3(0, -0.1, 0), Color("243b43"))
	_solid_box("NorthWall", Vector3(14.5, 4.5, 0.25), Vector3(0, 2.25, -8), Color("35545c"))
	_solid_box("SouthWall", Vector3(14.5, 4.5, 0.25), Vector3(0, 2.25, 8), Color("35545c"))
	_solid_box("WestWall", Vector3(0.25, 4.5, 16), Vector3(-7, 2.25, 0), Color("2d4853"))
	_solid_box("EastWall", Vector3(0.25, 4.5, 16), Vector3(7, 2.25, 0), Color("2d4853"))
	var sign_label := Label3D.new()
	sign_label.text = "LAST LETTER CLUB\nLOBBY / TISCH 01"
	sign_label.position = Vector3(0, 2.7, -7.84)
	sign_label.font_size = 64
	sign_label.pixel_size = 0.006
	sign_label.modulate = Color("f0ce8b")
	add_child(sign_label)


func _solid_box(node_name: String, size: Vector3, at: Vector3, color: Color) -> void:
	var visual := Geometry.box(self, size, at, Geometry.material(color))
	visual.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	_add_collider(visual, shape, Vector3.ZERO)


func _add_collider(parent: Node3D, shape: Shape3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func _build_table_collisions(target: Node3D) -> void:
	var table_shape := CylinderShape3D.new()
	table_shape.radius = 1.53
	table_shape.height = 0.83
	_add_collider(target, table_shape, Vector3(0, 0.415, 0))
	for seat in target.seats:
		var chair_shape := BoxShape3D.new()
		chair_shape.size = Vector3(0.7, 1.4, 0.75)
		_add_collider(seat, chair_shape, Vector3(0, 0.7, 0.05))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LobbyHUD"
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _label(root, 24)
	title.position = Vector2(36, 24)
	title.text = "LAST LETTER CLUB  /  LOBBY"
	title.modulate = Color("f0ce8b")
	mature_words_label = _label(root, 18)
	mature_words_label.position = Vector2(36, 64)
	difficulty_label = _label(root, 18)
	difficulty_label.position = Vector2(36, 90)
	network_panel = NetworkPanel.new()
	root.add_child(network_panel)
	network_panel.build(network_session, player)
	instructions = _label(root, 16)
	instructions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	instructions.offset_left = 36
	instructions.offset_right = 650
	instructions.offset_top = -76
	instructions.offset_bottom = -24
	join_hint = _label(root, 24)
	join_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	join_hint.offset_left = -300
	join_hint.offset_right = 300
	join_hint.offset_top = 64
	join_hint.offset_bottom = 110
	join_hint.modulate = Color("f0ce8b")
	join_hint.add_theme_constant_override("outline_size", 4)
	join_hint.add_theme_color_override("font_outline_color", Color("102027"))
	crosshair = _label(root, 22)
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10
	crosshair.offset_right = 10
	crosshair.offset_top = -15
	crosshair.offset_bottom = 15


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color("102027"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _update_hud() -> void:
	title.visible = not seated
	mature_words_label.visible = not seated
	difficulty_label.visible = not seated
	network_panel.visible = not seated
	difficulty_label.text = "Difficulty: %s  ·  F7 Umschalten" % ["Easy", "Normal", "Hard"][table.match_settings.difficulty]
	mature_words_label.text = "Mature Words: %s  ·  F6 Umschalten" % ("ON" if table.match_settings.mature_words_allowed else "OFF")
	if network_session.active:
		difficulty_label.text = "Difficulty: %s  ·  lokale Runde / offline einstellbar" % ["Easy", "Normal", "Hard"][table.match_settings.difficulty]
		mature_words_label.text = "Mature Words: %s  ·  lokale Runde / offline einstellbar" % ("ON" if table.match_settings.mature_words_allowed else "OFF")
	crosshair.visible = not seated and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var seat := join_candidate()
	join_hint.visible = seat >= 0 or not join_blocked_reason.is_empty()
	join_hint.text = "E – Join Table  /  Platz %02d frei" % (seat + 1)
	if network_session.connected:
		join_hint.text = "E – %s / Platz %02d frei" % [join_table_id, seat + 1]
		if not join_blocked_reason.is_empty():
			join_hint.text = join_blocked_reason
	if seated:
		instructions.offset_top = -48
		instructions.text = "F4  Tisch verlassen"
	else:
		instructions.offset_top = -76
		instructions.text = "WASD  Gehen    ·    MAUS  Umsehen    ·    SPACE  Springen\nESC  Maus freigeben / weiterspielen"
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			join_hint.show()
			join_hint.text = "Maus frei – Esc zum Weiterspielen" if player.get_window().has_focus() else "Zum Spielfenster zurückkehren"


func _network_spawn(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_camera()


func _sync_remote_players() -> void:
	for id: int in remote_players.keys():
		if not network_session.players.has(id):
			remote_players[id].queue_free()
			remote_players.erase(id)
	for id: int in network_session.players:
		if id == network_session.local_id:
			continue
		if not remote_players.has(id):
			var remote := RemotePlayer.new()
			remote.name = "RemotePlayer_%d" % id
			add_child(remote)
			remote.build(player.avatar, id)
			remote_players[id] = remote
		remote_players[id].receive(network_session.players[id])
		if is_instance_valid(table_service):
			remote_players[id].visible = table_service.seat_of(id).is_empty()


func _receive_remote_pose(id: int, pose: Dictionary) -> void:
	if remote_players.has(id):
		remote_players[id].receive(pose)
