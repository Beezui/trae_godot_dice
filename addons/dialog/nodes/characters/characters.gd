extends Control

@onready var most_left_marker: Control = %MostLeftMarker
@onready var left_marker: Control = %LeftMarker
@onready var center_marker: Control = %CenterMarker
@onready var right_marker: Control = %RightMarker
@onready var most_right_marker: Control = %MostRightMarker

var character_instances: Dictionary = {} # Dictionary to track character instances by character_id


func _ready() -> void:
	visible = true
	Dialog.update_speaker.connect(_on_dialog_update_speaker)
	Dialog.show_character.connect(_on_dialog_show_character)
	Dialog.hide_character.connect(_on_dialog_hide_character)
	Dialog.update_character.connect(_on_dialog_update_character)
	Dialog.move_character.connect(_on_dialog_move_character)


func _get_position(position_string: String) -> Vector2:
	match position_string:
		"most_left":
			return most_left_marker.global_position
		"left":
			return left_marker.global_position
		"center":
			return center_marker.global_position
		"right":
			return right_marker.global_position
		"most_right":
			return most_right_marker.global_position
		_:
			return Vector2.ZERO


func _on_dialog_update_speaker(speaker: String, speaker_id: String) -> void:
	for character_id in character_instances.keys():
		var character = character_instances[character_id]
		var tween = get_tree().create_tween()
		
		if character_id == speaker_id:
			tween.tween_property(character, "scale", Vector2(1.05, 1.05), 0.2) # Bring current speaker character to front
			tween.parallel().tween_property(character, "modulate", Color(1, 1, 1), 0.2) # Brighten current speaker character
		else:
			tween.tween_property(character, "scale", Vector2(1.0, 1.0), 0.2) # Reset scale for non-speaking characters
			tween.parallel().tween_property(character, "modulate", Color(0.6, 0.6, 0.6), 0.2) # Dim non-speaking characters


func _on_dialog_show_character(character_id: String, variation: String, position: String, transition: String) -> void:
	var position_vector: Vector2 = _get_position(position)
	if position_vector == Vector2.ZERO:
		push_error("Invalid character position: %s" % position)
		return
	
	var character_texture_path = Dialog.vars.get("%s_%s" % [character_id, variation], "") # Resolve character texture from variables
	if character_texture_path == "":
		push_error("Character texture not found for character_id: %s, variation: %s" % [character_id, variation])
		return
	
	var character_texture = load(character_texture_path)
	if character_texture == null:
		push_error("Failed to load character texture: %s" % character_texture_path)
		return
	
	var character = TextureRect.new()
	character.texture = character_texture
	character.modulate.a = 0.0
	character.global_position = position_vector - Vector2(character.texture.get_size().x * 0.5, character.texture.get_size().y) # Center character on position
	character.pivot_offset_ratio = Vector2(0.5, 1.0) # Set pivot to bottom center for better positioning
	
	add_child(character)

	await get_tree().create_tween().tween_property(character, "modulate:a", 1.0, 1.0).finished # Fade in character

	character_instances[character_id] = character # Track character instance

	Dialog.step() # Continue dialog after showing character


func _on_dialog_hide_character(character_id: String, transition: String) -> void:
	# This function can be used to hide character portraits based on character_id if desired
	if not character_instances.has(character_id):
		push_error("Attempted to hide character that is not currently shown: %s" % character_id)
		return
	
	var character = character_instances[character_id]
	await get_tree().create_tween().tween_property(character, "modulate:a", 0.0, 1.0).finished # Fade out character
	character.queue_free() # Remove character after fading out
	character_instances.erase(character_id) # Remove from tracking dictionary

	Dialog.step() # Continue dialog after hiding character


func _on_dialog_update_character(character_id: String, variation: String, transition: String) -> void:
	# just update the character's texture based on the new variation
	if not character_instances.has(character_id):
		push_error("Attempted to update character that is not currently shown: %s" % character_id)
		return
	
	var character_texture_path = Dialog.vars.get("%s_%s" % [character_id, variation], "") # Resolve character texture from variables
	if character_texture_path == "":
		push_error("Character texture not found for character_id: %s, variation: %s" % [character_id, variation])
		return
	
	var character_texture = load(character_texture_path)
	if character_texture == null:
		push_error("Failed to load character texture: %s" % character_texture_path)
		return
	
	var current_character = character_instances[character_id]
	var new_character: TextureRect = current_character.duplicate()

	new_character.texture = character_texture
	new_character.modulate.a = 0.0

	add_child(new_character)

	await get_tree().create_tween().tween_property(new_character, "modulate:a", 1.0, 0.3).finished # Fade in new variation
	current_character.queue_free() # Remove old variation after fading in new one
	character_instances[character_id] = new_character # Update tracking dictionary with new character instance
	
	Dialog.step() # Continue dialog after updating character


func _on_dialog_move_character(character_id: String, position: String, transition: String) -> void:
	if not character_instances.has(character_id):
		push_error("Attempted to move character that is not currently shown: %s" % character_id)
		return

	var character = character_instances[character_id]
	var new_position = _get_position(position)

	if new_position == Vector2.ZERO:
		push_error("Invalid character position: %s" % position)
		return
	
	var tween = get_tree().create_tween()
	tween.tween_property(character, "global_position:x", new_position.x - character.texture.get_size().x * 0.5, 0.3)
	await tween.finished

	Dialog.step() # Continue dialog after moving character
