extends Node3D

const CAMP = Vector3(0.0, 0.0, 0.0)
const AI_URL = "http://127.0.0.1:8765/decide"
const WOLF_ACTIONS = ["hunt", "observe", "retreat", "roam"]
const MAP_EDGE = 29.0
const MOUSE_SENSITIVITY = 0.003
const CAMERA_DISTANCE = 10.5
const FOREST_FLOOR_TEXTURE = preload("res://assets/textures/forest_floor.png")
const RUIN_STONE_TEXTURE = preload("res://assets/textures/ruin_stone.png")
const SIGNAL_SHARD_ICON = preload("res://assets/ui/signal_shard.png")

var player: CharacterBody3D
var player_visual: ExplorerAvatar
var pulse_ring: MeshInstance3D
var pulse_ring_material: StandardMaterial3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := 0.53
var mouse_captured := false
var sun: DirectionalLight3D
var environment: Environment
var fire_light: OmniLight3D
var ai_http: HTTPRequest
var wolves: Array[Dictionary] = []
var shards: Array[Dictionary] = []
var berries: Array[Dictionary] = []
var player_hp := 100.0
var supplies := 0
var ward_built := false
var collected := 0
var elapsed := 0.0
var pulse_cooldown := 0.0
var pulse_visual := 0.0
var scan_time := 0.0
var ai_timer := 0.0
var ai_busy := false
var use_laya := false
var pack_action := "roam"
var pack_source := "local"
var pack_hunger := 38.0
var pack_fear := 0.0
var show_debug := false
var game_over := false
var victory := false
var was_night := false
var message := "Find three signal stones. Watch how the wolves react."
var message_time := 7.0
var title_label: Label
var stats_label: Label
var objective_label: Label
var interaction_label: Label
var message_label: Label
var debug_label: Label
var end_label: Label
var pulse_label: Label
var pulse_fill: ColorRect
var scan_panel: ColorRect
var scan_label: Label
var shard_icons: Array[TextureRect] = []


func _ready() -> void:
	_build_world()
	_build_ui()
	ai_http = HTTPRequest.new()
	ai_http.timeout = 2.0
	add_child(ai_http)
	ai_http.request_completed.connect(_on_ai_response)
	_capture_mouse()
	_update_ui()


func _exit_tree() -> void:
	_release_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mouse()


func _capture_mouse() -> void:
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _apply_mouse_look(relative: Vector2) -> void:
	camera_yaw -= relative.x * MOUSE_SENSITIVITY
	camera_pitch = clampf(camera_pitch - relative.y * MOUSE_SENSITIVITY, 0.18, 1.12)


func _physics_process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	pack_hunger = minf(100.0, pack_hunger + delta * 0.34)
	pack_fear = maxf(0.0, pack_fear - delta * 0.7)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	pulse_visual = maxf(0.0, pulse_visual - delta)
	scan_time = maxf(0.0, scan_time - delta)
	message_time = maxf(0.0, message_time - delta)
	if _is_night() and not was_night:
		_new_night()
	was_night = _is_night()
	_update_daylight(delta)
	_move_player(delta)
	player_visual.animate(elapsed, Vector2(player.velocity.x, player.velocity.z).length(), pulse_visual / 0.4)
	_update_pulse_effect()
	_update_wolves(delta)
	_animate_collectibles(delta)
	_update_camera(delta)
	ai_timer -= delta
	if ai_timer <= 0.0:
		ai_timer = 2.5
		_decide_pack()
	if player_hp <= 0.0:
		game_over = true
		message = "The forest fell silent."
		_release_mouse()
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured and not game_over:
		var motion := event as InputEventMouseMotion
		_apply_mouse_look(motion.relative)
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if not mouse_captured:
			if button.button_index == MOUSE_BUTTON_LEFT and not game_over:
				_capture_mouse()
				_update_ui()
			return
		if not game_over:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_pulse()
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				_interact()
			_update_ui()
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		_release_mouse()
		_update_ui()
		return
	if game_over:
		if key.keycode == KEY_R:
			get_tree().reload_current_scene()
		return
	match key.keycode:
		KEY_E: _interact()
		KEY_Q: _pulse()
		KEY_B: _build_ward()
		KEY_F1: show_debug = not show_debug
		KEY_L:
			use_laya = not use_laya
			_say("Laya decisions enabled." if use_laya else "Local wolf decisions enabled.")
	_update_ui()


