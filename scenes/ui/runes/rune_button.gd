class_name RuneButton
extends Button

var rune: Rune

signal rune_selected(rune: Rune)

func _on_pressed() -> void:
	rune_selected.emit(rune)
