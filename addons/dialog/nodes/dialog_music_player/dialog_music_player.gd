class_name DialogMusicPlayer
extends AudioStreamPlayer

var loop: bool = true


func _ready() -> void:
    Dialog.play_music.connect(_on_play_music)
    Dialog.stop_music.connect(_on_stop_music)

    finished.connect(_on_music_finished)


func _on_play_music(music: String, transition: String) -> void:
    var audio_stream: AudioStream = load(music)
    if audio_stream == null:
        push_error("Failed to load music: %s" % music)
        return
    
    if playing:
        loop = false
        stop()
    
    if transition == "fade":
        volume_db = -80
        get_tree().create_tween().tween_property(self, "volume_db", 0, 4.0)
    
    stream = audio_stream
    loop = true
    play()


func _on_stop_music(transition: String) -> void:
    if transition == "fade":
        await get_tree().create_tween().tween_property(self, "volume_db", -80, 4.0).finished
    
    loop = false
    stop()


func _on_music_finished() -> void:
    volume_db = 0

    if loop:
        play()