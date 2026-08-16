extends Control

@onready var challenge_label: RichTextLabel = $RichTextLabel


func _ready() -> void:
	hide()
	EventBus.challenge_banner_shown.connect(_on_challenge_banner_shown)
	EventBus.challenge_banner_hidden.connect(_on_challenge_banner_hidden)


func _on_challenge_banner_shown(challenge_name: String) -> void:
	challenge_label.text = "[wave amp=50 freq=2]%s[/wave]" % challenge_name
	show()


func _on_challenge_banner_hidden() -> void:
	hide()
