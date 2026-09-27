class_name WolfAvatar
extends Node3D

const FUR := Color("66757a")
const FUR_LIGHT := Color("8a9694")
const FUR_DARK := Color("4a5a5e")

var eyes: Array[MeshInstance3D] = []
var mood_marker: MeshInstance3D
var head: Node3D
var tail: Node3D
var legs: Array[Node3D] = []
var gait_phase := 0.0
var attack_time := 0.0


func _ready() -> void:
	_build()


func play_attack() -> void:
	attack_time = 0.38


func reset_pose() -> void:
	attack_time = 0.0
	gait_phase = 0.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	tail.rotation = Vector3.ZERO
	for leg in legs:
		leg.rotation = Vector3.ZERO


func animate(horizontal_speed: float, action: String, stunned: bool, delta: float) -> void:
	var pace := clampf(horizontal_speed / 4.8, 0.0, 1.0)
	gait_phase += horizontal_speed * delta * 3.0
	var step := sin(gait_phase) * 0.48 * pace
	for i in legs.size():
		legs[i].rotation.x = step if i == 0 or i == 3 else -step
	var bob := absf(sin(gait_phase)) * 0.045 * pace
	position.y = bob
	position.z = 0.0
	rotation.z = 0.0
	var neck_target := -0.08 if action == "hunt" else 0.10 if action == "observe" else 0.04
	if stunned:
		neck_target = 0.24
		rotation.z = 0.12
		for leg in legs:
			leg.rotation.x *= 0.18
	if attack_time > 0.0:
		var phase := 1.0 - attack_time / 0.38
		var lunge := sin(phase * PI)
		position.z = -0.38 * lunge
		position.y += 0.10 * lunge
		neck_target = -0.30 * lunge
		attack_time = maxf(0.0, attack_time - delta)
	head.rotation.x = lerpf(head.rotation.x, neck_target, 1.0 - exp(-delta * 12.0))
	tail.rotation.y = sin(gait_phase * 0.5) * (0.14 + pace * 0.18)
	tail.rotation.x = -0.14 if action == "hunt" else 0.17


func _build() -> void:
	var body := _ellipsoid(self, Vector3(0.52, 0.40, 0.78), Vector3(0.0, 0.06, 0.12), FUR)
	body.name = "Body"
	_ellipsoid(self, Vector3(0.40, 0.30, 0.48), Vector3(0.0, 0.23, -0.37), FUR_LIGHT)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.31, -0.70)
	add_child(head)
	_ellipsoid(head, Vector3(0.37, 0.30, 0.37), Vector3.ZERO, FUR_LIGHT)
	var muzzle := _box(head, Vector3(0.43, 0.22, 0.48), Vector3(0.0, -0.11, -0.38), Color("9aa29d"))
	muzzle.rotation.x = -0.08
	_box(head, Vector3(0.22, 0.12, 0.10), Vector3(0.0, -0.11, -0.66), FUR_DARK)
	for side in [-1.0, 1.0]:
		var ear := _cone(head, 0.17, 0.41, Vector3(side * 0.25, 0.40, 0.03), FUR_DARK)
		ear.rotation.z = -side * 0.18
		eyes.append(_box(head, Vector3(0.16, 0.12, 0.08), Vector3(side * 0.20, 0.10, -0.31), Color("d6b982"), true))
	for z in [-0.47, 0.53]:
		for x in [-0.36, 0.36]:
			var leg := Node3D.new()
			leg.name = ("Front" if z < 0.0 else "Rear") + ("LeftLeg" if x < 0.0 else "RightLeg")
			leg.position = Vector3(x, -0.17, z)
			add_child(leg)
			_box(leg, Vector3(0.23, 0.47, 0.25), Vector3(0.0, -0.22, 0.0), FUR_DARK)
			_box(leg, Vector3(0.29, 0.12, 0.37), Vector3(0.0, -0.47, -0.07), Color("59676a"))
			legs.append(leg)
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.26, 0.78)
	add_child(tail)
	var tail_base := _cone(tail, 0.22, 0.80, Vector3(0.0, 0.14, 0.28), FUR_DARK)
	tail_base.rotation.x = 1.14
	mood_marker = _box(self, Vector3(0.22, 0.22, 0.22), Vector3(0.0, 1.18, 0.0), Color("d6b982"), true)
	mood_marker.rotation.z = PI / 4.0


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.93
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material


func _box(parent: Node3D, size: Vector3, offset: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(color, glow)
	instance.position = offset
	parent.add_child(instance)
	return instance


func _ellipsoid(parent: Node3D, dimensions: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	instance.mesh = mesh
	instance.scale = dimensions
	instance.material_override = _material(color)
	instance.position = offset
	parent.add_child(instance)
	return instance


func _cone(parent: Node3D, radius: float, height: float, offset: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = 0.0
	mesh.height = height
	mesh.radial_segments = 7
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = offset
	parent.add_child(instance)
	return instance
