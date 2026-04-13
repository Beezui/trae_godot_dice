extends Node

signal started(dialog_id: String)
signal ended(dialog_id: String)
signal say(text: String)
signal choose(options: Array, labels: Array)
signal update_background(background: String, transition: String)
signal update_speaker(speaker: String, speaker_id: String)
signal show_character(character_id: String, variation: String, position: String, transition: String)
signal hide_character(character_id: String, transition: String)
signal update_character(character_id: String, variation: String, transition: String)
signal move_character(character_id: String, position: String, transition: String)
signal play_sound(sound: String)
signal play_music(music: String, transition: String)
signal stop_music(transition: String)
signal unhandled_command(identifier: String, args: Array)
signal hide_dialog_box

enum {
	STATE_READY,
	STATE_RUNNING,
	STATE_WAITING,
	STATE_ENDED,
}

var debug_mode: bool = false

var dialog_vm: DialogVM = DialogVM.new()
var state: int = STATE_READY

var vars = {}

var current_speaker_id: String = "" # Track current speaker for localization purposes


func _print_debug(message: String) -> void:
	if debug_mode:
		print(message)


func _ready() -> void:
	dialog_vm.start.connect(_on_vm_start)
	dialog_vm.end.connect(_on_vm_end)
	dialog_vm.say.connect(_on_vm_say)
	dialog_vm.do_call.connect(_on_vm_do_call)
	dialog_vm.do_choose.connect(_on_vm_do_choose)

	load_dialogs_from_directory("res://")


func load_dialogs_from_directory(dir_path: String) -> void:
	"""Load all dialog resources from the specified directory"""
	var dir: DirAccess = DirAccess.open(dir_path)
	
	if dir == null:
		push_error("Failed to open directory: %s" % dir_path)
	
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() in DialogFormatLoader.FILE_EXTENSIONS:
			var full_path = "%s/%s" % [dir_path, file_name]
			load_dialog(full_path)
	
	for subdir_name in dir.get_directories():
		if subdir_name != "." and subdir_name != "..":
			var subdir_path = "%s/%s" % [dir_path, subdir_name]
			load_dialogs_from_directory(subdir_path)


func load_dialog(path: String) -> void:
	"""Load a dialog resource from the given path"""
	var resource: DialogResource = load(path)
	
	if resource == null:
		push_error("Failed to load dialog resource: %s" % path)
	
	dialog_vm.load_dialog(resource.dialog_id, resource.parsed_dialog)
	_print_debug("Loaded dialog: %s from %s" % [resource.dialog_id, path])


func start(dialog_id: String, label: String = "") -> void:
	"""Start a dialog by its ID and optional label"""
	state = STATE_RUNNING
	dialog_vm.start_dialog(dialog_id, label)


func step() -> void:
	"""Advance the active dialog to the next instruction"""
	if state == STATE_ENDED or state == STATE_WAITING:
		return
	
	dialog_vm.step()


func jump(label: String) -> void:
	"""Jump to a specific label in the active dialog"""
	if state == STATE_ENDED:
		return
	
	dialog_vm.jump_to_label(label)


func _replace_vars(text: String) -> String:
	"""Replace variable placeholders in the given text with their current values"""
	for var_name in vars.keys():
		var placeholder = "{%s}" % var_name
		if placeholder in text:
			text = text.replace(placeholder, str(vars.get(var_name, placeholder)))
	return text


func _on_vm_start() -> void:
	_print_debug("Dialog started: %s" % dialog_vm.active_dialog)
	emit_signal("started", dialog_vm.active_dialog)


func _on_vm_end() -> void:
	hide_dialog_box.emit() # Hide dialog box when dialog ends

	_print_debug("Dialog ended: %s" % dialog_vm.active_dialog)
	state = STATE_ENDED
	emit_signal("ended", dialog_vm.active_dialog)


func _on_vm_say(text: String) -> void:
	text = tr(text, current_speaker_id) # Localize text using Godot's translation system
	text = _replace_vars(text) # Replace variable placeholders with current values
	_print_debug("Dialog says: %s" % text)
	emit_signal("say", text)


func _on_vm_do_choose(options: Array, labels: Array) -> void:
	for i in range(options.size()):
		options[i] = tr(options[i]) # Localize options using Godot's translation system

	if debug_mode:
		_print_debug("Dialog presents choices:")
		for i in range(options.size()):
			_print_debug("  Option %d: %s -> %s" % [i, options[i], labels[i]])
	
	emit_signal("choose", options, labels)


