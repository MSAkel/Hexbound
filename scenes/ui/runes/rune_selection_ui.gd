extends Control

@onready var choices_container: HBoxContainer = $Panel/MarginPanel/ChoicesContainer
@onready var reroll_button: Button = $Panel/RerollButton


const RUNE_SELECTION_ITEM = preload("res://scenes/ui/runes/rune_selection_item.tscn")

func _ready() -> void:
	hide()
	
	UiManager.show_runes_choice_panel.connect(_on_show_panel)
	

	reroll_button.text = "Reroll (%s)" % GameManager.runes_reroll_cost
	if GameManager.runes_reroll_cost > GoldManager.amount:
		reroll_button.disabled = true
	else:
		reroll_button.disabled = false
	
	Events.rune_selected.connect(_on_rune_selected)

func _on_rune_selected(_rune: Rune) -> void:
	hide()

	# Open the merchant only after a rune pick when the phase goal was met this turn.
	if GameManager.consume_pending_merchant_visit():
		UiManager.show_merchant_panel.emit()


func _on_show_panel() -> void:
	UiManager.show_panel(self)
	GameManager.create_runes_pack()
	instantiate_rune_choices()

func _on_close_button_pressed() -> void:
	hide()


func _on_reroll_button_pressed() -> void:
	if GameManager.runes_reroll_cost > GoldManager.amount:
		return

	reroll_button.disabled = true
	
	await clear_choices()
	GameManager.runes_pack.clear()
	GameManager.create_runes_pack()
	GameManager.runes_reroll_cost += 5
	reroll_button.text = "Reroll (%s)" % GameManager.runes_reroll_cost
	instantiate_rune_choices()
	
	reroll_button.disabled = false

func instantiate_rune_choices() -> void:

	# Always clear existing choices first to ensure fresh display
	for node in choices_container.get_children():
		node.queue_free()
	
	# Wait one frame to ensure nodes are freed
	await get_tree().process_frame
	
	# Now create new choices from the current runes_pack
	for rune in GameManager.runes_pack:
		var selectionItem: RuneSelectionItem = RUNE_SELECTION_ITEM.instantiate()
		selectionItem.set_item(rune)
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
