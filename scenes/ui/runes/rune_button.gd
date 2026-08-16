class_name RuneButton
extends Button

var rune: TileCard

signal tile_card_selected(rune: TileCard)

func _on_pressed() -> void:
	tile_card_selected.emit(rune)
