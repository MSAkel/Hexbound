class_name CardUI
extends Control

# Emitted in MERCHANT and CHOICE modes when the player clicks an actionable card.
signal action_requested(card_ui: CardUI)
signal gold_purchase_requested(card_ui: CardUI)

# Printed side of the card. This script only positions it and forwards state to it.
@onready var card_face: CardFace = $CardFace

# Merchant chrome lives in the scene and is shown only in shop interaction modes.
@onready var _price_chip_row: VBoxContainer = $MerchantPriceRow
@onready var _price_chip_label: Label = $MerchantPriceRow/PriceCenter/PriceChip/PriceChipLabel
@onready var _purchase_tray: MerchantPurchaseTray = $MerchantPurchaseTray

enum InteractionMode {
	HAND,
	MERCHANT,
	MERCHANT_STOCK,
	CHOICE,
	PREVIEW,
}

# Typed payload. TileCard occupies hexes on the board.
var card: Card = null
var interaction_mode: InteractionMode = InteractionMode.HAND
# Preview cards (e.g. chef select) should not play hover elevation.
var hover_enabled := true
var price: int = 0

const HAND_HOVER_ELEVATION_OFFSET := -80.0
# Subtle pop when a hand card is hovered.
const HAND_HOVER_SCALE := 1.2
const HAND_ELEVATED_Z_INDEX := 10
# A card that is still shrinking back stays above its resting neighbors until it lands.
const HAND_SETTLING_Z_INDEX := 5
# Hover keeps hold this far past the lifted card's sides, covering the gap to its pushed neighbors.
const HAND_HOVER_HIT_MARGIN := 12.0
# The hovered card leans toward the cursor by up to this much. Set to 0 to keep it upright.
const HAND_HOVER_LEAN_DEGREES := 2.0
const HAND_HOVER_LEAN_SPEED := 12.0
# Slight squeeze while the button is held, before the press becomes a click or a drag.
const HAND_PRESS_SCALE := 0.96
const HAND_PRESS_DURATION := 0.07
const PANEL_HOVER_ELEVATION_OFFSET := -12.0
const MERCHANT_SELECTED_ELEVATION_OFFSET := -28.0
const HOVER_ANIMATION_DURATION := 0.22
# Neighbor spread uses a slightly longer ease so the fan feels weighted.
const HAND_SPREAD_ANIMATION_DURATION := 0.28
# Pointer travel from the press before a hand card counts as dragged instead of clicked.
const DRAG_START_THRESHOLD_PX := 8.0
# The card fades out under its ghost on pick-up and back in when the ghost returns.
const PICKUP_FADE_DURATION := 0.08
const RETURN_FADE_DURATION := 0.18
# Room beneath merchant stock cards for the compact purchase tray.
const MERCHANT_TRAY_HEIGHT := 44.0
# Space between the card frame and the purchase tray.
const MERCHANT_TRAY_GAP := -25.0
# Reserved band above the card frame for the price chip.
const PRICE_CHIP_ROW_HEIGHT := 24.0
const MERCHANT_STOCK_CARD_HEIGHT := 340.0
const MERCHANT_STOCK_SLOT_HEIGHT := (
	MERCHANT_STOCK_CARD_HEIGHT + PRICE_CHIP_ROW_HEIGHT + MERCHANT_TRAY_GAP + MERCHANT_TRAY_HEIGHT
)

## Pose layers. _apply_pose() adds them up and is the only writer of offset_transform,
## so a hand slide, a hover and a click nudge can overlap without fighting.
## Where the owner parks the card relative to its layout slot, such as below the screen.
var slot_offset := Vector2.ZERO:
	set(value):
		slot_offset = value
		_apply_pose()
## Extra scale from the owner. The generated-card showcase uses it.
var slot_scale := Vector2.ONE:
	set(value):
		slot_scale = value
		_apply_pose()
# Hover lift plus the fan spread Hand asks for.
var _hover_offset := Vector2.ZERO:
	set(value):
		_hover_offset = value
		_apply_pose()
var _hover_rotation := 0.0:
	set(value):
		_hover_rotation = value
		_apply_pose()
var _hover_scale := Vector2.ONE:
	set(value):
		_hover_scale = value
		_apply_pose()