func _build_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8daeb0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bcd3c6")
	environment.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -32.0, 0.0)
	sun.light_color = Color("ffe4af")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	_make_ground()
	_make_forest()
	_make_ruins()
	_make_camp()
	_make_collectibles()
	_make_player()
	_make_wolves()
	camera = Camera3D.new()
	camera.fov = 69.0
	camera.current = true
	camera.position = Vector3(0.0, 7.0, 12.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.8, 0.0))


func _make_ground() -> void:
	var ground := StaticBody3D.new()
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_child(ground)
	var surface := _box(ground, Vector3(64.0, 1.0, 64.0), Vector3.ZERO, Color.WHITE)
	surface.material_override = _textured_material(FOREST_FLOOR_TEXTURE, Vector3(8.0, 8.0, 1.0))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(64.0, 1.0, 64.0)
	shape.shape = box
	ground.add_child(shape)
	for i in 42:
		var x := -29.0 + float((i * 17) % 58)
		var z := -29.0 + float((i * 31) % 58)
		if Vector2(x, z).length() < 7.0:
			continue
		_box(self, Vector3(0.6 + float(i % 3), 0.02, 0.5 + float(i % 4)), Vector3(x, 0.02, z), Color("3d604b") if i % 2 == 0 else Color("385b4a"))
	for i in 19:
		var angle := float(i) * TAU / 19.0
		var p := Vector3(cos(angle) * 30.0, 1.1, sin(angle) * 30.0)
		_box(self, Vector3(3.0, 2.2, 1.0), p, Color("425b58"))


func _make_forest() -> void:
	var positions := [
		Vector2(-25, -24), Vector2(-21, -12), Vector2(-25, 4), Vector2(-24, 20),
		Vector2(-16, 24), Vector2(-13, 11), Vector2(-12, -21), Vector2(-7, -12),
		Vector2(-4, 25), Vector2(4, -24), Vector2(9, -14), Vector2(14, 23),
		Vector2(20, -26), Vector2(25, -10), Vector2(24, 5), Vector2(26, 23),
		Vector2(11, 12), Vector2(-20, -2), Vector2(18, 9), Vector2(-9, 2)
	]
	for i in positions.size():
		var p: Vector2 = positions[i]
		var height := 3.0 + float(i % 3) * 0.7
		_tree(Vector3(p.x, 0.0, p.y), height, i)


func _tree(pos: Vector3, height: float, index: int) -> void:
	var trunk := StaticBody3D.new()
	trunk.position = pos + Vector3(0.0, height * 0.42, 0.0)
	add_child(trunk)
	_cylinder(trunk, 0.27, height * 0.84, Vector3.ZERO, Color("6c5642"))
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = height * 0.84
	collision.shape = shape
	trunk.add_child(collision)
	var green := Color("447b65") if index % 3 == 0 else Color("386a60")
	_cone(self, 1.5, 2.8, pos + Vector3(0.0, height + 0.1, 0.0), green)
	_cone(self, 1.1, 2.2, pos + Vector3(0.0, height + 1.1, 0.0), green.lightened(0.1))
	_cone(self, 0.65, 1.7, pos + Vector3(0.0, height + 2.0, 0.0), green.lightened(0.16))


