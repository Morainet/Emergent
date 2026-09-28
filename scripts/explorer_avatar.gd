@tool
class_name ExplorerAvatar
extends Node3D

# Faces -Z; origin remains centred inside the gameplay capsule.
const EXPLORER_CANVAS = preload("res://assets/characters/explorer_canvas.png")
const ARI_CANVAS = preload("res://assets/characters/ari_canvas.png")
const SKIN := Color("d9ac87")
const HAIR := Color("292c30")
const LEATHER := Color("68503d")
const BOOTS := Color("3b3430")

@export_enum("Explorer", "Ari") var character := "Explorer"
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var head_pivot: Node3D
var pendant: MeshInstance3D
var pendant_base_scale := Vector3.ONE
var satchel: Node3D
var action_name := ""
var action_time := 0.0
var action_duration := 0.0
var was_grounded := true
var landing_time := 0.0


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func play_action(name: String, duration: float = 0.42) -> void:
	action_name = name
	action_duration = maxf(duration, 0.01)
	action_time = action_duration


func animate(walk_time: float, horizontal_speed: float, pulse: float, vertical_speed: float = 0.0, grounded: bool = true, delta: float = 0.016, step_phase: float = -1.0) -> void:
	var stride := clampf(horizontal_speed / 7.0, 0.0, 1.0)
	var cadence := step_phase if step_phase >= 0.0 else walk_time * 11.0
	var swing := sin(cadence) * 0.48 * stride
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_leg.position.y = -0.28 + maxf(0.0, sin(cadence)) * 0.075 * stride
	right_leg.position.y = -0.28 + maxf(0.0, -sin(cadence)) * 0.075 * stride
	left_arm.rotation.x = -swing * 0.65
	right_arm.rotation.x = swing * 0.65 - pulse * 1.4
	left_arm.rotation.z = -0.08 + sin(cadence) * 0.025 * stride
	right_arm.rotation.z = 0.08 + sin(cadence) * 0.025 * stride
	head_pivot.rotation.y = sin(walk_time * 0.85) * (0.22 if character == "Ari" else 0.15) * (1.0 - stride) + sin(cadence) * 0.035 * stride
	head_pivot.rotation.x = sin(walk_time * 1.7) * 0.025 * (1.0 - stride)
	if not grounded:
		left_leg.rotation.x = -0.25 if vertical_speed > 0.0 else 0.18
		right_leg.rotation.x = 0.35 if vertical_speed > 0.0 else -0.12
		left_arm.rotation.x = -0.42
		right_arm.rotation.x = -0.42 - pulse * 1.4
	if action_time > 0.0:
		var phase := 1.0 - action_time / action_duration
		var strength := sin(phase * PI)
		rotation.x = 0.0
		rotation.y = 0.0
		match action_name:
			"interact":
				right_arm.rotation.x -= 1.15 * strength
				rotation.x = 0.13 * strength
			"pulse":
				left_arm.rotation.x -= 0.65 * strength
				right_arm.rotation.x -= 1.5 * strength
				rotation.x = -0.12 * strength
			"hurt":
				left_arm.rotation.x += 0.7 * strength
				right_arm.rotation.x += 0.7 * strength
				rotation.x = -0.16 * strength
			"attack":
				right_arm.rotation.x -= 1.45 * strength
				right_arm.rotation.z += 0.32 * strength
				rotation.y = -0.20 * strength
			"dodge":
				left_arm.rotation.x += 0.55 * strength
				right_arm.rotation.x += 0.55 * strength
				rotation.x = 0.22 * strength
		action_time = maxf(0.0, action_time - delta)
	else:
		rotation.x = 0.0
		rotation.y = 0.0
	if grounded and not was_grounded:
		landing_time = 0.18
	was_grounded = grounded
	landing_time = maxf(0.0, landing_time - delta)
	var squash := sin(PI * landing_time / 0.18) * 0.06
	scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
	position.y = absf(sin(cadence)) * 0.035 * stride + sin(walk_time * 2.2) * 0.008 * (1.0 - stride)
	head_pivot.position.y = 0.45 + sin(walk_time * 2.2) * 0.006 * (1.0 - stride)
	satchel.rotation.z = sin(cadence) * 0.08 * stride
	satchel.rotation.x = -sin(cadence) * 0.055 * stride
	pendant.scale = pendant_base_scale * (1.0 + pulse * 0.65)
	pendant.rotation.z = PI / 4.0 + sin(cadence) * 0.055 * stride


