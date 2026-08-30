class_name PotionShopItem
extends Control

## Merchant shelf bottle. Icon and price only. Name and text live on the hover tooltip.

signal selected(item: PotionShopItem)

# 72px icon grown by about 15 percent. The well can be larger than its 80px minimum.
const ICON_SIZE := Vector2(83, 83)
const WELL_MIN := Vector2(80, 80)
const SIZE := Vector2(108, 136)

var potion: Potion
var price: int = 0
var _token_cost := 1
var _sold := false
var _chosen := false
var _icon: TextureRect
var _price_label: Label
var _well: PanelContainer


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
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
	_refresh()


func set_merchant_selected(active: bool) -> void:
	_chosen = active
	_refresh()


func get_token_cost() -> int:
	return _token_cost


func refresh_affordability() -> void:
	_refresh()


func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var price_panel := PanelContainer.new()
	price_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	price_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_panel.add_theme_stylebox_override("panel", _price_tag_style())
	column.add_child(price_panel)

	_price_label = Label.new()
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.add_theme_font_size_override("font_size", 16)
	_price_label.add_theme_color_override("font_color", Color(0.28, 0.2, 0.08, 1.0))
	price_panel.add_child(_price_label)

	_well = PanelContainer.new()
	_well.custom_minimum_size = WELL_MIN
	_well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_well)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Pixel flasks stay crisp instead of blurring when scaled up.
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.add_child(_icon)


func _price_tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("F9EDCF")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("C9AB6B")
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.shadow_size = 2
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.content_margin_left = 12
	style.content_margin_top = 3
	style.content_margin_right = 12
	style.content_margin_bottom = 3
	return style


func _well_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("536044")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("F4D48A") if _chosen else Color("F7E9C4")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	style.shadow_color = Color("00000040")
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _refresh() -> void:
	if potion == null:
		return
	_icon.texture = potion.icon
	# Keep the authored flask colors. Do not tint with liquid_color.
	_icon.self_modulate = Color.WHITE
	_price_label.text = "$%d" % price
	_well.add_theme_stylebox_override("panel", _well_style())
	if not GoldManager.can_afford(price) and not _sold:
		_price_label.add_theme_color_override("font_color", Color(0.62, 0.18, 0.14, 1.0))
	else:
		_price_label.add_theme_color_override("font_color", Color(0.28, 0.2, 0.08, 1.0))


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
