extends Control

signal show_done
signal hide_done

enum {
	STATE_IDLE,
	STATE_TYPING,
	STATE_WAITING,
}

var type_cooldown: float = 0.03
var type_timer: float = 0.0

var next_indicator_blink_cooldown: float = 0.5
var next_indicator_blink_timer: float = 0.0


var state: int = STATE_IDLE
var target_text: String = ""

@onready var step_button: Button = %StepButton
@onready var dialog_text_label: RichTextLabel = %DialogTextLabel

@onready var character_name_container: Control = %CharacterNameContainer
@onready var character_name_label: RichTextLabel = %CharacterNameLabel

@onready var margin_container: Control = %MarginContainer
@onready var next_indicator: Control = %NextIndicator

@onready var typying_sound: AudioStreamPlayer = %TypingSound


func _ready() -> void:
	next_indicator.modulate.a = 0.0
	modulate.a = 0.0
	hide()
	character_name_container.hide()

	Dialog.say.connect(_on_dialog_say)
	Dialog.hide_dialog_box.connect(_on_hide_dialog_box)
	Dialog.update_speaker.connect(_on_dialog_update_speaker)
	step_button.pressed.connect(_on_step_button_pressed)


func _physics_process(delta: float) -> void:
	if state == STATE_WAITING:
		next_indicator_blink_timer += delta
		if next_indicator_blink_timer >= next_indicator_blink_cooldown:
			next_indicator.modulate.a = 1.0 - next_indicator.modulate.a # Toggle visibility
			next_indicator_blink_timer = 0.0
	
	if state == STATE_TYPING:
		type_timer += delta
		if type_timer >= type_cooldown:
			type_timer = 0.0
			_type()


func _type() -> void:
	if target_text.length() > 0:
		typying_sound.play()
		# Check if we're at the start of a BBCode tag
		if target_text[0] == '[':
			# Find the closing bracket
			var closing_bracket = target_text.find(']')
			if closing_bracket != -1:
				# Extract and add the entire BBCode tag at once
				var bbcode_tag = target_text.substr(0, closing_bracket + 1)
				dialog_text_label.text += bbcode_tag
				target_text = target_text.substr(closing_bracket + 1)
			else:
				# No closing bracket found, just add the character
				dialog_text_label.text += target_text[0]
				target_text = target_text.substr(1)
		else:
			# Regular character, add it one at a time
			dialog_text_label.text += target_text[0]
			target_text = target_text.substr(1)
	else:
		next_indicator.modulate.a = 1.0 # Show next indicator when done typing
		next_indicator_blink_timer = 0.0
		state = STATE_WAITING


func _on_dialog_update_speaker(speaker: String, _speaker_id: String) -> void:
	if speaker == "_":
		character_name_container.hide()
	else:
		character_name_label.text = speaker
		character_name_container.show()


func _on_hide_dialog_box() -> void:
	animated_hide()
	await Signal(self, "hide_done")

	Dialog.step() # Continue dialog after hiding dialog box


func _on_dialog_say(text: String) -> void:
	if not visible:
		animated_show()
		await Signal(self, "show_done")

	dialog_text_label.text = ""
	target_text = text
	state = STATE_TYPING
	step_button.grab_focus()


func _on_step_button_pressed() -> void:
	if state == STATE_TYPING:
		# Finish typing immediately
		dialog_text_label.text += target_text
		target_text = ""
		next_indicator.modulate.a = 1.0 # Show next indicator when done typing
		next_indicator_blink_timer = 0.0
		state = STATE_WAITING
	
	elif state == STATE_WAITING:
		next_indicator.modulate.a = 0.0
		state = STATE_IDLE
		Dialog.step()


func animated_show() -> void:
	show()

	var tween: Tween = create_tween()
	tween.tween_property(margin_container, "theme_override_constants/margin_bottom", 45, 0.3) # Animate margin to slide up dialog box
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	await Signal(tween, "finished")

	show_done.emit()


func animated_hide() -> void:
	target_text = "" # Clear target text immediately when hiding dialog box
	dialog_text_label.text = "" # Clear dialog text immediately when hiding dialog box

	var tween: Tween = create_tween()
	tween.tween_property(margin_container, "theme_override_constants/margin_bottom", 0, 0.3) # Animate margin to slide down dialog box
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	await Signal(tween, "finished")

	hide()
	hide_done.emit()
