extends Control

@onready var choices_container: HBoxContainer = $Panel/MarginPanel/ChoicesContainer
@onready var reroll_button: Button = $Panel/MarginPanel/RerollButton

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CHOICE_CARD_SCALE := 1.45
const CHOICE_CARD_BASE_SIZE := Vector2(198, 317)

func _ready() -> void:
	hide()

	UiManager.show_runes_choice_panel.connect(_on_show_panel)
	Events.gold_changed.connect(_on_gold_changed)
	Events.rune_selected.connect(_on_rune_selected)
	_update_reroll_button()

func _on_rune_selected(_rune: Rune) -> void:
	hide()

	# Open the merchant only after a rune pick when the phase goal was met this turn.
	if GameManager.consume_pending_merchant_visit():
		UiManager.show_merchant_panel.emit()


func _on_show_panel() -> void:
	UiManager.show_panel(self)
	_update_reroll_button()
	GameManager.create_runes_pack()
	instantiate_rune_choices()

func _on_close_button_pressed() -> void:
	hide()


func _on_reroll_button_pressed() -> void:
	if not GoldManager.can_afford(GameManager.runes_reroll_cost):
		return

	reroll_button.disabled = true

	await clear_choices()
	GameManager.runes_pack.clear()
	GameManager.create_runes_pack()
	GoldManager.remove(GameManager.runes_reroll_cost)
	GameManager.runes_reroll_cost += 10
	instantiate_rune_choices()
	_update_reroll_button()


func _on_gold_changed(_new_amount: int) -> void:
	_update_reroll_button()


# Keep reroll label and disabled state in sync with the current gold balance.
func _update_reroll_button() -> void:
	reroll_button.text = "Reroll (%s)" % GameManager.runes_reroll_cost
	reroll_button.disabled = not GoldManager.can_afford(GameManager.runes_reroll_cost)

func instantiate_rune_choices() -> void:

	# Always clear existing choices first to ensure fresh display
	for node in choices_container.get_children():
		node.queue_free()
	
	# Wait one frame to ensure nodes are freed
	await get_tree().process_frame
	
	# Now create new choices from the current runes_pack
	for rune in GameManager.runes_pack:
		_create_choice_card(rune)


func _create_choice_card(rune: Rune) -> void:
	# Wrapper reserves scaled layout space; the card itself is visually scaled up.
	var card_slot := Control.new()
	card_slot.custom_minimum_size = CHOICE_CARD_BASE_SIZE * CHOICE_CARD_SCALE
	choices_container.add_child(card_slot)

	var card_ui: CardUI = CARD_UI_SCENE.instantiate()
	card_slot.add_child(card_ui)
	card_ui.scale = Vector2.ONE * CHOICE_CARD_SCALE
	card_ui.configure_interaction(CardUI.InteractionMode.CHOICE)
	card_ui.set_card(rune)
	card_ui.action_requested.connect(_on_rune_choice_selected)


func _on_rune_choice_selected(card_ui: CardUI) -> void:
	var rune := card_ui.card as Rune
	GameManager.available_runes_packs -= 1
	GameManager.runes_pack.clear()
	Events.rune_selected.emit(rune)
	Events.rune_pack_count_changed.emit()

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
