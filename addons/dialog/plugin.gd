@tool
extends EditorPlugin

const SINGLETOM_NAME: String = "Dialog"
const SINGLETOM_PATH: String = "res://addons/dialog/dialog_singleton.gd"

const GETTEXT_LOCALIZATION_PARSER_PATH: String = "res://addons/dialog/dialog_gettext_parser.gd"


var _resource_loader: DialogFormatLoader = null
var _gettext_parser: DialogGettextParser = null
var _syntax_highlighter: DialogSyntaxHighlighter = null


func _enter_tree() -> void:
	add_autoload_singleton(SINGLETOM_NAME, SINGLETOM_PATH)

	# Register the resource loader if it's not already registered
	if not _resource_loader:
		_resource_loader = DialogFormatLoader.new()
		ResourceLoader.add_resource_format_loader(_resource_loader)

	# Register the gettext parser if it's not already registered
	if not _gettext_parser:
		_gettext_parser = DialogGettextParser.new()
		add_translation_parser_plugin(_gettext_parser)
	
	# Register the syntax highlighter for dialog files
	if not _syntax_highlighter:
		_syntax_highlighter = DialogSyntaxHighlighter.new()
		var script_editor := get_editor_interface().get_script_editor()
		script_editor.register_syntax_highlighter(_syntax_highlighter)


func _exit_tree() -> void:
	remove_autoload_singleton(SINGLETOM_NAME)

	# Unregister the resource loader
	if _resource_loader:
		ResourceLoader.remove_resource_format_loader(_resource_loader)
		_resource_loader = null
	
	# Unregister the gettext parser
	if _gettext_parser:
		remove_translation_parser_plugin(_gettext_parser)
		_gettext_parser = null

	# Unregister the syntax highlighter
	if _syntax_highlighter:
		var script_editor := get_editor_interface().get_script_editor()
		script_editor.unregister_syntax_highlighter(_syntax_highlighter)
		_syntax_highlighter = null