@tool
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
var hurt_time := 0.0


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func play_attack() -> void:
	attack_time = 0.38


func play_hurt() -> void:
	hurt_time = 0.25


func reset_pose() -> void:
	attack_time = 0.0
	hurt_time = 0.0
	gait_phase = 0.0
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	tail.rotation = Vector3.ZERO
	mood_marker.scale = Vector3.ONE
	for leg in legs:
		leg.rotation = Vector3.ZERO


func animate(horizontal_speed: float, action: String, stunned: bool, delta: float, winding_up: bool = false) -> void:
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
	mood_marker.scale = Vector3.ONE * (1.35 if winding_up else 1.0)
	if winding_up:
		neck_target = -0.26
		rotation.x = -0.10
	else:
		rotation.x = 0.0
	if stunned:
		neck_target = 0.24
		rotation.z = 0.12
		for leg in legs:
			leg.rotation.x *= 0.18
	if hurt_time > 0.0:
		rotation.z = 0.20 * sin(PI * hurt_time / 0.25)
		neck_target = 0.22
		hurt_time = maxf(0.0, hurt_time - delta)
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
	_loft(self, "Body", [
		Vector4(-0.76, 0.24, 0.27, 0.16), Vector4(-0.52, 0.42, 0.39, 0.14),
		Vector4(-0.10, 0.52, 0.41, 0.09), Vector4(0.44, 0.44, 0.35, 0.06),
		Vector4(0.83, 0.23, 0.25, 0.09)
	], true, FUR)
	_loft(self, "ChestAndNeck", [
		Vector4(-0.85, 0.25, 0.25, 0.26), Vector4(-0.61, 0.34, 0.34, 0.23),
		Vector4(-0.29, 0.39, 0.37, 0.16)
	], true, FUR_LIGHT)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.31, -0.70)
	add_child(head)
	_loft(head, "Skull", [
		Vector4(-0.42, 0.20, 0.19, -0.05), Vector4(-0.23, 0.32, 0.27, 0.01),
		Vector4(0.03, 0.37, 0.29, 0.02), Vector4(0.27, 0.23, 0.20, 0.02)
	], true, FUR_LIGHT)
	_loft(head, "Muzzle", [
		Vector4(-0.73, 0.11, 0.09, -0.15), Vector4(-0.59, 0.16, 0.12, -0.14),
		Vector4(-0.37, 0.22, 0.16, -0.10), Vector4(-0.26, 0.23, 0.15, -0.09)
	], true, Color("a0a7a0"))
	_ellipsoid(head, "Nose", Vector3(0.12, 0.08, 0.07), Vector3(0.0, -0.15, -0.74), FUR_DARK)
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "LeftEar" if side < 0.0 else "RightEar"
		ear.position = Vector3(side * 0.25, 0.22, 0.07)
		ear.rotation.z = -side * 0.16
		head.add_child(ear)
		_loft(ear, "Ear", [
			Vector4(0.0, 0.16, 0.13, 0.0), Vector4(0.20, 0.12, 0.09, 0.01),
			Vector4(0.46, 0.012, 0.025, 0.025)
		], false, FUR_DARK)
		eyes.append(_ellipsoid(head, "Eye", Vector3(0.075, 0.065, 0.045), Vector3(side * 0.205, 0.09, -0.31), Color("d6b982"), true))
	for z in [-0.47, 0.53]:
		for x in [-0.36, 0.36]:
			var leg := Node3D.new()
			leg.name = ("Front" if z < 0.0 else "Rear") + ("LeftLeg" if x < 0.0 else "RightLeg")
			leg.position = Vector3(x, -0.17, z)
			add_child(leg)
			var leg_rings := [
				Vector4(0.06, 0.16, 0.20, 0.0), Vector4(-0.20, 0.13, 0.15, 0.06 if z > 0.0 else -0.02),
				Vector4(-0.42, 0.10, 0.11, -0.02), Vector4(-0.51, 0.12, 0.17, -0.07)
			]
			_loft(leg, "LegAndPaw", leg_rings, false, FUR_DARK)
			legs.append(leg)
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.26, 0.78)
	add_child(tail)
	_loft(tail, "TailFur", [
		Vector4(0.0, 0.19, 0.17, 0.0), Vector4(0.22, 0.22, 0.20, 0.08),
		Vector4(0.48, 0.15, 0.16, 0.18), Vector4(0.76, 0.025, 0.04, 0.27)
	], true, FUR_DARK)
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


func _ellipsoid(parent: Node3D, label: String, dimensions: Vector3, offset: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	instance.mesh = mesh
	instance.scale = dimensions
	instance.material_override = _material(color, glow)
	instance.position = offset
	parent.add_child(instance)
	return instance


func _loft(parent: Node3D, label: String, rings: Array, along_z: bool, color: Color) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 10
	for ring in range(rings.size() - 1):
		for side in sides:
			var a := _ring_point(rings[ring], side, sides, along_z)
			var b := _ring_point(rings[ring], side + 1, sides, along_z)
			var c := _ring_point(rings[ring + 1], side, sides, along_z)
			var d := _ring_point(rings[ring + 1], side + 1, sides, along_z)
			_face(tool, a, c, b)
			_face(tool, b, c, d)
	var first: Vector4 = rings[0]
	var last: Vector4 = rings[rings.size() - 1]
	var first_center := Vector3(0.0, first.w, first.x) if along_z else Vector3(0.0, first.x, first.w)
	var last_center := Vector3(0.0, last.w, last.x) if along_z else Vector3(0.0, last.x, last.w)
	for side in sides:
		_face(tool, first_center, _ring_point(first, side + 1, sides, along_z), _ring_point(first, side, sides, along_z))
		_face(tool, last_center, _ring_point(last, side, sides, along_z), _ring_point(last, side + 1, sides, along_z))
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = tool.commit()
	var material := _material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _ring_point(ring: Vector4, side: int, sides: int, along_z: bool) -> Vector3:
	var angle := TAU * float(side % sides) / float(sides)
	if along_z:
		return Vector3(cos(angle) * ring.y, ring.w + sin(angle) * ring.z, ring.x)
	return Vector3(cos(angle) * ring.y, ring.x, ring.w + sin(angle) * ring.z)


func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
