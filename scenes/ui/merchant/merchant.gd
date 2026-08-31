class_name Merchant
extends Control

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const POTION_ITEM_SCENE := preload("res://scenes/ui/potions/potion_shop_item.tscn")
const MERCHANT_TILE_CARD_COUNT := 3
const BASE_REROLL_COST := 5

@onready var cards_grid: GridContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/CardsGridContainer
@onready var potions_grid: HBoxContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/ShelfRow/PotionShelf/PotionsGrid
@onready var gold_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/GoldAmount
@onready var token_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/TokenAmount
@onready var buy_gold_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/PurchasePanel/BuyGoldButton
@onready var buy_token_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/PurchasePanel/BuyTokenButton
@onready var reroll_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/RerollButton
@onready var leave_button: Button = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/LeaveButton
@onready var _content_panel: Panel = $ContainerPanel
@onready var _show_board_button: Button = $ContainerPanel/ShowBoardButton
@onready var _show_merchant_button: Button = $ShowMerchantButton

var _displayed_cards: Array[CardUI] = []
var _displayed_potions: Array[PotionShopItem] = []
var _selected_card_ui: CardUI = null
var _selected_potion_ui: PotionShopItem = null
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
	buy_gold_button.pressed.connect(_on_buy_gold_button_pressed)
	buy_token_button.pressed.connect(_on_buy_token_button_pressed)
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	_show_board_button.pressed.connect(_on_show_board_button_pressed)
	_show_merchant_button.pressed.connect(_on_show_merchant_button_pressed)
	EventBus.gold_changed.connect(_on_currency_changed)
	EventBus.merchant_tokens_changed.connect(_on_currency_changed)
	EventBus.rerolls_changed.connect(_on_currency_changed)
	EventBus.potion_belt_changed.connect(_on_currency_changed)
	EventBus.potion_targeting_changed.connect(_on_potion_targeting_changed)
	UiManager.show_merchant_panel.connect(open)
	_update_currency_display()
	_update_reroll_button()
	_clear_selection()


func open() -> void:
	var restoring := not _restore_state.is_empty()
	var sold_card_indices: Array = []
	var sold_potion_indices: Array = []
	_session_open = true
	_set_board_view(false)
	if restoring:
		_stock_reroll_count = int(_restore_state.get("stock_reroll_count", 0))
		_reroll_cost = int(_restore_state.get("reroll_cost", BASE_REROLL_COST))
		sold_card_indices = _restore_state.get("sold_indices", [])
		sold_potion_indices = _restore_state.get("sold_potion_indices", [])
		_restore_state.clear()
	else:
		_stock_reroll_count = 0
		_reroll_cost = BASE_REROLL_COST
	_update_reroll_button()
	UiManager.show_panel(self)
	await _refresh_merchant_stock()
	_apply_sold_indices(sold_card_indices)
	_apply_sold_potion_indices(sold_potion_indices)
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


func _on_potion_targeting_changed(slot_index: int) -> void:
	if not visible:
		return
	if slot_index >= 0:
		_set_board_view(true)


func _refresh_merchant_stock() -> void:
	_clear_selection()
	await _refresh_merchant_cards()
	await _refresh_merchant_potions()


func _refresh_merchant_cards() -> void:
	var stream_name: String = RunRng.build_merchant_stream_name(
		GameManager.current_round,
		_stock_reroll_count
	)
	var loot_rng: RandomNumberGenerator = RunRng.create_rng(stream_name)
	var drafted_runes := RuneLoot.draw_runes(
		MERCHANT_TILE_CARD_COUNT,
		GameManager.tile_cards_pool,
		true,
		loot_rng
	)
	var inventory: Array[Card] = []
	for rune in drafted_runes:
		inventory.append(rune)
	await _display_merchant_cards(inventory)


func _refresh_merchant_potions() -> void:
	var stream_name := "merchant_potions:r%d:e%d" % [GameManager.current_round, _stock_reroll_count]
	var loot_rng := RunRng.create_rng(stream_name)
	var drawn := PotionCatalog.draw_unique(PotionManager.SHOP_STOCK, loot_rng)
	await _display_merchant_potions(drawn)


func _display_merchant_cards(inventory: Array[Card]) -> void:
	_displayed_cards.clear()

	for child in cards_grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	for item in inventory:
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.custom_minimum_size = Vector2(230, 340 + CardUI.PRICE_BELOW_HEIGHT)
		card_ui.configure_interaction(CardUI.InteractionMode.MERCHANT_STOCK)
		cards_grid.add_child(card_ui)
		card_ui.set_card(item)
		card_ui.action_requested.connect(_on_stock_card_selected)
		_displayed_cards.append(card_ui)


