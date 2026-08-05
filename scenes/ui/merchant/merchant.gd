extends Control

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const MERCHANT_CARD_COUNT := 6
const MERCHANT_ENHANCMENT_COUNT := 2
const REROLL_COST := 10
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var cards_grid: GridContainer = $ContainerPanel/MarginContainer/HBoxContainer/CardsGridContainer
@onready var enhancements_grid: GridContainer = $ContainerPanel/MarginContainer/HBoxContainer/EnhancementGridContainer
@onready var reroll_button: Button = $ContainerPanel/MarginContainer/HBoxContainer/VBoxContainer/Button
@onready var leave_button: Button = $ContainerPanel/MarginContainer/LeaveButton

# Runes and enhancements currently offered for purchase in the merchant grids.
var merchant_inventory: Array[Rune] = []
var merchant_enhancement_inventory: Array[Enhancement] = []
var _displayed_cards: Array[CardUI] = []
var _displayed_enhancement_cards: Array[CardUI] = []
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


# Shuffle both pools and pick random cards for each merchant grid.
func _refresh_merchant_cards() -> void:
	merchant_inventory.clear()
	merchant_enhancement_inventory.clear()

	var shuffled_runes := GameManager.runes_pool.duplicate()
	shuffled_runes.shuffle()

	for i in mini(MERCHANT_CARD_COUNT, shuffled_runes.size()):
		merchant_inventory.append(shuffled_runes[i])

	var shuffled_enhancements := GameManager.enhancements_pool.duplicate()
	shuffled_enhancements.shuffle()

	for i in mini(MERCHANT_ENHANCMENT_COUNT, shuffled_enhancements.size()):
		merchant_enhancement_inventory.append(shuffled_enhancements[i])

	await _display_merchant_cards()


# Clear both grids and instantiate a CardUI for each offered item.
func _display_merchant_cards() -> void:
	_displayed_cards.clear()
	_displayed_enhancement_cards.clear()

	for child in cards_grid.get_children():
		child.queue_free()
	for child in enhancements_grid.get_children():
		child.queue_free()

	# Wait one frame so freed card nodes are removed before repopulating.
	await get_tree().process_frame

	for rune in merchant_inventory:
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.configure_interaction(
			CardUI.InteractionMode.MERCHANT,
			{"discount": _merchant_discount}
		)
		cards_grid.add_child(card_ui)
		card_ui.set_card(rune)
		card_ui.action_requested.connect(_on_merchant_card_purchased)
		_displayed_cards.append(card_ui)

	for enhancement in merchant_enhancement_inventory:
		var enhancement_card: CardUI = CARD_UI_SCENE.instantiate()
		enhancement_card.configure_interaction(
			CardUI.InteractionMode.MERCHANT,
			{"discount": _merchant_discount}
		)
		enhancements_grid.add_child(enhancement_card)
		enhancement_card.set_card(enhancement)
		enhancement_card.action_requested.connect(_on_merchant_card_purchased)
		_displayed_enhancement_cards.append(enhancement_card)


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
	if not GoldManager.can_afford(REROLL_COST):
		return

	GoldManager.remove(REROLL_COST)
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	await _refresh_merchant_cards()
	_update_reroll_button()


func _on_leave_button_pressed() -> void:
	hide()
	if UiManager.active_panel == self:
		UiManager.active_panel = null
	Events.merchant_closed.emit()


func _on_gold_changed(_new_amount: int) -> void:
	for card_ui in _displayed_cards:
		card_ui.refresh_affordability()
	for card_ui in _displayed_enhancement_cards:
		card_ui.refresh_affordability()
	_update_reroll_button()


func _on_merchant_discount_changed(new_discount: float) -> void:
	_merchant_discount = clampf(new_discount, 0.0, 1.0)

	for card_ui in _displayed_cards:
		card_ui.apply_discount(_merchant_discount)
	for card_ui in _displayed_enhancement_cards:
		card_ui.apply_discount(_merchant_discount)


func _update_reroll_button() -> void:
	reroll_button.text = "Reroll: $%d" % REROLL_COST
	reroll_button.disabled = not GoldManager.can_afford(REROLL_COST)
