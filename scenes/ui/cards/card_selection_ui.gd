extends Control

@onready var building_choices_container: HBoxContainer = $PanelContainer/Panel/MarginContainer/VBoxContainer/BuildingsPanel/BuildingChoicesContainer
@onready var rune_choice_container: HBoxContainer = $PanelContainer/Panel/MarginContainer/VBoxContainer/RunesPanel/RuneChoiceContainer
@onready var building_reroll_button: Button = $PanelContainer/Panel/MarginContainer/VBoxContainer/BuildingsPanel/BuildingRerollButton
@onready var rune_reroll_button: Button = $PanelContainer/Panel/MarginContainer/VBoxContainer/RunesPanel/RuneRerollButton

@onready var buildings_panel: Panel = $PanelContainer/Panel/MarginContainer/VBoxContainer/BuildingsPanel
@onready var runes_panel: Panel = $PanelContainer/Panel/MarginContainer/VBoxContainer/RunesPanel

const BUILDING_SELECTION_ITEM = preload("res://scenes/ui/buildings/building_selection_item.tscn")
const RUNE_SELECTION_ITEM = preload("res://scenes/ui/runes/rune_selection_item.tscn")

func _ready() -> void:
	hide()
	
	UiManager.show_cards_choice_panel.connect(_on_show_panel)
	
	building_reroll_button.text = "Reroll (%s)" % GameManager.building_reroll_cost
	if GameManager.building_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		building_reroll_button.disabled = true
	else:
		building_reroll_button.disabled = false
	
	# Events.building_selected.connect(func(_building: Building):
	# 	buildings_panel.hide()
	# )

	rune_reroll_button.text = "Reroll (%s)" % GameManager.runes_reroll_cost
	if GameManager.runes_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		rune_reroll_button.disabled = true
	else:
		rune_reroll_button.disabled = false
	
	# Events.rune_selected.connect(func(_rune: Rune):
	# 	runes_panel.hide()	
	# )

func _on_show_panel() -> void:
	UiManager.show_panel(self)
	instantiate_building_choices()
	instantiate_rune_choices()

func _on_close_button_pressed() -> void:
	hide()


# Signal handler for the building reroll button
# reroll cost if free for inital reroll, cost increases by 5 gold after each reroll, cost goes up with turns
func _on_building_reroll_button_pressed() -> void:
	if GameManager.building_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		return

	building_reroll_button.disabled = true
	
	await clear_building_choices()
	GameManager.buildings_pack.clear()
	GameManager.create_buildings_pack()
	GameManager.building_reroll_cost += 5
	building_reroll_button.text = "Reroll (%s)" % GameManager.building_reroll_cost
	instantiate_building_choices()
	GoodsManager.remove_good(GoodType.Type.GOLD, GameManager.building_reroll_cost)

	if GameManager.building_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		building_reroll_button.disabled = true
	else:
		building_reroll_button.disabled = false


func _on_rune_reroll_button_pressed() -> void:
	if GameManager.runes_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		return

	rune_reroll_button.disabled = true
	
	await clear_rune_choices()
	GameManager.runes_pack.clear()
	GameManager.create_runes_pack()
	GameManager.runes_reroll_cost += 5
	rune_reroll_button.text = "Reroll (%s)" % GameManager.runes_reroll_cost
	instantiate_rune_choices()
	GoodsManager.remove_good(GoodType.Type.GOLD, GameManager.runes_reroll_cost)
	if GameManager.runes_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		rune_reroll_button.disabled = true
	else:
		rune_reroll_button.disabled = false

func instantiate_building_choices() -> void:
	if building_choices_container.get_child_count() == 0:
		for building in GameManager.buildings_pack:
			var selectionItem: BuildingSelectionItem = BUILDING_SELECTION_ITEM.instantiate()
			selectionItem.set_item(building)
			building_choices_container.add_child(selectionItem)

func instantiate_rune_choices() -> void:
	if rune_choice_container.get_child_count() == 0:
		for rune in GameManager.runes_pack:
			var selectionItem: RuneSelectionItem = RUNE_SELECTION_ITEM.instantiate()
			selectionItem.set_item(rune)
			rune_choice_container.add_child(selectionItem)

func clear_building_choices() -> void:
	for node in building_choices_container.get_children():
		animate_and_free(node)

	# Ensure the node queue is flushed before continuing.
	while building_choices_container.get_child_count() > 0:
		await get_tree().process_frame

func clear_rune_choices() -> void:
	for node in rune_choice_container.get_children():
		animate_and_free(node)

	# Ensure the node queue is flushed before continuing.
	while rune_choice_container.get_child_count() > 0:
		await get_tree().process_frame

func animate_and_free(node: Node) -> void:
	if node.has_method("fade_out"):
		node.fade_out()
	else:
		node.modulate = Color(1, 1, 1, 1)
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.3)
		tween.tween_callback(Callable(node, "queue_free"))
