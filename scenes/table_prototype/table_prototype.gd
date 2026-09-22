extends Node3D
## Existing table presentation with a separate, offline local round model.

const Seat = preload("res://scenes/table_prototype/prototype_seat.gd")
const RoundRules = preload("res://scripts/last_letter_round.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const SEAT_COUNT := 4
const SEAT_RADIUS := 2.25
const EYE_HEIGHT := 1.22
const NEUTRAL := Color("f0ce8b")
const SUCCESS := Color("80e6a1")
const FAILURE := Color("ff8089")
const COUNTDOWN_STEP_MS := 1000
const GO_MS := 500

enum Phase { TYPING, FEEDBACK, MOVING, FINISHED, COUNTDOWN }

@export_range(0.25, 1.2, 0.05) var camera_move_seconds := 0.55
@export_range(0.1, 0.6, 0.05) var feedback_seconds := 0.22
@export var embedded_in_lobby := false
@export var table_id := "table_01"
@export var match_settings: MatchSettings = MatchSettings.new()

var table_enabled := false
var session_id := 0
var feedback_id := 0
var feedback_active := false
var round_state := RoundRules.new()
var countdown_started_ms := 0
var pending_start_letter := ""
var hud: CanvasLayer

var active_seat := 0
var departing_seat := -1
var phase := Phase.TYPING
var orbit_angle := 0.0
var overview := false
var seats: Array[Node3D] = []
var camera: Camera3D
var word_input: LineEdit
var turn_label: Label
var status_label: Label
var rules_label: Label
var hearts_label: Label
var countdown_label: Label
var input_panel: StyleBoxFlat
var motion: Tween


func _ready() -> void:
	_build_room()
	_build_seats()
	camera = Camera3D.new()
	camera.name = "SeatCamera"
	# This camera already moves smoothly via an idle-frame tween.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = 78.0
	camera.near = 0.05
	add_child(camera)
	_build_hud()
	if embedded_in_lobby:
		leave_table()
	else:
		enter_table(0)


func enter_table(seat_index: int, start_letter: String = "") -> void:
	session_id += 1
	feedback_id += 1
	feedback_active = false
	if motion and motion.is_valid():
		motion.kill()
	table_enabled = true
	active_seat = clampi(seat_index, 0, SEAT_COUNT - 1)
	round_state.validator.policy.profanity_allowed = match_settings.mature_words_allowed
	round_state.prefix_advisor.profile = round_state.prefix_advisor.DifficultyProfile.for_mode(match_settings.difficulty)
	round_state.prepare(SEAT_COUNT, active_seat)
	pending_start_letter = start_letter
	countdown_started_ms = Time.get_ticks_msec()
	for seat in seats:
		seat.word_label.text = "…"
		seat.word_label.modulate = NEUTRAL
	departing_seat = -1
	phase = Phase.COUNTDOWN
	overview = false
	hud.show()
	camera.make_current()
	_place_camera(TAU * active_seat / SEAT_COUNT)
	word_input.editable = false
	word_input.release_focus()
	word_input.clear()
	_update_word("")
	_refresh_seats()
	_set_feedback(NEUTRAL, "RUNDE STARTET …")
	countdown_label.text = "3"
	countdown_label.show()
	_update_round_hud()


func leave_table() -> void:
	# Cancel both the camera tween and pending feedback from the previous session.
	session_id += 1
	feedback_id += 1
	feedback_active = false
	round_state.stop()
	pending_start_letter = ""
	countdown_started_ms = 0
	countdown_label.hide()
	table_enabled = false
	if motion and motion.is_valid():
		motion.kill()
	phase = Phase.TYPING
	departing_seat = -1
	overview = false
	word_input.editable = false
	word_input.release_focus()
	word_input.clear()
	hud.hide()
	camera.clear_current(false)
	_refresh_seats()


func _process(_delta: float) -> void:
	if not table_enabled:
		return
	if phase == Phase.COUNTDOWN:
		_update_countdown(Time.get_ticks_msec())
	if round_state.expire(Time.get_ticks_msec()):
		_present_result(RoundRules.Verdict.TIMEOUT)
	_update_round_hud()


func _update_countdown(now_ms: int) -> void:
	# No asynchronous callbacks: leaving/rejoining cannot finish an old countdown.
	var elapsed := now_ms - countdown_started_ms
	if elapsed < 3 * COUNTDOWN_STEP_MS:
		countdown_label.text = str(3 - int(elapsed / COUNTDOWN_STEP_MS))
	elif elapsed < 3 * COUNTDOWN_STEP_MS + GO_MS:
		countdown_label.text = "GO"
	else:
		round_state.begin_round(now_ms, pending_start_letter)
		pending_start_letter = ""
		countdown_label.hide()
		phase = Phase.TYPING
		word_input.clear()
		word_input.editable = true
		_update_word("")
		word_input.grab_focus()
		word_input.edit()


func nearest_free_seat(world_position: Vector3) -> int:
	# This local table has no other real occupants. While running, joining is locked.
	if table_enabled:
		return -1
	var nearest := -1
	var nearest_distance := INF
	for index in SEAT_COUNT:
		var distance := world_position.distance_squared_to(seats[index].global_position)
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func _build_room() -> void:
	if not embedded_in_lobby:
		_build_standalone_environment()
	_build_table()


func _build_standalone_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("15242c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9c8d1")
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
	Seat.box(self, Vector3(20, 0.1, 20), Vector3(0, -0.06, 0), Seat.material(Color("172b34")))


func _build_table() -> void:
	var rug := CylinderMesh.new()
	rug.top_radius = 3.2
	rug.bottom_radius = 3.2
	rug.height = 0.012
	rug.radial_segments = 96
	Seat.mesh(self, rug, Vector3.ZERO, Seat.material(Color("314e53")))
	var top := CylinderMesh.new()
	top.top_radius = 1.53
	top.bottom_radius = 1.53
	top.height = 0.12
	top.radial_segments = 96
	Seat.mesh(self, top, Vector3(0, 0.76, 0), Seat.material(Color("926949")))
	var inset := CylinderMesh.new()
	inset.top_radius = 1.40
	inset.bottom_radius = 1.40
	inset.height = 0.008
	inset.radial_segments = 96
	Seat.mesh(self, inset, Vector3(0, 0.824, 0), Seat.material(Color("294c49")))
	Seat.box(self, Vector3(0.5, 0.7, 0.5), Vector3(0, 0.35, 0), Seat.material(Color("433a32")))
	var center := TorusMesh.new()
	center.inner_radius = 0.24
	center.outer_radius = 0.255
	Seat.mesh(self, center, Vector3(0, 0.838, 0), Seat.material(NEUTRAL))


func _build_seats() -> void:
	for index in SEAT_COUNT:
		var angle := TAU * index / SEAT_COUNT
		var seat := Seat.new()
		add_child(seat)
		seat.position = Vector3(sin(angle), 0, cos(angle)) * SEAT_RADIUS
		seat.rotation.y = angle
		seat.build(index)
		seats.append(seat)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	hud = layer
	layer.name = "PrototypeHUD"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var title := Label.new()
	title.text = "LAST LETTER CLUB"
	title.position = Vector2(36, 24)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = NEUTRAL
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "LOKALE RUNDE  /  4 PLÄTZE · EINE TASTATUR"
	subtitle.position = Vector2(37, 59)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.modulate = Color("a3b4b6")
	root.add_child(subtitle)
	turn_label = Label.new()
	root.add_child(turn_label)
	turn_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	turn_label.offset_left = -460
	turn_label.offset_right = -36
	turn_label.offset_top = 28
	turn_label.offset_bottom = 64
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_label.add_theme_font_size_override("font_size", 22)
	rules_label = Label.new()
	root.add_child(rules_label)
	rules_label.position = Vector2(36, 96)
	rules_label.add_theme_font_size_override("font_size", 24)
	rules_label.add_theme_color_override("font_outline_color", Color("102027"))
	rules_label.add_theme_constant_override("outline_size", 6)
	hearts_label = Label.new()
	root.add_child(hearts_label)
	hearts_label.position = Vector2(36, 136)
	hearts_label.add_theme_font_size_override("font_size", 18)
	hearts_label.add_theme_color_override("font_outline_color", Color("102027"))
	hearts_label.add_theme_constant_override("outline_size", 6)
	countdown_label = Label.new()
	root.add_child(countdown_label)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.offset_left = -150
	countdown_label.offset_right = 150
	countdown_label.offset_top = -90
	countdown_label.offset_bottom = 10
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 72)
	countdown_label.add_theme_color_override("font_color", NEUTRAL)
	countdown_label.add_theme_color_override("font_outline_color", Color("102027"))
	countdown_label.add_theme_constant_override("outline_size", 8)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.hide()
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -194
	panel.offset_bottom = -24
	input_panel = StyleBoxFlat.new()
	input_panel.bg_color = Color("13242ef2")
	input_panel.set_border_width_all(1)
	input_panel.border_color = NEUTRAL
	input_panel.set_corner_radius_all(12)
	input_panel.content_margin_left = 24
	input_panel.content_margin_right = 24
	input_panel.content_margin_top = 16
	input_panel.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", input_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	column.add_child(status_label)
	word_input = LineEdit.new()
	word_input.name = "WordInput"
	word_input.placeholder_text = "Dein Wort …"
	word_input.max_length = RoundRules.Validator.MAX_WORD_LENGTH
	word_input.custom_minimum_size.y = 52
	word_input.add_theme_font_size_override("font_size", 30)
	word_input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	word_input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	word_input.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	word_input.context_menu_enabled = false
	# Godot otherwise exits edit mode after Enter, even when validation allows retries.
	word_input.keep_editing_on_text_submit = true
	word_input.text_changed.connect(_update_word)
	word_input.text_submitted.connect(func(_text: String): _submit())
	column.add_child(word_input)
	var hint := Label.new()
	hint.text = "ENTER  Wort prüfen    ·    ESC  Leeren\nTAB halten  Tischübersicht    ·    F5  Neue Runde nach Rundenende"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color("a3b4b6")
	column.add_child(hint)


