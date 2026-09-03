class_name Merchant
extends Control

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CONDIMENT_ITEM_SCENE := preload("res://scenes/ui/condiments/condiment_shop_item.tscn")
const MERCHANT_TILE_CARD_COUNT := 3
const BASE_REROLL_COST := 5

@onready var cards_grid: GridContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/CardsGridContainer
@onready var condiments_grid: HBoxContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/ShelfRow/CondimentShelf/CondimentsGrid
@onready var gold_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/GoldAmount
@onready var token_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/TokenAmount
@onready var reroll_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/RerollButton
@onready var leave_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/LeaveButton
@onready var _content_panel: Panel = $ContainerPanel
@onready var _show_board_button: Button = $ContainerPanel/ShowBoardButton
@onready var _show_merchant_button: Button = $ShowMerchantButton

var _displayed_cards: Array[CardUI] = []
var _displayed_condiments: Array[CondimentShopItem] = []
var _selected_card_ui: CardUI = null
var _selected_condiment_ui: CondimentShopItem = null
var _stock_reroll_count := 0
## Gold cost for the next merchant reroll. Resets when the shop opens.
var _reroll_cost := BASE_REROLL_COST
## Pending shop snapshot applied the next time open() runs after a continue.
var _restore_state: Dictionary = {}
## True from open() until Leave. Independent of board-peek visibility.
var _session_open := false


func _ready() -> void:
	add_to_group("run_merchant")
	hide()
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	_show_board_button.pressed.connect(_on_show_board_button_pressed)
	_show_merchant_button.pressed.connect(_on_show_merchant_button_pressed)
	EventBus.gold_changed.connect(_on_currency_changed)
	EventBus.merchant_tokens_changed.connect(_on_currency_changed)
	EventBus.rerolls_changed.connect(_on_currency_changed)
	EventBus.condiment_belt_changed.connect(_on_currency_changed)
	EventBus.condiment_targeting_changed.connect(_on_condiment_targeting_changed)
	UiManager.show_merchant_panel.connect(open)
	_update_currency_display()
	_update_reroll_button()
	_clear_selection()


func open() -> void:
	var restoring := not _restore_state.is_empty()
	var sold_card_indices: Array = []
	var sold_condiment_indices: Array = []
	_session_open = true
	_set_board_view(false)
	if restoring:
		_stock_reroll_count = int(_restore_state.get("stock_reroll_count", 0))
		_reroll_cost = int(_restore_state.get("reroll_cost", BASE_REROLL_COST))
		sold_card_indices = _restore_state.get("sold_indices", [])
		sold_condiment_indices = _restore_state.get("sold_condiment_indices", [])
		_restore_state.clear()
	else:
		_stock_reroll_count = 0
		_reroll_cost = BASE_REROLL_COST
	_update_reroll_button()
	UiManager.show_panel(self)
	await _refresh_merchant_stock()
	_apply_sold_indices(sold_card_indices)
	_apply_sold_condiment_indices(sold_condiment_indices)
	if restoring:
		return
	AudioManager.play_sfx(UISounds.MERCHANT_BELL)
	AudioManager.play_sfx(UISounds.MERCHANT_ENTRY)


func _input(event: InputEvent) -> void:
	if not visible or not _content_panel.visible:
		return
	if get_viewport().is_input_handled():
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


func _on_condiment_targeting_changed(slot_index: int) -> void:
	if not visible:
		return
	if slot_index >= 0:
		_set_board_view(true)


func _refresh_merchant_stock() -> void:
	_clear_selection()
	await _refresh_merchant_cards()
	await _refresh_merchant_condiments()


func _refresh_merchant_cards() -> void:
	var stream_name: String = RunRng.build_merchant_stream_name(
		GameManager.current_round,
		_stock_reroll_count
	)
	var loot_rng: RandomNumberGenerator = RunRng.create_rng(stream_name)
	var drafted_runes := CardLoot.draw_runes(
		MERCHANT_TILE_CARD_COUNT,
		GameManager.tile_cards_pool,
		true,
		loot_rng
	)
	var inventory: Array[Card] = []
	for rune in drafted_runes:
		inventory.append(rune)
	await _display_merchant_cards(inventory)


