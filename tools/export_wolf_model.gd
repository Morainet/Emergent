extends SceneTree


func _initialize() -> void:
	call_deferred("_export")


func _export() -> void:
	var avatar: WolfAvatar = load("res://scenes/wolf_avatar.tscn").instantiate()
	root.add_child(avatar)
	# The floating state lamp is HUD feedback, not part of the wolf model asset.
	avatar.mood_marker.get_parent().remove_child(avatar.mood_marker)
	avatar.mood_marker.free()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error := document.append_from_scene(avatar, state)
	if append_error != OK:
		push_error("Wolf GLB export failed while collecting scene: %d" % append_error)
		quit(1)
		return
	var output_path := "res://assets/models/wolf_lowpoly.glb"
	var save_error := document.write_to_filesystem(state, output_path)
	if save_error != OK:
		push_error("Wolf GLB export failed while saving: %d" % save_error)
		quit(1)
		return
	print("WOLF MODEL EXPORTED: ", output_path)
	quit(0)