func _input(event: InputEvent) -> void:
	if not table_enabled:
		return
	if not event is InputEventKey:
		return
	if event.keycode == KEY_TAB:
		overview = event.pressed
		_refresh_seats()
		_place_camera(orbit_angle)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5 and phase == Phase.FINISHED:
		enter_table(round_state.winner)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and phase == Phase.TYPING:
		word_input.clear()
		_update_word("")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not table_enabled:
		return
	# Releasing Tab outside the game must not leave the overview stuck on.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(camera):
		overview = false
		_refresh_seats()
		_place_camera(orbit_angle)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(word_input) and phase == Phase.TYPING:
		word_input.grab_focus()


func _update_word(text: String) -> void:
	seats[active_seat].word_label.text = text if not text.is_empty() else "…"
	# Keep long test words within the width of one seat's floating display.
	var text_width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	seats[active_seat].word_label.pixel_size = minf(0.004, 1.9 / maxf(1.0, text_width))
	if phase == Phase.TYPING and not feedback_active:
		_set_feedback(NEUTRAL, "DEIN ZUG  /  Englisches Wort mit %s" % round_state.required_prefix.to_upper())


func _set_feedback(color: Color, message: String) -> void:
	seats[active_seat].word_label.modulate = color
	word_input.add_theme_color_override("font_color", color)
	word_input.add_theme_color_override("font_uneditable_color", color)
	word_input.add_theme_color_override("font_selected_color", color)
	input_panel.border_color = color
	status_label.text = message
	status_label.modulate = color


