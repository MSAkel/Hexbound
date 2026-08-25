class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)
# Emitted in MERCHANT and CHOICE modes when the player clicks an actionable card.
signal action_requested(card_ui: CardUI)

const BASE_STYLEBOX := preload("res://themes/card_base_stylebox.tres")
const HOVER_STYLEBOX := preload("res://themes/card_hover_stylebox.tres")
const DRAG_STYLEBOX := preload("res://themes/card_drag_stylebox.tres")

# TileCardType.PRODUCER uses the production frame. Enhancement cards keep the scene default.
@export var frame_producer: Texture2D
@export var frame_support: Texture2D
@export var frame_modifier: Texture2D

@onready var card_name: Label = $Content/NameContainer/CardName
@onready var icon: TextureRect = $Content/IconContainer/Icon
@onready var card_description: RichTextLabel = $Content/DescriptionContainer/CardDescription
@onready var resource_cost_container: HBoxContainer = $Content/ResourceCostContainer
@onready var card_type_label: Label = $Content/CardTypeLabel
@onready var price_label: Label = $Content/PriceLabel

@onready var drop_point_area: Area2D = $DropPointArea
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []
@onready var starting_hand_position := self.get_index()

# Textured card frame. Used for hover tint and to ignore mouse so the root Control gets clicks.
@onready var panel: Panel = $CardBackground
@onready var content_container: VBoxContainer = $Content
# Scene-authored border glow; toggled when the card enters/exits the clicked placement state.
@onready var selection_glow: Panel = $Overlays/SelectionGlow
@onready var sold_overlay: Panel = $Overlays/SoldOverlay

enum InteractionMode {
	HAND,
	MERCHANT,
	MERCHANT_STOCK,
	CHOICE,
	PREVIEW,
}

# Typed payload. TileCard occupies hexes, Enhancement attaches to a placed TileCard.
var card: Card = null
var interaction_mode: InteractionMode = InteractionMode.HAND
# Preview cards (e.g. character select) should not play hover elevation.
var hover_enabled := true
var price: int = 0

const HAND_HOVER_ELEVATION_OFFSET := -80.0
# Lower lift while aiming at a tile so the selected card blocks fewer bottom hexes.
const HAND_MAP_TILE_HOVER_ELEVATION_OFFSET := -20.0
# Subtle pop when a hand card is hovered or selected.
const HAND_HOVER_SCALE := 1.2
const HAND_ELEVATED_Z_INDEX := 10
const PANEL_HOVER_ELEVATION_OFFSET := -12.0
const HOVER_ANIMATION_DURATION := 0.2
var _is_hover_elevated := false
var _map_tile_hover_active := false
var _resting_z_index := 0
var _elevation_tween: Tween
# Extra X shift applied by Hand so neighbors slide aside while this card grows.
var _hand_spread_x := 0.0
var _is_sold := false
var _discount := 0.0
var _token_cost := 0


func _ready() -> void:
	_resting_z_index = z_index
	_apply_interaction_mode()
	tree_exiting.connect(_hide_keyword_tooltips)


# Parent screens call this after instantiation to choose how the card responds to input.
func configure_interaction(mode: InteractionMode, options: Dictionary = {}) -> void:
	interaction_mode = mode
	_discount = options.get("discount", 0.0)

	if is_node_ready():
		_apply_interaction_mode()
	elif mode == InteractionMode.MERCHANT or mode == InteractionMode.MERCHANT_STOCK:
		if card != null:
			# set_card may run before _ready when merchant cards are spawned in a loop.
			call_deferred("_refresh_merchant_price")
			if mode == InteractionMode.MERCHANT_STOCK:
				call_deferred("_update_stock_affordability")
			else:
				call_deferred("_update_affordability")


