class_name Merchant
extends Control

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CONDIMENT_ITEM_SCENE := preload("res://scenes/ui/condiments/condiment_shop_item.tscn")
const MERCHANT_TILE_CARD_COUNT := 3
## Extra shelf slot that always offers a staff member the player does not own.
const MERCHANT_STAFF_COUNT := 1
const BASE_REROLL_COST := 5

@onready var cards_grid: GridContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/CardsGridContainer
@onready var condiments_grid: HBoxContainer = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/ShelfRow/CondimentShelf/CondimentsGrid
@onready var gold_amount_label: Label = $ContainerPanel/ShopPanel/MarginContainer/MainVBox/CurrencyRow/GoldAmount
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
## Shelf slot -> locked Card. Locked items keep their slot through rerolls and later days.
var _locked_cards: Dictionary = {}
## Condiment shelf slot -> locked Condiment.
var _locked_condiments: Dictionary = {}


func _ready() -> void:
	add_to_group("run_merchant")
	add_to_group(InputManager.MENU_GROUP)
	hide()
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	_show_board_button.pressed.connect(_on_show_board_button_pressed)
	_show_merchant_button.pressed.connect(_on_show_merchant_button_pressed)
	EventBus.gold_changed.connect(_on_currency_changed)
	EventBus.rerolls_changed.connect(_on_currency_changed)
	EventBus.condiment_belt_changed.connect(_on_currency_changed)
	# A freed staff slot re-enables Buy on the staff shelf card.
	EventBus.staff_roster_changed.connect(_on_currency_changed)
	EventBus.condiment_targeting_changed.connect(_on_condiment_targeting_changed)
	UiManager.show_merchant_panel.connect(open)
	# Picking up a controller mid-shop should place a focus ring without a re-open.
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	PadPrompt.attach(_show_board_button, InputManager.ACTION_ALT, PadPrompt.Side.LEFT)
	PadPrompt.attach(_show_merchant_button, InputManager.ACTION_ALT, PadPrompt.Side.LEFT)
	_update_currency_display()
	_update_reroll_button()
	_clear_selection()


func open() -> void:
	var restoring := not _restore_state.is_empty()
	var sold_card_indices: Array = []
	var sold_condiment_indices: Array = []
	var restored_cards: Array[Card] = []
	var restored_condiments: Array[Condiment] = []
	_session_open = true
	_set_board_view(false)
	if restoring:
		_stock_reroll_count = int(_restore_state.get("stock_reroll_count", 0))
		_reroll_cost = int(_restore_state.get("reroll_cost", BASE_REROLL_COST))
		sold_card_indices = _restore_state.get("sold_indices", [])
		sold_condiment_indices = _restore_state.get("sold_condiment_indices", [])
		for entry in _restore_state.get("stock_cards", []):
			var card := _card_from_save(entry)
			if card != null:
				restored_cards.append(card)
		for entry in _restore_state.get("stock_condiments", []):
			var condiment := CondimentCatalog.get_by_id(str(entry))
			if condiment != null:
				restored_condiments.append(condiment)
		_restore_state.clear()
	else:
		_stock_reroll_count = 0
		_reroll_cost = BASE_REROLL_COST
	_update_reroll_button()
	UiManager.show_panel(self)
	await _refresh_merchant_stock(restored_cards, restored_condiments)
	_apply_sold_indices(sold_card_indices)
	_apply_sold_condiment_indices(sold_condiment_indices)
	_queue_focus()
	if restoring:
		return
	AudioManager.play_sfx(UISounds.MERCHANT_BELL)
	AudioManager.play_sfx(UISounds.MERCHANT_ENTRY)


func _input(event: InputEvent) -> void:
	if not visible or get_viewport().is_input_handled():
		return
	if event.is_action_pressed(InputManager.ACTION_ALT):
		set_board_view(_content_panel.visible)
		get_viewport().set_input_as_handled()
		return
	if not _content_panel.visible:
		return
	# Back on a selected item drops the buy tray and returns focus to the shelf.
	if _has_selection() and event.is_action_pressed(&"ui_cancel"):
		_clear_selection()
		_queue_focus()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_clear_selection()
		get_viewport().set_input_as_handled()


func _on_input_mode_changed(using_gamepad: bool) -> void:
	if using_gamepad and visible:
		_queue_focus()


## InputManager menu hook. The board view hands input to the in-run controller.
func is_gamepad_menu_active() -> bool:
	return _content_panel.visible


## InputManager menu hook.
func focus_default() -> void:
	_focus_merchant()


