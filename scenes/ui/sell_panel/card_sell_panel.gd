class_name CardSellPanel
extends PanelContainer

## Drop zone in the bottom-left corner. Drag a hand card here and release to sell it.

const SELL_VALUE := 2

@onready var _idle_sell_label: Label = $MarginContainer/VBoxContainer/IdleSellLabel
@onready var _hover_row: HBoxContainer = $MarginContainer/VBoxContainer/HoverRow

var _panel_style: StyleBoxFlat
var _panel_style_hover: StyleBoxFlat
var _drag_card: CardUI = null


func _ready() -> void:
	add_to_group("card_sell_panel")
	_cache_panel_styles()
	EventBus.card_drag_started.connect(_on_card_drag_started)
	EventBus.card_drag_ended.connect(_on_card_drag_ended)
	_set_hover_active(false)


func _cache_panel_styles() -> void:
	var base_style := get_theme_stylebox("panel") as StyleBoxFlat
	_panel_style = base_style.duplicate() as StyleBoxFlat
	_panel_style_hover = base_style.duplicate() as StyleBoxFlat
	_panel_style_hover.bg_color = Color(0.2, 0.28, 0.22, 0.9)
	_panel_style_hover.border_color = Color(0.55, 0.72, 0.42, 1.0)


func _process(_delta: float) -> void:
	if _drag_card == null:
		return
	_set_hover_active(_is_mouse_over())


func _on_card_drag_started(card: CardUI) -> void:
	_drag_card = card


func _on_card_drag_ended() -> void:
	_drag_card = null
	_set_hover_active(false)


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


func _set_hover_active(active: bool) -> void:
	_idle_sell_label.visible = not active
	_hover_row.visible = active
	add_theme_stylebox_override("panel", _panel_style_hover if active else _panel_style)
