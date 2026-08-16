extends Panel

## Collections screen shows all all collections in game such as runes, challenges, and map templates.

@onready var collection_grid_container: GridContainer = $PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/ScrollContainer/MarginContainer/CollectionGridContainer

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")


func _ready() -> void:
	for rune in GameManager.tile_cards_pool:
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.configure_interaction(CardUI.InteractionMode.PREVIEW)
		collection_grid_container.add_child(card_ui)
		card_ui.set_card(rune)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