func _build() -> void:
	var is_ari := character == "Ari"
	var coat := Color("956e4f") if is_ari else Color("397677")
	var coat_light := Color("bd936b") if is_ari else Color("579294")
	var shirt := Color("e0caa5") if is_ari else Color("cfc5aa")
	var accent := Color("ffda8a") if is_ari else Color("77eadf")
	var fabric: Texture2D = ARI_CANVAS if is_ari else EXPLORER_CANVAS
	var trousers := Color("4b5148") if is_ari else Color("46494a")

	# Tapered trousers, separate boot shafts and toes make the stride legible.
	left_leg = _pivot("LeftLeg", Vector3(-0.155, -0.28, 0.0))
	right_leg = _pivot("RightLeg", Vector3(0.155, -0.28, 0.0))
	for leg in [left_leg, right_leg]:
		_loft(leg, "Trouser", [Vector4(0.02, 0.125, 0.14, 0.0), Vector4(-0.21, 0.155, 0.16, 0.015), Vector4(-0.40, 0.12, 0.135, 0.0), Vector4(-0.50, 0.105, 0.115, 0.0)], trousers)
		_loft(leg, "BootShaft", [Vector4(-0.41, 0.125, 0.14, 0.0), Vector4(-0.55, 0.135, 0.14, 0.0), Vector4(-0.58, 0.12, 0.135, 0.0)], LEATHER)
		_ellipsoid(leg, "BootToe", Vector3(0.0, -0.58, -0.105), Vector3(0.16, 0.095, 0.25), BOOTS)
		_ellipsoid(leg, "BootSole", Vector3(0.0, -0.645, -0.095), Vector3(0.165, 0.035, 0.245), Color("27282a"))
		_loft(leg, "BootCuff", [Vector4(-0.43, 0.135, 0.15, 0.0), Vector4(-0.49, 0.14, 0.15, 0.0)], coat_light)

	# One textured sculpted body, layered with an open shirt, lapels and collar.
	_loft(self, "Coat", [Vector4(-0.39, 0.29, 0.19, 0.0), Vector4(-0.29, 0.315, 0.20, 0.0), Vector4(0.20, 0.35, 0.22, 0.0), Vector4(0.35, 0.24, 0.17, 0.0)], Color.WHITE, fabric)
	_loft(self, "Shirt", [Vector4(-0.31, 0.15, 0.025, -0.205), Vector4(0.21, 0.14, 0.025, -0.235), Vector4(0.32, 0.09, 0.025, -0.195)], shirt)
	for side in [-1.0, 1.0]:
		_polygon(self, "CoatLapel", [Vector3(side * 0.13, 0.33, -0.196), Vector3(side * 0.30, 0.29, -0.19), Vector3(side * 0.225, -0.24, -0.218), Vector3(side * 0.14, -0.30, -0.205)], coat_light)
		_polygon(self, "RaisedCollar", [Vector3(side * 0.12, 0.43, -0.135), Vector3(side * 0.30, 0.43, -0.095), Vector3(side * 0.30, 0.28, -0.16), Vector3(side * 0.13, 0.33, -0.20)], coat)
		_ellipsoid(self, "CoatButton", Vector3(side * 0.175, -0.16, -0.225), Vector3(0.014, 0.014, 0.008), LEATHER)
	_loft(self, "WaistBelt", [Vector4(-0.28, 0.315, 0.208, 0.0), Vector4(-0.34, 0.315, 0.208, 0.0)], LEATHER)
	_ellipsoid(self, "Buckle", Vector3(0.0, -0.31, -0.213), Vector3(0.05, 0.035, 0.018), Color("c7a86c"))
	for side in [-1.0, 1.0]:
		_polygon(self, "SplitCoatTail", [Vector3(side * 0.02, -0.34, 0.199), Vector3(side * 0.28, -0.34, 0.185), Vector3(side * 0.31, -0.59, 0.224), Vector3(side * 0.035, -0.57, 0.225)], coat)

	left_arm = _pivot("LeftArm", Vector3(-0.36, 0.285, 0.0))
	right_arm = _pivot("RightArm", Vector3(0.36, 0.285, 0.0))
	for arm in [left_arm, right_arm]:
		_loft(arm, "Sleeve", [Vector4(0.04, 0.16, 0.17, 0.0), Vector4(-0.20, 0.145, 0.15, 0.0), Vector4(-0.41, 0.115, 0.12, 0.0), Vector4(-0.48, 0.12, 0.12, 0.0)], Color.WHITE, fabric)
		_loft(arm, "RolledCuff", [Vector4(-0.43, 0.13, 0.13, 0.0), Vector4(-0.51, 0.12, 0.125, 0.0)], coat_light)
		_ellipsoid(arm, "Hand", Vector3(0.0, -0.60, 0.0), Vector3(0.085, 0.135, 0.085), SKIN)
		_ellipsoid(arm, "Thumb", Vector3(-0.075 if arm == left_arm else 0.075, -0.56, -0.045), Vector3(0.035, 0.07, 0.05), SKIN)
	if not is_ari:
		_loft(right_arm, "BladeGrip", [Vector4(-0.65, 0.043, 0.043, 0.0), Vector4(-0.74, 0.043, 0.043, 0.0)], LEATHER)
		_loft(right_arm, "BladeGuard", [Vector4(-0.73, 0.105, 0.045, 0.0), Vector4(-0.77, 0.105, 0.045, 0.0)], Color("c4a576"))
		var blade := _loft(right_arm, "SignalBlade", [Vector4(-0.75, 0.044, 0.035, 0.0), Vector4(-0.99, 0.06, 0.025, -0.025), Vector4(-1.10, 0.006, 0.006, -0.04)], accent)
		blade.material_override = _material(accent, null, true)

	head_pivot = _pivot("HeadPivot", Vector3(0.0, 0.45, 0.0))
	var head_geometry := Node3D.new()
	head_geometry.name = "HeadGeometry"
	head_geometry.position.y = -0.45
	head_pivot.add_child(head_geometry)
	_loft(head_geometry, "Neck", [Vector4(0.33, 0.105, 0.105, 0.0), Vector4(0.49, 0.09, 0.09, 0.0)], SKIN)
	_ellipsoid(head_geometry, "Head", Vector3(0.0, 0.655, -0.012), Vector3(0.215, 0.26, 0.205), SKIN)
	_ellipsoid(head_geometry, "Jaw", Vector3(0.0, 0.535, -0.065), Vector3(0.155, 0.105, 0.155), SKIN)
	for side in [-1.0, 1.0]:
		_ellipsoid(head_geometry, "Ear", Vector3(side * 0.218, 0.635, -0.015), Vector3(0.045, 0.075, 0.045), SKIN)
		_ellipsoid(head_geometry, "Eye", Vector3(side * 0.082, 0.682, -0.207), Vector3(0.018, 0.025, 0.009), Color("302b2a"))
		_ellipsoid(head_geometry, "Brow", Vector3(side * 0.085, 0.724, -0.209), Vector3(0.07, 0.012, 0.015), HAIR)
	_ellipsoid(head_geometry, "Nose", Vector3(0.0, 0.622, -0.216), Vector3(0.037, 0.067, 0.045), Color("c69070"))
	_ellipsoid(head_geometry, "Mouth", Vector3(0.0, 0.540, -0.199), Vector3(0.055, 0.009, 0.006), Color("895d58"))
	if is_ari:
		_loft(head_geometry, "Scarf", [Vector4(0.36, 0.165, 0.15, 0.0), Vector4(0.43, 0.15, 0.145, 0.0), Vector4(0.48, 0.11, 0.11, 0.0)], Color("58736c"))
		_ellipsoid(head_geometry, "Hair", Vector3(0.0, 0.805, 0.02), Vector3(0.225, 0.125, 0.21), Color("4c3630"))
		_ellipsoid(head_geometry, "CapCrown", Vector3(0.0, 0.845, 0.0), Vector3(0.255, 0.105, 0.22), coat)
		_ellipsoid(head_geometry, "CapBrim", Vector3(0.0, 0.785, -0.175), Vector3(0.24, 0.025, 0.145), coat_light)
	else:
		_ellipsoid(head_geometry, "HairBack", Vector3(0.0, 0.79, 0.075), Vector3(0.23, 0.16, 0.17), HAIR)
		_ellipsoid(head_geometry, "HairTop", Vector3(0.0, 0.84, 0.0), Vector3(0.24, 0.12, 0.205), HAIR)
		for tuft in [Vector3(-0.15, 0.785, -0.16), Vector3(-0.02, 0.81, -0.18), Vector3(0.13, 0.78, -0.16)]:
			_ellipsoid(head_geometry, "HairTuft", tuft, Vector3(0.095, 0.08, 0.09), HAIR)
		for x in [-0.14, 0.0, 0.14]:
			_polygon(head_geometry, "HairLock", [Vector3(x - 0.07, 0.80, 0.245), Vector3(x + 0.07, 0.80, 0.245), Vector3(x + 0.025, 0.60 + absf(x) * 0.28, 0.218)], Color("24282a"))

	var front_strap := _loft(self, "FrontStrap", [Vector4(-0.32, 0.042, 0.022, -0.238), Vector4(0.34, 0.042, 0.022, -0.200)], LEATHER)
	front_strap.rotation.z = -0.43
	var back_strap := _loft(self, "BackStrap", [Vector4(-0.32, 0.042, 0.022, 0.217), Vector4(0.34, 0.042, 0.022, 0.194)], LEATHER)
	back_strap.rotation.z = 0.43
	satchel = _pivot("Satchel", Vector3(0.31, -0.18, 0.20))
	_loft(satchel, "Bag", [Vector4(-0.20, 0.165, 0.105, 0.0), Vector4(0.12, 0.17, 0.11, 0.0)], LEATHER)
	_polygon(satchel, "BagFlap", [Vector3(-0.16, 0.12, 0.115), Vector3(0.16, 0.12, 0.115), Vector3(0.13, -0.035, 0.118), Vector3(-0.13, -0.035, 0.118)], coat_light)
	_ellipsoid(satchel, "BagClasp", Vector3(0.0, -0.02, 0.128), Vector3(0.035, 0.04, 0.015), Color("c7a86c"))
	pendant = _ellipsoid(self, "SignalPendant", Vector3(0.0, 0.245, -0.254), Vector3(0.055, 0.09, 0.035), accent, true)
	pendant_base_scale = pendant.scale
	pendant.rotation.z = PI / 4.0


