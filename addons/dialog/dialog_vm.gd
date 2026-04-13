class_name DialogVM
extends Resource

signal start
signal end
signal say(text: String)
signal do_call(identifier: String, args: Array)
signal do_choose(options: Array, labels: Array)

var cursor: int = 0

# We can load multiple dialogs
var parsed_dialogs: Dictionary = {}
var active_dialog: String = ""

var current_call_identifier: String = ""
var current_call_args: Array = []

var current_choose_options: Array = []
var current_choose_labels: Array = []

var prev_dialog: String = ""
var prev_dialog_cursor: int = 0


func load_dialog(dialog_id: String, parsed_dialog: DialogParser.ParsedDialog) -> void:
	parsed_dialogs[dialog_id] = parsed_dialog


func start_dialog(dialog_id: String, label: String = "") -> void:
	if not parsed_dialogs.has(dialog_id):
		push_error("Dialog '%s' not loaded" % dialog_id)
		return
	
	# Chewck if the label exists in the dialog
	var dialog = parsed_dialogs[dialog_id]
	if label != "" and not dialog.labels.has(label):
		push_error("Label '%s' not found in dialog '%s'" % [label, dialog_id])
		return
	
	# If a label is specified, set the cursor to that label's position
	if label != "":
		cursor = dialog.labels[label]
	else:
		cursor = 0
	
	active_dialog = dialog_id
	step()


func jump_to_label(label: String) -> void:
	if active_dialog == "":
		push_error("No active dialog")
		return
	
	var dialog = parsed_dialogs[active_dialog]
	
	if not dialog.labels.has(label):
		push_error("Label '%s' not found in dialog '%s'" % [label, active_dialog])
		return
	
	cursor = dialog.labels[label]
	step()


func change_dialog(dialog_id: String, label: String = "") -> void:
	if not parsed_dialogs.has(dialog_id):
		push_error("Dialog '%s' not loaded" % dialog_id)
		return
	
	# Check if the label exists in the new dialog
	var dialog = parsed_dialogs[dialog_id]
	if label != "" and not dialog.labels.has(label):
		push_error("Label '%s' not found in dialog '%s'" % [label, dialog_id])
		return
	
	prev_dialog = active_dialog
	prev_dialog_cursor = cursor

	active_dialog = dialog_id
	
	# If a label is specified, set the cursor to that label's position
	if label != "":
		cursor = dialog.labels[label]
	else:
		cursor = 0
	
	step()


func return_from_dialog() -> void:
	if prev_dialog == "":
		push_error("No previous dialog to return to")
		return
	
	active_dialog = prev_dialog
	
	if prev_dialog_cursor != 0:
		cursor = prev_dialog_cursor
	else:
		cursor = 0
	
	step()


func step() -> void:
	if active_dialog == "":
		push_error("No active dialog")
		return
	
	var dialog = parsed_dialogs[active_dialog]
	
	if cursor >= dialog.opcodes.size():
		push_error("Cursor out of bounds in dialog '%s'" % active_dialog)
		return
	
	# OPCODE is an array [opcode, arg_a, arg_b]
	var opcode = dialog.opcodes[cursor]

	match opcode[0]:
		DialogParser.OpCode.START:
			emit_signal("start")
			cursor += 1
			step()
		
		DialogParser.OpCode.END:
			emit_signal("end")
		
		DialogParser.OpCode.SAY:
			cursor += 1
			emit_signal("say", get_string(opcode[1]))
		
		DialogParser.OpCode.START_CALL:
			current_call_identifier = get_string(opcode[1])
			current_call_args = []
			cursor += 1
			step()
		
		DialogParser.OpCode.ADD_CALL_ARG:
			current_call_args.append(get_string(opcode[1]))
			cursor += 1
			step()
		
		DialogParser.OpCode.EXECUTE_CALL:
			cursor += 1
			emit_signal("do_call", current_call_identifier, current_call_args)
		
		DialogParser.OpCode.START_CHOOSE:
			current_choose_options = []
			current_choose_labels = []
			cursor += 1
			step()
		
		DialogParser.OpCode.ADD_CHOOSE_OPTION:
			current_choose_options.append(get_string(opcode[1]))
			current_choose_labels.append(get_string(opcode[2]))
			cursor += 1
			step()
		
		DialogParser.OpCode.EXECUTE_CHOOSE:
			cursor += 1
			emit_signal("do_choose", current_choose_options, current_choose_labels)
	


func get_string(index: int) -> String:
	if active_dialog == "":
		push_error("No active dialog")
		return ""
	
	var dialog = parsed_dialogs[active_dialog]
	
	if index < 0 or index >= dialog.strings.size():
		push_error("String index out of bounds in dialog '%s': %d" % [active_dialog, index])
		return ""
	
	return dialog.strings[index]
