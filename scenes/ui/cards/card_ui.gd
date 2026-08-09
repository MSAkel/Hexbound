class_name CardUI
extends Control

signal reparent_requested(which_card_ui: CardUI)
# Emitted in MERCHANT and CHOICE modes when the player clicks an actionable card.
signal action_requested(card_ui: CardUI)

const BASE_STYLEBOX := preload("res://themes/card_base_stylebox.tres")
const HOVER_STYLEBOX := preload("res://themes/card_hover_stylebox.tres")
const DRAG_STYLEBOX := preload("res://themes/card_drag_stylebox.tres")

# Fallback prices when a rune has no rarity set in its resource.
const BASE_PRICE_BY_RARITY := {
	Rune.RuneRarity.COMMON: 15,
	Rune.RuneRarity.UNCOMMON: 30,
	Rune.RuneRarity.RARE: 45,
}
const DEFAULT_PRICE := 10
const ENHANCEMENT_BASE_PRICE := 30

@onready var card_name: Label = $VBoxContainer/NameContainer/CardName
@onready var icon: TextureRect = $VBoxContainer/IconContainer/Icon
@onready var card_description: Label = $VBoxContainer/CardDescription
@onready var resource_cost_container: HBoxContainer = $VBoxContainer/ResourceCostContainer
@onready var card_type_label: Label = $VBoxContainer/CardTypeLabel
@onready var price_label: Label = $VBoxContainer/PriceLabel

@onready var drop_point_area: Area2D = $DropPointArea
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []
@onready var starting_hand_position := self.get_index()

@onready var panel: Panel = $Panel
@onready var content_container: VBoxContainer = $VBoxContainer
# Scene-authored border glow; toggled when the card enters/exits the clicked placement state.
@onready var selection_glow: Panel = $SelectionGlow
@onready var sold_overlay: Panel = $SoldOverlay

enum InteractionMode {
	HAND,
	MERCHANT,
	CHOICE,
	PREVIEW,
}

enum CardType {
	RUNE,
	ENHANCEMENT,
}

var card = null
var card_type: CardType
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
var _is_sold := false
var _discount := 0.0


func _ready() -> void:
	_resting_z_index = z_index
	_apply_interaction_mode()


# Parent screens call this after instantiation to choose how the card responds to input.
func configure_interaction(mode: InteractionMode, options: Dictionary = {}) -> void:
	interaction_mode = mode
	_discount = options.get("discount", 0.0)

	if is_node_ready():
		_apply_interaction_mode()
	elif mode == InteractionMode.MERCHANT and card != null:
		# set_card may run before _ready when merchant cards are spawned in a loop.
		call_deferred("_refresh_merchant_price")
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
		InteractionMode.MERCHANT, InteractionMode.CHOICE:
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


func set_hover_elevated(elevated: bool, animate: bool = true) -> void:
	if not hover_enabled:
		elevated = false
		animate = false

	if _elevation_tween and _elevation_tween.is_valid():
		_elevation_tween.kill()
		_elevation_tween = null

	_is_hover_elevated = elevated
	_update_hand_z_index(elevated)
	var target_offset := Vector2(0, _get_hover_elevation_offset()) if elevated else Vector2.ZERO
	var apply_hand_scale := _should_apply_hand_hover_scale()
	var target_scale := _get_hand_hover_scale() if elevated and apply_hand_scale else Vector2.ONE

	if not animate or _is_hover_transform_at_target(target_offset, target_scale, apply_hand_scale):
		offset_transform_enabled = true
		offset_transform_position = target_offset
		if apply_hand_scale:
			offset_transform_scale = target_scale
		return

	offset_transform_enabled = true
	_elevation_tween = create_tween()
	_elevation_tween.set_parallel(true)
	var ease_type := Tween.EASE_OUT if elevated else Tween.EASE_IN
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
		InteractionMode.CHOICE:
			_handle_choice_gui_input(event)


func _on_mouse_entered() -> void:
	match interaction_mode:
		InteractionMode.HAND:
			card_state_machine.on_mouse_entered()
		InteractionMode.MERCHANT, InteractionMode.CHOICE:
			if _is_sold:
				return
			set_hover_elevated(true)


func _on_mouse_exited() -> void:
	match interaction_mode:
		InteractionMode.HAND:
			card_state_machine.on_mouse_exited()
		InteractionMode.MERCHANT, InteractionMode.CHOICE:
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


func _handle_choice_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		action_requested.emit(self)
		accept_event()


func set_card(data) -> void:
	if not is_node_ready():
		await ready

	card = data
	card_name.text = data.name
	icon.texture = data.icon
	card_description.text = data.description

	if data is Rune:
		card_type = CardType.RUNE
		card_type_label.text = Rune.RuneType.keys()[data.type]
	elif data is Enhancement:
		card_type = CardType.ENHANCEMENT
		card_type_label.text = "Enhancement"
	else:
		push_error("Unknown card type for data: ", data)

	if interaction_mode == InteractionMode.MERCHANT:
		_refresh_merchant_price()
		_update_affordability()


func get_card_type() -> CardType:
	return card_type


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
	set_hover_elevated(false, false)
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func refresh_affordability() -> void:
	if interaction_mode != InteractionMode.MERCHANT or _is_sold:
		return
	_update_affordability()


func apply_discount(discount: float) -> void:
	if interaction_mode != InteractionMode.MERCHANT or _is_sold:
		return

	_discount = discount
	_refresh_merchant_price()
	_update_affordability()


static func get_price_for_rune(card_rune: Rune, discount: float = 0.0) -> int:
	var base_price: int = BASE_PRICE_BY_RARITY.get(card_rune.rarity, DEFAULT_PRICE)
	return maxi(1, int(round(base_price * (Difficulty.get_merchant_price_multiplier(GameManager.selected_difficulty) - discount))))


static func get_price_for_enhancement(discount: float = 0.0) -> int:
	return maxi(1, int(round(ENHANCEMENT_BASE_PRICE * (Difficulty.get_merchant_price_multiplier(GameManager.selected_difficulty) - discount))))


func _refresh_merchant_price() -> void:
	if card == null:
		return

	if card is Rune:
		price = get_price_for_rune(card as Rune, _discount)
	elif card is Enhancement:
		price = get_price_for_enhancement(_discount)
	else:
		push_error("CardUI cannot price unsupported resource type")
		return

	price_label.text = "$%d" % price


func _update_affordability() -> void:
	var can_afford := GoldManager.can_afford(price)
	# Price color communicates affordability; the card itself stays unchanged.
	price_label.modulate = Color.WHITE if can_afford else Color.RED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW


func _on_drop_point_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_area_exited(area: Area2D) -> void:
	targets.erase(area)