func is_board_view_active() -> bool:
	return visible and not _content_panel.visible


func set_board_view(active: bool) -> void:
	if not visible or active == is_board_view_active():
		return
	AudioManager.play_sfx(UISounds.CLICK)
	_set_board_view(active)


func _has_selection() -> bool:
	return _selected_card_ui != null or _selected_condiment_ui != null


func _queue_focus() -> void:
	call_deferred("_focus_merchant")


## Places the gamepad focus ring on the most useful control for the current shop state.
## Mouse and keyboard players are left alone so no stray focus ring appears mid-run.
func _focus_merchant() -> void:
	if not visible or not InputManager.is_using_gamepad():
		return
	if not _content_panel.visible:
		# The board view belongs to the in-run controller. A focused button would eat its presses.
		get_viewport().gui_release_focus()
		return
	if _selected_card_ui != null and _selected_card_ui.focus_purchase_tray():
		return
	if _selected_condiment_ui != null and _selected_condiment_ui.focus_purchase_tray():
		return
	for card_ui in _displayed_cards:
		if not card_ui.is_sold():
			card_ui.grab_focus()
			return
	for condiment_ui in _displayed_condiments:
		if not condiment_ui.is_sold():
			condiment_ui.grab_focus()
			return
	leave_button.grab_focus()


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
	var hand := get_tree().get_first_node_in_group("run_hand") as Hand
	if hand != null:
		hand.set_peek(active)
	_queue_focus()


func _on_condiment_targeting_changed(slot_index: int) -> void:
	if not visible:
		return
	if slot_index >= 0:
		_set_board_view(true)


## Restored stock is shown as saved. Otherwise a fresh roll fills every unlocked slot.
func _refresh_merchant_stock(
	restored_cards: Array[Card] = [],
	restored_condiments: Array[Condiment] = []
) -> void:
	_clear_selection()
	await _display_merchant_cards(
		restored_cards if not restored_cards.is_empty() else _roll_card_stock()
	)
	await _display_merchant_condiments(
		restored_condiments if not restored_condiments.is_empty() else _roll_condiment_stock()
	)


func _roll_card_stock() -> Array[Card]:
	var owned_staff_ids := StaffManager.owned_ids()
	var locked_tile_ids: Array[String] = []
	var excluded_staff_ids := owned_staff_ids.duplicate()
	for slot in _locked_cards.keys():
		var locked: Card = _locked_cards[slot]
		# Staff hired some other way cannot be bought twice.
		if locked is StaffCard and locked.id in owned_staff_ids:
			_locked_cards.erase(slot)
		elif locked is TileCard:
			locked_tile_ids.append(locked.id)
		else:
			excluded_staff_ids.append(locked.id)

	var tiles: Array = draw_tile_card_stock(_stock_reroll_count, locked_tile_ids)
	var staff: Array = draw_staff_stock(_stock_reroll_count, excluded_staff_ids)
	var inventory: Array[Card] = []
	for slot in MERCHANT_TILE_CARD_COUNT + MERCHANT_STAFF_COUNT:
		var drawn := tiles if slot < MERCHANT_TILE_CARD_COUNT else staff
		var item: Card = _locked_cards.get(slot, null)
		if item == null and not drawn.is_empty():
			item = drawn.pop_front()
		if item != null:
			inventory.append(item)
	return inventory


func _roll_condiment_stock() -> Array[Condiment]:
	var locked_ids: Array[String] = []
	for locked: Condiment in _locked_condiments.values():
		locked_ids.append(locked.id)
	var drawn: Array = draw_condiment_stock(_stock_reroll_count, locked_ids)
	var stock: Array[Condiment] = []
	for slot in CondimentManager.SHOP_STOCK:
		var item: Condiment = _locked_condiments.get(slot, null)
		if item == null and not drawn.is_empty():
			item = drawn.pop_front()
		if item != null:
			stock.append(item)
	return stock


## Stock rolls are static so the headless playtest bot shops the same shelves.
## exclude_ids are left off the roll so locked items never appear twice.
static func draw_tile_card_stock(
	stock_reroll_count: int,
	exclude_ids: Array[String] = []
) -> Array[TileCard]:
	var stream_name: String = RunRng.build_merchant_stream_name(
		GameManager.current_round,
		stock_reroll_count
	)
	var drawn := CardLoot.card_draw(
		MERCHANT_TILE_CARD_COUNT + exclude_ids.size(),
		GameManager.tile_cards_pool,
		true,
		RunRng.create_rng(stream_name)
	)
	var stock: Array[TileCard] = []
	for tile_card in drawn:
		if stock.size() < MERCHANT_TILE_CARD_COUNT and tile_card.id not in exclude_ids:
			stock.append(tile_card)
	return stock