var _nudge_offset := Vector2.ZERO:
	set(value):
		_nudge_offset = value
		_apply_pose()
# Sway toward the cursor while hovered.
var _lean_rotation := 0.0:
	set(value):
		_lean_rotation = value
		_apply_pose()

var _is_hover_elevated := false
var _resting_z_index := 0
var _hover_tween: Tween
var _nudge_tween: Tween
var _fade_tween: Tween
# Fan spread requested by Hand so neighbors slide aside while another card grows.
var _hand_spread_x := 0.0
var _hand_spread_rotation := 0.0
var _is_sold := false
var _discount := 0.0
var _merchant_selected := false
## True while the card is hidden in its hand slot and its ghost is aimed at the board.
var _held_for_placement := false
# The left button went down on this hand card and has not been released or dragged yet.
var _press_held := false
var _press_position := Vector2.ZERO


func _ready() -> void:
	_resting_z_index = z_index
	resized.connect(_layout_card_face)
	_apply_interaction_mode()
	tree_exiting.connect(_hide_keyword_tooltips)
	# Shop and choice cards double as gamepad focus targets, so mirror hover on focus.
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


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


func _is_merchant_mode() -> bool:
	return (
		interaction_mode == InteractionMode.MERCHANT
		or interaction_mode == InteractionMode.MERCHANT_STOCK
	)


func _apply_interaction_mode() -> void:
	_release_press()

	match interaction_mode:
		InteractionMode.HAND:
			hover_enabled = true
			# Grow from the bottom edge so the card lifts and scales upward in the fan.
			offset_transform_pivot_ratio = Vector2(0.5, 1.0)
		InteractionMode.MERCHANT:
			hover_enabled = true
			_refresh_merchant_price()
			_update_affordability()
		InteractionMode.MERCHANT_STOCK:
			hover_enabled = true
			_refresh_merchant_price()
			_update_stock_affordability()
		InteractionMode.CHOICE:
			hover_enabled = true
		InteractionMode.PREVIEW:
			hover_enabled = false

	# Only shop cards can be sold out.
	card_face.set_sold(_is_sold and _is_merchant_mode())
	_layout_merchant_price(_is_merchant_mode())

	if interaction_mode == InteractionMode.HAND:
		_apply_pose()
	else:
		# Hand cards scale through their pose. Other modes stay at default size.
		offset_transform_scale = Vector2.ONE

	_refresh_focus_mode()


## Shop and choice cards are directional-navigation targets.
## Hand cards are excluded because Hand runs its own controller focus ring.
func _supports_focus() -> bool:
	if _is_sold:
		return false
	match interaction_mode:
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			return true
		_:
			return false


func _refresh_focus_mode() -> void:
	var wants_focus := _supports_focus()
	focus_mode = Control.FOCUS_ALL if wants_focus else Control.FOCUS_NONE
	if not wants_focus and has_focus():
		release_focus()


func _on_focus_entered() -> void:
	if _is_sold:
		return
	set_hover_elevated(true)
	_show_keyword_tooltips()


func _on_focus_exited() -> void:
	_hide_keyword_tooltips()
	# Choice and stock cards lose focus as they are freed. Skip the tween in that case.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	set_hover_elevated(false)


## Confirm on a focused card. Matches the left-click path for the current mode.
func _activate_focused_card() -> void:
	if _is_sold:
		return
	if interaction_mode == InteractionMode.MERCHANT and not GoldManager.can_afford(price):
		return
	action_requested.emit(self)


## Merchant price chip sits above the frame. Hand cards keep the original full-bleed layout.
func _layout_merchant_price(enabled: bool) -> void:
	_price_chip_row.visible = enabled
	_layout_card_face()
	if enabled:
		_update_merchant_stock_height()
		return
	_purchase_tray.visible = false
	_reset_merchant_stock_lift_targets()


## Runs on every resize, so the face follows whatever slot the parent gives this card.
func _layout_card_face() -> void:
	card_face.fit_to(_card_frame_rect())


## Area the card face may fill. Merchant modes reserve the chip row above and the tray below.
func _card_frame_rect() -> Rect2:
	if not _is_merchant_mode():
		return Rect2(Vector2.ZERO, size)
	var bottom := size.y + _merchant_card_frame_bottom_offset()
	return Rect2(0.0, PRICE_CHIP_ROW_HEIGHT, size.x, bottom - PRICE_CHIP_ROW_HEIGHT)