func _apply_interaction_mode() -> void:
	_disable_state_machine()

	match interaction_mode:
		InteractionMode.HAND:
			hover_enabled = true
			_configure_click_routing(true)
			price_label.visible = false
			sold_overlay.visible = false
			# Grow from the bottom edge so the card lifts and scales upward in the fan.
			offset_transform_pivot_ratio = Vector2(0.5, 1.0)
			card_state_machine.init(self)
		InteractionMode.MERCHANT:
			hover_enabled = true
			_configure_click_routing(true)
			price_label.visible = true
			sold_overlay.visible = _is_sold
			_refresh_merchant_price()
			_update_affordability()
		InteractionMode.MERCHANT_STOCK:
			hover_enabled = true
			_configure_click_routing(true)
			price_label.visible = true
			sold_overlay.visible = _is_sold
			_refresh_merchant_price()
			_update_stock_affordability()
		InteractionMode.CHOICE:
			hover_enabled = true
			_configure_click_routing(true)
			price_label.visible = false
			sold_overlay.visible = false
		InteractionMode.PREVIEW:
			hover_enabled = false
			_configure_click_routing(false)
			price_label.visible = false
			sold_overlay.visible = false

	# Hand cards animate scale via offset transform; other modes stay at default size.
	if interaction_mode != InteractionMode.HAND:
		offset_transform_scale = Vector2.ONE

	drop_point_area.monitoring = false


# Route all pointer events to the root control so merchant/choice clicks are not eaten by child labels.
func _configure_click_routing(interactive: bool) -> void:
	if interactive:
		mouse_filter = MOUSE_FILTER_STOP
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		content_container.mouse_filter = MOUSE_FILTER_IGNORE
		_set_controls_mouse_filter(content_container, MOUSE_FILTER_IGNORE)
	else:
		mouse_filter = MOUSE_FILTER_IGNORE
		panel.mouse_filter = MOUSE_FILTER_STOP
		content_container.mouse_filter = MOUSE_FILTER_STOP


func _set_controls_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_controls_mouse_filter(child, filter)


func _get_hover_elevation_offset() -> float:
	match interaction_mode:
		InteractionMode.HAND:
			if _map_tile_hover_active:
				return HAND_MAP_TILE_HOVER_ELEVATION_OFFSET
			return HAND_HOVER_ELEVATION_OFFSET
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			return PANEL_HOVER_ELEVATION_OFFSET
		_:
			return 0.0


func _should_apply_hand_hover_scale() -> bool:
	return interaction_mode == InteractionMode.HAND


func _get_hand_hover_scale() -> Vector2:
	return Vector2.ONE * HAND_HOVER_SCALE


func _is_hover_transform_at_target(
	target_offset: Vector2,
	target_scale: Vector2,
	apply_hand_scale: bool
) -> bool:
	if offset_transform_position.distance_to(target_offset) >= 0.5:
		return false
	if not apply_hand_scale:
		return true
	return offset_transform_scale.distance_to(target_scale) < 0.01


func _disable_state_machine() -> void:
	card_state_machine.set_process(false)
	card_state_machine.set_process_input(false)


func is_hover_elevated() -> bool:
	return _is_hover_elevated


# Selected cards dip slightly while the cursor aims at a map tile.
func set_map_tile_hover_active(active: bool, animate: bool = true) -> void:
	if _map_tile_hover_active == active:
		return
	_map_tile_hover_active = active
	if _is_hover_elevated:
		set_hover_elevated(true, animate)


func _update_hand_z_index(elevated: bool) -> void:
	if interaction_mode != InteractionMode.HAND:
		return
	z_index = HAND_ELEVATED_Z_INDEX if elevated else _resting_z_index


func get_hand_spread_x() -> float:
	return _hand_spread_x


# Hand uses this to push unhovered cards away from the featured card.
func set_hand_spread_x(spread_x: float, animate: bool = true) -> void:
	if is_equal_approx(_hand_spread_x, spread_x):
		return
	_hand_spread_x = spread_x
	var hand := get_parent() as Hand
	if hand != null and hand.is_preserving_offset_for(self):
		return
	# The featured card's hover tween already includes the composed offset.
	if _is_hover_elevated:
		return
	_apply_offset_transform(animate)


func set_hover_elevated(elevated: bool, animate: bool = true) -> void:
	if not hover_enabled:
		elevated = false
		animate = false

	# Clearing hover must not wipe intro slides or generated-card reveal offsets.
	var hand := get_parent() as Hand
	if not elevated and hand != null and hand.is_preserving_offset_for(self):
		_is_hover_elevated = false
		_update_hand_z_index(false)
		if hand != null:
			hand.notify_card_featured(self, false, false)
		return

	_is_hover_elevated = elevated
	_update_hand_z_index(elevated)
	if hand != null:
		hand.notify_card_featured(self, elevated, animate)
	_apply_offset_transform(animate)


