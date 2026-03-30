extends Node2D

@onready var play_example_dialog_button: Button = %PlayExampleDialogButton


func _ready() -> void:
	Dialog.ended.connect(_on_dialog_ended)
	play_example_dialog_button.grab_focus()


func _on_dialog_ended(_dialog_id: String) -> void:
	play_example_dialog_button.grab_focus()


func _on_play_example_dialog_button_pressed() -> void:
	Dialog.start("example_dialog")


func _on_change_lang_button_pressed() -> void:
	var current_locale = TranslationServer.get_locale()
	var new_locale = "es_MX" if current_locale != "es_MX" else "en_US"
	
	TranslationServer.set_locale(new_locale)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_play_second_example_pressed() -> void:
	Dialog.start("example_dialog_2")
