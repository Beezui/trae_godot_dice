@tool
class_name DialogFormatLoader
extends ResourceFormatLoader

const FILE_EXTENSIONS: Array = ["dialog"]

var dialog_parser := DialogParser.new()


func _get_recognized_extensions() -> PackedStringArray:
	"""Return the file extensions this loader handles"""
	return PackedStringArray(FILE_EXTENSIONS)


func _handles_type(type: StringName) -> bool:
	"""Check if this loader handles the given resource type"""
	return type == "Resource"


func _get_resource_type(path: String) -> String:
	"""Return the resource type for the given path"""
	if path.get_extension().to_lower() in FILE_EXTENSIONS:
		return "Resource"
	return ""


func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Failed to open dialog file: %s" % path)
		return ERR_FILE_NOT_FOUND
	
	var content: String = file.get_as_text()
	file.close()

	# Create a new Resource to hold the dialog content
	var dialog_resource = DialogResource.new()

	dialog_resource.resource_path = path
	dialog_resource.dialog_id = path.get_file().get_basename() # Use filename without extension as dialog ID
	dialog_resource.raw_dialog = content
	dialog_resource.parsed_dialog = dialog_parser.parse(content)

	#dialog_parser.print_debug()

	if dialog_parser.error:
		return null
	
	return dialog_resource
