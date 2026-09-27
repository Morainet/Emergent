extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://scenes/forest3d.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var player: CharacterBody3D = game.get("player")
	var ari: CharacterBody3D = game.get("ari")
	assert(ari.name == "Ari" and ari.get_node("AriAvatar") != null, "Ari should spawn beside the camp")
	assert(game.call("_local_ari_decision") == "explore", "Healthy Ari should guide exploration")
	var navigator: ForestNavigator = game.get("ari_navigator")
	var detour := navigator.route(Vector3(-25.0, 1.0, -12.0), Vector3(-17.0, 1.0, -12.0))
	assert(not detour.is_empty(), "Ari should have a route across the forest")
	var bends_around_tree := false
	for point in detour:
		if absf(point.z + 12.0) > 0.5:
			bends_around_tree = true
		assert(not navigator.grid.is_point_solid(navigator._world_to_id(point)), "Ari's route must avoid solid tree cells")
	assert(bends_around_tree, "Ari should detour around a tree directly between start and goal")
	var escape_route := navigator.route(Vector3(-21.0, 1.0, -12.0), Vector3(-17.0, 1.0, -12.0))
	assert(not escape_route.is_empty(), "Ari should find an exit if spawned in a blocked tree cell")
	assert(not navigator.grid.is_point_solid(navigator._world_to_id(escape_route.front())), "The first escape waypoint should be walkable")
	assert(not navigator.route(Vector3(29.0, 1.0, 29.0), Vector3(-29.0, 1.0, -29.0)).is_empty(), "Routes should clamp to map bounds")
	var avatar: Node3D = player.get_node("ExplorerAvatar")
	assert(avatar.get_node("LeftLeg") != null and avatar.get_node("RightLeg") != null, "Explorer should have animated legs")
	assert(avatar.get_node("LeftArm") != null and avatar.get_node("RightArm") != null, "Explorer should have animated arms")
	avatar.call("animate", 1.0, 7.0, 0.0)
	assert(absf(avatar.get_node("LeftLeg").rotation.x) > 0.3, "Explorer should step when moving")
	avatar.call("animate", 1.0, 0.0, 0.0)
	assert(is_zero_approx(avatar.get_node("LeftLeg").rotation.x), "Explorer should stand still when idle")
	avatar.call("animate", 1.0, 0.0, 0.0, 5.0, false)
	assert(avatar.get_node("LeftLeg").rotation.x < -0.2, "Explorer should tuck a leg while jumping")
	avatar.call("play_action", "interact")
	avatar.call("animate", 1.0, 0.0, 0.0, 0.0, true, 0.1)
	avatar.call("animate", 1.1, 0.0, 0.0, 0.0, true, 0.1)
	assert(avatar.get_node("RightArm").rotation.x < -0.5, "Explorer should reach out to interact")
	avatar.call("play_action", "pulse")
	avatar.call("animate", 1.0, 0.0, 0.0, 0.0, true, 0.1)
	avatar.call("animate", 1.1, 0.0, 0.0, 0.0, true, 0.1)
	assert(avatar.get_node("LeftArm").rotation.x < -0.3, "Pulse should lift both arms")
	var player_jacket_textured := false
	for part in avatar.get_children():
		if part is MeshInstance3D and part.material_override.albedo_texture == load("res://assets/characters/explorer_canvas.png"):
			player_jacket_textured = true
	assert(player_jacket_textured, "Player jacket should use its fabric texture")
	var ari_jacket_textured := false
	for part in ari.get_node("AriAvatar").get_children():
		if part is MeshInstance3D and part.material_override.albedo_texture == load("res://assets/characters/ari_canvas.png"):
			ari_jacket_textured = true
	assert(ari_jacket_textured, "Ari should use a distinct fabric texture")
	var ground: StaticBody3D = game.get_child(2)
	var ground_mesh: MeshInstance3D = ground.get_child(0)
	assert(ground_mesh.material_override.albedo_texture != null, "Forest ground texture should load")
	var textured_canopy_count := 0
	var tapered_trunk_count := 0
	for world_child in game.get_children():
		if world_child is MeshInstance3D and world_child.material_override.albedo_texture == load("res://assets/textures/pine_canopy.png"):
			textured_canopy_count += 1
		if world_child is StaticBody3D and world_child.get_child_count() > 0 and world_child.get_child(0) is MeshInstance3D:
			var trunk_mesh = world_child.get_child(0).mesh
			if trunk_mesh is CylinderMesh and trunk_mesh.bottom_radius > trunk_mesh.top_radius:
				tapered_trunk_count += 1
	assert(textured_canopy_count >= 160, "Trees should have layered, textured crowns and side branches")
	assert(tapered_trunk_count == 20, "Every tree should have a tapered trunk")
	var paths: Array = game.get("trail_paths")
	var sites: Array = game.get_script().get_script_constant_map()["SHARD_SITES"]
	var trees: Array = game.get("forest_tree_positions")
	assert(paths.size() == 3, "Map should have one trail per signal site")
	for i in paths.size():
		var path: PackedVector2Array = paths[i]
		assert(path[0] == Vector2.ZERO, "Each trail should leave the camp")
		assert(path[path.size() - 1].distance_to(Vector2(sites[i].x, sites[i].z)) < 0.1, "Each trail should reach its signal site")
		for j in range(path.size() - 1):
			var a: Vector2 = path[j]
			var segment: Vector2 = path[j + 1] - a
			for tree in trees:
				var t := clampf((tree - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
				assert(tree.distance_to(a + segment * t) > 1.1, "A marked trail should not run through a tree")
	var details: Node3D = game.get("map_details")
	assert(details.name == "MapDetails" and details.get_child_count() > 100, "Map landmarks and undergrowth should be present")
	var textured_trail := false
	var ribbon_count := 0
	for detail in details.get_children():
		assert(detail is MeshInstance3D, "Map dressing must not introduce collision bodies")
		if detail.material_override is StandardMaterial3D and detail.material_override.albedo_texture == load("res://assets/textures/trail_earth.png"):
			textured_trail = true
			assert(detail.mesh is ArrayMesh and detail.material_override.vertex_color_use_as_albedo, "Trails should be blended ribbon meshes")
			var colors: PackedColorArray = detail.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			var has_soft_edge := false
			for color in colors:
				if color.a < 0.1:
					has_soft_edge = true
					break
			assert(has_soft_edge, "Trail edges should fade into the forest floor")
			ribbon_count += 1
	assert(textured_trail, "A trail should use the new earth texture")
	assert(ribbon_count == 3, "Each destination should have one continuous trail ribbon")
	var icons: Array = game.get("shard_icons")
	assert(icons.size() == 3, "HUD should show three signal stone icons")
	assert(icons[0].texture != null, "Signal stone icon should load")
	var pulse_ring: MeshInstance3D = game.get("pulse_ring")
	assert(not pulse_ring.visible, "Pulse ring should start hidden")
	game.call("_pulse")
	assert(pulse_ring.visible and game.get("pulse_cooldown") == 4.0, "Pulse should show its ring and start cooldown")
	game.call("_update_ui")
	var scan_panel: ColorRect = game.get("scan_panel")
	var scan_label: Label = game.get("scan_label")
	assert(scan_panel.visible and scan_label.text.contains("SIGNAL ECHO"), "Pulse should reveal a temporary signal scan")
	var player_pos := player.global_position
	assert(game.call("_scan_bearing", player_pos + Vector3(0.0, 0.0, -10.0), 0.0) == "AHEAD", "Scan bearing should follow camera forward")
	assert(game.call("_scan_bearing", player_pos + Vector3(10.0, 0.0, 0.0), 0.0) == "RIGHT", "Scan bearing should report camera right")
	game.set("scan_time", 0.0)
	game.call("_update_ui")
	assert(not scan_panel.visible, "Scan should disappear after its timer")
	var pulse_fill: ColorRect = game.get("pulse_fill")
	assert(is_zero_approx(pulse_fill.size.x), "Pulse bar should empty after firing")
	game.set("pulse_visual", 0.2)
	game.call("_update_pulse_effect")
	assert(pulse_ring.scale.x > 2.0, "Pulse ring should expand over time")
	game.set("pulse_visual", 0.0)
	game.call("_update_pulse_effect")
	assert(not pulse_ring.visible, "Pulse ring should disappear after the effect")
	game.set("pulse_cooldown", 0.0)
	game.call("_update_ui")
	assert(is_equal_approx(pulse_fill.size.x, 175.0), "Pulse bar should refill when ready")
	var forward: Vector3 = game.call("_movement_direction", Vector2(0.0, -1.0), 0.0)
	var turned: Vector3 = game.call("_movement_direction", Vector2(0.0, -1.0), PI / 2.0)
	assert(forward.distance_to(Vector3(0.0, 0.0, -1.0)) < 0.01, "W should move toward camera forward")
	assert(turned.distance_to(Vector3(-1.0, 0.0, 0.0)) < 0.01, "Movement should rotate with camera yaw")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100.0, -50.0)
	game.call("_unhandled_input", motion)
	assert(game.get("camera_yaw") < -0.2, "Mouse movement should rotate the camera")
	assert(game.get("camera_pitch") > 0.6, "Mouse movement should tilt the camera")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game.call("_unhandled_input", escape)
	assert(game.get("mouse_captured") == false, "Escape should release the cursor")
	var stones: Array = game.get("shards")
	for stone in stones:
		var node: Node3D = stone["node"]
		player.global_position = node.global_position + Vector3(0.0, 0.8, 0.0)
		game.call("_interact")
	assert(game.get("collected") == 3, "All signal stones should be collectible")
	assert(game.call("_scan_text").contains("CAMP ECHO"), "Scan should point back to camp after all stones")
	game.call("_update_ui")
	assert(icons[2].modulate.a > 0.9, "Collected signal stones should light up in HUD")
	player.global_position = Vector3(0.0, 1.0, 0.0)
	game.set("supplies", 2)
	game.call("_build_ward")
	assert(game.get("ward_built") == true, "Two supplies should build a camp ward")
	assert(game.get("supplies") == 0, "Ward should consume supplies")
	game.call("_interact")
	assert(game.get("victory") == true, "Returning to camp should complete the game")
	game.set("victory", false)
	game.set("game_over", false)
	game.set("ward_built", false)
	game.set("pack_fear", 0.0)
	var wolves: Array = game.get("wolves")
	var alpha_data: Dictionary = wolves[0]
	assert(game.call("_wolf_signal_color", "hunt", false) == Color("ff806b"), "Hunting wolves should show a red warning")
	assert(game.call("_wolf_signal_color", "observe", false) == Color("f3c578"), "Watching wolves should show gold")
	assert(game.call("_wolf_signal_color", "retreat", false) == Color("8fb7ef"), "Retreating wolves should show blue")
	alpha_data["stun"] = 1.0
	game.call("_update_wolf_signal", alpha_data)
	var marker: MeshInstance3D = alpha_data["mood_marker"]
	assert(marker.material_override.albedo_color == Color("7eece2"), "Stunned wolves should show cyan")
	alpha_data["stun"] = 0.0
	var alpha: CharacterBody3D = wolves[0]["node"]
	alpha.global_position = player.global_position + Vector3(4.0, 0.0, 0.0)
	game.set("elapsed", 10.0)
	assert(game.call("_local_pack_decision") == "observe", "Daytime pack should observe nearby prey")
	game.set("elapsed", 50.0)
	assert(game.call("_local_pack_decision") == "hunt", "Nighttime pack should hunt nearby prey")
	game.set("pack_fear", 80.0)
	assert(game.call("_local_pack_decision") == "retreat", "Frightened pack should retreat")
	game.set("pack_fear", 0.0)
	game.set("elapsed", 10.0)
	alpha.global_position = Vector3(22.0, 1.0, 22.0)
	game.set("player_hp", 50.0)
	assert(game.call("_local_ari_decision") == "gather", "Ari should seek food when the player is hurt")
	game.set("player_hp", 100.0)
	var berries: Array = game.get("berries")
	var berry: Dictionary = berries[0]
	var bush: Node3D = berry["node"]
	ari.global_position = bush.global_position + Vector3(0.0, 1.0, 0.0)
	game.set("ari_action", "gather")
	game.call("_update_ari", 0.016)
	assert(not berry["ready"] and game.get("supplies") == 1, "Ari should deliver a gathered supply")
	ari.global_position = Vector3(12.0, 1.0, 12.0)
	alpha.global_position = ari.global_position + Vector3(3.0, 0.0, 0.0)
	alpha_data["stun"] = 0.0
	game.set("ari_defend_cooldown", 0.0)
	game.set("ari_action", "defend")
	game.call("_update_ari", 0.016)
	assert(alpha_data["stun"] > 1.0 and game.get("ari_defend_cooldown") > 7.0, "Ari should repel a close wolf")
	game.set("ari_hp", 30.0)
	assert(game.call("_safe_ari_action", "defend") == "hide", "Low-health Ari must not obey a reckless defend decision")
	game.set("ari_hp", 100.0)
	game.set("ari_defend_cooldown", 0.0)
	alpha.global_position = ari.global_position + Vector3(1.0, 0.0, 0.0)
	alpha_data["attack"] = 0.0
	alpha_data["stun"] = 0.0
	player.global_position = Vector3(-20.0, 1.0, -20.0)
	game.set("pack_action", "hunt")
	game.call("_update_wolves", 0.016)
	assert(game.get("ari_hp") == 87.0, "A wolf should be able to wound Ari")
	game.set("ari_hp", 0.0)
	player.global_position = ari.global_position + Vector3(0.0, 0.0, 1.0)
	game.call("_interact")
	assert(game.get("ari_hp") == 45.0 and game.get("supplies") == 0, "One supply should revive Ari")
	alpha.global_position = Vector3(-25.0, 1.0, -25.0)
	game.set("use_laya", true)
	game.call("_on_ari_response", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"action": "return"}).to_utf8_buffer())
	assert(game.get("ari_source") == "Laya" and game.get("ari_model_age") == 6.0, "A valid Laya response should control Ari")
	game.call("_on_ari_response", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"action": "unknown"}).to_utf8_buffer())
	assert(game.get("ari_model_age") == 0.0, "Invalid Laya actions should expire before local fallback")
	game.set("pack_fear", 80.0)
	game.call("_on_ai_response", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"action": "hunt"}).to_utf8_buffer())
	assert(game.get("pack_action") == "retreat", "A frightened pack must not obey a reckless Laya hunt decision")
	assert(game.get("pack_source") == "Laya+safe", "Debug output should disclose a guarded model decision")
	game.set("ari_hp", 0.0)
	ari.global_position = Vector3(1.0, 1.0, 0.0)
	game.call("_update_ari", 0.1)
	assert((ari.get_node("AriAvatar") as Node3D).rotation.z > 0.0, "Downed Ari should visibly fall")
	player.global_position = Vector3(0.0, 1.0, 0.0)
	game.set("victory", false)
	game.set("game_over", false)
	assert(game.call("_nearby_interaction_text").contains("Complete"), "Victory should take priority over reviving Ari at camp")
	game.call("_interact")
	assert(game.get("victory"), "Ari falling at camp must not block victory")
	for wolf_data in wolves:
		wolf_data["hp"] = 0
	assert(game.call("_safe_pack_action", "hunt") == "roam", "A defeated wolf pack must not keep hunting")
	print("SMOKE TEST PASSED: Ari companion, signal scanner, pulse feedback, wolf signals, avatar animation, textures, HUD icons, movement, collection, ward, victory, wolf decisions")
	quit(0)
