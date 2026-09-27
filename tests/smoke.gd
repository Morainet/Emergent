extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://scenes/forest3d.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var player: CharacterBody3D = game.get("player")
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
	var alpha: CharacterBody3D = wolves[0]["node"]
	alpha.global_position = player.global_position + Vector3(4.0, 0.0, 0.0)
	game.set("elapsed", 10.0)
	assert(game.call("_local_pack_decision") == "observe", "Daytime pack should observe nearby prey")
	game.set("elapsed", 50.0)
	assert(game.call("_local_pack_decision") == "hunt", "Nighttime pack should hunt nearby prey")
	game.set("pack_fear", 80.0)
	assert(game.call("_local_pack_decision") == "retreat", "Frightened pack should retreat")
	print("SMOKE TEST PASSED: mouse camera, cursor, collection, ward, victory, wolf decisions")
	quit(0)
