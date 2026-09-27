class_name ExplorerAvatar
extends Node3D

const JACKET := Color("2e716d")
const JACKET_LIGHT := Color("408783")
const SHIRT := Color("c9bda2")
const SKIN := Color("d8a980")
const HAIR := Color("292a2a")
const TROUSERS := Color("3f403c")
const LEATHER := Color("725842")
const BOOTS := Color("473b34")
const SIGNAL := Color("79ecdf")
const EXPLORER_CANVAS = preload("res://assets/characters/explorer_canvas.png")
const ARI_CANVAS = preload("res://assets/characters/ari_canvas.png")

var jacket_color := JACKET
var jacket_light_color := JACKET_LIGHT
var signal_color := SIGNAL
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var pendant: MeshInstance3D
var satchel: Node3D
var action_name := ""
var action_time := 0.0
var action_duration := 0.0
var was_grounded := true
var landing_time := 0.0


func _ready() -> void:
	_build()


func play_action(name: String, duration: float = 0.42) -> void:
	action_name = name
	action_duration = duration
	action_time = duration


func animate(walk_time: float, horizontal_speed: float, pulse: float, vertical_speed: float = 0.0, grounded: bool = true, delta: float = 0.016, step_phase: float = -1.0) -> void:
	var stride := clampf(horizontal_speed / 7.0, 0.0, 1.0)
	var cadence := step_phase if step_phase >= 0.0 else walk_time * 11.0
	var swing := sin(cadence) * 0.48 * stride
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.65
	right_arm.rotation.x = swing * 0.65 - pulse * 1.4
	if not grounded:
		left_leg.rotation.x = -0.25 if vertical_speed > 0.0 else 0.18
		right_leg.rotation.x = 0.35 if vertical_speed > 0.0 else -0.12
		left_arm.rotation.x = -0.42
		right_arm.rotation.x = -0.42 - pulse * 1.4
	if action_time > 0.0:
		var phase := 1.0 - action_time / action_duration
		var strength := sin(phase * PI)
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
		action_time = maxf(0.0, action_time - delta)
	else:
		rotation.x = 0.0
	if grounded and not was_grounded:
		landing_time = 0.18
	was_grounded = grounded
	landing_time = maxf(0.0, landing_time - delta)
	var squash := sin(PI * landing_time / 0.18) * 0.06
	scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
	position.y = absf(sin(cadence)) * 0.035 * stride + sin(walk_time * 2.2) * 0.008 * (1.0 - stride)
	satchel.rotation.z = sin(cadence) * 0.08 * stride
	pendant.scale = Vector3.ONE * (1.0 + pulse * 0.65)


func _build() -> void:
	# CharacterBody3D origin is at the center of its 1.8 m collision capsule.
	left_leg = _limb("LeftLeg", Vector3(-0.17, -0.28, 0.0))
	right_leg = _limb("RightLeg", Vector3(0.17, -0.28, 0.0))
	for leg in [left_leg, right_leg]:
		_box(leg, Vector3(0.28, 0.56, 0.30), Vector3(0.0, -0.20, 0.0), TROUSERS)
		_box(leg, Vector3(0.31, 0.23, 0.35), Vector3(0.0, -0.42, 0.0), LEATHER)
		_box(leg, Vector3(0.34, 0.16, 0.48), Vector3(0.0, -0.53, -0.06), BOOTS)

	var canvas: Texture2D = EXPLORER_CANVAS if jacket_color == JACKET else ARI_CANVAS
	_box(self, Vector3(0.67, 0.69, 0.38), Vector3(0.0, 0.03, 0.0), Color.WHITE, false, canvas)
	_box(self, Vector3(0.30, 0.48, 0.025), Vector3(0.0, 0.08, -0.205), SHIRT)
	_box(self, Vector3(0.16, 0.52, 0.04), Vector3(-0.23, 0.07, -0.22), jacket_light_color)
	_box(self, Vector3(0.16, 0.52, 0.04), Vector3(0.23, 0.07, -0.22), jacket_light_color)
	_box(self, Vector3(0.73, 0.10, 0.42), Vector3(0.0, -0.30, 0.0), LEATHER)
	_box(self, Vector3(0.09, 0.12, 0.035), Vector3(0.0, -0.30, -0.23), Color("bdab78"))

	left_arm = _limb("LeftArm", Vector3(-0.42, 0.29, 0.0))
	right_arm = _limb("RightArm", Vector3(0.42, 0.29, 0.0))
	for arm in [left_arm, right_arm]:
		_box(arm, Vector3(0.25, 0.45, 0.29), Vector3(0.0, -0.23, 0.0), Color.WHITE, false, canvas)
		_box(arm, Vector3(0.23, 0.10, 0.30), Vector3(0.0, -0.47, 0.0), jacket_color)
		_box(arm, Vector3(0.16, 0.18, 0.19), Vector3(0.0, -0.60, 0.0), SKIN)

	_box(self, Vector3(0.18, 0.16, 0.17), Vector3(0.0, 0.40, 0.0), SKIN)
	_sphere(self, 0.29, Vector3(0.0, 0.66, 0.0), SKIN)
	_box(self, Vector3(0.61, 0.18, 0.49), Vector3(0.0, 0.88, 0.015), HAIR)
	_box(self, Vector3(0.22, 0.14, 0.25), Vector3(-0.19, 0.83, -0.22), HAIR)
	_box(self, Vector3(0.22, 0.14, 0.25), Vector3(0.19, 0.83, -0.22), HAIR)
	_box(self, Vector3(0.10, 0.18, 0.18), Vector3(-0.29, 0.68, 0.01), HAIR)
	_box(self, Vector3(0.10, 0.18, 0.18), Vector3(0.29, 0.68, 0.01), HAIR)
	for x in [-0.11, 0.11]:
		_box(self, Vector3(0.055, 0.045, 0.02), Vector3(x, 0.69, -0.286), HAIR)

	# Readable from the third-person camera as well as the front.
	var front_strap := _box(self, Vector3(0.085, 0.74, 0.04), Vector3(0.0, 0.05, -0.245), LEATHER)
	front_strap.rotation.z = -0.50
	var back_strap := _box(self, Vector3(0.085, 0.74, 0.04), Vector3(0.0, 0.05, 0.225), LEATHER)
	back_strap.rotation.z = 0.50
	satchel = _limb("Satchel", Vector3(0.35, -0.18, 0.21))
	_box(satchel, Vector3(0.38, 0.32, 0.19), Vector3.ZERO, LEATHER)
	_box(satchel, Vector3(0.36, 0.07, 0.21), Vector3(0.0, 0.15, 0.0), Color("8b6c50"))
	pendant = _box(self, Vector3(0.11, 0.16, 0.06), Vector3(0.0, 0.25, -0.28), signal_color, true)
	pendant.rotation.z = PI / 4.0


func _limb(label: String, offset: Vector3) -> Node3D:
	var limb := Node3D.new()
	limb.name = label
	limb.position = offset
	add_child(limb)
	return limb


func _box(parent: Node3D, size: Vector3, offset: Vector3, color: Color, glow: bool = false, texture: Texture2D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if texture != null:
		material.albedo_texture = texture
	material.roughness = 0.9
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, radius: float, offset: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