## Staff already owned when the stock is rolled stay off the shelf.
static func draw_staff_stock(stock_reroll_count: int, owned_staff_ids: Array[String]) -> Array[StaffCard]:
	var stream_name := "merchant_staff:r%d:e%d" % [GameManager.current_round, stock_reroll_count]
	return StaffCatalog.draw(MERCHANT_STAFF_COUNT, RunRng.create_rng(stream_name), owned_staff_ids)


static func draw_condiment_stock(
	stock_reroll_count: int,
	exclude_ids: Array[String] = []
) -> Array[Condiment]:
	var stream_name := "merchant_condiments:r%d:e%d" % [GameManager.current_round, stock_reroll_count]
	var drawn := CondimentCatalog.draw_unique(
		CondimentManager.SHOP_STOCK + exclude_ids.size(),
		RunRng.create_rng(stream_name)
	)
	var stock: Array[Condiment] = []
	for condiment in drawn:
		if stock.size() < CondimentManager.SHOP_STOCK and condiment.id not in exclude_ids:
			stock.append(condiment)
	return stock


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
		card_ui.lock_toggle_requested.connect(_on_stock_card_lock_toggled)
		card_ui.set_merchant_locked(_locked_cards.has(_displayed_cards.size()))
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
		item.lock_toggle_requested.connect(_on_stock_condiment_lock_toggled)
		item.set_merchant_locked(_locked_condiments.has(_displayed_condiments.size()))
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
	_queue_focus()


func _on_stock_condiment_selected(item: CondimentShopItem) -> void:
	if item.is_sold():
		return
	_clear_card_selection()
	if _selected_condiment_ui != null and _selected_condiment_ui != item:
		_selected_condiment_ui.set_merchant_selected(false)
	_selected_condiment_ui = item
	_selected_condiment_ui.set_merchant_selected(true)
	_refresh_selected_purchase_tray()
	_queue_focus()


func _on_stock_card_gold_purchase_requested(card_ui: CardUI) -> void:
	if _selected_card_ui != card_ui:
		return
	_complete_purchase()


func _on_stock_condiment_gold_purchase_requested(item: CondimentShopItem) -> void:
	if _selected_condiment_ui != item:
		return
	_complete_purchase()


func _on_stock_card_lock_toggled(card_ui: CardUI, locked: bool) -> void:
	var slot := _displayed_cards.find(card_ui)
	if slot < 0 or card_ui.is_sold():
		return
	if locked:
		_locked_cards[slot] = card_ui.card
	else:
		_locked_cards.erase(slot)
	card_ui.set_merchant_locked(locked)
	AudioManager.play_sfx(UISounds.CLICK)
	RunSaveManager.request_autosave()


func _on_stock_condiment_lock_toggled(item: CondimentShopItem, locked: bool) -> void:
	var slot := _displayed_condiments.find(item)
	if slot < 0 or item.is_sold():
		return
	if locked:
		_locked_condiments[slot] = item.condiment
	else:
		_locked_condiments.erase(slot)
	item.set_merchant_locked(locked)
	AudioManager.play_sfx(UISounds.CLICK)
	RunSaveManager.request_autosave()


func _complete_purchase() -> void:
	if _selected_condiment_ui != null:
		_complete_condiment_purchase()
		return
	if _selected_card_ui == null or _selected_card_ui.is_sold():
		return

	var card: Card = _selected_card_ui.card
	var gold_price := _selected_card_ui.price
	if not EconomyManager.can_afford(gold_price):
		return
	if not card.get_purchase_block_reason().is_empty():
		return
	EconomyManager.remove(gold_price)

	var shelf_rect := _selected_card_ui.get_global_rect()
	_locked_cards.erase(_displayed_cards.find(_selected_card_ui))
	_selected_card_ui.mark_sold()
	# Keep the control in the grid as an invisible, inert placeholder so the
	# remaining stock never shifts when an item is purchased.
	_hide_purchased_stock(_selected_card_ui)

	if card is TileCard:
		EventBus.tile_card_selected.emit(card as TileCard)
	elif card is StaffCard:
		_seat_purchased_staff(card as StaffCard, shelf_rect)

	AudioManager.play_sfx(UISounds.MERCHANT_CARD_PURCHASED)
	_clear_selection()
	_update_reroll_button()
	# The bought card left the focus chain, so hand the ring to the next shelf item.
	_queue_focus()