func _submit() -> void:
	if not table_enabled or phase != Phase.TYPING:
		return
	var result := round_state.submit(word_input.text, Time.get_ticks_msec())
	if result != RoundRules.Verdict.IGNORED:
		_present_result(result)


func _present_result(result: int) -> void:
	var submitted_session := session_id
	feedback_id += 1
	var submitted_feedback := feedback_id
	feedback_active = true
	var accepted := result == RoundRules.Verdict.VALID
	var retry := result == RoundRules.Verdict.INVALID
	# Preserve the rejected word for red feedback. Lock briefly so delayed clearing
	# cannot erase a newly typed attempt. The round deadline continues independently.
	phase = Phase.FEEDBACK
	word_input.editable = false
	var message := "BESTÄTIGT  /  Nächste Vorgabe: %s" % round_state.required_prefix.to_upper()
	if not accepted:
		message = round_state.last_error
		if result == RoundRules.Verdict.ELIMINATED:
			message = "KEINE HERZEN  /  Platz %02d ausgeschieden" % (active_seat + 1)
		elif retry:
			message += "  (−1 Herz)"
	_set_feedback(SUCCESS if accepted else FAILURE,
		message)
	_update_round_hud()
	await get_tree().create_timer(feedback_seconds).timeout
	if not table_enabled or session_id != submitted_session or feedback_id != submitted_feedback:
		return
	feedback_active = false
	if retry or result == RoundRules.Verdict.ELIMINATED:
		word_input.clear()
		_update_word("")
	if retry:
		# Check the absolute deadline again before restoring input, even on a slow frame.
		if round_state.expire(Time.get_ticks_msec()):
			_present_result(RoundRules.Verdict.TIMEOUT)
			return
		phase = Phase.TYPING
		word_input.editable = true
		word_input.grab_focus()
		word_input.edit()
		_set_feedback(NEUTRAL, "DEIN ZUG  /  Zeit läuft weiter · Englisches Wort mit %s" % round_state.required_prefix.to_upper())
	elif round_state.finished:
		phase = Phase.FINISHED
		word_input.editable = false
		word_input.unedit()
		word_input.release_focus()
		_set_feedback(SUCCESS, "PLATZ %02d GEWINNT!  /  F5 für eine neue Runde" % (round_state.winner + 1))
		_refresh_seats()
		_update_round_hud()
	else:
		_move_to_next_seat()


