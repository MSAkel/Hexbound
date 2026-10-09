class_name CardSellPanel
extends PanelContainer

## Drop zone in the bottom-left corner. Drag a hand card or a chef here and release to sell it.

const SELL_VALUE := 2

const TITLE_IDLE := "Sell"
const TITLE_HOVER := "Release to sell"
const HINT_IDLE := "DRAG A CARD HERE"
const HINT_ARMED := "DROP THE CARD HERE"
## Resting panel sits back so it does not compete with the board.
const IDLE_MODULATE := Color(1, 1, 1, 0.88)
const ARMED_BORDER_COLOR := Color(0.87, 0.6, 0.16)
const HOVER_BG_COLOR := Color(0.86, 0.93, 0.76)
const HOVER_BORDER_COLOR := Color(0.33, 0.56, 0.2)

@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _price_label: Label = %PriceLabel

var _panel_style: StyleBoxFlat
var _panel_style_armed: StyleBoxFlat
var _panel_style_hover: StyleBoxFlat
var _drag_card: CardUI = null
## Chef slot being dragged, or -1. Chefs sell for their own value, not SELL_VALUE.
var _drag_chef_slot := -1


func _ready() -> void:
	add_to_group("card_sell_panel")
	_cache_panel_styles()
	EventBus.card_drag_started.connect(_on_card_drag_started)
	EventBus.card_drag_ended.connect(_on_card_drag_ended)
	EventBus.chef_drag_started.connect(_on_chef_drag_started)
	EventBus.chef_drag_ended.connect(_on_chef_drag_ended)
	_refresh_state()


func _cache_panel_styles() -> void:
	var base_style := get_theme_stylebox("panel") as StyleBoxFlat
	_panel_style = base_style.duplicate() as StyleBoxFlat
	# A dragged card lights the drop zone before the pointer reaches it.
	_panel_style_armed = base_style.duplicate() as StyleBoxFlat
	_panel_style_armed.border_color = ARMED_BORDER_COLOR
	_panel_style_hover = base_style.duplicate() as StyleBoxFlat
	_panel_style_hover.bg_color = HOVER_BG_COLOR
	_panel_style_hover.border_color = HOVER_BORDER_COLOR


func _process(_delta: float) -> void:
	if not _is_armed():
		return
	_refresh_state()


func _on_card_drag_started(card: CardUI) -> void:
	_drag_card = card
	_refresh_state()


func _on_card_drag_ended() -> void:
	_drag_card = null
	_refresh_state()


func _on_chef_drag_started(slot: int) -> void:
	_drag_chef_slot = slot
	_refresh_state()


func _on_chef_drag_ended() -> void:
	_drag_chef_slot = -1
	_refresh_state()


## Used by ChefRail when the player releases a dragged chef. True when it was sold.
func try_sell_chef(slot: int) -> bool:
	if not _is_mouse_over():
		return false
	if ChefManager.sell_chef(slot) < 0:
		return false
	AudioManager.play_sfx(UISounds.GOLD_GAINED)
	return true


## Sells without a pointer check. Controller players pick Sell as a drop target instead.
func sell_chef_from_controller(slot: int) -> bool:
	if ChefManager.sell_chef(slot) < 0:
		return false
	AudioManager.play_sfx(UISounds.GOLD_GAINED)
	return true


func _is_armed() -> bool:
	return _drag_card != null or _drag_chef_slot >= 0


func _current_sell_value() -> int:
	var chef := ChefManager.get_chef(_drag_chef_slot)
	if chef != null:
		return chef.get_sell_value()
	return SELL_VALUE


## Used by CardPlacementHandler when the player releases a dragged hand card.
func try_sell(card_ui: CardUI) -> bool:
	if card_ui == null or not _is_mouse_over():
		return false

	GoldManager.add(SELL_VALUE)
	AudioManager.play_sfx(UISounds.GOLD_GAINED)

	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map != null and tile_map.card_placement_handler != null:
		tile_map.card_placement_handler.cancel_selection_for_sell(card_ui)

	EventBus.card_sold.emit(card_ui)
	card_ui.queue_free()
	return true


func _is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


## Idle, armed while a card is dragged, and hover while it sits over the panel.
func _refresh_state() -> void:
	var armed := _is_armed()
	var hovered := armed and _is_mouse_over()
	_price_label.text = "+%d" % _current_sell_value()
	var style := _panel_style
	if hovered:
		style = _panel_style_hover
	elif armed:
		style = _panel_style_armed
	add_theme_stylebox_override("panel", style)
	modulate = Color.WHITE if armed else IDLE_MODULATE
	_title_label.text = TITLE_HOVER if hovered else TITLE_IDLE
	_hint_label.visible = not hovered
	_hint_label.text = HINT_ARMED if armed else HINT_IDLE
