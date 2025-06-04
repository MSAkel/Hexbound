extends Control

@onready var building_count_label: Label = $BuildingsPanelButton/BuildingCounterPanel/BuildingCountLabel
@onready var rune_count_label: Label = $RunesPanelButton/RuneCounterPanel/RuneCountLabel
@onready var buildings_panel_button: TextureButton = $BuildingsPanelButton
@onready var runes_panel_button: TextureButton = $RunesPanelButton

func _ready() -> void:
	if not is_node_ready():
		await ready

	building_count_label.text = str(GameManager.available_building_packs)
	rune_count_label.text = str(GameManager.available_runes_packs)

	Events.building_pack_count_changed.connect(_update_buildings_count)
	Events.rune_pack_count_changed.connect(_update_runes_count)

func _on_buildings_panel_button_pressed() -> void:
	UiManager.show_buildings_choice_panel.emit()

func _update_buildings_count() -> void:
	building_count_label.text = str(GameManager.available_building_packs)

	if GameManager.available_building_packs > 0:
		buildings_panel_button.disabled = false
	else:
		buildings_panel_button.disabled = true


func _update_runes_count() -> void:
	rune_count_label.text = str(GameManager.available_runes_packs)

	if GameManager.available_runes_packs > 0:
		runes_panel_button.disabled = false
	else:
		runes_panel_button.disabled = true


func _on_runes_panel_button_pressed() -> void:
	UiManager.show_runes_choice_panel.emit()