## The staff member takes the first empty slot and flies there from its shelf card.
func _seat_purchased_staff(staff: StaffCard, shelf_rect: Rect2) -> void:
	var rail := get_tree().get_first_node_in_group("staff_rail")
	if rail != null:
		rail.set_next_arrival_origin(shelf_rect)
	StaffManager.add_staff(staff)


func _complete_condiment_purchase() -> void:
	if _selected_condiment_ui == null or _selected_condiment_ui.is_sold():
		return
	if not CondimentManager.can_add():
		return
	var gold_price := _selected_condiment_ui.price
	if not EconomyManager.can_afford(gold_price):
		return
	EconomyManager.remove(gold_price)
	if not CondimentManager.add_condiment(_selected_condiment_ui.condiment):
		return
	_locked_condiments.erase(_displayed_condiments.find(_selected_condiment_ui))
	_selected_condiment_ui.mark_sold()
	AudioManager.play_sfx(UISounds.MERCHANT_CARD_PURCHASED)
	_clear_selection()
	_update_reroll_button()
	# The bought bottle left the focus chain, so hand the ring to the next shelf item.
	_queue_focus()


func _on_reroll_button_pressed() -> void:
	if not EconomyManager.can_afford(_reroll_cost):
		return
	EconomyManager.remove(_reroll_cost)
	_reroll_cost += 1

	AudioManager.play_sfx(UISounds.CLICK)
	_stock_reroll_count += 1
	await _refresh_merchant_stock()
	_update_reroll_button()
	# Fresh stock replaced the focused card, so re-seat the ring on the new grid.
	_queue_focus()
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
	gold_amount_label.text = str(EconomyManager.amount)


func _update_reroll_button() -> void:
	reroll_button.text = "REROLL - %d" % _reroll_cost
	reroll_button.disabled = not EconomyManager.can_afford(_reroll_cost)


func capture_shop_state() -> Dictionary:
	var sold_indices: Array = []
	for index in _displayed_cards.size():
		if _displayed_cards[index].is_sold():
			sold_indices.append(index)
	var sold_condiment_indices: Array = []
	for index in _displayed_condiments.size():
		if _displayed_condiments[index].is_sold():
			sold_condiment_indices.append(index)
	var stock_cards: Array = []
	for card_ui in _displayed_cards:
		stock_cards.append(_card_to_save(card_ui.card))
	var stock_condiments: Array = []
	for item in _displayed_condiments:
		stock_condiments.append(item.condiment.id)
	var locked_cards: Array = []
	for slot in _locked_cards:
		var entry := _card_to_save(_locked_cards[slot])
		entry["slot"] = slot
		locked_cards.append(entry)
	var locked_condiments: Array = []
	for slot in _locked_condiments:
		var condiment: Condiment = _locked_condiments[slot]
		locked_condiments.append({"slot": slot, "id": condiment.id})
	return {
		"open": _session_open,
		"stock_reroll_count": _stock_reroll_count,
		"reroll_cost": _reroll_cost,
		"sold_indices": sold_indices,
		"sold_condiment_indices": sold_condiment_indices,
		"stock_cards": stock_cards,
		"stock_condiments": stock_condiments,
		"locked_cards": locked_cards,
		"locked_condiments": locked_condiments,
	}


## Locks apply immediately because they outlive the shop visit that set them.
func apply_shop_state(state: Dictionary) -> void:
	_locked_cards.clear()
	_locked_condiments.clear()
	if state.is_empty():
		_restore_state.clear()
		return
	for entry in state.get("locked_cards", []):
		var card := _card_from_save(entry)
		if card != null:
			_locked_cards[int(entry.get("slot", -1))] = card
	for entry in state.get("locked_condiments", []):
		var condiment := CondimentCatalog.get_by_id(str(entry.get("id", "")))
		if condiment != null:
			_locked_condiments[int(entry.get("slot", -1))] = condiment
	_restore_state = state.duplicate(true)


static func _card_to_save(card: Card) -> Dictionary:
	return {"kind": "staff" if card is StaffCard else "tile", "id": card.id}


static func _card_from_save(entry: Dictionary) -> Card:
	var card_id := str(entry.get("id", ""))
	var source: Card = (
		StaffCatalog.get_by_id(card_id)
		if entry.get("kind", "") == "staff"
		else GameManager.get_tile_card_by_id(card_id)
	)
	return source.duplicate(true) if source != null else null


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