func _refresh_merchant_condiments() -> void:
	var stream_name := "merchant_condiments:r%d:e%d" % [GameManager.current_round, _stock_reroll_count]
	var loot_rng := RunRng.create_rng(stream_name)
	var drawn := CondimentCatalog.draw_unique(CondimentManager.SHOP_STOCK, loot_rng)
	await _display_merchant_condiments(drawn)


func _display_merchant_cards(inventory: Array[Card]) -> void:
	_displayed_cards.clear()

	for child in cards_grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	for item in inventory:
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.custom_minimum_size = Vector2(230, CardUI.MERCHANT_STOCK_SLOT_HEIGHT)
		card_ui.configure_interaction(CardUI.InteractionMode.MERCHANT_STOCK)
		cards_grid.add_child(card_ui)
		card_ui.set_card(item)
		card_ui.action_requested.connect(_on_stock_card_selected)
		card_ui.gold_purchase_requested.connect(_on_stock_card_gold_purchase_requested)
		card_ui.token_purchase_requested.connect(_on_stock_card_token_purchase_requested)
		_displayed_cards.append(card_ui)


func _display_merchant_condiments(stock: Array[Condiment]) -> void:
	_displayed_condiments.clear()
	for child in condiments_grid.get_children():
		child.queue_free()
	await get_tree().process_frame
	for condiment in stock:
		var item: CondimentShopItem = CONDIMENT_ITEM_SCENE.instantiate()
		condiments_grid.add_child(item)
		item.configure(condiment)
		item.selected.connect(_on_stock_condiment_selected)
		item.gold_purchase_requested.connect(_on_stock_condiment_gold_purchase_requested)
		item.token_purchase_requested.connect(_on_stock_condiment_token_purchase_requested)
		_displayed_condiments.append(item)


func _on_stock_card_selected(card_ui: CardUI) -> void:
	if card_ui.is_sold():
		return
	_clear_condiment_selection()
	if _selected_card_ui != null and _selected_card_ui != card_ui:
		_selected_card_ui.set_merchant_selected(false)
	_selected_card_ui = card_ui
	_selected_card_ui.set_merchant_selected(true)
	_refresh_selected_purchase_tray()


func _on_stock_condiment_selected(item: CondimentShopItem) -> void:
	if item.is_sold():
		return
	_clear_card_selection()
	if _selected_condiment_ui != null and _selected_condiment_ui != item:
		_selected_condiment_ui.set_merchant_selected(false)
	_selected_condiment_ui = item
	_selected_condiment_ui.set_merchant_selected(true)
	_refresh_selected_purchase_tray()


func _on_stock_card_gold_purchase_requested(card_ui: CardUI) -> void:
	if _selected_card_ui != card_ui:
		return
	_complete_purchase(false)


func _on_stock_card_token_purchase_requested(card_ui: CardUI) -> void:
	if _selected_card_ui != card_ui:
		return
	_complete_purchase(true)


func _on_stock_condiment_gold_purchase_requested(item: CondimentShopItem) -> void:
	if _selected_condiment_ui != item:
		return
	_complete_purchase(false)


func _on_stock_condiment_token_purchase_requested(item: CondimentShopItem) -> void:
	if _selected_condiment_ui != item:
		return
	_complete_purchase(true)


func _complete_purchase(pay_with_tokens: bool) -> void:
	if _selected_condiment_ui != null:
		_complete_condiment_purchase(pay_with_tokens)
		return
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
	_hide_purchased_stock(_selected_card_ui)

	if card is TileCard:
		EventBus.tile_card_selected.emit(card as TileCard)

	AudioManager.play_sfx(
		UISounds.CLICK if pay_with_tokens else UISounds.MERCHANT_CARD_PURCHASED
	)
	_clear_selection()
	_update_reroll_button()


func _complete_condiment_purchase(pay_with_tokens: bool) -> void:
	if _selected_condiment_ui == null or _selected_condiment_ui.is_sold():
		return
	if not CondimentManager.can_add():
		return
	var gold_price := _selected_condiment_ui.price
	var token_cost := _selected_condiment_ui.get_token_cost()
	if pay_with_tokens:
		if not GoldManager.spend_tokens(token_cost):
			return
	else:
		if not GoldManager.can_afford(gold_price):
			return
		GoldManager.remove(gold_price)
	if not CondimentManager.add_condiment(_selected_condiment_ui.condiment):
		return
	_selected_condiment_ui.mark_sold()
	AudioManager.play_sfx(
		UISounds.CLICK if pay_with_tokens else UISounds.MERCHANT_CARD_PURCHASED
	)
	_clear_selection()
	_update_reroll_button()