func _make_ruins() -> void:
	var stone := Color("778784")
	for pos in [Vector3(20, 1.1, -17), Vector3(24, 1.1, -17), Vector3(20, 1.1, -22), Vector3(24, 1.1, -22)]:
		_box(self, Vector3(1.1, 2.2, 1.1), pos, stone).material_override = _textured_material(RUIN_STONE_TEXTURE)
	_box(self, Vector3(5.3, 0.6, 1.4), Vector3(22, 2.45, -17), stone.lightened(0.12)).material_override = _textured_material(RUIN_STONE_TEXTURE)
	_box(self, Vector3(7.0, 0.3, 7.0), Vector3(22, 0.15, -19.5), Color("60716c")).material_override = _textured_material(RUIN_STONE_TEXTURE, Vector3(2.0, 2.0, 1.0))
	for pos in [Vector3(-21, 0.5, -20), Vector3(-19, 0.5, -23), Vector3(-23, 0.5, -22)]:
		_box(self, Vector3(1.5, 1.0, 1.5), pos, Color("647875")).material_override = _textured_material(RUIN_STONE_TEXTURE)


func _make_camp() -> void:
	_cylinder(self, 1.5, 0.3, Vector3(0.0, 0.15, 0.0), Color("686057"))
	for i in 8:
		var angle := float(i) * TAU / 8.0
		_box(self, Vector3(0.55, 0.38, 0.38), Vector3(cos(angle) * 1.25, 0.25, sin(angle) * 1.25), Color("8f9185"))
	_cone(self, 0.6, 1.25, Vector3(0.0, 0.95, 0.0), Color("ffad61"))
	_cone(self, 0.29, 0.75, Vector3(0.0, 1.2, 0.0), Color("ffe1a2"))
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0.0, 2.0, 0.0)
	fire_light.light_color = Color("ff9e62")
	fire_light.light_energy = 2.8
	fire_light.omni_range = 10.0
	add_child(fire_light)
	_box(self, Vector3(2.6, 0.45, 1.1), Vector3(4.0, 0.45, 0.5), Color("665b4c"))
	_box(self, Vector3(0.5, 1.0, 0.5), Vector3(2.95, 0.5, 0.5), Color("665b4c"))
	_box(self, Vector3(0.5, 1.0, 0.5), Vector3(5.05, 0.5, 0.5), Color("665b4c"))


func _make_collectibles() -> void:
	for pos in [Vector3(-21, 0, -21), Vector3(22, 0, -20), Vector3(19, 0, 21)]:
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		var crystal := _box(node, Vector3(0.8, 1.5, 0.8), Vector3(0.0, 1.15, 0.0), Color("8de9df"), true)
		crystal.rotation_degrees = Vector3(0.0, 40.0, 25.0)
		var glow := OmniLight3D.new()
		glow.position = Vector3(0.0, 1.3, 0.0)
		glow.light_color = Color("8de9df")
		glow.light_energy = 0.9
		glow.omni_range = 4.5
		node.add_child(glow)
		shards.append({"node": node, "taken": false})
	for pos in [Vector3(-15, 0, 8), Vector3(8, 0, -18), Vector3(17, 0, 6), Vector3(-7, 0, 20)]:
		var bush := Node3D.new()
		bush.position = pos
		add_child(bush)
		_sphere(bush, 0.82, Vector3(0.0, 0.7, 0.0), Color("5c8d69"))
		for offset in [Vector3(-0.35, 0.9, 0.2), Vector3(0.4, 0.75, -0.2), Vector3(0.2, 1.0, 0.3)]:
			_sphere(bush, 0.15, offset, Color("e88979"))
		berries.append({"node": bush, "ready": true})


func _make_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0.0, 1.2, 4.0)
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)
	player_visual = ExplorerAvatar.new()
	player_visual.name = "ExplorerAvatar"
	player.add_child(player_visual)
	pulse_ring = MeshInstance3D.new()
	pulse_ring.name = "PulseRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.88
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 8
	pulse_ring.mesh = ring_mesh
	pulse_ring.position.y = -0.72
	pulse_ring.visible = false
	pulse_ring_material = StandardMaterial3D.new()
	pulse_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse_ring_material.albedo_color = Color(0.55, 1.0, 0.91, 0.7)
	pulse_ring.material_override = pulse_ring_material
	player.add_child(pulse_ring)


