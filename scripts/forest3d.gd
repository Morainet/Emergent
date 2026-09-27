extends Node3D

const CAMP = Vector3(0.0, 0.0, 0.0)
const AI_URL = "http://127.0.0.1:8765/decide"
const WOLF_ACTIONS = ["hunt", "observe", "retreat", "roam"]
const ARI_ACTIONS = ["hide", "gather", "explore", "defend", "return"]
const MAP_EDGE = 29.0
const MOUSE_SENSITIVITY = 0.003
const CAMERA_DISTANCE = 10.5
const PLAYER_SPEED = 7.0
const FOREST_FLOOR_TEXTURE = preload("res://assets/textures/forest_floor.png")
const RUIN_STONE_TEXTURE = preload("res://assets/textures/ruin_stone.png")
const TRAIL_EARTH_TEXTURE = preload("res://assets/textures/trail_earth.png")
const MOSS_BARK_TEXTURE = preload("res://assets/textures/moss_bark.png")
const PINE_CANOPY_TEXTURE = preload("res://assets/textures/pine_canopy.png")
const WOLF_MODEL = preload("res://scenes/wolf_avatar.tscn")
const CROWN_RING_HEIGHTS = [-0.5, -0.36, -0.08, 0.22, 0.5]
const CROWN_RING_RADII = [0.78, 1.0, 0.72, 0.42, 0.035]
const SIGNAL_SHARD_ICON = preload("res://assets/ui/signal_shard.png")
const SHARD_SITES = [Vector3(-21, 0, -21), Vector3(22, 0, -20), Vector3(19, 0, 21)]
const WOLF_DENS = [Vector3(-22, 0, 12), Vector3(21, 0, -4), Vector3(10, 0, 25)]

var player: CharacterBody3D
var player_visual: ExplorerAvatar
var ari: CharacterBody3D
var ari_visual: ExplorerAvatar
var ari_hp := 100.0
var ari_action := "explore"
var ari_source := "local"
var ari_defend_cooldown := 0.0
var forest_tree_positions: Array[Vector2] = []
var trail_paths: Array[PackedVector2Array] = []
var map_details: Node3D
var ari_navigator: ForestNavigator
var ari_route: Array[Vector3] = []
var ari_route_goal := Vector3.INF
var ari_repath_time := 0.0
var pulse_ring: MeshInstance3D
var pulse_ring_material: StandardMaterial3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := 0.53
var camera_distance := CAMERA_DISTANCE
var camera_focus := Vector3.ZERO
var camera_collision_shape: SphereShape3D
var player_step_phase := 0.0
var ari_step_phase := 0.0
var jump_was_down := false
var jump_buffer_time := 0.0
var coyote_time := 0.0
var mouse_captured := false
var sun: DirectionalLight3D
var environment: Environment
var fire_light: OmniLight3D
var ai_http: HTTPRequest
var ari_http: HTTPRequest
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
var ai_round := 0
var ai_busy := false
var ari_busy := false
var pack_model_age := 0.0
var ari_model_age := 0.0
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
var ari_status_label: Label
var pulse_fill: ColorRect
var scan_panel: ColorRect
var scan_label: Label
var shard_icons: Array[TextureRect] = []


