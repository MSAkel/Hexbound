extends Node2D

@onready var label: Label = $Label
@onready var timer: Timer = $Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	timer.start()
	animation_player.play("float")

func set_text(text: String, is_gold := true):
	if not is_node_ready():
		await ready
	
	label.text = text
	label.add_theme_color_override("font_color", Color.GOLD if is_gold else Color.SKY_BLUE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 32)

	if is_gold:
		audio_stream_player_2d.play()
	else:
		audio_stream_player_2d.play()
	

func _on_Timer_timeout():
	queue_free()
