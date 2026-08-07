extends Control

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const MERCHANT_TOTAL_COUNT := 8
const MERCHANT_ENHANCEMENT_COUNT := 2
const MERCHANT_RUNE_COUNT := MERCHANT_TOTAL_COUNT - MERCHANT_ENHANCEMENT_COUNT
const BASE_REROLL_COST := 10
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var cards_grid: GridContainer = $ContainerPanel/MarginContainer/HBoxContainer/CardsGridContainer
@onready var reroll_button: Button = $ContainerPanel/MarginContainer/HBoxContainer/VBoxContainer/RerollButton
@onready var leave_button: Button = $ContainerPanel/MarginContainer/HBoxContainer/VBoxContainer/LeaveButton

# Runes and enhancements currently offered for purchase in the merchant grid.
var merchant_inventory: Array[Resource] = []
var reroll_cost := BASE_REROLL_COST
var reroll_counter := 1
var _displayed_cards: Array[CardUI] = []
var _merchant_discount := 0.0


func _ready() -> void:
	hide()
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	Events.gold_changed.connect(_on_gold_changed)
	Events.merchant_discount_changed.connect(_on_merchant_discount_changed)
	UiManager.show_merchant_panel.connect(open)
	_update_reroll_button()
	await _refresh_merchant_cards()


func open() -> void:
	UiManager.show_panel(self)
	await _refresh_merchant_cards()
	AudioManager.play_ui_sound(UI_SOUNDS.MERCHANT_ENTRY)


# Shuffle both pools, pick runes and enhancements, then mix them in one grid.
func _refresh_merchant_cards() -> void:
	merchant_inventory.clear()

	var shuffled_runes := GameManager.runes_pool.duplicate()
	shuffled_runes.shuffle()

	for i in mini(MERCHANT_RUNE_COUNT, shuffled_runes.size()):
		merchant_inventory.append(shuffled_runes[i])

	var shuffled_enhancements := GameManager.enhancements_pool.duplicate()
	shuffled_enhancements.shuffle()

	for i in mini(MERCHANT_ENHANCEMENT_COUNT, shuffled_enhancements.size()):
		merchant_inventory.append(shuffled_enhancements[i])

	merchant_inventory.shuffle()
	await _display_merchant_cards()


# Clear the grid and instantiate a CardUI for each offered item.
func _display_merchant_cards() -> void:
	_displayed_cards.clear()

	for child in cards_grid.get_children():
		child.queue_free()

	# Wait one frame so freed card nodes are removed before repopulating.
	await get_tree().process_frame

	for item in merchant_inventory:
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.configure_interaction(
			CardUI.InteractionMode.MERCHANT,
			{"discount": _merchant_discount}
		)
		cards_grid.add_child(card_ui)
		card_ui.set_card(item)
		card_ui.action_requested.connect(_on_merchant_card_purchased)
		_displayed_cards.append(card_ui)


func _on_merchant_card_purchased(card_ui: CardUI) -> void:
	if card_ui.is_sold():
		return

	var price := card_ui.price
	if not GoldManager.can_afford(price):
		return

	GoldManager.remove(price)
	card_ui.mark_sold()

	var card : Resource = card_ui.card
	if card is Rune:
		Events.rune_selected.emit(card as Rune)
		Events.merchant_item_purchased.emit("rune")
	elif card is Enhancement:
		Events.enhancement_selected.emit(card as Enhancement)
		Events.merchant_item_purchased.emit("enhancement")

	AudioManager.play_ui_sound(UI_SOUNDS.MERCHANT_CARD_PURCHASED)
	_update_reroll_button()


func _on_reroll_button_pressed() -> void:
	if not GoldManager.can_afford(reroll_cost):
		return

	GoldManager.remove(reroll_cost)
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	await _refresh_merchant_cards()
	reroll_counter += 1
	reroll_cost = BASE_REROLL_COST * reroll_counter
	_update_reroll_button()


func _on_leave_button_pressed() -> void:
	hide()
	if UiManager.active_panel == self:
		UiManager.active_panel = null
	Events.merchant_closed.emit()


func _on_gold_changed(_new_amount: int) -> void:
	for card_ui in _displayed_cards:
		card_ui.refresh_affordability()
	_update_reroll_button()


func _on_merchant_discount_changed(new_discount: float) -> void:
	_merchant_discount = clampf(new_discount, 0.0, 1.0)

	for card_ui in _displayed_cards:
		card_ui.apply_discount(_merchant_discount)


func _update_reroll_button() -> void:
	reroll_button.text = "Reroll: $%d" % reroll_cost
	reroll_button.disabled = not GoldManager.can_afford(reroll_cost)
