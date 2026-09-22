extends CharacterBody3D
## Existing movement controller; the historical filename is kept for scene compatibility.
## Walking is entirely disabled while the separate table camera owns the view.

@export var move_speed := 3.8
@export var jump_speed := 4.5
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity := 0.002

@export var camera_distance := 3.2
@export var camera_follow_speed := 18.0
@export var camera_look_speed := 24.0

@onready var camera_arm: SpringArm3D = $CameraArm
@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var avatar: Node3D = $Placeholder

var look_pitch := deg_to_rad(-12.0)

var walking_enabled := false
var mouse_released := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	camera_arm.add_excluded_object(get_rid())
	camera_arm.spring_length = camera_distance
	reset_camera()
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)


func set_walking(enabled: bool) -> void:
	walking_enabled = enabled
	avatar.visible = enabled
	velocity = Vector3.ZERO
	collision_layer = 1 if enabled else 0
	collision_mask = 1 if enabled else 0
	if enabled:
		reset_camera()
		camera.make_current()
		mouse_released = false
		# The editor may still be embedding the game window during _ready().
		_start_mouse_capture.call_deferred()
	else:
		camera.clear_current(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _start_mouse_capture() -> void:
	if walking_enabled and not mouse_released:
		get_window().grab_focus()
		_capture_mouse()


func _capture_mouse() -> void:
	if walking_enabled and not mouse_released and get_window().has_focus():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not walking_enabled:
		return
	# A retracted camera must not be blocked by the local placeholder's head.
	var fade := 1.0 - smoothstep(0.35, 1.5, camera_arm.get_hit_length())
	for part: MeshInstance3D in avatar.get_children():
		part.transparency = lerpf(part.transparency, fade, 1.0 - exp(-24.0 * delta))


func _physics_process(delta: float) -> void:
	if not walking_enabled:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	var direction := Vector2.ZERO
	# A cursor mode change alone must not silently disable keyboard movement.
	if not mouse_released and get_window().has_focus():
		direction = Input.get_vector("lobby_left", "lobby_right", "lobby_forward", "lobby_back")
		if Input.is_action_just_pressed("lobby_jump") and is_on_floor():
			velocity.y = jump_speed
	var motion := basis * Vector3(direction.x, 0, direction.y)
	velocity.x = motion.x * move_speed
	velocity.z = motion.z * move_speed
	move_and_slide()
	var target := global_position + global_basis * Vector3(0.22, 1.5, 0)
	camera_arm.global_position = camera_arm.global_position.lerp(target, 1.0 - exp(-camera_follow_speed * delta))
	var look_weight := 1.0 - exp(-camera_look_speed * delta)
	camera_arm.rotation.x = lerp_angle(camera_arm.rotation.x, look_pitch, look_weight)
	camera_arm.rotation.y = lerp_angle(camera_arm.rotation.y, global_rotation.y, look_weight)


func reset_camera() -> void:
	camera_arm.global_position = global_position + global_basis * Vector3(0.22, 1.5, 0)
	camera_arm.global_rotation = Vector3(look_pitch, global_rotation.y, 0)
	reset_physics_interpolation()
	camera_arm.reset_physics_interpolation()


func _unhandled_input(event: InputEvent) -> void:
	if not walking_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		mouse_released = not mouse_released
		if mouse_released:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			velocity.x = 0
			velocity.z = 0
		else:
			_capture_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not mouse_released and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.screen_relative.x * mouse_sensitivity)
		look_pitch = clampf(look_pitch - event.screen_relative.y * mouse_sensitivity,
			deg_to_rad(-60), deg_to_rad(55))


func _on_window_focus_exited() -> void:
	if walking_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		velocity = Vector3.ZERO


func _on_window_focus_entered() -> void:
	if walking_enabled:
		mouse_released = false
		_capture_mouse.call_deferred()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
