class_name PackShopItem
extends Control

## Merchant shelf pack. Name, what it holds and a price. Opening it happens in PackOpening.
## Mirrors CondimentShopItem (select, lock, buy tray) and is built in code, so it has no scene.
## Placeholder look: the pack art is still to come.

signal selected(item: PackShopItem)
signal gold_purchase_requested(item: PackShopItem)
signal lock_toggle_requested(item: PackShopItem, locked: bool)

const SIZE := Vector2(150, 140)
const WELL_SIZE := Vector2(140, 92)
const MERCHANT_TRAY_HEIGHT := 44.0
const MERCHANT_TRAY_GAP := 10.0
const TRAY_SCENE := preload("res://scenes/ui/merchant/merchant_purchase_tray.tscn")
const LOCK_TEXTURE := preload("res://assets/icons/others/lock.svg")
const NAME_COLOR := Color(0.97, 0.93, 0.8, 1.0)
const COUNT_COLOR := Color(0.9, 0.82, 0.62, 1.0)

var kind: MerchantPacks.Kind = MerchantPacks.Kind.INGREDIENTS
var price: int = 0

var _sold := false
var _locked := false
var _chosen := false
var _price_label: Label
var _lock_icon: TextureRect
var _well: PanelContainer
var _name_label: Label
var _count_label: Label
var _tray_gap: Control
var _tray: MerchantPurchaseTray


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_build()
	_refresh()


func configure(new_kind: MerchantPacks.Kind) -> void:
	kind = new_kind
	price = MerchantPacks.price(kind)
	_refresh()


func is_sold() -> bool:
	return _sold


func is_merchant_locked() -> bool:
	return _locked


## Locked packs survive rerolls and stay stocked into the next day.
func set_merchant_locked(locked: bool) -> void:
	_locked = locked
	_lock_icon.visible = locked
	_tray.set_locked(locked)


func mark_sold() -> void:
	_sold = true
	set_merchant_locked(false)
	_chosen = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.0)
	_tray.visible = false
	_tray.set_focusable(false)
	_tray_gap.visible = false
	focus_mode = Control.FOCUS_NONE
	if has_focus():
		release_focus()
	_update_layout_height()
	_refresh()


func set_merchant_selected(active: bool) -> void:
	_chosen = active
	var show_tray := active and not _sold
	_tray_gap.visible = show_tray
	_tray.visible = show_tray
	if active:
		refresh_purchase_tray()
	# Buy buttons only enter the focus chain while their tray is on screen.
	_tray.set_focusable(show_tray)
	_update_layout_height()
	_refresh()


## Move focus onto the buy row after this pack is selected. False when the tray is hidden.
func focus_purchase_tray() -> bool:
	if not _tray.visible:
		return false
	return _tray.focus_first_enabled()


func refresh_purchase_tray() -> void:
	var reason := MerchantPacks.get_purchase_block_reason(kind)
	_tray.set_block_reason(reason)
	_tray.set_gold_enabled(not _sold and reason.is_empty() and EconomyManager.can_afford(price))


func refresh_affordability() -> void:
	_refresh()
	refresh_purchase_tray()


func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(column)

	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _price_chip_style())
	column.add_child(chip)
	var chip_row := HBoxContainer.new()
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_theme_constant_override("separation", 4)
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(chip_row)
	_lock_icon = TextureRect.new()
	_lock_icon.texture = LOCK_TEXTURE
	_lock_icon.custom_minimum_size = Vector2(16, 16)
	_lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_icon.visible = false
	chip_row.add_child(_lock_icon)
	_price_label = Label.new()
	_price_label.add_theme_font_size_override("font_size", 16)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_row.add_child(_price_label)

	_well = PanelContainer.new()
	_well.custom_minimum_size = WELL_SIZE
	_well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_well)
	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 4)
	_well.add_child(text_column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(_name_label)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 15)
	_count_label.add_theme_color_override("font_color", COUNT_COLOR)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(_count_label)

	_tray_gap = Control.new()
	_tray_gap.custom_minimum_size = Vector2(0, MERCHANT_TRAY_GAP)
	_tray_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray_gap.visible = false
	column.add_child(_tray_gap)
	_tray = TRAY_SCENE.instantiate() as MerchantPurchaseTray
	_tray.custom_minimum_size = Vector2(0, MERCHANT_TRAY_HEIGHT)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.visible = false
	column.add_child(_tray)
	_tray.gold_purchase_pressed.connect(_on_gold_purchase_pressed)
	_tray.lock_toggled.connect(_on_lock_toggled)


func _update_layout_height() -> void:
	var height := SIZE.y
	if _tray.visible:
		height += MERCHANT_TRAY_GAP + MERCHANT_TRAY_HEIGHT
	custom_minimum_size = Vector2(SIZE.x, height)
	size.y = height


func _on_gold_purchase_pressed() -> void:
	gold_purchase_requested.emit(self)


func _on_lock_toggled(locked: bool) -> void:
	lock_toggle_requested.emit(self, locked)


func _refresh() -> void:
	if _name_label == null:
		return
	_name_label.text = MerchantPacks.display_name(kind)
	_count_label.text = "%d %s" % [MerchantPacks.CARD_COUNT, MerchantPacks.contents_label(kind)]
	_price_label.text = MerchantShopStyling.format_price(price)
	_well.add_theme_stylebox_override("panel", _well_style(_chosen))
	var can_afford := EconomyManager.can_afford(price)
	_price_label.add_theme_color_override(
		"font_color",
		MerchantShopStyling.price_label_color(can_afford and not _sold)
	)


func _tooltip_text() -> String:
	return MerchantPacks.tooltip_text(kind)


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
	EventBus.toggle_tooltip.emit(true, _tooltip_text(), get_global_rect())


func _on_mouse_exited() -> void:
	# A focused pack keeps its tooltip so the gamepad cursor stays readable.
	if has_focus():
		return
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _on_focus_entered() -> void:
	if _sold:
		return
	AudioManager.play_condiment_hover()
	EventBus.toggle_tooltip.emit(true, _tooltip_text(), get_global_rect())


func _on_focus_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


#region Styles

static func _price_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	style.bg_color = Color(0.9098039, 0.8509804, 0.6901961, 1)
	style.set_border_width_all(1)
	style.border_color = Color(0.7882353, 0.6705883, 0.4196078, 1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 2
	return style


static func _well_style(chosen: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(8.0)
	# Warm wood, so a pack reads as different from the green condiment wells.
	style.bg_color = Color(0.42, 0.3, 0.19, 1)
	style.set_border_width_all(2)
	style.border_color = (
		Color(0.9568627, 0.8313726, 0.5411765, 1) if chosen else Color(0.9686275, 0.9137255, 0.7686275, 1)
	)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	return style

#endregion
