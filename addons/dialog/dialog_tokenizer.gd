class_name DialogTokenizer
extends Resource

enum TokenType {
	DOLLAR,
	KEYWORD,
	IDENTIFIER,
	INTEGER,
	FLOAT,
	STRING,
	NEWLINE,
	ARROW,
	EOF
}

const TOKEN_TYPE_NAMES := {
	TokenType.DOLLAR: "DOLLAR",
	TokenType.KEYWORD: "KEYWORD",
	TokenType.IDENTIFIER: "IDENTIFIER",
	TokenType.INTEGER: "INTEGER",
	TokenType.FLOAT: "FLOAT",
	TokenType.STRING: "STRING",
	TokenType.NEWLINE: "NEWLINE",
	TokenType.ARROW: "ARROW",
	TokenType.EOF: "EOF"
}


class Token:
	var type: int
	var lexeme: String
	var line: int
	var column: int
	var value: Variant
	var type_name: String:
		get:
			return TOKEN_TYPE_NAMES.get(type, "UNKNOWN")

	func _init(t: int, l: String, ln: int, col: int, v = null) -> void:
		type = t
		type_name = TOKEN_TYPE_NAMES.get(type, "UNKNOWN")
		lexeme = l
		line = ln
		column = col
		value = v


var error: bool = false


func tokenize(content: String) -> Array:
	var i := 0
	var line := 1
	var column := 1
	var length := content.length()

	var tokens: Array = []

	while i < length:
		var ch := content[i]

		if ch == "\r":
			i += 1
			column += 1
			continue

		if ch == "\n":
			if tokens.size() > 0 and tokens[tokens.size() - 1].type != TokenType.NEWLINE:
				tokens.append(Token.new(TokenType.NEWLINE, "\\n", line, column))
			i += 1
			line += 1
			column = 1
			continue

		if ch == "#":
			# Comment until end of line
			while i < length and content[i] != "\n":
				i += 1
				column += 1
			continue
		
		# Arrow
		if ch == "-" and i + 1 < length and content[i + 1] == ">":
			tokens.append(Token.new(TokenType.ARROW, "->", line, column))
			i += 2
			column += 2

			# Remove following spaces
			while i < length and content[i] == " ":
				i += 1
				column += 1

			continue
		
		# Integer or Float
		if _is_digit(ch):
			var start_col := column
			var number_text := ""
			var has_dot := false
			while i < length and (_is_digit(content[i]) or (content[i] == "." and not has_dot)):
				if content[i] == ".":
					has_dot = true
				number_text += content[i]
				i += 1
				column += 1
			
			if has_dot:
				tokens.append(Token.new(TokenType.FLOAT, number_text, line, start_col, number_text))
			else:
				tokens.append(Token.new(TokenType.INTEGER, number_text, line, start_col, number_text))
			continue
		
		# Identifier
		if _is_valid_identifier_char(ch):
			var start_col := column
			var content_text := ""
			while i < length and _is_valid_identifier_char(content[i]):
				content_text += content[i]
				i += 1
				column += 1
			
			tokens.append(Token.new(TokenType.IDENTIFIER, content_text, line, start_col, content_text))

			# Remove following spaces
			while i < length and content[i] == " ":
				i += 1
				column += 1
			
			continue
		
		# Strings closed by quotes
		if ch == "\"" or ch == "'":
			var quote_type := ch
			var start_col := column
			var content_text := ""
			i += 1
			column += 1

			while i < length and content[i] != quote_type:
				if content[i] == "\\" and i + 1 < length:
					# Handle escape sequences
					var next_char := content[i + 1]
					match next_char:
						"n":
							content_text += "\n"
						"t":
							content_text += "\t"
						"r":
							content_text += "\r"
						"\"":
							content_text += "\""
						"'":
							content_text += "'"
						"\\":
							content_text += "\\"
						_:
							content_text += next_char
					i += 2
					column += 2
				else:
					content_text += content[i]
					i += 1
					column += 1
			
			if i >= length:
				unexpected_character("EOF", line, column)
				break
			
			# Consume closing quote
			i += 1
			column += 1

			tokens.append(Token.new(TokenType.STRING, content_text, line, start_col, content_text))
			continue
		
		# Strings could start with space or tab
		if ch == " " or ch == "\t":
			var start_col := column
			var content_text := ""

			# First consume all identation
			while i < length and (content[i] == " " or content[i] == "\t"):
				i += 1
				column += 1
			
			# Then conume all string until newline or arrow
			while i < length and content[i] != "\n" and content[i] != "-":
				content_text += content[i]
				i += 1
				column += 1
			
			content_text = content_text.strip_edges()

			if content_text != "":
				tokens.append(Token.new(TokenType.STRING, content_text, line, start_col, content_text))
				continue
		
		# Unexpected token
		unexpected_character(ch, line, column)
		break

	# Ensure the last token is a newline
	tokens.append(Token.new(TokenType.NEWLINE, "\\n", line, column))
	tokens.append(Token.new(TokenType.EOF, "EOF", line, column))
	return tokens


func unexpected_character(lexeme: String, line: int, column: int) -> void:
	push_error("Dialog: Unexpected character '%s' at line %d, column %d" % [lexeme, line, column])
	error = true


func _is_valid_identifier_char(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"


func _is_digit(ch: String) -> bool:
	return ch >= "0" and ch <= "9"