class_name RuneSelectionItem
extends VBoxContainer

@onready var icon: TextureRect = $IconPanel/Icon
@onready var label: Label = $TextPanel/VBoxContainer/Label
@onready var description: Label = $TextPanel/VBoxContainer/Description

var rune: Rune

func set_item(item: Rune) -> void:
	rune = item
	
	if not is_node_ready():
		await ready

	icon.texture = item.icon
	label.text = item.name
	description.text = item.description


func _on_select_button_pressed() -> void:
	GameManager.available_runes_packs -= 1
	GameManager.runes_pack.clear()
	Events.rune_selected.emit(rune)
	Events.rune_pack_count_changed.emit()
