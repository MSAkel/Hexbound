extends Control

# @onready var building_count_label: Label = $BuildingsPanelButton/BuildingCounterPanel/BuildingCountLabel
# @onready var rune_count_label: Label = $RunesPanelButton/RuneCounterPanel/RuneCountLabel
# @onready var buildings_panel_button: TextureButton = $BuildingsPanelButton
# @onready var runes_panel_button: TextureButton = $RunesPanelButton
# @onready var building_icon_particles: GPUParticles2D = $BuildingsPanelButton/buildingIconParticles
# @onready var rune_icon_particles: GPUParticles2D = $RunesPanelButton/RuneIconParticles
# @onready var building_icon: TextureRect = $BuildingsPanelButton/BuildingIcon
# @onready var rune_icon: TextureRect = $RunesPanelButton/RuneIcon
# @onready var building_counter_panel: Panel = $BuildingsPanelButton/BuildingCounterPanel
# @onready var rune_counter_panel: Panel = $RunesPanelButton/RuneCounterPanel

# func _ready() -> void:
# 	if not is_node_ready():
# 		await ready

# 	building_count_label.text = str(GameManager.available_building_packs)
# 	rune_count_label.text = str(GameManager.available_runes_packs)

# 	Events.building_pack_count_changed.connect(_update_buildings_count)
# 	Events.rune_pack_count_changed.connect(_update_runes_count)

# func _on_buildings_panel_button_pressed() -> void:
# 	UiManager.show_buildings_choice_panel.emit()

# func _update_buildings_count() -> void:
# 	building_count_label.text = str(GameManager.available_building_packs)

# 	if GameManager.available_building_packs > 0:
# 		buildings_panel_button.disabled = false
# 		building_icon_particles.emitting = true
# 		building_icon.modulate = Color(1, 1, 1, 1)
# 		building_counter_panel.show()
# 	else:
# 		buildings_panel_button.disabled = true
# 		building_icon_particles.emitting = false
# 		building_icon.modulate = Color(0.5, 0.5, 0.5, 1)
# 		building_counter_panel.hide()


# func _update_runes_count() -> void:
# 	rune_count_label.text = str(GameManager.available_runes_packs)

# 	if GameManager.available_runes_packs > 0:
# 		runes_panel_button.disabled = false
# 		rune_icon_particles.emitting = true
# 		rune_icon.modulate = Color(1, 1, 1, 1)
# 		rune_counter_panel.show()
# 	else:
# 		runes_panel_button.disabled = true
# 		rune_icon_particles.emitting = false
# 		rune_icon.modulate = Color(0.5, 0.5, 0.5, 1)
# 		rune_counter_panel.hide()


# func _on_runes_panel_button_pressed() -> void:
# 	UiManager.show_runes_choice_panel.emit()