func _ready() -> void:
	_build_world()
	_build_ui()
	ai_http = HTTPRequest.new()
	ai_http.timeout = 4.5
	add_child(ai_http)
	ai_http.request_completed.connect(_on_ai_response)
	ari_http = HTTPRequest.new()
	ari_http.timeout = 4.5
	add_child(ari_http)
	ari_http.request_completed.connect(_on_ari_response)
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
	ari_defend_cooldown = maxf(0.0, ari_defend_cooldown - delta)
	pack_model_age = maxf(0.0, pack_model_age - delta)
	ari_model_age = maxf(0.0, ari_model_age - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	pulse_visual = maxf(0.0, pulse_visual - delta)
	scan_time = maxf(0.0, scan_time - delta)
	message_time = maxf(0.0, message_time - delta)
	if _is_night() and not was_night:
		_new_night()
	was_night = _is_night()
	_update_daylight(delta)
	_move_player(delta)
	var player_speed := Vector2(player.velocity.x, player.velocity.z).length()
	player_step_phase += player_speed * delta * 1.6
	player_visual.animate(elapsed, player_speed, pulse_visual / 0.4, player.velocity.y, player.is_on_floor(), delta, player_step_phase)
	_update_pulse_effect()
	_update_ari(delta)
	_update_wolves(delta)
	_animate_collectibles(delta)
	_update_camera(delta)
	ai_timer -= delta
	if ai_timer <= 0.0:
		ai_timer = 2.5
		_decide_pack(ai_round % 2 == 0)
		_decide_ari(ai_round % 2 == 1)
		ai_round += 1
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
		if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clampf(camera_distance + (-0.8 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 5.8, 12.5)
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
			if not use_laya:
				pack_model_age = 0.0
				ari_model_age = 0.0
				_decide_pack(false)
				_decide_ari(false)
			_say("Laya decisions enabled for Ari and wolves." if use_laya else "Local decisions enabled for Ari and wolves.")
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
	ari_navigator = ForestNavigator.new(forest_tree_positions)
	_make_ruins()
	_make_camp()
	_make_map_details()
	_make_collectibles()
	_make_player()
	_make_ari()
	_make_wolves()
	camera = Camera3D.new()
	camera.fov = 69.0
	camera.current = true
	camera.position = Vector3(0.0, 7.0, 12.0)
	add_child(camera)
	camera_focus = player.global_position + Vector3(0.0, 1.15, 0.0)
	camera_collision_shape = SphereShape3D.new()
	camera_collision_shape.radius = 0.32
	camera.look_at(camera_focus)


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
		_ground_moss_patch(Vector2(x, z), 0.8 + float(i % 4) * 0.37, i)
	for i in 19:
		var angle := float(i) * TAU / 19.0
		var p := Vector3(cos(angle) * 30.0, 1.1, sin(angle) * 30.0)
		_box(self, Vector3(3.0, 2.2, 1.0), p, Color("425b58"))


func _ground_moss_patch(center: Vector2, radius: float, variation: int) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spoke in 9:
		var angle_a := float(spoke) * TAU / 9.0
		var angle_b := float(spoke + 1) * TAU / 9.0
		var radius_a := radius * (0.75 + 0.2 * sin(float(variation + spoke) * 2.17))
		var radius_b := radius * (0.75 + 0.2 * sin(float(variation + spoke + 1) * 2.17))
		var a := center + Vector2(cos(angle_a), sin(angle_a)) * radius_a
		var b := center + Vector2(cos(angle_b), sin(angle_b)) * radius_b
		_trail_vertex(tool, Vector3(center.x, 0.012, center.y), Vector2(0.5, 0.5), 0.36)
		_trail_vertex(tool, Vector3(a.x, 0.012, a.y), Vector2.ZERO, 0.0)
		_trail_vertex(tool, Vector3(b.x, 0.012, b.y), Vector2.ONE, 0.0)
	var patch := MeshInstance3D.new()
	patch.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("305b44") if variation % 2 == 0 else Color("486a4e")
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	patch.material_override = material
	add_child(patch)


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
		forest_tree_positions.append(p)
		var height := 2.9 + float((i * 7) % 5) * 0.43
		_tree(Vector3(p.x, 0.0, p.y), height, i)


func _tree(pos: Vector3, height: float, index: int) -> void:
	var trunk := StaticBody3D.new()
	trunk.position = pos + Vector3(0.0, height * 0.42, 0.0)
	add_child(trunk)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.bottom_radius = 0.37 + float(index % 3) * 0.025
	trunk_mesh.top_radius = 0.15
	trunk_mesh.height = height * 0.84
	trunk_mesh.radial_segments = 9
	var trunk_visual := MeshInstance3D.new()
	trunk_visual.mesh = trunk_mesh
	trunk_visual.material_override = _textured_material(MOSS_BARK_TEXTURE)
	trunk.add_child(trunk_visual)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = height * 0.84
	collision.shape = shape
	trunk.add_child(collision)
	for root in 3:
		var root_angle := float(root) * TAU / 3.0 + float(index) * 0.61
		var root_start := pos + Vector3(cos(root_angle) * 0.19, 0.52, sin(root_angle) * 0.19)
		var root_tip := pos + Vector3(cos(root_angle) * 0.68, 0.09, sin(root_angle) * 0.68)
		var root_mesh := CylinderMesh.new()
		root_mesh.bottom_radius = 0.16
		root_mesh.top_radius = 0.055
		root_mesh.height = root_start.distance_to(root_tip)
		root_mesh.radial_segments = 5
		var root_visual := MeshInstance3D.new()
		root_visual.mesh = root_mesh
		root_visual.position = (root_start + root_tip) * 0.5
		root_visual.quaternion = Quaternion(Vector3.UP, (root_tip - root_start).normalized())
		root_visual.material_override = _textured_material(MOSS_BARK_TEXTURE)
		add_child(root_visual)
	var lean := Vector2(sin(float(index) * 2.7), cos(float(index) * 1.9)) * 0.24
	var tier_count := 3 + index % 3
	for tier in tier_count:
		var radius := (1.55 - float(tier) * 0.24) * (0.88 + 0.06 * float((index + tier) % 4))
		var crown := _pine_crown(pos + Vector3(lean.x * float(tier) * 0.42, height - 0.15 + float(tier) * 0.72, lean.y * float(tier) * 0.42), radius, 2.2 - float(tier) * 0.16, index * 11 + tier)
		add_child(crown)
	var branch_count := 4 + (index * 2) % 3
	for branch in branch_count:
		var angle := float(branch) * TAU / float(branch_count) + float(index) * 1.37
		var start := pos + Vector3(0.0, height * (0.61 + float(branch % 3) * 0.11), 0.0)
		var reach := 0.95 + 0.16 * float((index + branch) % 3)
		var tip := start + Vector3(cos(angle) * reach, 0.28 + float(branch % 2) * 0.12, sin(angle) * reach)
		var branch_mesh := CylinderMesh.new()
		branch_mesh.bottom_radius = 0.11
		branch_mesh.top_radius = 0.045
		branch_mesh.height = start.distance_to(tip)
		branch_mesh.radial_segments = 6
		var branch_visual := MeshInstance3D.new()
		branch_visual.mesh = branch_mesh
		branch_visual.position = (start + tip) * 0.5
		branch_visual.quaternion = Quaternion(Vector3.UP, (tip - start).normalized())
		branch_visual.material_override = _textured_material(MOSS_BARK_TEXTURE)
		add_child(branch_visual)
		add_child(_pine_crown(tip + Vector3(0.0, 0.34, 0.0), 0.46 + 0.07 * float(branch % 3), 0.9 + 0.1 * float(branch % 2), index * 13 + branch))


func _pine_crown(pos: Vector3, radius: float, height: float, variation: int) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sectors := 9 + variation % 3
	for band in 4:
		for sector in sectors:
			var a := _crown_point(radius, height, band, sector, sectors, variation)
			var b := _crown_point(radius, height, band, sector + 1, sectors, variation)
			var c := _crown_point(radius, height, band + 1, sector, sectors, variation)
			var d := _crown_point(radius, height, band + 1, sector + 1, sectors, variation)
			_foliage_vertex(tool, a, Vector2(float(sector) / float(sectors), float(band) / 4.0))
			_foliage_vertex(tool, c, Vector2(float(sector) / float(sectors), float(band + 1) / 4.0))
			_foliage_vertex(tool, b, Vector2(float(sector + 1) / float(sectors), float(band) / 4.0))
			_foliage_vertex(tool, b, Vector2(float(sector + 1) / float(sectors), float(band) / 4.0))
			_foliage_vertex(tool, c, Vector2(float(sector) / float(sectors), float(band + 1) / 4.0))
			_foliage_vertex(tool, d, Vector2(float(sector + 1) / float(sectors), float(band + 1) / 4.0))
	for sector in sectors:
		_foliage_vertex(tool, Vector3(0.0, -height * 0.44, 0.0), Vector2(0.5, 0.5))
		_foliage_vertex(tool, _crown_point(radius, height, 0, sector + 1, sectors, variation), Vector2(1.0, 0.0))
		_foliage_vertex(tool, _crown_point(radius, height, 0, sector, sectors, variation), Vector2(0.0, 0.0))
	tool.generate_normals()
	var crown := MeshInstance3D.new()
	crown.mesh = tool.commit()
	crown.position = pos
	crown.rotation.y = float(variation) * 0.71
	crown.rotation.z = sin(float(variation) * 1.9) * 0.055
	var material := _textured_material(PINE_CANOPY_TEXTURE)
	material.albedo_color = Color(0.86, 0.95, 0.88) if variation % 3 == 0 else Color(1.0, 0.97, 0.91)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	crown.material_override = material
	return crown


func _crown_point(radius: float, height: float, ring: int, sector: int, sectors: int, variation: int) -> Vector3:
	var angle := float(sector % sectors) * TAU / float(sectors)
	var lobe := 1.0 + 0.13 * sin(angle * 3.0 + float(variation) * 1.71) + 0.07 * cos(angle * 5.0 + float(variation) * 0.83)
	var hem := sin(angle * 4.0 + float(variation) * 0.57) * height * 0.075 if ring == 0 else 0.0
	var shift := Vector2(sin(float(variation + ring) * 1.31), cos(float(variation - ring) * 1.19)) * radius * 0.055 * float(ring)
	return Vector3(cos(angle) * radius * CROWN_RING_RADII[ring] * lobe + shift.x, height * CROWN_RING_HEIGHTS[ring] + hem, sin(angle) * radius * CROWN_RING_RADII[ring] * lobe + shift.y)


func _foliage_vertex(tool: SurfaceTool, position: Vector3, uv: Vector2) -> void:
	tool.set_uv(uv)
	tool.add_vertex(position)


func _make_ruins() -> void:
	var stone := Color("778784")
	for pos in [Vector3(20, 1.1, -17), Vector3(24, 1.1, -17), Vector3(20, 1.1, -22), Vector3(24, 1.1, -22)]:
		_box(self, Vector3(1.1, 2.2, 1.1), pos, stone).material_override = _textured_material(RUIN_STONE_TEXTURE)
	_box(self, Vector3(5.3, 0.6, 1.4), Vector3(22, 2.45, -17), stone.lightened(0.12)).material_override = _textured_material(RUIN_STONE_TEXTURE)
	_box(self, Vector3(7.0, 0.3, 7.0), Vector3(22, 0.15, -19.5), Color("60716c")).material_override = _textured_material(RUIN_STONE_TEXTURE, Vector3(2.0, 2.0, 1.0))
	for pos in [Vector3(-21, 0.5, -20), Vector3(-19, 0.5, -23), Vector3(-23, 0.5, -22)]:
		_box(self, Vector3(1.5, 1.0, 1.5), pos, Color("647875")).material_override = _textured_material(RUIN_STONE_TEXTURE)


func _make_camp() -> void:
	_cylinder(self, 6.4, 0.025, Vector3(0.0, 0.012, 0.0), Color("5a604c"))
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
	_box(self, Vector3(1.0, 0.75, 0.9), Vector3(-3.7, 0.39, 2.8), Color("826a50"))
	_box(self, Vector3(1.05, 0.12, 0.95), Vector3(-3.7, 0.82, 2.8), Color("a28661"))
	for x in [-0.65, 0.65]:
		var canvas := _box(self, Vector3(1.8, 0.12, 2.4), Vector3(-3.5 + x, 1.04, -3.0), Color("9e9577"))
		canvas.rotation.z = 0.85 if x < 0.0 else -0.85
	_box(self, Vector3(2.0, 0.08, 2.4), Vector3(-3.5, 0.08, -3.0), Color("746e5a"))


func _make_map_details() -> void:
	map_details = Node3D.new()
	map_details.name = "MapDetails"
	add_child(map_details)
	trail_paths = [
		PackedVector2Array([Vector2.ZERO, Vector2(-5, -4), Vector2(-11, -9), Vector2(-17, -15), Vector2(-21, -21)]),
		PackedVector2Array([Vector2.ZERO, Vector2(7, -4), Vector2(14, -10), Vector2(22, -20)]),
		PackedVector2Array([Vector2.ZERO, Vector2(7, 4), Vector2(12, 8), Vector2(15, 15), Vector2(19, 21)])
	]
	for i in trail_paths.size():
		_make_trail_ribbon(trail_paths[i], i)
	_dress_trail_edges()
	_make_site_landmarks()
	_make_den_markers()
	_make_forest_props()
	_scatter_undergrowth()


func _make_trail_ribbon(path: PackedVector2Array, route_index: int) -> void:
	var points: Array[Vector2] = []
	for segment in range(path.size() - 1):
		var p0: Vector2 = path[maxi(0, segment - 1)]
		var p1: Vector2 = path[segment]
		var p2: Vector2 = path[segment + 1]
		var p3: Vector2 = path[mini(path.size() - 1, segment + 2)]
		for step in 5:
			var t := float(step) / 5.0
			var t2 := t * t
			var t3 := t2 * t
			var point := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			var direction := (p2 - p1).normalized()
			var sideways := Vector2(-direction.y, direction.x)
			point += sideways * sin(t * PI) * sin(float(segment * 5 + step) * 1.2 + float(route_index)) * 0.16
			points.append(point)
	points.append(path[path.size() - 1])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	var offsets := [-1.0, -0.72, 0.0, 0.72, 1.0]
	var opacity := [0.0, 0.9, 1.0, 0.9, 0.0]
	for i in range(points.size() - 1):
		var forward := (points[mini(points.size() - 1, i + 1)] - points[maxi(0, i - 1)]).normalized()
		var next_forward := (points[mini(points.size() - 1, i + 2)] - points[i]).normalized()
		var side := Vector2(-forward.y, forward.x)
		var next_side := Vector2(-next_forward.y, next_forward.x)
		var next_distance := distance + points[i].distance_to(points[i + 1])
		var width := 1.15 + 0.17 * sin(float(i) * 0.72 + float(route_index))
		var next_width := 1.15 + 0.17 * sin(float(i + 1) * 0.72 + float(route_index))
		for lane in 4:
			var a := Vector3(points[i].x + side.x * offsets[lane] * width, 0.053, points[i].y + side.y * offsets[lane] * width)
			var b := Vector3(points[i + 1].x + next_side.x * offsets[lane] * next_width, 0.053, points[i + 1].y + next_side.y * offsets[lane] * next_width)
			var c := Vector3(points[i].x + side.x * offsets[lane + 1] * width, 0.053, points[i].y + side.y * offsets[lane + 1] * width)
			var d := Vector3(points[i + 1].x + next_side.x * offsets[lane + 1] * next_width, 0.053, points[i + 1].y + next_side.y * offsets[lane + 1] * next_width)
			_trail_vertex(tool, a, Vector2((offsets[lane] + 1.0) * 0.5, distance / 3.0), opacity[lane])
			_trail_vertex(tool, b, Vector2((offsets[lane] + 1.0) * 0.5, next_distance / 3.0), opacity[lane])
			_trail_vertex(tool, c, Vector2((offsets[lane + 1] + 1.0) * 0.5, distance / 3.0), opacity[lane + 1])
			_trail_vertex(tool, c, Vector2((offsets[lane + 1] + 1.0) * 0.5, distance / 3.0), opacity[lane + 1])
			_trail_vertex(tool, b, Vector2((offsets[lane] + 1.0) * 0.5, next_distance / 3.0), opacity[lane])
			_trail_vertex(tool, d, Vector2((offsets[lane + 1] + 1.0) * 0.5, next_distance / 3.0), opacity[lane + 1])
		distance = next_distance
	var trail := MeshInstance3D.new()
	trail.name = "TrailRibbon%d" % route_index
	trail.mesh = tool.commit()
	var material := _textured_material(TRAIL_EARTH_TEXTURE)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail.material_override = material
	map_details.add_child(trail)


func _trail_vertex(tool: SurfaceTool, position: Vector3, uv: Vector2, alpha: float) -> void:
	tool.set_uv(uv)
	tool.set_color(Color(1.0, 1.0, 1.0, alpha))
	tool.set_normal(Vector3.UP)
	tool.add_vertex(position)


func _dress_trail_edges() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1841
	for path in trail_paths:
		for segment in range(path.size() - 1):
			var start: Vector2 = path[segment]
			var finish: Vector2 = path[segment + 1]
			var direction := (finish - start).normalized()
			var side := Vector2(-direction.y, direction.x)
			var samples := maxi(2, roundi(start.distance_to(finish) / 2.2))
			for i in samples:
				var t := (float(i) + random.randf_range(0.2, 0.8)) / float(samples)
				var center := start.lerp(finish, t)
				for sign_side in [-1.0, 1.0]:
					if random.randf() > 0.72:
						continue
					var p: Vector2 = center + side * float(sign_side) * random.randf_range(1.28, 1.82)
					if p.length() < 6.8:
						continue
					var blocked := false
					for tree in forest_tree_positions:
						if p.distance_to(tree) < 1.05:
							blocked = true
					for site in SHARD_SITES:
						if p.distance_to(Vector2(site.x, site.z)) < 3.0:
							blocked = true
					if blocked:
						continue
					if random.randf() < 0.25:
						var stone := _box(map_details, Vector3(0.3, 0.12, 0.27), Vector3(p.x, 0.07, p.y), Color("777b6a"))
						stone.rotation.y = random.randf_range(0.0, TAU)
					else:
						var height := random.randf_range(0.2, 0.48)
						_cone(map_details, 0.18, height, Vector3(p.x, height * 0.5, p.y), Color("688765"))


func _make_site_landmarks() -> void:
	# A broken stone circle, an inscribed gate and a lone beacon give each route a silhouette.
	var north_west: Vector3 = SHARD_SITES[0]
	for i in 7:
		var angle := float(i) * TAU / 7.0
		var height := 0.65 + float(i % 3) * 0.33
		var stone := _box(map_details, Vector3(0.62, height, 0.54), north_west + Vector3(cos(angle) * 2.5, height * 0.5, sin(angle) * 2.5), Color("71817a"))
		stone.rotation.y = angle
		stone.material_override = _textured_material(RUIN_STONE_TEXTURE)
	var fallen := _box(map_details, Vector3(0.65, 0.55, 2.4), north_west + Vector3(3.0, 0.31, -1.0), Color("657773"))
	fallen.rotation.y = 0.4
	fallen.material_override = _textured_material(RUIN_STONE_TEXTURE)
	for x in [20.0, 24.0]:
		for z in [-17.0, -22.0]:
			_box(map_details, Vector3(0.12, 0.72, 0.11), Vector3(x, 1.32, z - 0.56), Color("72d9cd"), true)
	for i in 3:
		_box(map_details, Vector3(1.8 + float(i) * 0.45, 0.12, 0.65), Vector3(22.0, 0.07, -14.4 + float(i) * 0.8), Color("778783"))
	var south_east: Vector3 = SHARD_SITES[2]
	for offset in [Vector3(-2.3, 0.0, 1.8), Vector3(2.3, 0.0, 1.8)]:
		_box(map_details, Vector3(0.95, 2.6, 0.95), south_east + offset + Vector3(0.0, 1.3, 0.0), Color("6b7875")).material_override = _textured_material(RUIN_STONE_TEXTURE)
	_box(map_details, Vector3(5.6, 0.52, 1.1), south_east + Vector3(0.0, 2.84, 1.8), Color("758681")).material_override = _textured_material(RUIN_STONE_TEXTURE)
	_box(map_details, Vector3(1.6, 0.18, 0.26), south_east + Vector3(0.0, 2.86, 1.23), Color("7ee6d8"), true)
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.25
		_box(map_details, Vector3(0.65, 0.3, 0.55), south_east + Vector3(cos(a) * 3.25, 0.16, sin(a) * 3.25), Color("62746d"))


func _make_den_markers() -> void:
	for den in WOLF_DENS:
		for i in 5:
			var angle := float(i) * TAU / 5.0
			var radius := 2.2 + float(i % 2) * 0.5
			var p: Vector3 = den + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			var rock := _box(map_details, Vector3(0.65, 0.38 + float(i % 3) * 0.17, 0.55), p + Vector3(0.0, 0.23, 0.0), Color("485852"))
			rock.rotation.y = angle
			_cone(map_details, 0.18, 0.65, p + Vector3(0.55, 0.32, 0.0), Color("775f51"))


func _make_forest_props() -> void:
	# Deliberately sparse silhouette props leave the three readable routes open.
	for position in [Vector2(-17, -4), Vector2(-5, -18), Vector2(15, -4), Vector2(5, 17), Vector2(-20, 17)]:
		var log := _cylinder(map_details, 0.35, 3.2, Vector3(position.x, 0.38, position.y), Color.WHITE)
		log.rotation.z = PI * 0.5
		log.material_override = _textured_material(MOSS_BARK_TEXTURE)
		for end in [-1.45, 1.45]:
			var end_cap := _cylinder(map_details, 0.38, 0.1, Vector3(position.x + end, 0.38, position.y), Color("97826b"))
			end_cap.rotation.z = PI * 0.5
	for position in [Vector2(-27, -16), Vector2(-27, 14), Vector2(-3, 23), Vector2(27, 18), Vector2(27, -15), Vector2(3, -27)]:
		var p := Vector3(position.x, 0.0, position.y)
		for i in 3:
			var h := 0.9 + float(i % 2) * 0.55
			var boulder := _box(map_details, Vector3(1.5 + float(i % 2) * 0.6, h, 1.3), p + Vector3(float(i - 1) * 0.9, h * 0.42, float(i % 2) * 0.65), Color("6d7b72"))
			boulder.rotation.y = float(i) * 0.7
			boulder.material_override = _textured_material(RUIN_STONE_TEXTURE)
	for position in [Vector2(-24, -17), Vector2(-16, -17), Vector2(-14, 19), Vector2(7, 20), Vector2(18, -13), Vector2(27, 13)]:
		var p := Vector3(position.x, 0.0, position.y)
		for i in 4:
			var angle := float(i) * TAU / 4.0
			var leaf := _cone(map_details, 0.55, 1.1, p + Vector3(cos(angle) * 0.32, 0.55, sin(angle) * 0.32), Color("668b69") if i % 2 == 0 else Color("4d785e"))
			leaf.rotation.z = cos(angle) * 0.4
			leaf.rotation.x = sin(angle) * 0.4
	for position in [Vector2(-23, -19), Vector2(-19, -24), Vector2(17, 24), Vector2(23, 19)]:
		for i in 3:
			var p := Vector3(position.x + float(i) * 0.35, 0.0, position.y + float(i % 2) * 0.3)
			_cylinder(map_details, 0.055, 0.3, p + Vector3(0.0, 0.15, 0.0), Color("c8c3a6"))
			_cone(map_details, 0.23, 0.23, p + Vector3(0.0, 0.38, 0.0), Color("88c5a8"))


func _scatter_undergrowth() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 9173
	for i in 125:
		var p := Vector2(random.randf_range(-27.0, 27.0), random.randf_range(-27.0, 27.0))
		if p.length() < 7.4 or _near_map_feature(p):
			continue
		if i % 4 == 0:
			var rock := _box(map_details, Vector3(random.randf_range(0.45, 0.9), 0.28, random.randf_range(0.4, 0.8)), Vector3(p.x, 0.15, p.y), Color("67746b"))
			rock.rotation.y = random.randf_range(0.0, TAU)
		else:
			var height := random.randf_range(0.38, 0.75)
			_cone(map_details, 0.28, height, Vector3(p.x, height * 0.5, p.y), Color("52775b") if i % 3 == 0 else Color("66835f"))
			_cone(map_details, 0.22, height * 0.8, Vector3(p.x + 0.35, height * 0.4, p.y + 0.12), Color("748a64"))


func _near_map_feature(point: Vector2) -> bool:
	for site in SHARD_SITES:
		if point.distance_to(Vector2(site.x, site.z)) < 4.0:
			return true
	for tree in forest_tree_positions:
		if point.distance_to(tree) < 1.5:
			return true
	for path in trail_paths:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var segment := b - a
			var t := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
			if point.distance_to(a + segment * t) < 1.55:
				return true
	return false


func _make_collectibles() -> void:
	for pos in SHARD_SITES:
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		_cylinder(node, 0.85, 0.28, Vector3(0.0, 0.14, 0.0), Color("71817a"))
		_cylinder(node, 0.58, 0.10, Vector3(0.0, 0.34, 0.0), Color("4d8079"))
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


func _make_ari() -> void:
	ari = CharacterBody3D.new()
	ari.name = "Ari"
	ari.position = Vector3(3.0, 1.2, 2.0)
	add_child(ari)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	ari.add_child(shape)
	ari_visual = ExplorerAvatar.new()
	ari_visual.name = "AriAvatar"
	ari_visual.jacket_color = Color("986e4e")
	ari_visual.jacket_light_color = Color("b88960")
	ari_visual.signal_color = Color("ffdb89")
	ari.add_child(ari_visual)
	var marker := _box(ari, Vector3(0.22, 0.22, 0.22), Vector3(0.0, 1.35, 0.0), Color("ffdb89"), true)
	marker.rotation.z = PI / 4.0


func _make_wolves() -> void:
	var homes := WOLF_DENS
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
		var visual: WolfAvatar = WOLF_MODEL.instantiate()
		wolf.add_child(visual)
		wolves.append({"node": wolf, "home": homes[i], "hp": 3, "stun": 0.0, "attack": 0.0, "eyes": visual.eyes, "mood_marker": visual.mood_marker, "visual": visual})


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
	ari_status_label = _label(layer, Vector2(650, 12), Vector2(325, 27), 16, Color("ffdb89"))
	ari_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	var horizontal := _approach_horizontal_velocity(Vector2(player.velocity.x, player.velocity.z), Vector2(move_direction.x, move_direction.z) * PLAYER_SPEED, delta, player.is_on_floor())
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.y
	var grounded := player.is_on_floor()
	if _should_jump(Input.is_key_pressed(KEY_SPACE), grounded, delta):
		player.velocity.y = 8.2
	elif not grounded:
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = -0.1
	if horizontal.length() > 0.2:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-horizontal.x, -horizontal.y), 1.0 - exp(-delta * 12.0))
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -MAP_EDGE, MAP_EDGE)
	player.position.z = clampf(player.position.z, -MAP_EDGE, MAP_EDGE)


