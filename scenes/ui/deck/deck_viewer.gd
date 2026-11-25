class_name DeckViewer
extends Control

## Full-screen overlay of cards. Clicking the deck pile opens it on the draw pile: the cards still to
## come this Day, shown sorted since the pile's order is hidden. The Merchant opens it in removal mode
## on the whole deck once the service is paid for (DeckManager.pay_for_removal): pick a card to take
## it out of the deck for good, or skip. Skipping keeps the Gold spent. Cards are grouped into
## Ingredients, Kitchenware and Meals, each with a header and its own grid; an empty group hides.
## The layout lives in deck_viewer.tscn.

signal closed

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CARD_SCALE := 0.68
const CARD_BASE_SIZE := Vector2(214, 317)

enum Mode { VIEW, REMOVE }

var _mode := Mode.VIEW
var _selected: TileCard = null
var _selected_ui: CardUI = null

@onready var _title: Label = %Title
@onready var _ingredient_header: Label = %IngredientHeader
@onready var _ingredient_grid: GridContainer = %IngredientGrid
@onready var _ingredient_gap: Control = %IngredientGap
@onready var _kitchenware_header: Label = %KitchenwareHeader
@onready var _kitchenware_grid: GridContainer = %KitchenwareGrid
@onready var _kitchenware_gap: Control = %KitchenwareGap
@onready var _meal_header: Label = %MealHeader
@onready var _meal_grid: GridContainer = %MealGrid
@onready var _meal_gap: Control = %MealGap
@onready var _empty_label: Label = %EmptyLabel
@onready var _remove_button: Button = %RemoveButton
@onready var _skip_button: Button = %SkipButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	add_to_group("deck_viewer")
	add_to_group(InputManager.MENU_GROUP)
	hide()
	_remove_button.pressed.connect(_on_remove_pressed)
	_skip_button.pressed.connect(close)
	_close_button.pressed.connect(close)
	DeckManager.piles_changed.connect(func() -> void:
		if visible:
			_rebuild()
	)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## InputManager menu hook.
func is_gamepad_menu_active() -> bool:
	return visible


## InputManager menu hook.
func focus_default() -> void:
	if visible:
		(_skip_button if _mode == Mode.REMOVE else _close_button).grab_focus()


func open_view() -> void:
	_open(Mode.VIEW)


## The Merchant's removal service, already paid for. Closing it skips the removal.
func open_removal() -> void:
	_open(Mode.REMOVE)


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	hide()
	_selected = null
	_selected_ui = null
	AudioManager.play_sfx(UISounds.CLICK)
	closed.emit()


func _open(mode: Mode) -> void:
	_mode = mode
	_selected = null
	_selected_ui = null
	show()
	move_to_front()
	_rebuild()
	if InputManager.is_using_gamepad():
		call_deferred("focus_default")


func _rebuild() -> void:
	for grid: GridContainer in [_ingredient_grid, _kitchenware_grid, _meal_grid]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	_selected_ui = null
	var removing := _mode == Mode.REMOVE
	_remove_button.visible = removing
	_remove_button.disabled = true
	_skip_button.visible = removing
	_close_button.visible = not removing

	var cards: Array[TileCard] = []
	if _mode == Mode.REMOVE:
		cards = DeckManager.all_cards()
		_title.text = "Remove a card (%d in your deck)" % cards.size()
	else:
		cards = DeckManager.draw_pile_cards()
		_title.text = "Draw pile (%d cards)" % cards.size()
	_add_cards(cards)


func _add_cards(cards: Array[TileCard]) -> void:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		if a.type != b.type:
			return a.type < b.type
		return String(a.name) < String(b.name)
	)
	_empty_label.visible = sorted.is_empty()
	var counts := {}
	for card: TileCard in sorted:
		counts[card.type] = int(counts.get(card.type, 0)) + 1
	_show_group(_ingredient_header, _ingredient_grid, _ingredient_gap, "Ingredients",
		int(counts.get(TileCard.TileCardType.INGREDIENT, 0)))
	_show_group(_kitchenware_header, _kitchenware_grid, _kitchenware_gap, "Kitchenware",
		int(counts.get(TileCard.TileCardType.KITCHENWARE, 0)))
	_show_group(_meal_header, _meal_grid, _meal_gap, "Meals",
		int(counts.get(TileCard.TileCardType.MEAL, 0)))
	for card: TileCard in sorted:
		var slot := Control.new()
		slot.custom_minimum_size = CARD_BASE_SIZE * CARD_SCALE
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_grid_for(card).add_child(slot)
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		slot.add_child(card_ui)
		card_ui.scale = Vector2.ONE * CARD_SCALE
		card_ui.configure_interaction(CardUI.InteractionMode.CHOICE if _mode == Mode.REMOVE else CardUI.InteractionMode.PREVIEW)
		card_ui.set_card(card)
		if _mode == Mode.REMOVE:
			card_ui.action_requested.connect(_on_card_chosen.bind(card))


func _on_card_chosen(card_ui: CardUI, card: TileCard) -> void:
	if _selected_ui != null and is_instance_valid(_selected_ui):
		_selected_ui.modulate = Color.WHITE
	_selected = card
	_selected_ui = card_ui
	card_ui.modulate = Color(1.0, 0.7, 0.7)
	_remove_button.disabled = false
	AudioManager.play_sfx(UISounds.CLICK)


func _on_remove_pressed() -> void:
	if _selected == null or _mode != Mode.REMOVE:
		return
	if DeckManager.remove_card(_selected):
		AudioManager.play_sfx(UISounds.DESTROY)
		RunSaveManager.request_autosave()
	# One removal per payment.
	close()


## Header text with the group's count. A group with no cards hides its header, grid and gap.
func _show_group(header: Label, grid: GridContainer, gap: Control, label: String, count: int) -> void:
	header.text = "%s (%d)" % [label, count]
	header.visible = count > 0
	grid.visible = count > 0
	gap.visible = count > 0


func _grid_for(card: TileCard) -> GridContainer:
	match card.type:
		TileCard.TileCardType.KITCHENWARE:
			return _kitchenware_grid
		TileCard.TileCardType.MEAL:
			return _meal_grid
	return _ingredient_grid
