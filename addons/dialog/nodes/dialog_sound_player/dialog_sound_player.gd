class_name DialogSoundPlayer
extends Node


func _ready() -> void:
    Dialog.play_sound.connect(_on_play_sound)


func _on_play_sound(sound: String) -> void:
    var audio_stream: AudioStream = load(sound)

    if audio_stream == null:
        push_error("Failed to load sound: %s" % sound)
        return
    
    var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
    
    audio_player.stream = audio_stream
    audio_player.finished.connect(audio_player.queue_free)
    
    add_child(audio_player)
    audio_player.play()