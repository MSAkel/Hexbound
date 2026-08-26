extends Control

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const MERCHANT_TILE_CARD_COUNT := 2
const MERCHANT_ENHANCEMENT_COUNT := 1
const BASE_REROLL_COST := 5
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var cards_grid: GridContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/CardsGridContainer
@onready var gold_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/GoldAmount
@onready var token_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/TokenAmount
@onready var buy_gold_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSide/PurchasePanel/BuyGoldButton
@onready var buy_token_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSide/PurchasePanel/BuyTokenButton
@onready var reroll_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSide/RerollButton
@onready var leave_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSide/LeaveButton
@onready var _content_panel: Panel = $ContainerPanel
@onready var _show_board_button: Button = $ContainerPanel/ShowBoardButton
@onready var _show_merchant_button: Button = $ShowMerchantButton

var reroll_cost := BASE_REROLL_COST
var _displayed_cards: Array[CardUI] = []
var _selected_card_ui: CardUI = null


func _ready() -> void:
	hide()
	buy_gold_button.pressed.connect(_on_buy_gold_button_pressed)
	buy_token_button.pressed.connect(_on_buy_token_button_pressed)
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	_show_board_button.pressed.connect(_on_show_board_button_pressed)
	_show_merchant_button.pressed.connect(_on_show_merchant_button_pressed)
	EventBus.gold_changed.connect(_on_currency_changed)
	EventBus.merchant_tokens_changed.connect(_on_currency_changed)
	UiManager.show_merchant_panel.connect(open)
	_update_currency_display()
	_update_reroll_button()
	_clear_selection()


func open() -> void:
	_set_board_view(false)
	reroll_cost = BASE_REROLL_COST
	_update_reroll_button()
	UiManager.show_panel(self)
	await _refresh_merchant_cards()
	AudioManager.play_sfx(UI_SOUNDS.MERCHANT_BELL)
	AudioManager.play_sfx(UI_SOUNDS.MERCHANT_ENTRY)


func _input(event: InputEvent) -> void:
	if not visible or not _content_panel.visible:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_clear_selection()
		get_viewport().set_input_as_handled()


func _on_show_board_button_pressed() -> void:
	_set_board_view(true)


func _on_show_merchant_button_pressed() -> void:
	_set_board_view(false)


## Hide the merchant overlay so the player can inspect the board and hand.
## Does not close the merchant or advance round flow.
func _set_board_view(active: bool) -> void:
	_content_panel.visible = not active
	_show_merchant_button.visible = active
	mouse_filter = Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP


func _refresh_merchant_cards() -> void:
	_clear_selection()

	var inventory: Array[Card] = []
	var drafted_runes := RuneLoot.draw_runes(MERCHANT_TILE_CARD_COUNT, GameManager.tile_cards_pool)
	for rune in drafted_runes:
		inventory.append(rune)

	var shuffled_enhancements := GameManager.enhancements_pool.duplicate()
	shuffled_enhancements.shuffle()

	for i in mini(MERCHANT_ENHANCEMENT_COUNT, shuffled_enhancements.size()):
		inventory.append(shuffled_enhancements[i])

	inventory.shuffle()
	await _display_merchant_cards(inventory)


func _display_merchant_cards(inventory: Array[Card]) -> void:
	_displayed_cards.clear()

	for child in cards_grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	for item in inventory:
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.custom_minimum_size = Vector2(260, 385)
		card_ui.configure_interaction(CardUI.InteractionMode.MERCHANT_STOCK)
		cards_grid.add_child(card_ui)
		# The shared card keeps hand-sized fixed content by default. Let merchant
		# instances use their full larger height so long descriptions stay inside.
		card_ui.content_container.anchor_bottom = 1.0
		card_ui.content_container.offset_bottom = -7.0
		card_ui.set_card(item)
		card_ui.action_requested.connect(_on_stock_card_selected)
		_displayed_cards.append(card_ui)

func _on_stock_card_selected(card_ui: CardUI) -> void:
	if card_ui.is_sold():
		return

	if _selected_card_ui != null and _selected_card_ui != card_ui:
		_selected_card_ui.set_merchant_selected(false)

	_selected_card_ui = card_ui
	_selected_card_ui.set_merchant_selected(true)
	_update_purchase_panel()


func _on_buy_gold_button_pressed() -> void:
	_complete_purchase(false)


func _on_buy_token_button_pressed() -> void:
	_complete_purchase(true)


func _complete_purchase(pay_with_tokens: bool) -> void:
	if _selected_card_ui == null or _selected_card_ui.is_sold():
		return

	var card: Card = _selected_card_ui.card
	var gold_price := _selected_card_ui.price
	var token_cost := _selected_card_ui.get_token_cost()

	if pay_with_tokens:
		if not GoldManager.spend_tokens(token_cost):
			return
	else:
		if not GoldManager.can_afford(gold_price):
			return
		GoldManager.remove(gold_price)

	_selected_card_ui.mark_sold()
	# Keep the control in the grid as an invisible, inert placeholder so the
	# remaining stock never shifts when an item is purchased.
	_selected_card_ui.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_selected_card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if card is TileCard:
		EventBus.tile_card_selected.emit(card as TileCard)
	elif card is Enhancement:
		EventBus.enhancement_selected.emit(card as Enhancement)

	AudioManager.play_sfx(
		UI_SOUNDS.CLICK if pay_with_tokens else UI_SOUNDS.MERCHANT_CARD_PURCHASED
	)
	_clear_selection()
	_update_reroll_button()


func _on_reroll_button_pressed() -> void:
	if not GoldManager.can_afford(reroll_cost):
		return

	GoldManager.remove(reroll_cost)
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	await _refresh_merchant_cards()
	reroll_cost += 1
	_update_reroll_button()


func _on_leave_button_pressed() -> void:
	_set_board_view(false)
	hide()
	if UiManager.active_panel == self:
		UiManager.active_panel = null
	EventBus.merchant_closed.emit()


func _on_currency_changed(_new_amount: int = 0) -> void:
	_update_currency_display()
	for card_ui in _displayed_cards:
		card_ui.refresh_affordability()
	_update_reroll_button()
	_update_purchase_panel()


func _clear_selection() -> void:
	if _selected_card_ui != null:
		_selected_card_ui.set_merchant_selected(false)
	_selected_card_ui = null
	_update_purchase_panel()


func _update_purchase_panel() -> void:
	var has_selection := _selected_card_ui != null and not _selected_card_ui.is_sold()

	if not has_selection:
		buy_gold_button.disabled = true
		buy_token_button.disabled = true
		return

	var gold_price := _selected_card_ui.price
	var token_cost := _selected_card_ui.get_token_cost()
	buy_gold_button.disabled = not GoldManager.can_afford(gold_price)
	buy_token_button.disabled = not GoldManager.can_afford_tokens(token_cost)


func _update_currency_display() -> void:
	gold_amount_label.text = str(GoldManager.amount)
	token_amount_label.text = "%d/%d" % [GoldManager.merchant_tokens, GoldManager.MAX_MERCHANT_TOKENS]


func _update_reroll_button() -> void:
	reroll_button.text = "REROLL - %d" % reroll_cost
	reroll_button.disabled = not GoldManager.can_afford(reroll_cost)