func _merchant_card_frame_bottom_offset() -> float:
	# Always reserve tray space so the card frame never resizes on selection.
	if interaction_mode != InteractionMode.MERCHANT_STOCK:
		return -3.0
	return -(MERCHANT_TRAY_GAP + MERCHANT_TRAY_HEIGHT + 3.0)


func _update_merchant_stock_height() -> void:
	if interaction_mode != InteractionMode.MERCHANT_STOCK:
		return
	custom_minimum_size.y = MERCHANT_STOCK_SLOT_HEIGHT
	_purchase_tray.offset_top = _purchase_tray_top()
	_purchase_tray.offset_bottom = _purchase_tray_top() + MERCHANT_TRAY_HEIGHT


func _purchase_tray_top() -> float:
	return _card_frame_bottom_y() + MERCHANT_TRAY_GAP


func _card_frame_bottom_y() -> float:
	return MERCHANT_STOCK_SLOT_HEIGHT + _merchant_card_frame_bottom_offset()


func _on_gold_purchase_pressed() -> void:
	gold_purchase_requested.emit(self)


func _get_hover_elevation_offset() -> float:
	match interaction_mode:
		InteractionMode.HAND:
			return HAND_HOVER_ELEVATION_OFFSET
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			return PANEL_HOVER_ELEVATION_OFFSET
		_:
			return 0.0


func is_hover_elevated() -> bool:
	return _is_hover_elevated


func is_held_for_placement() -> bool:
	return _held_for_placement


func _update_hand_z_index(elevated: bool) -> void:
	if interaction_mode != InteractionMode.HAND:
		return
	# Lowering is finished by _animate_hover_pose, once the card has shrunk back.
	if elevated:
		z_index = HAND_ELEVATED_Z_INDEX


## Drops hover lift and fan spread without notifying Hand. Hand calls this when it re-lays the fan.
func reset_hand_pose(animate: bool = false) -> void:
	_is_hover_elevated = false
	_hand_spread_x = 0.0
	_hand_spread_rotation = 0.0
	_update_hand_z_index(false)
	_animate_hover_pose(animate)


# Hand uses this to push unhovered cards away from the featured card.
func set_hand_spread_pose(spread_x: float, spread_rotation: float, animate: bool = true) -> void:
	if is_equal_approx(_hand_spread_x, spread_x) and is_equal_approx(_hand_spread_rotation, spread_rotation):
		return
	_hand_spread_x = spread_x
	_hand_spread_rotation = spread_rotation
	_animate_hover_pose(animate)


func set_hover_elevated(elevated: bool, animate: bool = true) -> void:
	# The hidden placement card keeps its pose so a cancelled drag returns it in place.
	if _held_for_placement:
		return
	if not hover_enabled:
		elevated = false
		animate = false

	_is_hover_elevated = elevated
	_update_hand_z_index(elevated)
	var hand := get_parent() as Hand
	if hand != null:
		hand.notify_card_featured(self, elevated, animate)
	_animate_hover_pose(animate)


## Hand resolves which card the mouse rests on and reports it here.
## Pass change_lift false to only update the tooltips.
func set_hand_hovered(hovered: bool, change_lift: bool = true) -> void:
	if change_lift:
		set_hover_elevated(hovered)
	if hovered:
		_show_keyword_tooltips()
	else:
		_hide_keyword_tooltips()


## Area that counts as this card for hand hover. Follows the pose the card is heading to,
## not its layout slot, so the whole lifted card can be hovered and grabbed.
func get_hover_hit_rect() -> Rect2:
	var rect := _visual_global_rect_for(_target_hover_offset(), _target_hover_scale())
	if _is_hover_elevated:
		# Keep the strip the lift uncovers below the card, so hover never flickers.
		rect = rect.grow_individual(HAND_HOVER_HIT_MARGIN, 0.0, HAND_HOVER_HIT_MARGIN, 0.0)
		rect.end.y = maxf(rect.end.y, get_global_rect().end.y)
	return rect