func _on_vm_do_call(identifier: String, args: Array) -> void:
	_print_debug("Dialog calls: %s with args %s" % [identifier, args])

	match identifier:
		"wait":
			if args.size() != 1:
				push_error("Invalid number of arguments for 'wait' call: expected 1, got %d" % args.size())
				return
			
			var duration = args[0].to_float()
			_print_debug("Dialog waits for %f seconds" % duration)
			
			state = STATE_WAITING
			await get_tree().create_timer(duration).timeout
			state = STATE_RUNNING

			dialog_vm.step() # Continue dialog after waiting
		
		"background":
			if args.size() < 1:
				push_error("Invalid number of arguments for 'background' call: expected at least 1, got %d" % args.size())
				return
			
			var background_name = vars.get(args[0], args[0]) # Resolve variable if exists, otherwise use raw value
			var transition = args[1] if args.size() > 1 else ""
			_print_debug("Dialog updates background to: %s with transition %s" % [background_name, transition])
			emit_signal("update_background", background_name, transition)
		
		"speaker":
			if args.size() != 1:
				push_error("Invalid number of arguments for 'speaker' call: expected 1, got %d" % args.size())
				return
			
			var speaker_name = args[0]

			current_speaker_id = speaker_name if speaker_name != "_" else "" # Update current speaker for localization

			emit_signal("update_speaker", vars.get(speaker_name, speaker_name), speaker_name) # Resolve variable if exists, otherwise use raw value
			dialog_vm.step() # Continue dialog after updating speaker
		
		"show":
			if args.size() == 0:
				push_error("Invalid number of arguments for 'show' call: expected 1 at least, got %d" % args.size())
				return
			
			var character_id = args[0]
			var variation = args[1] if args.size() > 1 else ""
			var position = args[2] if args.size() > 2 else ""
			var transition = args[3] if args.size() > 3 else ""

			_print_debug("Dialog shows character: %s with variation %s at position %s with transition %s" % [character_id, variation, position, transition])
			emit_signal("show_character", character_id, variation, position, transition)
		
		"hide":
			if args.size() == 0:
				push_error("Invalid number of arguments for 'hide' call: expected 1 at least, got %d" % args.size())
				return
			
			var character_id = args[0]
			var transition = args[1] if args.size() > 1 else ""

			_print_debug("Dialog hides character: %s with transition %s" % [character_id, transition])
			emit_signal("hide_character", character_id, transition)
		
		"update":
			if args.size() == 0:
				push_error("Invalid number of arguments for 'update' call: expected 1 at least, got %d" % args.size())
				return
			
			var character_id = args[0]
			var variation = args[1] if args.size() > 1 else ""
			var transition = args[2] if args.size() > 2 else ""

			_print_debug("Dialog updates character: %s with variation %s with transition %s" % [character_id, variation, transition])
			emit_signal("update_character", character_id, variation, transition)
		
		"move":
			if args.size() == 0:
				push_error("Invalid number of arguments for 'move' call: expected 1 at least, got %d" % args.size())
				return
			
			var character_id = args[0]
			var position = args[1] if args.size() > 1 else ""
			var transition = args[2] if args.size() > 2 else ""

			_print_debug("Dialog moves character: %s to position %s with transition %s" % [character_id, position, transition])
			emit_signal("move_character", character_id, position, transition)
		
		"jump":
			if args.size() != 1:
				push_error("Invalid number of arguments for 'jump' call: expected 1, got %d" % args.size())
				return
			
			var label = args[0]
			_print_debug("Dialog jumps to label: %s" % label)
			dialog_vm.jump_to_label(label)
		
		"dialog":
			if args.size() == 0:
				push_error("Invalid number of arguments for 'change_dialog' call: expected at least 1, got %d" % args.size())
				return
			
			var dialog_id = args[0]
			var label = args[1] if args.size() > 1 else ""
			_print_debug("Dialog changes to dialog: %s with label %s" % [dialog_id, label])
			dialog_vm.change_dialog(dialog_id, label)
		
		"return":
			_print_debug("Dialog returns to previous jump")
			dialog_vm.return_from_dialog()
		
		"play_sound":
			if args.size() != 1:
				push_error("Invalid number of arguments for 'play_sound' call: expected 1, got %d" % args.size())
				return
			
			var sound_id = vars.get(args[0], args[0]) # Resolve variable if exists, otherwise use raw value
			_print_debug("Dialog plays sound: %s" % sound_id)
			emit_signal("play_sound", sound_id)
			dialog_vm.step() # Continue dialog after playing sound
		
		"play_music":
			if args.size() < 1:
				push_error("Invalid number of arguments for 'play_music' call: expected at least 1, got %d" % args.size())
				return
			
			var music_id = vars.get(args[0], args[0]) # Resolve variable if exists, otherwise use raw value
			var transition = args[1] if args.size() > 1 else ""
			_print_debug("Dialog plays music: %s with transition %s" % [music_id, transition])
			emit_signal("play_music", music_id, transition)
			dialog_vm.step() # Continue dialog after playing music
		
		"stop_music":
			var transition = args[0] if args.size() > 0 else "default"
			_print_debug("Dialog stops music with transition %s" % transition)
			emit_signal("stop_music", transition)
			dialog_vm.step() # Continue dialog after stopping music
		
		"set":
			if args.size() != 2:
				push_error("Invalid number of arguments for 'set' call: expected 2, got %d" % args.size())
				return
			
			var var_name = args[0]
			var var_value = args[1]
			vars[var_name] = var_value
			_print_debug("Dialog sets variable '%s' to '%s'" % [var_name, var_value])
			dialog_vm.step() # Continue dialog after setting variable
		
		"hide_dialog":
			_print_debug("Dialog hides dialog box")
			hide_dialog_box.emit()
		
		_:
			_print_debug("Unknown call identifier: %s" % identifier)
			emit_signal("unhandled_command", identifier, args)