func _on_reroll_button_pressed() -> void:
	if RerollManager.can_reroll():
		RerollManager.use_reroll()
	else:
		if not GoldManager.can_afford(_reroll_cost):
			return
		GoldManager.remove(_reroll_cost)
		_reroll_cost += 1

	AudioManager.play_sfx(UISounds.CLICK)
	_stock_reroll_count += 1
	await _refresh_merchant_stock()
	_update_reroll_button()
	RunSaveManager.request_autosave()


func _on_leave_button_pressed() -> void:
	_session_open = false
	_set_board_view(false)
	hide()
	EventBus.merchant_closed.emit()


func _on_currency_changed(_new_amount: int = 0) -> void:
	_update_currency_display()
	for card_ui in _displayed_cards:
		card_ui.refresh_affordability()
	for condiment_ui in _displayed_condiments:
		condiment_ui.refresh_affordability()
	_update_reroll_button()
	_refresh_selected_purchase_tray()


func _clear_selection() -> void:
	_clear_card_selection()
	_clear_condiment_selection()


func _clear_card_selection() -> void:
	if _selected_card_ui != null:
		_selected_card_ui.set_merchant_selected(false)
	_selected_card_ui = null


func _clear_condiment_selection() -> void:
	if _selected_condiment_ui != null:
		_selected_condiment_ui.set_merchant_selected(false)
	_selected_condiment_ui = null


func _refresh_selected_purchase_tray() -> void:
	if _selected_card_ui != null and not _selected_card_ui.is_sold():
		_selected_card_ui.refresh_purchase_tray()
	if _selected_condiment_ui != null and not _selected_condiment_ui.is_sold():
		_selected_condiment_ui.refresh_purchase_tray()


func _update_currency_display() -> void:
	gold_amount_label.text = str(GoldManager.amount)
	token_amount_label.text = "%d/%d" % [GoldManager.merchant_tokens, GoldManager.MAX_MERCHANT_TOKENS]


func _update_reroll_button() -> void:
	if RerollManager.can_reroll():
		reroll_button.text = "REROLL (%d free)" % RerollManager.remaining
		reroll_button.disabled = false
		return
	reroll_button.text = "REROLL - %d" % _reroll_cost
	reroll_button.disabled = not GoldManager.can_afford(_reroll_cost)


func capture_shop_state() -> Dictionary:
	var sold_indices: Array = []
	for index in _displayed_cards.size():
		if _displayed_cards[index].is_sold():
			sold_indices.append(index)
	var sold_condiment_indices: Array = []
	for index in _displayed_condiments.size():
		if _displayed_condiments[index].is_sold():
			sold_condiment_indices.append(index)
	return {
		"open": _session_open,
		"stock_reroll_count": _stock_reroll_count,
		"reroll_cost": _reroll_cost,
		"sold_indices": sold_indices,
		"sold_condiment_indices": sold_condiment_indices,
	}


func apply_shop_state(state: Dictionary) -> void:
	if state.is_empty():
		_restore_state.clear()
		return
	_restore_state = state.duplicate(true)


## RoundFlow reopens the merchant. This covers a save where the shop was visible
## while round flow was already idle.
func restore_open_if_needed() -> void:
	if _restore_state.is_empty():
		return
	if not bool(_restore_state.get("open", false)):
		_restore_state.clear()
		return
	if RoundFlow.get_step() == RoundFlow.Step.MERCHANT:
		return
	open()


func _apply_sold_indices(sold_indices: Array) -> void:
	for entry in sold_indices:
		var index := int(entry)
		if index < 0 or index >= _displayed_cards.size():
			continue
		_displayed_cards[index].mark_sold()
		_hide_purchased_stock(_displayed_cards[index])


func _apply_sold_condiment_indices(sold_indices: Array) -> void:
	for entry in sold_indices:
		var index := int(entry)
		if index < 0 or index >= _displayed_condiments.size():
			continue
		_displayed_condiments[index].mark_sold()


func _hide_purchased_stock(card_ui: CardUI) -> void:
	card_ui.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