func _move_to_next_seat() -> void:
	phase = Phase.MOVING
	var start_angle := orbit_angle
	departing_seat = active_seat
	active_seat = round_state.advance_player()
	var seat_steps := (active_seat - departing_seat + SEAT_COUNT) % SEAT_COUNT
	word_input.clear()
	_update_word("")
	_refresh_seats()
	_set_feedback(NEUTRAL, "PLATZWECHSEL …")
	motion = create_tween()
	motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(_place_camera, start_angle, start_angle + seat_steps * TAU / SEAT_COUNT, camera_move_seconds)
	motion.tween_callback(_finish_move)


func _finish_move() -> void:
	if not table_enabled:
		return
	orbit_angle = fposmod(orbit_angle, TAU)
	_place_camera(orbit_angle)
	phase = Phase.TYPING
	round_state.begin_turn(Time.get_ticks_msec())
	departing_seat = -1
	_refresh_seats()
	word_input.editable = true
	_update_word("")
	word_input.grab_focus()
	_update_round_hud()


func _place_camera(angle: float) -> void:
	orbit_angle = angle
	if overview:
		camera.fov = 58.0
		camera.position = Vector3(3.6, 3.8, 4.6)
		camera.look_at(to_global(Vector3(0, 0.8, 0)))
	else:
		camera.fov = 78.0
		camera.position = Vector3(sin(angle) * SEAT_RADIUS, EYE_HEIGHT, cos(angle) * SEAT_RADIUS)
		camera.look_at(to_global(Vector3(0, 0.95, 0)))


func _refresh_seats() -> void:
	for index in SEAT_COUNT:
		var eliminated := table_enabled and not round_state.alive[index]
		seats[index].set_active(table_enabled and index == active_seat and phase != Phase.FINISHED, not overview)
		if eliminated:
			seats[index].avatar.visible = false
			seats[index].ring_material.albedo_color = Color("50363c")
			seats[index].ring_material.emission = Color("50363c")
		if embedded_in_lobby and not table_enabled:
			seats[index].avatar.visible = false
		# Do not reveal the old placeholder while the camera is still inside it.
		if not overview and phase == Phase.MOVING and index == departing_seat:
			seats[index].avatar.visible = false
	turn_label.text = "PLATZ %02d / %02d  ·  DU BIST DRAN" % [active_seat + 1, SEAT_COUNT]


func _update_round_hud() -> void:
	if not table_enabled:
		return
	var heart_rows: PackedStringArray = []
	for index in SEAT_COUNT:
		var state := "♥".repeat(round_state.hearts[index]) + "♡".repeat(3 - round_state.hearts[index])
		if not round_state.alive[index]:
			state = "AUS"
		heart_rows.append("%02d  %s" % [index + 1, state])
	hearts_label.text = "    ·    ".join(heart_rows)
	if phase == Phase.COUNTDOWN:
		rules_label.text = "VORGABE NACH GO  ·  DANN 10 SEKUNDEN"
		rules_label.modulate = NEUTRAL
		turn_label.text = "PLATZ %02d  ·  BEREIT MACHEN" % (active_seat + 1)
	elif round_state.finished:
		rules_label.text = "RUNDE BEENDET  ·  PLATZ %02d GEWINNT" % (round_state.winner + 1)
		rules_label.modulate = SUCCESS
		turn_label.text = "GEWINNER: PLATZ %02d" % (round_state.winner + 1)
	else:
		var remaining := round_state.seconds_left(Time.get_ticks_msec())
		var clock_text := "%.1f s" % remaining if round_state.turn_running else "Nächster Zug: 10.0 s"
		rules_label.text = "VORGABE  %s    /    %s" % [round_state.required_prefix.to_upper(), clock_text]
		rules_label.modulate = FAILURE if round_state.turn_running and remaining <= 3.0 else NEUTRAL
		turn_label.text = "PLATZ %02d  ·  %s" % [active_seat + 1, "DU BIST DRAN" if round_state.turn_running else "PLATZWECHSEL"]
