extends Button

var hex: Hex = null

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	# Make the sound effect play faster
	audio_stream_player_2d.pitch_scale = 1.5

func _on_pressed() -> void:
	audio_stream_player_2d.play()
	# Wait for the audio to finish before emitting the signal
	await audio_stream_player_2d.finished
	GameManager.tile_explored.emit(hex)