func _make_wolves() -> void:
	var homes := [Vector3(-22, 0, 12), Vector3(21, 0, -4), Vector3(10, 0, 25)]
	for i in homes.size():
		var wolf := CharacterBody3D.new()
		wolf.position = homes[i] + Vector3(0.0, 0.62, 0.0)
		add_child(wolf)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.55
		capsule.height = 1.2
		shape.shape = capsule
		wolf.add_child(shape)
		_box(wolf, Vector3(1.05, 0.8, 1.55), Vector3(0.0, 0.0, 0.0), Color("677479"))
		_box(wolf, Vector3(0.76, 0.64, 0.65), Vector3(0.0, 0.2, -0.88), Color("879092"))
		_cone(wolf, 0.24, 0.6, Vector3(-0.25, 0.7, -0.85), Color("7a8587"))
		_cone(wolf, 0.24, 0.6, Vector3(0.25, 0.7, -0.85), Color("7a8587"))
		var eyes: Array[MeshInstance3D] = []
		eyes.append(_box(wolf, Vector3(0.18, 0.15, 0.12), Vector3(-0.2, 0.27, -1.22), Color("d6b982"), true))
		eyes.append(_box(wolf, Vector3(0.18, 0.15, 0.12), Vector3(0.2, 0.27, -1.22), Color("d6b982"), true))
		var mood_marker := _box(wolf, Vector3(0.22, 0.22, 0.22), Vector3(0.0, 1.18, 0.0), Color("d6b982"), true)
		mood_marker.rotation.z = PI / 4.0
		wolves.append({"node": wolf, "home": homes[i], "hp": 3, "stun": 0.0, "attack": 0.0, "eyes": eyes, "mood_marker": mood_marker})


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0.035, 0.09, 0.10, 0.82)
	top.position = Vector2(0, 0)
	top.size = Vector2(1000, 83)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	title_label = _label(layer, Vector2(25, 10), Vector2(500, 28), 21, Color("fce2a7"))
	stats_label = _label(layer, Vector2(25, 47), Vector2(900, 26), 16, Color("d0e4db"))
	objective_label = _label(layer, Vector2(25, 92), Vector2(900, 30), 17, Color("fce2a7"))
	for i in 3:
		var icon := TextureRect.new()
		icon.texture = SIGNAL_SHARD_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(25 + i * 42, 127)
		icon.size = Vector2(34, 34)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(icon)
		shard_icons.append(icon)
	var wolf_legend := _label(layer, Vector2(171, 131), Vector2(590, 25), 13, Color("d4dfd6"))
	wolf_legend.text = "WOLF LIGHTS   red: hunt  ·  gold: watch  ·  blue: retreat  ·  cyan: stunned"
	pulse_label = _label(layer, Vector2(775, 119), Vector2(200, 24), 15, Color("a8f0e5"))
	var pulse_track := ColorRect.new()
	pulse_track.color = Color(0.04, 0.15, 0.17, 0.85)
	pulse_track.position = Vector2(778, 147)
	pulse_track.size = Vector2(175, 8)
	pulse_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pulse_track)
	pulse_fill = ColorRect.new()
	pulse_fill.color = Color("78e7d6")
	pulse_fill.position = pulse_track.position
	pulse_fill.size = pulse_track.size
	pulse_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pulse_fill)
	scan_panel = ColorRect.new()
	scan_panel.color = Color(0.04, 0.14, 0.16, 0.78)
	scan_panel.position = Vector2(255, 176)
	scan_panel.size = Vector2(490, 35)
	scan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan_panel.visible = false
	layer.add_child(scan_panel)
	scan_label = _label(scan_panel, Vector2(12, 5), Vector2(466, 26), 17, Color("a8f0e5"))
	scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label = _label(layer, Vector2(270, 492), Vector2(460, 33), 19, Color("fff2c5"))
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label = _label(layer, Vector2(200, 552), Vector2(600, 35), 18, Color("fff1c9"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label = _label(layer, Vector2(25, 590), Vector2(930, 27), 14, Color("c7d7d4"))
	end_label = _label(layer, Vector2(175, 240), Vector2(650, 155), 34, Color("ffe7ad"))
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for dimensions in [Vector2(14.0, 2.0), Vector2(2.0, 14.0)]:
		var crosshair := ColorRect.new()
		crosshair.color = Color("f1f3dd", 0.8)
		crosshair.position = Vector2(500.0, 320.0) - dimensions * 0.5
		crosshair.size = dimensions
		crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(crosshair)


func _label(parent: Node, pos: Vector2, dimensions: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _move_player(delta: float) -> void:
	var axis := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): axis.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): axis.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis.x += 1.0
	axis = axis.normalized()
	var move_direction := _movement_direction(axis, camera_yaw)
	player.velocity.x = move_direction.x * 7.0
	player.velocity.z = move_direction.z * 7.0
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	elif Input.is_key_pressed(KEY_SPACE):
		player.velocity.y = 8.2
	if move_direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-move_direction.x, -move_direction.z), minf(1.0, delta * 10.0))
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -MAP_EDGE, MAP_EDGE)
	player.position.z = clampf(player.position.z, -MAP_EDGE, MAP_EDGE)


