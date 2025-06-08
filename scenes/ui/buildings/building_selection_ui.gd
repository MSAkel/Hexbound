extends Control

@onready var choices_container: HBoxContainer = $PanelContainer/Panel/ChoicesContainer
@onready var reroll_button: Button = $PanelContainer/Panel/RerollButton

const BUILDING_SELECTION_ITEM = preload("res://scenes/ui/buildings/building_selection_item.tscn")

func _ready() -> void:
	hide()
	
	UiManager.show_buildings_choice_panel.connect(_on_show_panel)
	

	reroll_button.text = "Reroll (%s)" % GameManager.building_reroll_cost
	if GameManager.building_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		reroll_button.disabled = true
	else:
		reroll_button.disabled = false
	
	Events.building_selected.connect(func(_building: Building):
		hide()	
	)

func _on_show_panel() -> void:
	UiManager.show_panel(self)
	instantiate_building_choices()

func _on_close_button_pressed() -> void:
	hide()


func _on_reroll_button_pressed() -> void:
	if GameManager.building_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		return

	reroll_button.disabled = true
	
	await clear_choices()
	GameManager.buildings_pack.clear()
	GameManager.create_buildings_pack()
	GameManager.building_reroll_cost += 5
	reroll_button.text = "Reroll (%s)" % GameManager.building_reroll_cost
	instantiate_building_choices()
	GoodsManager.remove_good(GoodType.Type.GOLD, GameManager.building_reroll_cost)

	if GameManager.building_reroll_cost > GoodsManager.get_good_amount(GoodType.Type.GOLD):
		reroll_button.disabled = true
	else:
		reroll_button.disabled = false

func instantiate_building_choices() -> void:
	if choices_container.get_child_count() == 0:
		for building in GameManager.buildings_pack:
			var selectionItem: BuildingSelectionItem = BUILDING_SELECTION_ITEM.instantiate()
			selectionItem.set_item(building)
			choices_container.add_child(selectionItem)


func clear_choices() -> void:
	for node in choices_container.get_children():
		animate_and_free(node)

	# Ensure the node queue is flushed before continuing.
	while choices_container.get_child_count() > 0:
		await get_tree().process_frame


func animate_and_free(node: Node) -> void:
	if node.has_method("fade_out"):
		node.fade_out()
	else:
		node.modulate = Color(1, 1, 1, 1)
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.3)
		tween.tween_callback(Callable(node, "queue_free"))