## Eases the lean toward lean, from -1 (cursor at the left edge) to 1 (right edge).
func update_hover_lean(lean: float, delta: float) -> void:
	var target := deg_to_rad(HAND_HOVER_LEAN_DEGREES) * clampf(lean, -1.0, 1.0)
	if is_equal_approx(_lean_rotation, target):
		return
	_lean_rotation = lerpf(_lean_rotation, target, 1.0 - exp(-HAND_HOVER_LEAN_SPEED * delta))
	if absf(_lean_rotation - target) < 0.0005:
		_lean_rotation = target


func _target_hover_offset() -> Vector2:
	var y := _get_hover_elevation_offset() if _is_hover_elevated else 0.0
	if _merchant_selected:
		y = minf(y, MERCHANT_SELECTED_ELEVATION_OFFSET)
	return Vector2(_hand_spread_x, y)


func _target_hover_scale() -> Vector2:
	if interaction_mode != InteractionMode.HAND:
		return Vector2.ONE
	var hover_scale := HAND_HOVER_SCALE if _is_hover_elevated else 1.0
	if _press_held:
		hover_scale *= HAND_PRESS_SCALE
	return Vector2.ONE * hover_scale


## Eases the hover layer toward the current lift, spread and scale.
## A negative duration picks the usual hover or spread timing.
func _animate_hover_pose(animate: bool, duration: float = -1.0) -> void:
	_kill_tween(_hover_tween)

	var target_offset := _target_hover_offset()
	var target_rotation := _hand_spread_rotation if interaction_mode == InteractionMode.HAND else 0.0
	var target_scale := _target_hover_scale()
	var at_target := (
		_hover_offset.is_equal_approx(target_offset)
		and is_equal_approx(_hover_rotation, target_rotation)
		and _hover_scale.is_equal_approx(target_scale)
	)

	if not animate or at_target or not is_inside_tree():
		_hover_offset = target_offset
		_hover_rotation = target_rotation
		_hover_scale = target_scale
		_finish_hover_settle()
		return

	var is_hand := interaction_mode == InteractionMode.HAND
	var rising := _is_hover_elevated and not is_equal_approx(_hover_offset.y, target_offset.y)
	if duration < 0.0:
		duration = HOVER_ANIMATION_DURATION if _is_hover_elevated else HAND_SPREAD_ANIMATION_DURATION
	_hover_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	# A rising hand card overshoots a touch so the lift reads as a pop. Everything else eases flat.
	_hover_tween.set_trans(Tween.TRANS_BACK if rising and is_hand else Tween.TRANS_CUBIC)
	_hover_tween.tween_property(self, "_hover_offset", target_offset, duration)
	_hover_tween.tween_property(
		self, "_hover_rotation", target_rotation, duration
	).set_trans(Tween.TRANS_CUBIC)
	# Match the lift so hover reads as one motion.
	_hover_tween.tween_property(self, "_hover_scale", target_scale, duration)

	if is_hand and not _is_hover_elevated and z_index != _resting_z_index:
		# Still large on the way down. Stay above the neighbors until it lands.
		z_index = HAND_SETTLING_Z_INDEX
		_hover_tween.finished.connect(_finish_hover_settle)


func _finish_hover_settle() -> void:
	if interaction_mode == InteractionMode.HAND and not _is_hover_elevated:
		z_index = _resting_z_index


## Composes the pose layers onto offset_transform. Nothing else writes it.
func _apply_pose() -> void:
	if not is_node_ready():
		return
	var pose_position := slot_offset + _hover_offset + _nudge_offset

	if interaction_mode == InteractionMode.MERCHANT_STOCK:
		# Root offset_transform is draw-only. Lift card art only so tray buttons stay clickable.
		offset_transform_enabled = false
		offset_transform_position = Vector2.ZERO
		offset_transform_scale = Vector2.ONE
		for node in _merchant_stock_lift_targets():
			node.offset_transform_enabled = true
			node.offset_transform_position = pose_position
			node.offset_transform_scale = Vector2.ONE
		return

	offset_transform_enabled = true
	offset_transform_position = pose_position
	offset_transform_rotation = _hover_rotation + _lean_rotation
	offset_transform_scale = slot_scale * _hover_scale