func _update_camera(delta: float) -> void:
	var focus := player.global_position + Vector3(0.0, 1.2, 0.0)
	var offset := Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch)) * CAMERA_DISTANCE
	var desired := focus + offset
	var ray := PhysicsRayQueryParameters3D.create(focus, desired)
	ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		desired = hit["position"] + hit["normal"] * 0.35
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 9.0))
	camera.look_at(focus)


func _movement_direction(axis: Vector2, yaw: float) -> Vector3:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return (right * axis.x + forward * -axis.y).normalized()


func _update_wolves(delta: float) -> void:
	for wolf_data in wolves:
		var wolf: CharacterBody3D = wolf_data["node"]
		if wolf_data["hp"] <= 0:
			continue
		wolf_data["stun"] = maxf(0.0, wolf_data["stun"] - delta)
		wolf_data["attack"] = maxf(0.0, wolf_data["attack"] - delta)
		_update_wolf_signal(wolf_data)
		var to_player := player.global_position - wolf.global_position
		var flat := Vector3(to_player.x, 0.0, to_player.z)
		var distance := flat.length()
		var direction := Vector3.ZERO
		if wolf_data["stun"] <= 0.0:
			match pack_action:
				"hunt":
					if distance < (24.0 if _is_night() else 15.0): direction = flat.normalized()
				"observe":
					if distance < 5.5: direction = -flat.normalized()
					elif distance < 19.0 and distance > 9.0: direction = flat.normalized() * 0.55
				"retreat":
					var to_home: Vector3 = wolf_data["home"] - wolf.global_position
					to_home.y = 0.0
					if to_home.length() > 1.0: direction = to_home.normalized()
				"roam":
					var home: Vector3 = wolf_data["home"]
					var wander := home + Vector3(sin(elapsed * 0.45) * 2.8, 0.0, cos(elapsed * 0.4) * 2.8)
					var to_wander := wander - wolf.global_position
					to_wander.y = 0.0
					if to_wander.length() > 0.5: direction = to_wander.normalized() * 0.4
		var speed := 4.8 if _is_night() else 3.8
		if ward_built and wolf.global_position.distance_to(CAMP) < 9.0:
			var away := wolf.global_position - CAMP
			away.y = 0.0
			direction = away.normalized()
		wolf.velocity.x = direction.x * speed
		wolf.velocity.z = direction.z * speed
		if not wolf.is_on_floor(): wolf.velocity.y -= 22.0 * delta
		else: wolf.velocity.y = -0.1
		wolf.move_and_slide()
		if direction.length() > 0.1:
			wolf.rotation.y = lerp_angle(wolf.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 7.0))
		if pack_action == "hunt" and distance < 1.7 and wolf_data["attack"] <= 0.0 and wolf_data["stun"] <= 0.0:
			wolf_data["attack"] = 1.4
			player_hp -= 13.0
			pack_hunger = maxf(0.0, pack_hunger - 9.0)
			_say("A wolf struck! Q repels the pack.")


