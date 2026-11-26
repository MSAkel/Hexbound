class_name CondimentShopItem
extends Control

## Merchant shelf bottle. Icon and price only. Name and text live on the hover tooltip.
## Layout lives in condiment_shop_item.tscn.

signal selected(item: CondimentShopItem)
signal gold_purchase_requested(item: CondimentShopItem)
signal lock_toggle_requested(item: CondimentShopItem, locked: bool)

const SIZE := Vector2(108, 136)
const MERCHANT_TRAY_HEIGHT := 44.0
const MERCHANT_TRAY_GAP := 10.0
const HOVER_SCALE := Vector2(1.05, 1.05)
const HOVER_DURATION := 0.1

## Both empty: the bottle stands on the shelf with no panel behind it.
@export var well_idle_style: StyleBox
@export var well_selected_style: StyleBox

@onready var _price_label: Label = %PriceLabel
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _well: PanelContainer = %Well
@onready var _icon: TextureRect = %Icon
@onready var _tray_gap: Control = %TrayGap
@onready var _purchase_tray: MerchantPurchaseTray = %PurchaseTray

var condiment: Condiment
var price: int = 0
var _sold := false
var _locked := false
var _chosen := false
var _hover_tween: Tween
## Icon texture -> share of its height left empty below the drawing.
static var _bottom_pad_cache: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Shelf bottles are gamepad targets alongside the merchant card grid.
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_icon.resized.connect(_update_icon_pivot)
	_update_icon_pivot()
	_refresh()


func configure(new_condiment: Condiment) -> void:
	condiment = new_condiment
	if condiment != null:
		price = condiment.get_shop_price()
	_refresh()


func is_sold() -> bool:
	return _sold


func is_merchant_locked() -> bool:
	return _locked


## Locked bottles survive rerolls and stay stocked into the next day.
func set_merchant_locked(locked: bool) -> void:
	_locked = locked
	_lock_icon.visible = locked
	_purchase_tray.set_locked(locked)


func mark_sold() -> void:
	_sold = true
	set_merchant_locked(false)
	_chosen = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.0)
	_purchase_tray.visible = false
	_purchase_tray.set_focusable(false)
	_tray_gap.visible = false
	focus_mode = Control.FOCUS_NONE
	_apply_icon_scale(false)
	if has_focus():
		release_focus()
	_update_layout_height()
	_refresh()


func set_merchant_selected(active: bool) -> void:
	_chosen = active
	var show_tray := active and not _sold
	_tray_gap.visible = show_tray
	_purchase_tray.visible = show_tray
	if active:
		refresh_purchase_tray()
	# Buy buttons only enter the focus chain while their tray is on screen.
	_purchase_tray.set_focusable(show_tray)
	_update_layout_height()
	_refresh()


## Move focus onto the buy row after this bottle is selected.
## False when the tray is hidden.
func focus_purchase_tray() -> bool:
	if not _purchase_tray.visible:
		return false
	return _purchase_tray.focus_first_enabled()


func _update_layout_height() -> void:
	var height := SIZE.y
	if _purchase_tray.visible:
		height += MERCHANT_TRAY_GAP + MERCHANT_TRAY_HEIGHT
	custom_minimum_size = Vector2(SIZE.x, height)
	size.y = height


func refresh_purchase_tray() -> void:
	var belt_full := not CondimentManager.can_add()
	var gold_enabled := not _sold and not belt_full and EconomyManager.can_afford(price)
	_purchase_tray.set_gold_enabled(gold_enabled)


func refresh_affordability() -> void:
	_refresh()
	refresh_purchase_tray()


func _on_gold_purchase_pressed() -> void:
	gold_purchase_requested.emit(self)


func _on_lock_toggled(locked: bool) -> void:
	lock_toggle_requested.emit(self, locked)


func _refresh() -> void:
	if condiment == null:
		return
	_icon.texture = condiment.icon
	_sit_icon_on_shelf()
	# Keep the authored flask colors. Do not tint with liquid_color.
	_icon.self_modulate = Color.WHITE
	_price_label.text = MerchantShopStyling.format_price(price)
	_well.add_theme_stylebox_override("panel", well_selected_style if _chosen else well_idle_style)
	var can_afford := EconomyManager.can_afford(price)
	_price_label.add_theme_color_override(
		"font_color",
		MerchantShopStyling.price_label_color(can_afford and not _sold)
	)


func _icon_rest_scale() -> Vector2:
	var raised := not _sold and (has_focus() or get_global_rect().has_point(get_global_mouse_position()))
	return HOVER_SCALE if raised else Vector2.ONE


func _apply_icon_scale(animate: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	var target := _icon_rest_scale()
	if not animate or GameManager.skip_presentation:
		_icon.scale = target
		return
	_hover_tween = create_tween()
	_hover_tween.tween_property(_icon, "scale", target, HOVER_DURATION).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


## Moves the icon down by the empty rows under its drawing, so every bottle's base stands on the
## same line (the shelf top). Icons are drawn with different amounts of space below them.
func _sit_icon_on_shelf() -> void:
	var drop := _bottom_padding(_icon.texture) * _icon.get_parent_control().custom_minimum_size.y
	_icon.offset_top = drop
	_icon.offset_bottom = drop


static func _bottom_padding(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	if _bottom_pad_cache.has(texture):
		return _bottom_pad_cache[texture]
	var pad := 0.0
	var image := texture.get_image()
	if image != null and image.get_height() > 0:
		var used := image.get_used_rect()
		if used.has_area():
			pad = float(image.get_height() - used.end.y) / float(image.get_height())
	_bottom_pad_cache[texture] = pad
	return pad


func _update_icon_pivot() -> void:
	_icon.pivot_offset = _icon.size * 0.5


func _tooltip_text() -> String:
	if condiment == null:
		return ""
	return condiment.get_tooltip_text()


func _on_gui_input(event: InputEvent) -> void:
	if _sold:
		return
	if event.is_action_pressed("ui_accept"):
		selected.emit(self)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
		accept_event()


func _on_mouse_entered() -> void:
	if _sold:
		return
	AudioManager.play_condiment_hover()
	_apply_icon_scale(true)
	EventBus.toggle_tooltip.emit(true, _tooltip_text(), get_global_rect())


func _on_mouse_exited() -> void:
	_apply_icon_scale(true)
	# A focused bottle keeps its tooltip so the gamepad cursor stays readable.
	if has_focus():
		return
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _on_focus_entered() -> void:
	if _sold:
		return
	AudioManager.play_condiment_hover()
	_apply_icon_scale(true)
	EventBus.toggle_tooltip.emit(true, _tooltip_text(), get_global_rect())


func _on_focus_exited() -> void:
	_apply_icon_scale(true)
	EventBus.toggle_tooltip.emit(false, "", Rect2())
