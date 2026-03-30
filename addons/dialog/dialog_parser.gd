class_name DialogParser
extends Resource

enum OpCode {
	START,
	END,
	SAY,
	START_CALL,
	ADD_CALL_ARG,
	EXECUTE_CALL,
	START_CHOOSE,
	ADD_CHOOSE_OPTION,
	EXECUTE_CHOOSE,
}

const OP_CODE_NAMES := {
	OpCode.START: "START",
	OpCode.END: "END",
	OpCode.SAY: "SAY",
	OpCode.START_CALL: "START_CALL",
	OpCode.ADD_CALL_ARG: "ADD_CALL_ARG",
	OpCode.EXECUTE_CALL: "EXECUTE_CALL",
	OpCode.START_CHOOSE: "START_CHOOSE",
	OpCode.ADD_CHOOSE_OPTION: "ADD_CHOOSE_OPTION",
	OpCode.EXECUTE_CHOOSE: "EXECUTE_CHOOSE"
}


class ParsedDialog:
	var opcodes: Array
	var strings: Array
	var labels: Dictionary

	func _init(p_opcodes: Array, p_strings: Array, p_labels: Dictionary) -> void:
		opcodes = p_opcodes
		strings = p_strings
		labels = p_labels

var _tokenizer := DialogTokenizer.new()

var _cursor := 0
var _opcodes: Array = []
var _strings: Array = []
var _labels := {}
var _pending_jumps: Array = []
var _tokens: Array = []

var error: bool = false


func parse(content: String) -> ParsedDialog:
	_tokens = _tokenizer.tokenize(content)

	if _tokenizer.error:
		error = true
		return ParsedDialog.new([], [], {})
	
	_cursor = 0
	_opcodes = []
	_strings = []
	_labels = {}
	_pending_jumps = []

	error = false

	emit(OpCode.START)

	while true:
		var tok := peek(0)
		if tok.type == DialogTokenizer.TokenType.EOF:
			emit(OpCode.END)
			break

		if tok.type == DialogTokenizer.TokenType.NEWLINE:
			advance()
			continue
		
		# OP SAY -> STRING NEWLINE
		if tok.type == DialogTokenizer.TokenType.STRING:
			advance()

			if not match_token(DialogTokenizer.TokenType.NEWLINE):
				unexpected_token(tok.lexeme, tok.line, tok.column)
				break
			
			var content_text: Variant = tok.value
			emit(OpCode.SAY, add_string(content_text))

			advance()
			continue
		
		if tok.type == DialogTokenizer.TokenType.IDENTIFIER:
			var identifier: String = tok.value

			if identifier == "label":
				advance()

				if not match_token(DialogTokenizer.TokenType.IDENTIFIER):
					unexpected_token(peek(0).lexeme, peek(0).line, peek(0).column)
					break
				
				var label_name: Variant = peek(0).value
				_labels[label_name] = _opcodes.size()
				advance()
				continue

			elif identifier == "choose":
				advance()

				if not match_token(DialogTokenizer.TokenType.NEWLINE):
					unexpected_token(tok.lexeme, tok.line, tok.column)
					break
				
				emit(OpCode.START_CHOOSE)
				advance()
				
				# Parse choose options (STRING ARROW IDENTIFIER NEWLINE)
				while true:
					var option_token := peek(0)
					if option_token.type != DialogTokenizer.TokenType.STRING:
						break
					
					var option_text: Variant = option_token.value
					advance()

					if not match_token(DialogTokenizer.TokenType.ARROW):
						unexpected_token(peek(0).lexeme, peek(0).line, peek(0).column)
						break

					advance()

					var label_token := peek(0)
					if label_token.type != DialogTokenizer.TokenType.IDENTIFIER:
						unexpected_token(label_token.lexeme, label_token.line, label_token.column)
						break
					
					var label_name: Variant = label_token.value
					advance()

					emit(OpCode.ADD_CHOOSE_OPTION, add_string(option_text), add_string(label_name))

					if not match_token(DialogTokenizer.TokenType.NEWLINE):
						unexpected_token(peek(0).lexeme, peek(0).line, peek(0).column)
						break
					
					advance()
				
				emit(OpCode.EXECUTE_CHOOSE)
				continue
			
			else:
				# CALL OPERATION -> IDENTIFIER (arguments) NEWLINE
				emit(OpCode.START_CALL, add_string(identifier))
				advance()

				while  match_token(DialogTokenizer.TokenType.IDENTIFIER) or match_token(DialogTokenizer.TokenType.INTEGER) or match_token(DialogTokenizer.TokenType.FLOAT) or match_token(DialogTokenizer.TokenType.STRING):
					var arg_token := peek(0)
					emit(OpCode.ADD_CALL_ARG, add_string(arg_token.value))
					advance()
				
				if not match_token(DialogTokenizer.TokenType.NEWLINE):
					unexpected_token(peek(0).lexeme, peek(0).line, peek(0).column)
					break
				
				emit(OpCode.EXECUTE_CALL)
				advance()
				continue
		break

	return ParsedDialog.new(_opcodes, _strings, _labels)


func unexpected_token(lexeme: String, line: int, column: int) -> void:
	push_error("Dialog: Unexpected token '%s' at line %d, column %d" % [lexeme, line, column])
	error = true


func peek(offset := 0) -> DialogTokenizer.Token:
	var index := _cursor + offset
	if index < _tokens.size():
		return _tokens[index]
	return _tokens[_tokens.size() - 1]


func advance() -> void:
	_cursor += 1


func match_token(type: int) -> bool:
	if peek(0).type == type:
		return true
	return false


func add_string(value: String) -> int:
	var idx := _strings.find(value)
	if idx == -1:
		_strings.append(value)
		return _strings.size() - 1
	return idx


func emit(op: int, a: int = -1, b: int = -1) -> void:
	_opcodes.append([op, a, b])


func print_debug() -> void:
	print("-- Tokens:")
	for token in _tokens:
		print("Token('%s', '%s')" % [token.type_name, token.lexeme])

	print("-- Parsed Opcodes:")
	for i in range(_opcodes.size()):
		var opcode = _opcodes[i]
		var op_name = OP_CODE_NAMES.get(opcode[0], "UNKNOWN")
		var data = opcode[1]
		var data2 = opcode[2]
		print("%04d  %s %s %s" % [i, op_name, _strings[data] if data != -1 else "", _strings[data2] if data2 != -1 else ""])
	
	print("-- Labels:")
	for label in _labels:
		print("%s: %d" % [label, _labels[label]])