func _update_wolf_signal(wolf_data: Dictionary) -> void:
	var color := _wolf_signal_color(pack_action, wolf_data["stun"] > 0.0)
	for eye in wolf_data["eyes"]:
		var material: StandardMaterial3D = eye.material_override
		material.albedo_color = color
		material.emission = color
	var mood_marker: MeshInstance3D = wolf_data["mood_marker"]
	var material: StandardMaterial3D = mood_marker.material_override
	material.albedo_color = color
	material.emission = color


func _wolf_signal_color(action: String, stunned: bool) -> Color:
	if stunned:
		return Color("7eece2")
	match action:
		"hunt": return Color("ff806b")
		"observe": return Color("f3c578")
		"retreat": return Color("8fb7ef")
		_: return Color("b9b6a4")


func _update_pulse_effect() -> void:
	pulse_ring.visible = pulse_visual > 0.0
	if not pulse_ring.visible:
		return
	var progress := 1.0 - pulse_visual / 0.4
	var radius := lerpf(0.35, 5.0, progress)
	pulse_ring.scale = Vector3.ONE * radius
	pulse_ring_material.albedo_color.a = 0.7 * (1.0 - progress)


func _animate_collectibles(_delta: float) -> void:
	for shard in shards:
		if not shard["taken"]:
			var node: Node3D = shard["node"]
			node.position.y = 0.12 * sin(elapsed * 2.0)
			node.rotation.y += _delta * 0.65
	fire_light.light_energy = 2.6 + 0.3 * sin(elapsed * 9.0)


func _update_daylight(delta: float) -> void:
	var target_energy := 0.14 if _is_night() else 1.3
	sun.light_energy = lerpf(sun.light_energy, target_energy, minf(1.0, delta * 1.2))
	environment.background_color = Color("182c41") if _is_night() else Color("8daeb0")
	fire_light.omni_range = 15.0 if _is_night() else 10.0


func _interact() -> void:
	var pos := player.global_position
	if pos.distance_to(CAMP) < 3.5:
		if collected == 3:
			victory = true
			game_over = true
			_release_mouse()
		elif supplies > 0 and player_hp < 100.0:
			supplies -= 1
			player_hp = minf(100.0, player_hp + 30.0)
			_say("The fire and supplies helped you recover.")
		else:
			_say("The campfire is safe for now. Search the ruins.")
		return
	for shard in shards:
		var node: Node3D = shard["node"]
		if not shard["taken"] and pos.distance_to(node.global_position) < 2.5:
			shard["taken"] = true
			node.visible = false
			collected += 1
			_say("Signal stone found. %d / 3. Return to camp when ready." % collected)
			return
	for berry in berries:
		var node: Node3D = berry["node"]
		if berry["ready"] and pos.distance_to(node.global_position) < 2.3:
			berry["ready"] = false
			node.visible = false
			supplies += 1
			_say("Gathered a supply. Use it at the campfire.")
			return
	_say("Nothing close enough to use.")


func _pulse() -> void:
	if pulse_cooldown > 0.0:
		return
	pulse_cooldown = 4.0
	pulse_visual = 0.4
	scan_time = 6.0
	_update_pulse_effect()
	var hit := 0
	for wolf_data in wolves:
		if wolf_data["hp"] <= 0:
			continue
		var wolf: CharacterBody3D = wolf_data["node"]
		if wolf.global_position.distance_to(player.global_position) < 5.0:
			wolf_data["hp"] -= 1
			wolf_data["stun"] = 1.3
			wolf_data["attack"] = 1.2
			var away := wolf.global_position - player.global_position
			away.y = 0.0
			wolf.global_position += away.normalized() * 2.0
			if wolf_data["hp"] <= 0: wolf.visible = false
			hit += 1
	if hit > 0:
		pack_fear = minf(100.0, pack_fear + float(hit) * 28.0)
		_say("The ember pulse scattered the wolves.")
	else:
		_say("The pulse faded into the trees.")