func _should_jump(jump_down: bool, grounded: bool, delta: float) -> bool:
	coyote_time = 0.12 if grounded else maxf(0.0, coyote_time - delta)
	if jump_down and not jump_was_down:
		jump_buffer_time = 0.14
	jump_was_down = jump_down
	jump_buffer_time = maxf(0.0, jump_buffer_time - delta)
	if jump_buffer_time > 0.0 and coyote_time > 0.0:
		jump_buffer_time = 0.0
		coyote_time = 0.0
		return true
	return false


func _approach_horizontal_velocity(current: Vector2, target: Vector2, delta: float, grounded: bool) -> Vector2:
	var response := 8.0
	if grounded:
		response = 24.0 if target.length() > 0.01 else 29.0
	return current.move_toward(target, response * delta)


func _update_camera(delta: float) -> void:
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var target_focus := player.global_position + Vector3(0.0, 1.15, 0.0) + right * 0.28
	camera_focus = camera_focus.lerp(target_focus, 1.0 - exp(-delta * 12.0))
	var offset := Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch)) * camera_distance
	var desired := _camera_collision_position(camera_focus, camera_focus + offset)
	var follow_rate := 18.0 if camera.global_position.distance_to(camera_focus) > desired.distance_to(camera_focus) else 8.0
	var candidate := camera.global_position.lerp(desired, 1.0 - exp(-delta * follow_rate))
	camera.global_position = _camera_collision_position(camera_focus, candidate)
	camera.look_at(camera_focus)
	var speed_ratio := clampf(Vector2(player.velocity.x, player.velocity.z).length() / PLAYER_SPEED, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, 68.0 + speed_ratio * 3.0, 1.0 - exp(-delta * 4.0))


