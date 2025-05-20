extends Node2D

@onready var label: Label = $Label
@onready var timer: Timer = $Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	print("Ready")
	timer.start()
	animation_player.play("float")

func set_text(text: String):
	print("set_text")
	if not is_node_ready():
		await ready
	
	print(label.text)
	label.text = text

func _on_Timer_timeout():
	queue_free()