func _build_ward() -> void:
	if player.global_position.distance_to(CAMP) > 5.0:
		_say("Build the ward beside the campfire.")
		return
	if ward_built:
		_say("The ward is already lit.")
		return
	if supplies < 2:
		_say("Two supplies are needed to build the ward.")
		return
	supplies -= 2
	ward_built = true
	pack_fear = minf(100.0, pack_fear + 55.0)
	var pos := Vector3(-3.7, 0.0, -2.0)
	_cylinder(self, 0.22, 3.0, pos + Vector3(0.0, 1.5, 0.0), Color("81918a"))
	_sphere(self, 0.48, pos + Vector3(0.0, 3.2, 0.0), Color("9af1de"))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0.0, 3.2, 0.0)
	light.light_color = Color("87e7dc")
	light.light_energy = 2.1
	light.omni_range = 12.0
	add_child(light)
	_say("The ward lights the camp. Wolves keep their distance.")


func _decide_pack() -> void:
	pack_action = _local_pack_decision()
	pack_source = "local"
	if not use_laya or ai_busy:
		return
	var alive := 0
	var health := 0
	var nearest := 999.0
	for wolf_data in wolves:
		if wolf_data["hp"] <= 0: continue
		alive += 1
		health += int(wolf_data["hp"])
		var wolf: CharacterBody3D = wolf_data["node"]
		nearest = minf(nearest, wolf.global_position.distance_to(player.global_position))
	if alive == 0:
		return
	var state := {
		"wolf_count": alive,
		"pack_health": health,
		"pack_hunger": roundi(pack_hunger),
		"pack_fear": roundi(pack_fear),
		"player_distance": roundi(nearest),
		"player_hp": roundi(player_hp),
		"night": _is_night(),
		"camp_ward_active": ward_built,
		"camp_distance": roundi(player.global_position.distance_to(CAMP))
	}
	var error := ai_http.request(AI_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"agent": "wolf", "state": state}))
	if error == OK: ai_busy = true


func _local_pack_decision() -> String:
	var alive := 0
	var wounded := 0
	var nearest := 999.0
	for wolf_data in wolves:
		if wolf_data["hp"] <= 0: continue
		alive += 1
		if wolf_data["hp"] == 1: wounded += 1
		var wolf: CharacterBody3D = wolf_data["node"]
		nearest = minf(nearest, wolf.global_position.distance_to(player.global_position))
	if alive == 0: return "roam"
	if pack_fear > 45.0 or wounded >= 2 or (ward_built and player.global_position.distance_to(CAMP) < 10.0): return "retreat"
	if nearest < 14.0:
		return "hunt" if _is_night() or pack_hunger > 62.0 else "observe"
	return "roam"


func _on_ai_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	ai_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.has("action"):
		return
	var action := str(data["action"])
	if WOLF_ACTIONS.has(action):
		pack_action = action
		pack_source = "Laya"


func _new_night() -> void:
	for berry in berries:
		berry["ready"] = true
		var node: Node3D = berry["node"]
		node.visible = true
	for wolf_data in wolves:
		if wolf_data["hp"] <= 0:
			wolf_data["hp"] = 3
			var wolf: CharacterBody3D = wolf_data["node"]
			wolf.position = wolf_data["home"] + Vector3(0.0, 0.62, 0.0)
			wolf.visible = true
	_say("Night falls. The berry bushes regrow; the pack returns.")


func _is_night() -> bool:
	return fmod(elapsed, 78.0) > 40.0


func _say(text: String) -> void:
	message = text
	message_time = 4.0


func _nearest_signal_target() -> Vector3:
	var nearest := CAMP
	var best_distance := INF
	for shard in shards:
		if shard["taken"]:
			continue
		var node: Node3D = shard["node"]
		var distance := player.global_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = node.global_position
	return nearest