func _camera_collision_position(focus: Vector3, target: Vector3) -> Vector3:
	var motion := target - focus
	if motion.length() < 0.01:
		return target
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_collision_shape
	query.transform = Transform3D(Basis.IDENTITY, focus)
	query.motion = motion
	var excluded: Array[RID] = [player.get_rid(), ari.get_rid()]
	for wolf_data in wolves:
		var wolf: CharacterBody3D = wolf_data["node"]
		excluded.append(wolf.get_rid())
	query.exclude = excluded
	var travel := get_world_3d().direct_space_state.cast_motion(query)
	if travel.is_empty() or travel[0] >= 0.999:
		return target
	return focus + motion * maxf(0.0, travel[0] - 0.015)


func _movement_direction(axis: Vector2, yaw: float) -> Vector3:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return (right * axis.x + forward * -axis.y).normalized()


func _nearest_alive_wolf(origin: Vector3) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := INF
	for wolf_data in wolves:
		if wolf_data["hp"] <= 0:
			continue
		var wolf: CharacterBody3D = wolf_data["node"]
		var distance := origin.distance_squared_to(wolf.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = wolf_data
	return nearest


func _nearest_ready_berry(origin: Vector3) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := INF
	for berry in berries:
		if not berry["ready"]:
			continue
		var node: Node3D = berry["node"]
		var distance := origin.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = berry
	return nearest


func _nearest_untaken_shard(origin: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance := INF
	for shard in shards:
		if shard["taken"]:
			continue
		var node: Node3D = shard["node"]
		var distance := origin.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = node
	return nearest


func _update_ari(delta: float) -> void:
	if ari_hp <= 0.0:
		ari_visual.rotation.z = lerpf(ari_visual.rotation.z, 1.2, minf(1.0, delta * 5.0))
		ari.velocity.x = 0.0
		ari.velocity.z = 0.0
		if not ari.is_on_floor():
			ari.velocity.y -= 22.0 * delta
		ari.move_and_slide()
		ari_visual.animate(elapsed, 0.0, 0.0, ari.velocity.y, ari.is_on_floor(), delta)
		return
	ari_visual.rotation.z = lerpf(ari_visual.rotation.z, 0.0, minf(1.0, delta * 5.0))
	ari_action = _safe_ari_action(ari_action)
	var goal := CAMP + Vector3(2.8, 0.0, 1.5)
	match ari_action:
		"gather":
			var berry := _nearest_ready_berry(ari.global_position)
			if not berry.is_empty():
				var bush: Node3D = berry["node"]
				goal = bush.global_position
				if ari.global_position.distance_to(goal) < 2.0:
					ari_visual.play_action("interact")
					berry["ready"] = false
					bush.visible = false
					supplies += 1
					ari_action = "return"
					_say("Ari gathered a supply for the camp.")
		"explore":
			var shard := _nearest_untaken_shard(ari.global_position)
			if shard != null:
				goal = shard.global_position + Vector3(2.0, 0.0, 1.0)
				if ari.global_position.distance_to(player.global_position) > 8.0:
					goal = player.global_position
		"defend":
			var wolf_data := _nearest_alive_wolf(ari.global_position)
			if not wolf_data.is_empty():
				var wolf: CharacterBody3D = wolf_data["node"]
				goal = wolf.global_position
				if ari.global_position.distance_to(goal) < 3.8 and ari_defend_cooldown <= 0.0:
					ari_visual.play_action("pulse")
					wolf_data["stun"] = 1.6
					wolf_data["attack"] = 1.6
					ari_defend_cooldown = 8.0
					pack_fear = minf(100.0, pack_fear + 18.0)
					_say("Ari drove the wolf back!")
		"hide":
			goal = CAMP + Vector3(2.8, 0.0, 1.5)
		"return":
			goal = CAMP + Vector3(2.8, 0.0, 1.5)
	var direct_offset := goal - ari.global_position
	direct_offset.y = 0.0
	var waypoint := goal if direct_offset.length() <= 1.25 else _ari_waypoint(goal, delta)
	var offset := waypoint - ari.global_position
	offset.y = 0.0
	var direction := offset.normalized() if offset.length() > 1.25 else Vector3.ZERO
	ari.velocity.x = direction.x * 4.1
	ari.velocity.z = direction.z * 4.1
	if not ari.is_on_floor():
		ari.velocity.y -= 22.0 * delta
	else:
		ari.velocity.y = -0.1
	ari.move_and_slide()
	if direction.length() > 0.1:
		ari.rotation.y = lerp_angle(ari.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))
	var ari_speed := Vector2(ari.velocity.x, ari.velocity.z).length()
	ari_step_phase += ari_speed * delta * 1.6
	ari_visual.animate(elapsed, ari_speed, 0.0, ari.velocity.y, ari.is_on_floor(), delta, ari_step_phase)
	if ari.global_position.distance_to(CAMP) < 4.0:
		ari_hp = minf(100.0, ari_hp + delta * 3.0)


func _ari_waypoint(goal: Vector3, delta: float) -> Vector3:
	ari_repath_time -= delta
	if ari_repath_time <= 0.0 or ari_route_goal.distance_to(goal) > 1.5 or ari_route.is_empty():
		ari_route = ari_navigator.route(ari.global_position, goal)
		ari_route_goal = goal
		ari_repath_time = 0.6
	while not ari_route.is_empty():
		var point: Vector3 = ari_route.front()
		if Vector2(point.x - ari.global_position.x, point.z - ari.global_position.z).length() > 0.75:
			break
		ari_route.pop_front()
	return ari_route.front() if not ari_route.is_empty() else ari.global_position


func _update_wolves(delta: float) -> void:
	pack_action = _safe_pack_action(pack_action)
	for wolf_data in wolves:
		var wolf: CharacterBody3D = wolf_data["node"]
		if wolf_data["hp"] <= 0:
			continue
		wolf_data["stun"] = maxf(0.0, wolf_data["stun"] - delta)
		wolf_data["attack"] = maxf(0.0, wolf_data["attack"] - delta)
		_update_wolf_signal(wolf_data)
		var target: CharacterBody3D = player
		if ari_hp > 0.0 and wolf.global_position.distance_to(ari.global_position) < wolf.global_position.distance_to(player.global_position):
			target = ari
		var to_target := target.global_position - wolf.global_position
		var flat := Vector3(to_target.x, 0.0, to_target.z)
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
		var visual: WolfAvatar = wolf_data["visual"]
		visual.animate(Vector2(wolf.velocity.x, wolf.velocity.z).length(), pack_action, wolf_data["stun"] > 0.0, delta)
		if pack_action == "hunt" and distance < 1.7 and wolf_data["attack"] <= 0.0 and wolf_data["stun"] <= 0.0 and not (ward_built and target.global_position.distance_to(CAMP) < 9.0):
			wolf_data["attack"] = 1.4
			visual.play_attack()
			if target == ari:
				ari_hp = maxf(0.0, ari_hp - 13.0)
				ari_visual.play_action("hurt")
				_say("A wolf struck Ari! Help her or drive it away.")
			else:
				player_hp -= 13.0
				player_visual.play_action("hurt")
				_say("A wolf struck! Q repels the pack.")
			pack_hunger = maxf(0.0, pack_hunger - 9.0)


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
	player_visual.play_action("interact")
	var pos := player.global_position
	if collected == 3 and pos.distance_to(CAMP) < 3.5:
		victory = true
		game_over = true
		_release_mouse()
		return
	if ari_hp <= 0.0 and pos.distance_to(ari.global_position) < 2.5:
		if supplies < 1:
			_say("Ari needs one supply to recover.")
		else:
			supplies -= 1
			ari_hp = 45.0
			ari_action = "hide"
			ari_model_age = 0.0
			ari_source = "local"
			_say("Ari is back on her feet. She is heading for camp.")
		return
	if pos.distance_to(CAMP) < 3.5:
		if supplies > 0 and player_hp < 100.0:
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
	player_visual.play_action("pulse")
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


func _decide_pack(request_model: bool = true) -> void:
	if not use_laya or pack_model_age <= 0.0:
		pack_action = _local_pack_decision()
		pack_source = "local"
	else:
		pack_action = _safe_pack_action(pack_action)
	if not use_laya or ai_busy or not request_model:
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
	var nearest_ari := 999.0
	if ari_hp > 0.0:
		var ari_wolf := _nearest_alive_wolf(ari.global_position)
		if not ari_wolf.is_empty():
			var wolf: CharacterBody3D = ari_wolf["node"]
			nearest_ari = ari.global_position.distance_to(wolf.global_position)
	var state := {
		"wolf_count": alive,
		"pack_health": health,
		"pack_hunger": roundi(pack_hunger),
		"pack_fear": roundi(pack_fear),
		"player_distance": roundi(nearest),
		"npc_distance": roundi(nearest_ari),
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
		if ari_hp > 0.0:
			nearest = minf(nearest, wolf.global_position.distance_to(ari.global_position))
	if alive == 0: return "roam"
	if pack_fear > 45.0 or wounded >= 2 or (ward_built and (player.global_position.distance_to(CAMP) < 10.0 or ari.global_position.distance_to(CAMP) < 10.0)): return "retreat"
	if nearest < 14.0:
		return "hunt" if _is_night() or pack_hunger > 62.0 else "observe"
	return "roam"


func _safe_pack_action(candidate: String) -> String:
	var wounded := 0
	var alive := 0
	for wolf_data in wolves:
		if wolf_data["hp"] > 0:
			alive += 1
		if wolf_data["hp"] == 1:
			wounded += 1
	if alive == 0:
		return "roam"
	if pack_fear > 45.0 or wounded >= 2 or (ward_built and (player.global_position.distance_to(CAMP) < 10.0 or ari.global_position.distance_to(CAMP) < 10.0)):
		return "retreat"
	return candidate


func _local_ari_decision() -> String:
	if ari_hp <= 0.0:
		return "hide"
	var wolf_data := _nearest_alive_wolf(ari.global_position)
	var wolf_distance := INF
	if not wolf_data.is_empty():
		var wolf: CharacterBody3D = wolf_data["node"]
		wolf_distance = ari.global_position.distance_to(wolf.global_position)
	if ari_hp < 35.0 or (wolf_distance < 5.5 and ari_hp < 60.0):
		return "hide"
	if wolf_distance < 6.5 and ari_defend_cooldown <= 0.0 and ari_hp >= 60.0:
		return "defend"
	if player_hp < 75.0 and supplies < 2 and not _nearest_ready_berry(ari.global_position).is_empty():
		return "gather"
	if _nearest_untaken_shard(ari.global_position) != null:
		return "explore"
	if supplies < 2 and not _nearest_ready_berry(ari.global_position).is_empty():
		return "gather"
	return "return"


func _safe_ari_action(candidate: String) -> String:
	if ari_hp <= 0.0:
		return "hide"
	var wolf_data := _nearest_alive_wolf(ari.global_position)
	if not wolf_data.is_empty():
		var wolf: CharacterBody3D = wolf_data["node"]
		var wolf_distance := ari.global_position.distance_to(wolf.global_position)
		if wolf_distance < 5.5 and ari_hp < 60.0:
			return "hide"
		if wolf_distance < 4.5 and ari_hp >= 60.0 and ari_defend_cooldown <= 0.0 and candidate != "hide":
			return "defend"
	if candidate == "defend" and ari_hp < 60.0:
		return "hide"
	if candidate == "defend" and ari_defend_cooldown > 0.0:
		return "explore" if collected < 3 else "return"
	if candidate == "defend" and (wolf_data.is_empty() or ari.global_position.distance_to((wolf_data["node"] as CharacterBody3D).global_position) > 9.0):
		return "explore" if collected < 3 else "return"
	if candidate == "gather" and _nearest_ready_berry(ari.global_position).is_empty():
		return "explore" if collected < 3 else "return"
	if candidate == "explore" and collected >= 3:
		return "return"
	return candidate


func _decide_ari(request_model: bool = true) -> void:
	if not use_laya or ari_model_age <= 0.0:
		ari_action = _safe_ari_action(_local_ari_decision())
		ari_source = "local"
	else:
		ari_action = _safe_ari_action(ari_action)
	if not use_laya or ari_busy or not request_model or ari_hp <= 0.0:
		return
	var wolf_data := _nearest_alive_wolf(ari.global_position)
	var wolf_distance := 999.0
	var enemy_count := 0
	for pack_member in wolves:
		if pack_member["hp"] <= 0:
			continue
		var wolf: CharacterBody3D = pack_member["node"]
		if wolf.global_position.distance_to(ari.global_position) < 12.0:
			enemy_count += 1
	if not wolf_data.is_empty():
		var nearest_wolf: CharacterBody3D = wolf_data["node"]
		wolf_distance = ari.global_position.distance_to(nearest_wolf.global_position)
	var shard := _nearest_untaken_shard(ari.global_position)
	var state := {
		"npc_hp": roundi(ari_hp),
		"player_hp": roundi(player_hp),
		"player_distance": roundi(ari.global_position.distance_to(player.global_position)),
		"enemy_count": enemy_count,
		"enemy_distance": roundi(wolf_distance),
		"food_nearby": not _nearest_ready_berry(ari.global_position).is_empty(),
		"supplies": supplies,
		"night": _is_night(),
		"signal_stones_remaining": 3 - collected,
		"signal_distance": roundi(ari.global_position.distance_to(shard.global_position)) if shard != null else 999,
		"camp_distance": roundi(ari.global_position.distance_to(CAMP))
	}
	var error := ari_http.request(AI_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"agent": "ari", "state": state}))
	if error == OK:
		ari_busy = true


