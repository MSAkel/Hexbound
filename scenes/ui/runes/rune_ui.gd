class_name RuneUI
extends Button

var rune: Rune

signal rune_selected(rune: Rune)

func _on_pressed() -> void:
	rune_selected.emit(rune)
