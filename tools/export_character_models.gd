extends SceneTree


func _initialize() -> void:
	call_deferred("_export")


func _export() -> void:
	for character in ["explorer", "ari"]:
		var scene_path := "res://scenes/%s_avatar.tscn" % character
		var avatar: ExplorerAvatar = load(scene_path).instantiate()
		root.add_child(avatar)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var append_error := document.append_from_scene(avatar, state)
		if append_error != OK:
			push_error("%s GLB scene collection failed: %d" % [character, append_error])
			quit(1)
			return
		var output_path := "res://assets/models/%s_lowpoly.glb" % character
		var save_error := document.write_to_filesystem(state, output_path)
		if save_error != OK:
			push_error("%s GLB save failed: %d" % [character, save_error])
			quit(1)
			return
		print("CHARACTER MODEL EXPORTED: ", output_path)
		avatar.free()
	quit(0)