func _merchant_stock_lift_targets() -> Array[Control]:
	var lift_targets: Array[Control] = []
	lift_targets.append(_price_chip_row)
	lift_targets.append(card_face)
	return lift_targets


func _reset_merchant_stock_lift_targets() -> void:
	offset_transform_enabled = false
	offset_transform_position = Vector2.ZERO
	offset_transform_scale = Vector2.ONE
	for node in _merchant_stock_lift_targets():
		node.offset_transform_enabled = false
		node.offset_transform_position = Vector2.ZERO
		node.offset_transform_scale = Vector2.ONE


## Only runs while a press is held on this hand card. Tells a click from the start of a drag.
func _input(event: InputEvent) -> void:
	if not _press_held:
		return
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		# The hand slid away mid-press.
		_release_press()
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_release_press()
		# A press that never became a drag still gets feedback.
		play_click_nudge()
		return
	if event is InputEventMouseMotion \
			and get_global_mouse_position().distance_to(_press_position) >= DRAG_START_THRESHOLD_PX:
		_release_press()
		get_viewport().set_input_as_handled()
		EventBus.card_drag_requested.emit(self)


func _release_press() -> void:
	set_process_input(false)
	if not _press_held:
		return
	_press_held = false
	_animate_hover_pose(true, HAND_PRESS_DURATION)


## Hand calls this when the left button goes down on this card.
## The press becomes a drag only once the pointer travels.
func begin_press() -> void:
	if _held_for_placement:
		return
	_press_held = true
	_press_position = get_global_mouse_position()
	set_process_input(true)
	_animate_hover_pose(true, HAND_PRESS_DURATION)


func is_press_held() -> bool:
	return _press_held


func _on_gui_input(event: InputEvent) -> void:
	if _supports_focus() and event.is_action_pressed("ui_accept"):
		_activate_focused_card()
		accept_event()
		return

	match interaction_mode:
		InteractionMode.MERCHANT:
			_handle_merchant_gui_input(event)
		InteractionMode.MERCHANT_STOCK:
			_handle_merchant_stock_gui_input(event)
		InteractionMode.CHOICE:
			_handle_choice_gui_input(event)


func _on_mouse_entered() -> void:
	# Hand cards are hovered by Hand, which follows the lifted card instead of the layout slot.
	match interaction_mode:
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			if _is_sold:
				return
			set_hover_elevated(true)
			_show_keyword_tooltips()
		InteractionMode.PREVIEW:
			_show_keyword_tooltips()


func _on_mouse_exited() -> void:
	if interaction_mode == InteractionMode.HAND:
		return
	if not has_focus():
		_hide_keyword_tooltips()
	match interaction_mode:
		InteractionMode.MERCHANT, InteractionMode.MERCHANT_STOCK, InteractionMode.CHOICE:
			# A focused card keeps its lift so the gamepad cursor does not vanish.
			if not has_focus():
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
	card_face.set_card(data)

	if interaction_mode == InteractionMode.MERCHANT:
		_refresh_merchant_price()
		_update_affordability()
	elif interaction_mode == InteractionMode.MERCHANT_STOCK:
		_refresh_merchant_price()
		_update_stock_affordability()


## True when the cursor is over the card's layout slot, ignoring lift and scale.
func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


## Hides this card in its hand slot while its ghost is aimed at the board.
## It keeps its slot and pose, so neighbors do not reflow and a cancelled drag returns it in place.
func begin_board_placement() -> void:
	_held_for_placement = true
	_release_press()
	_kill_tween(_nudge_tween)
	_nudge_offset = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_keyword_tooltips()
	_fade_to(0.0, PICKUP_FADE_DURATION)


## Shows the card again after its placement was cancelled.
## Pass interactive false when the hand is off-screen and the card must stay inert.
func end_board_placement(interactive: bool = true) -> void:
	if not _held_for_placement:
		return
	_held_for_placement = false
	_fade_to(1.0, RETURN_FADE_DURATION)
	if interactive:
		# Hand decides next whether the cursor is still on this card.
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		reset_hand_pose()


func _fade_to(alpha: float, duration: float) -> void:
	_kill_tween(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, duration)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## Short shake on click so a press that does not start a drag still has feedback.