func _on_ari_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	ari_busy = false
	if not use_laya or result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		ari_model_age = 0.0
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.has("action"):
		ari_model_age = 0.0
		return
	var action := str(data["action"])
	if ARI_ACTIONS.has(action):
		ari_action = _safe_ari_action(action)
		ari_source = "Laya+safe" if ari_action != action else "Laya"
		ari_model_age = 6.0
	else:
		ari_model_age = 0.0


func _on_ai_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	ai_busy = false
	if not use_laya or result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		pack_model_age = 0.0
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.has("action"):
		pack_model_age = 0.0
		return
	var action := str(data["action"])
	if WOLF_ACTIONS.has(action):
		pack_action = _safe_pack_action(action)
		pack_source = "Laya+safe" if pack_action != action else "Laya"
		pack_model_age = 6.0
	else:
		pack_model_age = 0.0


func _new_night() -> void:
	for berry in berries:
		berry["ready"] = true
		var node: Node3D = berry["node"]
		node.visible = true
	for wolf_data in wolves:
		if wolf_data["hp"] <= 0:
			wolf_data["hp"] = 3
			wolf_data["stun"] = 0.0
			wolf_data["attack"] = 0.0
			var wolf: CharacterBody3D = wolf_data["node"]
			wolf.position = wolf_data["home"] + Vector3(0.0, 0.62, 0.0)
			wolf.visible = true
			var visual: WolfAvatar = wolf_data["visual"]
			visual.reset_pose()
	_say("Night falls. The berry bushes regrow; the pack returns.")


