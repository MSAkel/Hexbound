extends Control

@onready var panel_container: MarginContainer = $PanelContainer
@onready var choices_container: HBoxContainer = $PanelContainer/Panel/ChoicesContainer
@onready var reroll_button: Button = $PanelContainer/Panel/RerollButton

var reroll_locked := false

var selection_item_scene: PackedScene = preload("res://scenes/ui/selection_item_gui.tscn")

func _ready() -> void:
	reroll_button.text = "Reroll (%s)" % GameManager.building_reroll_cost
	if GameManager.building_reroll_cost > GameManager.gold_count:
		reroll_button.disabled = true
	else:
		reroll_button.disabled = false


func _on_open_building_selection_button_pressed() -> void:
	panel_container.show()
	instantiate_building_choices()
	

func _on_close_button_pressed() -> void:
	panel_container.hide()


func _on_reroll_button_pressed() -> void:
	if GameManager.building_reroll_cost > GameManager.gold_count:
		return

	if reroll_locked:
		return
	reroll_locked = true
	
	await clear_choices()
	GameManager.buildings_pack.clear()
	GameManager.create_buildings_pack()
	GameManager.building_reroll_cost += 5
	reroll_button.text = "Reroll (%s)" % GameManager.building_reroll_cost
	instantiate_building_choices()
	
	reroll_locked = false

func instantiate_building_choices() -> void:
	print(choices_container.get_child_count())
	if choices_container.get_child_count() == 0:
		for building in GameManager.buildings_pack:
			var selectionItem: SelectionItemGui = selection_item_scene.instantiate() as SelectionItemGui
			selectionItem.find_child("Icon").texture = building.icon
			selectionItem.find_child("Label").text = building.label
			selectionItem.find_child("Description").text = building.description
			choices_container.add_child(selectionItem)

func clear_choices() -> void:
	for node in choices_container.get_children():
		#node.queue_free()
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
