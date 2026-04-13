@tool
extends EditorSyntaxHighlighter

class_name DialogSyntaxHighlighter


func _get_name() -> String:
	return "Dialog Script"


func _get_supported_languages() -> PackedStringArray:
	return ["dialog"]


func _get_line_syntax_highlighting(p_line: int) -> Dictionary:
	var color_map := {}
	var line: String = get_text_edit().get_line(p_line)
	
	# Skip empty lines
	if line.is_empty():
		return color_map
	
	# Get color scheme from editor settings
	var editor_settings := EditorInterface.get_editor_settings()
	var comment_color := editor_settings.get_setting("text_editor/theme/highlighting/comment_color")
	var string_color := editor_settings.get_setting("text_editor/theme/highlighting/string_color")
	var keyword_color := editor_settings.get_setting("text_editor/theme/highlighting/keyword_color")
	var control_flow_color := editor_settings.get_setting("text_editor/theme/highlighting/control_flow_keyword_color")
	var text_color := editor_settings.get_setting("text_editor/theme/highlighting/text_color")
	var symbol_color := editor_settings.get_setting("text_editor/theme/highlighting/symbol_color")
	var engine_type_color := editor_settings.get_setting("text_editor/theme/highlighting/engine_type_color")
	
	# Comment highlighting
	if line.begins_with("#"):
		color_map[0] = { "color": comment_color }
		return color_map
	
	var cursor := 0
	
	if line.begins_with("\n") or line.begins_with("\r\n") or line.begins_with("\t"):
		color_map[0] = { "color": text_color }
		# looks for vars { foo }
		while cursor < line.length():
			var char := line[cursor]
			if char == "{":
				var end_brace := line.find("}", cursor + 1)
				if end_brace == -1:
					end_brace = line.length()
				color_map[cursor] = { "color": engine_type_color }
				color_map[end_brace + 1] = { "color": text_color }
				cursor = end_brace + 1
			else:
				cursor += 1
		return color_map

	while cursor < line.length():
		var char := line[cursor]
		
		# String highlighting
		if char == "\"":
			var end_quote := line.find("\"", cursor + 1)
			if end_quote == -1:
				end_quote = line.length()
			color_map[cursor] = { "color": string_color }
			color_map[end_quote + 1] = { "color": text_color }
			cursor = end_quote + 1
			continue
		
		# Number highlighting
		if _is_digit_or_dot(char):
			var start := cursor
			while cursor < line.length() and _is_digit_or_dot(line[cursor]):
				cursor += 1
			color_map[start] = { "color": symbol_color }
			color_map[cursor] = { "color": text_color }
			continue
		
		# Keyword highlighting
		if _is_valid_identifier_char(char):
			var start := cursor
			while cursor < line.length() and _is_valid_identifier_char(line[cursor]):
				cursor += 1
			var word := line.substr(start, cursor - start)
			if _is_keyword(word):
				color_map[start] = { "color": keyword_color }
				color_map[cursor] = { "color": text_color }
			else:
				color_map[start] = { "color": control_flow_color }
				color_map[cursor] = { "color": text_color }
			continue
		
		cursor += 1
	
	return color_map


func _is_valid_identifier_char(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"


func _is_digit_or_dot(ch: String) -> bool:
	return (ch >= "0" and ch <= "9") or ch == "."


func _is_keyword(word: String) -> bool:
	var keywords := [
		"label", "choose", "set", "speaker", "background", "show", "hide", "wait", "jump", "play_music", "play_sound",
		"hide_dialog", "move", "update", "stop_music", "dialog", "return"]
	return word in keywords

