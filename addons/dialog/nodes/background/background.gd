extends Control


func _ready() -> void:
	visible = true
	Dialog.update_background.connect(_on_dialog_update_background)


func _on_dialog_update_background(background: String, transition: String) -> void:
	var current_background = get_child(0) if get_child_count() > 0 else null

	if background == "none":
		if current_background != null:
			await get_tree().create_tween().tween_property(current_background, "modulate:a", 0.0, 1.0).finished
			current_background.queue_free() # Remove current background
			Dialog.step() # Continue dialog after updating background
		return

	var new_background_texture = load(background)

	if new_background_texture == null:
		push_error("Failed to load background texture: %s" % background)
		return
	
	var new_background = TextureRect.new()

	new_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	new_background.texture = new_background_texture
	new_background.modulate.a = 0.0 # Start invisible for fade-in

	new_background.set_anchors_preset(Control.PRESET_FULL_RECT)

	add_child(new_background)

	await get_tree().create_tween().tween_property(new_background, "modulate:a", 1.0, 1.0).finished

	if current_background != null:
		remove_child(current_background) # Detach old background before freeing to avoid issues with tweening
		current_background.queue_free() # Remove old background after transition
	
	Dialog.step() # Continue dialog after updating background
