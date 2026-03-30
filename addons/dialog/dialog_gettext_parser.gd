class_name DialogGettextParser
extends EditorTranslationParserPlugin


func _get_recognized_extensions() -> PackedStringArray:
    return PackedStringArray(DialogFormatLoader.FILE_EXTENSIONS)


func _parse_file(path: String) -> Array[PackedStringArray]:
    var file = FileAccess.open(path, FileAccess.READ)

    if file == null:
        push_error("Failed to open dialog file: %s" % path)
        return []

    var content: String = file.get_as_text()
    file.close()

    var dialog_resource = DialogResource.new()
    var dialog_parser = DialogParser.new()

    dialog_resource.dialog_id = path.get_file().get_basename()
    dialog_resource.raw_dialog = content
    dialog_resource.parsed_dialog = dialog_parser.parse(content)

    if dialog_resource == null:
        push_error("Failed to load dialog resource: %s" % path)
        return []
    
    var parsed_dialog = dialog_resource.parsed_dialog

    if parsed_dialog == null:
        push_error("Dialog resource '%s' does not contain a parsed dialog" % path)
        return []
    
    var dialog_vm = DialogVM.new()
    dialog_vm.load_dialog(dialog_resource.dialog_id, parsed_dialog)

    var parser_context = _DialogParserContext.new()
    parser_context.dialog_vm = dialog_vm
    
    dialog_vm.do_call.connect(parser_context._on_do_call)
    dialog_vm.do_choose.connect(parser_context._on_do_choose)
    dialog_vm.say.connect(parser_context._on_say)
    dialog_vm.end.connect(parser_context._on_end)

    dialog_vm.start_dialog(dialog_resource.dialog_id)

    var timeout: int = 0
    var max_timeout: int = 100
    
    while parser_context.wait_vm and timeout < max_timeout:
        OS.delay_msec(100)
        timeout += 1

    if timeout >= max_timeout:
        push_error("Dialog VM timed out for '%s'" % dialog_resource.dialog_id)
    
    return parser_context.strings_to_translate


class _DialogParserContext:
    var dialog_vm: DialogVM
    var wait_vm: bool = true
    var strings_to_translate: Array[PackedStringArray] = []
    var translation_speaker: String = ""

    func _on_say(text: String) -> void:
        strings_to_translate.append(PackedStringArray([text, translation_speaker]))
        dialog_vm.step()

    func _on_do_call(identifier: String, args: Array) -> void:
        if identifier == "speaker":
            if args.size() >= 1:
                translation_speaker = args[0] if args[0] != "_" else ""
        dialog_vm.step()
    
    func _on_do_choose(options: Array, labels: Array) -> void:
        for option in options:
            strings_to_translate.append(PackedStringArray([option]))
        dialog_vm.step()
    
    func _on_end() -> void:
        wait_vm = false
