extends Button

var hex: Hex = null

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	# Make the sound effect play faster
	audio_stream_player_2d.pitch_scale = 1.5
	text = "Explore (%s)" % GameManager.available_explores
	update_visibility()
	# Connect to the turn_started signal to show button when explores reset
	Events.turn_started.connect(update_visibility)
	Events.explore_count_changed.connect(update_visibility)

func update_visibility() -> void:
	visible = GameManager.available_explores > 0
	text = "Explore (%s)" % GameManager.available_explores

func _on_pressed() -> void:
	audio_stream_player_2d.play()
	# Wait for the audio to finish before emitting the signal
	await audio_stream_player_2d.finished
	GameManager.available_explores -= 1
	text = "Explore (%s)" % GameManager.available_explores
	update_visibility()
	
	# Run this last as it destroys the button
	GameManager.tile_explored.emit(hex)