func _is_night() -> bool:
	return fmod(elapsed, 78.0) > 40.0


func _say(text: String) -> void:
	message = text
	message_time = 4.0


func _nearest_signal_target() -> Vector3:
	var shard := _nearest_untaken_shard(player.global_position)
	return shard.global_position if shard != null else CAMP


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
	ari_status_label.text = "ARI  %d HP  ·  %s" % [roundi(ari_hp), "DOWN" if ari_hp <= 0.0 else ari_action.to_upper()]
	ari_status_label.modulate = Color("ff8d80") if ari_hp <= 0.0 else Color.WHITE
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
	debug_label.text = ("WOLVES %s [%s]  /  ARI %s [%s]  /  hunger %d  fear %d  /  Laya %s" % [pack_action.to_upper(), pack_source, ari_action.to_upper(), ari_source, roundi(pack_hunger), roundi(pack_fear), "ON" if use_laya else "OFF"]) if show_debug else "Mouse look  WASD move  LMB pulse  RMB interact  Space jump  B build  L Laya  F1 debug  Esc cursor"
	end_label.text = ("THE SIGNAL IS ALIVE\nYou made it home. Press R to play again." if victory else "THE FOREST WINS\nPress R to try again.") if game_over else ""


func _nearby_interaction_text() -> String:
	var pos := player.global_position
	if collected == 3 and pos.distance_to(CAMP) < 3.5:
		return "E / RMB  ·  Complete the signal"
	if ari_hp <= 0.0 and pos.distance_to(ari.global_position) < 2.5:
		return "E / RMB  ·  Revive Ari (one supply)" if supplies > 0 else "Ari is down  ·  Find one supply"
	if pos.distance_to(CAMP) < 3.5:
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