func _pivot(label: String, offset: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = offset
	add_child(node)
	return node


func _material(color: Color, texture: Texture2D = null, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = texture
	material.roughness = 0.9
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	return material


func _ellipsoid(parent: Node3D, label: String, offset: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	part.mesh = mesh
	part.position = offset
	part.scale = size
	part.material_override = _material(color, null, glow)
	parent.add_child(part)
	return part


func _loft(parent: Node3D, label: String, rings: Array[Vector4], color: Color, texture: Texture2D = null) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	for ring_id in range(rings.size() - 1):
		for side in range(sides):
			var a := _ring_point(rings[ring_id], side, sides)
			var b := _ring_point(rings[ring_id], side + 1, sides)
			var c := _ring_point(rings[ring_id + 1], side, sides)
			var d := _ring_point(rings[ring_id + 1], side + 1, sides)
			var u := float(side) / sides
			var u_next := float(side + 1) / sides
			var v := float(ring_id) / (rings.size() - 1)
			var v_next := float(ring_id + 1) / (rings.size() - 1)
			if rings[ring_id + 1].x > rings[ring_id].x:
				_triangle(surface, a, b, c, Vector2(u, v), Vector2(u_next, v), Vector2(u, v_next))
				_triangle(surface, b, d, c, Vector2(u_next, v), Vector2(u_next, v_next), Vector2(u, v_next))
			else:
				_triangle(surface, a, c, b, Vector2(u, v), Vector2(u, v_next), Vector2(u_next, v))
				_triangle(surface, b, c, d, Vector2(u_next, v), Vector2(u, v_next), Vector2(u_next, v_next))
	surface.generate_normals()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	part.material_override = _material(color, texture)
	parent.add_child(part)
	return part


func _ring_point(ring: Vector4, side: int, sides: int) -> Vector3:
	var angle := TAU * float(side) / sides
	return Vector3(cos(angle) * ring.y, ring.x, sin(angle) * ring.z + ring.w)


func _polygon(parent: Node3D, label: String, points: Array[Vector3], color: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size() - 1):
		_triangle(surface, points[0], points[i], points[i + 1], Vector2.ZERO, Vector2.ONE, Vector2(1.0, 0.0))
	surface.generate_normals()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	var material := _material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	part.material_override = material
	parent.add_child(part)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)
