extends Control

@onready var options_container: VBoxContainer = %OptionsContainer


func _ready() -> void:
	hide()
	Dialog.choose.connect(_on_dialog_choose)


func _on_dialog_choose(options: Array, labels: Array) -> void:
	for child in options_container.get_children():
		child.queue_free()

	var count: int = 0

	for i in range(options.size()):
		var option_text = options[i]
		var label = labels[i]
		var button = Button.new()
		button.text = option_text
		button.pressed.connect(_on_option_button_pressed.bind(label))
		options_container.add_child(button)

		if count == 0:
			button.call_deferred("grab_focus") # Grab focus on the first option button
		count += 1

	show()


func _on_option_button_pressed(label: String) -> void:
	Dialog.jump(label)
	hide()
