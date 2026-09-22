extends Node3D
## Presentation only: no CharacterBody controller, input callbacks or Camera3D.

var target_position := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var look_marker: Node3D
var initialized := false
var last_pose: Dictionary = {}


func build(template: Node3D, peer_id: int) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var body := template.duplicate() as Node3D
	body.visible = true
	add_child(body)
	for part: MeshInstance3D in body.get_children():
		part.transparency = 0.0
	look_marker = Node3D.new()
	look_marker.position.y = 1.53
	add_child(look_marker)
	# Minimal direction marker on a symmetric placeholder; not a final character.
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.32)
	marker.mesh = box
	marker.position.z = -0.28
	marker.material_override = template.get_child(0).material_override
	look_marker.add_child(marker)
	var label := Label3D.new()
	label.text = "HOST" if peer_id == 1 else "SPIELER %d" % peer_id
	label.position.y = 2.0
	label.font_size = 26
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func receive(pose: Dictionary) -> void:
	last_pose = pose
	target_position = pose.position
	target_yaw = pose.yaw
	target_pitch = pose.pitch
	if not initialized:
		global_position = target_position
		rotation.y = target_yaw
		look_marker.rotation.x = target_pitch
		initialized = true


func _process(delta: float) -> void:
	if not initialized:
		return
	var weight := 1.0 - exp(-15.0 * delta)
	global_position = global_position.lerp(target_position, weight)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	look_marker.rotation.x = lerp_angle(look_marker.rotation.x, target_pitch, weight)
