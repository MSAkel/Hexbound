extends Control

@onready var panel: Panel = $Panel
@onready var choices_container: HBoxContainer = $Panel/ChoicesContainer
@onready var reroll_button: Button = $Panel/RerollButton

var selection_item_scene: PackedScene = preload("res://scenes/ui/selection_item_ui.tscn")

func _ready() -> void:
	hide()
	UiManager.show_perks_panel.connect(_on_show_panel)
	reroll_button.text = "Reroll (%s)" % GameManager.available_perk_rerolls
	if GameManager.available_perk_rerolls < 1:
		reroll_button.disabled = true

func _on_show_panel() -> void:
	UiManager.show_panel(self)
	instantiate_perk_choices()

func _on_close_button_pressed() -> void:
	hide()

func _on_reroll_button_pressed() -> void:
	if GameManager.available_perk_rerolls < 1:
		return

	await clear_choices()
	reroll_button.disabled = true
	GameManager.available_perk_rerolls -= 1
	GameManager.perks_pack.clear()
	GameManager.create_perks_pack()
	reroll_button.text = "Reroll (%s)" % GameManager.available_perk_rerolls
	reroll_button.disabled = false
	instantiate_perk_choices()

func instantiate_perk_choices() -> void:
	if choices_container.get_child_count() == 0:
		for perk in GameManager.perks_pack:
			var selectionItem: SelectionItemGui = selection_item_scene.instantiate() as SelectionItemGui
			selectionItem.find_child("Icon").texture = perk.icon
			selectionItem.find_child("Label").text = perk.perk_name
			selectionItem.find_child("Description").text = perk.description
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
