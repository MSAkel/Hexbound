class_name RuneGui
extends Button

var rune: RuneData

signal rune_selected(rune: RuneData)

func _on_pressed() -> void:
	print("prssed")
	rune_selected.emit(rune)