func play_click_nudge() -> void:
	if _held_for_placement:
		return
	_kill_tween(_nudge_tween)

	const NUDGE := 3.0
	const STEP := 0.035
	_nudge_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_nudge_tween.tween_property(
		self, "_nudge_offset", Vector2(-NUDGE, 2.0), STEP
	).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(
		self, "_nudge_offset", Vector2(NUDGE, -1.5), STEP
	).set_ease(Tween.EASE_IN_OUT)
	_nudge_tween.tween_property(
		self, "_nudge_offset", Vector2(-NUDGE * 0.35, 1.0), STEP
	).set_ease(Tween.EASE_IN_OUT)
	_nudge_tween.tween_property(
		self, "_nudge_offset", Vector2.ZERO, STEP * 1.4
	).set_ease(Tween.EASE_OUT)


func show_selection_glow() -> void:
	card_face.set_selected(true)


func hide_selection_glow() -> void:
	card_face.set_selected(false)


func is_sold() -> bool:
	return _is_sold


func mark_sold() -> void:
	_is_sold = true
	card_face.set_sold(true)
	hide_selection_glow()
	set_hover_elevated(false, false)
	_purchase_tray.visible = false
	if interaction_mode == InteractionMode.MERCHANT_STOCK:
		custom_minimum_size.y = MERCHANT_STOCK_SLOT_HEIGHT
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_hide_keyword_tooltips()
	_purchase_tray.set_focusable(false)
	_refresh_focus_mode()


func refresh_affordability() -> void:
	if _is_sold:
		return
	if interaction_mode == InteractionMode.MERCHANT_STOCK:
		_update_stock_affordability()
	elif interaction_mode == InteractionMode.MERCHANT:
		_update_affordability()


func apply_discount(discount: float) -> void:
	if not _is_merchant_mode():
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
	_price_chip_label.text = MerchantShopStyling.format_price(price)
	_refresh_price_chip_affordability()


func _refresh_price_chip_affordability() -> void:
	var can_afford := GoldManager.can_afford(price)
	_price_chip_label.add_theme_color_override(
		"font_color",
		MerchantShopStyling.price_label_color(can_afford)
	)


func _update_affordability() -> void:
	_refresh_price_chip_affordability()
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if GoldManager.can_afford(price)
		else Control.CURSOR_ARROW
	)


## Stock cards are selectable even when the player cannot afford gold yet.
func _update_stock_affordability() -> void:
	_refresh_price_chip_affordability()
	mouse_default_cursor_shape = Control.CURSOR_ARROW if _is_sold else Control.CURSOR_POINTING_HAND
	refresh_purchase_tray()


func refresh_purchase_tray() -> void:
	var block_reason := card.get_purchase_block_reason() if card != null else ""
	var gold_enabled := not _is_sold and block_reason.is_empty() and GoldManager.can_afford(price)
	_purchase_tray.set_gold_enabled(gold_enabled)
	_purchase_tray.set_block_reason(block_reason)


func set_merchant_selected(selected: bool) -> void:
	_merchant_selected = selected
	z_index = 2 if selected else _resting_z_index
	if interaction_mode == InteractionMode.MERCHANT_STOCK:
		hide_selection_glow()
	elif selected:
		show_selection_glow()
	else:
		hide_selection_glow()
	# The buy tray is only used on the merchant shelf, not in the older single-click buy mode.
	_purchase_tray.visible = (
		selected
		and not _is_sold
		and interaction_mode == InteractionMode.MERCHANT_STOCK
	)
	if selected:
		refresh_purchase_tray()
	# Buy buttons only enter the focus chain while their tray is on screen.
	_purchase_tray.set_focusable(_purchase_tray.visible)
	_animate_hover_pose(true)


## Move focus onto the buy row after this shelf card is selected.
## False when the tray is hidden or every buy option is unaffordable.
func focus_purchase_tray() -> bool:
	if not _purchase_tray.visible:
		return false
	return _purchase_tray.focus_first_enabled()


func _show_keyword_tooltips() -> void:
	if card == null or _is_sold:
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
		pose_scale = Vector2.ONE * HAND_HOVER_SCALE
	elif interaction_mode == InteractionMode.MERCHANT_STOCK or interaction_mode == InteractionMode.MERCHANT:
		pose_offset = _target_hover_offset()
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
