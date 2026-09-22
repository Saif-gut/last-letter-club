extends Node3D
## Simple seated placeholder. The word belongs to this seat in world space.

const IDLE_COLOR := Color("617982")
const ACTIVE_COLOR := Color("f0ce8b")

var avatar: Node3D
var word_label: Label3D
var ring_material: StandardMaterial3D


func build(index: int) -> void:
	name = "Seat%d" % (index + 1)
	var chair_material := material(Color("263940"))
	box(self, Vector3(0.65, 0.12, 0.65), Vector3(0, 0.46, 0), chair_material)
	box(self, Vector3(0.65, 0.75, 0.1), Vector3(0, 0.88, 0.32), chair_material)
	for x in [-0.24, 0.24]:
		for z in [-0.24, 0.24]:
			box(self, Vector3(0.06, 0.45, 0.06), Vector3(x, 0.225, z), chair_material)
	avatar = Node3D.new()
	avatar.name = "Placeholder"
	add_child(avatar)
	var body_material := material(Color("819b9b"))
	box(avatar, Vector3(0.38, 0.48, 0.25), Vector3(0, 0.79, 0.08), body_material)
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	mesh(avatar, head, Vector3(0, 1.22, 0.08), body_material)
	ring_material = material(IDLE_COLOR)
	ring_material.emission_enabled = true
	ring_material.emission = IDLE_COLOR
	ring_material.emission_energy_multiplier = 0.35
	var ring := TorusMesh.new()
	ring.inner_radius = 0.39
	ring.outer_radius = 0.43
	mesh(self, ring, Vector3(0, 0.025, 0), ring_material)
	var seat_label := Label3D.new()
	seat_label.text = "%02d" % (index + 1)
	seat_label.position = Vector3(0, 1.58, 0)
	seat_label.font_size = 40
	seat_label.pixel_size = 0.003
	seat_label.modulate = Color("9bafad")
	seat_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(seat_label)
	word_label = Label3D.new()
	word_label.name = "FloatingWord"
	word_label.position = Vector3(0, 1.98, 0)
	word_label.font_size = 64
	word_label.pixel_size = 0.004
	word_label.outline_size = 12
	word_label.outline_modulate = Color("102027")
	word_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(word_label)


func set_active(active: bool, first_person: bool) -> void:
	word_label.visible = active
	avatar.visible = not (active and first_person)
	ring_material.albedo_color = ACTIVE_COLOR if active else IDLE_COLOR
	ring_material.emission = ring_material.albedo_color


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = surface
	instance.position = at
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, size: Vector3, at: Vector3, surface: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, surface)