func _composed_offset_position() -> Vector2:
	var y := _get_hover_elevation_offset() if _is_hover_elevated else 0.0
	return Vector2(_hand_spread_x, y)


func _apply_offset_transform(animate: bool) -> void:
	if _elevation_tween and _elevation_tween.is_valid():
		_elevation_tween.kill()
		_elevation_tween = null

	var target_offset := _composed_offset_position()
	var apply_hand_scale := _should_apply_hand_hover_scale()
	var target_scale := _get_hand_hover_scale() if _is_hover_elevated and apply_hand_scale else Vector2.ONE

	if not animate or _is_hover_transform_at_target(target_offset, target_scale, apply_hand_scale):
		offset_transform_enabled = true
		offset_transform_position = target_offset
		if apply_hand_scale:
			offset_transform_scale = target_scale
		return

	offset_transform_enabled = true
	_elevation_tween = create_tween()
	_elevation_tween.set_parallel(true)
	var ease_type := Tween.EASE_OUT if _is_hover_elevated else Tween.EASE_IN
	_elevation_tween.tween_property(
		self,
		"offset_transform_position",
		target_offset,
		HOVER_ANIMATION_DURATION
	).set_ease(ease_type).set_trans(Tween.TRANS_QUART)
	if apply_hand_scale:
		# Match the lift tween so hover and selection feel like one motion.
		_elevation_tween.tween_property(
			self,
			"offset_transform_scale",
			target_scale,
			HOVER_ANIMATION_DURATION
		).set_ease(ease_type).set_trans(Tween.TRANS_QUART)
	_elevation_tween.finished.connect(func() -> void:
		_elevation_tween = null
	)


func _input(event: InputEvent) -> void:
	if interaction_mode == InteractionMode.HAND:
		card_state_machine.on_input(event)


func _on_gui_input(event: InputEvent) -> void:
	match interaction_mode:
		InteractionMode.HAND:
			card_state_machine.on_gui_input(event)
		InteractionMode.MERCHANT:
			_handle_merchant_gui_input(event)
		InteractionMode.MERCHANT_STOCK:
			_handle_merchant_stock_gui_input(event)
		InteractionMode.CHOICE:
			_handle_choice_gui_input(event)


func _on_mouse_entered() -> void:
	match interaction_mode:
		InteractionMode.HAND:
			card_state_machine.on_mouse_entered()
			_show_keyword_tooltips()
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			if _is_sold:
				return
			set_hover_elevated(true)
			_show_keyword_tooltips()


func _on_mouse_exited() -> void:
	_hide_keyword_tooltips()
	match interaction_mode:
		InteractionMode.HAND:
			card_state_machine.on_mouse_exited()
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			set_hover_elevated(false)


func _handle_merchant_gui_input(event: InputEvent) -> void:
	if _is_sold:
		return

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not GoldManager.can_afford(price):
			return

		action_requested.emit(self)
		accept_event()


func _handle_merchant_stock_gui_input(event: InputEvent) -> void:
	if _is_sold:
		return

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		action_requested.emit(self)
		accept_event()


func _handle_choice_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		action_requested.emit(self)
		accept_event()


# Bind presentation fields from the shared Card resource.
func set_card(data: Card) -> void:
	if not is_node_ready():
		await ready

	card = data
	card_name.text = data.name
	icon.texture = data.icon
	# Keywords such as Energy, Mult, and Score are colored in CardKeywordGlossary.
	card_description.text = CardKeywordGlossary.to_bbcode(data.description)
	card_type_label.text = data.get_card_kind_label()
	_apply_card_frame()

	if interaction_mode == InteractionMode.MERCHANT:
		_refresh_merchant_price()
		_update_affordability()
	elif interaction_mode == InteractionMode.MERCHANT_STOCK:
		_refresh_merchant_price()
		_update_stock_affordability()


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func show_selection_glow() -> void:
	selection_glow.visible = true
	# Warm highlight so the selected card reads clearly above the rest of the hand.
	panel.modulate = Color(1.15, 1.1, 0.75, 1.0)


func hide_selection_glow() -> void:
	selection_glow.visible = false
	panel.modulate = Color.WHITE
	set_map_tile_hover_active(false, false)


func is_sold() -> bool:
	return _is_sold


