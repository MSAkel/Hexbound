extends Control

@onready var buildings_button: TextureButton = $MarginContainer/GridContainer/BuildingsButton
@onready var runes_button: TextureButton = $MarginContainer/GridContainer/RunesButton
@onready var perks_button: TextureButton = $MarginContainer/GridContainer/PerksButton
@onready var quests_button: TextureButton = $MarginContainer/GridContainer/QuestsButton
@onready var building_count_label: Label = $MarginContainer/GridContainer/BuildingsButton/BuildingCounterPanel/BuildingCountLabel
@onready var building_icon_particles: GPUParticles2D = $MarginContainer/GridContainer/BuildingsButton/buildingIconParticles
@onready var rune_count_label: Label = $MarginContainer/GridContainer/RunesButton/RuneCounterPanel/RuneCountLabel
@onready var rune_icon_particles: GPUParticles2D = $MarginContainer/GridContainer/RunesButton/RuneIconParticles
@onready var building_counter_panel: Panel = $MarginContainer/GridContainer/BuildingsButton/BuildingCounterPanel
@onready var rune_counter_panel: Panel = $MarginContainer/GridContainer/RunesButton/RuneCounterPanel
@onready var building_icon: TextureRect = $MarginContainer/GridContainer/BuildingsButton/BuildingIcon
@onready var rune_icon: TextureRect = $MarginContainer/GridContainer/RunesButton/RuneIcon


func _ready() -> void:
	if not is_node_ready():
		await ready

	building_count_label.text = str(GameManager.available_building_packs)
	rune_count_label.text = str(GameManager.available_runes_packs)

	Events.building_pack_count_changed.connect(_update_buildings_count)
	Events.rune_pack_count_changed.connect(_update_runes_count)

func _on_buildings_button_pressed() -> void:
	UiManager.show_buildings_choice_panel.emit()

func _on_runes_button_pressed() -> void:
	UiManager.show_runes_choice_panel.emit()

func _on_perks_button_pressed() -> void:
	UiManager.show_perks_panel.emit()

func _on_quests_button_pressed() -> void:
	UiManager.show_quests_panel.emit() 


func _update_buildings_count() -> void:
	building_count_label.text = str(GameManager.available_building_packs)

	if GameManager.available_building_packs > 0:
		buildings_button.disabled = false
		buildings_button.modulate = Color.GOLD
		building_icon_particles.emitting = true
		building_icon.modulate = Color(1, 1, 1, 1)
		building_counter_panel.show()
	else:
		buildings_button.disabled = true
		buildings_button.modulate = Color.WHITE
		building_icon_particles.emitting = false
		building_icon.modulate = Color(0.5, 0.5, 0.5, 1)
		building_counter_panel.hide()


func _update_runes_count() -> void:
	rune_count_label.text = str(GameManager.available_runes_packs)

	if GameManager.available_runes_packs > 0:
		runes_button.disabled = false
		runes_button.modulate = Color.GOLD
		rune_icon_particles.emitting = true
		rune_icon.modulate = Color(1, 1, 1, 1)
		rune_counter_panel.show()
	else:
		runes_button.disabled = true
		runes_button.modulate = Color.WHITE
		rune_icon_particles.emitting = false
		rune_icon.modulate = Color(0.5, 0.5, 0.5, 1)
		rune_counter_panel.hide()


func _on_buildings_button_mouse_entered() -> void:
	Events.toggle_tooltip.emit(true, "Building packs", buildings_button.get_global_rect())

func _on_runes_button_mouse_entered() -> void:
	Events.toggle_tooltip.emit(true, "Rune packs", runes_button.get_global_rect())


func _on_perks_button_mouse_entered() -> void:
	Events.toggle_tooltip.emit(true, "Perks", perks_button.get_global_rect())


func _on_quests_button_mouse_entered() -> void:
	Events.toggle_tooltip.emit(true, "Quests", quests_button.get_global_rect())


func _on_buildings_button_mouse_exited() -> void:
	Events.toggle_tooltip.emit(false, "", Rect2())


func _on_runes_button_mouse_exited() -> void:
	Events.toggle_tooltip.emit(false, "", Rect2())


func _on_perks_button_mouse_exited() -> void:
	Events.toggle_tooltip.emit(false, "", Rect2())


func _on_quests_button_mouse_exited() -> void:
	Events.toggle_tooltip.emit(false, "", Rect2())