func _display_merchant_potions(stock: Array[Potion]) -> void:
	_displayed_potions.clear()
	for child in potions_grid.get_children():
		child.queue_free()
	await get_tree().process_frame
	for potion in stock:
		var item: PotionShopItem = POTION_ITEM_SCENE.instantiate()
		potions_grid.add_child(item)
		item.configure(potion)
		item.selected.connect(_on_stock_potion_selected)
		_displayed_potions.append(item)


func _on_stock_card_selected(card_ui: CardUI) -> void:
	if card_ui.is_sold():
		return
	_clear_potion_selection()
	if _selected_card_ui != null and _selected_card_ui != card_ui:
		_selected_card_ui.set_merchant_selected(false)
	_selected_card_ui = card_ui
	_selected_card_ui.set_merchant_selected(true)
	_update_purchase_panel()


func _on_stock_potion_selected(item: PotionShopItem) -> void:
	if item.is_sold():
		return
	_clear_card_selection()
	if _selected_potion_ui != null and _selected_potion_ui != item:
		_selected_potion_ui.set_merchant_selected(false)
	_selected_potion_ui = item
	_selected_potion_ui.set_merchant_selected(true)
	_update_purchase_panel()


func _on_buy_gold_button_pressed() -> void:
	_complete_purchase(false)


func _on_buy_token_button_pressed() -> void:
	_complete_purchase(true)


func _complete_purchase(pay_with_tokens: bool) -> void:
	if _selected_potion_ui != null:
		_complete_potion_purchase(pay_with_tokens)
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


func _complete_potion_purchase(pay_with_tokens: bool) -> void:
	if _selected_potion_ui == null or _selected_potion_ui.is_sold():
		return
	if not PotionManager.can_add():
		return
	var gold_price := _selected_potion_ui.price
	var token_cost := _selected_potion_ui.get_token_cost()
	if pay_with_tokens:
		if not GoldManager.spend_tokens(token_cost):
			return
	else:
		if not GoldManager.can_afford(gold_price):
			return
		GoldManager.remove(gold_price)
	if not PotionManager.add_potion(_selected_potion_ui.potion):
		return
	_selected_potion_ui.mark_sold()
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
	for potion_ui in _displayed_potions:
		potion_ui.refresh_affordability()
	_update_reroll_button()
	_update_purchase_panel()


func _clear_selection() -> void:
	_clear_card_selection()
	_clear_potion_selection()
	_update_purchase_panel()


func _clear_card_selection() -> void:
	if _selected_card_ui != null:
		_selected_card_ui.set_merchant_selected(false)
	_selected_card_ui = null


func _clear_potion_selection() -> void:
	if _selected_potion_ui != null:
		_selected_potion_ui.set_merchant_selected(false)
	_selected_potion_ui = null


func _update_purchase_panel() -> void:
	if _selected_potion_ui != null and not _selected_potion_ui.is_sold():
		var gold_price := _selected_potion_ui.price
		var token_cost := _selected_potion_ui.get_token_cost()
		var belt_full := not PotionManager.can_add()
		buy_gold_button.disabled = belt_full or not GoldManager.can_afford(gold_price)
		buy_token_button.disabled = belt_full or not GoldManager.can_afford_tokens(token_cost)
		return

	var has_selection := _selected_card_ui != null and not _selected_card_ui.is_sold()
	if not has_selection:
		buy_gold_button.disabled = true
		buy_token_button.disabled = true
		return

	var card_gold := _selected_card_ui.price
	var card_tokens := _selected_card_ui.get_token_cost()
	buy_gold_button.disabled = not GoldManager.can_afford(card_gold)
	buy_token_button.disabled = not GoldManager.can_afford_tokens(card_tokens)


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
	var sold_potion_indices: Array = []
	for index in _displayed_potions.size():
		if _displayed_potions[index].is_sold():
			sold_potion_indices.append(index)
	return {
		"open": _session_open,
		"stock_reroll_count": _stock_reroll_count,
		"reroll_cost": _reroll_cost,
		"sold_indices": sold_indices,
		"sold_potion_indices": sold_potion_indices,
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


func _apply_sold_potion_indices(sold_indices: Array) -> void:
	for entry in sold_indices:
		var index := int(entry)
		if index < 0 or index >= _displayed_potions.size():
			continue
		_displayed_potions[index].mark_sold()


func _hide_purchased_stock(card_ui: CardUI) -> void:
	card_ui.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