func _scan_bearing(target: Vector3, yaw: float) -> String:
	var offset := target - player.global_position
	offset.y = 0.0
	if offset.length() < 3.0:
		return "NEARBY"
	var direction := offset.normalized()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var angle := atan2(right.dot(direction), forward.dot(direction))
	if absf(angle) < PI / 6.0:
		return "AHEAD"
	if absf(angle) > PI * 5.0 / 6.0:
		return "BEHIND"
	return "RIGHT" if angle > 0.0 else "LEFT"


func _scan_text() -> String:
	var target := _nearest_signal_target()
	var flat_distance := Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
	var kind := "CAMP ECHO" if collected == 3 else "SIGNAL ECHO"
	var bearing := _scan_bearing(target, camera_yaw)
	if bearing == "NEARBY":
		return "%s   ·   NEARBY" % kind
	var approximate_distance := maxi(5, roundi(flat_distance / 5.0) * 5)
	return "%s   ·   %s   ·   ~%d m" % [kind, bearing, approximate_distance]


func _update_ui() -> void:
	title_label.text = "EMERGENT  /  THE LAST SIGNAL"
	stats_label.text = "HEALTH %d     SUPPLIES %d     SIGNAL STONES %d / 3     %s" % [maxi(0, roundi(player_hp)), supplies, collected, "NIGHT" if _is_night() else "DAY"]
	objective_label.text = "Find three stones. Q scans and repels; B builds a camp ward for two supplies."
	for i in shard_icons.size():
		shard_icons[i].modulate = Color.WHITE if i < collected else Color(0.7, 0.8, 0.78, 0.25)
	pulse_label.text = "PULSE READY  ·  Q / LMB" if pulse_cooldown <= 0.0 else "PULSE  %.1f s" % pulse_cooldown
	pulse_fill.size.x = 175.0 * (1.0 - pulse_cooldown / 4.0)
	scan_panel.visible = scan_time > 0.0 and not game_over
	if scan_panel.visible:
		scan_label.text = _scan_text()
	interaction_label.text = _nearby_interaction_text() if not game_over else ""
	message_label.text = message if message_time > 0.0 else ""
	debug_label.text = ("WOLVES: %s [%s]  /  hunger %d  fear %d  /  Laya %s" % [pack_action.to_upper(), pack_source, roundi(pack_hunger), roundi(pack_fear), "ON" if use_laya else "OFF"]) if show_debug else "Mouse look  WASD move  LMB pulse  RMB interact  Space jump  B build  L Laya  F1 debug  Esc cursor"
	end_label.text = ("THE SIGNAL IS ALIVE\nYou made it home. Press R to play again." if victory else "THE FOREST WINS\nPress R to try again.") if game_over else ""


func _nearby_interaction_text() -> String:
	var pos := player.global_position
	if pos.distance_to(CAMP) < 3.5:
		if collected == 3:
			return "E / RMB  ·  Complete the signal"
		if not ward_built and supplies >= 2:
			return "B  ·  Build a camp ward"
		if supplies > 0 and player_hp < 100.0:
			return "E / RMB  ·  Heal at the campfire"
		return "Campfire  ·  Find stones and supplies"
	for shard in shards:
		var node: Node3D = shard["node"]
		if not shard["taken"] and pos.distance_to(node.global_position) < 2.5:
			return "E / RMB  ·  Take signal stone"
	for berry in berries:
		var node: Node3D = berry["node"]
		if berry["ready"] and pos.distance_to(node.global_position) < 2.3:
			return "E / RMB  ·  Gather supplies"
	return ""


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	return mat


func _textured_material(texture: Texture2D, uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.uv1_scale = uv_scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.95
	return mat


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, glow)
	node.position = pos
	parent.add_child(node)
	return node


func _cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	parent.add_child(node)
	return node


func _cone(parent: Node, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	parent.add_child(node)
	return node


func _sphere(parent: Node, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	parent.add_child(node)
	return node
