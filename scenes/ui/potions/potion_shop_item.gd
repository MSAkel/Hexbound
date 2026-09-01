class_name PotionShopItem
extends Control

## Merchant shelf bottle. Icon and price only. Name and text live on the hover tooltip.
## Layout lives in potion_shop_item.tscn.

signal selected(item: PotionShopItem)
signal gold_purchase_requested(item: PotionShopItem)
signal token_purchase_requested(item: PotionShopItem)

const SIZE := Vector2(108, 136)
const MERCHANT_TRAY_HEIGHT := 44.0
const MERCHANT_TRAY_GAP := 10.0

@export var well_idle_style: StyleBoxFlat
@export var well_selected_style: StyleBoxFlat

@onready var _price_label: Label = %PriceLabel
@onready var _well: PanelContainer = %Well
@onready var _icon: TextureRect = %Icon
@onready var _tray_gap: Control = %TrayGap
@onready var _purchase_tray: MerchantPurchaseTray = %PurchaseTray

var potion: Potion
var price: int = 0
var _token_cost := 1
var _sold := false
var _chosen := false


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()


func configure(new_potion: Potion) -> void:
	potion = new_potion
	if potion != null:
		price = potion.get_shop_price()
	_token_cost = GoldManager.MERCHANT_TOKEN_COST
	_refresh()


func is_sold() -> bool:
	return _sold


func mark_sold() -> void:
	_sold = true
	_chosen = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.0)
	_purchase_tray.visible = false
	_tray_gap.visible = false
	_update_layout_height()
	_refresh()


func set_merchant_selected(active: bool) -> void:
	_chosen = active
	var show_tray := active and not _sold
	_tray_gap.visible = show_tray
	_purchase_tray.visible = show_tray
	if active:
		refresh_purchase_tray()
	_update_layout_height()
	_refresh()


func _update_layout_height() -> void:
	var height := SIZE.y
	if _purchase_tray.visible:
		height += MERCHANT_TRAY_GAP + MERCHANT_TRAY_HEIGHT
	custom_minimum_size = Vector2(SIZE.x, height)
	size.y = height


func refresh_purchase_tray() -> void:
	var belt_full := not PotionManager.can_add()
	var gold_enabled := not _sold and not belt_full and GoldManager.can_afford(price)
	var token_enabled := not _sold and not belt_full and GoldManager.can_afford_tokens(_token_cost)
	_purchase_tray.set_gold_enabled(gold_enabled)
	_purchase_tray.set_token_enabled(token_enabled)


func get_token_cost() -> int:
	return _token_cost


func refresh_affordability() -> void:
	_refresh()
	refresh_purchase_tray()


func _on_gold_purchase_pressed() -> void:
	gold_purchase_requested.emit(self)


func _on_token_purchase_pressed() -> void:
	token_purchase_requested.emit(self)


func _refresh() -> void:
	if potion == null:
		return
	_icon.texture = potion.icon
	# Keep the authored flask colors. Do not tint with liquid_color.
	_icon.self_modulate = Color.WHITE
	_price_label.text = MerchantShopStyling.format_price(price)
	_well.add_theme_stylebox_override("panel", well_selected_style if _chosen else well_idle_style)
	var can_afford := GoldManager.can_afford(price)
	_price_label.add_theme_color_override(
		"font_color",
		MerchantShopStyling.price_label_color(can_afford and not _sold)
	)


func _tooltip_text() -> String:
	if potion == null:
		return ""
	return "%s\n%s" % [potion.display_name, potion.description]


func _on_gui_input(event: InputEvent) -> void:
	if _sold:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
		accept_event()


func _on_mouse_entered() -> void:
	if _sold:
		return
	AudioManager.play_potion_hover()
	EventBus.toggle_tooltip.emit(true, _tooltip_text(), get_global_rect())


func _on_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())