func mark_sold() -> void:
	_is_sold = true
	sold_overlay.visible = true
	hide_selection_glow()
	set_hover_elevated(false, false)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_hide_keyword_tooltips()


func refresh_affordability() -> void:
	if _is_sold:
		return
	if interaction_mode == InteractionMode.MERCHANT_STOCK:
		_update_stock_affordability()
	elif interaction_mode == InteractionMode.MERCHANT:
		_update_affordability()


func apply_discount(discount: float) -> void:
	if interaction_mode != InteractionMode.MERCHANT and interaction_mode != InteractionMode.MERCHANT_STOCK:
		return
	if _is_sold:
		return

	_discount = discount
	_refresh_merchant_price()
	if interaction_mode == InteractionMode.MERCHANT_STOCK:
		_update_stock_affordability()
	else:
		_update_affordability()


func _refresh_merchant_price() -> void:
	if card == null:
		return

	price = card.get_shop_price(_discount)
	_token_cost = GoldManager.get_token_cost(card)
	price_label.text = "$%d" % price


func _update_affordability() -> void:
	var can_afford := GoldManager.can_afford(price)
	price_label.modulate = Color.WHITE if can_afford else Color.RED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW


## Stock cards are selectable even when the player cannot afford gold yet.
func _update_stock_affordability() -> void:
	price_label.modulate = Color.WHITE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if _is_sold else Control.CURSOR_POINTING_HAND


func get_token_cost() -> int:
	return _token_cost


func set_merchant_selected(selected: bool) -> void:
	if selected:
		show_selection_glow()
	else:
		hide_selection_glow()


func _show_keyword_tooltips() -> void:
	if card == null or _is_sold:
		return
	if interaction_mode == InteractionMode.PREVIEW:
		return

	# Always emit a hover claim so an empty keyword list closes the previous card's tips.
	var entries := CardKeywordGlossary.tooltip_entries(card.description)
	EventBus.toggle_keyword_tooltips.emit(true, entries, get_keyword_tooltip_anchor_rect(), self)


# Visual card bounds after offset_transform, using the hover pose so tips sit on the lifted top corners.
func get_keyword_tooltip_anchor_rect() -> Rect2:
	var pose_offset := offset_transform_position
	var pose_scale := offset_transform_scale if offset_transform_enabled else Vector2.ONE
	if interaction_mode == InteractionMode.HAND:
		pose_offset = Vector2(_hand_spread_x, _get_hover_elevation_offset())
		pose_scale = _get_hand_hover_scale()
	elif _is_hover_elevated:
		pose_offset = Vector2(0.0, _get_hover_elevation_offset())
		pose_scale = Vector2.ONE
	return _visual_global_rect_for(pose_offset, pose_scale)


func _visual_global_rect_for(pose_offset: Vector2, pose_scale: Vector2) -> Rect2:
	var pivot := size * offset_transform_pivot_ratio
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		var local : Vector2 = pivot + (corner - pivot) * pose_scale + pose_offset
		min_p = min_p.min(local)
		max_p = max_p.max(local)
	return Rect2(global_position + min_p, max_p - min_p)


func _hide_keyword_tooltips() -> void:
	EventBus.toggle_keyword_tooltips.emit(false, [], Rect2(), self)


func _apply_card_frame() -> void:
	var frame := _frame_texture_for_card(card)
	if frame == null:
		return

	var current_style := panel.get_theme_stylebox("panel")
	var textured: StyleBoxTexture
	if current_style is StyleBoxTexture:
		# Duplicate so swapping one card's frame does not change other instances.
		textured = (current_style as StyleBoxTexture).duplicate() as StyleBoxTexture
	else:
		textured = StyleBoxTexture.new()
		textured.content_margin_left = 4.0
		textured.content_margin_top = 4.0
		textured.content_margin_right = 4.0

	textured.texture = frame
	panel.add_theme_stylebox_override("panel", textured)


func _frame_texture_for_card(data: Card) -> Texture2D:
	if data is TileCard:
		match (data as TileCard).type:
			TileCard.TileCardType.PRODUCER:
				return frame_producer
			TileCard.TileCardType.SUPPORT:
				return frame_support
			TileCard.TileCardType.MODIFIER:
				return frame_modifier
	return frame_producer


func _on_drop_point_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_area_exited(area: Area2D) -> void:
	targets.erase(area)
